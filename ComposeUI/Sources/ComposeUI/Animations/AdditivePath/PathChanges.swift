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

    /// The part of the offset from the layer's size changing, or `nil` when it's all from the path's shape changing, see
    /// `record(from:to:pointsAtOldSize:timing:at:)`. The rest of the offset is the shape's part.
    let sizeOffset: PathPoints?

    /// The animation of the change's timing, which shows the change when it is the only one in flight. Its begin time
    /// isn't kept, see `beginTime`.
    let animation: CABasicAnimation

    /// The curve of the change's timing.
    let curve: AnimationCurve

    /// The speed of the change's timing.
    let speed: TimeInterval

    /// The time the change begins, in the layer's time space, never zero, see `record(from:to:timing:at:)`.
    let beginTime: TimeInterval

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

      return CGFloat(1 - curve.progress(forElapsedTime: (now - beginTime + time) * speed))
    }

    /// A copy of the change with some parts of its offset, which keeps the change's timing.
    ///
    /// - Parameters:
    ///   - parts: The parts to keep.
    ///   - sizeOffset: The change's `sizeOffset`, which a change has when it has parts to split.
    /// - Returns: The copy.
    fileprivate func keeping(_ parts: ChangeParts, sizeOffset: PathPoints) -> Change {
      let keepsShape = parts.contains(.shape)
      let keepsSizeX = parts.contains(.sizeX)
      let keepsSizeY = parts.contains(.sizeY)
      let keepsSize = keepsSizeX || keepsSizeY
      var keptOffset: [CGPoint] = []
      keptOffset.reserveCapacity(offset.points.count)
      var keptSizeOffset: [CGPoint] = []
      keptSizeOffset.reserveCapacity(keepsSize ? offset.points.count : 0)
      for index in offset.points.indices {
        let point = offset.points[index]
        let size = sizeOffset.points[index]
        let keptSize = CGPoint(x: keepsSizeX ? size.x : 0, y: keepsSizeY ? size.y : 0)
        let keptShape = keepsShape ? CGPoint(x: point.x - size.x, y: point.y - size.y) : .zero
        keptOffset.append(CGPoint(x: keptShape.x + keptSize.x, y: keptShape.y + keptSize.y))
        if keepsSize {
          keptSizeOffset.append(keptSize)
        }
      }
      return Change(
        offset: PathPoints(kinds: offset.kinds, points: keptOffset),
        sizeOffset: keepsSize ? PathPoints(kinds: offset.kinds, points: keptSizeOffset) : nil,
        animation: animation,
        curve: curve,
        speed: speed,
        beginTime: beginTime
      )
    }
  }

  /// The changes in flight, in the order they were recorded.
  private(set) var changes: [Change] = []

  /// Whether no change is in flight.
  var isEmpty: Bool {
    changes.isEmpty
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

  /// Removes the changes that have landed.
  ///
  /// - Parameter now: The layer's current time.
  mutating func removeLandedChanges(at now: TimeInterval) {
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
  ///   - pointsAtOldSize: The points of the new path at the size the old path was made for, when the path follows the
  ///     layer's size and the size changed: the change up to them is the shape's part, and the rest the size's, see
  ///     `Change.sizeOffset`. `nil`, or points without the new path's segments, make the change all the shape's.
  ///   - timing: The timing of the change.
  ///   - now: The layer's current time.
  mutating func record(from oldPoints: PathPoints, to newPoints: PathPoints, pointsAtOldSize: PathPoints? = nil, timing: AnimationTiming, at now: TimeInterval) {
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

    let sizeOffset: PathPoints?
    if pointsAtOldSize == oldPoints {
      // the shape didn't change, as is usual, so the change is all the size's
      sizeOffset = offset
    } else if let pointsAtOldSize, pointsAtOldSize.hasSameSegments(as: newPoints), pointsAtOldSize.isFinite {
      let resize = pointsAtOldSize.subtracting(newPoints)
      sizeOffset = resize.isZero ? nil : resize
    } else {
      sizeOffset = nil
    }
    append(offset: offset, sizeOffset: sizeOffset, timing: timing, at: now)
  }

  /// Adds a change of an offset.
  ///
  /// - Parameters:
  ///   - offset: The change's offset.
  ///   - sizeOffset: The size's part of the offset, see `Change.sizeOffset`.
  ///   - timing: The timing of the change.
  ///   - now: The layer's current time.
  private mutating func append(offset: PathPoints, sizeOffset: PathPoints?, timing: AnimationTiming, at now: TimeInterval) {
    // the change begins when `CALayer.animate` begins an animation of its timing, so it keeps in step with the
    // animations of the same timing
    let animation = CABasicAnimation.makeAnimation(timing)
    changes.append(
      Change(
        offset: offset,
        sizeOffset: sizeOffset,
        animation: animation,
        curve: AnimationCurve(animation),
        speed: TimeInterval(animation.speed),
        beginTime: CAAnimation.beginTime(at: now, delay: timing.delay)
      )
    )
  }

  /// Retargets the changes in flight to a new path, so the path shown glides from where it is to the new path and lands
  /// when the changes would have, see `CALayer.retargetPath(keyPath:to:pathAtOldSize:)`.
  ///
  /// The path's change has the shape's part, up to the points at the old size, and the size's part, from them, and each
  /// is judged coordinate by coordinate against the motion of the same part of the changes in flight. A changed
  /// coordinate in motion glides from where it shows, and one at rest takes its new value at once.
  ///
  /// - The shape's part glides when a coordinate it changes is in motion, folding the shape's parts of the changes.
  /// - The size's part is judged axis by axis, as a frame's size is in `CALayer.retargetFrame(to:)`: the size glides
  ///   along an axis when a coordinate it changes along that axis is in motion, folding the motion of the changes'
  ///   size parts along it. Along an axis that doesn't glide, they keep going with their timing.
  /// - A part that doesn't glide keeps its motion as it is, as the changes still head to the new path.
  /// - Each glide is an ease-out change that lands when the changes it folds would have, and the glides that land
  ///   together share a change. A running spring that settles keeps going with the glides stacked on it. A change that
  ///   never finishes folds whole, as it can't overlap others, and the glides of its parts take
  ///   `Animations.defaultAnimationDuration`.
  ///
  /// - Parameters:
  ///   - oldPoints: The points of the model path before the change.
  ///   - newPoints: The points of the new path.
  ///   - pointsAtOldSize: The points of the new path at the size the old path was made for, see
  ///     `record(from:to:pointsAtOldSize:timing:at:)`. `nil` makes the change all the shape's.
  ///   - now: The layer's current time.
  mutating func retarget(from oldPoints: PathPoints, to newPoints: PathPoints, pointsAtOldSize: PathPoints? = nil, at now: TimeInterval) {
    guard hasSameSegments(as: oldPoints), oldPoints.hasSameSegments(as: newPoints), oldPoints.isFinite, newPoints.isFinite else {
      changes.removeAll()
      return
    }

    let old = oldPoints.points
    let new = newPoints.points
    let atOldSize = pointsAtOldSize.flatMap { $0.hasSameSegments(as: newPoints) && $0.isFinite ? $0.points : nil } ?? new
    let motions = changes.map { ChangeMotion($0, at: now) }

    // a part glides when a coordinate it changes is in motion from the same part of the changes. a changed coordinate at
    // rest has no motion to continue
    let tolerance = ComposeUI.Constants.geometryTolerance
    var foldedParts: ChangeParts = []
    for index in old.indices {
      let motion = pointMotion(at: index, motions: motions, folding: false)
      let shapeChange = CGPoint(x: old[index].x - atOldSize[index].x, y: old[index].y - atOldSize[index].y)
      let sizeChange = CGPoint(x: atOldSize[index].x - new[index].x, y: atOldSize[index].y - new[index].y)
      if motion.shapeMoves.x && abs(shapeChange.x) > tolerance || motion.shapeMoves.y && abs(shapeChange.y) > tolerance {
        foldedParts.insert(.shape)
      }
      if motion.sizeMoves.x, abs(sizeChange.x) > tolerance {
        foldedParts.insert(.sizeX)
      }
      if motion.sizeMoves.y, abs(sizeChange.y) > tolerance {
        foldedParts.insert(.sizeY)
      }
    }
    guard !foldedParts.isEmpty else {
      return
    }

    // a change that never finishes can't keep going next to a glide, see `keyframes(adding:points:at:)`, so it folds whole
    for motion in motions where motion.neverFinishes {
      foldedParts.formUnion(motion.movedParts)
    }

    // a folded coordinate in motion glides from where it shows, and a changed coordinate at rest takes its new value at
    // once
    let foldsShape = foldedParts.contains(.shape)
    let foldsSizeX = foldedParts.contains(.sizeX)
    let foldsSizeY = foldedParts.contains(.sizeY)
    var shapeGlide = [CGPoint](repeating: .zero, count: foldsShape ? old.count : 0)
    var sizeGlide = [CGPoint](repeating: .zero, count: foldsSizeX || foldsSizeY ? old.count : 0)
    for index in old.indices {
      let motion = pointMotion(at: index, motions: motions, folding: true)
      if foldsShape {
        shapeGlide[index] = CGPoint(
          x: motion.shapeMoves.x ? old[index].x - atOldSize[index].x + motion.foldedShape.x : 0,
          y: motion.shapeMoves.y ? old[index].y - atOldSize[index].y + motion.foldedShape.y : 0
        )
      }
      if foldsSizeX, motion.sizeMoves.x {
        sizeGlide[index].x = atOldSize[index].x - new[index].x + motion.foldedSize.x
      }
      if foldsSizeY, motion.sizeMoves.y {
        sizeGlide[index].y = atOldSize[index].y - new[index].y + motion.foldedSize.y
      }
    }

    // the folded parts go into the glides, and the rest of a change keeps going in a copy of it, with its timing
    changes = zip(changes, motions).compactMap { change, motion in
      guard motion.remainingFactor != nil, !motion.movedParts.isDisjoint(with: foldedParts) else {
        return change
      }
      let keptParts = motion.movedParts.subtracting(foldedParts)
      // a change without a size's part is all the shape's, so it folds whole
      guard !keptParts.isEmpty, let sizeOffset = change.sizeOffset else {
        return nil
      }
      return change.keeping(keptParts, sizeOffset: sizeOffset)
    }

    // each part glides over the time the changes that move it have left, so it lands when they would have
    func glideDuration(of part: ChangeParts) -> TimeInterval {
      var duration: TimeInterval = 0
      for motion in motions where motion.movedParts.contains(part) {
        guard !motion.neverFinishes else {
          // a change that never finishes has no landing to glide to
          return Animations.defaultAnimationDuration
        }
        duration = max(duration, motion.remainingTime)
      }
      return duration
    }
    var recordedParts: ChangeParts = []
    for part in ChangeParts.ordered where foldedParts.contains(part) && !recordedParts.contains(part) {
      let duration = glideDuration(of: part)
      let parts = ChangeParts.ordered.reduce(into: ChangeParts()) { parts, other in
        if foldedParts.contains(other), glideDuration(of: other) == duration {
          parts.insert(other)
        }
      }
      recordedParts.formUnion(parts)
      appendGlide(of: parts, shapeGlide: shapeGlide, sizeGlide: sizeGlide, kinds: newPoints.kinds, duration: duration, at: now)
    }
  }

  /// Adds an ease-out change that glides parts of the path from where they show, see
  /// `retarget(from:to:pointsAtOldSize:at:)`.
  ///
  /// - Parameters:
  ///   - parts: The parts the change glides.
  ///   - shapeGlide: The glide of the shape's part, point by point, or no points when the shape doesn't glide.
  ///   - sizeGlide: The glide of the size's part, point by point, or no points when the size doesn't glide.
  ///   - kinds: The kinds of the path's segments.
  ///   - duration: The duration of the glide.
  ///   - now: The layer's current time.
  private mutating func appendGlide(of parts: ChangeParts, shapeGlide: [CGPoint], sizeGlide: [CGPoint], kinds: [CGPathElementType], duration: TimeInterval, at now: TimeInterval) {
    // a glide without a duration shows at once
    guard duration > 0 else {
      return
    }
    let glidesShape = parts.contains(.shape)
    let glidesSizeX = parts.contains(.sizeX)
    let glidesSizeY = parts.contains(.sizeY)
    // a glide of the size alone is its own size's part, and a glide of both keeps the size's part apart
    let keepsSizeApart = glidesShape && (glidesSizeX || glidesSizeY)
    let count = max(shapeGlide.count, sizeGlide.count)
    var offset: [CGPoint] = []
    offset.reserveCapacity(count)
    var sizeOffset: [CGPoint] = []
    sizeOffset.reserveCapacity(keepsSizeApart ? count : 0)
    // the glide's points come from sums that cancel out where the path shows the new one, which leaves rounding errors
    // instead of zeros, so a glide within the tolerance is none
    let tolerance = ComposeUI.Constants.geometryTolerance
    var hasOffset = false
    var hasSizeOffset = false
    for index in 0 ..< count {
      let shape = glidesShape ? shapeGlide[index] : .zero
      let size = CGPoint(x: glidesSizeX ? sizeGlide[index].x : 0, y: glidesSizeY ? sizeGlide[index].y : 0)
      let point = CGPoint(x: shape.x + size.x, y: shape.y + size.y)
      offset.append(point)
      hasOffset = hasOffset || abs(point.x) > tolerance || abs(point.y) > tolerance
      if keepsSizeApart {
        sizeOffset.append(size)
        hasSizeOffset = hasSizeOffset || abs(size.x) > tolerance || abs(size.y) > tolerance
      }
    }
    guard hasOffset else {
      return
    }
    let offsetPoints = PathPoints(kinds: kinds, points: offset)
    let sizeOffsetPoints: PathPoints?
    if keepsSizeApart {
      sizeOffsetPoints = hasSizeOffset ? PathPoints(kinds: kinds, points: sizeOffset) : nil
    } else {
      sizeOffsetPoints = glidesShape ? nil : offsetPoints
    }
    append(offset: offsetPoints, sizeOffset: sizeOffsetPoints, timing: .easeOut(duration: duration), at: now)
  }

  /// The motion of the changes in flight at a point.
  ///
  /// - Parameters:
  ///   - index: The index of the point.
  ///   - motions: The motions of the changes, see `ChangeMotion`.
  ///   - folding: Whether to sum up the parts the folding changes have left.
  /// - Returns: The coordinates the changes' parts move, and when folding, the parts of those the folding changes have
  ///   left.
  private func pointMotion(at index: Int, motions: [ChangeMotion], folding: Bool) -> PointMotion {
    let tolerance = ComposeUI.Constants.geometryTolerance
    var motion = PointMotion()
    for (change, changeMotion) in zip(changes, motions) {
      let offset = change.offset.points[index]
      let size = change.sizeOffset?.points[index] ?? .zero
      let shape = CGPoint(x: offset.x - size.x, y: offset.y - size.y)
      motion.shapeMoves.x = motion.shapeMoves.x || abs(shape.x) > tolerance
      motion.shapeMoves.y = motion.shapeMoves.y || abs(shape.y) > tolerance
      motion.sizeMoves.x = motion.sizeMoves.x || abs(size.x) > tolerance
      motion.sizeMoves.y = motion.sizeMoves.y || abs(size.y) > tolerance
      if folding, let remainingFactor = changeMotion.remainingFactor {
        motion.foldedShape.x += shape.x * remainingFactor
        motion.foldedShape.y += shape.y * remainingFactor
        motion.foldedSize.x += size.x * remainingFactor
        motion.foldedSize.y += size.y * remainingFactor
      }
    }
    return motion
  }

  /// Parts of a path's change, which a retarget judges apart, see `retarget(from:to:pointsAtOldSize:at:)`.
  fileprivate struct ChangeParts: OptionSet {

    let rawValue: Int

    /// The shape's part.
    static let shape = ChangeParts(rawValue: 1 << 0)

    /// The size's part along x.
    static let sizeX = ChangeParts(rawValue: 1 << 1)

    /// The size's part along y.
    static let sizeY = ChangeParts(rawValue: 1 << 2)

    /// The parts one by one, in the order their glides are recorded.
    static let ordered: [ChangeParts] = [.shape, .sizeX, .sizeY]
  }

  /// What a retarget needs of a change in flight.
  private struct ChangeMotion {

    /// The part of the change's offset it has left, or `nil` for a running spring that settles, which keeps going so its
    /// momentum carries on.
    let remainingFactor: CGFloat?

    /// The time the change has left.
    let remainingTime: TimeInterval

    /// Whether the change never finishes, see `CAAnimation.neverFinishes(duration:)`.
    let neverFinishes: Bool

    /// The parts of its offset the change moves points by.
    let movedParts: ChangeParts

    init(_ change: Change, at now: TimeInterval) {
      neverFinishes = CAAnimation.neverFinishes(duration: change.curve.duration)
      let isRunningSpring = change.animation is CASpringAnimation && !neverFinishes && change.speed > 0 && change.beginTime <= now
      remainingFactor = isRunningSpring ? nil : change.remainingFactor(at: 0, now: now)
      remainingTime = change.remainingTime(at: now) ?? 0

      let tolerance = ComposeUI.Constants.geometryTolerance
      var movedParts: ChangeParts = []
      for index in change.offset.points.indices {
        let offset = change.offset.points[index]
        let size = change.sizeOffset?.points[index] ?? .zero
        if abs(offset.x - size.x) > tolerance || abs(offset.y - size.y) > tolerance {
          movedParts.insert(.shape)
        }
        if abs(size.x) > tolerance {
          movedParts.insert(.sizeX)
        }
        if abs(size.y) > tolerance {
          movedParts.insert(.sizeY)
        }
      }
      self.movedParts = movedParts
    }
  }

  /// The motion of the changes in flight at a point, see `pointMotion(at:motions:folding:)`.
  private struct PointMotion {

    /// The coordinates the shape's parts of the changes move.
    var shapeMoves = (x: false, y: false)

    /// The coordinates the size's parts of the changes move.
    var sizeMoves = (x: false, y: false)

    /// The part of the shape's parts that the folding changes have left.
    var foldedShape = CGPoint.zero

    /// The part of the size's parts that the folding changes have left.
    var foldedSize = CGPoint.zero
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
  /// - Returns: The keyframes, from now. A keyframe where every change has landed is the path itself.
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
      addBoundary(change.beginTime - now)
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
