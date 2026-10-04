//
//  CALayer+FrameAnimation.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/4/26.
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

  // MARK: - Animate

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
    let newPosition = position(from: to)
    if timing.timing.duration > 0 || timing.delay > 0 {
      let oldPosition = position
      let anchorPoint = self.anchorPoint
      let size = bounds.size
      let positionOffset = SIMD2<Double>(oldPosition.x - newPosition.x, oldPosition.y - newPosition.y)
      let sizeOffset = SIMD2<Double>(size.width - to.width, size.height - to.height)
      // the position moves with the size by the anchor point times its change, which a frame retarget folds apart from
      // the origin's part
      let sizeShare = SIMD2(anchorPoint.x, anchorPoint.y) * sizeOffset
      let originPart = positionOffset - sizeShare
      let positionPart: FrameAnimationPart
      switch (FrameAxes(of: originPart).isEmpty, FrameAxes(of: sizeShare).isEmpty) {
      case (_, true):
        positionPart = .origin
      case (true, false):
        positionPart = .sizeShare
      case (false, false):
        positionPart = .originAndSizeShare(originPart: originPart)
      }

      let beginTime = CAAnimation.beginTime(at: currentTime, delay: timing.delay)
      addFrameAnimation(
        keyPath: "position",
        from: CGPoint(x: positionOffset.x, y: positionOffset.y),
        to: CGPoint.zero,
        timing: timing,
        beginTime: beginTime,
        part: positionPart
      )
      addFrameAnimation(
        keyPath: "bounds.size",
        from: CGSize(width: sizeOffset.x, height: sizeOffset.y),
        to: CGSize.zero,
        timing: timing,
        beginTime: beginTime,
        part: .size
      )
    }

    // the `bounds.size` write syncs an AppKit backing view from both the position and the size, so the `position` write
    // skips its own sync, which would set the view's frame to an intermediate frame, the new position with the old
    // size, and post a frame-change notification for it
    skippingViewSync {
      setKeyPathValue("position", newPosition)
    }
    setKeyPathValue("bounds.size", to.size)
  }

  // MARK: - Retarget

  /// Sets the layer's frame and retargets its in-flight frame animations to it, so the frame glides from where it shows
  /// to the new frame and lands when the animations would have, as `retarget(keyPath:to:)` does for a key path.
  ///
  /// - The origin and the size are judged apart, axis by axis: an axis that a frame animation in flight moves glides
  ///   from where it shows, and one at rest takes its new value at once, as the height does during a move. A part
  ///   without a changed axis in motion keeps its animations, as they still head to its new value.
  /// - Only the animations of `animateFrame(to:timing:)` and of earlier frame retargets are retargeted, so other
  ///   animations of `position` and `bounds.size`, such as a slide transition's, keep going.
  /// - A running spring keeps going, with the glide stacked on it, as in `retarget(keyPath:to:)`.
  ///
  /// - Precondition: The layer's transform must be identity.
  ///
  /// - Parameter frame: The frame to set.
  @_spi(Private)
  func retargetFrame(to frame: CGRect) {
    if let keys = animationKeys(), retargetFrameAnimations(to: frame, animationKeys: keys) {
      return
    }
    let newPosition = position(from: frame)
    // the `bounds.size` write syncs an AppKit backing view from both, see `animateFrame(to:timing:)`
    skippingViewSync {
      setKeyPathValue("position", newPosition)
    }
    setKeyPathValue("bounds.size", frame.size)
  }

  /// Retargets the layer's in-flight frame animations to the frame, see `retargetFrame(to:)`.
  ///
  /// - Parameters:
  ///   - frame: The frame to set.
  ///   - keys: The layer's animation keys.
  /// - Returns: `false`, leaving the layer alone, when no changed axis is in motion, so the frame can be set directly.
  private func retargetFrameAnimations(to frame: CGRect, animationKeys keys: [String]) -> Bool {
    let anchorPoint = self.anchorPoint
    let anchor = SIMD2<Double>(anchorPoint.x, anchorPoint.y)
    let oldPosition = position
    let oldSize = bounds.size
    let newPosition = position(from: frame)
    let newSize = frame.size
    let sizeChange = SIMD2<Double>(oldSize.width - newSize.width, oldSize.height - newSize.height)
    let originChange = SIMD2<Double>(oldPosition.x - newPosition.x, oldPosition.y - newPosition.y) - anchor * sizeChange

    // the origin and the size are retargeted apart, so a part whose animations still head to its new value keeps them
    // with their curves
    var origin = FramePartMotion()
    var size = FramePartMotion()
    var now: TimeInterval?
    for key in keys {
      guard let animation = animation(forKey: key) as? any FrameAnimation else {
        continue
      }

      // the clock is read only when a frame animation is found, as `inFlightAnimations(forKeyPath:)` does
      let time = now ?? currentTime
      now = time
      guard let remainingTime = animation.remainingTime(at: time) else {
        // Core Animation removes an ended animation
        continue
      }

      ComposeUI.assert(animation.hasEvaluableTiming, "frame animation \"\(key)\" has a timing that can't be evaluated: \(animation)")
      // a frame animation goes from its offset to zero
      let remainingFactor = animation.isFoldable(at: time) ? 1 - animation.progress(forElapsedTime: animation.timeSinceBegin(at: time)) : nil

      switch animation.offset {
      case .position(let originPart, _):
        origin.add(originPart, duration: animation.duration, remainingTime: remainingTime, remainingFactor: remainingFactor)
      case .size(let offset):
        size.add(offset, duration: animation.duration, remainingTime: remainingTime, remainingFactor: remainingFactor)
      case nil:
        ComposeUI.assertFailure("frame animation \"\(key)\" doesn't animate its part from a value: \(animation)")
      }
    }

    // a part glides when an axis that changed is in motion. a changed axis at rest has no motion to continue
    let foldsOrigin = !FrameAxes(of: originChange).isDisjoint(with: origin.movingAxes)
    let foldsSize = !FrameAxes(of: sizeChange).isDisjoint(with: size.movingAxes)
    guard let now, foldsOrigin || foldsSize else {
      return false
    }

    for key in keys {
      guard let animation = animation(forKey: key) as? any FrameAnimation,
            animation.remainingTime(at: now) != nil,
            animation.isFoldable(at: now)
      else {
        continue
      }

      switch animation.offset {
      case .position(let originPart, let sizeShare):
        let hasOrigin = !FrameAxes(of: originPart).isEmpty
        let hasSizeShare = !FrameAxes(of: sizeShare).isEmpty
        guard foldsOrigin && hasOrigin || foldsSize && hasSizeShare else {
          continue
        }
        // the part that keeps going takes the animation's place, with its timing
        if !foldsOrigin, hasOrigin {
          replaceFrameAnimation(animation, forKey: key, offset: originPart, part: .origin)
        } else if !foldsSize, hasSizeShare {
          replaceFrameAnimation(animation, forKey: key, offset: sizeShare, part: .sizeShare)
        } else {
          removeAnimation(forKey: key)
        }
      case .size:
        if foldsSize {
          removeAnimation(forKey: key)
        }
      case nil:
        continue
      }
    }

    // a moving axis glides from where it shows, and an axis at rest takes its new value at once
    let originGlide = foldsOrigin ? origin.movingAxes.projecting(originChange + origin.folded) : .zero
    let sizeGlide = foldsSize ? size.movingAxes.projecting(sizeChange + size.folded) : .zero
    let sizeShareGlide = anchor * sizeGlide

    // the `bounds.size` write syncs an AppKit backing view from both, see `animateFrame(to:timing:)`
    skippingViewSync {
      setKeyPathValue("position", newPosition)
    }
    setKeyPathValue("bounds.size", newSize)
    let beginTime = CAAnimation.beginTime(at: now)
    let originTiming = AnimationTiming.easeOut(duration: origin.glideDuration)
    let sizeTiming = AnimationTiming.easeOut(duration: size.glideDuration)
    if originGlide != .zero, sizeShareGlide != .zero, origin.glideDuration == size.glideDuration {
      // the glides of the position share their timing, so one animation glides both
      let positionGlide = originGlide + sizeShareGlide
      addFrameAnimation(keyPath: "position", from: CGPoint(x: positionGlide.x, y: positionGlide.y), to: CGPoint.zero, timing: originTiming, beginTime: beginTime, part: .originAndSizeShare(originPart: originGlide))
    } else {
      if originGlide != .zero {
        addFrameAnimation(keyPath: "position", from: CGPoint(x: originGlide.x, y: originGlide.y), to: CGPoint.zero, timing: originTiming, beginTime: beginTime, part: .origin)
      }
      if sizeShareGlide != .zero {
        addFrameAnimation(keyPath: "position", from: CGPoint(x: sizeShareGlide.x, y: sizeShareGlide.y), to: CGPoint.zero, timing: sizeTiming, beginTime: beginTime, part: .sizeShare)
      }
    }
    if sizeGlide != .zero {
      addFrameAnimation(keyPath: "bounds.size", from: CGSize(width: sizeGlide.x, height: sizeGlide.y), to: CGSize.zero, timing: sizeTiming, beginTime: beginTime, part: .size)
    }
    return true
  }

  /// Replaces a frame animation of `position` with a copy of it from another offset, which keeps the animation's timing.
  ///
  /// - Parameters:
  ///   - animation: The animation.
  ///   - key: The animation's key.
  ///   - offset: The offset the copy starts from.
  ///   - part: The part of the frame the copy animates.
  private func replaceFrameAnimation(_ animation: any FrameAnimation, forKey key: String, offset: SIMD2<Double>, part: FrameAnimationPart) {
    let replacement = animation.copy() as! any FrameAnimation // swiftlint:disable:this force_cast
    replacement.fromValue = CGPoint(x: offset.x, y: offset.y)
    replacement.part = part
    add(replacement, forKey: key)
  }

  /// Adds an additive frame animation from an offset to zero, without setting the model value.
  ///
  /// - Parameters:
  ///   - keyPath: The key path of the part, `position` or `bounds.size`.
  ///   - offset: The offset the animation starts from.
  ///   - zero: The zero offset the animation lands on.
  ///   - timing: The animation's timing.
  ///   - beginTime: The animation's begin time.
  ///   - part: The part of the frame the animation animates.
  private func addFrameAnimation(keyPath: String, from offset: Any, to zero: Any, timing: AnimationTiming, beginTime: TimeInterval, part: FrameAnimationPart) {
    let animation = CABasicAnimation.makeAnimation(
      timing,
      basicAnimation: {
        let animation = FrameBasicAnimation()
        animation.part = part
        return animation
      },
      springAnimation: {
        let animation = FrameSpringAnimation()
        animation.part = part
        return animation
      }
    )
    animation.keyPath = keyPath
    animation.fromValue = offset
    animation.toValue = zero
    animation.isAdditive = true
    animation.beginTime = beginTime
    add(animation, forKey: uniqueAnimationKey(key: keyPath))
  }
}

