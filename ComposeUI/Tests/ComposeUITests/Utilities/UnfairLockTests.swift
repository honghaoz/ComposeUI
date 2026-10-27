//
//  UnfairLockTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/26/26.
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

class UnfairLockTests: XCTestCase {

  func test_withLock_returnsTheBodysResult() {
    // given: a lock
    let lock = UnfairLock()

    // then: running a body while holding it returns the body's result
    expect(lock.withLock { 42 }) == 42
  }

  func test_withLock_letsOneThreadIntoTheBodyAtATime() {
    // given: a lock, and a count that each thread reads and then writes back, which another thread's read between the
    // two would lose an addition of
    final class Count {
      var value = 0
    }
    let lock = UnfairLock()
    let count = Count()

    // when: 8 threads add to the count 10,000 times each, while holding the lock
    DispatchQueue.concurrentPerform(iterations: 8) { _ in
      for _ in 0 ..< 10000 {
        lock.withLock {
          let value = count.value
          count.value = value + 1
        }
      }
    }

    // then: no addition is lost
    expect(count.value) == 80000
  }
}
