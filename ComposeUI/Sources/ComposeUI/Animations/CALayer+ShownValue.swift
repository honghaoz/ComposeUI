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
  /// - Parameter keyPath: The key path.
  /// - Returns: The value.
  func shownValue(forKeyPath keyPath: String) -> Any? {
    // a key path usually has nothing animating, so its model value is returned without reading the clock, which
    // converts the time through every layer up the tree
    guard let animations = propertyAnimationSequence(forKeyPath: keyPath) else {
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
  /// The animations are evaluated at the time and composed the way Core Animation composes them: an additive animation's
  /// value adds to the value below it, and another animation's value replaces it. The properties the render server
  /// clamps after each animation are clamped the same way: `opacity` and `shadowOpacity` to [0, 1], and `cornerRadius`
  /// at 0, see `animate(keyPath:to:timing:updateAnimation:)`. The values interpolate as Core Animation interpolates them,
  /// see `AnimationInterpolation`.
  ///
  /// - Parameters:
  ///   - keyPath: The key path.
  ///   - animations: The layer's property animations of the key path, in the order Core Animation applies them.
  ///   - time: The time in the layer's time space, see `currentTime`.
  /// - Returns: The value. When an animation can't be evaluated, it's the presentation value instead: one that isn't a
  ///   basic animation from a value to a value, whose values don't interpolate, see `AnimationInterpolation`, or whose
  ///   timing `elapsedTime(at:)` doesn't evaluate.
  func shownValue(forKeyPath keyPath: String, animations: some Sequence<CAPropertyAnimation>, at time: TimeInterval) -> Any? {
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
  private func composedNumber(model: Double, clampedTo range: ClosedRange<Double>, animations: some Sequence<CAPropertyAnimation>, at time: TimeInterval) -> Double? {
    var value = model
    for animation in animations {
      guard let animation = animation as? CABasicAnimation,
            animation.byValue == nil,
            let from = (animation.fromValue as? NSNumber)?.doubleValue,
            let to = (animation.toValue as? NSNumber)?.doubleValue,
            let elapsed = animation.elapsedTime(at: time)
      else {
        return nil
      }
      guard animation.shows(atElapsedTime: elapsed, time: time) else {
        continue
      }

      let animatedValue = from + (to - from) * animation.progress(forElapsedTime: elapsed)
      value = min(max(animation.isAdditive ? value + animatedValue : animatedValue, range.lowerBound), range.upperBound)
    }
    return value
  }

  /// The value the animations show over the model value.
  private func composedValue(model: Any?, animations: some Sequence<CAPropertyAnimation>, at time: TimeInterval) -> ComposedValue {
    var value = model
    for animation in animations {
      // the values are read as objects, as Core Animation keeps them, and told apart by their type IDs, since casting an
      // `Any` costs far more
      guard let animation = animation as? CABasicAnimation,
            animation.byValue == nil,
            let from = animation.fromValue.map({ $0 as AnyObject }), CFGetTypeID(from) != CFNullGetTypeID(),
            let to = animation.toValue.map({ $0 as AnyObject }), CFGetTypeID(to) != CFNullGetTypeID(),
            let elapsed = animation.elapsedTime(at: time)
      else {
        return .unevaluable
      }
      guard animation.shows(atElapsedTime: elapsed, time: time) else {
        continue
      }

      guard let animatedValue = AnimationInterpolation.value(from: from, to: to, progress: animation.progress(forElapsedTime: elapsed)) else {
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

private extension CABasicAnimation {

  /// Whether the animation shows at a time, given its elapsed time then: before it begins only with a backwards fill,
  /// and once it has ended only when it's kept with a forwards fill, as Core Animation removes it on completion otherwise.
  ///
  /// - Parameters:
  ///   - elapsed: The animation's elapsed time at the time, see `elapsedTime(at:)`.
  ///   - time: The time in the layer's time space.
  /// - Returns: Whether the animation shows.
  func shows(atElapsedTime elapsed: TimeInterval, time: TimeInterval) -> Bool {
    if elapsed < 0 {
      return fillMode == .backwards || fillMode == .both
    }
    guard remainingTime(at: time) == nil else {
      return true
    }
    return !isRemovedOnCompletion && (fillMode == .forwards || fillMode == .both)
  }
}

/// A key path's composed value, or that an animation of it can't be evaluated.
private enum ComposedValue {

  /// The value, `nil` for a key path without a value, such as a layer without a background color.
  case value(Any?)

  /// An animation of the key path can't be evaluated.
  case unevaluable
}
