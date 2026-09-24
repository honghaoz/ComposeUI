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

  /// Sets a key path's value and retargets its in-flight animations to it, so the shown value glides from where it is
  /// to the new value and lands when the in-flight animations would have.
  ///
  /// - Without in-flight animations, the value is set directly. An animation already heading to the value is left alone.
  ///   An ended animation still on the layer is removed, since a forwards fill would show its end value over the new one.
  /// - Additive animations of numbers, `CGSize` and `CGPoint` are folded into one additive ease-out from the value they
  ///   show, so later additive animations keep stacking on it. A running spring keeps going instead, so its momentum
  ///   carries on, with the ease-out stacked on it. Stacked additive animations show their sum only for properties the
  ///   render server doesn't clamp between animations, see `animate(keyPath:to:timing:)`.
  /// - Other animations are replaced by one ease-out animation from the shown value. Note that additive animations of
  ///   `opacity` and `shadowOpacity` are replaced too, since the render server clamps them after each animation and
  ///   stacked animations wouldn't compose on screen.
  ///
  /// A folded or replaced animation is removed, so its delegate is told it stopped before finishing.
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

    // uses the basic easing curve for simplicity, no interrupted velocity to carry
    let timing = AnimationTiming.easeOut(duration: remainingTime)

    if let currentValue, let fold = additiveFold(of: inFlightAnimations, keyPath: keyPath, from: currentValue, to: value, at: now) {
      for key in fold.keys {
        removeAnimation(forKey: key)
      }

      guard !fold.offset.isZero else {
        // the shown value already is the new value, so there is nothing to glide
        setKeyPathValue(keyPath, value)
        return
      }

      // the glide is additive, so the animations kept alongside it and later animated updates stack on it
      animate(
        keyPath: keyPath,
        timing: timing,
        from: { _ in fold.offset.value },
        to: { _ in fold.offset.zero.value },
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

      if let remainingTime = animation.remainingTime(at: now) {
        inFlightAnimations.append(InFlightAnimation(key: key, animation: animation, remainingTime: remainingTime))
      } else if removingEnded {
        removeAnimation(forKey: key)
      }
    }
    return inFlightAnimations
  }

  /// The in-flight additive animations to fold into one glide to the new value, and the offset of the shown value from
  /// the new value, which the glide starts from.
  ///
  /// A running spring that lands on the model value isn't folded: it keeps going, so its momentum carries on, and lands
  /// on the new model value on its own.
  ///
  /// - Returns: The fold, or `nil` when the animations can't be folded: the render server clamps the key path after each
  ///   animation, the values aren't numbers, sizes or points of one kind, or an animation isn't an additive basic
  ///   animation whose value can be computed.
  private func additiveFold(of animations: [InFlightAnimation],
                            keyPath: String,
                            from oldValue: Any,
                            to newValue: Any,
                            at now: TimeInterval) -> (keys: [String], offset: AdditiveValue)?
  {
    guard !Constants.clampedKeyPaths.contains(keyPath),
          let oldValue = AdditiveValue(oldValue),
          let newValue = AdditiveValue(newValue),
          oldValue.isSameKind(as: newValue)
    else {
      return nil
    }

    // the model change alone would show as a jump of `old - new`, and each folded animation adds its value on top
    var offset = oldValue - newValue
    var keys: [String] = []
    for inFlightAnimation in animations {
      guard let animation = inFlightAnimation.animation as? CABasicAnimation,
            animation.isAdditive,
            let (from, to) = animation.additiveValues(ofKind: oldValue, at: now)
      else {
        return nil
      }

      if to.isZero, animation is CASpringAnimation, animation.speed > 0 {
        continue
      }

      // an unset begin time resolves to the next commit, so the animation hasn't moved yet
      let elapsed = animation.beginTime == 0 ? 0 : (now - animation.beginTime) * TimeInterval(animation.speed)
      offset += from + (to - from).scaled(by: animation.progress(forElapsedTime: elapsed))
      keys.append(inFlightAnimation.key)
    }
    return (keys, offset)
  }

  // MARK: - Constants

  private enum Constants {

    /// The key paths the render server clamps to [0, 1] after each animation, so the sum of their additive animations
    /// isn't what shows, see `animate(keyPath:to:timing:)`.
    static let clampedKeyPaths: Set<String> = ["opacity", "shadowOpacity"]
  }
}

