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
    animate(
      keyPath: "position",
      timing: timing,
      from: { $0.position - $0.position(from: to) },
      to: { _ in .zero },
      model: { $0.position(from: to) },
      updateAnimation: { $0.isAdditive = true }
    )
    animate(
      keyPath: "bounds.size",
      timing: timing,
      from: { $0.bounds.size - to.size },
      to: { _ in .zero },
      model: { _ in to.size },
      updateAnimation: { $0.isAdditive = true }
    )
  }

  /// Animate the layer's value additively.
  ///
  /// - Important: You must make sure the value type matches the key path type. Otherwise, a crash will occur.
  ///
  /// - Important: Additive animations compose on screen only for properties the render server doesn't clamp between
  ///   animations. It clamps opacities (`opacity`, `shadowOpacity`) to [0, 1] after applying each animation, so
  ///   opposing additive animations of an opacity don't compose: the shown value diverges from the sum `presentation()`
  ///   reports. Animate opacities non-additively, or with a single animation that replaces the in-flight one as
  ///   `RenderableTransition.opacity` does. Other bounded properties compose as a sum where verified (`shadowRadius`,
  ///   `CAShapeLayer`'s `strokeStart` and `strokeEnd`).
  ///
  /// - Parameters:
  ///   - keyPath: The key path to animate.
  ///   - to: The value to animate to.
  ///   - timing: The animation timing.
  ///   - updateAnimation: An optional closure to update the animation.
  @_spi(Private)
  func animate<T: FloatingPoint>(keyPath: String, to: T, timing: AnimationTiming, updateAnimation: ((CABasicAnimation) -> Void)? = nil) {
    animate(
      keyPath: keyPath,
      timing: timing,
      from: { ($0.value(forKeyPath: keyPath) as! T) - to }, // swiftlint:disable:this force_cast
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
      from: { ($0.value(forKeyPath: keyPath) as! CGSize) - to }, // swiftlint:disable:this force_cast
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
      from: { ($0.value(forKeyPath: keyPath) as! CGPoint) - to }, // swiftlint:disable:this force_cast
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
  /// The animation is added and the model value is set synchronously. The timing's delay schedules the animation's
  /// begin time in the layer's time space, and the animation's fill mode holds the `from` value until the delay
  /// elapses, so the layer keeps showing its pre-animation state during the delay window while the model value is
  /// already set. A zero-duration timing applies the model value immediately when there is no delay. With a delay,
  /// the change is scheduled as a snap that applies right after the delay window.
  ///
  /// A scheduled animation only survives on a layer that is in a committed layer tree: Core Animation drops animations
  /// on detached layers when the enclosing transaction commits.
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
    if timing.delay > 0 {
      animation.beginTime = currentTime + timing.delay
    }

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

  internal func setKeyPathValue(_ keyPath: String, _ value: Any) {
    #if canImport(AppKit)
    // an NSView's frame doesn't follow its layer's geometry: after `layer.position = CGPoint(200, 320)`, `layer.frame`
    // has moved but `backedView.frame` keeps the old origin, while UIKit keeps the two in sync. so the view's frame is
    // set from the layer's after the change. the value goes through key-value coding, so a component key path such as
    // `position.x` or `bounds.size.width` works like the whole property
    if Self.isViewGeometryKeyPath(keyPath), let backedView {
      CATransaction.disableAnimations {
        setValue(value, forKeyPath: keyPath)
        backedView.frame = frame
      }
      return
    }
    #endif

    if keyPath == "opacity", let backedView {
      guard let newValue = value as? Float else {
        ComposeUI.assertFailure("Expected Float value for \"opacity\" keyPath, got \(type(of: value))")
        return
      }
      CATransaction.disableAnimations {
        backedView.alpha = CGFloat(newValue)
        opacity = newValue
      }
      ComposeUI.assert(CGFloat(opacity) == backedView.alpha)
      return
    }

    CATransaction.disableAnimations {
      setValue(value, forKeyPath: keyPath)
    }
  }

  #if canImport(AppKit)
  /// Whether a key path is a layer property a view's frame is derived from, whole or by component, such as `position`
  /// or `bounds.size.width`.
  private static func isViewGeometryKeyPath(_ keyPath: String) -> Bool {
    switch keyPath.prefix(while: { $0 != "." }) {
    case "position",
         "bounds",
         "anchorPoint":
      return true
    default:
      return false
    }
  }
  #endif

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

  /// The current time in the layer's time space.
  ///
  /// This is the time that the layer's animation begin times are expressed in.
  internal var currentTime: TimeInterval {
    convertTime(CACurrentMediaTime(), from: nil)
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

  /// Removes the layer's animations animating the given key path, leaving other animations alone.
  ///
  /// - Parameter keyPath: The animated key path.
  internal func removeAnimations(forKeyPath keyPath: String) {
    for key in animationKeys() ?? [] where (animation(forKey: key) as? CAPropertyAnimation)?.keyPath == keyPath {
      removeAnimation(forKey: key)
    }
  }
}
