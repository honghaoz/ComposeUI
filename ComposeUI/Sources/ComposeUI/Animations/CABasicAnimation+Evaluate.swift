//
//  CABasicAnimation+Evaluate.swift
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

import Foundation
import QuartzCore

extension CABasicAnimation {

  /// Evaluates the animation's scalar value at the given time.
  ///
  /// The evaluation mirrors how Core Animation resolves the animation on its own: the animation's curve, the spring
  /// animation itself or the timing function, maps the elapsed time fraction to a progress via `solveForInput(_:)`, and
  /// the value interpolates `fromValue` to `toValue` by that progress.
  /// The elapsed time is scaled by the animation's `speed` and clamped to the animation's duration.
  ///
  /// The value is computed analytically instead of reading `presentation()`: a presentation snapshot reflects the last
  /// committed frame rather than the evaluation time, is unreliable for layers outside a committed layer tree, and
  /// cannot provide a rate of change.
  ///
  /// The supported animation shapes are the ones ComposeUI transitions produce: `timeOffset`, `repeatCount`, and
  /// `autoreverses` are not evaluated.
  ///
  /// - Parameter time: The time in the animation's time space, compared against `beginTime`. An animation with an
  ///   unset (zero) `beginTime` hasn't been scheduled by Core Animation yet (it is resolved when the transaction
  ///   commits), so it evaluates at zero elapsed time.
  /// - Returns: The scalar value at `time`. `nil` when `fromValue` or `toValue` is not a scalar number.
  func scalarValue(at time: TimeInterval) -> Double? {
    guard let from = (fromValue as? NSNumber)?.doubleValue,
          let to = (toValue as? NSNumber)?.doubleValue
    else {
      return nil
    }

    let elapsed = beginTime == 0 ? 0 : max(0, min((time - beginTime) * TimeInterval(speed), duration))

    let progress: Double
    if duration > 0 {
      let fraction = elapsed / duration
      if let spring = self as? CASpringAnimation {
        progress = spring.solveForInput(fraction)
      } else {
        // a nil timing function is linear, matching Core Animation's default for basic animations
        progress = timingFunction?.solveForInput(fraction) ?? fraction
      }
    } else {
      progress = 1
    }

    return from + (to - from) * progress
  }
}

extension CAMediaTimingFunction {

  /// Solves the timing curve's output progress for the given input time fraction.
  ///
  /// The public-API counterpart of Core Animation's private `_solveForInput:`: solves the unit cubic bezier (anchored
  /// at (0, 0) and (1, 1)) defined by the timing function's control points for `y` at the given `x`.
  ///
  /// Uses bisection: the bezier's x component is monotonic because the control points' x values are within [0, 1], so
  /// bisection always converges. This runs once per transition interrupt, so the simple and robust solver is preferred
  /// over a faster one.
  ///
  /// - Parameter fraction: The input time fraction, in [0, 1].
  /// - Returns: The curve's output progress at `fraction`.
  func solveForInput(_ fraction: Double) -> Double {
    guard fraction > 0 else {
      return 0
    }
    guard fraction < 1 else {
      return 1
    }

    var controlPoint1: [Float] = [0, 0]
    var controlPoint2: [Float] = [0, 0]
    getControlPoint(at: 1, values: &controlPoint1)
    getControlPoint(at: 2, values: &controlPoint2)

    func bezier(_ t: Double, _ value1: Double, _ value2: Double) -> Double {
      // cubic bezier with anchors 0 and 1: 3(1-t)²t·p1 + 3(1-t)t²·p2 + t³
      let oneMinusT = 1 - t
      return 3 * oneMinusT * oneMinusT * t * value1 + 3 * oneMinusT * t * t * value2 + t * t * t
    }

    var lowerBound: Double = 0
    var upperBound: Double = 1
    var t = fraction
    for _ in 0 ..< 32 {
      let sampledX = bezier(t, Double(controlPoint1[0]), Double(controlPoint2[0]))
      if sampledX < fraction {
        lowerBound = t
      } else {
        upperBound = t
      }
      t = (lowerBound + upperBound) / 2
    }

    return bezier(t, Double(controlPoint1[1]), Double(controlPoint2[1]))
  }
}

extension CASpringAnimation {

  /// Solves the spring's progress for the given input time fraction.
  ///
  /// The public-API counterpart of Core Animation's private `_solveForInput:`: solves the damped spring physics from
  /// the animation's `mass`, `stiffness`, `damping`, and `initialVelocity` at the elapsed time `fraction * duration`.
  /// The progress starts at 0 (the `fromValue` end), may overshoot past 1, and settles at 1 (the `toValue` end), with
  /// the initial rate given by `initialVelocity` in Core Animation's convention (positive moves towards the target, in
  /// full from-to distances per second).
  ///
  /// - Parameter fraction: The input time fraction of the animation's `duration`.
  /// - Returns: The spring's progress at `fraction`.
  func solveForInput(_ fraction: Double) -> Double {
    let omegaSquared = Double(stiffness) / Double(mass)
    // Core Animation clamps the damping at critical: an overdamped configuration (damping > 2√(stiffness·mass)) behaves
    // as critically damped.
    let beta = min(Double(damping) / (2 * Double(mass)), sqrt(omegaSquared))
    let discriminant = beta * beta - omegaSquared

    // the displacement u measures the remaining distance to the target, so the progress is 1 - u.
    // u solves the damped spring equation with u(0) = 1 and u'(0) as the negated initial velocity, because positive
    // velocity moves towards the target (0).
    let initialDisplacementRate = -Double(initialVelocity)
    let t = fraction * duration

    let displacement: Double
    if discriminant < -1e-9 {
      // underdamped: decaying oscillation
      let dampedFrequency = sqrt(-discriminant)
      let sinCoefficient = (beta + initialDisplacementRate) / dampedFrequency
      displacement = exp(-beta * t) * (cos(dampedFrequency * t) + sinCoefficient * sin(dampedFrequency * t))
    } else {
      // critically damped: fastest non-oscillating decay
      displacement = exp(-beta * t) * (1 + (beta + initialDisplacementRate) * t)
    }

    return 1 - displacement
  }
}
