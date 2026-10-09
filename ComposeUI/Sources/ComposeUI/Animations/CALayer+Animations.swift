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

    let objectiveCKeyPath = LayerKeyPath.objectiveC(keyPath)
    let animation = CABasicAnimation.makeAnimation(timing)
    animation.keyPath = objectiveCKeyPath
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
      animation.fromValue = shownValue(forKeyPath: keyPath) ?? value(forKeyPath: objectiveCKeyPath)
    }

    let rawKey = key ?? objectiveCKeyPath
    let animationKey = animation.isAdditive ? uniqueAnimationKey(key: rawKey) : rawKey
    add(animation, forKey: animationKey)
    #if DEBUG
    WorkCounter.count(.animation)
    #endif

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
    guard let animations = animationSequence(forKeyPath: keyPath) else {
      return []
    }
    return animations.compactMap { $0.animation.directAnimation as? CABasicAnimation }
  }

  /// The layer's property animations animating the given key path, such as basic and keyframe animations.
  ///
  /// - Parameter keyPath: The animated key path.
  /// - Returns: The property animations animating `keyPath`, in the layer's animation key order.
  internal func propertyAnimations(forKeyPath keyPath: String) -> [CAPropertyAnimation] {
    guard let animations = animationSequence(forKeyPath: keyPath) else {
      return []
    }
    return animations.compactMap(\.animation.directAnimation)
  }

  /// Removes the layer's property animations animating the given key path, leaving other animations alone.
  ///
  /// An animation that changes the key path through another key path is left alone too, see `KeyPathAnimation.indirect`,
  /// since it's there for the other key path.
  ///
  /// - Parameter keyPath: The animated key path.
  internal func removeAnimations(forKeyPath keyPath: String) {
    guard let animations = animationSequence(forKeyPath: keyPath) else {
      return
    }
    // the sequence walks a copy of the keys, so removing an animation doesn't skip the next one
    for (key, animation) in animations where animation.directAnimation != nil {
      removeAnimation(forKey: key)
    }
  }

  /// The layer's animations that change what the given key path shows, with their keys, looked up as they're iterated:
  /// its property animations of the key path, and the ones that change it through another key path, see
  /// `KeyPathAnimation`.
  ///
  /// The first animation is found when the sequence is created, so a caller can skip the work the animations need, such
  /// as reading the layer's current time, when no animation changes the key path.
  ///
  /// An animation added without a key isn't included, since `animationKeys()` doesn't list it, and without a key it
  /// can't be looked up.
  ///
  /// - Parameter keyPath: The animated key path.
  /// - Returns: The animations in the layer's animation key order, or `nil` when no animation changes the key path.
  internal func animationSequence(forKeyPath keyPath: String) -> KeyPathAnimationSequence? {
    guard let keys = unbridgedAnimationKeys else {
      return nil
    }
    return KeyPathAnimationSequence(layer: self, keyPath: keyPath, keys: keys)
  }

  /// The layer's animation keys, or `nil` when it has no animations.
  ///
  /// `animationKeys()` bridges Core Animation's array of keys to a Swift array of strings, which costs more than
  /// looking up the animations, so the keys are read through `AnimationKeysMessage`, which declares the array as it is.
  internal var unbridgedAnimationKeys: AnimationKeys? {
    let layer: AnyObject = self
    let keys = layer.animationKeyArray?() ?? nil
    return keys.map { AnimationKeys($0) }
  }
}

/// The Objective-C message of `CALayer`'s `animationKeys()`, declared with Core Animation's array of keys as it is
/// instead of bridged to a Swift array of strings, see `CALayer.unbridgedAnimationKeys`.
///
/// Nothing conforms to it. A layer receives the message through `AnyObject`'s lookup of Objective-C methods, by a Swift
/// name no other method has, which checks that the layer responds first. Reinterpreting the layer as the protocol with
/// `unsafeBitCast` would skip the check, but Apple documents `unsafeBitCast` with class types as undefined behavior,
/// and `perform(_:)` costs more, as it adds a dispatch and needs an `autoreleasepool` on every call.
@objc private protocol AnimationKeysMessage {

  @objc(animationKeys)
  func animationKeyArray() -> NSArray?
}

/// A layer's animation keys, read from Core Animation's array of keys as they're accessed, see
/// `CALayer.unbridgedAnimationKeys`.
struct AnimationKeys: RandomAccessCollection {

  private let keys: NSArray

  let endIndex: Int

