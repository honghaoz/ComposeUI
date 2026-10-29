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
  /// A changed transform animates from the transform that the layer shows. Without a timing, a transform animation in
  /// flight glides to the new transform over the time that its change has left, as `retarget(keyPath:to:)` does, and a
  /// transform at rest changes at once. While the layer's size animates, the transform follows the size that the layer
  /// shows, however the size's animations stack.
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
      // a refresh mostly keeps the transform, which then isn't set again. the keyframes of a change in flight follow
      // the size, even to a transform that doesn't, such as the identity, so a resize still samples them again
      guard oldSize != newSize, animation(forKey: "transform") is AnchoredTransformAnimation else {
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
      // a layer usually has nothing animating, and then nothing moves the transform
      setModelTransform(newTransform)
      return
    }

    let now = currentTime
    let keyframeAnimation = keys == nil ? nil : (animation(forKey: "transform") as? AnchoredTransformAnimation).flatMap {
      $0.remainingTime(at: now) == nil ? nil : $0
    }

    // the size that the layer shows moves the point only while an animation of the size is in flight, from when the
    // first of them begins to when the last of them ends
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

    // the transform keeps the course of its change in flight when only the size changed
    let keepsCourse: Bool
    if let keyframeAnimation {
      keepsCourse = keyframeAnimation.pivotOffset == pivotOffset && CATransform3DEqualToTransform(keyframeAnimation.transform, transform)
    } else {
      keepsCourse = CATransform3DEqualToTransform(
        self.transform,
        Self.anchoredTransform(transform, pivotOffset: pivotOffset, size: oldSize)
      )
    }

    var motion = keepsCourse ? keyframeAnimation?.motion : nil
    if !keepsCourse, let motionTiming = animationTiming == nil ? glideTiming(keyframeAnimation: keyframeAnimation, keys: keys, at: now) : timing {
      let start = shownTransform(pivotOffset: pivotOffset, keyframeAnimation: keyframeAnimation, hasAnimations: keys != nil, at: now)
      if pivotOffset == .zero, keyframeAnimation == nil {
        // the point is the anchor point, which the size doesn't move, so Core Animation interpolates the transform itself
        removeAnimations(forKeyPath: "transform")
        animate(
          keyPath: "transform",
          timing: motionTiming,
          from: { _ in NSValue(caTransform3D: start) },
          to: { _ in NSValue(caTransform3D: newTransform) }
        )
        return
      } else {
        motion = TransformMotion(from: start, to: transform, timing: motionTiming, at: now)
      }
    }

    guard motion.map({ $0.endTime > now }) == true || !sizeAnimations.isEmpty else {
      // nothing moves the transform, which changes at once, and an animation in flight would show over it until it ends
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
      motion: motion,
      sizeAnimations: sizeAnimations,
      sizeTimes: (sizeStartTime, sizeEndTime),
      newTransform: newTransform,
      newSize: newSize,
      at: now
    )
  }

  /// The timing of a glide to a new transform from a transform animation in flight: an ease out over the time that the
  /// animation's change of the transform has left, as `retarget(keyPath:to:)` glides.
  ///
  /// - Parameters:
  ///   - keyframeAnimation: The keyframe animation of the transform in flight, if any.
  ///   - keys: The layer's animation keys.
  ///   - now: The layer's current time.
  /// - Returns: The timing, or `nil` when the transform is at rest.
  private func glideTiming(keyframeAnimation: AnchoredTransformAnimation?, keys: AnimationKeys?, at now: TimeInterval) -> AnimationTiming? {
    let remainingTime: TimeInterval
    let neverFinishes: Bool
    if let keyframeAnimation {
      // the keyframes outlast the transform's change while the size animates, and the transform is at rest after it
      guard let motion = keyframeAnimation.motion, motion.endTime > now else {
        return nil
      }
      remainingTime = motion.endTime - now
      neverFinishes = motion.neverFinishes
    } else {
      // a basic animation of the transform, as one of a point at the anchor point, glides as `retarget(keyPath:to:)` does
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
  ///   - keyframeAnimation: The keyframe animation of the transform in flight, if any.
  ///   - hasAnimations: Whether the layer has animations.
  ///   - now: The layer's current time.
  /// - Returns: The transform.
  private func shownTransform(pivotOffset: SIMD2<Double>,
                              keyframeAnimation: AnchoredTransformAnimation?,
                              hasAnimations: Bool,
                              at now: TimeInterval) -> CATransform3D
  {
    let shown: CATransform3D
    let shownPivotOffset: SIMD2<Double>
    if let keyframeAnimation {
      // the keyframes show the transform's change, which gives the transform exactly, unlike the keyframes in between,
      // and the transform is the target once its change ends, see `addKeyframeAnimation`
      let motion = keyframeAnimation.motion.flatMap { now < $0.endTime ? $0 : nil }
      shown = motion.map { $0.transform(atProgress: $0.progress(at: now)) } ?? keyframeAnimation.transform
      shownPivotOffset = keyframeAnimation.pivotOffset
    } else {
      // the layer's own transform, which a basic animation of it may change, applies about the anchor point
      shown = hasAnimations ? (shownValue(forKeyPath: "transform") as? CATransform3D) ?? transform : transform
      shownPivotOffset = .zero
    }
    guard shownPivotOffset != pivotOffset else {
      return shown
    }

    // the first keyframe applies the transform about the new point at the size shown, so the change starts from the
    // transform about the new point that shows the same at that size, whatever size the transform shown was set for
    let size = hasAnimations ? shownValue(forKeyPath: "bounds.size") as? CGSize ?? bounds.size : bounds.size
    let anchoredTransform = Self.anchoredTransform(shown, pivotOffset: shownPivotOffset, size: size)
    return Self.anchoredTransform(anchoredTransform, pivotOffset: -pivotOffset, size: size)
  }

  /// Adds the keyframe animation of the transform about the point, from when the transform or the size first moves to
  /// when the last of them stops, and sets the model transform.
  ///
  /// - Parameters:
  ///   - transform: The transform that the layer ends at, before it applies about the point.
  ///   - pivotOffset: The point's offset from the anchor point, in the unit space of the layer's bounds.
  ///   - motion: The transform's change, or `nil` when the transform stays.
  ///   - sizeAnimations: The animations of the layer's size in flight.
  ///   - sizeTimes: The time from which the animations of the size move it, and the time the last of them ends.
  ///   - newTransform: The transform about the point at the new size, the model transform.
  ///   - newSize: The layer's size.
  ///   - now: The layer's current time.
  private func addKeyframeAnimation(transform: CATransform3D,
                                    pivotOffset: SIMD2<Double>,
                                    motion: TransformMotion?,
                                    sizeAnimations: [KeyPathAnimation],
                                    sizeTimes: (start: TimeInterval, end: TimeInterval),
                                    newTransform: CATransform3D,
                                    newSize: CGSize,
                                    at now: TimeInterval)
  {
    var startTime = sizeTimes.start
    var endTime = sizeTimes.end
    if let motion, motion.endTime > now {
      startTime = min(startTime, max(now, motion.beginTime))
      endTime = max(endTime, motion.endTime)
    }
    // an animation that never finishes, as a spring without damping doesn't, can't be followed forever
    let duration = min(endTime - startTime, Constants.maxSampledDuration)
    // a change cut off at the most time followed jumps to its end over the last interval, which more keyframes don't
    // shorten, so the deviation leaves that interval out
    let isCutOff = endTime - startTime > duration

    // the frame's own animations of the size are read once, while another animation of the size takes a read of each
    // animation's timing and values at each keyframe
    let frameSizeChanges = sizeAnimations.isEmpty ? nil : FrameSizeChange.changes(of: sizeAnimations)
    let modelSize = SIMD2(Double(bounds.size.width), Double(bounds.size.height))
    func size(at time: TimeInterval) -> CGSize {
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
        return shownValue(forKeyPath: "bounds.size", animations: sizeAnimations, at: time) as? CGSize ?? newSize
      }
    }

    // the transform about the point at a time, at the size shown then
    func keyframeTransform(at time: TimeInterval, size: CGSize) -> CATransform3D {
      // a spring ends close to its target rather than on it, so the transform is the target itself once its change ends
      if let motion, time < motion.endTime {
        return Self.anchoredTransform(motion.transform(atProgress: motion.progress(at: time)), pivotOffset: pivotOffset, size: size)
      } else {
        return Self.anchoredTransform(transform, pivotOffset: pivotOffset, size: size)
      }
    }

    // Core Animation interpolates between two keyframes as between any two transforms, which moves the point off its
    // place the farthest about halfway between them. that's where the farthest is measured, by projecting the point
    // with the interpolated transform and with the transform there, as an estimate misses the curves that a turn, a
    // scale during a resize or perspective each make
    func deviation(of transforms: [CATransform3D], count: Int) -> Double {
      let measuredCount = isCutOff ? count - 1 : count
      var deviation = 0.0
      var index = 0
      while index < measuredCount {
        if let interpolator = TransformInterpolator(from: transforms[index], to: transforms[index + 1]) {
          let time = startTime + duration * ((Double(index) + 0.5) / Double(count))
          let size = size(at: time)
          let point = pivotOffset * SIMD2(Double(size.width), Double(size.height))
          let shownPoint = Self.project(point, interpolator.transform(atProgress: 0.5))
          deviation = max(deviation, length(shownPoint - Self.project(point, keyframeTransform(at: time, size: size))))
        }
        index += 1
      }
      return deviation
    }

    // the transforms of the keyframes, unboxed, so that a count that turns out too low throws away only them
    func keyframeTransforms(count: Int) -> (transforms: [CATransform3D], deviation: Double) {
      var transforms: [CATransform3D] = []
      transforms.reserveCapacity(count + 1)
      var index = 0
      while index <= count {
        let time = startTime + duration * (Double(index) / Double(count))
        // the last keyframe is the model transform, which shows once the animation ends
        transforms.append(index == count ? newTransform : keyframeTransform(at: time, size: size(at: time)))
        index += 1
      }
      return (transforms, deviation(of: transforms, count: count))
    }

    var count = max(1, Int((duration * Constants.samplesPerSecond).rounded(.up)))
    let maxCount = max(count, Int((duration * Constants.samplesPerSecond * Constants.maxDensityFactor).rounded(.up)))
    var (transforms, deviation) = keyframeTransforms(count: count)
    while deviation > Constants.pointTolerance, count < maxCount {
      // a fast change about a far point takes more keyframes, as the deviation shrinks with about the square of the time
      // between them, up to a rate that keeps an absurd change from building a huge animation
      let denserCount = Int((Double(count) * (deviation / Constants.pointTolerance).squareRoot()).rounded(.up))
      count = min(max(denserCount, count + 1), maxCount)
      (transforms, deviation) = keyframeTransforms(count: count)
    }

    let animation = AnchoredTransformAnimation()
    animation.keyPath = "transform"
    animation.values = transforms.map { NSValue(caTransform3D: $0) }
    animation.duration = duration
    // backwards fill holds the first keyframe until the transform or the size begins to move
    animation.fillMode = .both
    animation.beginTime = CAAnimation.beginTime(at: startTime)
    animation.transform = transform
    animation.pivotOffset = pivotOffset
    animation.motion = motion

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

/// A keyframe animation of a layer's transform about a point of the layer, at the size that the layer shows at each
/// keyframe, see `CALayer.updateTransform(_:anchor:oldSize:newSize:animationTiming:)`.
///
/// It keeps the transform and its change, so that a later update computes the transform that the keyframes show instead
/// of reading it back from them. They're stored properties of the animation's class, as a key-value mark on an animation
/// costs about as much as making the animation, see `FrameAnimation`.
final class AnchoredTransformAnimation: CAKeyframeAnimation {

  /// The transform that the keyframes end at, before it applies about the point.
  var transform = CATransform3DIdentity

  /// The point's offset from the layer's anchor point, in the unit space of the layer's bounds.
  var pivotOffset = SIMD2<Double>.zero

  /// The transform's change, or `nil` when the transform stays while the layer's size animates.
  var motion: TransformMotion?

  override func copy(with zone: NSZone? = nil) -> Any {
    // Core Animation copies an animation when it's added, without the Swift properties, so the copy takes them here
    let copy = super.copy(with: zone) as! AnchoredTransformAnimation // swiftlint:disable:this force_cast
    copy.transform = transform
    copy.pivotOffset = pivotOffset
    copy.motion = motion
    return copy
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
  ///   - from: The transform to change from.
  ///   - to: The transform to change to.
  ///   - timing: The timing.
  ///   - time: The time the change is made at, in the layer's time space.
  /// - Returns: `nil` when the transforms don't interpolate, see `TransformInterpolator.init(from:to:)`.
  init?(from: CATransform3D, to: CATransform3D, timing: AnimationTiming, at time: TimeInterval) {
    guard let interpolator = TransformInterpolator(from: from, to: to) else {
      return nil
    }
    // the timing's animation has the curve, the duration and the speed that an animation of the transform would have
    let animation = CABasicAnimation.makeAnimation(timing)
    self.interpolator = interpolator
    curve = AnimationCurve(animation)
    speed = Double(animation.speed)
    beginTime = CAAnimation.beginTime(at: time, delay: timing.delay)
  }

  /// The time the change ends, in the layer's time space.
  var endTime: TimeInterval {
    beginTime + curve.duration / speed
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

  /// The transform at a progress of the change, see `progress(at:)`.
  ///
  /// - Parameter progress: The progress.
  /// - Returns: The transform.
  func transform(atProgress progress: Double) -> CATransform3D {
    interpolator.transform(atProgress: progress)
  }
}
