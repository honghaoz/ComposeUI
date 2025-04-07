//
//  NSView+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/7/25.
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

#if canImport(AppKit)

import ChouTiTest

@testable import ComposeUI

class NSView_ExtensionsTests: XCTestCase {

  func test_alpha() {
    let view = NSView()
    expect(view.alpha) == view.alphaValue
    view.alpha = 0.5
    expect(view.alpha) == 0.5
    expect(view.alphaValue) == 0.5
  }

  func test_updateCommonSettings() {
    let view = NSView()
    view.updateCommonSettings()

    expect(view.wantsLayer) == true
    expect(view.layer?.contentsScale) == NSScreen.main?.backingScaleFactor
    expect(view.layer?.masksToBounds) == false
  }

  func test_setNeedsLayout() {
    let view = NSView()
    view.setNeedsLayout()
    expect(view.needsLayout) == true
  }

  func test_layoutIfNeeded() {
    let view = TestView()
    view.layoutIfNeeded()
    expect(view.didLayoutSubtreeIfNeeded) == true
  }

  func test_bringSubviewToFront() {
    let view = BaseView()
    let subview1 = BaseView()
    let subview2 = BaseView()
    let subview3 = BaseView()
    view.addSubview(subview1)
    view.addSubview(subview2)
    view.addSubview(subview3)

    expect(view.subviews[0]) == subview1
    expect(view.subviews[1]) == subview2
    expect(view.subviews[2]) == subview3

    view.bringSubviewToFront(subview2)
    expect(view.subviews[0]) == subview1
    expect(view.subviews[1]) == subview3
    expect(view.subviews[2]) == subview2
  }
}

private class TestView: NSView {

  var didLayoutSubtreeIfNeeded = false
  override func layoutSubtreeIfNeeded() {
    super.layoutSubtreeIfNeeded()
    didLayoutSubtreeIfNeeded = true
  }
}

#endif
