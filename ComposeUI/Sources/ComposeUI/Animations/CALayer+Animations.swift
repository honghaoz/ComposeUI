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

/// The duration of a scheduled snap: a zero-duration timing with a delay renders as an instant change after the delay
/// window. Core Animation substitutes its default duration for a zero duration, so the snap uses a sub-frame duration
/// instead.
private let scheduledSnapDuration: TimeInterval = 0.001

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
    if timing.timing.duration <= 0 {
      animation.duration = scheduledSnapDuration
    }
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
    #if os(macOS)
    if keyPath.hasPrefix("position"), let backedView {
      CATransaction.disableAnimations {
        /**
         For `NSView`, changing layer's frame related properties (aka `position`, `bounds.size`, `anchorPoint`) could
         make view's frame and layer's frame out of sync.

         For example:
         ```
         backedView.frame // (196.0, 315.0, 24.0, 28.0)
         layer.position // (196.0, 315.0)
         layer.position = CGPoint(200, 320)
         layer.position // (200.0, 320.0)
         layer.frame // (200.0, 320.0, 24.0, 28.0), which is correct
         backedView.frame // (196.0, 315.0, 24.0, 28.0), which is still the old frame, it's out of sync with the layer's frame
         ```

         For this case, we should correct the view's frame
         */

        position = value as! CGPoint // swiftlint:disable:this force_cast
        backedView.frame = frame
      }
      return
    }
    if keyPath.hasPrefix("bounds.size"), let backedView {
      CATransaction.disableAnimations {
        /**
         ```
         backedView.frame // (196.0, 315.0, 24.0, 28.0)
         layer.frame // (196.0, 315.0, 24.0, 28.0)

         layer.bounds.size = CGSize(50, 80)

         layer.frame // (196.0, 315.0, 50.0, 80.0), which is correct. Note that anchorPoint is (0, 0)
         backedView.frame // (196.0, 315.0, 24.0, 28.0) which is still the old frame, it's out of sync with the layer's frame

         on iOS, anchorPoint is (0.5, 0.5), changing the bounds.size will change the frame around the anchorPoint
         uiView.frame // (200.0, 150.0, 50.0, 50.0)
         uiView.layer.frame // (200.0, 150.0, 50.0, 50.0)

         uiView.layer.bounds.size = CGSize(80, 100)

         uiView.layer.frame // (185.0, 125.0, 80.0, 100.0)
         uiView.frame // (185.0, 125.0, 80.0, 100.0)
         ```
         */

        bounds.size = value as! CGSize // swiftlint:disable:this force_cast
        backedView.frame = frame
      }
      return
    }
    if keyPath.hasPrefix("anchorPoint"), let backedView {
      CATransaction.disableAnimations {
        /**
         ```
         // macOS behavior:
         layer.frame // (196.0, 315.0, 24.0, 28.0)
         backedView.frame // (196.0, 315.0, 24.0, 28.0)

         backingLayer.anchorPoint // (0.0, 0.0)
         backingLayer.anchorPoint = CGPoint(0.5, 0.5)

         backingLayer.frame // (184.0, 301.0, 24.0, 28.0)
         backedView.frame // (196.0, 315.0, 24.0, 28.0)

         // iOS behavior:
         uiView.frame // (200.0, 150.0, 50.0, 50.0)
         uiView.layer.frame // (200.0, 150.0, 50.0, 50.0)

         uiView.layer.anchorPoint = CGPoint(0, 0)

         uiView.layer.frame // (225.0, 175.0, 50.0, 50.0)
         uiView.frame // (225.0, 175.0, 50.0, 50.0)

         // summary: anchorPoint position in the parent view is the same, the view/layer's frame moves accordingly
         ```
         */
        anchorPoint = value as! CGPoint // swiftlint:disable:this force_cast
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
