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

  /// Sets a key path's value, retargeting the key path's in-flight animations to it.
  ///
  /// This is useful for setting a non-additive property, such as a color or a path, without animating the change while
  /// existing animations of it are in flight.
  ///
  /// If no in-flight animations are found, the value is set without an implicit action. An in-flight animation already
  /// heading to the value is left alone. Otherwise the in-flight animations are replaced by one animation from the
  /// value the layer currently shows to `value`, easing out over the time the longest of them had left, so the motion
  /// continues from where it is and lands when it would have. With several animations in flight, the layer shows what
  /// Core Animation composes from them (the last non-additive one added wins), and the retarget starts from that. The
  /// retarget carries neither the interrupted animation's curve nor its velocity.
  ///
  /// An additive property needs no retarget: an additive animation is a delta on the model value, so setting the model
  /// value lands it on the new value while its motion continues.
  ///
  /// - Important: You must make sure the value type matches the key path type. Otherwise, a crash will occur.
  ///
  /// - Parameters:
  ///   - keyPath: The key path to set.
  ///   - value: The value to set.
  func retarget(keyPath: String, to value: Any) {
    guard let remainingTime = remainingAnimationTime(forKeyPath: keyPath) else {
      // no in-flight animations, set the value directly
      setKeyPathValue(keyPath, value)
      return
    }

    // an in-flight animation already heading to the value keeps its easing, skipping the retarget
    if let currentValue = self.value(forKeyPath: keyPath), (currentValue as AnyObject).isEqual(value) {
      return
    }

    // remove the in-flight animations and replace them with a new one from the current value to the new value
    removeAnimations(forKeyPath: keyPath)
    animate(
      keyPath: keyPath,
      timing: .easeOut(duration: remainingTime), // uses the basic easing curve for simplicity, no interrupted velocity to carry
      from: { $0.presentation()?.value(forKeyPath: keyPath) },
      to: { _ -> Any? in value }
    )
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
    let now = currentTime
    var remainingTime: TimeInterval?
    for key in animationKeys() ?? [] {
      guard let animation = animation(forKey: key) as? CAPropertyAnimation, animation.keyPath == keyPath else {
        continue
      }
      let scaledDuration = animation.speed > 0 ? animation.duration / TimeInterval(animation.speed) : animation.duration
      let animationRemainingTime = animation.beginTime == 0 ? scaledDuration : animation.beginTime + scaledDuration - now
      if animationRemainingTime > 0 {
        remainingTime = max(remainingTime ?? 0, animationRemainingTime)
      }
    }
    return remainingTime
  }
}
