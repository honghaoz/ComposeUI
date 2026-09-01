//
//  ScrollViewTypeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 2/20/26.
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
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import ChouTiTest

import ComposeUI

class ScrollViewTypeTests: XCTestCase {

  func test_contentInsets() {
    // given: a scroll view with a frame and content size
    let scrollView = ScrollView()
    scrollView.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
    scrollView.contentSize = CGSize(width: 300, height: 500)

    // when: setting the content insets
    scrollView.setContentInsets(EdgeInsets(top: 10, left: 20, bottom: 30, right: 40))

    // then: with automatic inset adjustment disabled, the content insets read back the set values
    #if canImport(AppKit)
    scrollView.automaticallyAdjustsContentInsets = false
    expect(scrollView.contentInsets().top) == 10
    expect(scrollView.contentInsets().left) == 20
    expect(scrollView.contentInsets().bottom) == 30
    expect(scrollView.contentInsets().right) == 40
    #endif
    #if canImport(UIKit)
    scrollView.contentInsetAdjustmentBehavior = .never
    expect(scrollView.contentInsets()) == EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)
    #endif
  }

  func test_offsets() {
    // given: a scroll view with content size and insets, automatic inset adjustment disabled
    let scrollView = ScrollView()
    scrollView.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
    scrollView.contentSize = CGSize(width: 300, height: 500)
    scrollView.setContentInsets(EdgeInsets(top: 10, left: 20, bottom: 30, right: 40))
    #if canImport(AppKit)
    scrollView.automaticallyAdjustsContentInsets = false
    #endif
    #if canImport(UIKit)
    scrollView.contentInsetAdjustmentBehavior = .never
    #endif

    // then: the min and max offsets account for the content size and insets
    expect(scrollView.minOffsetX) == -20
    expect(scrollView.maxOffsetX) == 240
    expect(scrollView.minOffsetY) == -10
    expect(scrollView.maxOffsetY) == 330
  }

  func test_canScroll() {
    // given: a scroll view with content size and insets, automatic inset adjustment disabled
    let scrollView = ScrollView()
    scrollView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    scrollView.contentSize = CGSize(width: 180, height: 220)
    scrollView.setContentInsets(EdgeInsets(top: 8, left: 6, bottom: 4, right: 2))
    #if canImport(AppKit)
    scrollView.automaticallyAdjustsContentInsets = false
    #endif
    #if canImport(UIKit)
    scrollView.contentInsetAdjustmentBehavior = .never
    #endif

    // when: scrolling to the minimum offset
    scrollView.setContentOffset(CGPoint(x: scrollView.minOffsetX, y: scrollView.minOffsetY))

    // then: it can only scroll to the right and to the bottom
    expect(scrollView.canScrollToLeft) == false
    expect(scrollView.canScrollToRight) == true
    expect(scrollView.canScrollToTop) == false
    expect(scrollView.canScrollToBottom) == true

    // when: scrolling to the maximum offset
    scrollView.setContentOffset(CGPoint(x: scrollView.maxOffsetX, y: scrollView.maxOffsetY))

    // then: it can only scroll to the left and to the top
    expect(scrollView.canScrollToLeft) == true
    expect(scrollView.canScrollToRight) == false
    expect(scrollView.canScrollToTop) == true
    expect(scrollView.canScrollToBottom) == false
  }
}
