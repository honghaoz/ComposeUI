//
//  AnimationCurve.swift
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

/// The curve of an animation, read from the animation once, to evaluate the animation's progress many times without
/// reading the animation again.
///
/// The curve maps a fraction of the duration to a progress the way Core Animation does: a spring animation by its spring
/// physics, a basic animation by its timing function, see `CABasicAnimation.progress(forElapsedTime:)`.
struct AnimationCurve {

  private enum Shape {

    case linear

    /// A unit cubic bezier anchored at (0, 0) and (1, 1), as the coefficients of its polynomials:
    /// `x(t) = ((ax * t + bx) * t + cx) * t`, and the same for `y`.
    case cubicBezier(ax: Double, bx: Double, cx: Double, ay: Double, by: Double, cy: Double)

    /// A decaying oscillation.
    case underdampedSpring(beta: Double, dampedFrequency: Double, sinCoefficient: Double)

    /// The fastest decay without an oscillation.
    case criticallyDampedSpring(beta: Double, coefficient: Double)
  }

  /// The animation's duration.
  let duration: TimeInterval

  private let shape: Shape

  /// Reads the curve of an animation: the spring of a spring animation, or the timing function of a basic animation.
  ///
  /// - Parameter animation: The animation.
  init(_ animation: CABasicAnimation) {
    duration = animation.duration
    if let springAnimation = animation as? CASpringAnimation {
      shape = Self.springShape(of: springAnimation)
    } else {
      shape = Self.timingFunctionShape(of: animation.timingFunction)
    }
  }

  /// Reads the curve of a timing function, to evaluate it at fractions.
  ///
  /// - Parameter timingFunction: The timing function.
  init(timingFunction: CAMediaTimingFunction) {
    duration = 1
    shape = Self.timingFunctionShape(of: timingFunction)
  }

  /// The progress after the given elapsed time, see `CABasicAnimation.progress(forElapsedTime:)`.
  ///
  /// - Parameter elapsed: The elapsed time in the animation's timeline, in seconds.
  /// - Returns: The progress, 1 for a zero duration.
  func progress(forElapsedTime elapsed: TimeInterval) -> Double {
    guard duration > 0 else {
      return 1
    }
    return progress(atFraction: max(0, min(elapsed, duration)) / duration)
  }

  /// The progress at the given fraction of the duration.
  ///
  /// - Parameter fraction: The fraction of the duration, in [0, 1].
  /// - Returns: The progress: 0 at the start, 1 at the end. A spring may overshoot 1 before it settles.
  func progress(atFraction fraction: Double) -> Double {
    switch shape {
    case .linear:
      return fraction
    case .cubicBezier(let ax, let bx, let cx, let ay, let by, let cy):
      return Self.solveCubicBezier(atX: fraction, ax: ax, bx: bx, cx: cx, ay: ay, by: by, cy: cy)
    case .underdampedSpring(let beta, let dampedFrequency, let sinCoefficient):
      let time = fraction * duration
      return 1 - exp(-beta * time) * (cos(dampedFrequency * time) + sinCoefficient * sin(dampedFrequency * time))
    case .criticallyDampedSpring(let beta, let coefficient):
      let time = fraction * duration
      return 1 - exp(-beta * time) * (1 + coefficient * time)
    }
  }

  // MARK: - Shapes

  /// The damped spring physics of a spring animation's `mass`, `stiffness`, `damping` and `initialVelocity`.
  ///
  /// The progress starts at 0 and settles at 1, with the initial rate given by `initialVelocity` in Core Animation's
  /// convention: positive moves towards the target, in full from-to distances per second.
  private static func springShape(of animation: CASpringAnimation) -> Shape {
    let mass = Double(animation.mass)
    let omegaSquared = Double(animation.stiffness) / mass
    // Core Animation clamps the damping at critical: an overdamped configuration (damping > 2√(stiffness·mass)) behaves
    // as critically damped.
    let beta = min(Double(animation.damping) / (2 * mass), sqrt(omegaSquared))
    let discriminant = beta * beta - omegaSquared

    // the displacement u measures the remaining distance to the target, so the progress is 1 - u.
    // u solves the damped spring equation with u(0) = 1 and u'(0) as the negated initial velocity, because positive
    // velocity moves towards the target (0).
    let initialDisplacementRate = -Double(animation.initialVelocity)

    if discriminant < -1e-9 {
      let dampedFrequency = sqrt(-discriminant)
      return .underdampedSpring(beta: beta, dampedFrequency: dampedFrequency, sinCoefficient: (beta + initialDisplacementRate) / dampedFrequency)
    } else {
      return .criticallyDampedSpring(beta: beta, coefficient: beta + initialDisplacementRate)
    }
  }

