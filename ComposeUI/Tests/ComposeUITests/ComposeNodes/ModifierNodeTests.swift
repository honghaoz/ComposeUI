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

import XCTest
@testable import ComposeUI

final class ModifierNodeTests: XCTestCase {

  func test_calls() {
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
    XCTAssertTrue(
      String(describing: node).hasPrefix("ModifierNode(node: ComposeUI.ViewNode<")
    )

    // when the compose view is refreshed
    let composeView = ComposeView { node }
    composeView.frame = CGRect(x: 0, y: 0, width: 500, height: 500)

    composeView.refresh(animated: false)

    // then the modifier calls are called in order
    XCTAssertEqual(willInsertCalls, ["first", "second"])
    XCTAssertEqual(didInsertCalls, ["first", "second"])
    XCTAssertEqual(willUpdateCalls, ["first", "second"])
    XCTAssertEqual(updateCalls, ["first", "second"])
    XCTAssertEqual(willRemoveCalls, [])
    XCTAssertEqual(didRemoveCalls, [])

    // when the content removed
    composeView.setContent { Empty() }
    composeView.refresh(animated: false)

    // then the remove modifier calls are called in order
    XCTAssertEqual(willInsertCalls, ["first", "second"])
    XCTAssertEqual(didInsertCalls, ["first", "second"])
    XCTAssertEqual(willUpdateCalls, ["first", "second"])
    XCTAssertEqual(updateCalls, ["first", "second"])
    XCTAssertEqual(willRemoveCalls, ["first", "second"])
    XCTAssertEqual(didRemoveCalls, ["first", "second"])
  }

  // MARK: - Animation and Transition Priority

  func test_animationAndTransitionPriority() {
    let expectation = XCTestExpectation(description: "animation")

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
          XCTAssertNil(context.animationContext)
        case 2:
          // then the inner animation is used
          XCTAssertEqual(
            context.animationContext?.timing.timing, .timingFunction(1, CAMediaTimingFunction(name: .easeInEaseOut))
          )
          expectation.fulfill()
        default:
          XCTFail("Unexpected update count: \(updateCount)")
        }
      }

    // when the compose view is refreshed
    let composeView = ComposeView { node }
    composeView.frame = CGRect(x: 0, y: 0, width: 500, height: 500)

    composeView.refresh(animated: true)
    composeView.refresh(animated: true)

    wait(for: [expectation], timeout: 1)
  }
}
