//
//  VerticalStackNodeTests.swift
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

class VerticalStackNodeTests: XCTestCase {

  func test_typealias() {
    _ = VStack {}
    _ = VerticalStack {}
    _ = VerticalStackNode {}
  }

  func test_empty() {
    // given: an empty vertical stack
    var node = VStack {}

    // when: laying out the stack
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

    // then: the sizing and size are zero
    expect(sizing) == ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
    expect(node.size) == .zero
  }

  func test_flexibleWidth_flexibleHeight() {
    // given: a stack with two flexible children
    var node = VStack {
      LayerNode()
      LayerNode()
    }

    // when: laying out the stack
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

    // then: the sizing is flexible and the size fills the container
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
    expect(node.size) == CGSize(width: 50, height: 100)

    // when: getting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

    // then: the children split the container height evenly
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 50)
    expect(items[1].frame) == CGRect(x: 0, y: 50, width: 50, height: 50)
  }

  func test_flexibleWidth_flexibleHeight_spacing() {
    // given: a stack with spacing and two flexible children
    var node = VStack(spacing: 10) {
      LayerNode()
      LayerNode()
    }

    // when: laying out the stack
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

    // then: the height sizing accounts for the spacing and the size fills the container
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .range(min: 10, max: .infinity))
    expect(node.size) == CGSize(width: 50, height: 100)

    // when: getting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

    // then: the children are laid out with the spacing
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 45)
    expect(items[1].frame) == CGRect(x: 0, y: 55, width: 50, height: 45)
  }

  func test_flexibleWidth_fixedHeight() {
    // given: a stack with two fixed height children
    var node = VStack {
      LayerNode().frame(width: .flexible, height: 30)
      LayerNode().frame(width: .flexible, height: 20)
    }

    // when: laying out the stack
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

    // then: the width is flexible and the height is the sum of the children heights
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(50))
    expect(node.size) == CGSize(width: 50, height: 50)

    // when: getting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

    // then: the children are stacked with their fixed heights
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 30)
    expect(items[1].frame) == CGRect(x: 0, y: 30, width: 50, height: 20)
  }

  func test_fixedWidth_flexibleHeight() {
    // given: a stack with two fixed width children
    var node = VStack {
      LayerNode().frame(width: 20, height: .flexible)
      LayerNode().frame(width: 30, height: .flexible)
    }

    // when: laying out the stack
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

    // then: the width is the max child width and the height is flexible
    expect(sizing) == ComposeNodeSizing(width: .fixed(30), height: .flexible)
    expect(node.size) == CGSize(width: 30, height: 100)

    // when: getting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

    // then: the children split the height and are centered horizontally
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 5, y: 0, width: 20, height: 50)
    expect(items[1].frame) == CGRect(x: 0, y: 50, width: 30, height: 50)
  }

  func test_fixedWidth_fixedHeight() {
    // given: a stack with two fixed size children
    var node = VStack {
      LayerNode().frame(width: 30, height: 50)
      LayerNode().frame(width: 20, height: 20)
    }

    // when: laying out the stack
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

    // then: the sizing and size are fixed to the combined children size
    expect(sizing) == ComposeNodeSizing(width: .fixed(30), height: .fixed(70))
    expect(node.size) == CGSize(width: 30, height: 70)

    // when: getting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

    // then: the children are stacked and centered horizontally
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 30, height: 50)
    expect(items[1].frame) == CGRect(x: 5, y: 50, width: 20, height: 20)
  }

  func test_fixedWidth_fixedHeight_spacer() {
    // given: a stack with two fixed size children separated by a spacer
    var node = VStack {
      LayerNode().frame(width: 30, height: 50)
      Spacer()
      LayerNode().frame(width: 20, height: 20)
    }

    // when: laying out the stack
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

    // then: the height sizing is a range starting at the combined children height
    expect(sizing) == ComposeNodeSizing(width: .fixed(30), height: .range(min: 70, max: .infinity))
    expect(node.size) == CGSize(width: 30, height: 100)

    // when: getting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

    // then: the spacer pushes the second child to the bottom
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 30, height: 50)
    expect(items[1].frame) == CGRect(x: 5, y: 80, width: 20, height: 20)
  }

  func test_fixedWidth_fixedHeight_alignment() {
    // left alignment
    do {
      // given: a left aligned stack with two fixed size children
      var node = VStack(alignment: .left) {
        LayerNode().frame(width: 30, height: 50)
        LayerNode().frame(width: 20, height: 20)
      }

      // when: laying out the stack
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

      // then: the sizing and size are fixed to the combined children size
      expect(sizing) == ComposeNodeSizing(width: .fixed(30), height: .fixed(70))
      expect(node.size) == CGSize(width: 30, height: 70)

      // when: getting renderable items
      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

      // then: the children are aligned to the left
      guard items.count == 2 else {
        fail("Expected 2 items")
        return
      }

      expect(items[0].frame) == CGRect(x: 0, y: 0, width: 30, height: 50)
      expect(items[1].frame) == CGRect(x: 0, y: 50, width: 20, height: 20)
    }

    // right alignment
    do {
      // given: a right aligned stack with two fixed size children
      var node = VStack(alignment: .right) {
        LayerNode().frame(width: 30, height: 50)
        LayerNode().frame(width: 20, height: 20)
      }

      // when: laying out the stack
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

      // then: the sizing and size are fixed to the combined children size
      expect(sizing) == ComposeNodeSizing(width: .fixed(30), height: .fixed(70))
      expect(node.size) == CGSize(width: 30, height: 70)

      // when: getting renderable items
      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

      // then: the children are aligned to the right
      guard items.count == 2 else {
        fail("Expected 2 items")
        return
      }

      expect(items[0].frame) == CGRect(x: 0, y: 0, width: 30, height: 50)
      expect(items[1].frame) == CGRect(x: 10, y: 50, width: 20, height: 20)
    }
  }

  func test_renderableItems_filtersOffscreenChildren() {
    // given: a laid out stack with three fixed size children
    var node = VStack {
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 10, height: 30), context: context)

    // when: getting renderable items in bounds covering only the first child
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))

    // then: only the visible child is provided
    guard items.count == 1 else {
      fail("Expected 1 item")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 10, height: 10)
  }

  func test_renderableItems_includesOffsetChildren() {
    // given: a laid out stack where the second child is offset into the first child's row
    var node = VStack {
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
        .offset(x: 0, y: -10)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 10, height: 20), context: context)

    // when: getting renderable items in bounds covering the first row
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))

    // then: both children are provided
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 10, height: 10)
    expect(items[1].frame) == CGRect(x: 0, y: 0, width: 10, height: 10)
  }

  func test_renderableItems_culling_onlyQueriesVisibleChildren() {
    // given: a laid out stack with many probe children
    let childCount = 100
    let states = (0 ..< childCount).map { _ in RenderableItemsProbeNode.State() }

    var node = VStack {
      for state in states {
        RenderableItemsProbeNode(state: state, size: CGSize(width: 10, height: 10))
      }
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 10, height: 1000), context: context)

    // when: getting renderable items in a visible bounds covering children 40 ... 44
    // child 45 starts at y == 450, touching, not intersecting
    let items = node.renderableItems(in: CGRect(x: 0, y: 400, width: 10, height: 50))

    // then: the five visible children provide items with the expected frames
    guard items.count == 5 else {
      fail("Expected 5 items")
      return
    }

    for (i, item) in items.enumerated() {
      expect(item.frame) == CGRect(x: 0, y: 400 + CGFloat(i) * 10, width: 10, height: 10)
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

  func test_renderableItems_negativeSpacing() {
    // given: a laid out stack with negative spacing and three fixed size children
    var node = VStack(spacing: -5) {
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 10, height: 20), context: context)

    expect(node.size) == CGSize(width: 10, height: 20)

    // when: getting renderable items in bounds covering the first two children
    // children are at y == 0, 5, 10. the visible bounds covers children 1 and 2 only.
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 8))

    // then: the two overlapping children are provided
    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 10, height: 10)
    expect(items[1].frame) == CGRect(x: 0, y: 5, width: 10, height: 10)
  }

  func test_renderableItems_emptyStack() {
    // given: an empty stack
    let node = VStack {}

    // then: no renderable items are provided
    expect(node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100)).isEmpty) == true
  }

  func test_renderableItems_visibleBoundsOutsideContent() {
    // given: a laid out stack with two fixed size children
    var node = VStack {
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 10, height: 20), context: context)

    // then: bounds below the content provide no items
    expect(node.renderableItems(in: CGRect(x: 0, y: 100, width: 10, height: 10)).isEmpty) == true

    // then: bounds above the content provide no items
    expect(node.renderableItems(in: CGRect(x: 0, y: -20, width: 10, height: 10)).isEmpty) == true
  }

  func test_renderableItems_assertion() {
    // given: a test assertion failure handler capturing the assertion
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == "renderableItems(in:) requires layout(containerSize:context:) to be called first"
      assertionCount += 1
    }

    // when: calling renderableItems without calling layout first
    let node = VStack {
      LayerNode()
    }

    // then: it should trigger the assertion and provide no items
    expect(node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100)).isEmpty) == true
    expect(assertionCount) == 1

    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
  }

  func test_renderableItemsBoundingRect() {
    // given: a laid out empty stack
    var emptyNode = VStack {}
    _ = emptyNode.layout(containerSize: CGSize(width: 10, height: 20), context: ComposeNodeLayoutContext(scaleFactor: 1))

    // then: the bounding rect is null since an empty stack has no renderable items
    expect(emptyNode.renderableItemsBoundingRect.isNull) == true

    // given: a laid out stack with only spacers
    var spacerNode = VStack {
      Spacer()
    }
    _ = spacerNode.layout(containerSize: CGSize(width: 10, height: 20), context: ComposeNodeLayoutContext(scaleFactor: 1))

    // then: the bounding rect is null since a stack with only spacers has no renderable items
    expect(spacerNode.renderableItemsBoundingRect.isNull) == true

    // given: a laid out stack with an offset child
    var node = VStack {
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
        .offset(x: 0, y: -5)
        .onUpdate { _, _ in } // wrap in a modifier node to verify the bounding rect is forwarded
    }
    _ = node.layout(containerSize: CGSize(width: 10, height: 20), context: ComposeNodeLayoutContext(scaleFactor: 1))

    // then: the bounding rect should include the translated child rect
    // child 1 items rect: (0, 0, 10, 10), child 2 items rect: (0, 5, 10, 10)
    expect(node.renderableItemsBoundingRect) == CGRect(x: 0, y: 0, width: 10, height: 15)
  }
}
