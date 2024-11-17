//
//  ViewItem+Animation.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/13/24.
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

/// A model contains the view animation info.
public struct ViewAnimation {

  /// Create a linear animation.
  ///
  /// - Parameters:
  ///   - duration: The duration of the animation.
  ///   - delay: The delay of the animation. Defaults to `0`.
  ///   - speed: The speed of the animation. Defaults to `1`.
  /// - Returns: The animation.
  public static func linear(_ duration: TimeInterval,
                            delay: TimeInterval = 0,
                            speed: TimeInterval = 1) -> ViewAnimation
  {
    ViewAnimation(
      timing: AnimationTiming(delay: delay, speed: speed, timing: .timingFunction(duration, CAMediaTimingFunction(name: .linear)))
    )
  }

  /// Create an ease in animation.
  ///
  /// - Parameters:
  ///   - duration: The duration of the animation.
  ///   - delay: The delay of the animation. Defaults to `0`.
  ///   - speed: The speed of the animation. Defaults to `1`.
  /// - Returns: The animation.
  public static func easeIn(_ duration: TimeInterval,
                            delay: TimeInterval = 0,
                            speed: TimeInterval = 1) -> ViewAnimation
  {
    ViewAnimation(
      timing: AnimationTiming(delay: delay, speed: speed, timing: .timingFunction(duration, CAMediaTimingFunction(name: .easeIn)))
    )
  }

  /// Create an ease out animation.
  ///
  /// - Parameters:
  ///   - duration: The duration of the animation.
  ///   - delay: The delay of the animation. Defaults to `0`.
  ///   - speed: The speed of the animation. Defaults to `1`.
  /// - Returns: The animation.
  public static func easeOut(_ duration: TimeInterval,
                             delay: TimeInterval = 0,
                             speed: TimeInterval = 1) -> ViewAnimation
  {
    ViewAnimation(
      timing: AnimationTiming(delay: delay, speed: speed, timing: .timingFunction(duration, CAMediaTimingFunction(name: .easeOut)))
    )
  }

  /// Create an ease in ease out animation.
  ///
  /// - Parameters:
  ///   - duration: The duration of the animation.
  ///   - delay: The delay of the animation. Defaults to `0`.
  ///   - speed: The speed of the animation. Defaults to `1`.
  /// - Returns: The animation.
  public static func easeInEaseOut(_ duration: TimeInterval,
                                   delay: TimeInterval = 0,
                                   speed: TimeInterval = 1) -> ViewAnimation
  {
    ViewAnimation(
      timing: AnimationTiming(delay: delay, speed: speed, timing: .timingFunction(duration, CAMediaTimingFunction(name: .easeInEaseOut)))
    )
  }

  /// Create a timing function animation.
  ///
  /// - Parameters:
  ///   - timingFunction: The timing function.
  ///   - duration: The duration of the animation.
  ///   - delay: The delay of the animation. Defaults to `0`.
  ///   - speed: The speed of the animation. Defaults to `1`.
  /// - Returns: The animation.
  public static func timingFunction(_ timingFunction: CAMediaTimingFunction,
                                    duration: TimeInterval,
                                    delay: TimeInterval = 0,
                                    speed: TimeInterval = 1) -> ViewAnimation
  {
    ViewAnimation(
      timing: AnimationTiming(delay: delay, speed: speed, timing: .timingFunction(duration, timingFunction))
    )
  }

  /// Create a spring animation.
  ///
  /// - Parameters:
  ///   - springDescriptor: The spring descriptor.
  ///   - duration: The duration of the animation. Defaults to `nil` which means the duration is determined by the spring descriptor.
  ///   - delay: The delay of the animation. Defaults to `0`.
  ///   - speed: The speed of the animation. Defaults to `1`.
  /// - Returns: The animation.
  public static func spring(_ springDescriptor: SpringDescriptor,
                            duration: TimeInterval? = nil,
                            delay: TimeInterval = 0,
                            speed: TimeInterval = 1) -> ViewAnimation
  {
    ViewAnimation(
      timing: AnimationTiming(delay: delay, speed: speed, timing: .spring(springDescriptor, duration: duration))
    )
  }

  /// The timing of the animation.
  public let timing: AnimationTiming
}

/// The context for animating a view.
public struct ViewAnimationContext {

  /// The timing of the animation.
  public let timing: AnimationTiming

  /// The content view that contains the view.
  public weak var contentView: ComposeView!
}
