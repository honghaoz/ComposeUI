//
//  TransformMotion.swift
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

/// A change of a transform from one transform to another with a timing, which gives the transform at any time.
struct TransformMotion {

  /// The time the change begins, in the layer's time space.
  let beginTime: TimeInterval

  private let interpolator: TransformInterpolator
  private let curve: AnimationCurve
  private let speed: Double

  /// Creates a change that begins at a time, after the timing's delay.
  ///
  /// - Parameters:
  ///   - interpolator: The interpolator between the transforms that the change goes from and to.
  ///   - timing: The timing.
  ///   - time: The time the change is made at, in the layer's time space.
  init(interpolator: TransformInterpolator, timing: AnimationTiming, at time: TimeInterval) {
    let beginTime = CAAnimation.beginTime(at: time, delay: timing.delay)
    switch timing.timing {
    case .timingFunction(let duration, let timingFunction) where duration > 0:
      // making the timing's animation allocates, so the curve, the duration and the speed, which an animation keeps as a
      // `Float`, come from the timing as `CABasicAnimation.makeAnimation(_:)` sets them
      self.init(
        interpolator: interpolator,
        curve: AnimationCurve(timingFunction: timingFunction, duration: duration),
        speed: Double(Float(timing.speed)),
        beginTime: beginTime
      )
    case .timingFunction,
         .spring:
      // Core Animation gives a spring its duration, and a zero duration makes a snap, so the timing's animation has the
      // curve, the duration and the speed that an animation of the transform would have
      self.init(interpolator: interpolator, animation: CABasicAnimation.makeAnimation(timing), beginTime: beginTime)
    }
  }

  /// Creates the change that an animation of the transform shows.
  ///
  /// - Parameters:
  ///   - interpolator: The interpolator between the transforms that the change goes from and to.
  ///   - animation: The animation, whose curve, duration and speed the change has.
  ///   - beginTime: The time the change begins, in the layer's time space.
  init(interpolator: TransformInterpolator, animation: CABasicAnimation, beginTime: TimeInterval) {
    self.init(interpolator: interpolator, curve: AnimationCurve(animation), speed: Double(animation.speed), beginTime: beginTime)
  }

  private init(interpolator: TransformInterpolator, curve: AnimationCurve, speed: Double, beginTime: TimeInterval) {
    self.interpolator = interpolator
    self.curve = curve
    self.speed = speed
    self.beginTime = beginTime
  }

  /// The time the change ends, in the layer's time space.
  var endTime: TimeInterval {
    beginTime + curve.duration / speed
  }

  /// The transform the change ends at.
  var target: CATransform3D {
    interpolator.transform(atProgress: 1)
  }

  /// Whether the change never ends, as a spring without damping doesn't.
  var neverFinishes: Bool {
    CAAnimation.neverFinishes(duration: curve.duration)
  }

  /// The change's progress at a time: 0 until it begins, 1 once it ends, and past 1 while a spring overshoots.
  ///
  /// - Parameter time: The time, in the layer's time space.
  /// - Returns: The progress.
  func progress(at time: TimeInterval) -> Double {
    curve.progress(forElapsedTime: (time - beginTime) * speed)
  }

  /// The transform at a time.
  ///
  /// It's always inlined, since the change is too big for registers, so a call would copy it to pass it, for each
  /// keyframe that follows it.
  ///
  /// - Parameter time: The time, in the layer's time space.
  /// - Returns: The transform, the change's target itself once it ends.
  @inline(__always)
  func transform(at time: TimeInterval) -> CATransform3D {
    // a spring ends close to its target rather than on it, so the change shows its target itself once it ends
    if time < endTime {
      return interpolator.transform(atProgress: progress(at: time))
    } else {
      return target
    }
  }
}
