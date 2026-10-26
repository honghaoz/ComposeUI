//
//  ComposeView+LayoutCacheNodeTests.swift
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

class ComposeView_LayoutCacheNodeTests: XCTestCase {

  func test_forwardsAndCachesWrappedNode() {
    // given: a layout cache node wrapping a test node
    let state = TestNode.State()
    let node = TestNode(state: state)
    let cachedNode = ComposeView.LayoutCacheNode(node: node)

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
      let cachedNode = ComposeView.LayoutCacheNode(node: node)

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

  func test_scaleFactorChange_recomputesCachedLayout() throws {
    // given: a node whose layout depends on display scale
    let state = TestNode.State()
    let node = ScaleDependentNode(state: state)
    let cachedNode = ComposeView.LayoutCacheNode(node: node)
    let size = CGSize(width: 100, height: 100)

    // when: trigger layout with scale factor 1
    _ = cachedNode.layout(containerSize: size, context: ComposeNodeLayoutContext(scaleFactor: 1))

    // then: the wrapped node performs the layout
    expect(state.layoutCount) == 1
    expect(cachedNode.size) == size
    do {
      let item = try cachedNode.renderableItems(in: CGRect(origin: .zero, size: size)).first.unwrap()
      let renderable = item.make(RenderableMakeContext(initialFrame: item.frame, contentView: nil))
      expect(renderable.frame) == CGRect(origin: .zero, size: size)
    }

    // when: trigger layout with a different scale factor without changing the proposed size
    _ = cachedNode.layout(containerSize: size, context: ComposeNodeLayoutContext(scaleFactor: 2))

    // then: the wrapped node performs the layout again
    expect(state.layoutCount) == 2
    expect(cachedNode.size) == CGSize(width: 50, height: 50)
    do {
      let item = try cachedNode.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 50, height: 50))).first.unwrap()
      let renderable = item.make(RenderableMakeContext(initialFrame: item.frame, contentView: nil))
      expect(renderable.frame) == CGRect(origin: .zero, size: CGSize(width: 50, height: 50))
    }

    // when: trigger layout with the same layout inputs but a different content evaluation
    _ = cachedNode.layout(containerSize: size, context: ComposeNodeLayoutContext(scaleFactor: 2, contentEvaluation: ContentEvaluation()))

    // then: the cached layout is reused because the evaluation is not a layout input
    expect(state.layoutCount) == 2
    expect(cachedNode.size) == CGSize(width: 50, height: 50)
  }

  func test_renderableItems_afterLayout_cachesTheItems() {
    // given: a root wrapping a laid out node that caches its item
    let buildCount = CachingNode.Counter()
    let root = ComposeView.LayoutCacheNode(node: CachingNode(buildCount: buildCount))
    _ = root.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))

    // when: making the root's items twice
    _ = root.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))
    _ = root.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))

    // then: the node builds its item once, which the root's cache keeps
    expect(buildCount.value) == 1
  }

  func test_renderableItems_beforeLayout_buildsTheItemsEachTime() {
    // given: a root wrapping a node that caches its item, not laid out
    let buildCount = CachingNode.Counter()
    let root = ComposeView.LayoutCacheNode(node: CachingNode(buildCount: buildCount))

    // when: making the root's items twice
    _ = root.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))
    _ = root.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))

    // then: the node builds its item each time, since it has no slot
    expect(buildCount.value) == 2
  }

  func test_releasingTheRoot_releasesCachedItemsThatKeepALaidOutNode() {
    // given: a root whose cache keeps an item whose update block keeps a node laid out in the content, which has a slot
    // in the cache, and an object
    weak var weakObject: NSObject?
    do {
      let object = NSObject()
      weakObject = object
      let root = ComposeView.LayoutCacheNode(node: KeepingNode(object: object))
      _ = root.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
      _ = root.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))

      // when: the root is released, at the end of the scope
    }

    // then: the root's cache went away with it, and so did the item and what the item kept
    expect(weakObject) == nil
  }

  func test_renderBounds() {
    // given: a cache node wrapping a laid out node with an offset
    var node = LayerNode().frame(width: 10, height: 10).offset(x: 5, y: 5)
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    let cachedNode = ComposeView.LayoutCacheNode(node: node)

    // then: the render bounds are forwarded from the wrapped node
    expect(cachedNode.renderBounds) == CGRect(x: 5, y: 5, width: 10, height: 10)
  }

  #if DEBUG && !COMPOSEUI_BENCHMARK
  func test_layout_keptLayoutAtAnotherSize_isCheckedAgainstANewLayout() {
    // given: a test assertion failure handler
    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // given: a root around a node that counts its layouts, framed to the container's width and a fixed height, laid out
    let state = TestNode.State()
    let root = ComposeView.LayoutCacheNode(node: TestNode(state: state).frame(width: .flexible, height: 300))
    _ = root.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

    // when: laying it out in a new pass at another height, at which it keeps its layout
    _ = root.layout(containerSize: CGSize(width: 100, height: 200), context: ComposeNodeLayoutContext(scaleFactor: 2))

    // then: the debug check lays out the content again, and finds the same layout
    expect(state.layoutCount) == 2
    expect(root.size) == CGSize(width: 100, height: 300)
    expect(assertionMessages.isEmpty) == true

    // when: laying it out at another height with the check off
    KeptLayoutChecks.isOn = false
    defer {
      KeptLayoutChecks.isOn = true
    }
    _ = root.layout(containerSize: CGSize(width: 100, height: 150), context: ComposeNodeLayoutContext(scaleFactor: 2))

    // then: it keeps its layout, without laying out the content again
    expect(state.layoutCount) == 2
  }

  func test_layout_keptLayoutThatDiffersFromANewLayout_asserts_andReturnsTheNewLayout() {
    // given: a test assertion failure handler
    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // given: a root around a node that picks a child's height by the container's height, whose sizing reports that its
    // layout reads the width alone, laid out
    let root = ComposeView.LayoutCacheNode(node: HeightPickingNode())
    _ = root.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
    expect(root.size) == CGSize(width: 100, height: 300)

    // when: laying it out in a new pass at another height, at which it keeps its layout
    let sizing = root.layout(containerSize: CGSize(width: 100, height: 200), context: ComposeNodeLayoutContext(scaleFactor: 2))

    // then: the debug check finds another layout, asserts, and returns the new layout
    expect(assertionMessages) == [
      """
      a layout differs at a container size that differs only in lengths that its sizing's dependence leaves out: \
      (100.0, 300.0) at (100.0, 100.0), and (100.0, 600.0) at (100.0, 200.0). Report each length of the container size \
      that a layout reads in its sizing's dependence, including when a node returns a child's sizing.
      """,
    ]
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(600))
    expect(root.size) == CGSize(width: 100, height: 600)
  }

  func test_layout_keptLayoutOfAnotherSizing_asserts() {
    // given: a test assertion failure handler
    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // given: a root around a node of a fixed size whose sizing changes with the container's height, and reports that its
    // layout reads no length, laid out
    let root = ComposeView.LayoutCacheNode(node: SizingFlippingNode())
    let sizing = root.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

    // when: laying it out in a new pass at another height, at which it keeps its layout
    let sizingAtAnotherHeight = root.layout(containerSize: CGSize(width: 100, height: 200), context: ComposeNodeLayoutContext(scaleFactor: 2))

    // then: the debug check finds the same size and items but another sizing, and asserts
    expect(sizingAtAnotherHeight) != sizing
    expect(root.size) == CGSize(width: 50, height: 50)
    expect(assertionMessages.count) == 1
  }

  func test_layout_keptLayoutOfAnotherSize_asserts() {
    // given: a test assertion failure handler
    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // given: a root around a node that fills its container, whose sizing reports that its layout reads no length, laid
    // out
    let root = ComposeView.LayoutCacheNode(node: FillingNode())
    _ = root.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

    // when: laying it out in a new pass at another size, at which it keeps its layout
    _ = root.layout(containerSize: CGSize(width: 80, height: 120), context: ComposeNodeLayoutContext(scaleFactor: 2))

    // then: the debug check finds the same sizing and items but another size, and asserts
    expect(root.size) == CGSize(width: 80, height: 120)
    expect(assertionMessages.count) == 1
  }

  func test_layout_keptLayoutOfMovedItems_asserts() {
    // given: a test assertion failure handler
    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // given: a root around a node of a fixed size whose items move with the container's height, whose sizing reports
    // that its layout reads no length, laid out
    let root = ComposeView.LayoutCacheNode(node: MovingItemsNode())
    _ = root.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

    // when: laying it out in a new pass at another height, at which it keeps its layout
    _ = root.layout(containerSize: CGSize(width: 100, height: 200), context: ComposeNodeLayoutContext(scaleFactor: 2))

    // then: the debug check finds the same sizing and size but the items moved, and asserts
    expect(root.size) == CGSize(width: 50, height: 50)
    expect(root.renderBounds) == CGRect(x: 0, y: 20, width: 50, height: 50)
    expect(assertionMessages.count) == 1
  }
  #endif
}

