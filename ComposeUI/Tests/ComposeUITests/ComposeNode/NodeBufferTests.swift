//
//  NodeBufferTests.swift
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

class NodeBufferTests: XCTestCase {

  func test_append_keepsEachChildWithItsType() {
    // given: a buffer with room for a color, a label and a spacer
    let buffer = NodeBuffer.make(
      capacity: 3,
      valuesByteCount: NodeBuffer.room(for: ColorNode.self) + NodeBuffer.room(for: LabelNode.self) + NodeBuffer.room(for: SpacerNode.self)
    )

    // when: appending them
    buffer.append(ColorNode(.red))
    buffer.append(LabelNode("Hello"))
    buffer.append(SpacerNode())

    // then: the buffer keeps each child in order, of its own type
    expect(buffer.count) == 3
    expect(type(of: buffer.node(at: 0)) == ColorNode.self) == true
    expect(type(of: buffer.node(at: 1)) == LabelNode.self) == true
    expect(type(of: buffer.node(at: 2)) == SpacerNode.self) == true
    expect(buffer.withNode(at: 1, as: LabelNode.self) { _ in true }) == true
    expect(buffer.withNode(at: 1, as: ColorNode.self) { _ in true }) == nil
  }

  func test_append_alignsEachValue() {
    // given: a buffer with room for one-byte nodes and 16-byte aligned nodes in turn
    expect(MemoryLayout<AlignedNode>.alignment) == 16
    let buffer = NodeBuffer.make(
      capacity: 4,
      valuesByteCount: 2 * NodeBuffer.room(for: ByteNode.self) + 2 * NodeBuffer.room(for: AlignedNode.self)
    )

    // when: appending them
    buffer.append(ByteNode(flag: true))
    buffer.append(AlignedNode(value: SIMD2(1, 2)))
    buffer.append(ByteNode(flag: false))
    buffer.append(AlignedNode(value: SIMD2(3, 4)))

    // then: each value is at its type's alignment and keeps its value
    for (index, value) in [(1, SIMD2<Double>(1, 2)), (3, SIMD2<Double>(3, 4))] {
      let alignment = buffer.withNode(at: index, as: AlignedNode.self) { node in
        withUnsafeMutablePointer(to: &node) { Int(bitPattern: $0) % 16 }
      }
      expect(alignment) == 0
      expect(buffer.withNode(at: index, as: AlignedNode.self) { $0.value }) == value
    }
    expect(buffer.withNode(at: 0, as: ByteNode.self) { $0.flag }) == true
    expect(buffer.withNode(at: 2, as: ByteNode.self) { $0.flag }) == false
  }

  func test_room_isTheStrideWithTheAlignment() {
    // then: a value's room is its stride and the bytes that aligning it can skip
    expect(NodeBuffer.room(for: AlignedNode.self)) == MemoryLayout<AlignedNode>.stride + 15
    expect(NodeBuffer.room(for: PaddedNode.self)) == MemoryLayout<PaddedNode>.stride + 7
    expect(NodeBuffer.room(for: ByteNode.self)) == MemoryLayout<ByteNode>.stride
  }

  func test_append_startsEachValueAfterThePreviousValuesStride() {
    // given: a buffer with room for a node with tail padding and a one-byte node
    expect(MemoryLayout<PaddedNode>.size) < MemoryLayout<PaddedNode>.stride
    let buffer = NodeBuffer.make(
      capacity: 2,
      valuesByteCount: NodeBuffer.room(for: PaddedNode.self) + NodeBuffer.room(for: ByteNode.self)
    )

    // when: appending the node with tail padding, then the one-byte node
    buffer.append(PaddedNode(value: 1, flag: true))
    buffer.append(ByteNode(flag: true))

    // then: the one-byte node starts after the other node's stride, outside the memory bound to its type
    let paddedAddress = buffer.withNode(at: 0, as: PaddedNode.self) { node in
      withUnsafeMutablePointer(to: &node) { Int(bitPattern: $0) }
    }
    let byteAddress = buffer.withNode(at: 1, as: ByteNode.self) { node in
      withUnsafeMutablePointer(to: &node) { Int(bitPattern: $0) }
    }
    expect(try (byteAddress.unwrap() - paddedAddress.unwrap())) >= MemoryLayout<PaddedNode>.stride
    expect(buffer.withNode(at: 0, as: PaddedNode.self) { $0.value }) == 1
    expect(buffer.withNode(at: 1, as: ByteNode.self) { $0.flag }) == true
  }

