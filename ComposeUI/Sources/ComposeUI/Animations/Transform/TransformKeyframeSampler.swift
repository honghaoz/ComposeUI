//
//  TransformKeyframeSampler.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/29/26.
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

/// The keyframes of a transform about a point of a layer, at the size that the layer shows at each keyframe, from when
/// the transform or the size first moves to when the last of them stops, see
/// `CALayer.updateTransform(_:anchor:oldSize:newSize:animationTiming:)`.
struct TransformKeyframeSampler {

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

  /// Whether keyframes stop following changes before they end, at the most time that they follow.
  ///
  /// - Parameters:
  ///   - changes: The changes.
  ///   - now: The layer's current time.
  /// - Returns: `true` if the changes move for longer than the keyframes follow from now.
  static func cutsOff(_ changes: TransformChanges, at now: TimeInterval) -> Bool {
    changes.endTime - max(now, changes.beginTime) > Constants.maxSampledDuration
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
