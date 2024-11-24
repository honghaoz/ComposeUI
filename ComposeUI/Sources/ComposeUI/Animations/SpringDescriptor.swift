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

  /// Creates a spring descriptor with physics parameters.
  ///
  /// - Parameters:
  ///   - initialVelocity: The initial velocity of the object.
  ///   - mass: The mass of the object attached to the spring.
  ///   - stiffness: The spring stiffness coefficient.
  ///   - damping: The damping coefficient.
  public init(initialVelocity: CGFloat = 0, mass: CGFloat, stiffness: CGFloat, damping: CGFloat) {
    self.initialVelocity = initialVelocity
    self.mass = mass
    self.stiffness = stiffness
    self.damping = damping
  }

  /// Creates a spring descriptor with intuitive parameters.
  ///
  /// - Parameters:
  ///   - dampingRatio: The damping ratio of the spring. The value controls how "bouncy" the animation is, should be in the range of 0 to 1.
  ///     - 0: No damping, infinite oscillation
  ///     - 0.1-0.4: Very bouncy
  ///     - 0.5-0.8: Moderate bouncy
  ///     - 1.0: Critically damped (no oscillation, fastest approach)
  ///   - response: The response time of the spring. The value represents a time in seconds that approximates how long one complete oscillation would take in an undamped system.
  ///     - 0.2 - 0.4: Faster, more responsive animations
  ///     - 0.5 - 0.8: Moderate response
  ///     - 0.8 - 1.0: Slower, more damped animations
  ///     - 1.0 - 2.0: Very slow, very damped animations (like a heavy object)
  ///   - initialVelocity: The initial velocity of the object. Default is 0.
  public init(dampingRatio: CGFloat, response: CGFloat, initialVelocity: CGFloat = 0) {
    let dampingRatio = max(0, min(dampingRatio, 1))
    let response = max(0.01, response)

    self.initialVelocity = initialVelocity
    self.mass = 1
    self.stiffness = pow(2 * .pi / response, 2)
    self.damping = 4 * .pi * dampingRatio / response
  }

  /// Get the settling duration.
  public func settlingDuration() -> TimeInterval {
    makeTempAnimation().settlingDuration
  }

  /// Get the perceptual duration.
  public func perceptualDuration() -> TimeInterval {
    makeTempAnimation().perceptualDuration()
  }

  /// Get duration with epsilon, using `CASpringAnimation`.
  /// - Parameter epsilon: The epsilon.
  /// - Returns: The settling duration.
  public func duration(epsilon: Double) -> TimeInterval? {
    makeTempAnimation().duration(epsilon: epsilon)
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
