//
//  PendingNodes.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/20/26.
//  Copyright © 2024 Honghao Zhang.
//
//  MIT License
//
//  Copyright (c) 2024 Honghao Zhang (github.com/honghaoz)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

/// The nodes that a thread's blocks of one statement write while content is built, which the block that holds them
/// moves into its own buffer, or takes in their buffer when they're all of the pending nodes.
///
/// A loop's iterations are blocks of one statement, so they write into one buffer, which a stack that holds only the
/// loop keeps as its children, instead of each into a buffer of its own. A block's content refers to its pending nodes
/// by their indexes until it's written.
///
/// The pending nodes stay sound through these rules:
/// - A block writes its nodes after the nodes of its statements, so its ranges follow theirs, and when it moves its
///   ranges in order, its last range is at the end.
/// - A block takes the buffer only when its range holds all of the pending nodes.
/// - Moving a range out leaves an empty node in each place, which the buffer drops once the places above it are empty.
/// - A content is written on the thread that wrote its nodes, which its claim asserts in debug builds.
/// - Content built in a task doesn't use the pending nodes, and the nodes that a builder function that throws leaves
///   are destroyed when the thread next writes a block of one node, once no content refers to them, or when the thread
///   exits.
@usableFromInline
final class PendingNodes {

  /// An object that the content of pending nodes keeps, whose references tell whether a content refers to pending nodes.
  @usableFromInline
  final class Claim {

    /// The pending nodes that the claim's content refers to, which outlive the build that writes and reads the content.
    unowned(unsafe) let owner: PendingNodes

    init(owner: PendingNodes) {
      self.owner = owner
    }
  }

  /// Takes room for nodes in the calling thread's pending nodes, unless the thread runs a task.
  ///
  /// - Parameters:
  ///   - count: The number of nodes.
  ///   - valuesByteCount: The number of bytes that the nodes' values take at most.
  /// - Returns: The buffer that the nodes are appended to, which has room for them, the index that the first takes, and
  ///   the claim that the nodes' content keeps, or `nil` in a task.
  @usableFromInline
  static func reserve(count: Int, valuesByteCount: Int) -> (buffer: NodeBuffer, start: Int, claim: Claim)? {
    // an async builder function can suspend between two blocks and resume on another thread, whose pending nodes its
    // content's indexes don't refer to, so content built in a task writes each block into a buffer of its own
    let isInTask = withUnsafeCurrentTask { task in
      // a switch reads the task's optional in place, while comparing it with `nil` copies it through its metadata
      switch task {
      case .none:
        false
      case .some:
        true
      }
    }
    if isInTask {
      return nil
    } else {
      return current.reserve(count: count, valuesByteCount: valuesByteCount)
    }
  }

  /// The calling thread's pending nodes, which the thread releases when it exits.
  static var current: PendingNodes {
    if let pointer = pthread_getspecific(key) {
      return Unmanaged<PendingNodes>.fromOpaque(pointer).takeUnretainedValue()
    } else {
      let nodes = PendingNodes()
      pthread_setspecific(key, Unmanaged.passRetained(nodes).toOpaque())
      return nodes
    }
  }

  /// The key of each thread's pending nodes.
  private static let key: pthread_key_t = {
    var key = pthread_key_t()
    let status = pthread_key_create(&key) { pointer in
      Unmanaged<PendingNodes>.fromOpaque(pointer).release()
    }
    precondition(status == 0, "a key for each thread's pending nodes must be created")
    return key
  }()

  /// The nodes, in a buffer made when a block writes the first, which a block can take.
  private var buffer: NodeBuffer?

  /// The claim that the content of the pending nodes keeps, a variable since `isKnownUniquelyReferenced(_:)` takes it
  /// in place, and implicitly unwrapped since it refers back to the pending nodes, so it's made once they exist.
  private var claim: Claim!

  /// The rooms of the recent loops that held all of the pending nodes, newest first, which a growing buffer grows to at
  /// once, since a refresh builds the same content again.
  private var rooms: [Room] = []

  private init() {
    claim = Claim(owner: self)
  }

  /// Returns the number of bytes that a range of the pending nodes' values take at most in another buffer.
  ///
  /// - Parameters:
  ///   - start: The index of the first node.
  ///   - count: The number of nodes.
  /// - Returns: The number of bytes.
  func room(start: Int, count: Int) -> Int {
    pendingBuffer().roomOfChildren(from: start, count: count)
  }

