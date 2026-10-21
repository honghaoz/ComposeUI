//
//  PendingNodesTests.swift
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

import ChouTiTest

@testable import ComposeUI

class PendingNodesTests: XCTestCase {

  func test_current_isOneForEachThread() {
    // given: the main thread's pending nodes
    let main = PendingNodes.current

    // when: reading them again, and reading another thread's
    let again = PendingNodes.current
    let other = onNewThread { PendingNodes.current }

    // then: each thread keeps its own
    expect(again) === main
    expect(other) !== main
  }

  func test_reserve_outsideATask_returnsRoomInTheThreadsBuffer() {
    let observed = onNewThread { () -> (starts: [Int], sameBuffer: Bool, count: Int) in
      // when: reserving room for a node twice on a thread outside a task, appending a node each time
      let first = PendingNodes.reserve(count: 1, valuesByteCount: NodeBuffer.room(for: ByteNode.self))! // swiftlint:disable:this force_unwrapping
      first.buffer.append(ByteNode(flag: true))
      let second = PendingNodes.reserve(count: 1, valuesByteCount: NodeBuffer.room(for: ByteNode.self))! // swiftlint:disable:this force_unwrapping
      second.buffer.append(ByteNode(flag: false))
      return ([first.start, second.start], first.buffer === second.buffer && second.buffer === PendingNodes.debugBuffer, second.buffer.count)
    }

    // then: the nodes take the first two places of the thread's buffer
    expect(observed.starts) == [0, 1]
    expect(observed.sameBuffer) == true
    expect(observed.count) == 2
  }

  func test_reserve_inATask_returnsNil() async {
    // when: reserving room in this test's task and in a detached task
    let reserved = PendingNodes.reserve(count: 1, valuesByteCount: NodeBuffer.room(for: ByteNode.self))
    let reservedInDetachedTask = await Task.detached {
      PendingNodes.reserve(count: 1, valuesByteCount: NodeBuffer.room(for: ByteNode.self)) == nil
    }.value

    // then: neither gets room, so their blocks write into buffers of their own
    expect(reserved == nil) == true
    expect(reservedInDetachedTask) == true
  }

  func test_reserve_pastTheBuffersRoom_growsKeepingTheNodesAtTheirIndexes() {
    let observed = onNewThread { () -> (values: [Int], bufferCount: Int, kept: Bool) in
      // given: nodes that keep objects
      var objects = (0 ..< 40).map { _ in Token() }
      let weakObjects = objects.map { WeakToken(token: $0) }

      // when: appending more of them to the thread's pending nodes than a first buffer has room for
      var buffers: [NodeBuffer] = []
      var claims: [PendingNodes.Claim] = []
      for (index, object) in objects.enumerated() {
        let pending = PendingNodes.reserve(count: 1, valuesByteCount: NodeBuffer.room(for: TrackedNode.self))! // swiftlint:disable:this force_unwrapping
        pending.buffer.append(TrackedNode(token: object, value: index))
        if buffers.last !== pending.buffer {
          buffers.append(pending.buffer)
        }
        claims.append(pending.claim)
      }
      objects = []

      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping
      let values = (0 ..< buffer.count).map { index in buffer.withNode(at: index, as: TrackedNode.self) { $0.value } ?? -1 }
      return (values, buffers.count, weakObjects.allSatisfy { $0.token != nil })
    }

    // then: the buffer grows, which moves each node into the next buffer at its index, without destroying it
    expect(observed.values) == Array(0 ..< 40)
    expect(observed.bufferCount > 1) == true
    expect(observed.kept) == true
  }

  func test_reserve_pastTheRoomForValues_growsOnlyTheValues() {
    let observed = onNewThread { () -> (firstChildCapacity: Int, childCapacity: Int, valuesByteCapacity: Int, taken: Bool) in
      // given: the room for children of the thread's first buffer
      let first = PendingNodes.reserve(count: 1, valuesByteCount: NodeBuffer.room(for: HugeNode.self))! // swiftlint:disable:this force_unwrapping
      let firstChildCapacity = first.buffer.childCapacity
      first.buffer.append(HugeNode())

      // when: appending more nodes whose values each take more room than the first buffer has, as many as fill half of its
      // room for children
      let claims = [first.claim] + appendPending([HugeNode](repeating: HugeNode(), count: firstChildCapacity / 2 - 1))
      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping
      let taken = PendingNodes.current.takeAll(start: 0, count: claims.count) != nil

      return (firstChildCapacity, buffer.childCapacity, buffer.valuesByteCapacity, taken)
    }

    // then: the buffer grows its values to fit them, and keeps its room for children, so a block takes it
    expect(observed.childCapacity) == observed.firstChildCapacity
    expect(observed.valuesByteCapacity >= observed.firstChildCapacity / 2 * MemoryLayout<HugeNode>.stride) == true
    expect(observed.taken) == true
  }

