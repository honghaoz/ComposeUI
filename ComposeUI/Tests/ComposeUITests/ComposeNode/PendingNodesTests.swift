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

      // when: appending more nodes whose values each take more room than the first buffer has, as many as fill its room
      // for children
      let claims = [first.claim] + appendPending([HugeNode](repeating: HugeNode(), count: firstChildCapacity - 1))
      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping
      let taken = PendingNodes.current.contentBuffer(start: 0, count: claims.count) === buffer

      return (firstChildCapacity, buffer.childCapacity, buffer.valuesByteCapacity, taken)
    }

    // then: the buffer grows its values to fit them, and keeps its room for children, so a block takes it
    expect(observed.childCapacity) == observed.firstChildCapacity
    expect(observed.valuesByteCapacity >= observed.firstChildCapacity * MemoryLayout<HugeNode>.stride) == true
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

  func test_contentBuffer_ofAllTheNodesFillingThreeQuartersOfTheRoom_isTheirBuffer() {
    let observed = onNewThread { () -> (fillsThreeQuarters: Bool, taken: Bool, left: Bool) in
      // given: wide nodes that fill three quarters of a first buffer's room for children and for values
      let claims = appendPending([WideNode](repeating: WideNode(), count: 12))
      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping
      let fills = fillsThreeQuarters(buffer)

      // when: reading the buffer of a content of all of them
      let contentBuffer = PendingNodes.current.contentBuffer(start: 0, count: claims.count)

      return (fills, contentBuffer === buffer, PendingNodes.debugBuffer == nil)
    }

    // then: the content takes their buffer, which leaves the thread without one
    expect(observed.fillsThreeQuarters) == true
    expect(observed.taken) == true
    expect(observed.left) == true
  }

  func test_contentBuffer_ofARangeAfterOtherNodes_movesTheNodesIntoABufferOfTheirOwn() {
    let observed = onNewThread { () -> (fillsThreeQuarters: Bool, taken: Bool, movedCount: Int, leftCount: Int?) in
      // given: 13 wide nodes, the last 12 of which fill three quarters of a first buffer's room for children and for
      // values
      let claims = appendPending([WideNode](repeating: WideNode(), count: 13))
      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping
      let fills = fillsThreeQuarters(buffer, start: 1, count: 12)

      // when: reading the buffer of a content of all of them but the first
      let contentBuffer = PendingNodes.current.contentBuffer(start: 1, count: claims.count - 1)

      return (fills, contentBuffer === buffer, contentBuffer.count, PendingNodes.debugBuffer === buffer ? buffer.count : nil)
    }

    // then: the nodes move into a buffer of their own, since the first node in their buffer belongs to another block,
    // which keeps its place
    expect(observed.fillsThreeQuarters) == true
    expect(observed.taken) == false
    expect(observed.movedCount) == 12
    expect(observed.leftCount) == 1
  }

  func test_contentBuffer_ofSomeOfTheNodes_movesTheNodesIntoABufferOfTheirOwn() {
    let observed = onNewThread { () -> (fillsThreeQuarters: Bool, taken: Bool, movedCount: Int, leftCount: Int?) in
      // given: 13 wide nodes, the first 12 of which fill three quarters of a first buffer's room for children and for
      // values
      let claims = appendPending([WideNode](repeating: WideNode(), count: 13))
      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping
      let fills = fillsThreeQuarters(buffer, start: 0, count: 12)

      // when: reading the buffer of a content of all of them but the last
      let contentBuffer = PendingNodes.current.contentBuffer(start: 0, count: claims.count - 1)

      return (fills, contentBuffer === buffer, contentBuffer.count, PendingNodes.debugBuffer === buffer ? buffer.count : nil)
    }

    // then: the nodes move into a buffer of their own, since the last node in their buffer belongs to another block,
    // which keeps its place above the places of the moved nodes
    expect(observed.fillsThreeQuarters) == true
    expect(observed.taken) == false
    expect(observed.movedCount) == 12
    expect(observed.leftCount) == 13
  }

  func test_contentBuffer_ofAllTheNodesFillingLessThanThreeQuartersOfTheRoomForChildren_movesTheNodesIntoABufferOfTheirOwn() {
    let observed = onNewThread { () -> (fillsTheChildren: Bool, fillsTheValues: Bool, taken: Bool, movedCount: Int) in
      // given: four nodes whose values fill three quarters of the buffer's room for values, and less of its room for
      // children
      let claims = appendPending([HugeNode](repeating: HugeNode(), count: 4))
      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping
      let fillsTheChildren = buffer.count * 4 >= buffer.childCapacity * 3
      let fillsTheValues = buffer.valuesByteCountInUse * 4 >= buffer.valuesByteCapacity * 3

      // when: reading the buffer of a content of all of them
      let contentBuffer = PendingNodes.current.contentBuffer(start: 0, count: claims.count)

      return (fillsTheChildren, fillsTheValues, contentBuffer === buffer, contentBuffer.count)
    }

    // then: the nodes move into a buffer of their own, since a stack that took their buffer would keep the room that
    // they don't use
    expect(observed.fillsTheChildren) == false
    expect(observed.fillsTheValues) == true
    expect(observed.taken) == false
    expect(observed.movedCount) == 4
  }

  func test_contentBuffer_ofAllTheNodesFillingLessThanThreeQuartersOfTheRoomForValues_movesTheNodesIntoABufferOfTheirOwn() {
    let observed = onNewThread { () -> (fillsTheChildren: Bool, fillsTheValues: Bool, taken: Bool, movedCount: Int) in
      // given: one-byte nodes that fill three quarters of a first buffer's room for children, and less of its room for
      // values
      let claims = appendPending([ByteNode](repeating: ByteNode(flag: true), count: 12))
      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping
      let fillsTheChildren = buffer.count * 4 >= buffer.childCapacity * 3
      let fillsTheValues = buffer.valuesByteCountInUse * 4 >= buffer.valuesByteCapacity * 3

      // when: reading the buffer of a content of all of them
      let contentBuffer = PendingNodes.current.contentBuffer(start: 0, count: claims.count)

      return (fillsTheChildren, fillsTheValues, contentBuffer === buffer, contentBuffer.count)
    }

    // then: the nodes move into a buffer of their own, since a stack that took their buffer would keep the room that
    // they don't use
    expect(observed.fillsTheChildren) == true
    expect(observed.fillsTheValues) == false
    expect(observed.taken) == false
    expect(observed.movedCount) == 12
  }

  func test_contentBuffer_ofAllTheNodes_remembersTheirRoom_whichAGrowingBufferGrowsToAtOnce() {
    let observed = onNewThread { () -> (taken: Bool, grown: (children: Int, values: Int), bufferCount: Int) in
      // given: a loop of 100 wide nodes, whose content took their buffer
      let taken = buildLoop([WideNode](repeating: WideNode(), count: 100))

      // when: appending more wide nodes than a first buffer has room for
      let (claims, bufferCount) = appendPendingCountingBuffers([WideNode](repeating: WideNode(), count: 17))

      let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping
      return (taken && claims.count == 17, (buffer.childCapacity, buffer.valuesByteCapacity), bufferCount)
    }

    // then: the first buffer grows once, to the room that the 100 nodes took and an eighth more
    expect(observed.taken) == true
    expect(observed.bufferCount) == 2
    expect(observed.grown.children) == 100 + 100 / 8
    expect(observed.grown.values) == 100 * MemoryLayout<WideNode>.stride * 9 / 8
  }

  func test_contentBuffer_ofAllTheNodesFillingTooLittle_remembersTheirRoomToo() {
    let observed = onNewThread { () -> (taken: Bool, grownChildCapacity: Int) in
      // given: a loop of 300 one-byte nodes, whose content didn't take their buffer, since their values fill too little
      // of it
      let taken = buildLoop([ByteNode](repeating: ByteNode(flag: true), count: 300))

      // when: appending more one-byte nodes than the room for children that the first growth reaches
      let (claims, _) = appendPendingCountingBuffers([ByteNode](repeating: ByteNode(flag: true), count: 273))

      return (taken, claims.count == 273 ? PendingNodes.debugBuffer?.childCapacity ?? 0 : 0)
    }

    // then: the buffer grows to the room that the 300 nodes took and an eighth more
    expect(observed.taken) == false
    expect(observed.grownChildCapacity) == 300 + 300 / 8
  }

  func test_contentBuffer_ofAFewNodes_keepsTheRememberedRoomsOfLongerLoops() {
    let observed = onNewThread { () -> Int in
      // given: the room of a loop of 300 one-byte nodes, which the thread remembers, and then loops of one to five
      // nodes, more loops of different lengths than the thread remembers rooms
      buildLoop([ByteNode](repeating: ByteNode(flag: true), count: 300))
      for count in 1 ... 5 {
        buildLoop([ByteNode](repeating: ByteNode(flag: true), count: count))
      }

      // when: appending more nodes than the room for children that the first growth reaches
      let (claims, _) = appendPendingCountingBuffers([ByteNode](repeating: ByteNode(flag: true), count: 273))

      return claims.count == 273 ? PendingNodes.debugBuffer?.childCapacity ?? 0 : 0
    }

    // then: the buffer grows to the room of 300 nodes and an eighth more, since a loop whose nodes fit a first buffer
    // leaves no room in place of a longer loop's
    expect(observed) == 300 + 300 / 8
  }

  func test_grown_toARememberedRoom_growsAtMostSixteenTimesWhatTheNodesNeed() {
    let observed = onNewThread { () -> Int in
      // given: the room of a loop of 1,000 one-byte nodes, which the thread remembers
      buildLoop([ByteNode](repeating: ByteNode(flag: true), count: 1000))

      // when: appending one more node than a first buffer has room for
      let (claims, _) = appendPendingCountingBuffers([ByteNode](repeating: ByteNode(flag: true), count: 17))

      return claims.count == 17 ? PendingNodes.debugBuffer?.childCapacity ?? 0 : 0
    }

    // then: the buffer grows to sixteen times the 17 nodes that it needs room for, instead of the remembered room
    expect(observed) == 17 * 16
  }

  func test_grown_choosesTheSmallestRememberedRoomThatFits_ofTheFourNewest() {
    let observed = onNewThread { () -> Int in
      // given: the rooms of loops of 300, 400, 500, 600 and 700 one-byte nodes, which the thread remembers, the four newest
      for count in [300, 400, 500, 600, 700] {
        buildLoop([ByteNode](repeating: ByteNode(flag: true), count: count))
      }

      // when: appending more nodes than the room for children that the first growth reaches
      let (claims, _) = appendPendingCountingBuffers([ByteNode](repeating: ByteNode(flag: true), count: 273))

      return claims.count == 273 ? PendingNodes.debugBuffer?.childCapacity ?? 0 : 0
    }

    // then: the buffer grows to the room of 400 nodes and an eighth more, since the room of 300 nodes was the oldest
    expect(observed) == 400 + 400 / 8
  }

  func test_grown_pastARememberedRoomWithTooFewBytes_doublesInstead() {
    let observed = onNewThread { () -> (count: Int, childCapacity: Int, valuesByteCapacity: Int) in
      // given: the room of a loop of 300 one-byte nodes, which the thread remembers
      buildLoop([ByteNode](repeating: ByteNode(flag: true), count: 300))

      // when: appending more wide nodes than a first buffer has room for, whose values take more bytes than the room has
      let (claims, _) = appendPendingCountingBuffers([WideNode](repeating: WideNode(), count: 17))

      let buffer = PendingNodes.debugBuffer
      return (claims.count, buffer?.childCapacity ?? 0, buffer?.valuesByteCapacity ?? 0)
    }

    // then: the first buffer doubles, instead of growing to the remembered room, which doesn't fit the nodes' values
    expect(observed.count) == 17
    expect(observed.childCapacity) == 2 * 16
    expect(observed.valuesByteCapacity) == 2 * 16 * MemoryLayout<WideNode>.stride
  }

  func test_grown_pastARememberedRoomWithTooFewChildren_doublesInstead() {
    let observed = onNewThread { () -> (count: Int, childCapacity: Int, valuesByteCapacity: Int, keptValuesByteCapacity: Int) in
      // given: the room of a loop of four huge nodes, which the thread remembers, since their values take more bytes
      // than a first buffer has, and the small empty buffer that the thread keeps after it
      buildLoop([HugeNode](repeating: HugeNode(), count: 4))
      let keptValuesByteCapacity = PendingNodes.debugBuffer?.valuesByteCapacity ?? 0

      // when: appending more one-byte nodes than the buffer has room for, more than the room has children for
      let (claims, _) = appendPendingCountingBuffers([ByteNode](repeating: ByteNode(flag: true), count: 17))

      let buffer = PendingNodes.debugBuffer
      return (claims.count, buffer?.childCapacity ?? 0, buffer?.valuesByteCapacity ?? 0, keptValuesByteCapacity)
    }

    // then: the buffer doubles its room for children and keeps its room for values, instead of growing to the
    // remembered room, which doesn't fit the nodes
    expect(observed.count) == 17
    expect(observed.childCapacity) == 2 * 16
    expect(observed.valuesByteCapacity) == observed.keptValuesByteCapacity
  }

  func test_contentBuffer_ofLoopsOfOneCountAndDifferentSizesInTurn_takesEachLoopsBuffer() {
    let observed = onNewThread { () -> [Bool] in
      // given: a thread that builds a loop of 200 wide nodes and a loop of 200 padded nodes in turn, as a screen of two
      // lists does on each refresh
      for _ in 0 ..< 2 {
        buildLoop([WideNode](repeating: WideNode(), count: 200))
        buildLoop([PaddedNode](repeating: PaddedNode(value: 0, flag: false), count: 200))
      }

      // when: building both loops in turn again
      return [
        buildLoop([WideNode](repeating: WideNode(), count: 200)),
        buildLoop([PaddedNode](repeating: PaddedNode(value: 0, flag: false), count: 200)),
      ]
    }

    // then: each loop fills a buffer that grew to its own room, which its content takes
    expect(observed) == [true, true]
  }

  func test_contentBuffer_ofAShortLoopAfterALongLoopOfNodesOfAboutTheirSize_takesItsBuffer() {
    let observed = onNewThread { () -> Bool in
      // given: the rooms of a loop of 2,000 wide and padded nodes in turn and of a loop of 300 such nodes and then 10
      // one-byte nodes, whose bytes per child differ a little
      buildMixedLoop(rowCount: 2000)
      buildMixedLoop(rowCount: 300, byteNodeCount: 10)

      // when: building the short loop again
      return buildMixedLoop(rowCount: 300, byteNodeCount: 10)
    }

    // then: the short loop fills a buffer that grew to its own room, which its content takes, instead of the long loop's
    // room, which its first nodes' bytes per child are closer to
    expect(observed) == true
  }

  func test_grown_ofSmallNodes_growsAtOnceToTheirRememberedRoom() {
    let observed = onNewThread { () -> Int in
      // given: the room of a loop of 300 one-byte nodes
      buildLoop([ByteNode](repeating: ByteNode(flag: true), count: 300))

      // when: appending 100 one-byte nodes
      let (claims, bufferCount) = appendPendingCountingBuffers([ByteNode](repeating: ByteNode(flag: true), count: 100))

      return claims.count == 100 ? bufferCount : 0
    }

    // then: the first buffer grows once, to the room of the one-byte nodes, though the room for alignment of its values
    // is larger than the bytes that they take
    expect(observed) == 2
  }

  func test_grown_withoutARememberedRoomOfNodesOfAboutTheirSize_doubles() {
    let observed = onNewThread { () -> (childCapacity: Int, bufferCount: Int) in
      // given: the room of a loop of 300 padded nodes, which take more bytes than one-byte nodes
      buildLoop([PaddedNode](repeating: PaddedNode(value: 0, flag: false), count: 300))

      // when: appending 100 one-byte nodes
      let (claims, bufferCount) = appendPendingCountingBuffers([ByteNode](repeating: ByteNode(flag: true), count: 100))

      return claims.count == 100 ? (PendingNodes.debugBuffer?.childCapacity ?? 0, bufferCount) : (0, 0)
    }

    // then: the buffer doubles each time it fills, from 16 children to 128, instead of growing to the padded nodes' room,
    // which isn't a loop of nodes of their size
    expect(observed.childCapacity) == 128
    expect(observed.bufferCount) == 4
  }

  func test_grown_amongRememberedRoomsOfAsManyChildren_growsToTheRoomOfNodesOfTheirSize() {
    let observed = onNewThread { () -> (childCapacity: Int, valuesByteCapacity: Int) in
      // given: the rooms of loops of 300 one-byte nodes and then 300 padded nodes, which have as many children and more
      // bytes
      buildLoop([ByteNode](repeating: ByteNode(flag: true), count: 300))
      buildLoop([PaddedNode](repeating: PaddedNode(value: 0, flag: false), count: 300))

      // when: appending more one-byte nodes than the room for children that the first growth reaches
      let (claims, _) = appendPendingCountingBuffers([ByteNode](repeating: ByteNode(flag: true), count: 273))

      let buffer = PendingNodes.debugBuffer
      return claims.count == 273 ? (buffer?.childCapacity ?? 0, buffer?.valuesByteCapacity ?? 0) : (0, 0)
    }

    // then: the buffer grows to the room of the one-byte nodes and an eighth more, instead of to the padded nodes' bytes
    expect(observed.childCapacity) == 300 + 300 / 8
    expect(observed.valuesByteCapacity) == NodeBuffer.make(capacity: 300 + 300 / 8, valuesByteCount: 300 + 300 / 8).valuesByteCapacity
  }

  func test_grown_amongRememberedRoomsOfAsManyChildren_growsOnceToTheRoomOfNodesOfTheirSize() {
    let observed = onNewThread { () -> Int in
      // given: the rooms of loops of 300 wide nodes, 300 one-byte nodes and then 300 padded nodes, which have as many
      // children and other bytes per child
      buildLoop([WideNode](repeating: WideNode(), count: 300))
      buildLoop([ByteNode](repeating: ByteNode(flag: true), count: 300))
      buildLoop([PaddedNode](repeating: PaddedNode(value: 0, flag: false), count: 300))

      // when: appending more wide nodes than a first buffer has room for
      let (claims, bufferCount) = appendPendingCountingBuffers([WideNode](repeating: WideNode(), count: 60))

      return claims.count == 60 ? bufferCount : 0
    }

    // then: the first buffer grows once, to the room of the wide nodes, instead of first to the padded nodes' room, which
    // the first wide nodes fit in
    expect(observed) == 2
  }

  func test_remember_aRoomWithinAnEighthOfAnother_replacesIt() {
    let observed = onNewThread { () -> Int in
      // given: the rooms of loops of 300 and then 330 one-byte nodes, which is within an eighth of 300
      for count in [300, 330] {
        buildLoop([ByteNode](repeating: ByteNode(flag: true), count: count))
      }

      // when: appending more nodes than the room for children that the first growth reaches
      let (claims, _) = appendPendingCountingBuffers([ByteNode](repeating: ByteNode(flag: true), count: 273))

      return claims.count == 273 ? PendingNodes.debugBuffer?.childCapacity ?? 0 : 0
    }

    // then: the buffer grows to the room of 330 nodes and an eighth more, since that room replaced the room of 300
    expect(observed) == 330 + 330 / 8
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

    // then: the first move keeps all four places, the last drops them all and keeps the small empty buffer for the next
    // loop
    expect(observed.countAfterFirst) == 4
    expect(observed.countAfterLast) == 0
    expect(observed.moved) == [0, 1, 2, 3]
  }

  func test_contentBuffer_ofAllTheNodesFillingTooLittleOfASmallBuffer_keepsTheBuffer() {
    let observed = onNewThread { () -> (taken: Bool, kept: Bool) in
      // given: eight wide nodes in the thread's pending nodes, which fill half of a first buffer
      let claims = appendPending([WideNode](repeating: WideNode(), count: 8))
      let buffer = PendingNodes.debugBuffer

      // when: reading the buffer of a content of all of them
      let contentBuffer = PendingNodes.current.contentBuffer(start: 0, count: claims.count)

      return (contentBuffer === buffer, PendingNodes.debugBuffer === buffer && buffer?.count == 0)
    }

    // then: the nodes move into a buffer of their own, and the thread keeps the small empty buffer, which costs little
    // to keep
    expect(observed.taken) == false
    expect(observed.kept) == true
  }

  func test_moveNodes_emptyingALargeBufferOnTheMainThread_keepsIt() {
    // given: 300 one-byte nodes in the main thread's pending nodes, whose buffer has more room than a small one
    PendingNodes.debugReset()
    let claims = appendPending([ByteNode](repeating: ByteNode(flag: true), count: 300))
    let childCapacity = PendingNodes.debugBuffer?.childCapacity ?? 0

    // when: moving them all out
    moveAllPending(keeping: claims)

    // then: the main thread keeps the empty buffer for its next loop
    expect(childCapacity > 256) == true
    expect(PendingNodes.debugBuffer?.count) == 0

    PendingNodes.debugReset()
  }

  func test_contentBuffer_ofAllTheNodesFillingTooLittleOfALargeBufferOnTheMainThread_releasesTheBuffer() {
    // given: 300 one-byte nodes in the main thread's pending nodes, whose values fill too little of their buffer
    PendingNodes.debugReset()
    let claims = appendPending([ByteNode](repeating: ByteNode(flag: true), count: 300))
    let buffer = PendingNodes.debugBuffer

    // when: reading the buffer of a content of all of them
    let contentBuffer = PendingNodes.current.contentBuffer(start: 0, count: claims.count)

    // then: the nodes move into a buffer of their own, and the empty buffer goes, so that the loop's next buffer grows
    // to fit them
    expect(contentBuffer === buffer) == false
    expect(contentBuffer.count) == 300
    expect(PendingNodes.debugBuffer) == nil

    // when: building the loop again
    let taken = buildLoop([ByteNode](repeating: ByteNode(flag: true), count: 300))

    // then: its nodes fill the buffer that grew to their room, which their content takes
    expect(taken) == true

    PendingNodes.debugReset()
  }

  func test_contentBuffer_ofTheLastRangeEmptyingALargeBufferOnTheMainThread_keepsTheBuffer() {
    // given: 300 one-byte nodes in the main thread's pending nodes, whose buffer has more room than a small one, the
    // first half of which moved into a buffer of their own
    PendingNodes.debugReset()
    let claims = appendPending([ByteNode](repeating: ByteNode(flag: true), count: 300))
    let buffer = PendingNodes.debugBuffer
    let firstHalf = PendingNodes.current.contentBuffer(start: 0, count: 150)

    // when: reading the buffer of a content of the second half, which empties the pending nodes
    let secondHalf = PendingNodes.current.contentBuffer(start: 150, count: claims.count - 150)

    // then: the main thread keeps the empty buffer for its next loop, since neither range held all of the nodes, which
    // makes neither a loop that filled too little of the buffer
    expect(firstHalf.count) == 150
    expect(secondHalf.count) == 150
    expect((buffer?.childCapacity ?? 0) > 256) == true
    expect(PendingNodes.debugBuffer === buffer) == true
    expect(buffer?.count) == 0

    PendingNodes.debugReset()
  }

  func test_contentBuffer_ofASingleNodeEmptyingALargeBufferOnTheMainThread_keepsTheBuffer() {
    // given: the main thread's large empty buffer, which a loop of 300 one-byte nodes left, with one node in it
    PendingNodes.debugReset()
    moveAllPending(keeping: appendPending([ByteNode](repeating: ByteNode(flag: true), count: 300)))
    let buffer = PendingNodes.debugBuffer
    let claims = appendPending([ByteNode(flag: true)])

    // when: reading the buffer of a content of the node, as a stack of one child does
    let contentBuffer = PendingNodes.current.contentBuffer(start: 0, count: claims.count)

    // then: the node moves into a buffer of its own, and the main thread keeps the large buffer for its next loop, since
    // a single node isn't a loop whose room the buffer should fit
    expect(contentBuffer.count) == 1
    expect((buffer?.childCapacity ?? 0) > 256) == true
    expect(PendingNodes.debugBuffer === buffer) == true
    expect(buffer?.count) == 0

    PendingNodes.debugReset()
  }

  func test_moveNodes_emptyingABufferPastTheMainThreadsLimits_releasesIt() {
    // given: more one-byte nodes in the main thread's pending nodes than an empty buffer that it keeps has room for
    PendingNodes.debugReset()
    let byteClaims = appendPending([ByteNode](repeating: ByteNode(flag: true), count: 5000))
    let childCapacity = PendingNodes.debugBuffer?.childCapacity ?? 0

    // when: moving them all out
    moveAllPending(keeping: byteClaims)

    // then: the main thread releases the empty buffer, instead of keeping it
    expect(childCapacity > 4096) == true
    expect(PendingNodes.debugBuffer) == nil

    // given: few nodes whose values take more bytes than an empty buffer that the main thread keeps has room for
    let hugeClaims = appendPending([HugeNode](repeating: HugeNode(), count: 600))
    let buffer = PendingNodes.debugBuffer! // swiftlint:disable:this force_unwrapping

    // when: moving them all out
    moveAllPending(keeping: hugeClaims)

    // then: the main thread releases the empty buffer
    expect(buffer.childCapacity <= 4096) == true
    expect(buffer.valuesByteCapacity > 1 << 20) == true
    expect(PendingNodes.debugBuffer) == nil

    PendingNodes.debugReset()
  }

  func test_moveNodes_emptyingALargeBufferOffTheMainThread_releasesIt() {
    let observed = onNewThread { () -> (childCapacity: Int, released: Bool) in
      // given: 300 one-byte nodes in another thread's pending nodes, whose buffer has more room than a small one
      let claims = appendPending([ByteNode](repeating: ByteNode(flag: true), count: 300))
      let childCapacity = PendingNodes.debugBuffer?.childCapacity ?? 0

      // when: moving them all out
      moveAllPending(keeping: claims)

      return (childCapacity, PendingNodes.debugBuffer == nil)
    }

    // then: the thread releases the empty buffer, since a thread other than the main thread keeps only a small one
    expect(observed.childCapacity > 256) == true
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
private func appendPending(_ nodes: [some ComposeNode]) -> [PendingNodes.Claim] {
  appendPendingCountingBuffers(nodes).claims
}

/// Appends nodes to the calling thread's pending nodes, as blocks of one node do, and returns the claims that their
/// contents keep and the number of buffers that the nodes were appended to.
private func appendPendingCountingBuffers<N: ComposeNode>(_ nodes: [N]) -> (claims: [PendingNodes.Claim], bufferCount: Int) {
  var claims: [PendingNodes.Claim] = []
  var buffers: [NodeBuffer] = []
  for node in nodes {
    let pending = PendingNodes.reserve(count: 1, valuesByteCount: NodeBuffer.room(for: N.self))! // swiftlint:disable:this force_unwrapping
    pending.buffer.append(node)
    if buffers.last !== pending.buffer {
      buffers.append(pending.buffer)
    }
    claims.append(pending.claim)
  }
  return (claims, buffers.count)
}

/// Appends nodes to the calling thread's pending nodes and reads the buffer of a content of all of them, as a stack that
/// holds a loop of blocks of one node does, and returns whether the content took the pending nodes' buffer.
@discardableResult
private func buildLoop(_ nodes: [some ComposeNode]) -> Bool {
  let claims = appendPending(nodes)
  let buffer = PendingNodes.debugBuffer
  return PendingNodes.current.contentBuffer(start: 0, count: claims.count) === buffer
}

/// Appends wide and padded nodes in turn and then one-byte nodes to the calling thread's pending nodes, as a loop of rows
/// of two kinds and then of a few small rows does, reads the buffer of a content of all of them, and returns whether the
/// content took the pending nodes' buffer.
@discardableResult
private func buildMixedLoop(rowCount: Int, byteNodeCount: Int = 0) -> Bool {
  var claims: [PendingNodes.Claim] = []
  for index in 0 ..< rowCount {
    claims += index.isMultiple(of: 2) ? appendPending([WideNode()]) : appendPending([PaddedNode(value: 0, flag: false)])
  }
  claims += appendPending([ByteNode](repeating: ByteNode(flag: true), count: byteNodeCount))
  let buffer = PendingNodes.debugBuffer
  return PendingNodes.current.contentBuffer(start: 0, count: claims.count) === buffer
}

/// Moves all of the calling thread's pending nodes out, as the block that holds them does, while their contents keep
/// their claims.
private func moveAllPending(keeping claims: [PendingNodes.Claim] = []) {
  withExtendedLifetime(claims) {
    let count = PendingNodes.debugBuffer?.count ?? 0
    let other = NodeBuffer.make(capacity: count, valuesByteCount: count > 0 ? PendingNodes.current.room(start: 0, count: count) : 0)
    if count > 0 {
      PendingNodes.current.moveNodes(start: 0, count: count, into: other)
    }
  }
}

/// Returns whether a buffer's children fill at least three quarters of its room for children and for values.
private func fillsThreeQuarters(_ buffer: NodeBuffer) -> Bool {
  buffer.count * 4 >= buffer.childCapacity * 3 && buffer.valuesByteCountInUse * 4 >= buffer.valuesByteCapacity * 3
}

/// Returns whether a range of a buffer's children fills at least three quarters of the buffer's room for children and
/// for values.
private func fillsThreeQuarters(_ buffer: NodeBuffer, start: Int, count: Int) -> Bool {
  count * 4 >= buffer.childCapacity * 3 && buffer.roomOfChildren(from: start, count: count) * 4 >= buffer.valuesByteCapacity * 3
}

// MARK: - Test Nodes

/// A node of one byte, whose id isn't stored.
private struct ByteNode: ComposeNode {

  let flag: Bool

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

  let value: Int64

  let flag: Bool

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

  let value = SIMD16<Int64>()

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

  let values = (SIMD64<Int64>(), SIMD64<Int64>(), SIMD64<Int64>(), SIMD64<Int64>())

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

  let value: Int

  var id: ComposeNodeId = .custom("tracked")

  var size: CGSize {
    .zero
  }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {}
}