  func test_make_fromNodes_copiesThemInOrder() {
    // given: nodes of different types
    let nodes: [any ComposeNode] = [LabelNode("A"), ColorNode(.blue), AlignedNode(value: SIMD2(5, 6))]

    // when: making a buffer of them
    let buffer = NodeBuffer.make(nodes)

    // then: the buffer has copies of them in order
    expect(buffer.count) == 3
    expect(type(of: buffer.node(at: 0)) == LabelNode.self) == true
    expect(type(of: buffer.node(at: 1)) == ColorNode.self) == true
    expect(buffer.withNode(at: 2, as: AlignedNode.self) { $0.value }) == SIMD2(5, 6)
  }

  func test_children_layOutSizeAndRenderAsTheNodesDo() {
    // given: a label and a framed color, and a buffer of copies of them
    let label = LabelNode("Hello")
    let color = ColorNode(.red).frame(width: 20, height: 10)
    let buffer = NodeBuffer.make([label, color])
    var nodes: [any ComposeNode] = [label, color]
    let containerSize = CGSize(width: 100, height: 100)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)

    for index in 0 ..< 2 {
      // when: laying out the child in the buffer and the node itself, and rendering both
      let sizing = buffer.layout(at: index, containerSize: containerSize, context: context)
      let nodeSizing = nodes[index].layout(containerSize: containerSize, context: context)
      var items: [RenderableItem] = []
      buffer.render(at: index, visibleBounds: CGRect(origin: .zero, size: containerSize), into: &items)
      let nodeItems = nodes[index].renderableItems(in: CGRect(origin: .zero, size: containerSize))

      // then: the child lays out, sizes and renders as the node does
      expect(sizing) == nodeSizing
      expect(buffer.size(at: index)) == nodes[index].size
      expect(buffer.renderableItemsBounds(at: index)) == nodes[index].renderableItemsBounds
      expect(items.map(\.id)) == nodeItems.map(\.id)
      expect(items.map(\.frame)) == nodeItems.map(\.frame)
      expect(items.isEmpty) == false
    }
  }

  func test_appendContentsOf_copiesTheChildrenAfterAnUnalignedValue() {
    // given: a buffer of a 16-byte aligned node and a one-byte node, whose last byte needs the room for alignment, and a
    // buffer with room for a one-byte node and copies of them
    let source = NodeBuffer.make([AlignedNode(value: SIMD2(1, 2)), ByteNode(flag: false)])
    let buffer = NodeBuffer.make(capacity: 3, valuesByteCount: NodeBuffer.room(for: ByteNode.self) + source.roomOfChildren)
    buffer.append(ByteNode(flag: true))

    // when: appending copies of the source's children after the one-byte node
    buffer.append(contentsOf: source)

    // then: the copies fit and keep their values, and the source keeps its children
    expect(buffer.count) == 3
    expect(buffer.withNode(at: 1, as: AlignedNode.self) { $0.value }) == SIMD2(1, 2)
    expect(buffer.withNode(at: 2, as: ByteNode.self) { $0.flag }) == false
    expect(source.count) == 2
    expect(source.withNode(at: 1, as: ByteNode.self) { $0.flag }) == false
  }

  func test_moveChildren_movesThemAndEmptiesTheBuffer() {
    // given: a buffer with nodes that keep objects, and a buffer with room for them
    var objects: [Token]? = [Token(), Token()]
    let weakObjects = objects!.map { WeakToken(token: $0) } // swiftlint:disable:this force_unwrapping
    // the nodes are an array literal, since a map into `[any ComposeNode]` in this module changes how the optimizer
    // compiles the benchmarks' arrays of rows, which then box each row again
    var source: NodeBuffer? = NodeBuffer.make([
      TrackedNode(token: objects![0], value: 0), // swiftlint:disable:this force_unwrapping
      TrackedNode(token: objects![1], value: 0), // swiftlint:disable:this force_unwrapping
    ])
    objects = nil
    var buffer: NodeBuffer? = NodeBuffer.make(capacity: 2, valuesByteCount: source!.roomOfChildren) // swiftlint:disable:this force_unwrapping

    // when: moving the children
    source?.moveChildren(into: buffer!) // swiftlint:disable:this force_unwrapping

    // then: the other buffer has them, and the source is empty
    expect(buffer?.count) == 2
    expect(source?.count) == 0

    // when: releasing the source
    source = nil

    // then: the moved children keep their objects
    expect(weakObjects.allSatisfy { $0.token != nil }) == true

    // when: releasing the other buffer
    buffer = nil

    // then: the children are destroyed, which releases their objects
    expect(weakObjects.allSatisfy { $0.token == nil }) == true
  }

  func test_moveChildrenFromRange_movesTheRangeAndKeepsTheOtherChildren() {
    // given: a buffer with nodes that keep objects, and a buffer with room for the middle two
    var objects: [Token]? = [Token(), Token(), Token(), Token()]
    let weakObjects = objects!.map { WeakToken(token: $0) } // swiftlint:disable:this force_unwrapping
    var source: NodeBuffer? = NodeBuffer.make([
      TrackedNode(token: objects![0], value: 0), // swiftlint:disable:this force_unwrapping
      TrackedNode(token: objects![1], value: 1), // swiftlint:disable:this force_unwrapping
      TrackedNode(token: objects![2], value: 2), // swiftlint:disable:this force_unwrapping
      TrackedNode(token: objects![3], value: 3), // swiftlint:disable:this force_unwrapping
    ])
    objects = nil
    var other: NodeBuffer? = NodeBuffer.make(capacity: 2, valuesByteCount: source!.roomOfChildren(from: 1, count: 2)) // swiftlint:disable:this force_unwrapping

    // when: moving the middle two children
    source?.moveChildren(from: 1, count: 2, into: other!) // swiftlint:disable:this force_unwrapping

    // then: the other buffer has them in order, and the source keeps its other children in their places
    expect(other?.count) == 2
    expect(other?.withNode(at: 0, as: TrackedNode.self) { $0.value }) == 1
    expect(other?.withNode(at: 1, as: TrackedNode.self) { $0.value }) == 2
    expect(source?.count) == 4
    expect(source?.withNode(at: 0, as: TrackedNode.self) { $0.value }) == 0
    expect(source?.withNode(at: 1, as: TrackedNode.self) { $0.value }) == nil
    expect(source?.withNode(at: 2, as: TrackedNode.self) { $0.value }) == nil
    expect(source?.withNode(at: 3, as: TrackedNode.self) { $0.value }) == 3

    // when: releasing the source
    source = nil

    // then: its children in place are destroyed, while the moved children keep their objects
    expect(weakObjects.map { $0.token != nil }) == [false, true, true, false]

    // when: releasing the other buffer
    other = nil

    // then: the moved children are destroyed too
    expect(weakObjects.allSatisfy { $0.token == nil }) == true
  }

  func test_moveChildrenFromRange_leavesAnEmptyChildInEachPlace() {
    // given: a buffer with a label, and a buffer with room for it
    let source = NodeBuffer.make([LabelNode("Hello")])
    let other = NodeBuffer.make(capacity: 1, valuesByteCount: source.roomOfChildren)

    // when: moving the label
    source.moveChildren(from: 0, count: 1, into: other)

    // then: its place holds a child that has no size, lays out to no size, renders nothing and keeps the empty id
    var items: [RenderableItem] = []
    source.render(at: 0, visibleBounds: CGRect(x: 0, y: 0, width: 100, height: 100), into: &items)
    expect(items.count) == 0
    let sizing = source.layout(at: 0, containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
    expect(sizing) == ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
    expect(source.size(at: 0)) == .zero
    var node = source.node(at: 0)
    node.id = .custom("other")
    expect(node.id) == .standard(.empty)
    expect(other.withNode(at: 0, as: LabelNode.self) { _ in true }) == true
  }

  func test_moveChildrenFromRange_ofAMovedChild_asserts() {
    // given: a buffer whose child is moved out, and a test assertion failure handler
    let source = NodeBuffer.make([ByteNode(flag: true)])
    let other = NodeBuffer.make(capacity: 2, valuesByteCount: 2 * NodeBuffer.room(for: ByteNode.self))
    source.moveChildren(from: 0, count: 1, into: other)
    var messages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      messages.append(message)
    }

    // when: moving the child out again, which no caller does
    source.moveChildren(from: 0, count: 1, into: other)

    // then: it asserts
    expect(messages) == ["a child is moved out once"]

    Assert.resetTestAssertionFailureHandler()
  }

  func test_dropMovedChildren_dropsThePlacesOfTheMovedChildrenAtTheEnd() {
    // given: a buffer of four nodes with tail padding, whose last two are moved out, and the bytes the first two take
    let source = NodeBuffer.make(capacity: 4, valuesByteCount: 4 * NodeBuffer.room(for: PaddedNode.self))
    source.append(PaddedNode(value: 0, flag: false))
    source.append(PaddedNode(value: 1, flag: false))
    let bytesOfTwo = source.valuesByteCountInUse
    source.append(PaddedNode(value: 2, flag: false))
    source.append(PaddedNode(value: 3, flag: false))
    let other = NodeBuffer.make(capacity: 2, valuesByteCount: source.roomOfChildren(from: 2, count: 2))
    source.moveChildren(from: 2, count: 2, into: other)

    // when: dropping the places of the moved children at the end
    source.dropMovedChildren()

    // then: the buffer keeps the first two, and its next value starts where the third did
    expect(source.count) == 2
    expect(source.valuesByteCountInUse) == bytesOfTwo
    expect(source.withNode(at: 1, as: PaddedNode.self) { $0.value }) == 1

    // when: appending a node
    source.append(PaddedNode(value: 4, flag: true))

    // then: it takes the third place
    expect(source.count) == 3
    expect(source.withNode(at: 2, as: PaddedNode.self) { $0.value }) == 4
  }

  func test_dropMovedChildren_keepsThePlacesBelowAChildInPlace() {
    // given: a buffer of three nodes, whose first two are moved out
    let source = NodeBuffer.make([ByteNode(flag: true), ByteNode(flag: false), ByteNode(flag: true)])
    let other = NodeBuffer.make(capacity: 3, valuesByteCount: source.roomOfChildren)
    source.moveChildren(from: 0, count: 2, into: other)

    // when: dropping the places of the moved children at the end
    source.dropMovedChildren()

    // then: the child in place at the end keeps all three places
    expect(source.count) == 3

    // when: moving the last child out and dropping the places again
    source.moveChildren(from: 2, count: 1, into: other)
    source.dropMovedChildren()

    // then: all the places are dropped
    expect(source.count) == 0
    expect(source.valuesByteCountInUse) == 0
    expect(other.count) == 3
  }

  func test_dropMovedChildren_withoutMovedChildren_keepsTheChildren() {
    // given: a buffer of two nodes, and an empty buffer
    let buffer = NodeBuffer.make([ByteNode(flag: true), ByteNode(flag: false)])
    let empty = NodeBuffer.make(capacity: 1, valuesByteCount: 1)

    // when: dropping the places of moved children at the end
    buffer.dropMovedChildren()
    empty.dropMovedChildren()

    // then: both keep their children
    expect(buffer.count) == 2
    expect(empty.count) == 0
  }

  func test_moveChildren_carriesThePlacesOfMovedChildren() {
    // given: a buffer of three nodes whose first is moved out, and a buffer with room for all three
    let source = NodeBuffer.make([PaddedNode(value: 0, flag: false), PaddedNode(value: 1, flag: false), PaddedNode(value: 2, flag: false)])
    let moved = NodeBuffer.make(capacity: 1, valuesByteCount: source.roomOfChildren(from: 0, count: 1))
    source.moveChildren(from: 0, count: 1, into: moved)
    let other = NodeBuffer.make(capacity: 3, valuesByteCount: source.roomOfChildren)

    // when: moving all the children into the other buffer
    source.moveChildren(into: other)

    // then: the other buffer keeps each child at its index, with the moved child's place empty
    expect(other.count) == 3
    expect(other.withNode(at: 0, as: PaddedNode.self) { $0.value }) == nil
    expect(other.withNode(at: 1, as: PaddedNode.self) { $0.value }) == 1
    expect(other.withNode(at: 2, as: PaddedNode.self) { $0.value }) == 2

    // when: moving the other two out and dropping the places of the moved children
    let rest = NodeBuffer.make(capacity: 2, valuesByteCount: other.roomOfChildren(from: 1, count: 2))
    other.moveChildren(from: 1, count: 2, into: rest)
    other.dropMovedChildren()

    // then: the carried place is dropped too
    expect(other.count) == 0
  }

  func test_roomOfChildren_ofARange_boundsTheBytesTheRangeTakesAfterAnyOffset() {
    // given: a buffer of one-byte and 16-byte aligned nodes in turn
    let source = NodeBuffer.make(
      capacity: 4,
      valuesByteCount: 2 * NodeBuffer.room(for: ByteNode.self) + 2 * NodeBuffer.room(for: AlignedNode.self)
    )
    source.append(ByteNode(flag: true))
    source.append(AlignedNode(value: SIMD2(1, 2)))
    source.append(ByteNode(flag: false))
    source.append(AlignedNode(value: SIMD2(3, 4)))

    for (start, count) in [(0, 4), (1, 2), (1, 3), (2, 2), (3, 1), (4, 0)] {
      let room = source.roomOfChildren(from: start, count: count)
      for offset in 0 ..< 16 {
        // when: moving a copy of the range after a number of one-byte nodes, into a buffer with only the range's room left
        let other = NodeBuffer.make(capacity: offset + count, valuesByteCount: offset + room)
        for _ in 0 ..< offset {
          other.append(ByteNode(flag: true))
        }
        let bytesBefore = other.valuesByteCountInUse
        source.copy().moveChildren(from: start, count: count, into: other)

        // then: the range takes at most its room
        expect(other.count) == offset + count
        expect(other.valuesByteCountInUse - bytesBefore <= room) == true
      }
    }
  }

  func test_capacities_tellTheRoomAndTheBytesInUse() {
    // given: a buffer with room for two nodes with tail padding
    let room = 2 * NodeBuffer.room(for: PaddedNode.self)
    let buffer = NodeBuffer.make(capacity: 2, valuesByteCount: room)

    // then: it has room for two children and for the values, rounded up to its chunks, none of which are in use
    expect(buffer.childCapacity) == 2
    expect(buffer.valuesByteCapacity >= room) == true
    expect(buffer.valuesByteCapacity < room + MemoryLayout<NodeBuffer.Chunk>.stride) == true
    expect(buffer.valuesByteCountInUse) == 0

    // when: appending a node
    buffer.append(PaddedNode(value: 1, flag: true))

    // then: its stride is in use
    expect(buffer.valuesByteCountInUse) == MemoryLayout<PaddedNode>.stride
  }

  func test_withNode_changesTheChildInPlace() {
    // given: a buffer with a node
    let buffer = NodeBuffer.make([ByteNode(flag: false)])

    // when: changing the node in place
    buffer.withNode(at: 0, as: ByteNode.self) { $0.flag = true }

    // then: the buffer's child is changed
    expect(buffer.withNode(at: 0, as: ByteNode.self) { $0.flag }) == true
  }

  func test_makeUnique_copiesASharedBuffer() {
    // given: a buffer with a node that keeps an object, shared by two holders
    var object: Token? = Token()
    weak var weakObject: Token?
    weakObject = object
    var holder: NodeBuffer? = NodeBuffer.make([TrackedNode(token: object!, value: 1)]) // swiftlint:disable:this force_unwrapping
    var otherHolder = holder! // swiftlint:disable:this force_unwrapping
    object = nil

    // when: making the other holder's buffer unique, and changing its child
    NodeBuffer.makeUnique(&otherHolder)
    otherHolder.withNode(at: 0, as: TrackedNode.self) { $0.value = 2 }

    // then: the other holder has a copy, whose change leaves the first holder's child
    expect(otherHolder) !== holder
    expect(holder?.withNode(at: 0, as: TrackedNode.self) { $0.value }) == 1
    expect(otherHolder.withNode(at: 0, as: TrackedNode.self) { $0.value }) == 2

    // when: releasing the first holder's buffer
    holder = nil

    // then: the copy still keeps the object
    expect(weakObject) != nil

    // when: releasing the copy
    otherHolder = NodeBuffer.make(capacity: 0, valuesByteCount: 0)

    // then: the object is released, so each child was destroyed
    expect(weakObject) == nil
  }

  func test_makeUnique_keepsAUniqueBuffer() {
    // given: a buffer with one holder
    var buffer = NodeBuffer.make([ByteNode(flag: true)])
    let identifier = ObjectIdentifier(buffer)

    // when: making it unique
    NodeBuffer.makeUnique(&buffer)

    // then: the holder keeps the same buffer
    expect(ObjectIdentifier(buffer)) == identifier
  }

  func test_deinit_destroysEachChild() {
    // given: a buffer with nodes that each keep an object
    var objects: [Token]? = [Token(), Token(), Token()]
    let weakObjects = objects!.map { WeakToken(token: $0) } // swiftlint:disable:this force_unwrapping
    // the nodes are an array literal, since a map into `[any ComposeNode]` in this module changes how the optimizer
    // compiles the benchmarks' arrays of rows, which then box each row again
    var buffer: NodeBuffer? = NodeBuffer.make([
      TrackedNode(token: objects![0], value: 0), // swiftlint:disable:this force_unwrapping
      TrackedNode(token: objects![1], value: 0), // swiftlint:disable:this force_unwrapping
      TrackedNode(token: objects![2], value: 0), // swiftlint:disable:this force_unwrapping
    ])
    objects = nil

    // then: the buffer keeps the objects
    expect(weakObjects.allSatisfy { $0.token != nil }) == true

    // when: releasing the buffer
    buffer = nil

    // then: each child is destroyed, which releases its object
    expect(buffer) == nil
    expect(weakObjects.allSatisfy { $0.token == nil }) == true
  }

  func test_deinit_runOfOneTypeRightBeforeAnotherType_destroysEachChild() {
    // given: a buffer with two 8-byte nodes that keep objects, a node of another type right after them, which keeps its
    // object after a number instead of in its first 8 bytes, where an 8-byte node keeps its object, and another 8-byte
    // node that keeps an object
    var objects: [Token]? = [Token(), Token(), Token(), Token()]
    let weakObjects = objects!.map { WeakToken(token: $0) } // swiftlint:disable:this force_unwrapping
    var buffer: NodeBuffer? = NodeBuffer.make(
      capacity: 4,
      valuesByteCount: 3 * NodeBuffer.room(for: TokenNode.self) + NodeBuffer.room(for: NumberAndTokenNode.self)
    )
    buffer?.append(TokenNode(token: objects![0])) // swiftlint:disable:this force_unwrapping
    buffer?.append(TokenNode(token: objects![1])) // swiftlint:disable:this force_unwrapping
    buffer?.append(NumberAndTokenNode(number: 0, token: objects![2])) // swiftlint:disable:this force_unwrapping
    buffer?.append(TokenNode(token: objects![3])) // swiftlint:disable:this force_unwrapping
    objects = nil
    expect(buffer?.valuesByteCountInUse) == 40

    // when: releasing the buffer
    buffer = nil

    // then: each node is destroyed, which releases its object
    expect(weakObjects.map { $0.token == nil }) == [true, true, true, true]
  }

  func test_deinit_childOfTheSameTypePastTheStride_destroysEachChild() {
    // given: a buffer with an 8-byte node that keeps an object, then a 16-byte aligned node, which is moved out and whose
    // place is dropped, and another 8-byte node that keeps an object, which takes that place, 16 bytes after the first
    // node instead of one stride after it
    var objects: [Token]? = [Token(), Token()]
    let weakObjects = objects!.map { WeakToken(token: $0) } // swiftlint:disable:this force_unwrapping
    var buffer: NodeBuffer? = NodeBuffer.make(
      capacity: 2,
      valuesByteCount: NodeBuffer.room(for: TokenNode.self) + NodeBuffer.room(for: AlignedNode.self)
    )
    buffer?.append(TokenNode(token: objects![0])) // swiftlint:disable:this force_unwrapping
    buffer?.append(AlignedNode(value: SIMD2(1, 2)))
    buffer?.moveChildren(from: 1, count: 1, into: NodeBuffer.make(capacity: 1, valuesByteCount: NodeBuffer.room(for: AlignedNode.self)))
    buffer?.dropMovedChildren()
    buffer?.append(TokenNode(token: objects![1])) // swiftlint:disable:this force_unwrapping
    objects = nil
    expect(MemoryLayout<TokenNode>.stride) == 8
    expect(buffer?.valuesByteCountInUse) == 24

    // when: releasing the buffer
    buffer = nil

    // then: each node is destroyed, which releases its object
    expect(weakObjects.allSatisfy { $0.token == nil }) == true
  }

  func test_copy_ofAPartlyFilledBuffer_keepsEachValueAligned() {
    // given: a buffer with room for three children, holding a one-byte node and a 16-byte aligned node
    let buffer = NodeBuffer.make(
      capacity: 3,
      valuesByteCount: 3 * NodeBuffer.room(for: AlignedNode.self)
    )
    buffer.append(ByteNode(flag: true))
    buffer.append(AlignedNode(value: SIMD2(7, 8)))

    // when: copying it, which makes room for only the two children
    let copy = buffer.copy()

    // then: the copy's values start at another offset, and each value is at its alignment and keeps its value
    expect(copy.count) == 2
    let alignment = copy.withNode(at: 1, as: AlignedNode.self) { node in
      withUnsafeMutablePointer(to: &node) { Int(bitPattern: $0) % 16 }
    }
    expect(alignment) == 0
    expect(copy.withNode(at: 0, as: ByteNode.self) { $0.flag }) == true
    expect(copy.withNode(at: 1, as: AlignedNode.self) { $0.value }) == SIMD2(7, 8)
  }

  func test_make_withoutNodes_sharesTheEmptyBuffer() {
    // when: making a buffer of no nodes
    let buffer = NodeBuffer.make([])

    // then: it's the shared empty buffer
    expect(buffer) === NodeBuffer.empty
    expect(buffer.count) == 0
  }

  func test_makeUnique_keepsTheSharedEmptyBuffer() {
    // given: the shared empty buffer, which other holders share
    var buffer = NodeBuffer.empty

    // when: making it unique
    NodeBuffer.makeUnique(&buffer)

    // then: the holder keeps the shared buffer, since it has no child to change
    expect(buffer) === NodeBuffer.empty
  }

  func test_roomOfChildren_withoutChildren_isZero() {
    // given: a buffer of a node, and a buffer whose node is moved out
    let buffer = NodeBuffer.make([ByteNode(flag: true)])
    let emptied = NodeBuffer.make([ByteNode(flag: false)])
    emptied.moveChildren(into: NodeBuffer.make(capacity: 1, valuesByteCount: emptied.roomOfChildren))

    // then: the shared empty buffer and the emptied buffer take no room in another buffer, while the node takes some
    expect(NodeBuffer.empty.roomOfChildren) == 0
    expect(emptied.roomOfChildren) == 0
    expect(buffer.roomOfChildren >= NodeBuffer.room(for: ByteNode.self)) == true
  }

  func test_nodes_returnsTheChildrenInOrder() {
    // given: a buffer of nodes of different types
    let buffer = NodeBuffer.make([LabelNode("A").id("a"), ColorNode(.blue).id("b")])

    // when: reading its nodes
    let nodes = buffer.nodes

    // then: each child is in its place, with its type
    expect(nodes.count) == 2
    expect(nodes[0] is LabelNode) == true
    expect(nodes[1] is ColorNode) == true
    expect(nodes.map(\.id.id)) == ["a", "b"]
  }

  func test_emptyBuffer() {
    // given: a buffer with no room
    var buffer = NodeBuffer.make(capacity: 0, valuesByteCount: 0)

    // then: it has no children, and its copy has none
    expect(buffer.count) == 0
    expect(buffer.copy().count) == 0

    // when: making it unique
    NodeBuffer.makeUnique(&buffer)

    // then: it still has no children
    expect(buffer.count) == 0
  }
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

/// A node whose value is 16-byte aligned.
private struct AlignedNode: ComposeNode {

  let value: SIMD2<Double>

  var id: ComposeNodeId = .custom("aligned")

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

/// A node that keeps only an object, so that its value takes 8 bytes, and whose id isn't stored.
private struct TokenNode: ComposeNode {

  let token: Token

  var id: ComposeNodeId {
    get { .custom("token") }
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

/// A node that keeps an object after a number, and whose id isn't stored.
private struct NumberAndTokenNode: ComposeNode {

  let number: Int

  let token: Token

  var id: ComposeNodeId {
    get { .custom("numberAndToken") }
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
