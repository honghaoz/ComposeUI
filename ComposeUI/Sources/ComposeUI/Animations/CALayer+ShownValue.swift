//
//  CALayer+ShownValue.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/26.
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

extension CALayer {

  /// The value a key path shows at the animation clock's current time, which an animation that begins now starts from.
  ///
  /// The value is computed from the model value and the key path's animations, see
  /// `shownValue(forKeyPath:animations:at:)`, instead of read from `presentation()`: Core Animation evaluates the
  /// presentation layers of a transaction at the time of its first presentation read of a layer with animations, which
  /// can be up to a run loop turn away from the clock's time in either direction, and a layer has no presentation layer
  /// before it is committed.
  ///
  /// - Important: An animation added without a key isn't included, since Core Animation doesn't list it, see
  ///   `animationSequence(forKeyPath:)`.
  ///
  /// - Parameter keyPath: The key path.
  /// - Returns: The value.
  func shownValue(forKeyPath keyPath: String) -> Any? {
    // a key path usually has nothing animating, so its model value is returned without reading the clock, which
    // converts the time through every layer up the tree
    guard let animations = animationSequence(forKeyPath: keyPath) else {
      return modelValue(forKeyPath: keyPath)
    }
    return shownValue(forKeyPath: keyPath, animations: animations.lazy.map(\.animation), at: currentTime)
  }

  /// The color a color key path shows, see `shownValue(forKeyPath:)`.
  ///
  /// - Parameter keyPath: The key path.
  /// - Returns: The color, or `nil` without one.
  func shownColor(forKeyPath keyPath: String) -> CGColor? {
    Self.object(shownValue(forKeyPath: keyPath), withTypeID: CGColor.typeID).map { unsafeDowncast($0, to: CGColor.self) }
  }

  /// The path a path key path shows, see `shownValue(forKeyPath:)`.
  ///
  /// - Parameter keyPath: The key path.
  /// - Returns: The path, or `nil` without one.
  func shownPath(forKeyPath keyPath: String) -> CGPath? {
    Self.object(shownValue(forKeyPath: keyPath), withTypeID: CGPath.typeID).map { unsafeDowncast($0, to: CGPath.self) }
  }

  /// The opacity `opacity` or `shadowOpacity` shows, see `shownValue(forKeyPath:)`.
  ///
  /// - Parameter keyPath: The key path.
  /// - Returns: The opacity, or `nil` for another key path.
  func shownOpacity(forKeyPath keyPath: String) -> Float? {
    shownValue(forKeyPath: keyPath) as? Float
  }

  /// The value a key path shows at a time, given its animations.
  ///
  /// The animations that show at the time are evaluated and composed the way Core Animation composes them: an additive
  /// animation's value adds to the value below it, and another animation's value replaces it. An animation that doesn't
  /// show, one that hasn't begun without a backwards fill or has ended, has no effect, whatever its values. The
  /// properties the render server clamps after each animation are clamped the same way: `opacity` and `shadowOpacity` to
  /// [0, 1], and `cornerRadius` at 0, see `animate(keyPath:to:timing:updateAnimation:)`. The values interpolate as Core
  /// Animation interpolates them, see `AnimationInterpolation`.
  ///
  /// - Parameters:
  ///   - keyPath: The key path.
  ///   - animations: The layer's animations that change the key path, in the order Core Animation applies them, see
  ///     `animationSequence(forKeyPath:)`.
  ///   - time: The time in the layer's time space, see `currentTime`.
  /// - Returns: The value. When an animation can't be evaluated, it's the presentation value instead: one that has begun
  ///   or fills backwards, and has a time offset, repeats or autoreverses, see `hasEvaluableTiming`, or a negative speed,
  ///   or one that shows and changes the key path through another key path, see `KeyPathAnimation.indirect`, isn't a
  ///   basic animation from a value to a value, has values that don't interpolate, see `AnimationInterpolation`, or has
  ///   a value function, which only applies to a transform.
  func shownValue(forKeyPath keyPath: String, animations: some Sequence<KeyPathAnimation>, at time: TimeInterval) -> Any? {
    switch keyPath {
    case "opacity":
      if let opacity = composedNumber(model: Double(opacity), clampedTo: 0 ... 1, animations: animations, at: time) {
        return Float(opacity)
      }
    case "shadowOpacity":
      if let opacity = composedNumber(model: Double(shadowOpacity), clampedTo: 0 ... 1, animations: animations, at: time) {
        return Float(opacity)
      }
    case "cornerRadius":
      if let radius = composedNumber(model: Double(cornerRadius), clampedTo: 0 ... .infinity, animations: animations, at: time) {
        return CGFloat(radius)
      }
    default:
      switch composedValue(model: modelValue(forKeyPath: keyPath), animations: animations, at: time) {
      case .value(let value):
        return value
      case .unevaluable:
        break
      }
    }
    // an animation that can't be evaluated, so Core Animation's own evaluation, which is for another time
    return presentation()?.value(forKeyPath: keyPath)
  }

