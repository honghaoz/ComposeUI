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
    let baseNode = LayerNode()
    var gestureNode = baseNode.onTap { _ in }
    let containerSize = CGSize(width: 200, height: 100)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)
    gestureNode.layout(containerSize: containerSize, context: context)

    expect(gestureNode.size) == containerSize
  }

  // MARK: - Renderable Items Tests

  func test_renderableItems() {
    let baseNode = LayerNode().frame(width: 100, height: 50)
    var gestureNode = baseNode.onTap { _ in }

    let containerSize = CGSize(width: 200, height: 100)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)
    gestureNode.layout(containerSize: containerSize, context: context)

    let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
    let renderableItems = gestureNode.renderableItems(in: visibleBounds)

    // should have base node items + gesture overlay view
    expect(renderableItems.count) == 2

    // check that last item is the gesture overlay view
    let lastItem = renderableItems.last
    expect(lastItem?.id) == .standard(.gesture)
    expect(lastItem?.frame) == CGRect(origin: .zero, size: CGSize(width: 100, height: 50))
  }

  // MARK: - Gesture Handler Coalescing Tests

  func test_gestureHandlerCoalescing() {
    let baseNode = LayerNode().frame(width: 100, height: 50)

    var tapCallCount = 0
    var pressCallCount = 0

    var gestureNode = baseNode
      .onTap { _ in tapCallCount += 1 }
      .onPress { _ in pressCallCount += 1 }

    let containerSize = CGSize(width: 200, height: 100)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)
    gestureNode.layout(containerSize: containerSize, context: context)

    let renderableItems = gestureNode.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    // should still only have base node items + single gesture overlay view
    expect(renderableItems.count) == 2

    // The gesture overlay should handle both gestures
    let gestureItem = renderableItems.last
    expect(gestureItem?.id) == .standard(.gesture)
  }

  func test_multipleGestureCoalescing() {
    let baseNode = LayerNode().frame(width: 100, height: 50)

    var gestureNode = baseNode
      .onTap(count: 1) { _ in }
      .onTap(count: 2) { _ in }
      .onPress(duration: 0.5) { _ in }
      .onPan { _ in }

    let containerSize = CGSize(width: 200, height: 100)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)
    gestureNode.layout(containerSize: containerSize, context: context)

    let renderableItems = gestureNode.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    // should still only have base node items + single gesture overlay view
    expect(renderableItems.count) == 2
  }

  // MARK: - Integration Tests

  func test_gestureRecognizer() throws {
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

    view.refresh()

    // test the tap gesture is installed
    do {
      let gestureView = try optionalGestureView.unwrap()

      let installedGestureRecognizers = try (DynamicLookup(gestureView).keyPath("installedGestureRecognizers") as? [AnyHashable: Any]).unwrap()
      expect(installedGestureRecognizers.count) == 1

      let handlers = try (DynamicLookup(gestureView).keyPath("handlers") as? [AnyHashable: Any]).unwrap()
      expect(handlers.count) == 1
    }

    // refresh with multiple gestures
    view.setContent {
      LayerNode()
        .onTap { _ in }
        .onPress { _ in }
        .onPan { _ in }
    }

    view.refresh()

    // test the multiple gestures are installed
    do {
      let gestureView = try optionalGestureView.unwrap()

      let installedGestureRecognizers = try (DynamicLookup(gestureView).keyPath("installedGestureRecognizers") as? [AnyHashable: Any]).unwrap()
      expect(installedGestureRecognizers.count) == 3

      let handlers = try (DynamicLookup(gestureView).keyPath("handlers") as? [AnyHashable: Any]).unwrap()
      expect(handlers.count) == 3
    }
  }
}
