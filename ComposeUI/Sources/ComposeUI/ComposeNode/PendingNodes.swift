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
/// by their indexes until it's written, on the thread that built it.
///
/// Content built in a task doesn't use the pending nodes. A builder function that throws leaves the nodes it wrote,
/// which the pending nodes destroy once no content refers to them.
@usableFromInline
final class PendingNodes {

  /// An object that the content of pending nodes keeps, whose references tell whether a content refers to pending nodes.
  @usableFromInline
  final class Claim {}

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
  /// in place.
  private var claim = Claim()

  /// The number of children that the buffer that a block took last had room for, which a growing buffer grows to at
  /// once, since a refresh builds the same content again.
  private var takenChildCapacity = 0

  /// The number of bytes that the values of the buffer that a block took last had room for.
  private var takenValuesByteCapacity = 0

  private init() {}

  /// Returns the number of bytes that a range of the pending nodes' values take at most in another buffer.
  ///
  /// - Parameters:
  ///   - start: The index of the first node.
  ///   - count: The number of nodes.
  /// - Returns: The number of bytes.
  func room(start: Int, count: Int) -> Int {
    pendingBuffer().roomOfChildren(from: start, count: count)
  }

  /// Takes the buffer of the pending nodes when a range holds all of them and at least half of the buffer's room for
  /// children and for values, leaving no buffer for the next nodes.
  ///
  /// - Parameters:
  ///   - start: The index of the first node.
  ///   - count: The number of nodes.
  /// - Returns: The buffer, or `nil` when the range doesn't qualify, whose block moves the nodes out instead.
  func takeAll(start: Int, count: Int) -> NodeBuffer? {
    let buffer = pendingBuffer()
    guard start == 0,
          count == buffer.count,
          count * 2 >= buffer.childCapacity,
          buffer.valuesByteCountInUse * 2 >= buffer.valuesByteCapacity
    else {
      return nil
    }
    takenChildCapacity = min(buffer.childCapacity, Constants.maximumChildCapacity)
    takenValuesByteCapacity = min(buffer.valuesByteCapacity, Constants.maximumValuesByteCapacity)
    self.buffer = nil
    return buffer
  }

  /// Moves a range of the pending nodes into a buffer, and drops the places of the moved nodes at the end of the pending
  /// nodes.
  ///
  /// - Parameters:
  ///   - start: The index of the first node.
  ///   - count: The number of nodes.
  ///   - other: The buffer, whose room the nodes must fit in.
  func moveNodes(start: Int, count: Int, into other: NodeBuffer) {
    let buffer = pendingBuffer()
    precondition(start >= 0 && count >= 0 && start + count <= buffer.count, "a block's pending nodes are written once")
    buffer.moveChildren(from: start, count: count, into: other)
    // a block moves its ranges in order, after the blocks in it moved theirs, so its last range is at the end, and
    // moving it drops the places of all the block's nodes, down to any nodes left by a builder function that threw
    buffer.dropMovedChildren()
    if buffer.count == 0,
       buffer.childCapacity > Constants.maximumChildCapacity || buffer.valuesByteCapacity > Constants.maximumValuesByteCapacity
    {
      // an empty buffer is kept for the next loop, which a refresh builds again, unless it's larger than the thread keeps
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
  /// A first buffer is small, and a buffer that grows grows to the room of the buffer that a block took last at once,
  /// so that a block of one node doesn't make a large buffer, and a loop that a refresh builds again moves its first
  /// nodes once instead of each time the buffer doubles.
  private func grown(adding count: Int, valuesByteCount: Int) -> NodeBuffer {
    let grown: NodeBuffer
    if let old = buffer {
      // the table and the values grow apart, since doubling the table each time the values grow would leave it mostly
      // empty, which a block doesn't take
      let childCount = old.count + count
      let valuesByteCount = old.roomOfChildren + valuesByteCount
      let childCapacity = childCount > old.childCapacity ? max(2 * old.childCapacity, childCount) : old.childCapacity
      let valuesByteCapacity = valuesByteCount > old.valuesByteCapacity ? max(2 * old.valuesByteCapacity, valuesByteCount) : old.valuesByteCapacity
      grown = NodeBuffer.make(
        capacity: max(childCapacity, takenChildCapacity),
        valuesByteCount: max(valuesByteCapacity, takenValuesByteCapacity)
      )
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

  // MARK: - Constants

  private enum Constants {

    /// The number of children that a first buffer has room for.
    static let initialChildCapacity = 16

    /// The number of bytes that a first buffer's values have room for.
    static let initialValuesByteCapacity = 16 * 128

    /// The most children that a buffer grows to at once, and that an empty buffer the thread keeps has room for.
    static let maximumChildCapacity = 4096

    /// The most bytes that a buffer's values grow to at once, and that an empty buffer the thread keeps has room for.
    static let maximumValuesByteCapacity = 1 << 20
  }
}

#if DEBUG
extension PendingNodes {

  /// The buffer of the calling thread's pending nodes, for the tests.
  static var debugBuffer: NodeBuffer? {
    current.buffer
  }
}
#endif
