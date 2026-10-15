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
    // given: a node that keeps its items and appends them on each call, inside nodes that change their child's items
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

  func test_renderableItems_returnsTheItemsThatTheNodeAppends() {
    // given: a node that appends the items it keeps, laid out
    var node = ItemsKeepingNode()
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

    // when: getting its items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))

    // then: they're the items that the node appends, in a new array
    expect(items.map(\.id)) == [.custom("kept", isFixed: false)]
    expect(items.map(\.frame)) == [CGRect(x: 0, y: 0, width: 10, height: 10)]
  }

  func test_appendRenderableItems_builtInNodes_appendTheItemsOfRenderableItemsAfterTheExistingOnes() {
    // given: each built-in node, with children where it has them, and the number of items it makes
    let shadowPath: (CGSize) -> CGPath = { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) }
    let nodes: [(String, any ComposeNode, Int)] = [
      ("color", ColorNode(.red), 1),
      ("text", TextNode("Hello"), 1),
      ("label", LabelNode("Hello"), 1),
      ("layer", LayerNode(), 1),
      ("view", ViewNode(), 1),
      ("button", ButtonNode(content: { _ in ColorNode(.red) }, onTap: {}), 1),
      ("drop shadow", DropShadowNode(color: .black, opacity: 0.5, radius: 4, offset: CGSize(width: 0, height: 2), path: shadowPath), 1),
      ("inner shadow", InnerShadowNode(color: .black, opacity: 0.5, radius: 4, offset: CGSize(width: 0, height: 2), path: shadowPath), 1),
      ("compose view", ComposeViewNode { ColorNode(.red) }, 1),
      ("empty", Empty(), 0),
      ("spacer", Spacer(), 0),
      ("frame", ColorNode(.red).frame(width: 40, height: 30), 1),
      ("padding", ColorNode(.red).padding(5), 1),
      ("offset", ColorNode(.red).offset(x: 3, y: 4), 1),
      ("modifier", ColorNode(.red).opacity(0.5), 1),
      ("modifier that adds updates", ColorNode(.red).onUpdate { _, _ in }, 1),
      ("gesture recognizer", ColorNode(.red).onTap { _ in }, 2),
      ("gesture recognizer of a node without items", Empty().onTap { _ in }, 0),
      ("overlay", ColorNode(.red).overlay { ColorNode(.blue).frame(width: 10, height: 10) }, 2),
      ("underlay", ColorNode(.red).underlay { ColorNode(.blue).frame(width: 10, height: 10) }, 2),
      ("vertical stack", VStack { ColorNode(.red).frame(width: 40, height: 20)
        ColorNode(.blue).padding(2).frame(width: 40, height: 20)
      }, 2),
      ("horizontal stack", HStack { ColorNode(.red).frame(width: 20, height: 40)
        ColorNode(.blue).padding(2).frame(width: 20, height: 40)
      }, 2),
      ("layered stack", ZStack { ColorNode(.red).frame(width: 40, height: 20)
        ColorNode(.blue).offset(x: 5, y: 5)
      }, 2),
      ("layout cache", ComposeView.LayoutCacheNode(node: VStack { ColorNode(.red).frame(width: 40, height: 20)
        ColorNode(.blue)
      }), 2),
    ]
    let existingItem = Self.makeItem(id: "existing", frame: CGRect(x: 1, y: 2, width: 3, height: 4))
    let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 100)

    for (name, node, itemCount) in nodes {
      var node = node
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
      let expectedItems = node.renderableItems(in: visibleBounds)
      expect(expectedItems.count, name) == itemCount

      // when: appending the node's items to an array with another node's item
      var items = [existingItem]
      node.appendRenderableItems(in: visibleBounds, to: &items)

      // then: the node's items follow the existing one, which stays as it was
      expect(items.first?.id, name) == existingItem.id
      expect(items.first?.frame, name) == existingItem.frame
      expect(Array(items.dropFirst()).map(\.id), name) == expectedItems.map(\.id)
      expect(Array(items.dropFirst()).map(\.frame), name) == expectedItems.map(\.frame)
    }
  }

  /// Returns a layer item with the given id and frame.
  private static func makeItem(id: String, frame: CGRect) -> RenderableItem {
    LayerItem<CALayer>(id: .custom(id, isFixed: false), frame: frame, make: { _ in CALayer() }, update: { _, _ in }).eraseToRenderableItem()
  }
}

/// A node that keeps its items and appends them on each call.
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

  func appendRenderableItems(in visibleBounds: CGRect, to items: inout [RenderableItem]) {
    items.append(contentsOf: storage.items)
  }
}

private class MockComposeNode: ComposeNode {

  var id: ComposeNodeId = .custom("test", isFixed: false)
  var size: CGSize = .zero

  func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    ComposeNodeSizing(width: .fixed(100), height: .fixed(100))
  }

  func appendRenderableItems(in visibleBounds: CGRect, to items: inout [RenderableItem]) {}
}
