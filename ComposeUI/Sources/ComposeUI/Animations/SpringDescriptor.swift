//
//  SpringDescriptor.swift
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

/// A descriptor for a spring animation.
public struct SpringDescriptor: Hashable {

  /// The initial velocity of the object attached to the spring.
  public let initialVelocity: CGFloat

  /// The mass of the object attached to the end of the spring. Must be greater than 0.
  public let mass: CGFloat

  /// The spring stiffness coefficient. Must be greater than 0.
  public let stiffness: CGFloat

  /// The damping coefficient. Must be greater than or equal to 0.
  public let damping: CGFloat

  /// Get a settling duration.
  func settlingDuration() -> TimeInterval {
    makeTempAnimation().settlingDuration
  }

  private func makeTempAnimation() -> CASpringAnimation {
    let animation = CASpringAnimation(keyPath: "position")
    animation.initialVelocity = initialVelocity

    animation.mass = mass
    animation.damping = damping
    animation.stiffness = stiffness

    /// It seems like `settlingDuration` doesn't respect `from` and `to` value.
    /// https://twitter.com/b3ll/status/750447919719784448
    animation.fromValue = 0
    animation.toValue = 100

    return animation
  }
}
