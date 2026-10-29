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
import simd

extension CALayer {

  /// Applies a transform about a point of the layer unless the layer already has it, animating a change with the timing
  /// if given, and keeps the point in place while the transform changes and while the layer's size animates.
  ///
  /// A changed transform animates from the transform that the layer shows, and a change during another one about the
  /// same point stacks on it, as frame changes do: each change goes on along its own timing, so the motion of the change
  /// in flight carries on, see `TransformChanges`. Without a timing, a transform animation in flight glides to the new
  /// transform over the time that its changes have left, as `retarget(keyPath:to:)` does, and a transform at rest changes
  /// at once. While the layer's size animates, the transform follows the size that the layer shows, however the size's
  /// animations stack.
  ///
  /// - Parameters:
  ///   - transform: The transform to apply.
  ///   - anchor: The point of the layer to apply the transform about, in the unit space of its bounds with the origin
  ///     at the top left.
  ///   - oldSize: The layer's size before the update, which the layer's transform applies about the point at.
  ///   - newSize: The layer's size.
  ///   - animationTiming: The timing to animate a changed transform with, or `nil` to apply it without starting an
  ///     animation.
  func updateTransform(_ transform: CATransform3D,
                       anchor: UnitPoint,
                       oldSize: CGSize,
                       newSize: CGSize,
                       animationTiming: AnimationTiming?)
  {
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

  /// Changes the transform to a transform about a point, see `updateTransform(_:anchor:oldSize:newSize:animationTiming:)`.
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
  ///   about the point moves, a change in flight or the new one never finishes, or the transforms don't interpolate or
  ///   invert.
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
          let interpolator = TransformInterpolator(from: anchoredAnimation.transform, to: transform)
    else {
      return nil
    }
    return changes.stacking(TransformMotion(interpolator: interpolator, timing: timing, at: now), at: now)
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

/// The keyframes of a transform about a point of a layer, at the size that the layer shows at each keyframe, from when
/// the transform or the size first moves to when the last of them stops, see
/// `CALayer.updateTransform(_:anchor:oldSize:newSize:animationTiming:)`.
private struct TransformKeyframeSampler {

  /// The time the keyframes begin, in the layer's time space.
  let startTime: TimeInterval

  /// The time from the first keyframe to the last.
  let duration: TimeInterval

  private let layer: CALayer
  private let transform: CATransform3D
  private let pivotOffset: SIMD2<Double>

  /// The transform's changes, or changes that ended before any time when the transform stays.
  ///
  /// They aren't optional, since reading an optional's value copies it, which would copy the changes for each keyframe.
  private let changes: TransformChanges

  /// The time the transform's changes end, until which the keyframes follow them, in the layer's time space.
  private let changesEndTime: TimeInterval

  private let sizeAnimations: [KeyPathAnimation]
  private let frameSizeChanges: [FrameSizeChange]?
  private let modelSize: SIMD2<Double>
  private let newTransform: CATransform3D
  private let newSize: CGSize

  /// Whether the keyframes stop following a change before it ends, at the most time that they follow.
  private let isCutOff: Bool

  /// Changes that ended before any time, which the keyframes of a transform that stays hold in place of changes.
  private static let endedChanges = TransformChanges(TransformMotion(
    // two affine transforms always interpolate
    interpolator: TransformInterpolator(from: CATransform3DIdentity, to: CATransform3DIdentity)!, // swiftlint:disable:this force_unwrapping
    timing: .linear(duration: 1),
    at: -.infinity
  ))

  /// Creates the sampler of the keyframes of a change of a layer's transform, its size, or both.
  ///
  /// - Parameters:
  ///   - layer: The layer.
  ///   - transform: The transform that the layer ends at, before it applies about the point.
  ///   - pivotOffset: The point's offset from the anchor point, in the unit space of the layer's bounds.
  ///   - changes: The transform's changes, or `nil` when the transform stays.
  ///   - sizeAnimations: The animations of the layer's size in flight.
  ///   - sizeTimes: The time from which the animations of the size move it, and the time the last of them ends.
  ///   - newTransform: The transform about the point at the new size, the model transform.
  ///   - newSize: The layer's size.
  ///   - now: The layer's current time.
  init(layer: CALayer,
       transform: CATransform3D,
       pivotOffset: SIMD2<Double>,
       changes: TransformChanges?,
       sizeAnimations: [KeyPathAnimation],
       sizeTimes: (start: TimeInterval, end: TimeInterval),
       newTransform: CATransform3D,
       newSize: CGSize,
       at now: TimeInterval)
  {
    var startTime = sizeTimes.start
    var endTime = sizeTimes.end
    if let changes, changes.endTime > now {
      startTime = min(startTime, max(now, changes.beginTime))
      endTime = max(endTime, changes.endTime)
    }
    self.startTime = startTime
    duration = min(endTime - startTime, Constants.maxSampledDuration)
    // a change cut off at the most time followed jumps to its end over the last interval, which more keyframes don't
    // shorten, so the deviation leaves that interval out
    isCutOff = endTime - startTime > duration

    self.layer = layer
    self.transform = transform
    self.pivotOffset = pivotOffset
    self.changes = changes ?? Self.endedChanges
    changesEndTime = self.changes.endTime
    self.sizeAnimations = sizeAnimations
    frameSizeChanges = sizeAnimations.isEmpty ? nil : FrameSizeChange.changes(of: sizeAnimations)
    modelSize = SIMD2(Double(layer.bounds.size.width), Double(layer.bounds.size.height))
    self.newTransform = newTransform
    self.newSize = newSize
  }

  /// The keyframes' transforms, at 60 per second, and more where Core Animation's interpolation between two of them
  /// would move the point off its place by more than a quarter point.
  ///
  /// - Returns: The transforms, the last of which is the model transform.
  func keyframes() -> [CATransform3D] {
    var count = max(1, Int((duration * Constants.samplesPerSecond).rounded(.up)))
    let maxCount = max(count, Int((duration * Constants.samplesPerSecond * Constants.maxDensityFactor).rounded(.up)))
    var (transforms, deviation) = keyframes(count: count)
    while deviation > Constants.pointTolerance, count < maxCount {
      // a fast change about a far point takes more keyframes, as the deviation shrinks with about the square of the time
      // between them, up to a rate that keeps an absurd change from building a huge animation
      let denserCount = (Double(count) * (deviation / Constants.pointTolerance).squareRoot()).rounded(.up)
      // a point at the depth of the eye projects to infinity, so the count is capped while it's a `Double`
      count = Int(min(max(denserCount, Double(count + 1)), Double(maxCount)))
      (transforms, deviation) = keyframes(count: count)
    }
    return transforms
  }

  /// The keyframes' transforms for a number of intervals between them, unboxed, so that a number that turns out too low
  /// throws away only them, and the farthest that Core Animation's interpolation between them moves the point.
  ///
  /// - Parameter count: The number of intervals.
  /// - Returns: The transforms, and the farthest that the interpolation moves the point, in points.
  private func keyframes(count: Int) -> (transforms: [CATransform3D], deviation: Double) {
    var transforms: [CATransform3D] = []
    transforms.reserveCapacity(count + 1)
    var index = 0
    while index <= count {
      let time = startTime + duration * (Double(index) / Double(count))
      // the last keyframe is the model transform, which shows once the animation ends
      transforms.append(index == count ? newTransform : transform(at: time, size: size(at: time)))
      index += 1
    }
    return (transforms, deviation(of: transforms, count: count))
  }

  /// The farthest that Core Animation's interpolation between keyframes moves the point off its place.
  ///
  /// - Parameters:
  ///   - transforms: The keyframes' transforms.
  ///   - count: The number of intervals between them.
  /// - Returns: The distance, in points.
  private func deviation(of transforms: [CATransform3D], count: Int) -> Double {
    // Core Animation interpolates between two keyframes as between any two transforms, which moves the point off its
    // place the farthest about halfway between them, so that's where the deviation is measured, as an estimate misses
    // the curves that a turn, a scale during a resize or perspective each make
    let measuredCount = isCutOff ? count - 1 : count
    var deviation = 0.0
    var index = 0
    while index < measuredCount {
      if let interpolator = TransformInterpolator(from: transforms[index], to: transforms[index + 1]) {
        let time = startTime + duration * ((Double(index) + 0.5) / Double(count))
        let size = size(at: time)
        let point = pivotOffset * SIMD2(Double(size.width), Double(size.height))
        let shownPoint = Self.project(point, interpolator.transform(atProgress: 0.5))
        deviation = max(deviation, length(shownPoint - Self.project(point, transform(at: time, size: size))))
      }
      index += 1
    }
    return deviation
  }

  /// The transform about the point at a time, at a size.
  ///
  /// - Parameters:
  ///   - time: The time, in the layer's time space.
  ///   - size: The size that the layer shows then.
  /// - Returns: The transform to set on the layer.
  private func transform(at time: TimeInterval, size: CGSize) -> CATransform3D {
    if time < changesEndTime {
      return CALayer.anchoredTransform(changes.transform(at: time), pivotOffset: pivotOffset, size: size)
    } else {
      return CALayer.anchoredTransform(transform, pivotOffset: pivotOffset, size: size)
    }
  }

  /// The size that the layer shows at a time.
  ///
  /// - Parameter time: The time, in the layer's time space.
  /// - Returns: The size.
  private func size(at time: TimeInterval) -> CGSize {
    if sizeAnimations.isEmpty {
      return newSize
    } else if let frameSizeChanges {
      var size = modelSize
      var index = 0
      while index < frameSizeChanges.count {
        size += frameSizeChanges[index].offset(at: time)
        index += 1
      }
      return CGSize(width: size.x, height: size.y)
    } else {
      return layer.shownValue(forKeyPath: "bounds.size", animations: sizeAnimations, at: time) as? CGSize ?? newSize
    }
  }

  /// Where a transform puts a point of the layer, with its perspective.
  ///
  /// - Parameters:
  ///   - point: The point, from the layer's anchor point.
  ///   - transform: The transform.
  /// - Returns: The point that the transform puts the point at, from the layer's position.
  private static func project(_ point: SIMD2<Double>, _ transform: CATransform3D) -> SIMD2<Double> {
    let x = point.x * Double(transform.m11) + point.y * Double(transform.m21) + Double(transform.m41)
    let y = point.x * Double(transform.m12) + point.y * Double(transform.m22) + Double(transform.m42)
    let w = point.x * Double(transform.m14) + point.y * Double(transform.m24) + Double(transform.m44)
    return SIMD2(x, y) / w
  }

  // MARK: - Constants

  private enum Constants {

    /// The keyframes' rate, as an additive path's, see `PathChanges`: a display's rate of 120 would follow the size a
    /// quarter as far off, but it doubles the transforms to build and commit, so the rate stays at 60.
    static let samplesPerSecond: TimeInterval = 60

    /// The farthest that Core Animation's interpolation between two keyframes may move the point off its place, in
    /// points, beyond which a change takes more keyframes.
    static let pointTolerance: Double = 0.25

    /// The most keyframes that a change takes, as a multiple of the keyframes at the rate.
    static let maxDensityFactor: Double = 8

    /// The most time that the keyframes follow, so that an animation that never finishes builds a bounded animation,
    /// and shows its end once they end.
    static let maxSampledDuration: TimeInterval = 10
  }
}

/// A frame animation's change of a layer's size, read once, which gives the part of the change that the animation shows
/// at any time, as `CALayer.shownValue(forKeyPath:animations:at:)` gives it, see `CALayer.animateFrame(to:timing:)`.
private struct FrameSizeChange {

  private let offset: SIMD2<Double>
  private let curve: AnimationCurve
  private let beginTime: TimeInterval
  private let speed: Double

  /// The changes of the frame's animations of the size.
  ///
  /// - Parameter animations: The animations of the size.
  /// - Returns: The changes, or `nil` when an animation isn't one of the frame's animations of the size with a timing
  ///   that `shownValue(forKeyPath:animations:at:)` evaluates, and a begin time, which the frame's animations have.
  static func changes(of animations: [KeyPathAnimation]) -> [FrameSizeChange]? {
    var changes: [FrameSizeChange] = []
    changes.reserveCapacity(animations.count)
    for keyPathAnimation in animations {
      guard let animation = keyPathAnimation.directAnimation as? any FrameAnimation,
            animation.part == .size,
            animation.hasEvaluableTiming,
            animation.speed > 0,
            animation.beginTime != 0,
            let offset = animation.fromValue as? CGSize
      else {
        return nil
      }
      changes.append(FrameSizeChange(
        offset: SIMD2(Double(offset.width), Double(offset.height)),
        curve: AnimationCurve(animation),
        beginTime: animation.beginTime,
        speed: Double(animation.speed)
      ))
    }
    return changes
  }

  /// The part of the offset that the animation shows at a time: all of it until it begins, as its backwards fill holds
  /// its from value, and none once it ends, as Core Animation removes it.
  ///
  /// - Parameter time: The time, in the layer's time space.
  /// - Returns: The offset.
  func offset(at time: TimeInterval) -> SIMD2<Double> {
    let elapsed = (time - beginTime) * speed
    guard elapsed < curve.duration else {
      return .zero
    }
    return offset * (1 - curve.progress(forElapsedTime: elapsed))
  }
}

/// A change of a transform from one transform to another with a timing, which gives the transform at any time.
struct TransformMotion {

  /// The time the change begins, in the layer's time space.
  let beginTime: TimeInterval

  private let interpolator: TransformInterpolator
  private let curve: AnimationCurve
  private let speed: Double

  /// Creates a change that begins at a time, after the timing's delay.
  ///
  /// - Parameters:
  ///   - interpolator: The interpolator between the transforms that the change goes from and to.
  ///   - timing: The timing.
  ///   - time: The time the change is made at, in the layer's time space.
  init(interpolator: TransformInterpolator, timing: AnimationTiming, at time: TimeInterval) {
    let beginTime = CAAnimation.beginTime(at: time, delay: timing.delay)
    switch timing.timing {
    case .timingFunction(let duration, let timingFunction) where duration > 0:
      // making the timing's animation allocates, so the curve, the duration and the speed, which an animation keeps as a
      // `Float`, come from the timing as `CABasicAnimation.makeAnimation(_:)` sets them
      self.init(
        interpolator: interpolator,
        curve: AnimationCurve(timingFunction: timingFunction, duration: duration),
        speed: Double(Float(timing.speed)),
        beginTime: beginTime
      )
    case .timingFunction,
         .spring:
      // Core Animation gives a spring its duration, and a zero duration makes a snap, so the timing's animation has the
      // curve, the duration and the speed that an animation of the transform would have
      self.init(interpolator: interpolator, animation: CABasicAnimation.makeAnimation(timing), beginTime: beginTime)
    }
  }

  /// Creates the change that an animation of the transform shows.
  ///
  /// - Parameters:
  ///   - interpolator: The interpolator between the transforms that the change goes from and to.
  ///   - animation: The animation, whose curve, duration and speed the change has.
  ///   - beginTime: The time the change begins, in the layer's time space.
  init(interpolator: TransformInterpolator, animation: CABasicAnimation, beginTime: TimeInterval) {
    self.init(interpolator: interpolator, curve: AnimationCurve(animation), speed: Double(animation.speed), beginTime: beginTime)
  }

  private init(interpolator: TransformInterpolator, curve: AnimationCurve, speed: Double, beginTime: TimeInterval) {
    self.interpolator = interpolator
    self.curve = curve
    self.speed = speed
    self.beginTime = beginTime
  }

  /// The time the change ends, in the layer's time space.
  var endTime: TimeInterval {
    beginTime + curve.duration / speed
  }

  /// The transform the change ends at.
  var target: CATransform3D {
    interpolator.transform(atProgress: 1)
  }

  /// Whether the change never ends, as a spring without damping doesn't.
  var neverFinishes: Bool {
    CAAnimation.neverFinishes(duration: curve.duration)
  }

  /// The change's progress at a time: 0 until it begins, 1 once it ends, and past 1 while a spring overshoots.
  ///
  /// - Parameter time: The time, in the layer's time space.
  /// - Returns: The progress.
  func progress(at time: TimeInterval) -> Double {
    curve.progress(forElapsedTime: (time - beginTime) * speed)
  }

  /// The transform at a time.
  ///
  /// It's always inlined, since the change is too big for registers, so a call would copy it to pass it, for each
  /// keyframe that follows it.
  ///
  /// - Parameter time: The time, in the layer's time space.
  /// - Returns: The transform, the change's target itself once it ends.
  @inline(__always)
  func transform(at time: TimeInterval) -> CATransform3D {
    // a spring ends close to its target rather than on it, so the change shows its target itself once it ends
    if time < endTime {
      return interpolator.transform(atProgress: progress(at: time))
    } else {
      return target
    }
  }
}