  /// Returns the buffer of a block's content whose nodes are a range of the pending nodes: their buffer, when the range
  /// holds all of the pending nodes and at least three quarters of the buffer's room for children and for values, which
  /// leaves no buffer for the next nodes, or else a buffer of their own that they move into.
  ///
  /// A range of all the pending nodes is a loop that a refresh builds again, so its room is remembered either way.
  ///
  /// - Parameters:
  ///   - start: The index of the first node.
  ///   - count: The number of nodes.
  /// - Returns: The buffer.
  func contentBuffer(start: Int, count: Int) -> NodeBuffer {
    let buffer = pendingBuffer()
    // a single node is neither a loop whose room a buffer grows to nor enough to fill a buffer, so it moves out without
    // either check
    guard count > 1, start == 0, count == buffer.count else {
      return movedIntoBufferOfTheirOwn(from: buffer, start: start, count: count, loopFilledTooLittle: false)
    }
    let valuesByteCount = buffer.valuesByteCountInUse
    remember(Room(childCount: count, valuesByteCount: valuesByteCount))
    if count * 4 >= buffer.childCapacity * 3, valuesByteCount * 4 >= buffer.valuesByteCapacity * 3 {
      self.buffer = nil
      return buffer
    } else {
      // the stack would keep the room that its nodes don't use, so the nodes move into a buffer of their own instead
      return movedIntoBufferOfTheirOwn(from: buffer, start: start, count: count, loopFilledTooLittle: true)
    }
  }

  /// Moves a range of the pending nodes into a buffer, and drops the places of the moved nodes at the end of the pending
  /// nodes.
  ///
  /// - Parameters:
  ///   - start: The index of the first node.
  ///   - count: The number of nodes.
  ///   - other: The buffer, whose room the nodes must fit in.
  func moveNodes(start: Int, count: Int, into other: NodeBuffer) {
    move(from: pendingBuffer(), start: start, count: count, into: other, loopFilledTooLittle: false)
  }

  private func movedIntoBufferOfTheirOwn(from buffer: NodeBuffer, start: Int, count: Int, loopFilledTooLittle: Bool) -> NodeBuffer {
    let other = NodeBuffer.make(capacity: count, valuesByteCount: buffer.roomOfChildren(from: start, count: count))
    move(from: buffer, start: start, count: count, into: other, loopFilledTooLittle: loopFilledTooLittle)
    return other
  }

  private func move(from buffer: NodeBuffer, start: Int, count: Int, into other: NodeBuffer, loopFilledTooLittle: Bool) {
    precondition(start >= 0 && count >= 0 && start + count <= buffer.count, "a block's pending nodes are written once")
    buffer.moveChildren(from: start, count: count, into: other)
    // a block moves its ranges in order, after the blocks in it moved theirs, so its last range is at the end, and
    // moving it drops the places of all the block's nodes, down to any nodes left by a builder function that threw
    buffer.dropMovedChildren()
    if buffer.count == 0, !keepsEmpty(buffer, loopFilledTooLittle: loopFilledTooLittle) {
      self.buffer = nil
    }
  }

  private func reserve(count: Int, valuesByteCount: Int) -> (buffer: NodeBuffer, start: Int, claim: Claim) {
    if let buffer, buffer.count > 0, isKnownUniquelyReferenced(&claim) {
      // no content refers to the nodes in the buffer, so a builder function that threw left them, and dropping the
      // buffer destroys them
      self.buffer = nil
    }
    if let buffer,
       buffer.count + count <= buffer.childCapacity,
       buffer.valuesByteCountInUse + valuesByteCount <= buffer.valuesByteCapacity
    {
      return (buffer, buffer.count, claim)
    } else {
      let buffer = grown(adding: count, valuesByteCount: valuesByteCount)
      return (buffer, buffer.count, claim)
    }
  }

  /// Replaces the buffer with one that has room for more nodes, which keeps the nodes at their indexes.
  ///
  /// A first buffer is small, so that a block of one node doesn't make a large buffer, and a buffer that grows grows to
  /// the smallest remembered room that fits its nodes at once, preferring a loop of nodes of about their size, so that a
  /// loop that a refresh builds again moves its first nodes once instead of each time the buffer doubles.
  private func grown(adding count: Int, valuesByteCount: Int) -> NodeBuffer {
    let grown: NodeBuffer
    if let old = buffer {
      // the table and the values grow apart, since doubling the table each time the values grow would leave it mostly
      // empty, which a block doesn't take
      let childCount = old.count + count
      // the nodes' size comes from the bytes that they take, since the room for alignment would overstate small nodes
      let usedValuesByteCount = old.valuesByteCountInUse + valuesByteCount
      let valuesByteCount = old.roomOfChildren + valuesByteCount
      var childCapacity = childCount > old.childCapacity ? max(2 * old.childCapacity, childCount) : old.childCapacity
      var valuesByteCapacity = valuesByteCount > old.valuesByteCapacity ? max(2 * old.valuesByteCapacity, valuesByteCount) : old.valuesByteCapacity
      if let room = smallestRoom(fitting: childCount, valuesByteCount: valuesByteCount, usedValuesByteCount: usedValuesByteCount) {
        // an eighth more fits the loop when its list gets a little longer, and the jump stops at a number of times what
        // the nodes need now, so that a short loop doesn't grow to a long list's room
        childCapacity = min(room.childCount + room.childCount / 8, childCount * Constants.maximumGrowth)
        valuesByteCapacity = min(room.valuesByteCount + room.valuesByteCount / 8, valuesByteCount * Constants.maximumGrowth)
      }
      grown = NodeBuffer.make(capacity: childCapacity, valuesByteCount: valuesByteCapacity)
      old.moveChildren(into: grown)
    } else {
      grown = NodeBuffer.make(
        capacity: max(Constants.initialChildCapacity, count),
        valuesByteCount: max(Constants.initialValuesByteCapacity, valuesByteCount)
      )
    }
    buffer = grown
    return grown
  }

