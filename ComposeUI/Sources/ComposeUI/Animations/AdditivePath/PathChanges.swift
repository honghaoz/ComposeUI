//
//  PathChanges.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/24/26.
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

/// The additive changes of a path in flight.
///
/// Core Animation interpolates a path point by point, but it can't add path animations together. So the changes are
/// kept here and added up: the path shown is the model path plus the part of each change that is left, the way additive
/// animations add up on a number. A change is the old path minus the new path, point by point, and it shrinks to zero
/// along its timing. The points only line up between paths with the same segments.
struct PathChanges {

  /// A change of the path.
  struct Change {

    /// The old path minus the new path, point by point.
    let offset: PathPoints

    /// The animation of the change's timing, which shows the change when it is the only one in flight. Its begin time
    /// isn't kept, see `beginTime`.
    let animation: CABasicAnimation

    /// The curve of the change's timing.
    let curve: AnimationCurve

    /// The speed of the change's timing.
    let speed: TimeInterval

    /// The time the change begins, in the layer's time space, or zero while it begins at the commit of the animation
    /// that shows it, see `update(beginTime:at:)`.
    var beginTime: TimeInterval

    /// The time the change has left, see `CAAnimation.remainingTime(at:)`.
    ///
    /// - Parameter now: The layer's current time.
    /// - Returns: The remaining time, or `nil` when the change has landed.
    func remainingTime(at now: TimeInterval) -> TimeInterval? {
      CAAnimation.remainingTime(beginTime: beginTime, duration: curve.duration, speed: speed, at: now)
    }

    /// The part of the offset left when the change lands.
    ///
    /// It is zero unless the curve doesn't reach its end, as a spring cut short by its duration, and the change jumps
    /// from it to zero when it lands. A change of an infinite duration never lands, so it has no jump.
    var landingFactor: CGFloat {
      // the curve's end is at an infinite time, where a spring's progress is undefined, so there is no jump to key
      guard curve.duration.isFinite else {
        return 0
      }
      return CGFloat(1 - curve.progress(atFraction: 1))
    }

    /// The part of the offset left at a time.
    ///
    /// - Parameters:
    ///   - time: The time from now, see `PathChanges.keyframes(adding:points:at:)`.
    ///   - now: The layer's current time.
    ///   - beforeLanding: Whether the change shows its landing factor at its landing time, as the side of its jump
    ///     before it lands, instead of zero.
    /// - Returns: One until the change begins, zero once it has landed.
    func remainingFactor(at time: TimeInterval, now: TimeInterval, beforeLanding: Bool = false) -> CGFloat {
      guard let remainingTime = remainingTime(at: now) else {
        return 0
      }

      // a spring doesn't reach exactly one at its end, so the change lands when its time is up, jumping from its landing
      // factor to zero. a time within the tolerance is the landing time, as an evenly spread keyframe on it is computed
      // another way
      guard time < remainingTime - Constants.timeTolerance else {
        return beforeLanding && time <= remainingTime + Constants.timeTolerance ? landingFactor : 0
      }

      // an unset begin time resolves to the next commit, so the change is evaluated from its start
      let started = beginTime == 0 ? 0 : now - beginTime

      return CGFloat(1 - curve.progress(forElapsedTime: (started + time) * speed))
    }
  }

  /// The changes in flight, in the order they were recorded.
  private(set) var changes: [Change] = []

  /// Whether no change is in flight.
  var isEmpty: Bool {
    changes.isEmpty
  }

  /// Whether the keyframes of the changes begin at the next commit, instead of now.
  ///
  /// The keyframes have one begin time, while a change begins at the commit or at its own begin time, see
  /// `update(beginTime:at:)`, and the time between now and the commit isn't known until the commit. A change that moves
  /// has to keep its motion, so the keyframes begin now once one moves. Before that, they begin at the commit when a
  /// change begins there, so a transaction held open draws the changes with their own begin times late by the hold,
  /// until an update draws them again. The begin time only decides how the keyframes draw the changes, it doesn't change
  /// theirs.
  ///
  /// - Parameter now: The layer's current time.
  /// - Returns: `true` if a change begins at the commit and no change moves yet.
  func beginsAtCommit(at now: TimeInterval) -> Bool {
    var hasChangeBeginningAtCommit = false
    for change in changes {
      if change.beginTime == 0 {
        hasChangeBeginningAtCommit = true
      } else if change.beginTime <= now {
        return false
      }
    }
    return hasChangeBeginningAtCommit
  }

  /// The time the longest change has left.
  ///
  /// - Parameter now: The layer's current time.
  /// - Returns: The remaining time, zero without changes.
  func remainingTime(at now: TimeInterval) -> TimeInterval {
    changes.reduce(0) { max($0, $1.remainingTime(at: now) ?? 0) }
  }

  /// Whether a path has the segments of every change, so the offsets can be added to it.
  ///
  /// - Parameter path: The path.
  /// - Returns: `true` if the segments match, or there are no changes.
  func hasSameSegments(as path: PathPoints) -> Bool {
    changes.allSatisfy { $0.offset.hasSameSegments(as: path) }
  }

