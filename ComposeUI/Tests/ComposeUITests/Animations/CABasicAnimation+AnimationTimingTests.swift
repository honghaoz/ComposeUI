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

import ChouTiTest

@_spi(Private) @testable import ComposeUI

class CABasicAnimation_AnimationTimingTests: XCTestCase {

  func test_makeAnimation() {
    // when: making an animation with a timing function timing
    do {
      let animation = CABasicAnimation.makeAnimation(AnimationTiming.easeInEaseOut())

      // then: the animation uses the timing function with default duration, speed, and fill mode
      expect(animation.timingFunction) == CAMediaTimingFunction(name: .easeInEaseOut)
      expect(animation.duration) == Animations.defaultAnimationDuration
      expect(animation.speed) == 1
      expect(animation.fillMode) == .both
    }

    // when: making an animation with a spring timing
    do {
      let timing = AnimationTiming.spring(dampingRatio: 0.5, response: 0.5, initialVelocity: 0.1, duration: nil, delay: 1, speed: 2)
      let animation = CABasicAnimation.makeAnimation(timing)

      // then: the animation is a spring animation with derived spring values, speed, and fill mode
      let springAnimation = try unwrap(animation as? CASpringAnimation)
      expect(springAnimation.initialVelocity) == 0.1
      expect(springAnimation.mass) == 1
      expect(springAnimation.damping) == 12.566370614359172
      expect(springAnimation.stiffness) == 157.91367041742973
      expect(springAnimation.duration) == 0.9148578261552982

      expect(springAnimation.speed) == 2
      expect(springAnimation.fillMode) == .both
    } catch {
      fail("error: \(error)")
    }
  }

  func test_makeAnimation_zeroDuration_snaps() {
    // when: making animations of a timing function and of a spring with a zero duration, at normal and at a slow speed
    let spring = AnimationTiming.Timing.spring(SpringDescriptor(dampingRatio: 1, response: 0.4), duration: 0)
    let animations = [
      CABasicAnimation.makeAnimation(.linear(duration: 0)),
      CABasicAnimation.makeAnimation(.linear(duration: 0, speed: 0.01)),
      CABasicAnimation.makeAnimation(AnimationTiming(timing: spring)),
      CABasicAnimation.makeAnimation(AnimationTiming(timing: spring, speed: 0.01)),
    ]

    // then: each lasts less than a frame at normal speed, so it lands at once, as Core Animation would run a zero
    // duration for its default duration instead, and a zero duration has no timeline for the speed to scale
    for animation in animations {
      expect(animation.duration) > 0
      expect(animation.duration) < 1.0 / 60
      expect(animation.speed) == 1
    }
    expect(animations[2] is CASpringAnimation) == true
  }
}
