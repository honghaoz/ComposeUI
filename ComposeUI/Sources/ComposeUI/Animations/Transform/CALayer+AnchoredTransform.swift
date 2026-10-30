//
//  CALayer+AnchoredTransform.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/28/26.
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

#if canImport(AppKit)
import AppKit
#endif

public extension CALayer {

  /// Applies a transform about a point of the layer, animating a change with the timing if given, and keeps the point in
  /// place while the transform changes and while the layer's size animates.
  ///
  /// A change animates from the transform that the layer shows, and a change made during another one about the same
  /// point adds to it, so that the motion in flight carries on. Without a timing, a transform animation in flight glides
  /// to the new transform over the time that it has left, and a layer at rest takes the new transform at once.
  ///
  /// The layer remembers its size each time the function sets its transform, so that the next call tells a resize from
  /// a change of the transform. After the layer's size changes, call it again with the same transform, as a layout pass
  /// does, and the transform applies about the point at the new size, following the size's animations.
  ///
  /// Set the layer's transform only through this function: it remembers the size it set the transform at, which a
  /// transform set another way, such as through the `transform` property or the transform modifier, leaves out of date.
  /// Debug builds assert when the layer's transform isn't the one that the function last set.
  ///
  /// On AppKit, a view's layer keeps the transform when AppKit resets it to the identity, as AppKit does when the view
  /// moves or resizes. So set a view's layer back to the identity through this function rather than its `transform`
  /// property, which would get the transform back.
  ///
  /// - Parameters:
  ///   - transform: The transform to apply.
  ///   - anchor: The point of the layer to apply the transform about, in the unit space of its bounds with the origin
  ///     at the top left.
  ///   - animationTiming: The timing to animate a changed transform with, or `nil` to apply it without starting an
  ///     animation.
  @_spi(Private)
  func updateTransform(_ transform: CATransform3D, anchor: UnitPoint = .center, animationTiming: AnimationTiming?) {
    let transformSize = self.transformSize
    #if DEBUG
    if let transformSize {
      ComposeUI.assert(
        CATransform3DEqualToTransform(self.transform, transformSize.transform),
        "the layer's transform was set other than through updateTransform(_:anchor:animationTiming:)"
      )
    }
    #endif
    // the first call has no size to tell a resize by, so the layer's transform counts as set at the layer's size
    let oldSize = transformSize?.size ?? bounds.size

    #if canImport(AppKit)
    // AppKit resets only a view's layer transform, which the next call would take for a change
    let keepsTransform = delegate is NSView
    let mayBeKeeping = keepsTransform && pauseKeepingTransform()
    #endif

    updateTransform(transform, anchor: anchor, oldSize: oldSize, animationTiming: animationTiming)

    #if canImport(AppKit)
    if keepsTransform {
      resumeKeepingTransform(mayBeKeeping: mayBeKeeping)
    }
    #endif

    if let transformSize {
      transformSize.size = bounds.size
      #if DEBUG
      transformSize.transform = self.transform
      #endif
    } else {
      self.transformSize = TransformSize(bounds.size, transform: self.transform)
    }
  }

  /// Applies a transform about a point of the layer, animating a change with the timing if given, and keeps the point in
  /// place while the transform changes and while the layer's size animates, given the size that the layer's transform
  /// was set at.
  ///
  /// It works as `updateTransform(_:anchor:animationTiming:)` does, for a caller that knows the size that the layer's
  /// transform was set at, such as the size of the layer's previous frame in a layout pass: the size tells a resize from
  /// a change of the transform. Unlike that function, it doesn't remember the size, and it doesn't keep a view's layer
  /// transform through AppKit's resets.
  ///
  /// - Parameters:
  ///   - transform: The transform to apply.
  ///   - anchor: The point of the layer to apply the transform about, in the unit space of its bounds with the origin
  ///     at the top left.
  ///   - oldSize: The layer's size when its transform was set, before the update.
  ///   - animationTiming: The timing to animate a changed transform with, or `nil` to apply it without starting an
  ///     animation.
  @_spi(Private)
  func updateTransform(_ transform: CATransform3D,
                       anchor: UnitPoint = .center,
                       oldSize: CGSize,
                       animationTiming: AnimationTiming?)
  {
    let newSize = bounds.size
    let anchorPoint = self.anchorPoint
    let pivotOffset = SIMD2(anchor.x - Double(anchorPoint.x), anchor.y - Double(anchorPoint.y))
    let newTransform = Self.anchoredTransform(transform, pivotOffset: pivotOffset, size: newSize)

    if CATransform3DEqualToTransform(self.transform, newTransform) {
      // a change in flight follows the size, even to a transform that doesn't, such as the identity, so a resize still
      // updates its animation
      guard oldSize != newSize, animation(forKey: "transform") is any AnchoredTransformAnimation else {
        return
      }
    }

    changeTransform(
      transform,
      pivotOffset: pivotOffset,
      newTransform: newTransform,
      oldSize: oldSize,
      newSize: newSize,
      animationTiming: animationTiming
    )
  }
}