  var startIndex: Int {
    0
  }

  fileprivate init(_ keys: NSArray) {
    self.keys = keys
    endIndex = keys.count
  }

  subscript(index: Int) -> String {
    // Core Animation's keys are strings
    unsafeDowncast(keys.object(at: index) as AnyObject, to: NSString.self) as String
  }
}

/// A layer's animation that changes what a key path shows, see `CALayer.animationSequence(forKeyPath:)`.
enum KeyPathAnimation {

  /// A property animation of the key path.
  case direct(CAPropertyAnimation)

  /// An animation that changes the key path through another key path: a property animation of a component of the key
  /// path, such as `position.x` of `position`, or of a key path the key path is a component of, such as `bounds` of
  /// `bounds.size`, or a group with an animation of the key path or of such a key path, at any depth.
  case indirect(CAAnimation)

  /// The animation.
  var animation: CAAnimation {
    switch self {
    case .direct(let animation):
      return animation
    case .indirect(let animation):
      return animation
    }
  }

  /// The property animation of the key path, or `nil` for an animation that changes it through another key path.
  var directAnimation: CAPropertyAnimation? {
    switch self {
    case .direct(let animation):
      return animation
    case .indirect:
      return nil
    }
  }
}

/// A layer's animations that change what a key path shows, with their keys, looked up as they're iterated, see
/// `CALayer.animationSequence(forKeyPath:)`.
struct KeyPathAnimationSequence: Sequence, IteratorProtocol {

  private let layer: CALayer
  private let keyPath: String
  private let keys: AnimationKeys
  private var index = 0

  /// The first animation, found when the sequence is created, which `next()` returns first.
  private var first: (key: String, animation: KeyPathAnimation)?

  /// Creates the sequence, or returns `nil` when no animation changes the key path.
  fileprivate init?(layer: CALayer, keyPath: String, keys: AnimationKeys) {
    self.layer = layer
    self.keyPath = keyPath
    self.keys = keys
    guard let first = lookUpNext() else {
      return nil
    }
    self.first = first
  }

  mutating func next() -> (key: String, animation: KeyPathAnimation)? {
    if let first {
      self.first = nil
      return first
    }
    return lookUpNext()
  }

  /// Looks up the next animation that changes the key path, after the keys looked up so far.
  private mutating func lookUpNext() -> (key: String, animation: KeyPathAnimation)? {
    while index < keys.endIndex {
      let key = keys[index]
      index += 1
      let animation = layer.animation(forKey: key)
      if let propertyAnimation = animation as? CAPropertyAnimation, let animatedKeyPath = propertyAnimation.keyPath {
        if animatedKeyPath == keyPath {
          return (key, .direct(propertyAnimation))
        }
        if Self.isKeyPath(animatedKeyPath, aComponentOf: keyPath) || Self.isKeyPath(keyPath, aComponentOf: animatedKeyPath) {
          return (key, .indirect(propertyAnimation))
        }
      } else if let group = animation as? CAAnimationGroup, Self.group(group, changes: keyPath) {
        return (key, .indirect(group))
      }
    }
    return nil
  }

  /// Whether a group changes what a key path shows, with an animation of the key path, of one of its components, or of
  /// a key path it's a component of, directly or in a group of its own.
  private static func group(_ group: CAAnimationGroup, changes keyPath: String) -> Bool {
    group.animations?.contains { animation in
      if let propertyAnimation = animation as? CAPropertyAnimation {
        guard let animatedKeyPath = propertyAnimation.keyPath else {
          return false
        }
        return animatedKeyPath == keyPath || isKeyPath(animatedKeyPath, aComponentOf: keyPath) || isKeyPath(keyPath, aComponentOf: animatedKeyPath)
      }
      return (animation as? CAAnimationGroup).map { Self.group($0, changes: keyPath) } ?? false
    } ?? false
  }

  /// Whether a key path is a component of another, such as `position.x` of `position`: it starts with the other key
  /// path and a dot.
  ///
  /// The bytes are compared instead of splitting the key path into components by character, since splitting by
  /// character segments grapheme clusters, which costs more than the lookup the check is for.
  private static func isKeyPath(_ keyPath: String, aComponentOf otherKeyPath: String) -> Bool {
    let bytes = keyPath.utf8
    let otherBytes = otherKeyPath.utf8
    return bytes.count > otherBytes.count && bytes.starts(with: otherBytes) && bytes.dropFirst(otherBytes.count).first == UInt8(ascii: ".")
  }
}
