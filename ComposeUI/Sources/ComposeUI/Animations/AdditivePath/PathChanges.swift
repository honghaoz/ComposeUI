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

    /// The animation that times the change: its curve, duration, speed and begin time.
    ///
    /// Its begin time is zero until the animation that shows the change is committed, see `update(beginTime:at:)`.
    let animation: CABasicAnimation

    /// The part of the offset left at a time.
    ///
    /// - Parameters:
    ///   - time: The time from now, see `PathChanges.points(adding:at:now:)`.
    ///   - now: The layer's current time.
    /// - Returns: One until the change begins, zero once it has landed.
    func remainingFactor(at time: TimeInterval, now: TimeInterval) -> CGFloat {
      // a spring doesn't reach exactly one at its end, so the change lands when its time is up
      guard let remainingTime = animation.remainingTime(at: now), time < remainingTime else {
        return 0
      }

      // an unset begin time resolves to the next commit, so the change is evaluated from its start
      let started = animation.beginTime == 0 ? 0 : now - animation.beginTime

      return CGFloat(1 - animation.progress(forElapsedTime: (started + time) * TimeInterval(animation.speed)))
    }
  }

  /// The changes in flight, in the order they were recorded.
  private(set) var changes: [Change] = []

  /// Whether no change is in flight.
  var isEmpty: Bool {
    changes.isEmpty
  }

  /// Whether a change has a begin time. The others begin when the animation that shows them is committed.
  var hasResolvedBeginTime: Bool {
    changes.contains { $0.animation.beginTime != 0 }
  }

  /// The time the longest change has left.
  ///
  /// - Parameter now: The layer's current time.
  /// - Returns: The remaining time, zero without changes.
  func remainingTime(at now: TimeInterval) -> TimeInterval {
    changes.reduce(0) { max($0, $1.animation.remainingTime(at: now) ?? 0) }
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
  /// The changes recorded before the last commit take the begin time Core Animation gave the animation that shows them,
  /// and the changes that have landed are removed.
  ///
  /// - Parameters:
  ///   - beginTime: The begin time of the animation that shows the changes, zero until it is committed.
  ///   - now: The layer's current time.
  mutating func update(beginTime: TimeInterval, at now: TimeInterval) {
    var remainingChanges: [Change] = []
    for change in changes {
      if change.animation.beginTime == 0 {
        change.animation.beginTime = beginTime
      }
      if change.animation.remainingTime(at: now) != nil {
        remainingChanges.append(change)
      }
    }
    changes = remainingChanges
  }

  /// Records a change of the path.
  ///
  /// The new path's points only line up with the old path's when they have the same segments, and they only blend when
  /// they are finite. Otherwise the changes in flight are dropped instead, and the new path shows at once.
  ///
  /// - Parameters:
  ///   - oldPath: The path before the change.
  ///   - newPath: The path after the change.
  ///   - timing: The timing of the change.
  ///   - now: The layer's current time.
  mutating func record(from oldPath: CGPath, to newPath: CGPath, timing: AnimationTiming, at now: TimeInterval) {
    let oldPoints = PathPoints(oldPath)
    let newPoints = PathPoints(newPath)
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

    // a change without a duration shows at once, unless it is scheduled
    guard timing.timing.duration > 0 || timing.delay > 0 else {
      return
    }

    let animation = CABasicAnimation.makeAnimation(timing)
    if timing.timing.duration <= 0 {
      animation.duration = scheduledSnapDuration
    }
    if timing.delay > 0 {
      animation.beginTime = now + timing.delay
    }

    changes.append(Change(offset: offset, animation: animation))
  }

  /// The points of a path plus the part of each change's offset that is left at a time.
  ///
  /// - Parameters:
  ///   - points: The points of the path, with the segments of the changes, see `hasSameSegments(as:)`.
  ///   - time: The time from now, or from the next commit when no change has a begin time, see `hasResolvedBeginTime`.
  ///   - now: The layer's current time.
  /// - Returns: The points, or `nil` when every change has landed by then.
  func points(adding points: PathPoints, at time: TimeInterval, now: TimeInterval) -> PathPoints? {
    var sum: PathPoints?
    for change in changes {
      let factor = change.remainingFactor(at: time, now: now)
      guard factor != 0 else {
        continue
      }
      sum = (sum ?? points).adding(change.offset, multipliedBy: factor)
    }
    return sum
  }

  /// The times to sample the path at, spread evenly from zero until every change has landed.
  ///
  /// - Parameter now: The layer's current time.
  /// - Returns: The times, from now, or from the next commit when no change has a begin time, see `hasResolvedBeginTime`.
  func sampleTimes(at now: TimeInterval) -> [TimeInterval] {
    let duration = remainingTime(at: now)
    let sampledDuration = min(Constants.maxSampledDuration, duration)
    let sampleCount = max(2, Int((sampledDuration * Constants.samplesPerSecond).rounded(.up)) + 1)
    return (0 ..< sampleCount).map { duration * (TimeInterval($0) / TimeInterval(sampleCount - 1)) }
  }

  // MARK: - Constants

  private enum Constants {

    /// The sampling rate of the path.
    static let samplesPerSecond: TimeInterval = 60 // TODO: do we need to make this following the device's refresh rate?

    /// The most motion sampled at the sampling rate. Longer changes get this much motion's worth of samples.
    ///
    /// For example, 10s of changes at 60 samples per second get 600 samples. Changes longer than 10s get fewer than 60
    /// samples per second. This is to prevent an absurd duration from building millions of samples.
    static let maxSampledDuration: TimeInterval = 10
  }
}
