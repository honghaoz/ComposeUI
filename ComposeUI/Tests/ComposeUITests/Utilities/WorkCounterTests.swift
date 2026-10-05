//
//  WorkCounterTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/4/26.
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

import Foundation

import ChouTiTest

@testable import ComposeUI

class WorkCounterTests: XCTestCase {

  func test_counting_countsEachKindOfWork() {
    // when: counting a block that does each kind of work
    let counts = WorkCounter.counting {
      WorkCounter.count(.textMeasurement)
      WorkCounter.count(.animation, 2)
      WorkCounter.count(.bezierSolverStep, 3)
    }

    // then: each kind of work is counted by its amount, which is 1 by default
    expect(counts.textMeasurements) == 1
    expect(counts.animations) == 2
    expect(counts.bezierSolverSteps) == 3
  }

  func test_count_outsideCounting_countsNothing() {
    // given: work done outside of a counted block
    WorkCounter.count(.textMeasurement)
    WorkCounter.count(.animation)
    WorkCounter.count(.bezierSolverStep)

    // when: counting a block that does no work
    let counts = WorkCounter.counting {}

    // then: the earlier work isn't counted
    expect(counts.textMeasurements) == 0
    expect(counts.animations) == 0
    expect(counts.bezierSolverSteps) == 0
  }

  func test_counting_nested_countsTheNestedWorkForTheEnclosingBlock() throws {
    // when: counting a block that does work before, in and after a nested counted block
    var nestedCounts: WorkCounter.Counts?
    let counts = WorkCounter.counting {
      WorkCounter.count(.animation)
      nestedCounts = WorkCounter.counting {
        WorkCounter.count(.animation, 2)
        WorkCounter.count(.textMeasurement)
      }
      WorkCounter.count(.animation, 4)
    }

    // then: the nested block counts its own work, and the enclosing block counts all of it
    expect(try nestedCounts.unwrap().animations) == 2
    expect(try nestedCounts.unwrap().textMeasurements) == 1
    expect(counts.animations) == 7
    expect(counts.textMeasurements) == 1
  }

  func test_counting_blockThrows_rethrowsAndStopsCounting() {
    // given: a block that does work and throws
    struct TestError: Error, Equatable {}

    // when: counting the block
    expect(try WorkCounter.counting {
      WorkCounter.count(.animation)
      throw TestError()
    }).to(throwError(TestError()))

    // then: the error is thrown on, and work after the block isn't counted for the next counted block
    WorkCounter.count(.animation)
    let counts = WorkCounter.counting {}
    expect(counts.animations) == 0
  }

  func test_count_offTheMainThread_countsNothing() {
    // when: counting a block in which a background thread does work
    let counts = WorkCounter.counting {
      let workDone = XCTestExpectation(description: "work")
      DispatchQueue.global().async {
        WorkCounter.count(.animation)
        workDone.fulfill()
      }
      wait(for: [workDone], timeout: 5)
    }

    // then: the background thread's work isn't counted, as the counts are main thread state
    expect(counts.animations) == 0
  }

  func test_counting_offTheMainThread_assertsAndRunsTheBlockWithoutCounting() {
    // given: an assertion failure handler that records the messages
    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: counting a block that does work, on a background thread
    var didRunBlock = false
    var counts: WorkCounter.Counts?
    let countingDone = XCTestExpectation(description: "counting")
    DispatchQueue.global().async {
      counts = WorkCounter.counting {
        didRunBlock = true
        WorkCounter.count(.animation)
      }
      countingDone.fulfill()
    }
    wait(for: [countingDone], timeout: 5)

    // then: it asserts, runs the block, and counts nothing, as the counts are main thread state
    expect(assertionMessages) == ["counting(_:) must be called on the main thread"]
    expect(didRunBlock) == true
    expect(counts?.animations) == 0
  }
}
