//
//  StackLayoutCacheTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 6/11/26.
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

import CoreGraphics

import ChouTiTest

@testable import ComposeUI

class StackLayoutCacheTests: XCTestCase {

  func test_update_mismatchedCounts_assertion() {
    // given: a test assertion failure handler capturing the assertion
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == "mismatched child origins and bounding rects count"
      assertionCount += 1
    }

    // when: updating a cache with mismatched child origins and bounding rects counts
    var cache = StackLayoutCache()
    cache.update(
      childOrigins: [],
      childItemsBoundingRects: [CGRect(x: 0, y: 0, width: 10, height: 10)],
      mainAxis: .vertical
    )

    // then: the assertion is triggered
    expect(assertionCount) == 1

    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
  }

  func test_update_withoutMainAxis_collectsBoundingRectOnly() {
    // when: updating a cache without a main axis
    var cache = StackLayoutCache()
    cache.update(
      childOrigins: [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 10), CGPoint(x: 0, y: 20)],
      childItemsBoundingRects: [
        CGRect(x: 0, y: 0, width: 10, height: 10),
        .null, // a child with no renderable items
        CGRect(x: 0, y: 20, width: 10, height: 10),
      ],
      mainAxis: nil
    )

    // then: the child count and items bounding rect are collected
    expect(cache.childCount) == 3
    expect(cache.itemsBoundingRect) == CGRect(x: 0, y: 0, width: 10, height: 30)
  }

  func test_update_withoutMainAxis_allNullRects_boundingRectIsNull() {
    // when: updating a cache without a main axis, with all null bounding rects
    var cache = StackLayoutCache()
    cache.update(
      childOrigins: [CGPoint(x: 0, y: 0)],
      childItemsBoundingRects: [.null],
      mainAxis: nil
    )

    // then: the child count is collected and the items bounding rect is null
    expect(cache.childCount) == 1
    expect(cache.itemsBoundingRect.isNull) == true
  }

  func test_visibleChildRange_withoutMainAxis_assertsAndReturnsAllChildren() {
    // given: a cache updated without a main axis, with a test assertion failure handler
    var cache = StackLayoutCache()
    cache.update(
      childOrigins: [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 10)],
      childItemsBoundingRects: [
        CGRect(x: 0, y: 0, width: 10, height: 10),
        CGRect(x: 0, y: 10, width: 10, height: 10),
      ],
      mainAxis: nil
    )

    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == "visibleChildRange(minPosition:maxPosition:) requires the cache built with a main axis"
      assertionCount += 1
    }

    // then: the assertion is triggered and all children are returned
    // without the search structures, all children are treated as potentially visible
    expect(cache.visibleChildRange(minPosition: 0, maxPosition: 5)) == 0 ..< 2
    expect(assertionCount) == 1

    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
  }
}
