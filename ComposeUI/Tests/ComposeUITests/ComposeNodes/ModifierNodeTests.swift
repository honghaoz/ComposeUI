//
//  ModifierNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/17/24.
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

import ComposeUI

class ModifierNodeTests: XCTestCase {

  func test_lifeCycleCalls() {
    // given many modifiers
    var willInsertCalls: [String] = []
    var didInsertCalls: [String] = []
    var willUpdateCalls: [String] = []
    var updateCalls: [String] = []
    var willRemoveCalls: [String] = []
    var didRemoveCalls: [String] = []

    let node = ViewNode()
      .willInsert { _, _ in willInsertCalls.append("first") }
      .onInsert { _, _ in didInsertCalls.append("first") }
      .willUpdate { _, _ in willUpdateCalls.append("first") }
      .onUpdate { _, _ in updateCalls.append("first") }
      .willRemove { _, _ in willRemoveCalls.append("first") }
      .onRemove { _, _ in didRemoveCalls.append("first") }
      .willInsert { _, _ in willInsertCalls.append("second") }
      .onInsert { _, _ in didInsertCalls.append("second") }
      .willUpdate { _, _ in willUpdateCalls.append("second") }
      .onUpdate { _, _ in updateCalls.append("second") }
      .willRemove { _, _ in willRemoveCalls.append("second") }
      .onRemove { _, _ in didRemoveCalls.append("second") }

    // expect modifiers are coalescing
    expect(
      String(describing: node).hasPrefix("ModifierNode(node: ComposeUI.ViewNode<")
    ) == true

    // when the compose view is refreshed
    let composeView = ComposeView { node }
    composeView.frame = CGRect(x: 0, y: 0, width: 500, height: 500)

    composeView.refresh(animated: false)

    // then the modifier calls are called in order
    expect(willInsertCalls) == ["first", "second"]
    expect(didInsertCalls) == ["first", "second"]
    expect(willUpdateCalls) == ["first", "second"]
    expect(updateCalls) == ["first", "second"]
    expect(willRemoveCalls) == []
    expect(didRemoveCalls) == []

    // when the content removed
    composeView.setContent { Empty() }
    composeView.refresh(animated: false)

    // then the remove modifier calls are called in order
    expect(willInsertCalls) == ["first", "second"]
    expect(didInsertCalls) == ["first", "second"]
    expect(willUpdateCalls) == ["first", "second"]
    expect(updateCalls) == ["first", "second"]
    expect(willRemoveCalls) == ["first", "second"]
    expect(didRemoveCalls) == ["first", "second"]
  }

  // MARK: - Animation and Transition Priority

  func test_animationAndTransitionPriority() {
    let expectation = expectation(description: "animation")

    // given a view node with multiple animations
    var updateCount = 0
    let node = ViewNode()
      .animation(.easeInEaseOut(duration: 1))
      .animation(.easeInEaseOut(duration: 2))
      .onUpdate { View, context in
        updateCount += 1
        switch updateCount {
        case 1:
          // initial insert update
          expect(context.animationTiming) == nil
        case 2:
          // then the inner animation is used
          expect(
            context.animationTiming?.timing
          ) == .timingFunction(1, CAMediaTimingFunction(name: .easeInEaseOut))
          expectation.fulfill()
        default:
          fail("Unexpected update count: \(updateCount)")
        }
      }

    // when the compose view is refreshed
    let composeView = ComposeView { node }
    composeView.frame = CGRect(x: 0, y: 0, width: 500, height: 500)

    composeView.refresh(animated: true)
    composeView.refresh(animated: true)

    wait(for: [expectation], timeout: 1)
  }

  // MARK: - Rasterization

  func test_rasterize() {
    var layer: CALayer?
    let contentView = ComposeView {
      LayerNode()
        .rasterize(nil)
        .onInsert { renderable, _ in
          layer = renderable.layer
        }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    contentView.refresh()

    expect(layer?.shouldRasterize) == false
    expect(layer?.rasterizationScale) == 1

    contentView.setContent {
      LayerNode()
        .rasterize(3)
        .onInsert { renderable, _ in
          layer = renderable.layer
        }
    }
    contentView.refresh()

    expect(layer?.shouldRasterize) == true
    expect(layer?.rasterizationScale) == 3
  }
}
