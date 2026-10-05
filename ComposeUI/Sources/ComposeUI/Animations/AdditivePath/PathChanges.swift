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

    /// The part of the offset from the layer's width changing, or `nil` when the width didn't change, see
    /// `record(from:to:resize:timing:at:)`.
    let widthOffset: PathPoints?

    /// The part of the offset from the layer's height changing, or `nil` when the height didn't change. The rest of the
    /// offset, past the width's and the height's parts, is the shape's part.
    let heightOffset: PathPoints?

    /// The animation of the change's timing, which shows the change when it is the only one in flight. Its begin time
    /// isn't kept, see `beginTime`.
    let animation: CABasicAnimation

    /// The curve of the change's timing.
    let curve: AnimationCurve

    /// The speed of the change's timing.
    let speed: TimeInterval

    /// The time the change begins, in the layer's time space, never zero, see `record(from:to:resize:timing:at:)`.
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

    /// The parts of the offset at a point, by cause.
    ///
    /// - Parameter index: The index of the point.
    /// - Returns: The shape's part, the width's part and the height's part of the offset at the point.
    fileprivate func parts(at index: Int) -> (shape: CGPoint, width: CGPoint, height: CGPoint) {
      let offset = offset.points[index]
      let width = widthOffset?.points[index] ?? .zero
      let height = heightOffset?.points[index] ?? .zero
      return (CGPoint(x: offset.x - width.x - height.x, y: offset.y - width.y - height.y), width, height)
    }

    /// A copy of the change with some parts of its offset, which keeps the change's timing.
    ///
    /// - Parameter parts: The parts to keep.
    /// - Returns: The copy.
    fileprivate func keeping(_ parts: ChangeParts) -> Change {
      let keepsShape = parts.contains(.shape)
      let keepsWidth = parts.contains(.width)
      let keepsHeight = parts.contains(.height)
      var keptOffset: [CGPoint] = []
      keptOffset.reserveCapacity(offset.points.count)
      for index in offset.points.indices {
        let (shape, width, height) = self.parts(at: index)
        var point = keepsShape ? shape : .zero
        if keepsWidth {
          point.x += width.x
          point.y += width.y
        }
        if keepsHeight {
          point.x += height.x
          point.y += height.y
        }
        keptOffset.append(point)
      }
      return Change(
        offset: PathPoints(kinds: offset.kinds, points: keptOffset),
        widthOffset: keepsWidth ? widthOffset : nil,
        heightOffset: keepsHeight ? heightOffset : nil,
        animation: animation,
        curve: curve,
        speed: speed,
        beginTime: beginTime
      )
    }
  }

  /// The points of a path that follows its layer's size at the sizes between an old path's and a new path's, which tell
  /// the change of the path's shape apart from the changes of the width and the height: the change from the old path to
  /// the points at the old size is the shape's, from those to the points at the new width the width's, and from those to
  /// the new path the height's.
  struct Resize {

    /// The points of the new path at the size the old path was made for.
    let atOldSize: PathPoints

    /// The points of the new path at the new width and the old height.
    let atNewWidth: PathPoints

    /// Whether the points line up with a path's, which takes the same segments, and are finite.
    ///
    /// - Parameter points: The points of the path.
    /// - Returns: `true` if the points can be added to and subtracted from the path's.
    fileprivate func linesUp(with points: PathPoints) -> Bool {
      atOldSize.hasSameSegments(as: points) && atNewWidth.hasSameSegments(as: points) && atOldSize.isFinite && atNewWidth.isFinite
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
  ///   - resize: The points of the new path at the sizes between, when the path follows the layer's size and the size
  ///     changed, which tell the parts of the change apart, see `Resize`. `nil`, or points that don't line up with the
  ///     new path's, make the change all the shape's.
  ///   - timing: The timing of the change.
  ///   - now: The layer's current time.
  mutating func record(from oldPoints: PathPoints, to newPoints: PathPoints, resize: Resize? = nil, timing: AnimationTiming, at now: TimeInterval) {
    guard oldPoints.hasSameSegments(as: newPoints), oldPoints.isFinite, newPoints.isFinite else {
      changes.removeAll()
      return
    }

    let offset = oldPoints.subtracting(newPoints)
    func part(from start: PathPoints, to end: PathPoints) -> PathPoints? {
      guard start != end else {
        return nil
      }
      // a part is the whole change when the other causes didn't change, as the width's is in a usual resize, so the
      // change's offset serves as it
      guard start != oldPoints || end != newPoints else {
        return offset
      }
      return start.subtracting(end)
    }
    let resize = resize.flatMap { $0.linesUp(with: newPoints) ? $0 : nil }
    let widthOffset = resize.flatMap { part(from: $0.atOldSize, to: $0.atNewWidth) }
    let heightOffset = resize.flatMap { part(from: $0.atNewWidth, to: newPoints) }

    // `CGPath` equality compares how a path is stored, so paths built in other ways can be unequal with the same points,
    // which is no change. a resize that a change of the shape cancels out is a change though, as the path's size moves
    // with the layer's size if a later change retargets it
    guard !offset.isZero || widthOffset != nil || heightOffset != nil else {
      return
    }

    // a change without a duration shows at once, unless it has a delay
    guard timing.timing.duration > 0 || timing.delay > 0 else {
      return
    }

    append(offset: offset, widthOffset: widthOffset, heightOffset: heightOffset, timing: timing, at: now)
  }

  /// Adds a change of an offset.
  ///
  /// - Parameters:
  ///   - offset: The change's offset.
  ///   - widthOffset: The width's part of the offset, see `Change.widthOffset`.
  ///   - heightOffset: The height's part of the offset, see `Change.heightOffset`.
  ///   - timing: The timing of the change.
  ///   - now: The layer's current time.
  private mutating func append(offset: PathPoints, widthOffset: PathPoints?, heightOffset: PathPoints?, timing: AnimationTiming, at now: TimeInterval) {
    // the change begins when `CALayer.animate` begins an animation of its timing, so it keeps in step with the
    // animations of the same timing
    let animation = CABasicAnimation.makeAnimation(timing)
    changes.append(
      Change(
        offset: offset,
        widthOffset: widthOffset,
        heightOffset: heightOffset,
        animation: animation,
        curve: AnimationCurve(animation),
        speed: TimeInterval(animation.speed),
        beginTime: CAAnimation.beginTime(at: now, delay: timing.delay)
      )
    )
  }

  /// Retargets the changes in flight to a new path, so the path shown glides from where it is to the new path and lands
  /// when the changes would have, see `CALayer.retargetPath(keyPath:resizingFrom:to:)`.
  ///
  /// The path's change has the shape's part, the width's part and the height's part, see `Resize`, and each is judged
  /// against the motion of the same part of the changes in flight, so a path that follows its layer's frame glides where
  /// the frame does.
  ///
  /// - The width and the height are judged as a frame's size is, axis by axis, in `CALayer.retargetFrame(to:)`: one that
  ///   changed and that a change in flight moves glides from where it shows, folding the changes' motion of it, one that
  ///   changed at rest takes its new value at once, and one that didn't change keeps the changes' motion of it.
  /// - The shape is judged change by change, as the points of a change move together: a change whose shape's part moves
  ///   a coordinate that the shape's change changes folds that part whole, and the other changes keep theirs. A changed
  ///   coordinate that no change moves takes its new value at once.
  /// - Each glide is an ease-out change that lands when the changes it continues would have, and the glides that land
  ///   together share a change. A running spring that settles keeps going with the glides stacked on it.
  /// - A change that never finishes can't keep going next to a glide, so it folds whole, as a frame folds a spring that
  ///   never settles when its part glides, and the glides take `Animations.defaultAnimationDuration`. When only the shape
  ///   glides, a change that moves the width or the height keeps going instead, as the frame's size does, and the shape's
  ///   change shows at once.
  ///
  /// - Parameters:
  ///   - oldPoints: The points of the model path before the change.
  ///   - newPoints: The points of the new path.
  ///   - resize: The points of the new path at the sizes between, see `record(from:to:resize:timing:at:)`. `nil` makes
  ///     the change all the shape's.
  ///   - now: The layer's current time.
  mutating func retarget(from oldPoints: PathPoints, to newPoints: PathPoints, resize: Resize? = nil, at now: TimeInterval) {
    guard hasSameSegments(as: oldPoints), oldPoints.hasSameSegments(as: newPoints), oldPoints.isFinite, newPoints.isFinite else {
      changes.removeAll()
      return
    }

    let resize = resize.flatMap { $0.linesUp(with: newPoints) ? $0 : nil }
    let old = oldPoints.points
    let new = newPoints.points
    let atOldSize = resize?.atOldSize.points ?? new
    let atNewWidth = resize?.atNewWidth.points ?? new
    var motions = changes.map { ChangeMotion($0, at: now) }

    let tolerance = ComposeUI.Constants.geometryTolerance
    var widthChanged = false
    var heightChanged = false
    for index in old.indices {
      widthChanged = widthChanged || abs(atOldSize[index].x - atNewWidth[index].x) > tolerance || abs(atOldSize[index].y - atNewWidth[index].y) > tolerance
      heightChanged = heightChanged || abs(atNewWidth[index].x - new[index].x) > tolerance || abs(atNewWidth[index].y - new[index].y) > tolerance
      let shapeChanged = (x: abs(old[index].x - atOldSize[index].x) > tolerance, y: abs(old[index].y - atOldSize[index].y) > tolerance)
      guard shapeChanged.x || shapeChanged.y else {
        continue
      }
      for changeIndex in changes.indices where !motions[changeIndex].meetsShapeChange {
        let shape = changes[changeIndex].parts(at: index).shape
        if shapeChanged.x && abs(shape.x) > tolerance || shapeChanged.y && abs(shape.y) > tolerance {
          motions[changeIndex].meetsShapeChange = true
        }
      }
    }
    // the width and the height glide when they changed and a change in flight moves them, as a frame's size does axis by
    // axis, and the shape glides for the changes that move a coordinate it changes, as the points of a change move
    // together
    var foldedParts: ChangeParts = []
    if widthChanged, motions.contains(where: { $0.movedParts.contains(.width) }) {
      foldedParts.insert(.width)
    }
    if heightChanged, motions.contains(where: { $0.movedParts.contains(.height) }) {
      foldedParts.insert(.height)
    }
    if motions.contains(where: \.meetsShapeChange) {
      foldedParts.insert(.shape)
    }
    guard !foldedParts.isEmpty else {
      return
    }

    // a change that never finishes can't keep going next to a glide, see `keyframes(adding:points:at:)`, so it folds
    // whole, as a frame folds a spring that never settles when its part glides. when only the shape glides, a change that
    // moves the size keeps going instead, as folding it would stop the path's size while the frame's size keeps going,
    // and the shape's change shows at once
    let sizeGlides = !foldedParts.isDisjoint(with: .size)
    for changeIndex in motions.indices where motions[changeIndex].neverFinishes {
      guard sizeGlides || motions[changeIndex].movedParts.isDisjoint(with: .size) else {
        return
      }
      foldedParts.formUnion(motions[changeIndex].movedParts)
      motions[changeIndex].meetsShapeChange = motions[changeIndex].movedParts.contains(.shape)
    }

    // a folded part glides from where it shows: the width and the height whole, as a frame's size does, and the shape at
    // the coordinates the changes move it, while a changed coordinate at rest takes its new value at once
    let foldsShape = foldedParts.contains(.shape)
    let foldsWidth = foldedParts.contains(.width)
    let foldsHeight = foldedParts.contains(.height)
    var shapeGlide = [CGPoint](repeating: .zero, count: foldsShape ? old.count : 0)
    var widthGlide = [CGPoint](repeating: .zero, count: foldsWidth ? old.count : 0)
    var heightGlide = [CGPoint](repeating: .zero, count: foldsHeight ? old.count : 0)
    for index in old.indices {
      let motion = pointMotion(at: index, motions: motions)
      if foldsShape {
        shapeGlide[index] = CGPoint(
          x: motion.shapeMoves.x ? old[index].x - atOldSize[index].x + motion.foldedShape.x : 0,
          y: motion.shapeMoves.y ? old[index].y - atOldSize[index].y + motion.foldedShape.y : 0
        )
      }
      if foldsWidth {
        widthGlide[index] = CGPoint(
          x: atOldSize[index].x - atNewWidth[index].x + motion.foldedWidth.x,
          y: atOldSize[index].y - atNewWidth[index].y + motion.foldedWidth.y
        )
      }
      if foldsHeight {
        heightGlide[index] = CGPoint(
          x: atNewWidth[index].x - new[index].x + motion.foldedHeight.x,
          y: atNewWidth[index].y - new[index].y + motion.foldedHeight.y
        )
      }
    }

    // the folded parts go into the glides, and the rest of a change keeps going in a copy of it, with its timing
    changes = zip(changes, motions).compactMap { change, motion in
      let foldedPartsOfChange = motion.meetsShapeChange ? foldedParts : foldedParts.subtracting(.shape)
      guard motion.remainingFactor != nil, !motion.movedParts.isDisjoint(with: foldedPartsOfChange) else {
        return change
      }
      let keptParts = motion.movedParts.subtracting(foldedPartsOfChange)
      return keptParts.isEmpty ? nil : change.keeping(keptParts)
    }

    // each part glides over the time the changes it continues have left, so it lands when they would have: the shape the
    // changes that meet its change, and the width or the height the changes that move it
    func glideDuration(of part: ChangeParts) -> TimeInterval {
      var duration: TimeInterval = 0
      for motion in motions where part == .shape ? motion.meetsShapeChange : motion.movedParts.contains(part) {
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
      appendGlide(of: parts, shapeGlide: shapeGlide, widthGlide: widthGlide, heightGlide: heightGlide, kinds: newPoints.kinds, duration: duration, at: now)
    }
  }

  /// Adds an ease-out change that glides parts of the path from where they show, see `retarget(from:to:resize:at:)`.
  ///
  /// - Parameters:
  ///   - parts: The parts the change glides.
  ///   - shapeGlide: The glide of the shape's part, point by point, or no points when the shape doesn't glide.
  ///   - widthGlide: The glide of the width's part, point by point, or no points when the width doesn't glide.
  ///   - heightGlide: The glide of the height's part, point by point, or no points when the height doesn't glide.
  ///   - kinds: The kinds of the path's segments.
  ///   - duration: The duration of the glide.
  ///   - now: The layer's current time.
  private mutating func appendGlide(of parts: ChangeParts, shapeGlide: [CGPoint], widthGlide: [CGPoint], heightGlide: [CGPoint], kinds: [CGPathElementType], duration: TimeInterval, at now: TimeInterval) {
    // a glide without a duration shows at once
    guard duration > 0 else {
      return
    }

    // the glide's points come from sums that cancel out where the path shows the new one, which leaves rounding errors
    // instead of zeros, so a part within the tolerance glides nothing
    let tolerance = ComposeUI.Constants.geometryTolerance
    func glide(of part: ChangeParts, _ points: [CGPoint]) -> PathPoints? {
      guard parts.contains(part), points.contains(where: { abs($0.x) > tolerance || abs($0.y) > tolerance }) else {
        return nil
      }
      return PathPoints(kinds: kinds, points: points)
    }
    let shape = glide(of: .shape, shapeGlide)
    let width = glide(of: .width, widthGlide)
    let height = glide(of: .height, heightGlide)

    let offset: PathPoints
    switch (shape, width, height) {
    case (nil, nil, nil):
      return
    case (let part?, nil, nil),
         (nil, let part?, nil),
         (nil, nil, let part?):
      offset = part
    default:
      var sum = [CGPoint](repeating: .zero, count: max(shapeGlide.count, widthGlide.count, heightGlide.count))
      func add(_ part: PathPoints?) {
        guard let part else {
          return
        }
        for index in sum.indices {
          sum[index].x += part.points[index].x
          sum[index].y += part.points[index].y
        }
      }
      add(shape)
      add(width)
      add(height)
      offset = PathPoints(kinds: kinds, points: sum)
    }
    append(offset: offset, widthOffset: width, heightOffset: height, timing: .easeOut(duration: duration), at: now)
  }

  /// The motion of the changes in flight at a point.
  ///
  /// - Parameters:
  ///   - index: The index of the point.
  ///   - motions: The motions of the changes, see `ChangeMotion`.
  /// - Returns: The coordinates the changes' shape parts move, and the parts the folding changes have left.
  private func pointMotion(at index: Int, motions: [ChangeMotion]) -> PointMotion {
    let tolerance = ComposeUI.Constants.geometryTolerance
    var motion = PointMotion()
    for (change, changeMotion) in zip(changes, motions) {
      let (shape, width, height) = change.parts(at: index)
      motion.shapeMoves.x = motion.shapeMoves.x || abs(shape.x) > tolerance
      motion.shapeMoves.y = motion.shapeMoves.y || abs(shape.y) > tolerance
      if let remainingFactor = changeMotion.remainingFactor {
        if changeMotion.meetsShapeChange {
          motion.foldedShape.x += shape.x * remainingFactor
          motion.foldedShape.y += shape.y * remainingFactor
        }
        motion.foldedWidth.x += width.x * remainingFactor
        motion.foldedWidth.y += width.y * remainingFactor
        motion.foldedHeight.x += height.x * remainingFactor
        motion.foldedHeight.y += height.y * remainingFactor
      }
    }
    return motion
  }

  /// Parts of a path's change, which a retarget judges apart, see `retarget(from:to:resize:at:)`.
  fileprivate struct ChangeParts: OptionSet {

    let rawValue: Int

    /// The shape's part.
    static let shape = ChangeParts(rawValue: 1 << 0)

    /// The width's part.
    static let width = ChangeParts(rawValue: 1 << 1)

    /// The height's part.
    static let height = ChangeParts(rawValue: 1 << 2)

    /// The width's and the height's parts.
    static let size: ChangeParts = [.width, .height]

    /// The parts one by one, in the order their glides are recorded.
    static let ordered: [ChangeParts] = [.shape, .width, .height]
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

    /// Whether the change's shape part moves a coordinate that the path's change of shape changes, so a retarget folds
    /// it, or stacks the glide on it for a running spring.
    var meetsShapeChange = false

    init(_ change: Change, at now: TimeInterval) {
      neverFinishes = CAAnimation.neverFinishes(duration: change.curve.duration)
      let isRunningSpring = change.animation is CASpringAnimation && !neverFinishes && change.speed > 0 && change.beginTime <= now
      remainingFactor = isRunningSpring ? nil : change.remainingFactor(at: 0, now: now)
      remainingTime = change.remainingTime(at: now) ?? 0

      let tolerance = ComposeUI.Constants.geometryTolerance
      var movedParts: ChangeParts = []
      for index in change.offset.points.indices {
        let (shape, width, height) = change.parts(at: index)
        if abs(shape.x) > tolerance || abs(shape.y) > tolerance {
          movedParts.insert(.shape)
        }
        if abs(width.x) > tolerance || abs(width.y) > tolerance {
          movedParts.insert(.width)
        }
        if abs(height.x) > tolerance || abs(height.y) > tolerance {
          movedParts.insert(.height)
        }
      }
      self.movedParts = movedParts
    }
  }

  /// The motion of the changes in flight at a point, see `pointMotion(at:motions:)`.
  private struct PointMotion {

    /// The coordinates the shape's parts of the changes move.
    var shapeMoves = (x: false, y: false)

    /// The part of the shape's parts that the changes folding their shape have left, see `ChangeMotion.meetsShapeChange`.
    var foldedShape = CGPoint.zero

    /// The part of the width's parts that the folding changes have left.
    var foldedWidth = CGPoint.zero

    /// The part of the height's parts that the folding changes have left.
    var foldedHeight = CGPoint.zero
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
