//
//  UIScrollView+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 2/22/26.
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

import UIKit
import XCTest

@testable import ComposeUI

class UIScrollView_ExtensionsTests: XCTestCase {

  func test_offsets() {
    let scrollView = UIScrollView()
    scrollView.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
    scrollView.contentSize = CGSize(width: 300, height: 500)
    scrollView.contentInset = UIEdgeInsets(top: 10, left: 20, bottom: 30, right: 40)
    scrollView.contentInsetAdjustmentBehavior = .never

    XCTAssertEqual(scrollView.minOffsetX, -20)
    XCTAssertEqual(scrollView.maxOffsetX, 240)
    XCTAssertEqual(scrollView.minOffsetY, -10)
    XCTAssertEqual(scrollView.maxOffsetY, 330)
  }

  func test_canScroll() {
    let scrollView = UIScrollView()
    scrollView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    scrollView.contentSize = CGSize(width: 180, height: 220)
    scrollView.contentInset = UIEdgeInsets(top: 8, left: 6, bottom: 4, right: 2)
    scrollView.contentInsetAdjustmentBehavior = .never

    scrollView.contentOffset = CGPoint(x: scrollView.minOffsetX, y: scrollView.minOffsetY)
    XCTAssertFalse(scrollView.canScrollToLeft)
    XCTAssertTrue(scrollView.canScrollToRight)
    XCTAssertFalse(scrollView.canScrollToTop)
    XCTAssertTrue(scrollView.canScrollToBottom)

    scrollView.contentOffset = CGPoint(x: scrollView.maxOffsetX, y: scrollView.maxOffsetY)
    XCTAssertTrue(scrollView.canScrollToLeft)
    XCTAssertFalse(scrollView.canScrollToRight)
    XCTAssertTrue(scrollView.canScrollToTop)
    XCTAssertFalse(scrollView.canScrollToBottom)
  }
}
