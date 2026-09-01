//
//  CABasicAnimation+EvaluateTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/26/26.
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

class CABasicAnimation_EvaluateTests: XCTestCase {

  func test_scalarValue_linear() throws {
    // given: a linear animation from 1 to 0
    let animation = makeAnimation(from: 1, to: 0, duration: 4, beginTime: 100, timingFunction: CAMediaTimingFunction(name: .linear))

    // then: values interpolate linearly over the active duration
    expect(animation.scalarValue(at: 100)) == 1
    expect(try unwrap(animation.scalarValue(at: 101))).to(beApproximatelyEqual(to: 0.75, within: 1e-9))
    expect(try unwrap(animation.scalarValue(at: 102))).to(beApproximatelyEqual(to: 0.5, within: 1e-9))
    expect(animation.scalarValue(at: 104)) == 0

    // then: values are clamped outside of the active duration
    expect(animation.scalarValue(at: 99)) == 1
    expect(animation.scalarValue(at: 106)) == 0
  }

  func test_scalarValue_nilTimingFunction_isLinear() throws {
    // given: an animation without a timing function
    let animation = makeAnimation(from: 0, to: 1, duration: 2, beginTime: 100)

    // then: values interpolate linearly
    expect(try unwrap(animation.scalarValue(at: 101))).to(beApproximatelyEqual(to: 0.5, within: 1e-9))
  }

  func test_scalarValue_easeInEaseOut() throws {
    // given: an ease in ease out animation from 0 to 1
    let animation = makeAnimation(from: 0, to: 1, duration: 2, beginTime: 100, timingFunction: CAMediaTimingFunction(name: .easeInEaseOut))

    // then: values follow the ease in ease out curve
    expect(animation.scalarValue(at: 100)) == 0
    expect(animation.scalarValue(at: 102)) == 1

    // the curve is symmetric, so the midpoint maps to 0.5
    expect(try unwrap(animation.scalarValue(at: 101))).to(beApproximatelyEqual(to: 0.5, within: 1e-6))

    // ease in: slower than linear at the start, faster than linear near the end
    expect(try unwrap(animation.scalarValue(at: 100.5))) < 0.25
    expect(try unwrap(animation.scalarValue(at: 101.5))) > 0.75
  }

  func test_scalarValue_speed() throws {
    // given: a linear animation with a doubled speed
    let animation = makeAnimation(from: 0, to: 1, duration: 4, beginTime: 100, timingFunction: CAMediaTimingFunction(name: .linear))
    animation.speed = 2

    // then: values progress at twice the pace
    expect(try unwrap(animation.scalarValue(at: 101))).to(beApproximatelyEqual(to: 0.5, within: 1e-9))
    expect(animation.scalarValue(at: 102)) == 1
  }

  func test_scalarValue_zeroDuration() {
    // given: an animation with a zero duration
    let animation = makeAnimation(from: 0, to: 1, duration: 0, beginTime: 100)

    // then: the value is the to value at any time
    expect(animation.scalarValue(at: 100)) == 1
    expect(animation.scalarValue(at: 110)) == 1
  }

  func test_scalarValue_unresolvedBeginTime_evaluatesAtZeroElapsedTime() throws {
    // given: an animation with an unset begin time, which hasn't been scheduled by Core Animation yet (the begin
    // time is resolved when the transaction commits)
    let animation = makeAnimation(from: 1, to: 0, duration: 4, beginTime: 0, timingFunction: CAMediaTimingFunction(name: .linear))

    // then: it evaluates at zero elapsed time regardless of the query time
    expect(animation.scalarValue(at: 0)) == 1
    expect(animation.scalarValue(at: CACurrentMediaTime())) == 1
  }

  func test_scalarValue_nonScalarValues() {
    // given: an animation with non-scalar from and to values
    let animation = CABasicAnimation(keyPath: "position")
    animation.fromValue = "not a number"
    animation.toValue = "not a number"
    animation.duration = 1

    // then: the scalar value is nil
    expect(animation.scalarValue(at: 0)) == nil
  }

