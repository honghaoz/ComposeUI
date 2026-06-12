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
    _ = ZStack {}
    _ = LayeredStack {}
    _ = LayeredStackNode {}
  }

  func test_empty() {
    var node = ZStack {}

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    expect(sizing) == ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
    expect(node.size) == .zero
  }

  func test_flexibleWidth_flexibleHeight() {
    var node = ZStack {
      LayerNode()
      LayerNode()
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
    expect(node.size) == CGSize(width: 100, height: 50)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 100, height: 50)
    expect(items[1].frame) == CGRect(x: 0, y: 0, width: 100, height: 50)
  }

  func test_flexibleWidth_fixedHeight() {
    var node = ZStack {
      LayerNode().frame(width: .flexible, height: 30)
      LayerNode().frame(width: .flexible, height: 20)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(30))
    expect(node.size) == CGSize(width: 100, height: 30)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 100, height: 30)
    expect(items[1].frame) == CGRect(x: 0, y: 5, width: 100, height: 20)
  }

  func test_fixedWidth_flexibleHeight() {
    var node = ZStack {
      LayerNode().frame(width: 50, height: .flexible)
      LayerNode().frame(width: 20, height: .flexible)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .flexible)
    expect(node.size) == CGSize(width: 50, height: 50)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 50)
    expect(items[1].frame) == CGRect(x: 15, y: 0, width: 20, height: 50)
  }

  func test_fixedWidth_fixedHeight() {
    var node = ZStack {
      LayerNode().frame(width: 50, height: 30)
      LayerNode().frame(width: 20, height: 20)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .fixed(30))
    expect(node.size) == CGSize(width: 50, height: 30)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 30)
    expect(items[1].frame) == CGRect(x: 15, y: 5, width: 20, height: 20)
  }

  func test_fixedWidth_fixedHeight_spacer() {
    var node = ZStack {
      LayerNode().frame(width: 50, height: 30)
      Spacer()
      LayerNode().frame(width: 20, height: 20)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    expect(sizing) == ComposeNodeSizing(width: .range(min: 50, max: .infinity), height: .range(min: 30, max: .infinity))
    expect(node.size) == CGSize(width: 100, height: 100)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))

    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 25, y: 35, width: 50, height: 30)
    expect(items[1].frame) == CGRect(x: 40, y: 40, width: 20, height: 20)
  }

  func test_renderableItems_culling_onlyQueriesVisibleChildren() {
    let bigChildState = RenderableItemsProbeNode.State()
    let smallChildState = RenderableItemsProbeNode.State()

    var node = ZStack(alignment: .topLeft) {
      RenderableItemsProbeNode(state: bigChildState, size: CGSize(width: 100, height: 100))
      RenderableItemsProbeNode(state: smallChildState, size: CGSize(width: 10, height: 10))
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // a visible bounds covering the big child but not the small child
    let items = node.renderableItems(in: CGRect(x: 50, y: 50, width: 40, height: 40))

    guard items.count == 1 else {
      fail("Expected 1 item")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

    expect(bigChildState.renderableItemsCallCount) == 1
    expect(smallChildState.renderableItemsCallCount) == 0
  }

  func test_renderableItems_emptyStack() {
    let node = ZStack {}
    expect(node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100)).isEmpty) == true
  }

  func test_renderableItems_assertion() {
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == "renderableItems(in:) requires layout(containerSize:context:) to be called first"
      assertionCount += 1
    }

    // when calling renderableItems without calling layout first
    // then it should trigger the assertion and provide no items
    let node = ZStack {
      LayerNode()
    }
    expect(node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100)).isEmpty) == true
    expect(assertionCount) == 1

    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
  }

  func test_renderableItemsBoundingRect() {
    // an empty stack has no renderable items
    var emptyNode = ZStack {}
    _ = emptyNode.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 1))
    expect(emptyNode.renderableItemsBoundingRect.isNull) == true

    // a stack with an offset child should include the translated child rect
    var node = ZStack {
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
        .offset(x: 5, y: 5)
    }
    _ = node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 1))

    // child 1 items rect: (0, 0, 10, 10), child 2 items rect: (5, 5, 10, 10)
    expect(node.renderableItemsBoundingRect) == CGRect(x: 0, y: 0, width: 15, height: 15)
  }
}
