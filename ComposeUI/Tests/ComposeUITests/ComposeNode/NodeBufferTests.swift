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

  func test_room_isTheSizeWithTheAlignment() {
    // then: a value's room is its size and the bytes that aligning it can skip
    expect(NodeBuffer.room(for: AlignedNode.self)) == MemoryLayout<AlignedNode>.size + 15
    expect(NodeBuffer.room(for: ByteNode.self)) == MemoryLayout<ByteNode>.size
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
      expect(buffer.renderableItemsBoundingRect(at: index)) == nodes[index].renderableItemsBoundingRect
      expect(items.map(\.id)) == nodeItems.map(\.id)
      expect(items.map(\.frame)) == nodeItems.map(\.frame)
      expect(items.isEmpty) == false
    }
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
    weak var weakObject = object
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
    var buffer: NodeBuffer? = NodeBuffer.make(objects!.map { TrackedNode(token: $0, value: 0) }) // swiftlint:disable:this force_unwrapping
    objects = nil

    // then: the buffer keeps the objects
    expect(weakObjects.allSatisfy { $0.token != nil }) == true

    // when: releasing the buffer
    buffer = nil

    // then: each child is destroyed, which releases its object
    expect(buffer) == nil
    expect(weakObjects.allSatisfy { $0.token == nil }) == true
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

/// A node whose value is 16-byte aligned.
private struct AlignedNode: ComposeNode {

  var value: SIMD2<Double>

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