  func test_reserve_pastTheRoomForChildren_growsOnlyTheChildren() {
    let observed = onNewThread { () -> (first: (children: Int, values: Int), grown: (children: Int, values: Int), count: Int) in
      // given: the room of the thread's first buffer
      let first = PendingNodes.reserve(count: 1, valuesByteCount: NodeBuffer.room(for: ByteNode.self))! // swiftlint:disable:this force_unwrapping
      let firstRoom = (children: first.buffer.childCapacity, values: first.buffer.valuesByteCapacity)
      first.buffer.append(ByteNode(flag: true))

      // when: appending one-byte nodes, one more than the first buffer has room for
      let claims = [first.claim] + appendPending([ByteNode](repeating: ByteNode(flag: true), count: firstRoom.children))
      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping

      return (firstRoom, (buffer.childCapacity, buffer.valuesByteCapacity), claims.count)
    }

    // then: the buffer grows its room for children, and keeps its room for values
    expect(observed.count) == observed.first.children + 1
    expect(observed.grown.children > observed.first.children) == true
    expect(observed.grown.values) == observed.first.values
  }

  func test_reserve_afterNodesThatNoContentRefersTo_destroysThem() {
    let observed = onNewThread { () -> (keptBefore: Bool, keptAfter: Bool, start: Int) in
      // given: nodes in the thread's pending nodes whose contents are gone, which a builder function that throws leaves
      var weakObjects: [WeakToken] = []
      var keptBefore = false
      do {
        let objects = [Token(), Token()]
        weakObjects = objects.map { WeakToken(token: $0) }
        let claims = appendPending([TrackedNode(token: objects[0], value: 0), TrackedNode(token: objects[1], value: 1)])
        keptBefore = claims.count == 2 && weakObjects.allSatisfy { $0.token != nil }
      }

      // when: reserving room for another node
      let pending = PendingNodes.reserve(count: 1, valuesByteCount: NodeBuffer.room(for: ByteNode.self))! // swiftlint:disable:this force_unwrapping

      return (keptBefore, weakObjects.contains { $0.token != nil }, pending.start)
    }

    // then: the nodes are destroyed, and the new node takes the first place
    expect(observed.keptBefore) == true
    expect(observed.keptAfter) == false
    expect(observed.start) == 0
  }

  func test_reserve_whileAContentRefersToTheNodes_keepsThem() {
    let observed = onNewThread { () -> (kept: Bool, start: Int) in
      // given: nodes in the thread's pending nodes whose contents are still around
      let objects = [Token(), Token()]
      let weakObjects = objects.map { WeakToken(token: $0) }
      let claims = appendPending([TrackedNode(token: objects[0], value: 0), TrackedNode(token: objects[1], value: 1)])

      // when: reserving room for another node
      let pending = PendingNodes.reserve(count: 1, valuesByteCount: NodeBuffer.room(for: ByteNode.self))! // swiftlint:disable:this force_unwrapping

      return (claims.count == 2 && weakObjects.allSatisfy { $0.token != nil }, pending.start)
    }

    // then: the nodes stay, and the new node takes the place after them
    expect(observed.kept) == true
    expect(observed.start) == 2
  }

  func test_takeAll_ofAllTheNodesFillingHalfTheRoom_takesTheBuffer() {
    let observed = onNewThread { () -> (fillsHalf: Bool, taken: Bool, left: Bool) in
      // given: wide nodes that fill half of a first buffer's room for children and for values
      let claims = appendPending([WideNode](repeating: WideNode(), count: 8))
      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping

      // when: taking all of them
      let taken = PendingNodes.current.takeAll(start: 0, count: claims.count)

      return (fillsHalf(buffer), taken === buffer, PendingNodes.debugBuffer == nil)
    }

    // then: the block takes the buffer, which leaves the thread without one
    expect(observed.fillsHalf) == true
    expect(observed.taken) == true
    expect(observed.left) == true
  }

