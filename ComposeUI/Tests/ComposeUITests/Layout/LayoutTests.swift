//
//  LayoutTests.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
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

class LayoutTests: XCTestCase {

  func test_emptyNodes() {
    // when proposed space is positive
    do {
      let result = Layout.stackLayout(space: 100, items: [])
      XCTAssertEqual(result, [])
    }

    // when proposed space is zero
    do {
      let result = Layout.stackLayout(space: 0, items: [])
      XCTAssertEqual(result, [])
    }

    // when proposed space is negative
    do {
      let result = Layout.stackLayout(space: -100, items: [])
      XCTAssertEqual(result, [])
    }
  }

  func test_fixedNodes() {
    let items: [ComposeNodeSizing.Sizing] = [.fixed(30), .fixed(40), .fixed(50)]

    // when proposed space is larger enough
    do {
      let result = Layout.stackLayout(space: 200, items: items)
      XCTAssertEqual(result, [30, 40, 50])
    }

    // when proposed space is just enough
    do {
      let result = Layout.stackLayout(space: 100, items: items)
      XCTAssertEqual(result, [30, 40, 50])
    }

    // when proposed space is not enough
    do {
      let result = Layout.stackLayout(space: 90, items: items)
      XCTAssertEqual(result, [30, 40, 50])
    }

    // when proposed space is zero
    do {
      let result = Layout.stackLayout(space: 0, items: items)
      XCTAssertEqual(result, [30, 40, 50])
    }

    // when proposed space is negative
    do {
      let result = Layout.stackLayout(space: -100, items: items)
      XCTAssertEqual(result, [30, 40, 50])
    }
  }

  func test_flexibleNodes() {
    let items: [ComposeNodeSizing.Sizing] = [.flexible, .flexible, .flexible]

    // when proposed space is positive
    do {
      let result = Layout.stackLayout(space: 90, items: items)
      XCTAssertEqual(result, [30, 30, 30])
    }

    // when proposed space is zero
    do {
      let result = Layout.stackLayout(space: 0, items: items)
      XCTAssertEqual(result, [0, 0, 0])
    }

    // when proposed space is negative
    do {
      let result = Layout.stackLayout(space: -100, items: items)
      XCTAssertEqual(result, [0, 0, 0])
    }
  }

  func test_rangeNodes() {
    let items: [ComposeNodeSizing.Sizing] = [
      .range(min: 10, max: 40),
      .range(min: 20, max: 50),
      .range(min: 30, max: 60),
    ]

    // when proposed space is larger than the sum of all max sizes
    do {
      let result = Layout.stackLayout(space: 200, items: items)
      XCTAssertEqual(result, [40, 50, 60], "should allocate to the max size")
    }

    // when proposed space is equal to the sum of all max sizes
    do {
      let result = Layout.stackLayout(space: 150, items: items)
      XCTAssertEqual(result, [40, 50, 60], "should allocate to the max size")
    }

    // when proposed space is between the sum of all min sizes and the sum of all max sizes
    do {
      let result = Layout.stackLayout(space: 90, items: items)
      XCTAssertEqual(result, [20, 30, 40], "should allocate the extra space evenly")
    }

    // when proposed space is equal to the sum of all min sizes
    do {
      let result = Layout.stackLayout(space: 60, items: items)
      XCTAssertEqual(result, [10, 20, 30], "should allocate to the min size")
    }

    // when proposed space is less than the sum of all min sizes
    do {
      let result = Layout.stackLayout(space: 40, items: items)
      XCTAssertEqual(result, [10, 20, 30], "should allocate to the min size")
    }

    // when proposed space is zero
    do {
      let result = Layout.stackLayout(space: 0, items: items)
      XCTAssertEqual(result, [10, 20, 30], "should allocate to the min size")
    }

    // when proposed space is negative
    do {
      let result = Layout.stackLayout(space: -100, items: items)
      XCTAssertEqual(result, [10, 20, 30], "should allocate to the min size")
    }
  }

  func test_fixedNodes_with_flexibleNodes1() {
    let items: [ComposeNodeSizing.Sizing] = [
      .fixed(20),
      .flexible,
    ]

    // when proposed space is larger than the fixed size
    do {
      let result = Layout.stackLayout(space: 100, items: items)
      XCTAssertEqual(result, [20, 80])
    }

    // when proposed space is equal to the fixed size
    do {
      let result = Layout.stackLayout(space: 20, items: items)
      XCTAssertEqual(result, [20, 0])
    }

    // when proposed space is less than the fixed size
    do {
      let result = Layout.stackLayout(space: 10, items: items)
      XCTAssertEqual(result, [20, 0])
    }

    // when proposed space is zero
    do {
      let result = Layout.stackLayout(space: 0, items: items)
      XCTAssertEqual(result, [20, 0])
    }

    // when proposed space is negative
    do {
      let result = Layout.stackLayout(space: -100, items: items)
      XCTAssertEqual(result, [20, 0])
    }
  }

