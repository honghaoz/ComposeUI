//
//  GestureRecognizerNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 7/30/25.
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

class GestureRecognizerNodeTests: XCTestCase {

  // MARK: - Basic Node Tests

  func test_nodeSize() {
    // given: a layer node with a tap handler
    let baseNode = LayerNode()
    var gestureNode = baseNode.onTap { _ in }
    let containerSize = CGSize(width: 200, height: 100)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)

    // when: laying out in the container
    gestureNode.layout(containerSize: containerSize, context: context)

    // then: the node size matches the container size
    expect(gestureNode.size) == containerSize
  }

  // MARK: - Renderable Items Tests

  func test_renderableItems() throws {
    // given: a laid out framed color node with a tap handler
    var node = ColorNode(.red).frame(width: 100, height: 50).onTap { _ in }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when: visible bounds intersects with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)

      // then: the color item and a gesture overlay item are provided with the expected behaviors
      expect(items.count) == 2

      let item = items[1]
      expect(item.id.id) == "G"
      expect(item.frame) == CGRect(x: 0, y: 0, width: 100, height: 50)

      // make
      do {
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: nil))
        expect(renderable.view?.frame) == CGRect(x: 1, y: 2, width: 3, height: 4)
      }

      expect(item.willInsert) == nil
      expect(item.didInsert) == nil
      expect(item.willUpdate) == nil

      // update
      do {
        // normal update
        do {
          let contentView = ComposeView()
          let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

          let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
          item.update(renderable, context)
          let view = try (renderable.view).unwrap()
          let viewLookup = DynamicLookup(view)
          expect((viewLookup.property("handlers") as? [AnyHashable: Any])?.count) == 1
          expect((viewLookup.property("installedGestureRecognizers") as? [AnyHashable: Any])?.count) == 1

          expect((view as? GestureRecognizerDelegate)?.gestureRecognizer?(GestureRecognizer(), shouldRecognizeSimultaneouslyWith: GestureRecognizer())) == true
        }

        // conditional update
        do {
          let contentView = ComposeView()
          let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

          // scroll doesn't trigger update
          do {
            let context = RenderableUpdateContext(updateType: .scroll, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
            item.update(renderable, context)
            let view = try (renderable.view).unwrap()
            let viewLookup = DynamicLookup(view)
            expect((viewLookup.property("handlers") as? [AnyHashable: Any])?.count) == 0 // doesn't update
            expect((viewLookup.property("installedGestureRecognizers") as? [AnyHashable: Any])?.count) == 0 // doesn't update
          }

          // bounds change triggers update
          do {
            let context = RenderableUpdateContext(updateType: .boundsChange, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
            item.update(renderable, context)
            let view = try (renderable.view).unwrap()
            let viewLookup = DynamicLookup(view)
            expect((viewLookup.property("handlers") as? [AnyHashable: Any])?.count) == 0 // doesn't update
            expect((viewLookup.property("installedGestureRecognizers") as? [AnyHashable: Any])?.count) == 0 // doesn't update
          }
        }
      }

      expect(item.willRemove) == nil
      expect(item.didRemove) == nil
      expect(item.transition) == nil
      expect(item.animationTiming) == nil
    }

    // when: visible bounds does not intersect with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 100, width: 100, height: 100)
      let items = node.renderableItems(in: visibleBounds)

      // then: no items are provided
      expect(items.count) == 0
    }
  }

  func test_renderableItemsBoundingRect() {
    // given: a layout context
    let context = ComposeNodeLayoutContext(scaleFactor: 1)

    // when: laying out a node whose child items are within the node's bounds
    do {
      var node = ColorNode(.red).frame(width: 100, height: 50).onTap { _ in }
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the bounding rect is the child items rect
      expect(node.renderableItemsBoundingRect) == CGRect(x: 0, y: 0, width: 100, height: 50)
    }

    // when: laying out a node whose child items are outside of the node's bounds
    do {
      var node = ColorNode(.red).frame(width: 50, height: 50).offset(x: -10, y: -10).onTap { _ in }
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the bounding rect should include both the child items rect and the gesture overlay (the node's bounds)
      expect(node.renderableItemsBoundingRect) == CGRect(x: -10, y: -10, width: 60, height: 60)
    }

    // when: laying out a node whose child has no renderable items
    do {
      var node = Spacer().onTap { _ in }
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the node provides no items, including the gesture overlay
      expect(node.renderableItemsBoundingRect.isNull) == true
    }
  }

  // MARK: - Gesture Handler Coalescing Tests

  func test_gestureHandlerCoalescing() {
    // given: a laid out node with tap and press handlers
    let baseNode = LayerNode().frame(width: 100, height: 50)

    var tapCallCount = 0
    var pressCallCount = 0

    var gestureNode = baseNode
      .onTap { _ in tapCallCount += 1 }
      .onPress { _ in pressCallCount += 1 }

    let containerSize = CGSize(width: 200, height: 100)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)
    gestureNode.layout(containerSize: containerSize, context: context)

    // when: requesting renderable items
    let renderableItems = gestureNode.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    // then: should still only have base node items + single gesture overlay view
    expect(renderableItems.count) == 2

    // then: the gesture overlay should handle both gestures
    let gestureItem = renderableItems.last
    expect(gestureItem?.id) == .standard(.gesture)
  }

  func test_multipleGestureCoalescing() {
    // given: a laid out node with multiple gesture handlers
    let baseNode = LayerNode().frame(width: 100, height: 50)

    var gestureNode = baseNode
      .onTap(count: 1) { _ in }
      .onTap(count: 2) { _ in }
      .onPress(duration: 0.5) { _ in }
      .onPan { _ in }

    let containerSize = CGSize(width: 200, height: 100)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)
    gestureNode.layout(containerSize: containerSize, context: context)

    // when: requesting renderable items
    let renderableItems = gestureNode.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    // then: should still only have base node items + single gesture overlay view
    expect(renderableItems.count) == 2
  }

  // MARK: - Integration Tests

  func test_gestureRecognizer() throws {
    // given: a compose view in a test window with a tap gesture
    var optionalGestureView: View?

    let testWindow = TestWindow()
    let view = ComposeView {
      LayerNode()
        .onTap { _ in }
        .onUpdate { renderable, _ in
          if let view = renderable.view {
            optionalGestureView = view
          }
        }
    }

    testWindow.contentView().addSubview(view)
    view.frame = testWindow.contentView().bounds

    // when: the view is refreshed
    view.refresh()

    // then: the tap gesture is installed
    do {
      let gestureView = try optionalGestureView.unwrap()

      let installedGestureRecognizers = try (DynamicLookup(gestureView).keyPath("installedGestureRecognizers") as? [AnyHashable: Any]).unwrap()
      expect(installedGestureRecognizers.count) == 1

      let handlers = try (DynamicLookup(gestureView).keyPath("handlers") as? [AnyHashable: Any]).unwrap()
      expect(handlers.count) == 1
    }

    // when: refresh with multiple gestures
    view.setContent {
      LayerNode()
        .onTap { _ in }
        .onPress { _ in }
        .onPan { _ in }
    }

    view.refresh()

    // then: the multiple gestures are installed
    do {
      let gestureView = try optionalGestureView.unwrap()

      let installedGestureRecognizers = try (DynamicLookup(gestureView).keyPath("installedGestureRecognizers") as? [AnyHashable: Any]).unwrap()
      expect(installedGestureRecognizers.count) == 3

      let handlers = try (DynamicLookup(gestureView).keyPath("handlers") as? [AnyHashable: Any]).unwrap()
      expect(handlers.count) == 3
    }
  }
}