  func test_takeAll_ofARangeAfterOtherNodes_leavesTheBuffer() {
    let observed = onNewThread { () -> (fillsHalf: Bool, taken: Bool, kept: Bool) in
      // given: wide nodes that fill half of a first buffer's room for children and for values
      let claims = appendPending([WideNode](repeating: WideNode(), count: 8))
      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping

      // when: taking all of them but the first
      let taken = PendingNodes.current.takeAll(start: 1, count: claims.count - 1)

      return (fillsHalf(buffer), taken != nil, PendingNodes.debugBuffer === buffer)
    }

    // then: the block doesn't take the buffer, whose first node belongs to another block
    expect(observed.fillsHalf) == true
    expect(observed.taken) == false
    expect(observed.kept) == true
  }

  func test_takeAll_ofSomeOfTheNodes_leavesTheBuffer() {
    let observed = onNewThread { () -> (fillsHalf: Bool, taken: Bool, kept: Bool) in
      // given: wide nodes that fill half of a first buffer's room for children and for values
      let claims = appendPending([WideNode](repeating: WideNode(), count: 8))
      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping

      // when: taking all of them but the last
      let taken = PendingNodes.current.takeAll(start: 0, count: claims.count - 1)

      return (fillsHalf(buffer), taken != nil, PendingNodes.debugBuffer === buffer)
    }

    // then: the block doesn't take the buffer, whose last node belongs to another block
    expect(observed.fillsHalf) == true
    expect(observed.taken) == false
    expect(observed.kept) == true
  }

  func test_takeAll_ofNodesFillingLessThanHalfTheRoomForChildren_leavesTheBuffer() {
    let observed = onNewThread { () -> (fillsHalfOfTheChildren: Bool, fillsHalfOfTheValues: Bool, taken: Bool, kept: Bool) in
      // given: two nodes whose values fill half of the buffer's room for values, and less of its room for children
      let claims = appendPending([HugeNode](repeating: HugeNode(), count: 2))
      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping

      // when: taking all of them
      let taken = PendingNodes.current.takeAll(start: 0, count: claims.count)

      return (
        buffer.count * 2 >= buffer.childCapacity,
        buffer.valuesByteCountInUse * 2 >= buffer.valuesByteCapacity,
        taken != nil,
        PendingNodes.debugBuffer === buffer
      )
    }

    // then: the block doesn't take the buffer, which would keep the room it doesn't use
    expect(observed.fillsHalfOfTheChildren) == false
    expect(observed.fillsHalfOfTheValues) == true
    expect(observed.taken) == false
    expect(observed.kept) == true
  }

  func test_takeAll_ofNodesFillingLessThanHalfTheRoomForValues_leavesTheBuffer() {
    let observed = onNewThread { () -> (fillsHalfOfTheChildren: Bool, fillsHalfOfTheValues: Bool, taken: Bool, kept: Bool) in
      // given: one-byte nodes that fill half of a first buffer's room for children, and less of its room for values
      let claims = appendPending([ByteNode](repeating: ByteNode(flag: true), count: 8))
      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping

      // when: taking all of them
      let taken = PendingNodes.current.takeAll(start: 0, count: claims.count)

      return (
        buffer.count * 2 >= buffer.childCapacity,
        buffer.valuesByteCountInUse * 2 >= buffer.valuesByteCapacity,
        taken != nil,
        PendingNodes.debugBuffer === buffer
      )
    }

    // then: the block doesn't take the buffer, which would keep the room it doesn't use
    expect(observed.fillsHalfOfTheChildren) == true
    expect(observed.fillsHalfOfTheValues) == false
    expect(observed.taken) == false
    expect(observed.kept) == true
  }

