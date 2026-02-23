//
//  ComposeView+WindowChangeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/3/25.
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
import Foundation

@testable import ComposeUI

class ComposeView_WindowChangeTests: XCTestCase {

  func test_windowDidChange() throws {
    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let window = TestWindow()
    window.contentScaleFactor = 1

    var renderCount = 0
    var refreshCount = 0
    var isAnimated: Bool?
    let view = ComposeView {
      renderCount += 1
      LayerNode()
        .animation(.linear())
        .onUpdate { _, context in
          isAnimated = context.animationTiming != nil
          refreshCount += 1
        }
    }

    view.frame = frame
    window.addSubview(view)

    XCTAssertEqual(renderCount, 0)
    XCTAssertEqual(refreshCount, 0)
    XCTAssertEventuallyEqual(renderCount, 1)
    XCTAssertEqual(refreshCount, 1)
    XCTAssertEqual(isAnimated, false)
    isAnimated = nil

    view.removeFromSuperview()
    XCTAssertEqual(renderCount, 1)
    XCTAssertEqual(refreshCount, 1)

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3)) // flush the pending refresh
    XCTAssertEqual(renderCount, 1) // setting window to nil should not trigger a new render
    XCTAssertEqual(refreshCount, 1)

    window.addSubview(view)
    XCTAssertEqual(renderCount, 1)
    XCTAssertEventuallyEqual(renderCount, 2) // adding to the same window again should trigger a new render
    XCTAssertEqual(refreshCount, 2)
    XCTAssertEqual(isAnimated, false)
    isAnimated = nil

    let window2 = TestWindow()
    window.contentScaleFactor = 4
    window2.addSubview(view)
    XCTAssertEqual(renderCount, 2)
    XCTAssertEventuallyEqual(renderCount, 3) // adding to a different window should trigger a new render
    XCTAssertEqual(refreshCount, 3)
    XCTAssertEqual(isAnimated, false)
    isAnimated = nil
  }
}
