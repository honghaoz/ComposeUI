//
//  RangeReplaceableCollection+ExtensionsTests.swift
//  ComposéUI
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

import ChouTiTest

@testable import ComposeUI

class RangeReplaceableCollection_ExtensionsTests: XCTestCase {

  func test_swapRemove() {
    // given: an array
    var array = [1, 2, 3, 4, 5]

    // when: swap removing an element
    let removed = array.swapRemove(at: 2)

    // then: the element is removed and the last element takes its place
    expect(removed) == 3
    expect(array) == [1, 2, 5, 4]
  }

  // Test correctness
  func test_swapRemoveCorrectness() {
    // given: an array
    var array = [1, 2, 3, 4, 5]

    // when: swap removing an element
    let removed = array.swapRemove(at: 1)

    // then: the element is removed and the last element takes its place
    expect(removed) == 2
    expect(array) == [1, 5, 3, 4]
  }

  // Test edge cases
  func test_swapRemoveLastElement() {
    // given: an array
    var array = [1, 2, 3]

    // when: swap removing the last element
    let removed = array.swapRemove(at: 2)

    // then: the element is removed and the remaining order is unchanged
    expect(removed) == 3
    expect(array) == [1, 2]
  }

  // MARK: - Performance tests

  func test_performanceSwapRemoveBulk() throws {
    // given: a large array
    try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

    let size = 100000
    let array = Array(0 ..< size)

    // when: measuring swap removing half of the elements
    measure {
      var testArray = array
      for i in stride(from: 0, to: size / 2, by: 1) {
        _ = testArray.swapRemove(at: i)
      }
    }
  }

  func test_performanceRegularRemoveBulk() throws {
    // given: a large array
    try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

    let size = 100000
    let array = Array(0 ..< size)

    // when: measuring regular removing half of the elements
    measure {
      var testArray = array
      for i in stride(from: 0, to: size / 2, by: 1) {
        _ = testArray.remove(at: i)
      }
    }
  }

  func test_performanceSwapRemoveFirst() throws {
    // given: a large array
    try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

    let size = 100000
    let array = Array(0 ..< size)

    // when: measuring swap removing the first element
    measure {
      var testArray = array
      _ = testArray.swapRemove(at: 0)
    }
  }

  func test_performanceRegularRemoveFirst() throws {
    // given: a large array
    try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

    let size = 100000
    let array = Array(0 ..< size)

    // when: measuring regular removing the first element
    measure {
      var testArray = array
      _ = testArray.remove(at: 0)
    }
  }

  func test_performanceSwapRemoveMiddle() throws {
    // given: a large array
    try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

    let size = 100000
    let array = Array(0 ..< size)
    let middleIndex = size / 2

    // when: measuring swap removing the middle element
    measure {
      var testArray = array
      _ = testArray.swapRemove(at: middleIndex)
    }
  }

  func test_performanceRegularRemoveMiddle() throws {
    // given: a large array
    try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

    let size = 100000
    let array = Array(0 ..< size)
    let middleIndex = size / 2

    // when: measuring regular removing the middle element
    measure {
      var testArray = array
      _ = testArray.remove(at: middleIndex)
    }
  }

  func test_performanceSwapRemoveLast() throws {
    // given: a large array
    try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

    let size = 100000
    let array = Array(0 ..< size)
    let lastIndex = size - 1

    // when: measuring swap removing the last element
    measure {
      var testArray = array
      _ = testArray.swapRemove(at: lastIndex)
    }
  }

  func test_performanceRegularRemoveLast() throws {
    // given: a large array
    try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

    let size = 100000
    let array = Array(0 ..< size)
    let lastIndex = size - 1

    // when: measuring regular removing the last element
    measure {
      var testArray = array
      _ = testArray.remove(at: lastIndex)
    }
  }

  func test_performanceSwapRemoveContiguousArray() throws {
    // given: a large contiguous array
    try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

    let size = 100000
    let array = ContiguousArray(0 ..< size)
    let middleIndex = size / 2

    // when: measuring swap removing the middle element
    measure {
      var testArray = array
      _ = testArray.swapRemove(at: middleIndex)
    }
  }

  func test_performanceRegularRemoveContiguousArray() throws {
    // given: a large contiguous array
    try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

    let size = 100000
    let array = ContiguousArray(0 ..< size)
    let middleIndex = size / 2

    // when: measuring regular removing the middle element
    measure {
      var testArray = array
      _ = testArray.remove(at: middleIndex)
    }
  }
}