  func test_fixedNodes_with_flexibleNodes2() {
    let items: [ComposeNodeSizing.Sizing] = [
      .flexible,
      .fixed(20),
      .flexible,
    ]

    // when proposed space is larger than the fixed size
    do {
      let result = Layout.stackLayout(space: 100, items: items)
      XCTAssertEqual(result, [40, 20, 40])
    }

    // when proposed space is equal to the fixed size
    do {
      let result = Layout.stackLayout(space: 20, items: items)
      XCTAssertEqual(result, [0, 20, 0])
    }

    // when proposed space is less than the fixed size
    do {
      let result = Layout.stackLayout(space: 10, items: items)
      XCTAssertEqual(result, [0, 20, 0])
    }

    // when proposed space is zero
    do {
      let result = Layout.stackLayout(space: 0, items: items)
      XCTAssertEqual(result, [0, 20, 0])
    }

    // when proposed space is negative
    do {
      let result = Layout.stackLayout(space: -100, items: items)
      XCTAssertEqual(result, [0, 20, 0])
    }
  }

  func test_fixedNodes_with_rangeNodes1() {
    let items: [ComposeNodeSizing.Sizing] = [
      .fixed(20),
      .range(min: 10, max: 30),
    ]

    // when proposed space is larger than the fixed size + max size
    do {
      let result = Layout.stackLayout(space: 100, items: items)
      XCTAssertEqual(result, [20, 30], "should allocate to the max size")
    }

    // when proposed space is equal to the fixed size + max size
    do {
      let result = Layout.stackLayout(space: 50, items: items)
      XCTAssertEqual(result, [20, 30], "should allocate to the max size")
    }

    // when proposed space is between the fixed size + min size and the fixed size + max size
    do {
      let result = Layout.stackLayout(space: 40, items: items)
      XCTAssertEqual(result, [20, 20])
    }

    // when proposed space is equal to the fixed size + min size
    do {
      let result = Layout.stackLayout(space: 30, items: items)
      XCTAssertEqual(result, [20, 10], "should allocate to the min size")
    }

    // when proposed space is less than the fixed size + min size
    do {
      let result = Layout.stackLayout(space: 20, items: items)
      XCTAssertEqual(result, [20, 10], "should allocate to the min size")
    }

    // when proposed space is zero
    do {
      let result = Layout.stackLayout(space: 0, items: items)
      XCTAssertEqual(result, [20, 10], "should allocate to the min size")
    }

    // when proposed space is negative
    do {
      let result = Layout.stackLayout(space: -100, items: items)
      XCTAssertEqual(result, [20, 10], "should allocate to the min size")
    }
  }

  func test_fixedNodes_with_rangeNodes2() {
    let items: [ComposeNodeSizing.Sizing] = [
      .fixed(20),
      .range(min: 10, max: 25),
      .range(min: 20, max: 40),
    ]

    // when proposed space is larger than the max size needed
    do {
      let result = Layout.stackLayout(space: 120, items: items)
      XCTAssertEqual(result, [20, 25, 40], "should allocate to the max size")
    }

    // when proposed space is equal to the max size needed
    do {
      let result = Layout.stackLayout(space: 85, items: items)
      XCTAssertEqual(result, [20, 25, 40], "should allocate to the max size")
    }

    // when proposed space is between the min size needed and the max size needed
    do {
      let result = Layout.stackLayout(space: 83, items: items)
      // extra space: 33
      // 33 / 2 = 16.5
      // node 2 doesn't need the extra space, should allocate more to node 3
      XCTAssertEqual(result, [20, 25, 38])
    }
    do {
      let result = Layout.stackLayout(space: 80, items: items)
      // extra space: 30
      // 30 / 2 = 15
      // node 2 doesn't need the extra space, should allocate more to node 3
      XCTAssertEqual(result, [20, 25, 35])
    }
    do {
      let result = Layout.stackLayout(space: 70, items: items)
      // extra space: 20
      // 20 / 2 = 10
      XCTAssertEqual(result, [20, 20, 30], "should allocate the extra space evenly")
    }
    do {
      let result = Layout.stackLayout(space: 60, items: items)
      // extra space: 10
      // 10 / 2 = 5
      XCTAssertEqual(result, [20, 15, 25], "should allocate the extra space evenly")
    }

    // when proposed space is equal to the min size needed
    do {
      let result = Layout.stackLayout(space: 50, items: items)
      XCTAssertEqual(result, [20, 10, 20], "should allocate to the min size")
    }

    // when proposed space is less than the min size needed
    do {
      let result = Layout.stackLayout(space: 40, items: items)
      XCTAssertEqual(result, [20, 10, 20], "should allocate to the min size")
    }

    // when proposed space is zero
    do {
      let result = Layout.stackLayout(space: 0, items: items)
      XCTAssertEqual(result, [20, 10, 20], "should allocate to the min size")
    }

    // when proposed space is negative
    do {
      let result = Layout.stackLayout(space: -100, items: items)
      XCTAssertEqual(result, [20, 10, 20], "should allocate to the min size")
    }
  }