extension CALayer {

  /// Changes the transform to a transform about a point, see `updateTransform(_:anchor:oldSize:animationTiming:)`.
  ///
  /// It's never inlined, since most updates keep the transform and return before reaching it, while its body would make
  /// every update save and restore more registers.
  ///
  /// - Parameters:
  ///   - transform: The transform to apply.
  ///   - pivotOffset: The point's offset from the anchor point, in the unit space of the layer's bounds.
  ///   - newTransform: The transform about the point at the new size, which the layer doesn't have.
  ///   - oldSize: The layer's size before the update.
  ///   - newSize: The layer's size.
  ///   - animationTiming: The timing to animate the change with, if any.
  @inline(never)
  private func changeTransform(_ transform: CATransform3D,
                               pivotOffset: SIMD2<Double>,
                               newTransform: CATransform3D,
                               oldSize: CGSize,
                               newSize: CGSize,
                               animationTiming: AnimationTiming?)
  {
    // a zero duration without a delay changes the transform at once, as `animate(keyPath:timing:from:to:)` does
    let timing = animationTiming.flatMap { $0.timing.duration > 0 || $0.delay > 0 ? $0 : nil }
    let keys = unbridgedAnimationKeys
    guard keys != nil || timing != nil else {
      setModelTransform(newTransform)
      return
    }

    let now = currentTime
    let anchoredAnimation = keys == nil ? nil : (animation(forKey: "transform") as? any AnchoredTransformAnimation).flatMap {
      $0.remainingTime(at: now) == nil ? nil : $0
    }

    var sizeAnimations: [KeyPathAnimation] = []
    var sizeStartTime = TimeInterval.infinity
    var sizeEndTime = now
    if let keys, pivotOffset != .zero, let animations = animationSequence(forKeyPath: "bounds.size", keys: keys) {
      for (_, sizeAnimation) in animations {
        guard let remainingTime = sizeAnimation.animation.remainingTime(at: now) else {
          continue
        }
        sizeAnimations.append(sizeAnimation)
        sizeStartTime = min(sizeStartTime, max(now, sizeAnimation.animation.beginTime))
        sizeEndTime = max(sizeEndTime, now + remainingTime)
      }
    }

    let keepsCourse: Bool
    if let anchoredAnimation {
      keepsCourse = anchoredAnimation.pivotOffset == pivotOffset && CATransform3DEqualToTransform(anchoredAnimation.transform, transform)
    } else {
      keepsCourse = CATransform3DEqualToTransform(
        self.transform,
        Self.anchoredTransform(transform, pivotOffset: pivotOffset, size: oldSize)
      )
    }

    var changes = keepsCourse ? anchoredAnimation?.changes : nil
    if !keepsCourse, let motionTiming = animationTiming == nil ? glideTiming(anchoredAnimation: anchoredAnimation, keys: keys, at: now) : timing {
      if animationTiming != nil, let stackedChanges = stackedChanges(on: anchoredAnimation, to: transform, pivotOffset: pivotOffset, timing: motionTiming, at: now) {
        changes = stackedChanges
      } else {
        let start = shownTransform(pivotOffset: pivotOffset, anchoredAnimation: anchoredAnimation, hasAnimations: keys != nil, at: now)
        if let interpolator = TransformInterpolator(from: start, to: transform) {
          if sizeAnimations.isEmpty, pivotOffset == .zero || interpolator.isLinear {
            // Core Animation's interpolation keeps the point in place while the size stays, when the point is the anchor
            // point or the change blends linearly, as the point's translation is linear in the matrix
            addBasicAnimation(
              transform: transform,
              pivotOffset: pivotOffset,
              interpolator: interpolator,
              from: start,
              to: newTransform,
              size: newSize,
              timing: motionTiming,
              at: now
            )
            return
          } else {
            changes = TransformChanges(TransformMotion(interpolator: interpolator, timing: motionTiming, at: now))
          }
        }
      }
    }

    guard changes.map({ $0.endTime > now }) == true || !sizeAnimations.isEmpty else {
      // an animation in flight would show over the transform until it ends
      removeAnimations(forKeyPath: "transform")
      setModelTransform(newTransform)
      return
    }

    // the transform set on the layer moves the pivot from the anchor point to the point and back, by an offset that
    // follows the size, and Core Animation would interpolate the translation that this makes along a straight line,
    // which moves the point off its place, so the keyframes sample the transform about the point at the size shown
    addKeyframeAnimation(
      transform: transform,
      pivotOffset: pivotOffset,
      changes: changes,
      sizeAnimations: sizeAnimations,
      sizeTimes: (sizeStartTime, sizeEndTime),
      newTransform: newTransform,
      newSize: newSize,
      at: now
    )
  }

