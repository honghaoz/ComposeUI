//
//  ComposeNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/5/24.
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

import QuartzCore

import ChouTiTest

@testable import ComposeUI

class ComposeNodeTests: XCTestCase {

  func test_ComposeContent() {
    // given: a mock compose node
    let node = MockComposeNode()

    // when: reading the node's nodes as a content
    let nodes = node.nodes

    // then: the node itself is returned as a single node
    expect(nodes.count) == 1
    expect((nodes[0] as? MockComposeNode)) === node
  }

  func test_id() {
    // when: setting a custom id
    do {
      let node = MockComposeNode().id("test")

      // then: the node has a non-fixed custom id
      expect(node.id) == .custom("test", isFixed: false)
      expect(node.id.isSameConfiguration(as: .custom("test", isFixed: false))) == true
    }

    // when: setting a fixed id
    do {
      let node = MockComposeNode().fixedId("test")

      // then: the node has a fixed custom id
      expect(node.id) == .custom("test", isFixed: true)
      expect(node.id.isSameConfiguration(as: .custom("test", isFixed: true))) == true
    }
  }

  func test_fixedId_appliesWhenIdStringUnchanged() {
    // given: a node with a fixed id set over the same id string
    let node = MockComposeNode().id("test").fixedId("test")

    // then: the fixed id survives joining with a parent id
    expect(ComposeNodeId.custom("parent").join(with: node.id).id) == "test"
  }

  func test_renderableItems_childKeepsItsItems_staysUnchanged() {
    // given: a node that keeps its items and returns them on each call, inside nodes that change their child's items
    let itemsKeepingNode = ItemsKeepingNode()
    var node = itemsKeepingNode
      .padding(5)
      .offset(x: 3, y: 4)
      .opacity(0.5)
      .frame(width: 40, height: 40)
      .overlay { LayerNode() }
      .underlay { LayerNode() }
      .onTap { _ in }
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
    let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: making the items twice
    let items = node.renderableItems(in: visibleBounds)
    let itemsAgain = node.renderableItems(in: visibleBounds)

    // then: the kept item is moved once in each call, by the padding, the offset and the frame's centering, and the
    // node's kept items stay as they were
    expect(items.map(\.frame)) == itemsAgain.map(\.frame)
    expect(items.map(\.id)) == itemsAgain.map(\.id)
    expect(items[1].frame) == CGRect(x: 18, y: 19, width: 10, height: 10)
    expect(itemsKeepingNode.storage.items.map(\.frame)) == [CGRect(x: 0, y: 0, width: 10, height: 10)]
    expect(itemsKeepingNode.storage.items.map(\.id)) == [.custom("kept", isFixed: false)]
  }
}

/// A node that keeps its items and returns the same array on each call.
private struct ItemsKeepingNode: ComposeNode {

  final class Storage {

    var items: [RenderableItem] = []
  }

  let storage = Storage()

  var id: ComposeNodeId = .custom("kept", isFixed: false)

  private(set) var size: CGSize = .zero

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    size = CGSize(width: 10, height: 10)
    if storage.items.isEmpty {
      let item = LayerItem<CALayer>(id: id, frame: CGRect(origin: .zero, size: size), make: { _ in CALayer() }, update: { _, _ in })
      storage.items = [item.eraseToRenderableItem()]
    }
    return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height))
  }

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    storage.items
  }
}

private class MockComposeNode: ComposeNode {

  var id: ComposeNodeId = .custom("test", isFixed: false)
  var size: CGSize = .zero

  func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    ComposeNodeSizing(width: .fixed(100), height: .fixed(100))
  }

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    []
  }
}
