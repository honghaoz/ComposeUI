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
    /// see `update(beginTime:at:)`.
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
    ///   - time: The time from now, see `PathChanges.sampledPaths(adding:points:at:)`.
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

  /// Whether a change has a begin time. The others begin when the animation that shows them is committed.
  var hasResolvedBeginTime: Bool {
    changes.contains { $0.beginTime != 0 }
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
  /// The changes recorded before the last commit take the begin time Core Animation gave the animation that shows them,
  /// and the changes that have landed are removed.
  ///
  /// - Parameters:
  ///   - beginTime: The begin time of the animation that shows the changes, zero until it is committed.
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

  /// A path plus the part of each change's offset that is left, at times spread evenly from zero until every change has
  /// landed, for keyframes.
  ///
  /// - Parameters:
  ///   - path: The path.
  ///   - points: The points of the path, with the segments of the changes, see `hasSameSegments(as:)`.
  ///   - now: The layer's current time.
  /// - Returns: A path per time, from now, or from the next commit when no change has a begin time, see
  ///   `hasResolvedBeginTime`. The path itself where every change has landed.
  func sampledPaths(adding path: CGPath, points: PathPoints, at now: TimeInterval) -> [CGPath] {
    let duration = remainingTime(at: now)
    let sampledDuration = min(Constants.maxSampledDuration, duration)
    let sampleCount = max(2, Int((sampledDuration * Constants.samplesPerSecond).rounded(.up)) + 1)

    // every sample reuses the factors and the sum, so sampling allocates only the paths
    var factors = [CGFloat](repeating: 0, count: changes.count)
    var sum = points.points

    var paths: [CGPath] = []
    paths.reserveCapacity(sampleCount)
    for sampleIndex in 0 ..< sampleCount {
      let time = duration * (TimeInterval(sampleIndex) / TimeInterval(sampleCount - 1))

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
    return paths
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
