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

    /// The time the change begins, in the layer's time space, or zero until the animation that shows it is committed,
    /// see `update(beginTime:sampledBeginTime:at:)`.
    var beginTime: TimeInterval

    /// The time the change has left, see `CAAnimation.remainingTime(at:)`.
    ///
    /// - Parameter now: The layer's current time.
    /// - Returns: The remaining time, or `nil` when the change has landed.
    func remainingTime(at now: TimeInterval) -> TimeInterval? {
      CAAnimation.remainingTime(beginTime: beginTime, duration: curve.duration, speed: speed, at: now)
    }

    /// The part of the offset left at a time.
    ///
    /// - Parameters:
    ///   - time: The time from now, see `PathChanges.keyframes(adding:points:at:)`.
    ///   - now: The layer's current time.
    /// - Returns: One until the change begins, zero once it has landed.
    func remainingFactor(at time: TimeInterval, now: TimeInterval) -> CGFloat {
      // a spring doesn't reach exactly one at its end, so the change lands when its time is up
      guard let remainingTime = remainingTime(at: now), time < remainingTime else {
        return 0
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
  /// A change without a delay begins at the commit, as an animation without a delay does, while a change with a delay
  /// begins its delay after it was recorded. The keyframes have one begin time, so they begin at the commit when a
  /// change begins there and no change moves yet, and a transaction held open delays the other changes by the hold.
  /// Once a change moves, the keyframes begin now to keep it where it is shown, and a change that begins at the commit
  /// begins now with them.
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
  /// Once the animation that shows the changes is committed, the changes that begin at the commit take the begin time
  /// Core Animation gave the animation, and the other changes move by as much as that begin time differs from the one
  /// the animation was sampled for, so every change stays where the animation showed it. The changes that have landed
  /// are removed.
  ///
  /// - Parameters:
  ///   - beginTime: The begin time of the animation that shows the changes, zero until it is committed.
  ///   - sampledBeginTime: The begin time the animation was sampled for: the time it was made at when it begins at the
  ///     commit, otherwise its begin time.
  ///   - now: The layer's current time.
  mutating func update(beginTime: TimeInterval, sampledBeginTime: TimeInterval, at now: TimeInterval) {
    if beginTime != 0 {
      let shift = beginTime - sampledBeginTime
      for index in changes.indices {
        if changes[index].beginTime == 0 {
          changes[index].beginTime = beginTime
        } else {
          changes[index].beginTime += shift
        }
      }
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
  /// The keyframes are spread evenly at the sampling rate. A change too short for the spacing, as a snap is, would show
  /// spread across the spacing, so the times it begins and lands get keyframes of their own, which hold it until it
  /// begins and land it when it lands.
  ///
  /// - Parameters:
  ///   - path: The path.
  ///   - points: The points of the path, with the segments of the changes, see `hasSameSegments(as:)`.
  ///   - now: The layer's current time.
  /// - Returns: The keyframes, from now, or from the next commit, see `beginsAtCommit(at:)`. A keyframe where every
  ///   change has landed is the path itself.
  func keyframes(adding path: CGPath, points: PathPoints, at now: TimeInterval) -> Keyframes {
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
      let time = times?[sampleIndex] ?? duration * (TimeInterval(sampleIndex) / TimeInterval(sampleCount - 1))

      var hasOffset = false
      for changeIndex in changes.indices {
        let factor = changes[changeIndex].remainingFactor(at: time, now: now)
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
    return Keyframes(paths: paths, keyTimes: times?.map { NSNumber(value: $0 / duration) }, duration: duration)
  }

  /// The times of the keyframes when a change is too short for evenly spread keyframes: the evenly spread times, and
  /// the times the short changes begin and land.
  ///
  /// - Parameters:
  ///   - evenSampleCount: The number of evenly spread keyframes.
  ///   - duration: The keyframes' duration.
  ///   - now: The layer's current time.
  /// - Returns: The times from now, in order, or `nil` when no change is too short.
  private func sampleTimes(evenSampleCount: Int, duration: TimeInterval, at now: TimeInterval) -> [TimeInterval]? {
    let spacing = duration / TimeInterval(evenSampleCount - 1)
    var boundaries: [TimeInterval] = []
    for change in changes {
      guard let landing = change.remainingTime(at: now) else {
        continue
      }

      // a change shorter than two spacings has one evenly spread keyframe within it at most
      let begin = change.beginTime == 0 ? 0 : change.beginTime - now
      guard landing - begin < 2 * spacing else {
        continue
      }
      for time in [begin, landing] where time > 0 && time < duration {
        boundaries.append(time)
      }
    }
    guard !boundaries.isEmpty else {
      return nil
    }

    let evenTimes = (0 ..< evenSampleCount).map { duration * (TimeInterval($0) / TimeInterval(evenSampleCount - 1)) }
    return (evenTimes + boundaries).sorted()
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
  }
}
