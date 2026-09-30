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
  /// `CAAnimation.beginTime(at:delay:)`. The animation's backwards fill, see `CABasicAnimation.makeAnimation(_:)`, holds
  /// the `from` value until the delay elapses, so the layer keeps showing its pre-animation state during the delay window
  /// while the model value is already set. A zero-duration timing applies the model value immediately when there is no
  /// delay. With a delay, the change is scheduled as a snap that applies right after the delay window.
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
  ///     non-additive animation is resolved at dispatch, from the value the layer shows, see `shownValue(forKeyPath:)`,
  ///     falling back to the model value, because the backwards fill can't hold an unresolved value during the delay
  ///     window.
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
      animation.fromValue = shownValue(forKeyPath: keyPath) ?? value(forKeyPath: keyPath)
    }

    let rawKey = key ?? keyPath
    let animationKey = animation.isAdditive ? uniqueAnimationKey(key: rawKey) : rawKey
    add(animation, forKey: animationKey)

    setKeyPathValue(keyPath, model?(layer) ?? toValue)
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
    guard let animations = propertyAnimationSequence(forKeyPath: keyPath) else {
      return []
    }
    return animations.compactMap { $0.animation as? CABasicAnimation }
  }

  /// The layer's property animations animating the given key path, such as basic and keyframe animations.
  ///
  /// - Parameter keyPath: The animated key path.
  /// - Returns: The property animations animating `keyPath`, in the layer's animation key order.
  internal func propertyAnimations(forKeyPath keyPath: String) -> [CAPropertyAnimation] {
    guard let animations = propertyAnimationSequence(forKeyPath: keyPath) else {
      return []
    }
    return animations.map(\.animation)
  }

  /// Removes the layer's animations animating the given key path, leaving other animations alone.
  ///
  /// - Parameter keyPath: The animated key path.
  internal func removeAnimations(forKeyPath keyPath: String) {
    guard let animations = propertyAnimationSequence(forKeyPath: keyPath) else {
      return
    }
    // the sequence walks a copy of the keys, so removing an animation doesn't skip the next one
    for (key, _) in animations {
      removeAnimation(forKey: key)
    }
  }

  /// The layer's property animations animating the given key path, with their keys, looked up as they're iterated.
  ///
  /// The first animation is found when the sequence is created, so a caller can skip the work the animations need, such
  /// as reading the layer's current time, when no animation animates the key path.
  ///
  /// - Parameter keyPath: The animated key path.
  /// - Returns: The animations in the layer's animation key order, or `nil` when no animation animates the key path.
  internal func propertyAnimationSequence(forKeyPath keyPath: String) -> PropertyAnimationSequence? {
    // `animationKeys()` bridges Core Animation's array of keys to a Swift array of strings, which costs more than
    // looking up the animations, so the array is read as it is. `perform(_:)` autoreleases the layer, so a local pool
    // releases it right away instead of keeping a layer its owners let go alive until the run loop's pool drains.
    let keys = autoreleasepool {
      perform(#selector(CALayer.animationKeys))?.takeUnretainedValue() as? NSArray
    }
    guard let keys else {
      return nil
    }
    return PropertyAnimationSequence(layer: self, keyPath: keyPath, keys: keys)
  }
}

/// A layer's property animations animating a key path, with their keys, looked up as they're iterated, see
/// `CALayer.propertyAnimationSequence(forKeyPath:)`.
struct PropertyAnimationSequence: Sequence, IteratorProtocol {

  private let layer: CALayer
  private let keyPath: String
  private let keys: NSArray
  private let keyCount: Int
  private var index = 0

  /// The first animation, found when the sequence is created, which `next()` returns first.
  private var first: (key: String, animation: CAPropertyAnimation)?

  /// Creates the sequence, or returns `nil` when no animation animates the key path.
  fileprivate init?(layer: CALayer, keyPath: String, keys: NSArray) {
    self.layer = layer
    self.keyPath = keyPath
    self.keys = keys
    keyCount = keys.count
    guard let first = lookUpNext() else {
      return nil
    }
    self.first = first
  }

  mutating func next() -> (key: String, animation: CAPropertyAnimation)? {
    if let first {
      self.first = nil
      return first
    }
    return lookUpNext()
  }

  /// Looks up the next animation animating the key path, after the keys looked up so far.
  private mutating func lookUpNext() -> (key: String, animation: CAPropertyAnimation)? {
    while index < keyCount {
      // Core Animation's keys are strings
      let key = unsafeDowncast(keys.object(at: index) as AnyObject, to: NSString.self) as String
      index += 1
      if let animation = layer.animation(forKey: key) as? CAPropertyAnimation, animation.keyPath == keyPath {
        return (key, animation)
      }
    }
    return nil
  }
}
