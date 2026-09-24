//
//  AnimationCurveTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/24/26.
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

class AnimationCurveTests: XCTestCase {

  func test_init_readsTheAnimationOnce() {
    // given: the curve of an ease in animation of two seconds
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.duration = 2
    animation.timingFunction = CAMediaTimingFunction(name: .easeIn)
    let curve = AnimationCurve(animation)
    let progress = curve.progress(forElapsedTime: 0.5)

    // when: the animation changes afterwards
    animation.duration = 4
    animation.timingFunction = CAMediaTimingFunction(name: .linear)

    // then: the curve keeps what it read
    expect(curve.duration) == 2
    expect(curve.progress(forElapsedTime: 0.5)) == progress
    expect(progress) < 0.25
  }

  func test_init_timingFunction() {
    // given: the curve of an ease in timing function, and the curve of an ease in animation of one second
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.duration = 1
    animation.timingFunction = CAMediaTimingFunction(name: .easeIn)

    // when: reading the curve of the timing function alone
    let curve = AnimationCurve(timingFunction: CAMediaTimingFunction(name: .easeIn))

    // then: it lasts one second, so a time is a fraction, and it matches the animation's curve
    expect(curve.duration) == 1
    expect(curve.progress(forElapsedTime: 0.3)) == curve.progress(atFraction: 0.3)
    expect(curve.progress(atFraction: 0.3)) == AnimationCurve(animation).progress(atFraction: 0.3)
  }

  func test_progress_linear() {
    // given: the curves of an animation without a timing function, and of an animation with a diagonal timing function
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.duration = 2
    let withoutTimingFunction = AnimationCurve(animation)
    animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.3, 0.3, 0.8, 0.8)
    let diagonal = AnimationCurve(animation)

    // then: both are linear, exactly, since a linear curve isn't solved
    for curve in [withoutTimingFunction, diagonal] {
      expect(curve.progress(forElapsedTime: 0.5)) == 0.25
      expect(curve.progress(forElapsedTime: 1)) == 0.5
    }

