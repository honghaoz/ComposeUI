//
//  CABasicAnimation+AnimationTiming.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/25/21.
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

  /// Make an animation based on the timing.
  ///
  /// - Parameters:
  ///   - timing: The timing of the animation.
  /// - Returns: The animation.
  static func makeAnimation(_ timing: AnimationTiming) -> CABasicAnimation {
    let animation: CABasicAnimation
    switch timing.timing {
    case .spring(let spring, let duration):
      let springAnimation = CASpringAnimation()
      springAnimation.initialVelocity = spring.initialVelocity

      springAnimation.mass = spring.mass
      springAnimation.damping = spring.damping
      springAnimation.stiffness = spring.stiffness

      // without setting the duration, the spring animation can abruptly stop
      // use the settling duration to make sure the spring animation has enough duration
      springAnimation.duration = duration ?? springAnimation.settlingDuration
      animation = springAnimation

    case .timingFunction(let duration, let timingFunction):
      animation = CABasicAnimation()
      animation.timingFunction = timingFunction
      animation.duration = duration
    }

    animation.speed = Float(timing.speed)
    animation.fillMode = .both // avoid the final frame appears before the animation

    return animation
  }
}
