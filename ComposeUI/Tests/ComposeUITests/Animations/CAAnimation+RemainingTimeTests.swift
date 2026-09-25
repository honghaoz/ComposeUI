//
//  CAAnimation+RemainingTimeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/22/26.
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

class CAAnimation_RemainingTimeTests: XCTestCase {

  func test_remainingTime_unresolvedBeginTime() {
    // given: an animation that isn't committed yet, so its begin time is unset
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.duration = 4
    expect(animation.beginTime) == 0

    // then: the animation begins at the commit, so its whole duration remains
    expect(animation.remainingTime(at: 100)) == 4

    // when: the animation runs at double speed
    animation.speed = 2

    // then: the duration is scaled by the speed
    expect(animation.remainingTime(at: 100)) == 2

    // when: the animation is paused
    animation.speed = 0

    // then: the duration stands in, as a paused animation has no end to measure to
    expect(animation.remainingTime(at: 100)) == 4
  }

  func test_remainingTime_scheduledAnimation() {
    // given: an animation scheduled one second ahead
    let now: TimeInterval = 100
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.duration = 2
    animation.beginTime = now + 1

    // then: the remaining delay counts towards the remaining time
    expect(animation.remainingTime(at: now)) == 3
  }

  func test_remainingTime_runningAnimation() {
    // given: an animation that began half a second ago
    let now: TimeInterval = 100
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.duration = 2
    animation.beginTime = now - 0.5

    // then: the time to its end remains
    expect(animation.remainingTime(at: now)) == 1.5

    // when: the animation runs at double speed
    animation.speed = 2

    // then: the scaled duration counts from the begin time
    expect(animation.remainingTime(at: now)) == 0.5
  }

  func test_remainingTime_pausedAnimation_pastItsDuration() {
    // given: a paused animation that began longer ago than its duration
    let now: TimeInterval = 100
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.duration = 2
    animation.speed = 0
    animation.beginTime = now - 5

    // then: it hasn't ended, its time is frozen, so it still counts its duration
    expect(animation.remainingTime(at: now)) == 2
  }

  func test_remainingTime_endedAnimation() {
    // given: an animation that ended a while ago
    let now: TimeInterval = 100
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.duration = 2
    animation.beginTime = now - 5

    // then: nothing remains
    expect(animation.remainingTime(at: now)) == nil

    // when: the animation ends right now
    animation.beginTime = now - 2

    // then: nothing remains either
    expect(animation.remainingTime(at: now)) == nil
  }

  func test_remainingTime_committedAnimation() throws {
    // given: a hosted layer with a committed opacity animation that has run for a while
    let testWindow = TestWindow()
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    testWindow.layer.addSublayer(layer)
    CATransaction.flush()

    let fadeAnimation = CABasicAnimation(keyPath: "opacity")
    fadeAnimation.fromValue = Float(1)
    fadeAnimation.toValue = Float(0)
    fadeAnimation.duration = 2
    layer.add(fadeAnimation, forKey: "fade")
    CATransaction.flush()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    let committedAnimation = try layer.animation(forKey: "fade").unwrap()
    expect(committedAnimation.beginTime) > 0

    // then: the time to the animation's end remains, measured from its begin time since the run loop's wait isn't exact
    let now = layer.currentTime
    let remainingTime = try committedAnimation.remainingTime(at: now).unwrap()
    expect(remainingTime).to(beApproximatelyEqual(to: committedAnimation.beginTime + 2 - now, within: 0.02))
    expect(remainingTime) < 2
  }

  func test_neverFinishes() {
    // then: Core Animation's forever and longer never finish
    expect(CAAnimation.neverFinishes(duration: TimeInterval(Float.greatestFiniteMagnitude))) == true
    expect(CAAnimation.neverFinishes(duration: .infinity)) == true

    // then: a shorter duration, or one that isn't a number, isn't forever
    expect(CAAnimation.neverFinishes(duration: TimeInterval(Float.greatestFiniteMagnitude).nextDown)) == false
    expect(CAAnimation.neverFinishes(duration: 2)) == false
    expect(CAAnimation.neverFinishes(duration: .nan)) == false
  }

  func test_neverFinishes_springWithoutDamping() {
    // given: a spring without damping, which never settles
    let animation = CABasicAnimation.makeAnimation(.spring(dampingRatio: 0, response: 0.5))

    // then: its duration is Core Animation's forever
    expect(CAAnimation.neverFinishes(duration: animation.duration)) == true
  }
}
