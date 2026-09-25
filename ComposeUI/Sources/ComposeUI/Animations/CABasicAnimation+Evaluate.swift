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
  /// animation itself or the timing function, maps the elapsed time fraction to a progress, see `AnimationCurve`, and
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
  /// - Parameter time: The time in the layer's time space, compared against `beginTime`. An animation with an unset
  ///   (zero) `beginTime` hasn't been scheduled by Core Animation yet (it is resolved when the transaction commits),
  ///   and an animation scheduled in the future hasn't started: both evaluate at zero elapsed time, yielding `fromValue`.
  /// - Returns: The scalar value at `time`. `nil` when `fromValue` or `toValue` is not a scalar number.
  func scalarValue(at time: TimeInterval) -> Double? {
    guard let from = (fromValue as? NSNumber)?.doubleValue,
          let to = (toValue as? NSNumber)?.doubleValue
    else {
      return nil
    }

    let elapsed = beginTime == 0 ? 0 : (time - beginTime) * TimeInterval(speed)
    return from + (to - from) * progress(forElapsedTime: elapsed)
  }

  /// The animation's progress from `fromValue` (0) to `toValue` (1) after the given elapsed time.
  ///
  /// - Parameter elapsed: The elapsed time in the animation's timeline, in seconds.
  /// - Returns: The progress, 1 for a zero-duration animation.
  func progress(forElapsedTime elapsed: TimeInterval) -> Double {
    AnimationCurve(self).progress(forElapsedTime: elapsed)
  }
}

extension CAMediaTimingFunction {

  /// Solves the timing curve's output progress for the given input time fraction.
  ///
  /// The public-API counterpart of Core Animation's private `_solveForInput:`: solves the unit cubic bezier (anchored
  /// at (0, 0) and (1, 1)) defined by the timing function's control points for `y` at the given `x`, see `AnimationCurve`.
  ///
  /// - Parameter fraction: The input time fraction, in [0, 1].
  /// - Returns: The curve's output progress at `fraction`.
  func solveForInput(_ fraction: Double) -> Double {
    AnimationCurve(timingFunction: self).progress(atFraction: fraction)
  }
}

extension CASpringAnimation {

  /// Solves the spring's progress for the given input time fraction.
  ///
  /// The public-API counterpart of Core Animation's private `_solveForInput:`: solves the damped spring physics from
  /// the animation's `mass`, `stiffness`, `damping`, and `initialVelocity` at the elapsed time `fraction * duration`,
  /// see `AnimationCurve`.
  ///
  /// - Parameter fraction: The input time fraction of the animation's `duration`.
  /// - Returns: The spring's progress at `fraction`.
  func solveForInput(_ fraction: Double) -> Double {
    AnimationCurve(self).progress(atFraction: fraction)
  }
}
