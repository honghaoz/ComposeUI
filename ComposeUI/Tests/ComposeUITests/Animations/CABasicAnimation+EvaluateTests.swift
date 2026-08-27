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
    let animation = makeAnimation(from: 1, to: 0, duration: 4, beginTime: 100, timingFunction: CAMediaTimingFunction(name: .linear))

    expect(animation.scalarValue(at: 100)) == 1
    expect(try unwrap(animation.scalarValue(at: 101))).to(beApproximatelyEqual(to: 0.75, within: 1e-9))
    expect(try unwrap(animation.scalarValue(at: 102))).to(beApproximatelyEqual(to: 0.5, within: 1e-9))
    expect(animation.scalarValue(at: 104)) == 0

    // clamped outside of the active duration
    expect(animation.scalarValue(at: 99)) == 1
    expect(animation.scalarValue(at: 106)) == 0
  }

  func test_scalarValue_nilTimingFunction_isLinear() throws {
    let animation = makeAnimation(from: 0, to: 1, duration: 2, beginTime: 0)

    expect(try unwrap(animation.scalarValue(at: 1))).to(beApproximatelyEqual(to: 0.5, within: 1e-9))
  }

  func test_scalarValue_easeInEaseOut() throws {
    let animation = makeAnimation(from: 0, to: 1, duration: 2, beginTime: 0, timingFunction: CAMediaTimingFunction(name: .easeInEaseOut))

    expect(animation.scalarValue(at: 0)) == 0
    expect(animation.scalarValue(at: 2)) == 1

    // the curve is symmetric, so the midpoint maps to 0.5
    expect(try unwrap(animation.scalarValue(at: 1))).to(beApproximatelyEqual(to: 0.5, within: 1e-6))

    // ease in: slower than linear at the start, faster than linear near the end
    expect(try unwrap(animation.scalarValue(at: 0.5))) < 0.25
    expect(try unwrap(animation.scalarValue(at: 1.5))) > 0.75
  }

  func test_scalarValue_speed() throws {
    let animation = makeAnimation(from: 0, to: 1, duration: 4, beginTime: 0, timingFunction: CAMediaTimingFunction(name: .linear))
    animation.speed = 2

    expect(try unwrap(animation.scalarValue(at: 1))).to(beApproximatelyEqual(to: 0.5, within: 1e-9))
    expect(animation.scalarValue(at: 2)) == 1
  }

  func test_scalarValue_zeroDuration() {
    let animation = makeAnimation(from: 0, to: 1, duration: 0, beginTime: 0)

    expect(animation.scalarValue(at: 0)) == 1
    expect(animation.scalarValue(at: 10)) == 1
  }

  func test_scalarValue_nonScalarValues() {
    let animation = CABasicAnimation(keyPath: "position")
    animation.fromValue = "not a number"
    animation.toValue = "not a number"
    animation.duration = 1

    expect(animation.scalarValue(at: 0)) == nil
  }

  func test_scalarValue_spring_criticallyDamped() throws {
    let descriptor = SpringDescriptor(dampingRatio: 1, response: 0.4)
    let animation = try unwrap(CABasicAnimation.makeAnimation(AnimationTiming(timing: .spring(descriptor))) as? CASpringAnimation)
    animation.fromValue = 1.0
    animation.toValue = 0.0
    animation.beginTime = 0

    expect(animation.scalarValue(at: 0)) == 1

    // monotonically decays from 1 to 0 without overshoot
    var previous = 1.0
    for sample in stride(from: 0.05, through: animation.duration, by: 0.05) {
      let value = try unwrap(animation.scalarValue(at: sample))
      expect(value) <= previous
      expect(value) >= 0
      previous = value
    }
    expect(previous).to(beApproximatelyEqual(to: 0, within: 0.01))
  }

  func test_scalarValue_spring_underdamped_overshoots() throws {
    let descriptor = SpringDescriptor(dampingRatio: 0.2, response: 0.3)
    let animation = try unwrap(CABasicAnimation.makeAnimation(AnimationTiming(timing: .spring(descriptor))) as? CASpringAnimation)
    animation.fromValue = 1.0
    animation.toValue = 0.0
    animation.beginTime = 0

    expect(animation.scalarValue(at: 0)) == 1

    // a lightly damped spring passes the target
    var minimum = 1.0
    for sample in stride(from: 0.01, through: animation.duration, by: 0.01) {
      let value = try unwrap(animation.scalarValue(at: sample))
      minimum = min(minimum, value)
    }
    expect(minimum) < 0
  }

  func test_scalarValue_spring_overdamped() throws {
    // damping greater than 2 * sqrt(stiffness * mass) is an overdamped configuration, which Core Animation clamps to
    // critically damped
    let descriptor = SpringDescriptor(initialVelocity: 0, mass: 1, stiffness: 100, damping: 30)
    let animation = try unwrap(CABasicAnimation.makeAnimation(AnimationTiming(timing: .spring(descriptor, duration: 2))) as? CASpringAnimation)
    animation.fromValue = 1.0
    animation.toValue = 0.0
    animation.beginTime = 0

    // monotonically decays from 1 towards 0 without overshoot
    var previous = 1.0
    for sample in stride(from: 0.05, through: 2, by: 0.05) {
      let value = try unwrap(animation.scalarValue(at: sample))
      expect(value) <= previous
      expect(value) >= 0
      previous = value
    }
    expect(previous).to(beApproximatelyEqual(to: 0, within: 0.01))
  }

  func test_scalarValue_spring_initialVelocity() throws {
    let still = try unwrap(CABasicAnimation.makeAnimation(AnimationTiming(timing: .spring(SpringDescriptor(dampingRatio: 1, response: 0.4)))) as? CASpringAnimation)
    still.fromValue = 1.0
    still.toValue = 0.0
    still.beginTime = 0

    let moving = try unwrap(CABasicAnimation.makeAnimation(AnimationTiming(timing: .spring(SpringDescriptor(dampingRatio: 1, response: 0.4, initialVelocity: 5)))) as? CASpringAnimation)
    moving.fromValue = 1.0
    moving.toValue = 0.0
    moving.beginTime = 0

    // a positive initial velocity moves towards the target faster
    expect(try unwrap(moving.scalarValue(at: 0.1))) < (try unwrap(still.scalarValue(at: 0.1)))
  }

  // MARK: - Parity with Core Animation's private _solveForInput:

  func test_solveForInput_timingFunction_matchesPrivateImplementation() throws {
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

    for timingFunction in timingFunctions {
      for fraction in stride(from: 0.0, through: 1.0, by: 0.01) {
        let expected = try unwrap(
          timingFunction.privateSolveForInput(fraction),
          "Core Animation's private _solveForInput: is unavailable, the parity is unverified"
        )
        expect(timingFunction.solveForInput(fraction)).to(beApproximatelyEqual(to: expected, within: 1e-4))
      }
    }
  }

  func test_solveForInput_spring_matchesPrivateImplementation() throws {
    // (mass, stiffness, damping, initialVelocity) covering underdamped, critically damped (damping = 2√(stiffness·mass)),
    // and overdamped springs, still and moving in both directions
    let parameters: [(mass: CGFloat, stiffness: CGFloat, damping: CGFloat, initialVelocity: CGFloat)] = [
      (1, 100, 10, 0), // underdamped
      (1, 100, 20, 0), // critically damped
      (1, 100, 30, 0), // overdamped configuration, clamped to critically damped
      (1, 200, 12, 5), // underdamped, moving towards the target
      (1, 200, 12, -5), // underdamped, moving away from the target
      (3, 150, 25, 2), // heavier mass
    ]

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
        let expected = try unwrap(
          animation.privateSolveForInput(fraction),
          "Core Animation's private _solveForInput: is unavailable, the parity is unverified"
        )
        expect(animation.solveForInput(fraction)).to(beApproximatelyEqual(to: expected, within: 1e-3))
      }
    }
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
  /// Both `CAMediaTimingFunction`'s and `CASpringAnimation`'s implementations take and return `float` (type encoding `f20@0:8f16`).
  ///
  /// - Parameter value: The input value to solve for.
  /// - Returns: The solved value, or `nil` when the receiver doesn't implement `_solveForInput:`.
  func privateSolveForInput(_ value: Double) -> Double? {
    let selector = Selector(("_solveForInput:"))
    guard responds(to: selector) else {
      return nil
    }

    typealias Method = @convention(c) (AnyObject, Selector, Float) -> Float
    let method = unsafeBitCast(self.method(for: selector), to: Method.self)
    return Double(method(self, selector, Float(value)))
  }
}