private struct ScaleDependentNode: ComposeNode {

  private var state: TestNode.State
  private var node = LayerNode<CALayer>()

  init(state: TestNode.State) {
    self.state = state
  }

  var id: ComposeNodeId = .custom("scale-dependent")

  var size: CGSize { node.size }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    state.layoutCount += 1
    return node.layout(
      containerSize: CGSize(
        width: containerSize.width / context.scaleFactor,
        height: containerSize.height / context.scaleFactor
      ),
      context: context
    )
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
    state.renderCount += 1
    node.render(visibleBounds: visibleBounds, into: &items)
  }
}

/// A node that caches its item in the item cache of its content, as the built-in leaf nodes do, and counts the builds of
/// its item.
private struct CachingNode: ComposeNode {

  /// A count that the node's copies share.
  final class Counter {
    var value = 0
  }

  private let buildCount: Counter
  private var itemSlot = RenderableItemCache.Slot.unassigned

  init(buildCount: Counter) {
    self.buildCount = buildCount
  }

  var id: ComposeNodeId = .custom("caching")

  private(set) var size: CGSize = .zero

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    RenderableItemCache.updateSlot(&itemSlot)
    size = containerSize
    return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height))
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
    let id = id
    let frame = CGRect(origin: .zero, size: size)
    let buildCount = buildCount
    let item = RenderableItemCache.item(in: itemSlot, id: id, frame: frame) {
      buildCount.value += 1
      return RenderableItem(id: id, frame: frame, make: { _ in .layer(CALayer()) }, update: { _, _ in })
    }
    items.append(item)
  }
}

/// A node that caches its item, whose update block keeps the node's laid out child and an object.
private struct KeepingNode: ComposeNode {

  private var child = ColorNode(.red)
  private let object: AnyObject
  private var itemSlot = RenderableItemCache.Slot.unassigned

  init(object: AnyObject) {
    self.object = object
  }

  var id: ComposeNodeId = .custom("keeping")

  private(set) var size: CGSize = .zero

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    RenderableItemCache.updateSlot(&itemSlot)
    _ = child.layout(containerSize: containerSize, context: context)
    size = containerSize
    return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height))
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
    let id = id
    let frame = CGRect(origin: .zero, size: size)
    let child = child
    let object = object
    let item = RenderableItemCache.item(in: itemSlot, id: id, frame: frame) {
      RenderableItem(id: id, frame: frame, make: { _ in .layer(CALayer()) }, update: { _, _ in
        _ = child
        _ = object
      })
    }
    items.append(item)
  }
}