/// The axes of the origin or the size of a layer's frame.
private struct FrameAxes: OptionSet {

  let rawValue: Int

  init(rawValue: Int) {
    self.rawValue = rawValue
  }

  /// The axes along which a value isn't zero, beyond `Constants.geometryTolerance`.
  ///
  /// - Parameter value: The value.
  init(of value: SIMD2<Double>) {
    let tolerance = Constants.geometryTolerance
    rawValue = (abs(value.x) > tolerance ? FrameAxes.x.rawValue : 0) | (abs(value.y) > tolerance ? FrameAxes.y.rawValue : 0)
  }

  static let x = FrameAxes(rawValue: 1 << 0)
  static let y = FrameAxes(rawValue: 1 << 1)

  /// The value along the axes, with zero along the others.
  ///
  /// - Parameter value: The value.
  /// - Returns: The value along the axes.
  func projecting(_ value: SIMD2<Double>) -> SIMD2<Double> {
    SIMD2(contains(.x) ? value.x : 0, contains(.y) ? value.y : 0)
  }
}

/// The offset of a frame animation, which goes to zero.
private enum FrameAnimationOffset {

  /// The offset of a `position` animation: the origin's part and the size's share.
  case position(originPart: SIMD2<Double>, sizeShare: SIMD2<Double>)

