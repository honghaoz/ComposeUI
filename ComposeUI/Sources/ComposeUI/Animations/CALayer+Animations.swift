//
//  CALayer+Animations.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/25/22.
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

  /// Animate the layer's frame additively.
  ///
  /// The timing's delay schedules the animations' begin time while the model frame updates immediately, see
  /// `animate(key:keyPath:timing:from:to:model:updateAnimation:)`.
  ///
  /// - Parameters:
  ///   - to: The frame to animate to.
  ///   - timing: The animation timing.
  @_spi(Private)
  func animateFrame(to: CGRect, timing: AnimationTiming) {
    // the `bounds.size` write syncs an AppKit backing view from both the position and the size, so the `position` write
    // skips its own sync, which would set the view's frame to an intermediate frame, the new position with the old
    // size, and post a frame-change notification for it
    skippingViewSync {
      animate(keyPath: "position", to: position(from: to), timing: timing)
    }
    animate(keyPath: "bounds.size", to: to.size, timing: timing)
  }

  /// Animate the layer's value additively.
  ///
  /// - Important: You must make sure the value type matches the key path type. Otherwise, a crash will occur.
  ///
  /// - Important: Additive animations compose on screen correctly only for properties the render server doesn't clamp
  ///   between animations. For properties such as `opacity` and `shadowOpacity`, the render server clamps the value to
  ///   [0, 1] after applying each animation, so opposing additive animations of an opacity don't compose: the shown
  ///   value diverges from the sum `presentation()` reports.
  ///
  ///   For properties that may not compose correctly, make sure each animation's value is within the property's valid
  ///   value range or use non-additive animations. `RenderableTransition.opacity`, for example, continues an opacity
  ///   with a single animation that replaces the in-flight one.
  ///
  ///   Properties that compose correctly:
  ///   - `shadowRadius`
  ///   - `borderWidth`
  ///   - `CAShapeLayer`'s `strokeStart` and `strokeEnd`
  ///
  ///   Properties that may not compose correctly:
  ///   - `opacity`, clamped to [0, 1].
  ///   - `shadowOpacity`, clamped to [0, 1].
  ///   - `cornerRadius`, clamped at 0.
  ///
  /// - Parameters:
  ///   - keyPath: The key path to animate.
  ///   - to: The value to animate to.
  ///   - timing: The animation timing.
  ///   - updateAnimation: An optional closure to update the animation.
  @_spi(Private)
  func animate(keyPath: String, to: some FloatingPoint, timing: AnimationTiming, updateAnimation: ((CABasicAnimation) -> Void)? = nil) {
    animate(
      keyPath: keyPath,
      timing: timing,
      from: { $0.floatingPointValue(forKeyPath: keyPath) - to },
      to: { _ in 0 },
      model: { _ in to },
      updateAnimation: {
        $0.isAdditive = true
        updateAnimation?($0)
      }
    )
  }

  /// Animate the layer's value additively.
  ///
  /// - Important: You must make sure the value type matches the key path type. Otherwise, a crash will occur.
  ///
  /// - Parameters:
  ///   - keyPath: The key path to animate.
  ///   - to: The value to animate to.
  ///   - timing: The animation timing.
  ///   - updateAnimation: An optional closure to update the animation.
  @_spi(Private)
  func animate(keyPath: String, to: CGSize, timing: AnimationTiming, updateAnimation: ((CABasicAnimation) -> Void)? = nil) {
    animate(
      keyPath: keyPath,
      timing: timing,
      from: { $0.sizeValue(forKeyPath: keyPath) - to },
      to: { _ in .zero },
      model: { _ in to },
      updateAnimation: {
        $0.isAdditive = true
        updateAnimation?($0)
      }
    )
  }

  /// Animate the layer's value additively.
  ///
  /// - Important: You must make sure the value type matches the key path type. Otherwise, a crash will occur.
  ///
  /// - Parameters:
  ///   - keyPath: The key path to animate.
  ///   - to: The value to animate to.
  ///   - timing: The animation timing.
  ///   - updateAnimation: An optional closure to update the animation.
  @_spi(Private)
  func animate(keyPath: String, to: CGPoint, timing: AnimationTiming, updateAnimation: ((CABasicAnimation) -> Void)? = nil) {
    animate(
      keyPath: keyPath,
      timing: timing,
      from: { $0.pointValue(forKeyPath: keyPath) - to },
      to: { _ in .zero },
      model: { _ in to },
      updateAnimation: {
        $0.isAdditive = true
        updateAnimation?($0)
      }
    )
  }

  /// Add an animation to the layer.
  ///
  /// See `animate(key:keyPath:timing:from:to:model:updateAnimation:)` for the scheduling behavior of a delayed timing.
  ///
  /// - Important: You must make sure the value type matches the key path type. Otherwise, a crash will occur.
  ///
  /// - Parameters:
  ///   - key: The key to use for the animation. If `nil`, the key path will be used.
  ///   - keyPath: The key path to animate.
  ///   - timing: The animation timing.
  ///   - from: The value to animate from.
  ///   - to: The value to animate to.
  ///   - updateAnimation: An optional closure to update the animation.
  @_spi(Private)
  func animate<T>(key: String? = nil,
                  keyPath: String,
                  timing: AnimationTiming,
                  from: (Self) -> T,
                  to: (Self) -> T,
                  updateAnimation: ((CABasicAnimation) -> Void)? = nil)
  {
    // cast `self` to `Self` so the compiler resolves the called overload's `Self` to the dynamic type rather than `CALayer`
    // otherwise, `(Self) -> T` closures fail to convert to `(CALayer) -> T`.
    let layer = self as! Self // swiftlint:disable:this force_cast
    layer.animate( // swiftlint:disable:this force_cast
      key: key,
      keyPath: keyPath,
      timing: timing,
      from: from,
      to: to,
      model: nil,
      updateAnimation: updateAnimation
    )
  }

  /// Add an animation to the layer.
  ///
  /// The animation is added and the model value is set synchronously. The animation begins at the current time of the
  /// animation clock plus the timing's delay, in the layer's time space, see `AnimationClock` and
  /// `CAAnimation.beginTime(at:delay:)`. The animation's fill mode holds the `from` value until the delay elapses, so the
  /// layer keeps showing its pre-animation state during the delay window while the model value is already set. A
  /// zero-duration timing applies the model value immediately when there is no delay. With a delay, the change is
  /// scheduled as a snap that applies right after the delay window.
  ///
  /// The animation only survives on a layer that is in a committed layer tree: Core Animation drops animations on
  /// detached layers when the enclosing transaction commits. The begin time is in the layer's time space when the
  /// animation is added, and Core Animation reads it in the layer's time space at the commit, so add the animation after
  /// the layer joins a tree whose timing differs, such as under an ancestor with a `speed` other than 1.
  ///
  /// - Important: You must make sure the value type matches the key path type. Otherwise, a crash will occur.
  ///
  /// - Parameters:
  ///   - key: The key to use for the animation. If `nil`, the key path will be used.
  ///   - keyPath: The key path to animate.
  ///   - timing: The animation timing.
  ///   - from: The value to animate from. Evaluated before the model value is set. A `nil` value on a scheduled
  ///     non-additive animation is resolved at dispatch, from the presentation value falling back to the model
  ///     value, because the fill mode can't hold an unresolved value during the delay window.
  ///   - to: The value to animate to. Evaluated before the model value is set.
  ///   - model: The model value to set. If `nil`, the `to` value will be used.
  ///   - updateAnimation: An optional closure to update the animation.
  @_spi(Private)
  func animate<T>(key: String? = nil,
                  keyPath: String,
                  timing: AnimationTiming,
                  from: (Self) -> T,
                  to: (Self) -> T,
                  model: ((Self) -> T)?,
                  updateAnimation: ((CABasicAnimation) -> Void)? = nil)
  {
    // cast `self` to `Self` so the closures typed over the extension's `Self` accept it.
    let layer = self as! Self // swiftlint:disable:this force_cast

    guard timing.timing.duration > 0 || timing.delay > 0 else {
      setKeyPathValue(keyPath, model?(layer) ?? to(layer))
      return
    }

    let animation = CABasicAnimation.makeAnimation(timing)
    animation.keyPath = keyPath
    animation.fromValue = from(layer)
    let toValue = to(layer)
    animation.toValue = toValue
    animation.beginTime = CAAnimation.beginTime(at: currentTime, delay: timing.delay)

    updateAnimation?(animation)

    // a nil `T` boxes as `NSNull` when `T` is an optional type, which Core Animation also treats as unresolved
    let isFromValueUnresolved = animation.fromValue == nil || animation.fromValue is NSNull
    if timing.delay > 0, isFromValueUnresolved, !animation.isAdditive {
      // a scheduled to-only animation can't backwards-fill an unresolved from value (the fill would show the target),
      // so resolve it at dispatch the way Core Animation would at activation
      animation.fromValue = presentation()?.value(forKeyPath: keyPath) ?? value(forKeyPath: keyPath)
    }

    let rawKey = key ?? keyPath
    let animationKey = animation.isAdditive ? uniqueAnimationKey(key: rawKey) : rawKey
    add(animation, forKey: animationKey)

    setKeyPathValue(keyPath, model?(layer) ?? toValue)
  }

  // a read through KVC boxes the value in an `NSValue` or `NSNumber` and casts it back, which costs a sizable share of
  // setting up an animation, so the typed `animate(keyPath:to:timing:updateAnimation:)` overloads read the current value
  // with the functions below, which read the properties the framework animates directly

  /// Get the layer's model value at a key path whose value is a `CGPoint`.
  ///
  /// `position` is read directly, other key paths through KVC.
  ///
  /// - Important: The key path's value must be a `CGPoint`. Otherwise, a crash will occur.
  ///
  /// - Parameter keyPath: The key path to read.
  /// - Returns: The value at the key path.
  internal func pointValue(forKeyPath keyPath: String) -> CGPoint {
    switch keyPath {
    case "position":
      return position
    default:
      return value(forKeyPath: keyPath) as! CGPoint // swiftlint:disable:this force_cast
    }
  }

  /// Get the layer's model value at a key path whose value is a `CGSize`.
  ///
  /// `bounds.size` and `shadowOffset` are read directly, other key paths through KVC.
  ///
  /// - Important: The key path's value must be a `CGSize`. Otherwise, a crash will occur.
  ///
  /// - Parameter keyPath: The key path to read.
  /// - Returns: The value at the key path.
  internal func sizeValue(forKeyPath keyPath: String) -> CGSize {
    switch keyPath {
    case "bounds.size":
      return bounds.size
    case "shadowOffset":
      return shadowOffset
    default:
      return value(forKeyPath: keyPath) as! CGSize // swiftlint:disable:this force_cast
    }
  }

  /// Get the layer's model value at a key path whose value is a floating-point number.
  ///
  /// `opacity`, `shadowOpacity`, `borderWidth`, `cornerRadius`, and `shadowRadius` are read directly when `T` is the
  /// property's type. Other key paths and types are read through KVC.
  ///
  /// - Important: The key path's value must be a number that casts to `T`. Otherwise, a crash will occur.
  ///
  /// - Parameter keyPath: The key path to read.
  /// - Returns: The value at the key path.
  internal func floatingPointValue<T: FloatingPoint>(forKeyPath keyPath: String) -> T {
    // a direct read is only taken for the property's own type, as other types rely on the conversion of KVC's boxed
    // number, for example reading the `Float` opacity as a `CGFloat`
    switch keyPath {
    case "opacity":
      if let value = opacity as? T {
        return value
      }
    case "shadowOpacity":
      if let value = shadowOpacity as? T {
        return value
      }
    case "borderWidth":
      if let value = borderWidth as? T {
        return value
      }
    case "cornerRadius":
      if let value = cornerRadius as? T {
        return value
      }
    case "shadowRadius":
      if let value = shadowRadius as? T {
        return value
      }
    default:
      break
    }
    return value(forKeyPath: keyPath) as! T // swiftlint:disable:this force_cast
  }

  /// Get a unique animation key.
  ///
  /// This is useful when you want to add multiple animations, such as additive animations, with the same name to a layer.
  ///
  /// For example, if the animation for "position" already exists, the function will return "position-1".
  ///
  /// - Parameters:
  ///   - key: The desired animation key.
  /// - Returns: A unique animation key.
  @_spi(Private)
  func uniqueAnimationKey(key: String) -> String {
    var currentKey = key
    var counter = 1

    while animation(forKey: currentKey) != nil {
      currentKey = "\(key)-\(counter)"
      counter += 1
    }

    return currentKey
  }

  /// The current time in the layer's time space, read from the animation clock, see `AnimationClock`.
  ///
  /// This is the time that the layer's animation begin times are expressed in.
  internal var currentTime: TimeInterval {
    convertTime(AnimationClock.now, from: nil)
  }

  /// The layer's basic animations animating the given key path.
  ///
  /// - Parameter keyPath: The animated key path.
  /// - Returns: The basic animations animating `keyPath`, in the layer's animation key order.
  internal func basicAnimations(forKeyPath keyPath: String) -> [CABasicAnimation] {
    (animationKeys() ?? []).compactMap { key in
      guard let animation = animation(forKey: key) as? CABasicAnimation, animation.keyPath == keyPath else {
        return nil
      }
      return animation
    }
  }

  /// The layer's property animations animating the given key path, such as basic and keyframe animations.
  ///
  /// - Parameter keyPath: The animated key path.
  /// - Returns: The property animations animating `keyPath`, in the layer's animation key order.
  internal func propertyAnimations(forKeyPath keyPath: String) -> [CAPropertyAnimation] {
    (animationKeys() ?? []).compactMap { key in
      guard let animation = animation(forKey: key) as? CAPropertyAnimation, animation.keyPath == keyPath else {
        return nil
      }
      return animation
    }
  }

  /// Removes the layer's animations animating the given key path, leaving other animations alone.
  ///
  /// - Parameter keyPath: The animated key path.
  internal func removeAnimations(forKeyPath keyPath: String) {
    for key in animationKeys() ?? [] where (animation(forKey: key) as? CAPropertyAnimation)?.keyPath == keyPath {
      removeAnimation(forKey: key)
    }
  }
}
