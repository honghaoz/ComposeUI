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

  func test_finish_withoutMainAxis_collectsBoundingRectOnly() {
    // given: a cache with 3 children appended, one of them without renderable items
    var cache = StackLayoutCache()
    cache.reset(reservingCapacity: 3)
    cache.appendChild(origin: CGPoint(x: 0, y: 0), itemsBoundingRect: CGRect(x: 0, y: 0, width: 10, height: 10))
    cache.appendChild(origin: CGPoint(x: 0, y: 10), itemsBoundingRect: .null)
    cache.appendChild(origin: CGPoint(x: 0, y: 20), itemsBoundingRect: CGRect(x: 0, y: 20, width: 10, height: 10))

    // when: finishing the cache without a main axis
    cache.finish(mainAxis: nil)

    // then: the children and the items bounding rect are collected
    expect(cache.childCount) == 3
    expect(cache.children[1].origin) == CGPoint(x: 0, y: 10)
    expect(cache.children[1].itemsBoundingRect.isNull) == true
    expect(cache.itemsBoundingRect) == CGRect(x: 0, y: 0, width: 10, height: 30)
  }

  func test_finish_withoutMainAxis_allNullRects_boundingRectIsNull() {
    // given: a cache with a child without renderable items appended
    var cache = StackLayoutCache()
    cache.reset(reservingCapacity: 1)
    cache.appendChild(origin: CGPoint(x: 0, y: 0), itemsBoundingRect: .null)

    // when: finishing the cache without a main axis
    cache.finish(mainAxis: nil)

    // then: the child is collected and the items bounding rect is null
    expect(cache.childCount) == 1
    expect(cache.itemsBoundingRect.isNull) == true
  }

  func test_visibleChildRange_withMainAxis_returnsTheChildrenInTheRange() {
    // given: a cache of 3 children 10 points tall, stacked vertically, the middle one without renderable items
    var cache = StackLayoutCache()
    cache.reset(reservingCapacity: 3)
    cache.appendChild(origin: CGPoint(x: 0, y: 0), itemsBoundingRect: CGRect(x: 0, y: 0, width: 10, height: 10))
    cache.appendChild(origin: CGPoint(x: 0, y: 10), itemsBoundingRect: .null)
    cache.appendChild(origin: CGPoint(x: 0, y: 20), itemsBoundingRect: CGRect(x: 0, y: 20, width: 10, height: 10))
    cache.finish(mainAxis: .vertical)

    // then: a visible range returns the children whose items can intersect it, and an empty range between the items
    // or past them
    expect(cache.visibleChildRange(minPosition: 0, maxPosition: 5)) == 0 ..< 1
    expect(cache.visibleChildRange(minPosition: 5, maxPosition: 25)) == 0 ..< 3
    expect(cache.visibleChildRange(minPosition: 12, maxPosition: 18)) == 2 ..< 2
    expect(cache.visibleChildRange(minPosition: 22, maxPosition: 40)) == 2 ..< 3
    expect(cache.visibleChildRange(minPosition: 30, maxPosition: 40)) == 3 ..< 3
    expect(cache.itemsBoundingRect) == CGRect(x: 0, y: 0, width: 10, height: 30)
  }

  func test_visibleChildRange_emptyCache_returnsNoChildrenWithoutAsserting() {
    // given: an empty cache, as an empty stack has, and a test assertion failure handler
    let cache = StackLayoutCache()
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { _, _, _, _ in
      assertionCount += 1
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // then: no children are returned, without an assertion, since there are no children to search
    expect(cache.visibleChildRange(minPosition: 0, maxPosition: 10)) == 0 ..< 0
    expect(assertionCount) == 0
  }

  func test_reset_removesThePreviousLayout() {
    // given: a cache of 2 children finished with a vertical main axis, and a test assertion failure handler
    var cache = StackLayoutCache()
    cache.reset(reservingCapacity: 2)
    cache.appendChild(origin: CGPoint(x: 0, y: 0), itemsBoundingRect: CGRect(x: 0, y: 0, width: 10, height: 10))
    cache.appendChild(origin: CGPoint(x: 0, y: 10), itemsBoundingRect: CGRect(x: 0, y: 10, width: 10, height: 10))
    cache.finish(mainAxis: .vertical)
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { _, _, _, _ in
      assertionCount += 1
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: rebuilding it with another child, without a main axis
    cache.reset(reservingCapacity: 1)
    cache.appendChild(origin: CGPoint(x: 5, y: 5), itemsBoundingRect: CGRect(x: 5, y: 5, width: 1, height: 1))
    cache.finish(mainAxis: nil)

    // then: only the new child and its bounding rect remain, and the previous search structures are gone
    expect(cache.childCount) == 1
    expect(cache.children[0].origin) == CGPoint(x: 5, y: 5)
    expect(cache.itemsBoundingRect) == CGRect(x: 5, y: 5, width: 1, height: 1)
    expect(cache.visibleChildRange(minPosition: 0, maxPosition: 10)) == 0 ..< 1
    expect(assertionCount) == 1
  }

  func test_visibleChildRange_withoutMainAxis_assertsAndReturnsAllChildren() {
    // given: a cache finished without a main axis, with a test assertion failure handler
    var cache = StackLayoutCache()
    cache.reset(reservingCapacity: 2)
    cache.appendChild(origin: CGPoint(x: 0, y: 0), itemsBoundingRect: CGRect(x: 0, y: 0, width: 10, height: 10))
    cache.appendChild(origin: CGPoint(x: 0, y: 10), itemsBoundingRect: CGRect(x: 0, y: 10, width: 10, height: 10))
    cache.finish(mainAxis: nil)

    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == "visibleChildRange(minPosition:maxPosition:) requires the cache built with a main axis"
      assertionCount += 1
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // then: the assertion is triggered and all children are returned
    // without the search structures, all children are treated as potentially visible
    expect(cache.visibleChildRange(minPosition: 0, maxPosition: 5)) == 0 ..< 2
    expect(assertionCount) == 1
  }
}