  /// The offset of a `bounds.size` animation.
  case size(SIMD2<Double>)
}

private extension FrameAnimation {

  /// The animation's offset, or `nil` when its from value isn't one of its part.
  var offset: FrameAnimationOffset? {
    switch part {
    case .size:
      return (fromValue as? CGSize).map { .size(SIMD2($0.width, $0.height)) }
    case .origin:
      return positionOffset.map { .position(originPart: $0, sizeShare: .zero) }
    case .sizeShare:
      return positionOffset.map { .position(originPart: .zero, sizeShare: $0) }
    case .originAndSizeShare(let originPart):
      return positionOffset.map { .position(originPart: originPart, sizeShare: $0 - originPart) }
    }
  }

  /// The from value of a `position` animation.
  private var positionOffset: SIMD2<Double>? {
    (fromValue as? CGPoint).map { SIMD2($0.x, $0.y) }
  }
}

/// The in-flight motion of a part of a layer's frame, the origin or the size, see `CALayer.retargetFrame(to:)`.
private struct FramePartMotion {

  /// The axes the animations move the part along.
  private(set) var movingAxes: FrameAxes = []

  /// The part of the folded animations' offsets they have left, which the glide continues from.
  private(set) var folded = SIMD2<Double>.zero

  /// The time the longest animation has left.
  private var remainingTime: TimeInterval = 0

