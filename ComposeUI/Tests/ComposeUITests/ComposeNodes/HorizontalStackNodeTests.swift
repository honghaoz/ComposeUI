//
//  HorizontalStackNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/31/25.
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

class HorizontalStackNodeTests: XCTestCase {

  func test_typealias() {
    // then: the stack typealiases can be created
    _ = HStack {}
    _ = HorizontalStack {}
    _ = HorizontalStackNode {}
  }

  func test_empty() {
    // given: an empty hstack
    var node = HStack {}

    // when: laying out in a 100x50 container
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    // then: the sizing and size are zero
    expect(sizing) == ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
    expect(node.size) == .zero
  }

  func test_flexibleWidth_flexibleHeight() {
    // given: an hstack with two flexible layer nodes
    var node = HStack {
      LayerNode()
      LayerNode()
    }

    // when: laying out in a 100x50 container
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    // then: the stack is flexible and fills the container
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
    expect(node.size) == CGSize(width: 100, height: 50)

    // when: requesting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    // then: the children split the width evenly
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 50)
    expect(items[1].frame) == CGRect(x: 50, y: 0, width: 50, height: 50)
  }

  func test_flexibleWidth_flexibleHeight_spacing() {
    // given: an hstack with two flexible layer nodes and spacing
    var node = HStack(spacing: 10) {
      LayerNode()
      LayerNode()
    }

    // when: laying out in a 100x50 container
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    // then: the width requires at least the spacing and the stack fills the container
    expect(sizing) == ComposeNodeSizing(width: .range(min: 10, max: .infinity), height: .flexible)
    expect(node.size) == CGSize(width: 100, height: 50)

    // when: requesting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    // then: the children split the remaining width with spacing between
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 45, height: 50)
    expect(items[1].frame) == CGRect(x: 55, y: 0, width: 45, height: 50)
  }

  func test_flexibleWidth_fixedHeight() {
    // given: an hstack with flexible width, fixed height children
    var node = HStack {
      LayerNode().frame(width: .flexible, height: 30)
      LayerNode().frame(width: .flexible, height: 20)
    }

    // when: laying out in a 100x50 container
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    // then: the width is flexible and the height is the tallest child
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(30))
    expect(node.size) == CGSize(width: 100, height: 30)

    // when: requesting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    // then: the children fill the width and are centered vertically
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 30)
    expect(items[1].frame) == CGRect(x: 50, y: 5, width: 50, height: 20)
  }

  func test_fixedWidth_flexibleHeight() {
    // given: an hstack with fixed width, flexible height children
    var node = HStack {
      LayerNode().frame(width: 50, height: .flexible)
      LayerNode().frame(width: 20, height: .flexible)
    }

    // when: laying out in a 100x50 container
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    // then: the width is the total children width and the height is flexible
    expect(sizing) == ComposeNodeSizing(width: .fixed(70), height: .flexible)
    expect(node.size) == CGSize(width: 70, height: 50)

    // when: requesting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    // then: the children keep fixed widths and fill the height
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 50)
    expect(items[1].frame) == CGRect(x: 50, y: 0, width: 20, height: 50)
  }

  func test_fixedWidth_fixedHeight() {
    // given: an hstack with fixed size children
    var node = HStack {
      LayerNode().frame(width: 50, height: 30)
      LayerNode().frame(width: 20, height: 20)
    }

    // when: laying out in a 100x50 container
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    // then: the size is the children's total width and tallest height
    expect(sizing) == ComposeNodeSizing(width: .fixed(70), height: .fixed(30))
    expect(node.size) == CGSize(width: 70, height: 30)

    // when: requesting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    // then: the children keep fixed sizes and are centered vertically
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 30)
    expect(items[1].frame) == CGRect(x: 50, y: 5, width: 20, height: 20)
  }

  func test_fixedWidth_fixedHeight_spacer() {
    // given: an hstack with fixed size children separated by a spacer
    var node = HStack {
      LayerNode().frame(width: 50, height: 30)
      Spacer()
      LayerNode().frame(width: 20, height: 20)
    }

    // when: laying out in a 100x50 container
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    // then: the width expands with the spacer and the height is the tallest child
    expect(sizing) == ComposeNodeSizing(width: .range(min: 70, max: .infinity), height: .fixed(30))
    expect(node.size) == CGSize(width: 100, height: 30)

    // when: requesting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    // then: the spacer pushes the second child to the trailing edge
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 30)
    expect(items[1].frame) == CGRect(x: 80, y: 5, width: 20, height: 20)
  }

  func test_fixedWidth_fixedHeight_alignment() {
    // given: an hstack with top alignment
    do {
      var node = HStack(alignment: .top) {
        LayerNode().frame(width: 50, height: 30)
        LayerNode().frame(width: 20, height: 20)
      }

      // when: laying out in a 100x50 container
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

      // then: the size is the children's total width and tallest height
      expect(sizing) == ComposeNodeSizing(width: .fixed(70), height: .fixed(30))
      expect(node.size) == CGSize(width: 70, height: 30)

      // when: requesting renderable items
      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

      // then: the shorter child is aligned to the top
      guard items.count == 2 else {
        fail("Expected 2 items")
        return
      }

      expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 30)
      expect(items[1].frame) == CGRect(x: 50, y: 0, width: 20, height: 20)
    }

    // given: an hstack with bottom alignment
    do {
      var node = HStack(alignment: .bottom) {
        LayerNode().frame(width: 50, height: 30)
        LayerNode().frame(width: 20, height: 20)
      }

      // when: laying out in a 100x50 container
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

      // then: the size is the children's total width and tallest height
      expect(sizing) == ComposeNodeSizing(width: .fixed(70), height: .fixed(30))
      expect(node.size) == CGSize(width: 70, height: 30)

      // when: requesting renderable items
      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

      // then: the shorter child is aligned to the bottom
      guard items.count == 2 else {
        fail("Expected 2 items")
        return
      }

      expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 30)
      expect(items[1].frame) == CGRect(x: 50, y: 10, width: 20, height: 20)
    }
  }

  func test_renderableItems_filtersOffscreenChildren() {
    // given: a laid out hstack with three fixed size children
    var node = HStack {
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 30, height: 10), context: context)

    // when: requesting renderable items in bounds covering only the first child
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))

    // then: only the visible child is provided
    guard items.count == 1 else {
      fail("Expected 1 item")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 10, height: 10)
  }

  func test_renderableItems_includesOffsetChildren() {
    // given: a laid out hstack with an offset second child
    var node = HStack {
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
        .offset(x: -10, y: 0)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 20, height: 10), context: context)

    // when: requesting renderable items in bounds covering the first child
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))

    // then: both children are provided including the offset child
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 10, height: 10)
    expect(items[1].frame) == CGRect(x: 0, y: 0, width: 10, height: 10)
  }

  func test_renderableItems_culling_onlyQueriesVisibleChildren() {
    // given: a laid out hstack with 100 probe children
    let childCount = 100
    let states = (0 ..< childCount).map { _ in RenderableItemsProbeNode.State() }

    var node = HStack {
      for state in states {
        RenderableItemsProbeNode(state: state, size: CGSize(width: 10, height: 10))
      }
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 1000, height: 10), context: context)

    // when: requesting renderable items in a visible bounds covering children 40 ... 44
    // (child 45 starts at x == 450, touching, not intersecting)
    let items = node.renderableItems(in: CGRect(x: 400, y: 0, width: 50, height: 10))

    // then: only the visible children are provided
    guard items.count == 5 else {
      fail("Expected 5 items")
      return
    }

    for (i, item) in items.enumerated() {
      expect(item.frame) == CGRect(x: 400 + CGFloat(i) * 10, y: 0, width: 10, height: 10)
    }

    // then: only the visible children should be queried
    for (i, state) in states.enumerated() {
      if (40 ... 44).contains(i) {
        expect(state.renderableItemsCallCount, "child \(i)") == 1
      } else {
        expect(state.renderableItemsCallCount, "child \(i)") == 0
      }
    }
  }

  func test_renderableItems_emptyStack() {
    // given: an empty stack
    let node = HStack {}

    // then: no renderable items are provided
    expect(node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100)).isEmpty) == true
  }

  func test_renderableItems_visibleBoundsOutsideContent() {
    // given: a laid out hstack with two fixed size children
    var node = HStack {
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 20, height: 10), context: context)

    // then: visible bounds outside the content provide no items
    // after the content
    expect(node.renderableItems(in: CGRect(x: 100, y: 0, width: 10, height: 10)).isEmpty) == true

    // before the content
    expect(node.renderableItems(in: CGRect(x: -20, y: 0, width: 10, height: 10)).isEmpty) == true
  }

  func test_renderableItems_assertion() {
    // given: a test assertion failure handler
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == "renderableItems(in:) requires layout(containerSize:context:) to be called first"
      assertionCount += 1
    }

    // when: calling renderableItems without calling layout first
    let node = HStack {
      LayerNode()
    }

    // then: it should trigger the assertion and provide no items
    expect(node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100)).isEmpty) == true
    expect(assertionCount) == 1

    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
  }

  func test_renderableItemsBoundingRect() {
    // when: laying out an empty stack
    var emptyNode = HStack {}
    _ = emptyNode.layout(containerSize: CGSize(width: 20, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 1))

    // then: an empty stack has no renderable items, the bounding rect is null
    expect(emptyNode.renderableItemsBoundingRect.isNull) == true

    // when: laying out a stack with an offset child
    var node = HStack {
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
        .offset(x: -5, y: 0)
    }
    _ = node.layout(containerSize: CGSize(width: 20, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 1))

    // then: the bounding rect should include the translated child rect
    // child 1 items rect: (0, 0, 10, 10), child 2 items rect: (5, 0, 10, 10)
    expect(node.renderableItemsBoundingRect) == CGRect(x: 0, y: 0, width: 15, height: 10)
  }
}
