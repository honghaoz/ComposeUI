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

  /// The delay of the animation.
  public let delay: TimeInterval

  /// The speed of the animation.
  public let speed: CGFloat

  /// The timing type.
  public let timing: Timing

  /// Creates an animation timing.
  ///
  /// - Parameters:
  ///   - delay: The delay of the animation. Defaults to `0`.
  ///   - speed: The speed of the animation. Defaults to `1`.
  ///   - timing: The timing type.
  public init(delay: TimeInterval = 0, speed: CGFloat = 1, timing: Timing) {
    self.delay = delay
    self.speed = speed
    self.timing = timing
  }
}