/// An in-flight property animation of a layer.
private struct InFlightAnimation {

  /// The key the animation is on the layer.
  let key: String

  /// The animation.
  let animation: CAPropertyAnimation

  /// The time the animation has left, in seconds of the layer's time space.
  let remainingTime: TimeInterval
}

private extension CABasicAnimation {

  /// The animation's from and to values, when both are of `kind` and the animation's value at a time can be computed
  /// the way `progress(forElapsedTime:)` evaluates it, otherwise `nil`.
  ///
  /// The evaluation doesn't cover a by value, repeats and time offsets, and a scheduled animation without a backwards
  /// fill doesn't show its from value until it begins.
  func additiveValues(ofKind kind: AdditiveValue, at now: TimeInterval) -> (from: AdditiveValue, to: AdditiveValue)? {
    guard byValue == nil,
          repeatCount == 0,
          repeatDuration == 0,
          !autoreverses,
          timeOffset == 0,
          beginTime <= now || fillMode == .backwards || fillMode == .both,
          let from = fromValue.flatMap({ AdditiveValue($0) }),
          from.isSameKind(as: kind),
          let to = toValue.flatMap({ AdditiveValue($0) }),
          to.isSameKind(as: kind)
    else {
      return nil
    }
    return (from, to)
  }
}

/// A value of a kind that animates additively, a number, `CGSize` or `CGPoint`, as two components.
///
/// A number uses the first component and leaves the second at zero, so the component-wise math is the same for every
/// kind.
private struct AdditiveValue {

  private enum Kind {
    case number
    case size
    case point
  }

  private let kind: Kind

  /// The components: the number and zero, width and height, or x and y.
  private let components: SIMD2<Double>

  /// Creates the value from a number, `CGSize` or `CGPoint`, as Core Animation boxes them.
  ///
  /// - Returns: `nil` for a value of another kind.
  init?(_ value: Any) {
    if let size = value as? CGSize {
      kind = .size
      components = SIMD2(size.width, size.height)
    } else if let point = value as? CGPoint {
      kind = .point
      components = SIMD2(point.x, point.y)
    } else if let number = value as? NSNumber {
      kind = .number
      components = SIMD2(number.doubleValue, 0)
    } else {
      return nil
    }
  }

  private init(kind: Kind, components: SIMD2<Double>) {
    self.kind = kind
    self.components = components
  }

  /// The value as Core Animation boxes it.
  var value: Any {
    switch kind {
    case .number:
      return components.x
    case .size:
      return CGSize(width: components.x, height: components.y)
    case .point:
      return CGPoint(x: components.x, y: components.y)
    }
  }

  /// The zero of the value's kind.
  var zero: AdditiveValue {
    AdditiveValue(kind: kind, components: .zero)
  }

  /// Whether every component is zero.
  var isZero: Bool {
    components == .zero
  }

  func isSameKind(as other: AdditiveValue) -> Bool {
    kind == other.kind
  }

  /// The value with every component multiplied by `factor`.
  func scaled(by factor: Double) -> AdditiveValue {
    AdditiveValue(kind: kind, components: components * factor)
  }

  /// The component-wise sum of two values of the same kind.
  static func + (lhs: AdditiveValue, rhs: AdditiveValue) -> AdditiveValue {
    AdditiveValue(kind: lhs.kind, components: lhs.components + rhs.components)
  }

  static func += (lhs: inout AdditiveValue, rhs: AdditiveValue) {
    lhs = lhs + rhs
  }

  /// The component-wise difference of two values of the same kind.
  static func - (lhs: AdditiveValue, rhs: AdditiveValue) -> AdditiveValue {
    AdditiveValue(kind: lhs.kind, components: lhs.components - rhs.components)
  }
}
