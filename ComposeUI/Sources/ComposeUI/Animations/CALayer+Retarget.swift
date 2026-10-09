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
  /// to the new value and lands when the in-flight animations would have. With an in-flight animation that never
  /// finishes, such as a spring without damping, the glide takes `Animations.defaultAnimationDuration` instead.
  ///
  /// - A value the model already has leaves the layer alone, as its in-flight animations already head to it. Without
  ///   in-flight animations, the value is set directly. An ended animation is skipped, as Core Animation removes it.
  /// - Additive animations of numbers, `CGSize` and `CGPoint` are folded into one additive ease-out from the value they
  ///   show, so later additive animations keep stacking on it. A running spring keeps going instead, so its momentum
  ///   carries on, with the ease-out stacked on it. Stacked additive animations show their sum only for properties the
  ///   render server doesn't clamp between animations, see `animate(keyPath:to:timing:)`.
  /// - Other animations are replaced by one ease-out animation from the shown value. Note that additive animations of
  ///   `opacity` and `shadowOpacity` are replaced too, since the render server clamps them after each animation and
  ///   stacked animations wouldn't compose on screen.
  ///
  /// A folded or replaced animation is removed, so its delegate is told it stopped before finishing. An animation that
  /// changes the key path through another key path, such as a group or an animation of `position.x` for `position`, is
  /// neither folded nor replaced, since it's there for the other key path, and keeps running.
  ///
  /// - Important: The value's type must match the key path's, or Core Animation crashes.
  /// - Important: Animations kept with `isRemovedOnCompletion` off aren't supported.
  /// - Important: Animations added without a key aren't retargeted or accounted for, since Core Animation doesn't list
  ///   them.
  ///
  /// - Parameters:
  ///   - keyPath: The key path to set.
  ///   - value: The value to set.
  func retarget(keyPath: String, to value: Any) {
    // the model already has the value, so the in-flight animations already head to it, nothing to change
    if hasModelValue(value, forKeyPath: keyPath) {
      return
    }

    guard let animations = inFlightAnimations(forKeyPath: keyPath) else {
      // nothing animates the key path, set the value directly
      setKeyPathValue(keyPath, value)
      return
    }
    let (inFlightAnimations, indirectAnimations, endedKeptKeys, now) = animations

    // a kept animation that has ended would cover the new value
    for key in endedKeptKeys {
      removeAnimation(forKey: key)
    }

    guard let remainingTime = inFlightAnimations.max(by: { $0.remainingTime < $1.remainingTime })?.remainingTime else {
      // no in-flight animations, set the value directly
      setKeyPathValue(keyPath, value)
      return
    }

    // an animation that never finishes has no landing to glide to, so the glide takes the default duration instead of forever
    let neverFinishes = inFlightAnimations.contains(where: { CAAnimation.neverFinishes(duration: $0.animation.duration) })

    // uses the basic easing curve for simplicity, no interrupted velocity to carry
    let timing = AnimationTiming.easeOut(duration: neverFinishes ? Animations.defaultAnimationDuration : remainingTime)

    if let fold = additiveFold(of: inFlightAnimations, keyPath: keyPath, to: value, at: now) {
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
      // replace the in-flight animations with a new one from the value they show to the new value.
      // an animation that changes the key path through another key path keeps running and is part of the start value,
      // which only then needs the animations in one array
      let startValue = indirectAnimations.isEmpty
        ? shownValue(forKeyPath: keyPath, animations: inFlightAnimations.lazy.map { KeyPathAnimation.direct($0.animation) }, at: now)
        : shownValue(forKeyPath: keyPath, animations: indirectAnimations + inFlightAnimations.map { KeyPathAnimation.direct($0.animation) }, at: now)
      for inFlightAnimation in inFlightAnimations {
        removeAnimation(forKey: inFlightAnimation.key)
      }
      animate(
        keyPath: keyPath,
        timing: timing,
        from: { _ in startValue },
        to: { _ -> Any? in value }
      )
    }
  }

  /// The layer's property animations of the given key path that haven't ended at `now`, its animations that change the
  /// key path through another key path, the keys of the kept property animations that have ended, and `now`, the
  /// layer's current time.
  ///
  /// An animation that changes the key path through another key path, see `KeyPathAnimation.indirect`, isn't one of the
  /// in-flight animations, since it's there for the other key path, so the retarget neither folds nor removes it.
  ///
  /// Returns `nil` when no animation changes the key path, without reading the current time, since reading it converts
  /// the time through the layer tree, and a layer usually has nothing animating.
  private func inFlightAnimations(forKeyPath keyPath: String) -> (animations: [InFlightAnimation], indirectAnimations: [KeyPathAnimation], endedKeptKeys: [String], now: TimeInterval)? {
    guard let animations = animationSequence(forKeyPath: keyPath) else {
      return nil
    }

    let now = currentTime
    var inFlightAnimations: [InFlightAnimation] = []
    var indirectAnimations: [KeyPathAnimation] = []
    var endedKeptKeys: [String] = []
    for (key, keyPathAnimation) in animations {
      guard let animation = keyPathAnimation.directAnimation else {
        indirectAnimations.append(keyPathAnimation)
        continue
      }
      ComposeUI.assert(
        animation.isRemovedOnCompletion,
        "animation \"\(key)\" of \"\(keyPath)\" is kept with isRemovedOnCompletion off, which isn't supported"
      )

      if let remainingTime = animation.remainingTime(at: now) {
        inFlightAnimations.append(InFlightAnimation(key: key, animation: animation, remainingTime: remainingTime))
      } else if !animation.isRemovedOnCompletion {
        endedKeptKeys.append(key)
      }
    }
    return (inFlightAnimations, indirectAnimations, endedKeptKeys, now)
  }

  /// The in-flight additive animations to fold into one glide to the new value, and the offset of the shown value from
  /// the new value, which the glide starts from.
  ///
  /// A running spring that lands on the model value isn't folded: it keeps going, so its momentum carries on, and lands
  /// on the new model value on its own. A spring scheduled to begin later is folded, since it has no momentum yet and
  /// holds its from value until it begins, which would pull the shown value away once the glide lands.
  ///
  /// - Returns: The fold, or `nil` when the animations can't be folded: the render server clamps the key path after each
  ///   animation, the values aren't numbers, sizes or points of one kind, or an animation isn't an additive basic
  ///   animation whose value can be computed.
  private func additiveFold(of animations: [InFlightAnimation],
                            keyPath: String,
                            to newValue: Any,
                            at now: TimeInterval) -> (keys: [String], offset: AdditiveValue)?
  {
    // a key path the framework doesn't animate is read through KVC, so the model value is read only once the new value
    // can fold
    guard !Constants.clampedKeyPaths.contains(keyPath),
          let newValue = AdditiveValue(newValue),
          let currentValue = modelValue(forKeyPath: keyPath),
          let oldValue = AdditiveValue(currentValue),
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
            let elapsed = animation.elapsedTime(at: now),
            let (from, to) = animation.additiveValues(ofKind: oldValue, at: now)
      else {
        return nil
      }

      if to.isZero, animation is CASpringAnimation, animation.speed > 0, animation.beginTime <= now {
        continue
      }

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

  /// The animation's from and to values, when both are of `kind` and the value the animation shows at `now`
  /// interpolates them, otherwise `nil`. The timing, which gives the progress to interpolate by, is checked by
  /// `elapsedTime(at:)`.
  ///
  /// A by value isn't evaluated, and a scheduled animation without a backwards fill doesn't show its from value until
  /// it begins.
  func additiveValues(ofKind kind: AdditiveValue, at now: TimeInterval) -> (from: AdditiveValue, to: AdditiveValue)? {
    guard byValue == nil,
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