  func test_takeAll_remembersTheRoom_whichAGrowingBufferTakesAtOnce() {
    let observed = onNewThread { () -> (taken: (children: Int, values: Int), grown: (children: Int, values: Int), firstBuffers: Int) in
      // given: a buffer of many wide nodes that a block took
      var taken: (children: Int, values: Int) = (0, 0)
      do {
        let claims = appendPending([WideNode](repeating: WideNode(), count: 100))
        let buffer = PendingNodes.current.takeAll(start: 0, count: claims.count)
        taken = (buffer?.childCapacity ?? 0, buffer?.valuesByteCapacity ?? 0)
      }

      // when: appending more wide nodes than a first buffer has room for
      var buffers: [NodeBuffer] = []
      var claims: [PendingNodes.Claim] = []
      for _ in 0 ..< 17 {
        let pending = PendingNodes.reserve(count: 1, valuesByteCount: NodeBuffer.room(for: WideNode.self))! // swiftlint:disable:this force_unwrapping
        pending.buffer.append(WideNode())
        if buffers.last !== pending.buffer {
          buffers.append(pending.buffer)
        }
        claims.append(pending.claim)
      }

      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping
      return (taken, (buffer.childCapacity, buffer.valuesByteCapacity), buffers.count)
    }

    // then: the first buffer grows once, to the room of the buffer that the block took
    expect(observed.taken.children > 0) == true
    expect(observed.firstBuffers) == 2
    expect(observed.grown.children) == observed.taken.children
    expect(observed.grown.values) == observed.taken.values
  }

  func test_moveNodes_ofTheLastRange_dropsThePlacesOfTheMovedNodes() {
    let observed = onNewThread { () -> (countAfterFirst: Int, countAfterLast: Int?, moved: [Int64]) in
      // given: four nodes in the thread's pending nodes, and a buffer with room for them
      let claims = appendPending([
        PaddedNode(value: 0, flag: false),
        PaddedNode(value: 1, flag: false),
        PaddedNode(value: 2, flag: false),
        PaddedNode(value: 3, flag: false),
      ])
      let other = NodeBuffer.make(capacity: claims.count, valuesByteCount: PendingNodes.current.room(start: 0, count: claims.count))

      // when: moving the first two out
      PendingNodes.current.moveNodes(start: 0, count: 2, into: other)
      let countAfterFirst = PendingNodes.debugBuffer?.count ?? -1

      // when: moving the last two out
      PendingNodes.current.moveNodes(start: 2, count: 2, into: other)

      let moved = (0 ..< other.count).map { index in other.withNode(at: index, as: PaddedNode.self) { $0.value } ?? -1 }
      return (countAfterFirst, PendingNodes.debugBuffer?.count, moved)
    }

    // then: the first move keeps all four places, the last drops them all and keeps the empty buffer for the next loop
    expect(observed.countAfterFirst) == 4
    expect(observed.countAfterLast) == 0
    expect(observed.moved) == [0, 1, 2, 3]
  }

  func test_moveNodes_emptyingABufferWithMoreRoomForChildrenThanTheThreadKeeps_releasesIt() {
    let observed = onNewThread { () -> (childCapacity: Int, released: Bool) in
      // given: one-byte nodes in the thread's pending nodes, more than an empty buffer that the thread keeps has room for
      let claims = appendPending([ByteNode](repeating: ByteNode(flag: true), count: 5000))
      let childCapacity = PendingNodes.debugBuffer?.childCapacity ?? 0
      let other = NodeBuffer.make(capacity: claims.count, valuesByteCount: PendingNodes.current.room(start: 0, count: claims.count))

      // when: moving them all out
      PendingNodes.current.moveNodes(start: 0, count: claims.count, into: other)

      return (childCapacity, PendingNodes.debugBuffer == nil)
    }

    // then: the thread releases the empty buffer, instead of keeping it
    expect(observed.childCapacity >= 5000) == true
    expect(observed.released) == true
  }

  func test_moveNodes_emptyingABufferWithMoreRoomForValuesThanTheThreadKeeps_releasesIt() {
    let observed = onNewThread { () -> (childCapacity: Int, valuesByteCapacity: Int, released: Bool) in
      // given: few nodes in the thread's pending nodes whose values take more bytes than an empty buffer that the thread
      // keeps has room for
      let claims = appendPending([HugeNode](repeating: HugeNode(), count: 600))
      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping
      let other = NodeBuffer.make(capacity: claims.count, valuesByteCount: PendingNodes.current.room(start: 0, count: claims.count))

      // when: moving them all out
      PendingNodes.current.moveNodes(start: 0, count: claims.count, into: other)

      return (buffer.childCapacity, buffer.valuesByteCapacity, PendingNodes.debugBuffer == nil)
    }

    // then: the thread releases the empty buffer, instead of keeping it
    expect(observed.childCapacity <= 4096) == true
    expect(observed.valuesByteCapacity > 1 << 20) == true
    expect(observed.released) == true
  }