  private static func timingFunctionShape(of timingFunction: CAMediaTimingFunction?) -> Shape {
    // a nil timing function is linear, matching Core Animation's default for basic animations
    guard let timingFunction else {
      return .linear
    }

    let point1 = timingFunction.controlPoint(at: 1)
    let point2 = timingFunction.controlPoint(at: 2)

    // control points on the diagonal make the curve the identity, the linear curve, so there is nothing to solve
    if point1.x == point1.y, point2.x == point2.y {
      return .linear
    }

    // the bezier 3(1-t)²t·p1 + 3(1-t)t²·p2 + t³, expanded into a polynomial of t
    let cx = 3 * point1.x
    let bx = 3 * (point2.x - point1.x) - cx
    let cy = 3 * point1.y
    let by = 3 * (point2.y - point1.y) - cy
    return .cubicBezier(ax: 1 - cx - bx, bx: bx, cx: cx, ay: 1 - cy - by, by: by, cy: cy)
  }

  /// Solves the unit cubic bezier for `y` at the given `x`.
  ///
  /// Newton's method finds the `t` of `x` in a few steps. The bezier's x component is monotonic, because the control
  /// points' x values are within [0, 1], so `t` stays within a bracket that shrinks on every step. Where the slope is
  /// flat, a Newton step can leave the bracket, or crawl towards `t`, so the step bisects the bracket instead. So the
  /// solver is never slower than bisection.
  ///
  /// It stops when `t` settles rather than when the bezier's x is close to `x`, since around a flat slope a tiny
  /// difference in x is a large difference in `t`, and so in `y`.
  private static func solveCubicBezier(atX x: Double, ax: Double, bx: Double, cx: Double, ay: Double, by: Double, cy: Double) -> Double {
    guard x > 0 else {
      return 0
    }
    guard x < 1 else {
      return 1
    }

    var lowerBound: Double = 0
    var upperBound: Double = 1
    var t = x
    var step: Double = 1
    for _ in 0 ..< Constants.maxSolverSteps {
      let error = ((ax * t + bx) * t + cx) * t - x
      if error < 0 {
        lowerBound = t
      } else if error > 0 {
        upperBound = t
      } else {
        break
      }

      let newtonStep = error / ((3 * ax * t + 2 * bx) * t + cx)
      let newtonT = t - newtonStep
      if newtonT > lowerBound, newtonT < upperBound, abs(newtonStep) * 2 <= abs(step) {
        step = newtonStep
        t = newtonT
      } else {
        step = (upperBound - lowerBound) / 2
        t = lowerBound + step
      }
      if abs(step) < Constants.solverTolerance {
        break
      }
    }

    return ((ay * t + by) * t + cy) * t
  }

  // MARK: - Constants

  private enum Constants {

    /// The most steps to solve a cubic bezier, a bound that isn't reached: bisection alone settles `t` in about 40 steps.
    static let maxSolverSteps = 64

    /// The step of `t` at which a cubic bezier's `t` has settled.
    static let solverTolerance: Double = 1e-12
  }
}

private extension CAMediaTimingFunction {

  /// A control point of the timing function, read without allocating.
  func controlPoint(at index: Int) -> (x: Double, y: Double) {
    var values: (Float, Float) = (0, 0)
    withUnsafeMutablePointer(to: &values) { pointer in
      pointer.withMemoryRebound(to: Float.self, capacity: 2) {
        getControlPoint(at: index, values: $0)
      }
    }
    return (Double(values.0), Double(values.1))
  }
}