    // then: the elapsed time is clamped to the duration
    expect(withoutTimingFunction.progress(forElapsedTime: -1)) == 0
    expect(withoutTimingFunction.progress(forElapsedTime: 3)) == 1
  }

  func test_progress_cubicBezier() {
    // given: the curve of an ease in ease out timing function
    let curve = AnimationCurve(timingFunction: CAMediaTimingFunction(name: .easeInEaseOut))

    // then: it starts at zero and ends at one, exactly, also for fractions outside of the curve
    expect(curve.progress(atFraction: -0.5)) == 0
    expect(curve.progress(atFraction: 0)) == 0
    expect(curve.progress(atFraction: 1)) == 1
    expect(curve.progress(atFraction: 1.5)) == 1

    // then: it is symmetric, slower than linear at the start, and faster than linear near the end
    expect(curve.progress(atFraction: 0.5)).to(beApproximatelyEqual(to: 0.5, within: 1e-6))
    expect(curve.progress(atFraction: 0.25)) < 0.25
    expect(curve.progress(atFraction: 0.75)) > 0.75
  }

  func test_progress_cubicBezier_flatInflection() {
    // given: the curve of control points (1, 0) and (0, 1), whose x stalls in the middle: x(t) = 0.5 + 0.5(2t - 1)³
    let curve = AnimationCurve(timingFunction: CAMediaTimingFunction(controlPoints: 1, 0, 0, 1))

    // then: the progress matches the exact inverse, t = 0.5 + ∛(2(x - 0.5)) / 2 and y(t) = 3t² - 2t³, also right by the
    // stall, where a tiny difference in x is a large difference in t
    for fraction in [0.1, 0.4, 0.5 - 1e-3, 0.5 - 1e-9, 0.5, 0.5 + 1e-9, 0.5 + 1e-3, 0.6, 0.9] {
      let t = 0.5 + cbrt(2 * (fraction - 0.5)) / 2
      expect(curve.progress(atFraction: fraction)).to(beApproximatelyEqual(to: 3 * t * t - 2 * t * t * t, within: 1e-8))
    }
  }

  func test_progress_cubicBezier_flatEnds() {
    // given: the curve of control points (0, 1) and (1, 0), whose x starts and ends flat
    let curve = AnimationCurve(timingFunction: CAMediaTimingFunction(controlPoints: 0, 1, 1, 0))

    // then: the progress at the x of a point on the curve is the y of the point, near the flat ends too
    for t in [0.001, 0.01, 0.05, 0.3, 0.7, 0.95, 0.99, 0.999] {
      let x = 3 * t * t - 2 * t * t * t
      let y = 3 * (1 - t) * (1 - t) * t + t * t * t
      expect(curve.progress(atFraction: x)).to(beApproximatelyEqual(to: y, within: 1e-9))
    }
  }

  func test_progress_zeroDuration() {
    // given: the curve of an animation without a duration
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.duration = 0
    let curve = AnimationCurve(animation)

    // then: it has landed at any time
    expect(curve.progress(forElapsedTime: 0)) == 1
    expect(curve.progress(forElapsedTime: 10)) == 1
  }

  func test_progress_spring_underdamped_overshoots() throws {
    // given: the curve of a lightly damped spring
    let animation = try makeSpring(stiffness: 100, damping: 4)
    let curve = AnimationCurve(animation)

    // when: sampling the curve over the spring's duration
    let samples = stride(from: 0.0, through: animation.duration, by: 0.01).map { curve.progress(forElapsedTime: $0) }

    // then: it starts at zero, passes one, and settles at one
    expect(samples.first) == 0
    expect(try samples.max().unwrap()) > 1
    expect(try samples.last.unwrap()).to(beApproximatelyEqual(to: 1, within: 0.01))
  }

  func test_progress_spring_criticallyDamped_doesNotOvershoot() throws {
    // given: the curve of a critically damped spring
    let animation = try makeSpring(stiffness: 100, damping: 20)
    let curve = AnimationCurve(animation)

    // when: sampling the curve over the spring's duration
    let samples = stride(from: 0.0, through: animation.duration, by: 0.01).map { curve.progress(forElapsedTime: $0) }

    // then: it rises from zero to one without passing it
    expect(samples.first) == 0
    expect(zip(samples, samples.dropFirst()).allSatisfy { $0 <= $1 }) == true
    expect(try samples.max().unwrap()) <= 1
    expect(try samples.last.unwrap()).to(beApproximatelyEqual(to: 1, within: 0.01))
  }

  func test_progress_spring_overdamped_isCriticallyDamped() throws {
    // given: the curves of a critically damped spring and of an overdamped spring with the same stiffness
    let critical = try AnimationCurve(makeSpring(stiffness: 100, damping: 20, duration: 2))
    let overdamped = try AnimationCurve(makeSpring(stiffness: 100, damping: 30, duration: 2))

    // then: Core Animation clamps the damping at critical, so the curves are the same
    for time in stride(from: 0.0, through: 2, by: 0.1) {
      expect(overdamped.progress(forElapsedTime: time)) == critical.progress(forElapsedTime: time)
    }
  }

  func test_progress_spring_initialVelocity() throws {
    // given: the curves of a still spring and of a spring moving towards the target
    let still = try AnimationCurve(makeSpring(stiffness: 100, damping: 20))
    let moving = try AnimationCurve(makeSpring(stiffness: 100, damping: 20, initialVelocity: 5))

    // then: the moving spring is further along early on
    expect(moving.progress(forElapsedTime: 0.1)) > still.progress(forElapsedTime: 0.1)
  }

  // MARK: - Helpers

  /// A spring animation of a mass of 1, lasting its settling duration unless given a duration.
  private func makeSpring(stiffness: CGFloat, damping: CGFloat, initialVelocity: CGFloat = 0, duration: TimeInterval? = nil) throws -> CASpringAnimation {
    let descriptor = SpringDescriptor(initialVelocity: initialVelocity, mass: 1, stiffness: stiffness, damping: damping)
    return try (CABasicAnimation.makeAnimation(AnimationTiming(timing: .spring(descriptor, duration: duration))) as? CASpringAnimation).unwrap()
  }
}