  func test_flexibleNodes_with_rangeNodes() {
    let items: [ComposeNodeSizing.Sizing] = [
      .flexible,
      .range(min: 10, max: 20),
      .flexible,
      .range(min: 20, max: 40),
    ]

    do {
      let result = Layout.stackLayout(space: 120, items: items)
      // extra space: 90
      // 90 / 4 = 22.5
      XCTAssertEqual(result, [30.0, 20.0, 30.0, 40.0])
    }

    do {
      let result = Layout.stackLayout(space: 105, items: items)
      // extra space: 75
      // 75 / 4 = 18.75
      XCTAssertEqual(result, [22.5, 20.0, 22.5, 40.0])
    }

    do {
      let result = Layout.stackLayout(space: 100, items: items)
      // extra space: 70
      // 70 / 4 = 17.5
      XCTAssertEqual(result, [20.0, 20.0, 20.0, 40.0])
    }

    do {
      let result = Layout.stackLayout(space: 90, items: items)
      // extra space: 60
      // 60 / 4 = 15
      // node 2 doesn't need the extra space
      XCTAssertEqual(result, [15 + 5.0 / 3, 20.0, 15 + 5.0 / 3, 35 + 5.0 / 3])
    }

    do {
      let result = Layout.stackLayout(space: 50, items: items)
      // extra space: 20
      // 20 / 4 = 5
      XCTAssertEqual(result, [5.0, 15.0, 5.0, 25.0])
    }

    do {
      let result = Layout.stackLayout(space: 40, items: items)
      // extra space: 10
      // 10 / 4 = 2.5
      XCTAssertEqual(result, [2.5, 12.5, 2.5, 22.5])
    }

    do {
      let result = Layout.stackLayout(space: 30, items: items)
      // extra space: 0
      XCTAssertEqual(result, [0, 10, 0, 20])
    }

    do {
      let result = Layout.stackLayout(space: 20, items: items)
      XCTAssertEqual(result, [0, 10, 0, 20])
    }

    do {
      let result = Layout.stackLayout(space: 0, items: items)
      XCTAssertEqual(result, [0, 10, 0, 20])
    }

    do {
      let result = Layout.stackLayout(space: -100, items: items)
      XCTAssertEqual(result, [0, 10, 0, 20])
    }
  }

  func test_mixedNodes1() {
    let items: [ComposeNodeSizing.Sizing] = [
      .fixed(20),
      .range(min: 10, max: 30),
      .flexible,
      .range(min: 15, max: 25),
    ]

    do {
      let result = Layout.stackLayout(space: 100, items: items)
      XCTAssertEqual(result, [20, 30, 25, 25])
    }

    do {
      let result = Layout.stackLayout(space: 75, items: items)
      XCTAssertEqual(result, [20, 20, 10, 25])
    }

    do {
      let result = Layout.stackLayout(space: 50, items: items)
      XCTAssertEqual(result, [20, 10 + 5.0 / 3, 5.0 / 3, 15 + 5.0 / 3])
    }

    do {
      let result = Layout.stackLayout(space: 45, items: items)
      XCTAssertEqual(result, [20, 10, 0, 15])
    }

    do {
      let result = Layout.stackLayout(space: 30, items: items)
      XCTAssertEqual(result, [20, 10, 0, 15])
    }

    do {
      let result = Layout.stackLayout(space: 0, items: items)
      XCTAssertEqual(result, [20, 10, 0, 15])
    }

    do {
      let result = Layout.stackLayout(space: -100, items: items)
      XCTAssertEqual(result, [20, 10, 0, 15])
    }
  }
}