  /// The changes of the transform in flight with a change to a transform stacked on them, as frame changes stack, so
  /// that the changes in flight keep their motion instead of starting over from the transform shown.
  ///
  /// - Parameters:
  ///   - anchoredAnimation: The anchored transform animation in flight, if any.
  ///   - transform: The transform to change to, before it applies about the point.
  ///   - pivotOffset: The point's offset from the anchor point, in the unit space of the layer's bounds.
  ///   - timing: The timing of the change.
  ///   - now: The layer's current time.
  /// - Returns: The changes, or `nil` when the change starts over from the transform shown: no change of the transform
  ///   about the point moves, a change in flight or the new one never finishes, the transforms don't interpolate or
  ///   invert, or the keyframes would stop following the changes before they end.
  private func stackedChanges(on anchoredAnimation: (any AnchoredTransformAnimation)?,
                              to transform: CATransform3D,
                              pivotOffset: SIMD2<Double>,
                              timing: AnimationTiming,
                              at now: TimeInterval) -> TransformChanges?
  {
    guard let anchoredAnimation,
          anchoredAnimation.pivotOffset == pivotOffset,
          let changes = anchoredAnimation.changes,
          changes.endTime > now,
          let interpolator = TransformInterpolator(from: anchoredAnimation.transform, to: transform),
          let stackedChanges = changes.stacking(TransformMotion(interpolator: interpolator, timing: timing, at: now), at: now)
    else {
      return nil
    }
    // keyframes follow a bounded time from when they begin, and a stack's begin with the changes in flight, so a change
    // stacks only when they follow the stack to its end, and otherwise starts over, which never stops sooner
    guard !TransformKeyframeSampler.cutsOff(stackedChanges, at: now) else {
      return nil
    }
    return stackedChanges
  }

  /// The timing of a glide to a new transform from a transform animation in flight: an ease out over the time that the
  /// animation's change of the transform has left, as `retarget(keyPath:to:)` glides.
  ///
  /// - Parameters:
  ///   - anchoredAnimation: The anchored transform animation in flight, if any.
  ///   - keys: The layer's animation keys.
  ///   - now: The layer's current time.
  /// - Returns: The timing, or `nil` when the transform is at rest.
  private func glideTiming(anchoredAnimation: (any AnchoredTransformAnimation)?, keys: AnimationKeys?, at now: TimeInterval) -> AnimationTiming? {
    let remainingTime: TimeInterval
    let neverFinishes: Bool
    if let anchoredAnimation {
      // keyframes outlast the transform's changes while the size animates, and the transform is at rest after them
      guard let changes = anchoredAnimation.changes, changes.endTime > now else {
        return nil
      }
      remainingTime = changes.endTime - now
      neverFinishes = changes.neverFinishes
    } else {
      guard let keys, let animations = animationSequence(forKeyPath: "transform", keys: keys) else {
        return nil
      }
      var longest: (remainingTime: TimeInterval, duration: TimeInterval)?
      for (_, keyPathAnimation) in animations {
        guard let animation = keyPathAnimation.directAnimation,
              let animationRemainingTime = animation.remainingTime(at: now),
              animationRemainingTime > longest?.remainingTime ?? 0
        else {
          continue
        }
        longest = (animationRemainingTime, animation.duration)
      }
      guard let longest else {
        return nil
      }
      remainingTime = longest.remainingTime
      neverFinishes = CAAnimation.neverFinishes(duration: longest.duration)
    }
    // an animation that never finishes has no landing to glide to, so the glide takes the default duration instead of forever
    return .easeOut(duration: neverFinishes ? Animations.defaultAnimationDuration : remainingTime)
  }

