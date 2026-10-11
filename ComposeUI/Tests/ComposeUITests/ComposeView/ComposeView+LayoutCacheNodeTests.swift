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

  func test_renderableItems_afterLayout_cachesTheItemsInTheContentsCache() {
    // given: a root wrapping a node that caches its item, laid out in a content
    let buildCount = CachingNode.Counter()
    let root = ComposeView.LayoutCacheNode(node: CachingNode(buildCount: buildCount))
    _ = root.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))

    // when: making the root's items twice
    _ = root.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))
    _ = root.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))

    // then: the node builds its item once, which the content's cache keeps
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

  func test_layout_skippedInAnotherContent_keepsTheCacheOfTheSlots() {
    // given: a root laid out in a content, whose node's item is cached
    let buildCount = CachingNode.Counter()
    let root = ComposeView.LayoutCacheNode(node: CachingNode(buildCount: buildCount))
    let containerSize = CGSize(width: 10, height: 10)
    _ = root.layout(containerSize: containerSize, context: ComposeNodeLayoutContext(scaleFactor: 2))
    _ = root.renderableItems(in: CGRect(origin: .zero, size: containerSize))

    // when: laying the root out again in another content with the same inputs, which skips the node's layout, and
    // making its items
    _ = root.layout(containerSize: containerSize, context: ComposeNodeLayoutContext(scaleFactor: 2))
    _ = root.renderableItems(in: CGRect(origin: .zero, size: containerSize))

    // then: the root collects the items in the first content's cache, which has the node's slot, so the item stays
    // cached
    expect(buildCount.value) == 1
  }

  func test_renderableItemsBoundingRect() {
    // given: a cache node wrapping a laid out node with an offset
    var node = LayerNode().frame(width: 10, height: 10).offset(x: 5, y: 5)
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    let cachedNode = ComposeView.LayoutCacheNode(node: node)

    // then: the bounding rect is forwarded from the wrapped node
    expect(cachedNode.renderableItemsBoundingRect) == CGRect(x: 5, y: 5, width: 10, height: 10)
  }
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

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    state.renderCount += 1
    return node.renderableItems(in: visibleBounds)
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
    context.updateRenderableItemSlot(&itemSlot)
    size = containerSize
    return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height))
  }

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    let id = id
    let frame = CGRect(origin: .zero, size: size)
    let buildCount = buildCount
    let item = RenderableItemCache.item(in: itemSlot, id: id, frame: frame) {
      buildCount.value += 1
      return RenderableItem(id: id, frame: frame, make: { _ in .layer(CALayer()) }, update: { _, _ in })
    }
    return [item]
  }
}