  func test_scalarValue_spring_criticallyDamped() throws {
    // given: a critically damped spring animation from 1 to 0
    let descriptor = SpringDescriptor(dampingRatio: 1, response: 0.4)
    let animation = try unwrap(CABasicAnimation.makeAnimation(AnimationTiming(timing: .spring(descriptor))) as? CASpringAnimation)
    animation.fromValue = 1.0
    animation.toValue = 0.0
    animation.beginTime = 100

    // then: the value starts at 1 and monotonically decays from 1 to 0 without overshoot
    expect(animation.scalarValue(at: 100)) == 1

    var previous = 1.0
    for sample in stride(from: 0.05, through: animation.duration, by: 0.05) {
      let value = try unwrap(animation.scalarValue(at: 100 + sample))
      expect(value) <= previous
      expect(value) >= 0
      previous = value
    }
    expect(previous).to(beApproximatelyEqual(to: 0, within: 0.01))
  }

  func test_scalarValue_spring_underdamped_overshoots() throws {
    // given: an underdamped spring animation from 1 to 0
    let descriptor = SpringDescriptor(dampingRatio: 0.2, response: 0.3)
    let animation = try unwrap(CABasicAnimation.makeAnimation(AnimationTiming(timing: .spring(descriptor))) as? CASpringAnimation)
    animation.fromValue = 1.0
    animation.toValue = 0.0
    animation.beginTime = 100

    // then: the value starts at 1 and a lightly damped spring passes the target
    expect(animation.scalarValue(at: 100)) == 1

    var minimum = 1.0
    for sample in stride(from: 0.01, through: animation.duration, by: 0.01) {
      let value = try unwrap(animation.scalarValue(at: 100 + sample))
      minimum = min(minimum, value)
    }
    expect(minimum) < 0
  }

  func test_scalarValue_spring_overdamped() throws {
    // given: an overdamped spring animation from 1 to 0
    // damping greater than 2 * sqrt(stiffness * mass) is an overdamped configuration, which Core Animation clamps to
    // critically damped
    let descriptor = SpringDescriptor(initialVelocity: 0, mass: 1, stiffness: 100, damping: 30)
    let animation = try unwrap(CABasicAnimation.makeAnimation(AnimationTiming(timing: .spring(descriptor, duration: 2))) as? CASpringAnimation)
    animation.fromValue = 1.0
    animation.toValue = 0.0
    animation.beginTime = 100

    // then: the value monotonically decays from 1 towards 0 without overshoot
    var previous = 1.0
    for sample in stride(from: 0.05, through: 2, by: 0.05) {
      let value = try unwrap(animation.scalarValue(at: 100 + sample))
      expect(value) <= previous
      expect(value) >= 0
      previous = value
    }
    expect(previous).to(beApproximatelyEqual(to: 0, within: 0.01))
  }

  func test_scalarValue_spring_initialVelocity() throws {
    // given: two spring animations from 1 to 0, one still and one with an initial velocity
    let still = try unwrap(CABasicAnimation.makeAnimation(AnimationTiming(timing: .spring(SpringDescriptor(dampingRatio: 1, response: 0.4)))) as? CASpringAnimation)
    still.fromValue = 1.0
    still.toValue = 0.0
    still.beginTime = 100

    let moving = try unwrap(CABasicAnimation.makeAnimation(AnimationTiming(timing: .spring(SpringDescriptor(dampingRatio: 1, response: 0.4, initialVelocity: 5)))) as? CASpringAnimation)
    moving.fromValue = 1.0
    moving.toValue = 0.0
    moving.beginTime = 100

    // then: a positive initial velocity moves towards the target faster
    expect(try unwrap(moving.scalarValue(at: 100.1))) < (try unwrap(still.scalarValue(at: 100.1)))
  }

  // MARK: - Parity with Core Animation's private _solveForInput:

  func test_solveForInput_timingFunction_matchesPrivateImplementation() throws {
    // given: timing functions covering the standard names and custom control points
    let timingFunctions: [CAMediaTimingFunction] = [
      CAMediaTimingFunction(name: .linear),
      CAMediaTimingFunction(name: .easeIn),
      CAMediaTimingFunction(name: .easeOut),
      CAMediaTimingFunction(name: .easeInEaseOut),
      CAMediaTimingFunction(name: .default),
      CAMediaTimingFunction(controlPoints: 0.17, 0.67, 0.83, 0.67),
      // control points with y outside [0, 1] make the curve overshoot
      CAMediaTimingFunction(controlPoints: 0.3, 1.5, 0.6, -0.5),
    ]

    // then: the solved values match the private implementation for all inputs
    for timingFunction in timingFunctions {
      for fraction in stride(from: 0.0, through: 1.0, by: 0.01) {
        guard let expected = timingFunction.privateSolveForInput(fraction) else {
          throw XCTSkip("Core Animation's private _solveForInput: is unavailable, see test_solveForInput_privateImplementationIsAvailable")
        }
        expect(timingFunction.solveForInput(fraction)).to(beApproximatelyEqual(to: expected, within: 1e-4))
      }
    }
  }