  /// The transform that the layer shows before it applies about the point, which a change starts from.
  ///
  /// - Parameters:
  ///   - pivotOffset: The point's offset from the anchor point, in the unit space of the layer's bounds.
  ///   - anchoredAnimation: The anchored transform animation in flight, if any.
  ///   - hasAnimations: Whether the layer has animations.
  ///   - now: The layer's current time.
  /// - Returns: The transform.
  private func shownTransform(pivotOffset: SIMD2<Double>,
                              anchoredAnimation: (any AnchoredTransformAnimation)?,
                              hasAnimations: Bool,
                              at now: TimeInterval) -> CATransform3D
  {
    let shown: CATransform3D
    let shownPivotOffset: SIMD2<Double>
    if let anchoredAnimation {
      // the animation shows the transform's changes, which give the transform exactly, unlike keyframes in between, and
      // the transform is the target once its changes end, see `addKeyframeAnimation`
      let changes = anchoredAnimation.changes.flatMap { now < $0.endTime ? $0 : nil }
      shown = changes.map { $0.transform(at: now) } ?? anchoredAnimation.transform
      shownPivotOffset = anchoredAnimation.pivotOffset
    } else {
      // the layer's own transform, which a basic animation of it may change, applies about the anchor point
      shown = hasAnimations ? (shownValue(forKeyPath: "transform") as? CATransform3D) ?? transform : transform
      shownPivotOffset = .zero
    }
    guard shownPivotOffset != pivotOffset else {
      return shown
    }

    // the animation applies its first transform about the new point at the size shown, so the change starts from the
    // transform about the new point that shows the same at that size
    let size = hasAnimations ? shownValue(forKeyPath: "bounds.size") as? CGSize ?? bounds.size : bounds.size
    let anchoredTransform = Self.anchoredTransform(shown, pivotOffset: shownPivotOffset, size: size)
    return Self.anchoredTransform(anchoredTransform, pivotOffset: -pivotOffset, size: size)
  }

  /// Adds one animation of the transform about the point, from the transform shown, which Core Animation interpolates
  /// about the point, and sets the model transform.
  ///
  /// - Parameters:
  ///   - transform: The transform that the layer ends at, before it applies about the point.
  ///   - pivotOffset: The point's offset from the anchor point, in the unit space of the layer's bounds.
  ///   - interpolator: The interpolator from the transform shown to the transform, which blends them linearly.
  ///   - start: The transform shown, before it applies about the point.
  ///   - newTransform: The transform about the point at the layer's size, the model transform.
  ///   - size: The layer's size, which no animation changes.
  ///   - timing: The timing of the change.
  ///   - now: The layer's current time.
  private func addBasicAnimation(transform: CATransform3D,
                                 pivotOffset: SIMD2<Double>,
                                 interpolator: TransformInterpolator,
                                 from start: CATransform3D,
                                 to newTransform: CATransform3D,
                                 size: CGSize,
                                 timing: AnimationTiming,
                                 at now: TimeInterval)
  {
    let animation = CABasicAnimation.makeAnimation(
      timing,
      basicAnimation: { AnchoredTransformBasicAnimation() },
      springAnimation: { AnchoredTransformSpringAnimation() }
    )
    let beginTime = CAAnimation.beginTime(at: now, delay: timing.delay)
    animation.keyPath = "transform"
    animation.fromValue = NSValue(caTransform3D: Self.anchoredTransform(start, pivotOffset: pivotOffset, size: size))
    animation.toValue = NSValue(caTransform3D: newTransform)
    animation.beginTime = beginTime
    let anchoredAnimation = animation as! any AnchoredTransformMotionAnimation // swiftlint:disable:this force_cast
    anchoredAnimation.transform = transform
    anchoredAnimation.pivotOffset = pivotOffset
    anchoredAnimation.motion = TransformMotion(interpolator: interpolator, animation: animation, beginTime: beginTime)

    // an animation of the transform in flight would show over the animation, or after it when it ends later
    removeAnimations(forKeyPath: "transform")
    add(animation, forKey: "transform")

    #if DEBUG
    WorkCounter.count(.animation)
    #endif

    setModelTransform(newTransform)
  }

