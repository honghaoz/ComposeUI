//
//  ScrollViewTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/26.
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

import ChouTiTest

import ComposeUI

class ScrollViewTests: XCTestCase {

  func test_scrollElasticity() {
    // given: a 100 × 100 scroll view whose document is half a point larger than it in both axes
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100.5, height: 100.5)

    // when: the scroll elasticity updates
    scrollView.invalidateScrollElasticity()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    // then: the document overflows, so the scroll view bounces in both axes
    expect(scrollView.horizontalScrollElasticity) == .allowed
    expect(scrollView.verticalScrollElasticity) == .allowed

    // when: the document shrinks to the scroll view's size
    scrollView.contentSize = CGSize(width: 100, height: 100)
    scrollView.invalidateScrollElasticity()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    // then: the document fits, so the scroll view doesn't bounce
    expect(scrollView.horizontalScrollElasticity) == .none
    expect(scrollView.verticalScrollElasticity) == .none

    // when: the scroll view always bounces
    scrollView.alwaysBounceHorizontal = true
    scrollView.alwaysBounceVertical = true
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    // then: the scroll view bounces in both axes even though the document fits
    expect(scrollView.horizontalScrollElasticity) == .allowed
    expect(scrollView.verticalScrollElasticity) == .allowed
  }

  func test_scrollElasticity_documentLargerByFloatingPointNoise() {
    // given: a 100 × 100 scroll view whose document is larger than it by floating-point noise in both axes
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: CGFloat(100).nextUp, height: CGFloat(100).nextUp)

    // when: the scroll elasticity updates
    scrollView.invalidateScrollElasticity()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    // then: the document fits, so the scroll view doesn't bounce
    expect(scrollView.horizontalScrollElasticity) == .none
    expect(scrollView.verticalScrollElasticity) == .none
  }
}
#endif
