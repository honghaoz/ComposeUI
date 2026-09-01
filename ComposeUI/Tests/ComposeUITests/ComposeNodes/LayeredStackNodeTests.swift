//
//  LayeredStackNodeTests.swift
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

class LayeredStackNodeTests: XCTestCase {

  func test_typealias() {
    // then: the stack typealiases can be created
    _ = ZStack {}
    _ = LayeredStack {}
    _ = LayeredStackNode {}
  }

  func test_empty() {
    // given: an empty zstack
    var node = ZStack {}

    // when: laying out in a 100x50 container
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    // then: the sizing and size are zero
    expect(sizing) == ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
    expect(node.size) == .zero
  }

  func test_flexibleWidth_flexibleHeight() {
    // given: a zstack with two flexible layer nodes
    var node = ZStack {
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

    // then: the children overlap, filling the stack
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 100, height: 50)
    expect(items[1].frame) == CGRect(x: 0, y: 0, width: 100, height: 50)
  }

  func test_flexibleWidth_fixedHeight() {
    // given: a zstack with flexible width, fixed height children
    var node = ZStack {
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

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 100, height: 30)
    expect(items[1].frame) == CGRect(x: 0, y: 5, width: 100, height: 20)
  }

  func test_fixedWidth_flexibleHeight() {
    // given: a zstack with fixed width, flexible height children
    var node = ZStack {
      LayerNode().frame(width: 50, height: .flexible)
      LayerNode().frame(width: 20, height: .flexible)
    }

    // when: laying out in a 100x50 container
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    // then: the width is the widest child and the height is flexible
    expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .flexible)
    expect(node.size) == CGSize(width: 50, height: 50)

    // when: requesting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    // then: the children fill the height and are centered horizontally
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 50)
    expect(items[1].frame) == CGRect(x: 15, y: 0, width: 20, height: 50)
  }

  func test_fixedWidth_fixedHeight() {
    // given: a zstack with fixed size children
    var node = ZStack {
      LayerNode().frame(width: 50, height: 30)
      LayerNode().frame(width: 20, height: 20)
    }

    // when: laying out in a 100x50 container
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    // then: the size is the widest and tallest child size
    expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .fixed(30))
    expect(node.size) == CGSize(width: 50, height: 30)

    // when: requesting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    // then: the smaller child is centered in the stack
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 30)
    expect(items[1].frame) == CGRect(x: 15, y: 5, width: 20, height: 20)
  }

  func test_fixedWidth_fixedHeight_spacer() {
    // given: a zstack with fixed size children and a spacer
    var node = ZStack {
      LayerNode().frame(width: 50, height: 30)
      Spacer()
      LayerNode().frame(width: 20, height: 20)
    }

    // when: laying out in a 100x100 container
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the stack expands with the spacer to fill the container
    expect(sizing) == ComposeNodeSizing(width: .range(min: 50, max: .infinity), height: .range(min: 30, max: .infinity))
    expect(node.size) == CGSize(width: 100, height: 100)

    // when: requesting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))

    // then: the children are centered in the expanded stack
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 25, y: 35, width: 50, height: 30)
    expect(items[1].frame) == CGRect(x: 40, y: 40, width: 20, height: 20)
  }

  func test_renderableItems_culling_onlyQueriesVisibleChildren() {
    // given: a laid out zstack with a big and a small probe child
    let bigChildState = RenderableItemsProbeNode.State()
    let smallChildState = RenderableItemsProbeNode.State()

    var node = ZStack(alignment: .topLeft) {
      RenderableItemsProbeNode(state: bigChildState, size: CGSize(width: 100, height: 100))
      RenderableItemsProbeNode(state: smallChildState, size: CGSize(width: 10, height: 10))
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when: requesting renderable items in a visible bounds covering the big child but not the small child
    let items = node.renderableItems(in: CGRect(x: 50, y: 50, width: 40, height: 40))

    // then: only the big child is provided and queried
    guard items.count == 1 else {
      fail("Expected 1 item")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

    expect(bigChildState.renderableItemsCallCount) == 1
    expect(smallChildState.renderableItemsCallCount) == 0
  }

  func test_renderableItems_emptyStack() {
    // given: an empty stack
    let node = ZStack {}

    // then: no renderable items are provided
    expect(node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100)).isEmpty) == true
  }

  func test_renderableItems_assertion() {
    // given: a test assertion failure handler
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == "renderableItems(in:) requires layout(containerSize:context:) to be called first"
      assertionCount += 1
    }

    // when: calling renderableItems without calling layout first
    let node = ZStack {
      LayerNode()
    }

    // then: it should trigger the assertion and provide no items
    expect(node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100)).isEmpty) == true
    expect(assertionCount) == 1

    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
  }

  func test_renderableItemsBoundingRect() {
    // when: laying out an empty stack
    var emptyNode = ZStack {}
    _ = emptyNode.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 1))

    // then: an empty stack has no renderable items, the bounding rect is null
    expect(emptyNode.renderableItemsBoundingRect.isNull) == true

    // when: laying out a stack with an offset child
    var node = ZStack {
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
        .offset(x: 5, y: 5)
    }
    _ = node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 1))

    // then: the bounding rect should include the translated child rect
    // child 1 items rect: (0, 0, 10, 10), child 2 items rect: (5, 5, 10, 10)
    expect(node.renderableItemsBoundingRect) == CGRect(x: 0, y: 0, width: 15, height: 15)
  }
}