  /// Prepares the changes for an update of the path.
  ///
  /// A change has the begin time an animation of its timing gets, see `record(from:to:timing:at:)`, and a begin time
  /// that is set doesn't change, so the changes stay in step with animations of the same timings. A change without a
  /// begin time takes the begin time of the animation that shows it: the commit once Core Animation has resolved it, or
  /// the time the animation begins at when it doesn't begin at the commit, which is when it showed the change beginning.
  /// The changes that have landed are removed.
  ///
  /// - Parameters:
  ///   - beginTime: The begin time of the animation that shows the changes, zero while it begins at the next commit.
  ///   - now: The layer's current time.
  mutating func update(beginTime: TimeInterval, at now: TimeInterval) {
    for index in changes.indices where changes[index].beginTime == 0 {
      changes[index].beginTime = beginTime
    }
    changes.removeAll { $0.remainingTime(at: now) == nil }
  }

  /// Records a change of the path.
  ///
  /// The new path's points only line up with the old path's when they have the same segments, and they only blend when
  /// they are finite. Otherwise the changes in flight are dropped instead, and the new path shows at once.
  ///
  /// - Parameters:
  ///   - oldPoints: The points of the path before the change.
  ///   - newPoints: The points of the path after the change.
  ///   - timing: The timing of the change.
  ///   - now: The layer's current time.
  mutating func record(from oldPoints: PathPoints, to newPoints: PathPoints, timing: AnimationTiming, at now: TimeInterval) {
    guard oldPoints.hasSameSegments(as: newPoints), oldPoints.isFinite, newPoints.isFinite else {
      changes.removeAll()
      return
    }

    // `CGPath` equality compares how a path is stored, so paths built in other ways can be unequal with the same points,
    // which is no change
    let offset = oldPoints.subtracting(newPoints)
    guard !offset.isZero else {
      return
    }

    // a change without a duration shows at once, unless it has a delay
    guard timing.timing.duration > 0 || timing.delay > 0 else {
      return
    }

    // the change begins when `CALayer.animate` begins an animation of its timing, at the commit without a delay and the
    // delay from now with one, so it keeps in step with the animations of the same timing
    let animation = CABasicAnimation.makeAnimation(timing)
    changes.append(
      Change(
        offset: offset,
        animation: animation,
        curve: AnimationCurve(animation),
        speed: TimeInterval(animation.speed),
        beginTime: timing.delay > 0 ? now + timing.delay : 0
      )
    )
  }

  /// The keyframes of a path with the changes in flight.
  struct Keyframes {

    /// The path plus the part of each change's offset that is left, at the keyframes' times.
    let paths: [CGPath]

    /// The keyframes' times as fractions of the duration, or `nil` when the keyframes are spread evenly.
    let keyTimes: [NSNumber]?

    /// The keyframes' duration, see `remainingTime(at:)`.
    let duration: TimeInterval
  }

  /// The keyframes of a path plus the part of each change's offset that is left, from zero until every change has landed.
  ///
  /// The keyframes are spread evenly at the sampling rate, and each time a change begins or lands gets a keyframe of its
  /// own. A change starts or stops moving at those times, which the straight lines between evenly spread keyframes would
  /// round off, and a change shorter than the spacing, as a snap is, would show spread across it. A change that jumps
  /// when it lands, see `Change.landingFactor`, gets a keyframe at its landing time before the jump too, so the jump
  /// shows at once instead of across the spacing.
  ///
  /// A change that never finishes, see `CAAnimation.neverFinishes(duration:)`, isn't supported.
  ///
  /// - Parameters:
  ///   - path: The path.
  ///   - points: The points of the path, with the segments of the changes, see `hasSameSegments(as:)`.
  ///   - now: The layer's current time.
  /// - Returns: The keyframes, from now, or from the next commit, see `beginsAtCommit(at:)`. A keyframe where every
  ///   change has landed is the path itself.
  func keyframes(adding path: CGPath, points: PathPoints, at now: TimeInterval) -> Keyframes {
    ComposeUI.assert(
      !changes.contains(where: { CAAnimation.neverFinishes(duration: $0.curve.duration) }),
      "a path change that never finishes can't overlap others"
    )

    let duration = remainingTime(at: now)
    let sampledDuration = min(Constants.maxSampledDuration, duration)
    let evenSampleCount = max(2, Int((sampledDuration * Constants.samplesPerSecond).rounded(.up)) + 1)
    let times = sampleTimes(evenSampleCount: evenSampleCount, duration: duration, at: now)
    let sampleCount = times?.count ?? evenSampleCount

    // every sample reuses the factors and the sum, so sampling allocates only the paths
    var factors = [CGFloat](repeating: 0, count: changes.count)
    var sum = points.points

    var paths: [CGPath] = []
    paths.reserveCapacity(sampleCount)
    for sampleIndex in 0 ..< sampleCount {
      let sampleTime = times?[sampleIndex] ?? SampleTime(time: duration * (TimeInterval(sampleIndex) / TimeInterval(sampleCount - 1)))

      var hasOffset = false
      for changeIndex in changes.indices {
        let factor = changes[changeIndex].remainingFactor(at: sampleTime.time, now: now, beforeLanding: sampleTime.isBeforeLanding)
        factors[changeIndex] = factor
        hasOffset = hasOffset || factor != 0
      }

      guard hasOffset else {
        paths.append(path)
        continue
      }

      // assigning the points would share their storage, and the next write would copy it
      for pointIndex in sum.indices {
        sum[pointIndex] = points.points[pointIndex]
      }
      for changeIndex in changes.indices where factors[changeIndex] != 0 {
        let factor = factors[changeIndex]
        let offset = changes[changeIndex].offset.points
        for pointIndex in sum.indices {
          sum[pointIndex].x += offset[pointIndex].x * factor
          sum[pointIndex].y += offset[pointIndex].y * factor
        }
      }
      paths.append(PathPoints.path(kinds: points.kinds, points: sum))
    }
    return Keyframes(paths: paths, keyTimes: times?.map { NSNumber(value: $0.time / duration) }, duration: duration)
  }

