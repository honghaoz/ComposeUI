//
//  CAAnimation+BeginTimeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/27/26.
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

import QuartzCore

import ChouTiTest

@testable import ComposeUI

class CAAnimation_BeginTimeTests: XCTestCase {

  func test_beginTime() {
    // then: an animation added at a time begins at it, or the delay after it
    expect(CAAnimation.beginTime(at: 100)) == 100
    expect(CAAnimation.beginTime(at: 100, delay: 0.5)) == 100.5
  }

  func test_beginTime_nonpositiveDelay_isNoDelay() {
    // then: a delay of zero or less, a negative infinity included, which `AnimationTiming` keeps, is no delay, instead of
    // a begin time in the past
    expect(CAAnimation.beginTime(at: 100, delay: 0)) == 100
    expect(CAAnimation.beginTime(at: 100, delay: -0.5)) == 100
    expect(CAAnimation.beginTime(at: 100, delay: -.infinity)) == 100
  }

  func test_beginTime_onZero_isTheLeastPositiveTime() {
    // then: a begin time that falls on zero, which Core Animation takes as unset, is the least positive time instead,
    // whether it's the time itself or the time plus the delay, and a negative begin time is kept
    expect(CAAnimation.beginTime(at: 0)) == .leastNormalMagnitude
    expect(CAAnimation.beginTime(at: -0.5, delay: 0.5)) == .leastNormalMagnitude
    expect(CAAnimation.beginTime(at: -0.5)) == -0.5
  }
}
