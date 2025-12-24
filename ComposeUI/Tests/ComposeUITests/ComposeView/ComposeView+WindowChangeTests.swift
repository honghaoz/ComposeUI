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

import ChouTiTest

@testable import ComposeUI

class ComposeView_WindowChangeTests: XCTestCase {

  func test_windowDidChange() throws {
    #if os(visionOS)
    throw XCTSkip("visionOS on CI machines may hang when creating a UIWindow.")
    #endif

    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let window = TestWindow()
    #if canImport(UIKit)
    window.contentScaleFactor = 1
    #endif

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
    #if canImport(AppKit)
    window.contentView?.addSubview(view)
    #endif
    #if canImport(UIKit)
    window.addSubview(view)
    #endif

    expect(renderCount) == 0
    expect(refreshCount) == 0
    expect(renderCount).toEventually(beEqual(to: 1))
    expect(refreshCount) == 1
    expect(isAnimated) == false
    isAnimated = nil

    view.removeFromSuperview()
    expect(renderCount) == 1
    expect(refreshCount) == 1

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3)) // flush the pending refresh
    expect(renderCount) == 1 // setting window to nil should not trigger a new render
    expect(refreshCount) == 1

    #if canImport(AppKit)
    window.contentView?.addSubview(view)
    #endif
    #if canImport(UIKit)
    window.addSubview(view)
    #endif
    expect(renderCount) == 1
    expect(renderCount).toEventually(beEqual(to: 2)) // adding to the same window again should trigger a new render
    expect(refreshCount) == 2
    expect(isAnimated) == false
    isAnimated = nil

    let window2 = TestWindow()
    #if canImport(UIKit)
    window.contentScaleFactor = 4
    #endif

    #if canImport(AppKit)
    window2.contentView?.addSubview(view)
    #endif
    #if canImport(UIKit)
    window2.addSubview(view)
    #endif
    expect(renderCount) == 2
    expect(renderCount).toEventually(beEqual(to: 3)) // adding to a different window should trigger a new render
    expect(refreshCount) == 3
    expect(isAnimated) == false
    isAnimated = nil
  }
}
