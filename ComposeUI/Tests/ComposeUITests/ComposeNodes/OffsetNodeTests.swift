//
//  OffsetNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/13/25.
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

import ChouTi
@testable import ComposeUI

class OffsetNodeTests: XCTestCase {

  func test_id() throws {
    let node = LayerNode().offset(x: 10, y: 20)
    expect(node.id.id) == "O"
  }

  func test_size() throws {
    // node without a size
    do {
      let node = LayerNode()
      expect(node.size) == .zero
      expect(node.offset(x: 10, y: 20).size) == .zero
    }

    // node with a size
    do {
      var node = LayerNode().frame(width: 20, height: 30)

      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      expect(node.size) == CGSize(width: 20, height: 30)
      expect(node.offset(x: 10, y: 20).size) == CGSize(width: 20, height: 30)
    }
  }

  func test_layout() throws {
    let state = TestNode.State()
    let node = TestNode(state: state)

    var offsetNode = node.offset(x: 10, y: 20)

    expect(state.layoutCount) == 0

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = offsetNode.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    expect(state.layoutCount) == 1
  }

  func test_renderableItems() throws {
    var node = LayerNode()
      .frame(width: 20, height: 30)
      .offset(x: 10, y: 20)

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when visible bounds contains the node
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 100)
      let items = node.renderableItems(in: visibleBounds)

      expect(items.count) == 1
      expect(items[0].frame) == CGRect(x: 10, y: 20, width: 20, height: 30)
      expect(items[0].id.id) == "O|F|L"
    }

    // when visible bounds does not contain the node
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 10, height: 10)
      let items = node.renderableItems(in: visibleBounds)

      expect(items.count) == 0
    }
  }

  func test_renderableItems_childMovedOutsideOriginalBounds() throws {
    let context = ComposeNodeLayoutContext(scaleFactor: 1)

    // e.g. a (20, 20) child with .offset(x: 30, y: 30) is fully outside (0, 0, 20, 20)
    do {
      var node = LayerNode()
        .frame(width: 20, height: 20)
        .offset(x: 30, y: 30)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      let originalBounds = CGRect(x: 0, y: 0, width: 20, height: 20)
      let items = node.renderableItems(in: originalBounds)

      expect(items.count) == 0
    }

    // querying bounds that intersect the offset child should still return its renderable items
    do {
      var node = LayerNode()
        .frame(width: 20, height: 20)
        .offset(x: 30, y: 0)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      let visibleBounds = CGRect(x: 11, y: 0, width: 20, height: 20)
      let items = node.renderableItems(in: visibleBounds)

      expect(items.count) == 1
      expect(items[0].frame) == CGRect(x: 30, y: 0, width: 20, height: 20)
      expect(items[0].id.id) == "O|F|L"
    }
  }

  func test_renderableItemsBoundingRect() throws {
    let context = ComposeNodeLayoutContext(scaleFactor: 1)

    // the bounding rect should be translated by the offset
    do {
      var node = LayerNode()
        .frame(width: 20, height: 30)
        .offset(x: 10, y: 20)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      expect(node.renderableItemsBoundingRect) == CGRect(x: 10, y: 20, width: 20, height: 30)
    }

    // when the child node has no renderable items
    do {
      var node = Spacer().offset(x: 10, y: 20)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      expect(node.renderableItemsBoundingRect.isNull) == true
    }
  }
}
