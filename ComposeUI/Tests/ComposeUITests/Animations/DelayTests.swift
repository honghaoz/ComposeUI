//
//  DelayTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/21.
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
import QuartzCore

import ChouTiTest

@testable import ComposeUI

class DelayTests: XCTestCase {

  func test_positiveDelay() {
    var isExecuted = false
    let startTime = CACurrentMediaTime()
    var delayTime: CFTimeInterval = 0
    delay(0.01) {
      let endTime = CACurrentMediaTime()
      delayTime = endTime - startTime
      expect(Thread.isMainThread) == true
      isExecuted = true
    }
    expect(isExecuted) == false
    expect(isExecuted).toEventually(beTrue(), timeout: 0.05)
    expect(delayTime).to(beApproximatelyEqual(to: 0.01, within: 1e-3))
  }

  func test_negativeDelay() {
    var isExecuted = false
    delay(-0.01) {
      expect(Thread.isMainThread) == true
      isExecuted = true
    }
    expect(isExecuted) == true
  }

  func test_zeroDelay() {
    var isExecuted = false
    delay(0) {
      expect(Thread.isMainThread) == true
      isExecuted = true
    }
    expect(isExecuted) == true
  }
}
