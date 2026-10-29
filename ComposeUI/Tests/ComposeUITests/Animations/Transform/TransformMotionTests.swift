//
//  TransformMotionTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/29/26.
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

@_spi(Private) @testable import ComposeUI

class TransformMotionTests: XCTestCase {

  func test_transformMotion_fromATiming_matchesTheMotionOfTheTimingsAnimation() throws {
    // given: timing functions with a delay or a speed that a `Float` doesn't hold exactly, a spring, and a timing of no
    // duration with a delay, whose animation makes a snap
    let interpolator = try unwrap(TransformInterpolator(from: CATransform3DIdentity, to: CATransform3DMakeRotation(.pi / 2, 0, 0, 1)))
    let customCurve = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
    let timings: [(name: String, timing: AnimationTiming)] = [
      ("linear", .linear(duration: 1)),
      ("ease in and out with a delay", .easeInEaseOut(duration: 0.3, delay: 0.2)),
      ("custom curve at 1.1 times the speed", AnimationTiming(timing: .timingFunction(0.5, customCurve), speed: 1.1)),
      ("spring", .spring(dampingRatio: 0.5, response: 0.4)),
      ("no duration with a delay", .linear(duration: 0, delay: 0.5)),
    ]

    for testCase in timings {
      // when: making the motion from the timing, and from the animation that the timing makes
      let motion = TransformMotion(interpolator: interpolator, timing: testCase.timing, at: 100)
      let animation = CABasicAnimation.makeAnimation(testCase.timing)
      let beginTime = CAAnimation.beginTime(at: 100, delay: testCase.timing.delay)
      let animationMotion = TransformMotion(interpolator: interpolator, animation: animation, beginTime: beginTime)

      // then: the motions begin and end at the same times, and make the same progress in between
      expect(motion.beginTime, testCase.name) == animationMotion.beginTime
      expect(motion.endTime, testCase.name) == animationMotion.endTime
      for time in [100, 100.1, 100.25, 100.4, 100.5, 101] {
        expect(motion.progress(at: time), "\(testCase.name) at \(time)") == animationMotion.progress(at: time)
      }
    }
  }
}
