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
  /// This is useful for setting a property without animating the change while existing animations of it are in flight:
  /// the motion continues from where it is and lands on the new value when it would have.
  ///
  /// If no in-flight animations are found, the value is set without an implicit action. An in-flight animation already
  /// heading to the value is left alone.
  ///
  /// Additive in-flight animations are deltas that land on the model value on their own, so they are kept, and one more
  /// additive animation is added on top of them: a delta from the old value to the new one, decaying to zero over the
  /// time the longest of them has left. It cancels the jump the model change would show and fades out as they
  /// land, and later animated updates keep stacking on them. The delta is computed for numbers, `CGSize` and `CGPoint`.
  ///
  /// Otherwise the in-flight animations are replaced by one animation from the value the layer currently shows to
  /// `value`, easing out over the time the longest of them had left. With several animations in flight, the layer shows
  /// what Core Animation composes from them (the last non-additive one added wins), and the retarget starts from that.
  /// Additive animations of a kind without a delta, or mixed with non-additive ones, are replaced the same way.
  ///
  /// The retarget carries neither the interrupted animation's curve nor its velocity.
  ///
  /// - Important: You must make sure the value type matches the key path type. Otherwise, a crash will occur.
  ///
  /// - Parameters:
  ///   - keyPath: The key path to set.
  ///   - value: The value to set.
  func retarget(keyPath: String, to value: Any) {
    let inFlightAnimations = inFlightAnimations(forKeyPath: keyPath)
    guard let remainingTime = inFlightAnimations.map(\.remainingTime).max() else {
      // no in-flight animations, set the value directly
      setKeyPathValue(keyPath, value)
      return
    }

    // an in-flight animation already heading to the value keeps its easing, skipping the retarget
    let currentValue = self.value(forKeyPath: keyPath)
    if let currentValue, (currentValue as AnyObject).isEqual(value) {
      return
    }

    // uses the basic easing curve for simplicity, no interrupted velocity to carry
    let timing = AnimationTiming.easeOut(duration: remainingTime)

    if inFlightAnimations.allSatisfy(\.animation.isAdditive),
       let currentValue,
       let delta = AdditiveDelta(from: currentValue, to: value)
    {
      // keep the additive animations and stack a decaying delta from the old value on top, so the shown value doesn't
      // jump when the model changes and the animations land on the new model value as they finish
      animate(
        keyPath: keyPath,
        timing: timing,
        from: { _ in delta.value },
        to: { _ in delta.zero },
        model: { _ in value },
        updateAnimation: { $0.isAdditive = true }
      )
    } else {
      // remove the in-flight animations and replace them with a new one from the current value to the new value
      removeAnimations(forKeyPath: keyPath)
      animate(
        keyPath: keyPath,
        timing: timing,
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
    inFlightAnimations(forKeyPath: keyPath).map(\.remainingTime).max()
  }

  /// The layer's property animations of the given key path that haven't ended, each with the time it has left.
  private func inFlightAnimations(forKeyPath keyPath: String) -> [(animation: CAPropertyAnimation, remainingTime: TimeInterval)] {
    let now = currentTime
    return (animationKeys() ?? []).compactMap { key in
      guard let animation = animation(forKey: key) as? CAPropertyAnimation, animation.keyPath == keyPath else {
        return nil
      }

      let scaledDuration = animation.speed > 0 ? animation.duration / TimeInterval(animation.speed) : animation.duration
      let remainingTime = animation.beginTime == 0 ? scaledDuration : animation.beginTime + scaledDuration - now
      guard remainingTime > 0 else {
        return nil
      }

      return (animation, remainingTime)
    }
  }
}

/// The additive delta from an old value to a new one, for the value kinds that animate additively.
private struct AdditiveDelta {

  /// The delta, `old - new`.
  let value: Any

  /// The zero of the delta's kind, the value the delta decays to.
  let zero: Any

  /// Creates the delta for numbers, `CGSize` and `CGPoint` values, as Core Animation boxes them.
  ///
  /// - Returns: `nil` when the values are of another kind or of different kinds.
  init?(from oldValue: Any, to newValue: Any) {
    if let oldSize = oldValue as? CGSize, let newSize = newValue as? CGSize {
      value = CGSize(width: oldSize.width - newSize.width, height: oldSize.height - newSize.height)
      zero = CGSize.zero
    } else if let oldPoint = oldValue as? CGPoint, let newPoint = newValue as? CGPoint {
      value = CGPoint(x: oldPoint.x - newPoint.x, y: oldPoint.y - newPoint.y)
      zero = CGPoint.zero
    } else if let oldNumber = oldValue as? NSNumber, let newNumber = newValue as? NSNumber {
      value = oldNumber.doubleValue - newNumber.doubleValue
      zero = 0.0
    } else {
      return nil
    }
  }
}
