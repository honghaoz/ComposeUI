//
//  CABasicAnimation+AnimationTimingTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/29/25.
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

@_spi(Private) @testable import ComposeUI

class CABasicAnimation_AnimationTimingTests: XCTestCase {

  func test_makeAnimation() {
    // timing function
    do {
      let animation = CABasicAnimation.makeAnimation(AnimationTiming.easeInEaseOut())
      XCTAssertEqual(animation.timingFunction, CAMediaTimingFunction(name: .easeInEaseOut))
      XCTAssertEqual(animation.duration, ComposeAnimations.defaultAnimationDuration)
      XCTAssertEqual(animation.speed, 1)
      XCTAssertEqual(animation.fillMode, .both)
    }

    // spring
    do {
      let timing = AnimationTiming.spring(dampingRatio: 0.5, response: 0.5, initialVelocity: 0.1, duration: nil, delay: 1, speed: 2)
      let animation = CABasicAnimation.makeAnimation(timing)

      let springAnimation = try XCTUnwrap(animation as? CASpringAnimation)
      XCTAssertEqual(springAnimation.initialVelocity, 0.1)
      XCTAssertEqual(springAnimation.mass, 1)
      XCTAssertEqual(springAnimation.damping, 12.566370614359172)
      XCTAssertEqual(springAnimation.stiffness, 157.91367041742973)
      XCTAssertEqual(springAnimation.duration, 0.9148578261552982)

      XCTAssertEqual(springAnimation.speed, 2)
      XCTAssertEqual(springAnimation.fillMode, .both)
    } catch {
      XCTFail("error: \(error)")
    }
  }
}