  func test_room_ofARange_isTheRoomOfTheNodesInTheBuffer() {
    let observed = onNewThread { () -> (room: Int, roomOfChildren: Int) in
      // given: nodes of different alignments in the thread's pending nodes
      let claims = appendPending([ByteNode(flag: true)]) + appendPending([PaddedNode(value: 1, flag: true)]) + appendPending([ByteNode(flag: false)])

      // when: reading the room of the last two
      let room = PendingNodes.current.room(start: 1, count: claims.count - 1)

      return (room, PendingNodes.debugBuffer?.roomOfChildren(from: 1, count: 2) ?? -1)
    }

    // then: it's the room that the buffer gives for those children
    expect(observed.room) == observed.roomOfChildren
  }

  func test_threadExit_releasesItsPendingNodes() {
    // given: nodes that a thread leaves in its pending nodes
    let weakObjects = onNewThread { () -> [WeakToken] in
      let objects = [Token(), Token()]
      _ = appendPending([TrackedNode(token: objects[0], value: 0), TrackedNode(token: objects[1], value: 1)])
      return objects.map { WeakToken(token: $0) }
    }

    // then: the thread released its pending nodes when it exited, which destroyed the nodes
    expect(weakObjects.count) == 2
    expect(weakObjects.allSatisfy { $0.token == nil }) == true
  }
}

// MARK: - Helpers

/// Appends nodes to the calling thread's pending nodes, as blocks of one node do, and returns the claims that their
/// contents keep.
private func appendPending<N: ComposeNode>(_ nodes: [N]) -> [PendingNodes.Claim] {
  var claims: [PendingNodes.Claim] = []
  for node in nodes {
    let pending = PendingNodes.reserve(count: 1, valuesByteCount: NodeBuffer.room(for: N.self))! // swiftlint:disable:this force_unwrapping
    pending.buffer.append(node)
    claims.append(pending.claim)
  }
  return claims
}

/// Returns whether a buffer's children fill at least half of its room for children and for values.
private func fillsHalf(_ buffer: NodeBuffer) -> Bool {
  buffer.count * 2 >= buffer.childCapacity && buffer.valuesByteCountInUse * 2 >= buffer.valuesByteCapacity
}

// MARK: - Test Nodes

/// A node of one byte, whose id isn't stored.
private struct ByteNode: ComposeNode {

  var flag: Bool

  var id: ComposeNodeId {
    get { .custom("byte") }
    set {} // swiftlint:disable:this unused_setter_value
  }

  var size: CGSize {
    .zero
  }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {}
}

/// A node with tail padding: its size is smaller than its stride, and its id isn't stored.
private struct PaddedNode: ComposeNode {

  var value: Int64

  var flag: Bool

  var id: ComposeNodeId {
    get { .custom("padded") }
    set {} // swiftlint:disable:this unused_setter_value
  }

  var size: CGSize {
    .zero
  }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {}
}

/// A node of 128 bytes, whose id isn't stored.
private struct WideNode: ComposeNode {

  var value = SIMD16<Int64>()

  var id: ComposeNodeId {
    get { .custom("wide") }
    set {} // swiftlint:disable:this unused_setter_value
  }

  var size: CGSize {
    .zero
  }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {}
}

/// A node of 2048 bytes, whose id isn't stored.
private struct HugeNode: ComposeNode {

  var values = (SIMD64<Int64>(), SIMD64<Int64>(), SIMD64<Int64>(), SIMD64<Int64>())

  var id: ComposeNodeId {
    get { .custom("huge") }
    set {} // swiftlint:disable:this unused_setter_value
  }

  var size: CGSize {
    .zero
  }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {}
}

/// An object that a test node keeps, to tell when the node is destroyed.
private final class Token {}

private struct WeakToken {

  weak var token: Token?
}

/// A node that keeps an object.
private struct TrackedNode: ComposeNode {

  let token: Token

  var value: Int

  var id: ComposeNodeId = .custom("tracked")

  var size: CGSize {
    .zero
  }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {}
}