  func test_solveForInput_spring_matchesPrivateImplementation() throws {
    // given: (mass, stiffness, damping, initialVelocity) covering underdamped, critically damped (damping = 2√(stiffness·mass)),
    // and overdamped springs, still and moving in both directions
    let parameters: [(mass: CGFloat, stiffness: CGFloat, damping: CGFloat, initialVelocity: CGFloat)] = [
      (1, 100, 10, 0), // underdamped
      (1, 100, 20, 0), // critically damped
      (1, 100, 30, 0), // overdamped configuration, clamped to critically damped
      (1, 200, 12, 5), // underdamped, moving towards the target
      (1, 200, 12, -5), // underdamped, moving away from the target
      (3, 150, 25, 2), // heavier mass
    ]

    // then: the solved values match the private implementation for each spring and input
    for parameter in parameters {
      let animation = CASpringAnimation(keyPath: "opacity")
      animation.mass = parameter.mass
      animation.stiffness = parameter.stiffness
      animation.damping = parameter.damping
      animation.initialVelocity = parameter.initialVelocity
      // the private implementation solves for a fraction of the duration, and its internal solver is initialized when
      // the duration is set, so set the duration after the spring parameters.
      // the public implementation reads the same duration, keeping the two comparable per input.
      animation.duration = animation.settlingDuration

      for fraction in stride(from: 0.0, through: 1.0, by: 0.01) {
        guard let expected = animation.privateSolveForInput(fraction) else {
          throw XCTSkip("Core Animation's private _solveForInput: is unavailable, see test_solveForInput_privateImplementationIsAvailable")
        }
        expect(animation.solveForInput(fraction)).to(beApproximatelyEqual(to: expected, within: 1e-3))
      }
    }
  }

  func test_solveForInput_privateImplementationIsAvailable() {
    // then: Core Animation's private _solveForInput: is available
    // the parity tests skip when the private implementation is unavailable, so this canary fails loudly to flag that
    // the parity is no longer being verified and the assumptions need to be re-established.
    expect(CAMediaTimingFunction(name: .linear).privateSolveForInput(0.5)) != nil
    expect(CASpringAnimation(keyPath: "opacity").privateSolveForInput(0.5)) != nil
  }

  private func makeAnimation(from: Double, to: Double, duration: TimeInterval, beginTime: TimeInterval, timingFunction: CAMediaTimingFunction? = nil) -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.fromValue = from
    animation.toValue = to
    animation.duration = duration
    animation.beginTime = beginTime
    animation.timingFunction = timingFunction
    return animation
  }
}

// MARK: - Private API Trampoline

private extension NSObject {

  /// Calls Core Animation's private `_solveForInput:` on the receiver.
  ///
  /// Both `CAMediaTimingFunction`'s and `CASpringAnimation`'s implementations take and return `float`. The method's
  /// type encoding is validated before the call, so an implementation with a changed signature is treated as
  /// unavailable instead of being called through a mismatched convention.
  ///
  /// - Parameter value: The input value to solve for.
  /// - Returns: The solved value, or `nil` when the receiver doesn't implement `_solveForInput:` with the expected
  ///   signature.
  func privateSolveForInput(_ value: Double) -> Double? {
    let selector = Selector(("_solveForInput:"))
    guard let method = class_getInstanceMethod(type(of: self), selector),
          let encoding = method_getTypeEncoding(method).map(String.init(cString:)),
          encoding.filter({ !$0.isNumber }) == "f@:f"
    else {
      return nil
    }

    typealias Method = @convention(c) (AnyObject, Selector, Float) -> Float
    let implementation = unsafeBitCast(method_getImplementation(method), to: Method.self)
    return Double(implementation(self, selector, Float(value)))
  }
}
