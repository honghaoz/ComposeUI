//
//  AnimationTiming.swift
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

/// A descriptor for an animation timing.
public struct AnimationTiming {

  /// Create a linear animation timing.
  ///
  /// - Parameters:
  ///   - duration: The duration of the animation.
  ///   - delay: The delay of the animation. Defaults to `0`.
  ///   - speed: The speed of the animation. Defaults to `1`.
  /// - Returns: The animation timing.
  public static func linear(duration: TimeInterval,
                            delay: TimeInterval = 0,
                            speed: CGFloat = 1) -> AnimationTiming
  {
    AnimationTiming(timing: .timingFunction(duration, CAMediaTimingFunction(name: .linear)), delay: delay, speed: speed)
  }

  /// Create an ease in animation timing.
  ///
  /// - Parameters:
  ///   - duration: The duration of the animation.
  ///   - delay: The delay of the animation. Defaults to `0`.
  ///   - speed: The speed of the animation. Defaults to `1`.
  /// - Returns: The animation timing.
  public static func easeIn(duration: TimeInterval,
                            delay: TimeInterval = 0,
                            speed: CGFloat = 1) -> AnimationTiming
  {
    AnimationTiming(timing: .timingFunction(duration, CAMediaTimingFunction(name: .easeIn)), delay: delay, speed: speed)
  }

  /// Create an ease out animation timing.
  ///
  /// - Parameters:
  ///   - duration: The duration of the animation.
  ///   - delay: The delay of the animation. Defaults to `0`.
  ///   - speed: The speed of the animation. Defaults to `1`.
  /// - Returns: The animation timing.
  public static func easeOut(duration: TimeInterval,
                             delay: TimeInterval = 0,
                             speed: CGFloat = 1) -> AnimationTiming
  {
    AnimationTiming(timing: .timingFunction(duration, CAMediaTimingFunction(name: .easeOut)), delay: delay, speed: speed)
  }

  /// Create an ease in ease out animation timing.
  ///
  /// - Parameters:
  ///   - duration: The duration of the animation.
  ///   - delay: The delay of the animation. Defaults to `0`.
  ///   - speed: The speed of the animation. Defaults to `1`.
  /// - Returns: The animation timing.
  public static func easeInEaseOut(duration: TimeInterval,
                                   delay: TimeInterval = 0,
                                   speed: CGFloat = 1) -> AnimationTiming
  {
    AnimationTiming(timing: .timingFunction(duration, CAMediaTimingFunction(name: .easeInEaseOut)), delay: delay, speed: speed)
  }

  /// Create a spring animation timing.
  ///
  /// - Parameters:
  ///   - dampingRatio: The damping ratio of the spring.
  ///   - response: The response of the spring.
  ///   - initialVelocity: The initial velocity of the spring.
  ///   - duration: The duration of the animation. Defaults to `nil` which means the duration is determined by the spring descriptor.
  ///   - delay: The delay of the animation. Defaults to `0`.
  ///   - speed: The speed of the animation. Defaults to `1`.
  /// - Returns: The animation timing.
  public static func spring(dampingRatio: CGFloat,
                            response: CGFloat,
                            initialVelocity: CGFloat = 0,
                            duration: TimeInterval? = nil,
                            delay: TimeInterval = 0,
                            speed: CGFloat = 1) -> AnimationTiming
  {
    AnimationTiming(
      timing: .spring(
        SpringDescriptor(dampingRatio: dampingRatio, response: response, initialVelocity: initialVelocity),
        duration: duration
      ),
      delay: delay,
      speed: speed
    )
  }

  /// The timing type.
  public enum Timing: Hashable {

    /// A spring animation.
    ///
    /// - Parameters:
    ///   - springDescriptor: The spring descriptor.
    ///   - duration: The duration of the animation. Defaults to `nil` which means the duration is determined by the spring descriptor.
    case spring(SpringDescriptor, duration: TimeInterval? = nil)

    /// A timing function animation.
    ///
    /// - Parameters:
    ///   - duration: The duration of the animation.
    ///   - timingFunction: The timing function. Defaults to `easeInEaseOut`.
    case timingFunction(_ duration: TimeInterval, _ timingFunction: CAMediaTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut))

    /// The timing's duration.
    public var duration: TimeInterval {
      switch self {
      case .spring(let springDescriptor, let duration):
        return duration ?? springDescriptor.settlingDuration()
      case .timingFunction(let duration, _):
        return duration
      }
    }
  }

  /// The timing type.
  public let timing: Timing

  /// The delay of the animation.
  public let delay: TimeInterval

  /// The speed of the animation.
  public let speed: CGFloat

  /// Creates an animation timing.
  ///
  /// - Parameters:
  ///   - timing: The timing type.
  ///   - delay: The delay of the animation. Defaults to `0`.
  ///   - speed: The speed of the animation. Defaults to `1`.
  public init(timing: Timing, delay: TimeInterval = 0, speed: CGFloat = 1) {
    self.timing = timing
    self.delay = delay
    self.speed = speed
  }
}
