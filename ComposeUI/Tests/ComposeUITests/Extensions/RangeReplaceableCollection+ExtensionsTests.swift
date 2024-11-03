//
//  RangeReplaceableCollection+ExtensionsTests.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 11/3/24.
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

class RangeReplaceableCollection_ExtensionsTests: XCTestCase {

  func testSwapRemove() {
    var array = [1, 2, 3, 4, 5]
    let removed = array.swapRemove(at: 2)
    XCTAssertEqual(removed, 3)
    XCTAssertEqual(array, [1, 2, 5, 4])
  }

  // Test correctness
  func testSwapRemoveCorrectness() {
    var array = [1, 2, 3, 4, 5]
    let removed = array.swapRemove(at: 1)

    XCTAssertEqual(removed, 2)
    XCTAssertEqual(array, [1, 5, 3, 4])
  }

  // Test edge cases
  func testSwapRemoveLastElement() {
    var array = [1, 2, 3]
    let removed = array.swapRemove(at: 2)

    XCTAssertEqual(removed, 3)
    XCTAssertEqual(array, [1, 2])
  }

  // MARK: - Performance tests

  func testPerformanceSwapRemoveBulk() {
    let size = 100000
    let array = Array(0 ..< size)

    measure {
      var testArray = array
      for i in stride(from: 0, to: size / 2, by: 1) {
        _ = testArray.swapRemove(at: i)
      }
    }
  }

  func testPerformanceRegularRemoveBulk() {
    let size = 100000
    let array = Array(0 ..< size)

    measure {
      var testArray = array
      for i in stride(from: 0, to: size / 2, by: 1) {
        _ = testArray.remove(at: i)
      }
    }
  }

  func testPerformanceSwapRemoveFirst() {
    let size = 100000
    let array = Array(0 ..< size)

    measure {
      var testArray = array
      _ = testArray.swapRemove(at: 0)
    }
  }

  func testPerformanceRegularRemoveFirst() {
    let size = 100000
    let array = Array(0 ..< size)

    measure {
      var testArray = array
      _ = testArray.remove(at: 0)
    }
  }

  func testPerformanceSwapRemoveMiddle() {
    let size = 100000
    let array = Array(0 ..< size)
    let middleIndex = size / 2

    measure {
      var testArray = array
      _ = testArray.swapRemove(at: middleIndex)
    }
  }

  func testPerformanceRegularRemoveMiddle() {
    let size = 100000
    let array = Array(0 ..< size)
    let middleIndex = size / 2

    measure {
      var testArray = array
      _ = testArray.remove(at: middleIndex)
    }
  }

  func testPerformanceSwapRemoveLast() {
    let size = 100000
    let array = Array(0 ..< size)
    let lastIndex = size - 1

    measure {
      var testArray = array
      _ = testArray.swapRemove(at: lastIndex)
    }
  }

  func testPerformanceRegularRemoveLast() {
    let size = 100000
    let array = Array(0 ..< size)
    let lastIndex = size - 1

    measure {
      var testArray = array
      _ = testArray.remove(at: lastIndex)
    }
  }

  func testPerformanceSwapRemoveContiguousArray() {
    let size = 100000
    let array = ContiguousArray(0 ..< size)
    let middleIndex = size / 2

    measure {
      var testArray = array
      _ = testArray.swapRemove(at: middleIndex)
    }
  }

  func testPerformanceRegularRemoveContiguousArray() {
    let size = 100000
    let array = ContiguousArray(0 ..< size)
    let middleIndex = size / 2

    measure {
      var testArray = array
      _ = testArray.remove(at: middleIndex)
    }
  }
}
