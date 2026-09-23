//
//  CALayer+Retarget.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/21/26.
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

public extension CALayer {

  /// Sets a key path's value and retargets its in-flight animations to it, so the motion continues from where it is
  /// and lands on the new value when it would have.
  ///
  /// - Without in-flight animations, the value is set directly. An animation already heading to the value is left alone.
  ///   An ended animation still on the layer is removed, since a forwards fill would show its end value over the new one.
  /// - Additive animations of numbers, `CGSize` and `CGPoint` are kept, with a scaled copy of each stacked on top that
  ///   cancels the jump and fades along the animation's own curve. When the remaining motion can't be scaled, one
  ///   ease-out correction is stacked instead.
  /// - Non-additive animations are replaced by one ease-out animation from the shown value over the remaining time.
  ///   Note that additive animations of `opacity` and `shadowOpacity` are also treated as non-additive, since the
  ///   render server clamps them after each animation and stacked animations wouldn't compose on screen.
  ///
  /// - Important: The value's type must match the key path's, or Core Animation crashes.
  ///
  /// - Parameters:
  ///   - keyPath: The key path to set.
  ///   - value: The value to set.
  func retarget(keyPath: String, to value: Any) {
    let now = currentTime
    let inFlightAnimations = inFlightAnimations(forKeyPath: keyPath, at: now, removingEnded: true)
    guard let remainingTime = inFlightAnimations.max(by: { $0.remainingTime < $1.remainingTime })?.remainingTime else {
      // no in-flight animations, set the value directly
      setKeyPathValue(keyPath, value)
      return
    }

    // an in-flight animation already heading to the value keeps its easing, skipping the retarget
    let currentValue = self.value(forKeyPath: keyPath)
    if let currentValue, (currentValue as AnyObject).isEqual(value) {
      return
    }

    if let currentValue,
       let additiveRetarget = AdditiveRetarget(keyPath: keyPath, animations: inFlightAnimations, from: currentValue, to: value, at: now)
    {
      if let factors = additiveRetarget.correctionFactors(over: remainingTime) {
        additiveRetarget.stackCorrectionAnimations(on: self, scaledBy: factors, forKeyPath: keyPath)
        setKeyPathValue(keyPath, value)
      } else {
        // no motion to scale, so one correction animation eases out on its own
        let jump = additiveRetarget.jump
        animate(
          keyPath: keyPath,
          timing: .easeOut(duration: remainingTime),
          from: { _ in jump.value },
          to: { _ in jump.zero.value },
          model: { _ in value },
          updateAnimation: { $0.isAdditive = true }
        )
      }
    } else {
      // remove the in-flight animations and replace them with a new one from the current value to the new value.
      // uses the basic easing curve for simplicity, no interrupted velocity to carry
      removeAnimations(forKeyPath: keyPath)
      animate(
        keyPath: keyPath,
        timing: .easeOut(duration: remainingTime),
        from: { $0.presentation()?.value(forKeyPath: keyPath) },
        to: { _ -> Any? in value }
      )
    }
  }

  /// The time the layer's in-flight animations of the given key path have left, in seconds of the layer's time space.
  ///
  /// The time is the longest animation's: a delayed animation that hasn't begun counts its remaining delay, and an
  /// animation whose `beginTime` is still unset (zero) begins when the transaction commits, so it counts its full
  /// duration. A paused animation (zero speed) counts its duration, as it has no end to measure to.
  ///
  /// - Parameter keyPath: The animated key path.
  /// - Returns: The remaining time, or `nil` when no animation of the key path is in flight.
  internal func remainingAnimationTime(forKeyPath keyPath: String) -> TimeInterval? {
    inFlightAnimations(forKeyPath: keyPath, at: currentTime, removingEnded: false)
      .max(by: { $0.remainingTime < $1.remainingTime })?
      .remainingTime
  }

  /// The layer's property animations of the given key path that haven't ended at `now`.
  ///
  /// - Parameter removingEnded: Whether to remove the key path's ended animations on the way. Core Animation removes an
  ///   ended animation itself, unless it is kept with `isRemovedOnCompletion` off, and with a forwards fill it then shows
  ///   its end value over the model value, so a new model value only shows once it is gone.
  private func inFlightAnimations(forKeyPath keyPath: String, at now: TimeInterval, removingEnded: Bool) -> [InFlightAnimation] {
    var inFlightAnimations: [InFlightAnimation] = []
    for key in animationKeys() ?? [] {
      guard let animation = animation(forKey: key) as? CAPropertyAnimation, animation.keyPath == keyPath else {
        continue
      }

      if let remainingTime = remainingTime(of: animation, at: now) {
        inFlightAnimations.append(InFlightAnimation(key: key, animation: animation, remainingTime: remainingTime))
      } else if removingEnded {
        removeAnimation(forKey: key)
      }
    }
    return inFlightAnimations
  }

  /// The time an animation has left at `now`, or `nil` when it has ended.
  private func remainingTime(of animation: CAAnimation, at now: TimeInterval) -> TimeInterval? {
    let scaledDuration = animation.speed > 0 ? animation.duration / TimeInterval(animation.speed) : animation.duration
    let remainingTime = animation.beginTime == 0 ? scaledDuration : animation.beginTime + scaledDuration - now
    return remainingTime > 0 ? remainingTime : nil
  }
}

/// An in-flight property animation of a layer.
struct InFlightAnimation {

  /// The key the animation is on the layer.
  let key: String

  /// The animation.
  let animation: CAPropertyAnimation

  /// The time the animation has left, in seconds of the layer's time space.
  let remainingTime: TimeInterval
}