  /// The number the animations show over the model value, clamped after each animation.
  ///
  /// - Returns: The number, or `nil` when an animation can't be evaluated.
  private func composedNumber(model: Double, clampedTo range: ClosedRange<Double>, animations: some Sequence<KeyPathAnimation>, at time: TimeInterval) -> Double? {
    var value = model
    for keyPathAnimation in animations {
      switch keyPathAnimation.effect(at: time) {
      case .noEffect:
        continue
      case .unevaluable:
        return nil
      case .shows(let animation, let progress):
        guard let from = (animation.fromValue as? NSNumber)?.doubleValue, let to = (animation.toValue as? NSNumber)?.doubleValue else {
          return nil
        }
        let animatedValue = from + (to - from) * progress
        value = min(max(animation.isAdditive ? value + animatedValue : animatedValue, range.lowerBound), range.upperBound)
      }
    }
    return value
  }

  /// The value the animations show over the model value.
  private func composedValue(model: Any?, animations: some Sequence<KeyPathAnimation>, at time: TimeInterval) -> ComposedValue {
    var value = model
    for keyPathAnimation in animations {
      switch keyPathAnimation.effect(at: time) {
      case .noEffect:
        continue
      case .unevaluable:
        return .unevaluable
      case .shows(let animation, let progress):
        // a value function, which only applies to a transform, shows its output instead of the interpolated value. the
        // values are read as objects, as Core Animation keeps them, and told apart by their type IDs, since casting an
        // `Any` costs far more
        guard animation.valueFunction == nil,
              let from = animation.fromValue.map({ $0 as AnyObject }), CFGetTypeID(from) != CFNullGetTypeID(),
              let to = animation.toValue.map({ $0 as AnyObject }), CFGetTypeID(to) != CFNullGetTypeID(),
              let animatedValue = AnimationInterpolation.value(from: from, to: to, progress: progress)
        else {
          return .unevaluable
        }
        if animation.isAdditive {
          guard let base = value.flatMap({ AdditiveValue($0) }), let addend = AdditiveValue(animatedValue), base.isSameKind(as: addend) else {
            return .unevaluable
          }
          value = (base + addend).value
        } else {
          value = animatedValue
        }
      }
    }
    return .value(value)
  }

  /// The value as an object of a Core Foundation type, or `nil` for a value of another type or no value.
  private static func object(_ value: Any?, withTypeID typeID: CFTypeID) -> AnyObject? {
    guard let object = value.map({ $0 as AnyObject }), CFGetTypeID(object) == typeID else {
      return nil
    }
    return object
  }
}

private extension CAAnimation {

  /// Whether the animation begins after a time, whatever its speed, which only sets how it runs once it begins. An
  /// unset (zero) `beginTime` becomes the time of the commit, so the animation has begun.
  func begins(after time: TimeInterval) -> Bool {
    beginTime != 0 && time < beginTime
  }

  /// Whether the animation shows its start before it begins.
  var fillsBackwards: Bool {
    fillMode == .backwards || fillMode == .both
  }

  /// Whether the animation shows at a time, given its elapsed time then: before it begins only with a backwards fill,
  /// and once it has ended only when it's kept with a forwards fill, as Core Animation removes it on completion otherwise.
  ///
  /// - Parameters:
  ///   - elapsed: The animation's elapsed time at the time, see `timeSinceBegin(at:)`.
  ///   - time: The time in the layer's time space.
  /// - Returns: Whether the animation shows.
  func shows(atElapsedTime elapsed: TimeInterval, time: TimeInterval) -> Bool {
    if elapsed < 0 {
      return fillsBackwards
    }
    guard remainingTime(at: time) == nil else {
      return true
    }
    return !isRemovedOnCompletion && (fillMode == .forwards || fillMode == .both)
  }
}

private extension KeyPathAnimation {

  /// How the animation affects the value its key path shows at a time.
  ///
  /// Whether the animation has begun is decided first, since one that hasn't begun shows nothing without a backwards
  /// fill, whatever its timing or kind. Whether it has ended depends on its timing, so that's decided once its timing is
  /// known to be evaluated.
  ///
  /// - Parameter time: The time in the layer's time space, see `CALayer.currentTime`.
  /// - Returns: The effect.
  func effect(at time: TimeInterval) -> AnimationEffect {
    // an animation that hasn't begun shows only with a backwards fill, whatever its timing or speed
    if animation.begins(after: time), !animation.fillsBackwards {
      return .noEffect
    }
    // a negative speed runs the animation backwards from its end once it begins, which isn't evaluated
    guard animation.hasEvaluableTiming, animation.speed >= 0 else {
      return .unevaluable
    }
    let elapsed = animation.timeSinceBegin(at: time)
    guard animation.shows(atElapsedTime: elapsed, time: time) else {
      return .noEffect
    }
    guard let basicAnimation = directAnimation as? CABasicAnimation, basicAnimation.byValue == nil else {
      return .unevaluable
    }
    return .shows(basicAnimation, progress: basicAnimation.progress(forElapsedTime: elapsed))
  }
}

/// How an animation affects the value a key path shows at a time.
private enum AnimationEffect {

  /// The animation doesn't show at the time.
  case noEffect

  /// The animation may show, but its timing or kind isn't evaluated, see `CALayer.shownValue(forKeyPath:animations:at:)`.
  case unevaluable

  /// The animation shows its values at a progress, from its from value (0) to its to value (1).
  case shows(CABasicAnimation, progress: Double)
}

/// A key path's composed value, or that an animation of it can't be evaluated.
private enum ComposedValue {

  /// The value, `nil` for a key path without a value, such as a layer without a background color.
  case value(Any?)

  /// An animation of the key path can't be evaluated.
  case unevaluable
}