  /// The time of a keyframe.
  private struct SampleTime {

    /// The time from now.
    let time: TimeInterval

    /// Whether the keyframe shows the changes that land at the time before their jump, see `Change.landingFactor`. It
    /// goes right before the keyframe at the same time that shows them landed.
    let isBeforeLanding: Bool

    /// The order of the keyframe: by time, and the keyframe before a jump first at the same time.
    var order: (TimeInterval, Int) {
      (time, isBeforeLanding ? 0 : 1)
    }

    init(time: TimeInterval, isBeforeLanding: Bool = false) {
      self.time = time
      self.isBeforeLanding = isBeforeLanding
    }
  }

  /// The times of the keyframes when a change begins or lands between evenly spread keyframes, or jumps when it lands:
  /// the evenly spread times, the times the changes begin and land, and the keyframes before the jumps.
  ///
  /// - Parameters:
  ///   - evenSampleCount: The number of evenly spread keyframes.
  ///   - duration: The keyframes' duration.
  ///   - now: The layer's current time.
  /// - Returns: The times from now, in order, or `nil` when every change begins and lands on an evenly spread time
  ///   without a jump.
  private func sampleTimes(evenSampleCount: Int, duration: TimeInterval, at now: TimeInterval) -> [SampleTime]? {
    let spacing = duration / TimeInterval(evenSampleCount - 1)
    func evenTime(_ index: Int) -> TimeInterval {
      duration * (TimeInterval(index) / TimeInterval(evenSampleCount - 1))
    }

    var boundaries: [SampleTime] = []
    func addBoundary(_ time: TimeInterval, isBeforeLanding: Bool = false) {
      // a change can jump when it lands at the end, where its keyframe before the jump goes before the last one
      guard time > 0, isBeforeLanding ? time <= duration : time < duration else {
        return
      }
      let evenIndex = (time / spacing).rounded()
      if abs(time / spacing - evenIndex) * spacing > Constants.timeTolerance {
        boundaries.append(SampleTime(time: time, isBeforeLanding: isBeforeLanding))
      } else if isBeforeLanding {
        // a jump on an evenly spread keyframe takes its time, so the keyframe before the jump sorts right before it
        boundaries.append(SampleTime(time: evenTime(Int(evenIndex)), isBeforeLanding: true))
      }
      // otherwise the time is on an evenly spread keyframe, which is its keyframe already
    }

    for change in changes {
      guard let landing = change.remainingTime(at: now) else {
        continue
      }
      addBoundary(change.beginTime == 0 ? 0 : change.beginTime - now)
      addBoundary(landing)
      if change.landingFactor != 0 {
        addBoundary(landing, isBeforeLanding: true)
      }
    }
    guard !boundaries.isEmpty else {
      return nil
    }

    let evenTimes = (0 ..< evenSampleCount).map { SampleTime(time: evenTime($0)) }
    return (evenTimes + boundaries).sorted { $0.order < $1.order }
  }

  // MARK: - Constants

  private enum Constants {

    /// The sampling rate of the path.
    ///
    /// Core Animation draws straight lines between samples. At 60 per second they stray from the path by a fraction of a
    /// point per 100 points of motion, about 0.1 for an ease of 0.35s and 0.5 for the default spring, and only while
    /// changes overlap, as one change is an animation that Core Animation evaluates on every frame. A display's rate of
    /// 120 would stray a quarter as much, but it doubles the paths to build and commit, so the rate stays at 60.
    static let samplesPerSecond: TimeInterval = 60

    /// The most motion sampled at the sampling rate. Longer changes get this much motion's worth of samples.
    ///
    /// For example, 10s of changes at 60 samples per second get 600 samples. Changes longer than 10s get fewer than 60
    /// samples per second. This is to prevent an absurd duration from building millions of samples.
    static let maxSampledDuration: TimeInterval = 10

    /// The distance within which two times are the same time. Times computed in different ways differ by far less, and
    /// keyframes are far further apart.
    static let timeTolerance: TimeInterval = 1e-9
  }
}
