//
//  LayoutCacheNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
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

class LayoutCacheNodeTests: XCTestCase {

  func test() {
    // given: a layout cache node wrapping a test node
    let state = TestNode.State()
    let node = TestNode(state: state)
    let cachedNode = LayoutCacheNode(node: node)

    // then: the id is forwarded from the wrapped node
    expect(cachedNode.id.id) == "test"

    // when: setting a new id
    cachedNode.id = .custom("test2")

    // then: the id is updated
    expect(cachedNode.id.id) == "test2"

    // then: the size is zero before layout
    expect(cachedNode.size) == .zero

    // node with different size
    do {
      // given: a cache node wrapping a laid out node with a fixed size
      var node = LayerNode().frame(width: 100, height: 50)
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
      let cachedNode = LayoutCacheNode(node: node)

      // then: the size is forwarded from the wrapped node
      expect(cachedNode.size) == CGSize(width: 100, height: 50)
    }

    // when: laying out for the first time
    _ = cachedNode.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 1))

    // then: the wrapped node performs the layout
    expect(state.layoutCount) == 1

    // when: laying out again with the same container size
    _ = cachedNode.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 1))

    // then: the cached layout is reused
    expect(state.layoutCount) == 1

    // when: laying out with a different container size
    _ = cachedNode.layout(containerSize: CGSize(width: 200, height: 200), context: ComposeNodeLayoutContext(scaleFactor: 1))

    // then: the wrapped node performs a new layout
    expect(state.layoutCount) == 2

    // then: no renderable items are requested yet
    expect(state.renderCount) == 0

    // when: getting renderable items
    _ = cachedNode.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))

    // then: the wrapped node provides the renderable items
    expect(state.renderCount) == 1
  }

  func test_renderableItemsBoundingRect() {
    // given: a cache node wrapping a laid out node with an offset
    var node = LayerNode().frame(width: 10, height: 10).offset(x: 5, y: 5)
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    let cachedNode = LayoutCacheNode(node: node)

    // then: the bounding rect is forwarded from the wrapped node
    expect(cachedNode.renderableItemsBoundingRect) == CGRect(x: 5, y: 5, width: 10, height: 10)
  }
}