  /// Adds the keyframe animation of the transform about the point, from when the transform or the size first moves to
  /// when the last of them stops, and sets the model transform.
  ///
  /// - Parameters:
  ///   - transform: The transform that the layer ends at, before it applies about the point.
  ///   - pivotOffset: The point's offset from the anchor point, in the unit space of the layer's bounds.
  ///   - changes: The transform's changes, or `nil` when the transform stays.
  ///   - sizeAnimations: The animations of the layer's size in flight.
  ///   - sizeTimes: The time from which the animations of the size move it, and the time the last of them ends.
  ///   - newTransform: The transform about the point at the new size, the model transform.
  ///   - newSize: The layer's size.
  ///   - now: The layer's current time.
  private func addKeyframeAnimation(transform: CATransform3D,
                                    pivotOffset: SIMD2<Double>,
                                    changes: TransformChanges?,
                                    sizeAnimations: [KeyPathAnimation],
                                    sizeTimes: (start: TimeInterval, end: TimeInterval),
                                    newTransform: CATransform3D,
                                    newSize: CGSize,
                                    at now: TimeInterval)
  {
    let sampler = TransformKeyframeSampler(
      layer: self,
      transform: transform,
      pivotOffset: pivotOffset,
      changes: changes,
      sizeAnimations: sizeAnimations,
      sizeTimes: sizeTimes,
      newTransform: newTransform,
      newSize: newSize,
      at: now
    )

    let animation = AnchoredTransformKeyframeAnimation()
    animation.keyPath = "transform"
    animation.values = sampler.keyframes().map { NSValue(caTransform3D: $0) }
    animation.duration = sampler.duration
    // backwards fill holds the first keyframe until the transform or the size begins to move
    animation.fillMode = .both
    animation.beginTime = CAAnimation.beginTime(at: sampler.startTime)
    animation.transform = transform
    animation.pivotOffset = pivotOffset
    animation.changes = changes

    // an animation of the transform in flight would show over the keyframes, or after them when it ends later
    removeAnimations(forKeyPath: "transform")
    add(animation, forKey: "transform")
    #if DEBUG
    WorkCounter.count(.animation)
    #endif
    setModelTransform(newTransform)
  }

  private func setModelTransform(_ newTransform: CATransform3D) {
    disableActions(for: "transform") {
      transform = newTransform
    }
  }

  /// The transform that applies a transform about a point of the layer.
  ///
  /// Core Animation applies a layer's transform about its anchor point, which an AppKit view's layer has at a corner,
  /// so the pivot moves to the point, the transform applies, and the pivot moves back, for the same pivot on every
  /// platform.
  ///
  /// - Parameters:
  ///   - transform: The transform to apply.
  ///   - pivotOffset: The point's offset from the layer's anchor point, in the unit space of the layer's bounds. A
  ///     negated offset gives the transform about the anchor point back.
  ///   - size: The layer's size.
  /// - Returns: The transform to set on the layer.
  static func anchoredTransform(_ transform: CATransform3D, pivotOffset: SIMD2<Double>, size: CGSize) -> CATransform3D {
    let offsetX = CGFloat(pivotOffset.x) * size.width
    let offsetY = CGFloat(pivotOffset.y) * size.height
    guard offsetX != 0 || offsetY != 0 else {
      return transform
    }
    let pivoted = CATransform3DConcat(CATransform3DMakeTranslation(-offsetX, -offsetY, 0), transform)
    return CATransform3DConcat(pivoted, CATransform3DMakeTranslation(offsetX, offsetY, 0))
  }
}

// MARK: - TransformSize

/// The layer's size when `CALayer.updateTransform(_:anchor:animationTiming:)` last set its transform, the size that the
/// transform applies about the point at.
private final class TransformSize {

  /// The layer's size when the function last set its transform.
  var size: CGSize

  #if DEBUG
  /// The transform that the function last set, which the layer has until something else sets its transform.
  var transform: CATransform3D
  #endif

  init(_ size: CGSize, transform: CATransform3D) {
    self.size = size
    #if DEBUG
    self.transform = transform
    #endif
  }
}

private extension CALayer {

  static let transformSizeKey = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)

  /// The layer's size when `updateTransform(_:anchor:animationTiming:)` last set its transform, or `nil` until it does.
  var transformSize: TransformSize? {
    get {
      objc_getAssociatedObject(self, CALayer.transformSizeKey) as? TransformSize
    }
    set {
      objc_setAssociatedObject(self, CALayer.transformSizeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
  }
}