  /// Whether an animation never finishes, see `CAAnimation.neverFinishes(duration:)`.
  private var neverFinishes = false

  /// The duration of the part's glide, which lands when the animations would have. An animation that never finishes has
  /// no landing to glide to, so the glide takes the default duration.
  var glideDuration: TimeInterval {
    neverFinishes ? Animations.defaultAnimationDuration : remainingTime
  }

  /// Adds an in-flight animation's offset of the part.
  ///
  /// - Parameters:
  ///   - offset: The animation's offset of the part.
  ///   - duration: The animation's duration.
  ///   - remainingTime: The time the animation has left.
  ///   - remainingFactor: The part of the offset the animation has left, or `nil` when the animation isn't folded.
  mutating func add(_ offset: SIMD2<Double>, duration: TimeInterval, remainingTime: TimeInterval, remainingFactor: Double?) {
    let axes = FrameAxes(of: offset)
    guard !axes.isEmpty else {
      return
    }
    movingAxes.formUnion(axes)
    self.remainingTime = max(self.remainingTime, remainingTime)
    neverFinishes = neverFinishes || CAAnimation.neverFinishes(duration: duration)
    if let remainingFactor {
      folded += offset * remainingFactor
    }
  }
}

private extension CABasicAnimation {

  /// Whether a frame retarget can fold the animation at the time: its timing can be evaluated, and it isn't a running
  /// spring, which keeps going so its momentum carries on.
  ///
  /// - Parameter time: The time, in the layer's time space.
  /// - Returns: `true` if the animation can be folded.
  func isFoldable(at time: TimeInterval) -> Bool {
    let isRunningSpring = self is CASpringAnimation && speed > 0 && beginTime <= time
    return !isRunningSpring && hasEvaluableTiming
  }
}