  private func pendingBuffer() -> NodeBuffer {
    guard let buffer else {
      preconditionFailure("a block's pending nodes are written once")
    }
    return buffer
  }

  // MARK: - Sizing

  /// Remembers the room of a loop that held all of the pending nodes, in place of a room within an eighth of it in children
  /// and in bytes, which is likely the same loop's, or else of the oldest room.
  private func remember(_ room: Room) {
    guard room.childCount > Constants.initialChildCapacity || room.valuesByteCount > Constants.initialValuesByteCapacity else {
      // a loop that fits a first buffer doesn't make a buffer grow
      return
    }
    // a loop of as many nodes of another size keeps a room of its own, since its next buffer needs other bytes
    if let index = rooms.firstIndex(where: {
      abs($0.childCount - room.childCount) * 8 <= room.childCount && abs($0.valuesByteCount - room.valuesByteCount) * 8 <= room.valuesByteCount
    }) {
      rooms.remove(at: index)
    } else if rooms.count == Constants.rememberedRoomCount {
      rooms.removeLast()
    }
    rooms.insert(room, at: 0)
  }

  /// Returns the remembered room with the fewest children that has room for a number of children and of bytes, among the
  /// rooms whose bytes per child are within an eighth of the nodes', or else among all the rooms.
  ///
  /// - Parameters:
  ///   - childCount: The number of children.
  ///   - valuesByteCount: The number of bytes that the children's values take at most.
  ///   - usedValuesByteCount: The number of bytes that the children's values take, which tells their size.
  private func smallestRoom(fitting childCount: Int, valuesByteCount: Int, usedValuesByteCount: Int) -> Room? {
    var smallestAlike: Room?
    var smallest: Room?
    for room in rooms where room.childCount >= childCount && room.valuesByteCount >= valuesByteCount {
      if abs(room.valuesByteCount * childCount - usedValuesByteCount * room.childCount) * 8 <= usedValuesByteCount * room.childCount,
         room.childCount < smallestAlike?.childCount ?? .max
      {
        smallestAlike = room
      }
      if room.childCount < smallest?.childCount ?? .max {
        smallest = room
      }
    }
    // a room of nodes of about the nodes' size comes first, since a loop of large nodes would otherwise grow to the room
    // of a loop of as many small nodes, which its first nodes fit in, and the smallest room comes next, since the first
    // nodes of a loop of uneven nodes don't tell the size of the rest
    return smallestAlike ?? smallest
  }

  /// Returns whether the thread keeps an empty buffer for its next loop.
  ///
  /// - Parameters:
  ///   - buffer: The empty buffer.
  ///   - loopFilledTooLittle: Whether the buffer was emptied by a loop that held all of it and filled too little of it.
  private func keepsEmpty(_ buffer: NodeBuffer, loopFilledTooLittle: Bool) -> Bool {
    if buffer.childCapacity <= Constants.smallChildCapacity, buffer.valuesByteCapacity <= Constants.smallValuesByteCapacity {
      // a small buffer costs little to keep, and serves the blocks and short loops that most content has
      return true
    } else if loopFilledTooLittle || !Thread.isMain {
      // a buffer that the loop that held all of it filled too little of goes, so that the loop's next buffer grows to
      // fit it, and a thread other than the main thread, which can stay alive without building again, keeps only a
      // small buffer
      return false
    } else {
      return buffer.childCapacity <= Constants.mainThreadChildCapacity && buffer.valuesByteCapacity <= Constants.mainThreadValuesByteCapacity
    }
  }

  /// The room that a loop's nodes take, in children and in bytes of values.
  private struct Room {

    let childCount: Int

    let valuesByteCount: Int
  }

  // MARK: - Constants

  private enum Constants {

    /// The number of children that a first buffer has room for.
    static let initialChildCapacity = 16

    /// The number of bytes that a first buffer's values have room for.
    static let initialValuesByteCapacity = 16 * 128

    /// The most times what its nodes need that a buffer grows to at once.
    static let maximumGrowth = 16

    /// The number of rooms of recent loops that the thread remembers.
    static let rememberedRoomCount = 4

    /// The most children that an empty buffer that any thread keeps has room for.
    static let smallChildCapacity = 256

    /// The most bytes of values that an empty buffer that any thread keeps has room for.
    static let smallValuesByteCapacity = 64 * 1024

    /// The most children that an empty buffer that the main thread keeps has room for.
    static let mainThreadChildCapacity = 4096

    /// The most bytes of values that an empty buffer that the main thread keeps has room for.
    static let mainThreadValuesByteCapacity = 1 << 20
  }
}

#if DEBUG
extension PendingNodes {

  /// The buffer of the calling thread's pending nodes, for the tests.
  static var debugBuffer: NodeBuffer? {
    current.buffer
  }

  /// Drops the buffer of the calling thread's pending nodes and forgets the rooms of its loops, for the tests.
  static func debugReset() {
    let nodes = current
    nodes.buffer = nil
    nodes.rooms = []
  }
}
#endif
