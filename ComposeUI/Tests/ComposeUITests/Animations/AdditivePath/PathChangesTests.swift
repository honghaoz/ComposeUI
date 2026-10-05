//
//  PathChangesTests.swift
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

import ChouTiTest

@_spi(Private) @testable import ComposeUI

class PathChangesTests: XCTestCase {

  // MARK: - Record

  func test_record() throws {
    // given: no changes in flight
    var changes = PathChanges()

    // when: recording a change from a rect to an inset rect
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .easeIn(duration: 2), at: 100)

    // then: the change is the rect minus the inset rect, point by point, timed by the timing, and it begins now
    expect(changes.changes.count) == 1
    let change = try changes.changes.first.unwrap()
    expect(change.offset) == PathPoints(rect(inset: 0)).subtracting(PathPoints(rect(inset: 10)))
    expect(change.animation.duration) == 2
    expect(change.animation.timingFunction) == CAMediaTimingFunction(name: .easeIn)
    expect(change.curve.duration) == 2
    expect(change.speed) == 1
    expect(change.beginTime) == 100
  }

  func test_record_delayedChange_beginsAfterTheDelay() throws {
    // given: no changes in flight
    var changes = PathChanges()

    // when: recording a change with a delay
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1, delay: 0.5), at: 100)

    // then: the change begins after the delay, and its animation's begin time stays unset, since the change keeps it
    let change = try changes.changes.first.unwrap()
    expect(change.beginTime) == 100.5
    expect(change.animation.beginTime) == 0
  }

  func test_record_negativeDelay_beginsNow() {
    // given: no changes in flight
    var changes = PathChanges()

    // when: recording changes with negative delays, a negative infinity included, which `AnimationTiming` keeps
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1, delay: -0.5), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .linear(duration: 1, delay: -.infinity), at: 100)

    // then: the changes begin now, as without a delay, instead of in the past
    expect(changes.changes.map(\.beginTime)) == [100, 100]
  }

  func test_record_atTimeZero_beginsAtTheLeastPositiveTime() throws {
    // given: no changes in flight
    var changes = PathChanges()

    // when: recording a linear change over one second at a layer time of zero, as a paused layer's can be
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1), at: 0)

    // then: the change begins at the least positive time instead of zero, which Core Animation takes as unset, so half
    // a second later it's halfway
    let change = try changes.changes.first.unwrap()
    expect(change.beginTime) == .leastNormalMagnitude
    expect(change.remainingTime(at: 0.5)) == 0.5
    expect(change.remainingFactor(at: 0, now: 0.5)) == 0.5

    // then: so are its keyframes, which start halfway and last the half second left
    let path = rect(inset: 10)
    let keyframes = changes.keyframes(adding: path, points: PathPoints(path), at: 0.5)
    expect(keyframes.duration) == 0.5
    expect(keyframes.keyTimes) == nil
    expect(keyframes.paths[0].maxPointDistance(to: rect(inset: 5))) < 1e-9
  }

  func test_record_zeroDuration() throws {
    // given: no changes in flight
    var changes = PathChanges()

    // when: recording a change with a zero duration
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 0), at: 100)

    // then: no change is recorded, so the new path shows at once
    expect(changes.isEmpty) == true

    // when: recording a change with a zero duration and a delay
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 0, delay: 1), at: 100)

    // then: the change snaps after the delay, in less than a frame
    let change = try changes.changes.first.unwrap()
    expect(change.animation.duration) > 0
    expect(change.animation.duration) < 1.0 / 60
    expect(change.curve.duration) == change.animation.duration
    expect(change.beginTime) == 101
  }

  func test_record_samePointsBuiltAnotherWay_recordsNothing() {
    // given: no changes in flight, and a rect built from its segments, which isn't equal to the rect path
    var changes = PathChanges()
    let builtRect = CGMutablePath()
    builtRect.move(to: CGPoint(x: 0, y: 0))
    builtRect.addLine(to: CGPoint(x: 100, y: 0))
    builtRect.addLine(to: CGPoint(x: 100, y: 50))
    builtRect.addLine(to: CGPoint(x: 0, y: 50))
    builtRect.closeSubpath()
    expect(builtRect == rect(inset: 0)) == false

    // when: recording a change from the rect path to the built rect
    changes.record(from: rect(inset: 0), to: builtRect, timing: .linear(duration: 1), at: 100)

    // then: the points are the same, so no change is recorded
    expect(changes.isEmpty) == true
  }

  func test_record_otherSegments_dropsTheChanges() {
    // given: a change in flight
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1), at: 100)

    // when: recording a change from the inset rect to a rounded rect
    changes.record(from: rect(inset: 10), to: roundedRect(), timing: .linear(duration: 1), at: 100)

    // then: the points of the paths don't line up, so the changes are dropped
    expect(changes.isEmpty) == true
  }

  func test_record_pointsNotFinite_dropsTheChanges() {
    // given: a change in flight, and the path of a null rect, whose points are at infinity
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1), at: 100)
    let nullRect = CGPath(rect: .null, transform: nil)

    // when: recording a change to the null rect
    changes.record(from: rect(inset: 10), to: nullRect, timing: .linear(duration: 1), at: 100)

    // then: the points don't blend, so the changes are dropped
    expect(changes.isEmpty) == true

    // when: a change is in flight, and a change is recorded from the null rect
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1), at: 100)
    changes.record(from: nullRect, to: rect(inset: 20), timing: .linear(duration: 1), at: 100)

    // then: the changes are dropped too
    expect(changes.isEmpty) == true
  }

  func test_record_resize_keepsTheWidthsAndTheHeightsParts() throws {
    // given: no changes in flight
    var changes = PathChanges()

    // when: recording a change from a rounded rect of 100 by 50 points with a corner radius of 5 to the rounded rect with
    // a corner radius of 10 for 200 by 80 points
    changes.record(from: roundedRect(width: 100, radius: 5), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 200, height: 80), path: { roundedRect(size: $0, radius: 10) }, timing: .linear(duration: 1), at: 100)

    // then: the change keeps the width's part, from the new shape at the old size to the new width, and the height's
    // part, from there to the new path
    let change = try changes.changes.first.unwrap()
    expect(change.offset) == PathPoints(roundedRect(width: 100, radius: 5)).subtracting(PathPoints(roundedRect(size: CGSize(width: 200, height: 80), radius: 10)))
    expect(change.widthOffset) == PathPoints(roundedRect(width: 100, radius: 10)).subtracting(PathPoints(roundedRect(width: 200, radius: 10)))
    expect(change.heightOffset) == PathPoints(roundedRect(width: 200, radius: 10)).subtracting(PathPoints(roundedRect(size: CGSize(width: 200, height: 80), radius: 10)))
  }

  func test_record_resizeOfOneDimension_isThatDimensionsPart() {
    // given: no changes in flight
    var changes = PathChanges()

    // when: recording a rect widening from 100 to 200 points, and then growing from 50 to 100 points high
    changes.record(from: rect(width: 100, height: 50), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 200, height: 50), path: rect(size:), timing: .linear(duration: 1), at: 100)
    changes.record(from: rect(width: 200, height: 50), resizingFrom: CGSize(width: 200, height: 50), to: CGSize(width: 200, height: 100), path: rect(size:), timing: .linear(duration: 1), at: 100)

    // then: each change is all the part of the dimension that changed
    expect(changes.changes.count) == 2
    let widthChange = changes.changes[0]
    expect(widthChange.widthOffset) == widthChange.offset
    expect(widthChange.heightOffset) == nil
    let heightChange = changes.changes[1]
    expect(heightChange.widthOffset) == nil
    expect(heightChange.heightOffset) == heightChange.offset
  }

  func test_record_resizeCanceledByAShapeChange_isAChange() throws {
    // given: no changes in flight
    var changes = PathChanges()

    // when: recording a change of a rect as wide as a size plus an extension, from 100 points wide with an extension of
    // 200 to 300 points wide without one, which leaves the path 300 points wide
    changes.record(from: extendedRect(CGSize(width: 100, height: 50), by: 200), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 300, height: 50), path: { extendedRect($0, by: 0) }, timing: .linear(duration: 1), at: 100)

    // then: the change has no offset, but it keeps the resize that the shape's change cancels out
    let change = try changes.changes.first.unwrap()
    expect(change.offset.isZero) == true
    expect(change.widthOffset) == PathPoints(rect(width: 100, height: 50)).subtracting(PathPoints(rect(width: 300, height: 50)))
    expect(change.heightOffset) == nil
  }

  func test_record_withoutAResize_isAllTheShapes() {
    // given: no changes in flight
    var changes = PathChanges()

    // when: recording changes of a rounded rect's corner radius, with the paths for the sizes between at its own size,
    // and without them
    changes.record(from: roundedRect(radius: 5), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 100, height: 50), path: { roundedRect(size: $0, radius: 10) }, timing: .linear(duration: 1), at: 100)
    changes.record(from: roundedRect(radius: 10), to: roundedRect(radius: 15), timing: .linear(duration: 1), at: 100)

    // then: the changes have no width's or height's part, so they're all the shape's
    expect(changes.changes.count) == 2
    expect(changes.changes.allSatisfy { $0.widthOffset == nil && $0.heightOffset == nil }) == true
  }

  func test_record_resizeThatDoesntLineUp_isAllTheShapes() {
    // given: a rect widening from 100 to 200 points, and points between of a rounded rect, which has other segments, and
    // of the null rect, which aren't finite, in place of each of the paths between
    let oldPoints = PathPoints(rect(width: 100, height: 50))
    let newPoints = PathPoints(rect(width: 200, height: 50))
    let otherSegments = PathPoints(roundedRect())
    let notFinite = PathPoints(CGPath(rect: .null, transform: nil))
    let resizes = [
      PathChanges.Resize(atOldSize: otherSegments, atNewWidth: newPoints),
      PathChanges.Resize(atOldSize: oldPoints, atNewWidth: otherSegments),
      PathChanges.Resize(atOldSize: notFinite, atNewWidth: newPoints),
      PathChanges.Resize(atOldSize: oldPoints, atNewWidth: notFinite),
    ]

    for resize in resizes {
      // when: recording the change with the points between
      var changes = PathChanges()
      changes.record(from: oldPoints, to: newPoints, resize: resize, timing: .linear(duration: 1), at: 100)

      // then: the points don't tell the parts apart, so the change is all the shape's
      expect(changes.changes.count) == 1
      expect(changes.changes.first?.widthOffset) == nil
      expect(changes.changes.first?.heightOffset) == nil
    }
  }

  // MARK: - Retarget

  func test_retarget_shapeChangeWithoutShapeMotion_keepsTheChanges() throws {
    // given: a rounded rect widening from 100 to 200 points over 4 seconds from 100
    var changes = PathChanges()
    changes.record(from: roundedRect(width: 100), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 200, height: 50), path: { roundedRect(size: $0) }, timing: .linear(duration: 4), at: 100)
    let resize = try changes.changes.first.unwrap()

    // when: retargeting to a corner radius of 10 at the resize's width a second in
    changes.retarget(from: roundedRect(width: 200), to: roundedRect(width: 200, radius: 10), at: 101)

    // then: no change of the shape is in flight, so the corner radius shows at once, and the resize keeps going as it is
    expect(changes.changes.count) == 1
    expect(changes.changes.first?.offset) == resize.offset
    expect(changes.changes.first?.animation) === resize.animation
  }

  func test_retarget_resizeWithoutResizeMotion_keepsTheChanges() throws {
    // given: a rounded rect, 100 points wide, whose corner radius goes from 5 to 15 over 4 seconds from 100
    var changes = PathChanges()
    changes.record(from: roundedRect(radius: 5), to: roundedRect(radius: 15), timing: .linear(duration: 4), at: 100)
    let shapeChange = try changes.changes.first.unwrap()

    // when: retargeting to 200 points wide a second in
    changes.retarget(from: roundedRect(radius: 15), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 200, height: 50), path: { roundedRect(size: $0, radius: 15) }, at: 101)

    // then: no resize is in flight, so the width shows at once, and the change of the corner radius keeps going as it is
    expect(changes.changes.count) == 1
    expect(changes.changes.first?.offset) == shapeChange.offset
    expect(changes.changes.first?.animation) === shapeChange.animation
  }

  func test_retarget_widthChangeDuringResizeOfBothAxes_keepsTheHeightInACopy() throws {
    // given: a rect growing from 100 by 50 to 200 by 100 points over 4 seconds from 100
    var changes = PathChanges()
    changes.record(from: rect(width: 100, height: 50), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 200, height: 100), path: rect(size:), timing: .linear(duration: 4), at: 100)
    let resize = try changes.changes.first.unwrap()

    // when: retargeting to 150 points wide at the resize's height a second in
    changes.retarget(from: rect(width: 200, height: 100), resizingFrom: CGSize(width: 200, height: 100), to: CGSize(width: 150, height: 100), path: rect(size:), at: 101)

    // then: the height, which didn't change, keeps the resize's motion in a copy of it, with its timing
    expect(changes.changes.count) == 2
    let heightResize = changes.changes[0]
    expect(heightResize.offset) == PathPoints(rect(width: 200, height: 50)).subtracting(PathPoints(rect(width: 200, height: 100)))
    expect(heightResize.widthOffset) == nil
    expect(heightResize.heightOffset) == heightResize.offset
    expect(heightResize.animation) === resize.animation
    expect(heightResize.beginTime) == 100

    // then: the width glides from the 125 points shown over the 3 seconds the resize had left
    let widthGlide = changes.changes[1]
    expect(widthGlide.offset) == PathPoints(rect(width: 125, height: 100)).subtracting(PathPoints(rect(width: 150, height: 100)))
    expect(widthGlide.widthOffset) == widthGlide.offset
    expect(widthGlide.heightOffset) == nil
    expect(widthGlide.curve.duration) == 3
    expect(widthGlide.animation.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(widthGlide.beginTime) == 101
  }

  func test_retarget_resizeAndShapeChange_shapeChange_keepsTheResizeInACopy() throws {
    // given: a rounded rect widening from 100 to 200 points while its corner radius goes from 5 to 15, over 4 seconds
    // from 100, in one change
    var changes = PathChanges()
    changes.record(from: roundedRect(width: 100, radius: 5), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 200, height: 50), path: { roundedRect(size: $0, radius: 15) }, timing: .linear(duration: 4), at: 100)
    let change = try changes.changes.first.unwrap()

    // when: retargeting to a corner radius of 25 at the change's width a second in
    changes.retarget(from: roundedRect(width: 200, radius: 15), to: roundedRect(width: 200, radius: 25), at: 101)

    // then: the resize keeps going in a copy of the change, with its timing
    expect(changes.changes.count) == 2
    let resize = changes.changes[0]
    let widthOffset = try change.widthOffset.unwrap()
    expect(isPoints(resize.offset, closeTo: widthOffset)) == true
    expect(resize.widthOffset) == widthOffset
    expect(resize.heightOffset) == nil
    expect(resize.animation) === change.animation

    // then: the corner radius glides from the 7.5 shown to 25 over the 3 seconds the change had left, as a change of
    // the shape
    let shapeGlide = changes.changes[1]
    let expectedOffset = PathPoints(roundedRect(width: 200, radius: 7.5)).subtracting(PathPoints(roundedRect(width: 200, radius: 25)))
    expect(isPoints(shapeGlide.offset, closeTo: expectedOffset)) == true
    expect(shapeGlide.widthOffset) == nil
    expect(shapeGlide.heightOffset) == nil
    expect(shapeGlide.curve.duration) == 3
  }

  func test_retarget_resizeAndShapeChange_resize_keepsTheShapeChangeInACopy() throws {
    // given: a rounded rect widening from 100 to 200 points while its corner radius goes from 5 to 15, over 4 seconds
    // from 100, in one change
    var changes = PathChanges()
    changes.record(from: roundedRect(width: 100, radius: 5), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 200, height: 50), path: { roundedRect(size: $0, radius: 15) }, timing: .linear(duration: 4), at: 100)
    let change = try changes.changes.first.unwrap()

    // when: retargeting to 150 points wide at the change's corner radius a second in
    changes.retarget(from: roundedRect(width: 200, radius: 15), resizingFrom: CGSize(width: 200, height: 50), to: CGSize(width: 150, height: 50), path: { roundedRect(size: $0, radius: 15) }, at: 101)

    // then: the change of the corner radius keeps going in a copy of the change, with its timing
    expect(changes.changes.count) == 2
    let shapeChange = changes.changes[0]
    expect(shapeChange.offset) == change.offset.subtracting(try change.widthOffset.unwrap())
    expect(shapeChange.widthOffset) == nil
    expect(shapeChange.heightOffset) == nil
    expect(shapeChange.animation) === change.animation

    // then: the width glides from the 125 points shown over the 3 seconds the change had left, as a change of the width
    let widthGlide = changes.changes[1]
    let expectedOffset = PathPoints(roundedRect(width: 125, radius: 15)).subtracting(PathPoints(roundedRect(width: 150, radius: 15)))
    expect(isPoints(widthGlide.offset, closeTo: expectedOffset)) == true
    expect(widthGlide.widthOffset) == widthGlide.offset
    expect(widthGlide.curve.duration) == 3
  }

  func test_retarget_shapeChangeOfOneEdge_keepsTheOtherEdgesChange() throws {
    // given: a rect whose left edge moves from 0 to 20 over 2 seconds, and whose right edge moves from 100 to 80 over 8
    // seconds, both from 100, in changes of their own
    var changes = PathChanges()
    changes.record(from: rect(left: 0, right: 100), to: rect(left: 20, right: 100), timing: .linear(duration: 2), at: 100)
    changes.record(from: rect(left: 20, right: 100), to: rect(left: 20, right: 80), timing: .linear(duration: 8), at: 100)
    let rightEdgeChange = changes.changes[1]

    // when: retargeting the left edge to 30 a second in
    changes.retarget(from: rect(left: 20, right: 80), to: rect(left: 30, right: 80), at: 101)

    // then: the right edge's change, which doesn't move a changed point, keeps going as it is
    expect(changes.changes.count) == 2
    let keptChange = try changes.changes.first.unwrap()
    expect(keptChange.offset) == rightEdgeChange.offset
    expect(keptChange.animation) === rightEdgeChange.animation

    // then: the left edge glides from the 10 shown to 30 over the second its change had left, instead of the right edge's
    // 7 seconds
    let glide = try changes.changes.last.unwrap()
    expect(glide.offset) == PathPoints(rect(left: 10, right: 80)).subtracting(PathPoints(rect(left: 30, right: 80)))
    expect(glide.curve.duration) == 1
  }

  func test_retarget_shapeChangeOfOneEdge_foldsTheWholeChangeThatMovesIt() throws {
    // given: a rect whose left edge moves from 0 to 20 and whose right edge moves from 100 to 80 over 4 seconds from 100,
    // in one change
    var changes = PathChanges()
    changes.record(from: rect(left: 0, right: 100), to: rect(left: 20, right: 80), timing: .linear(duration: 4), at: 100)

    // when: retargeting the left edge to 30 a second in
    changes.retarget(from: rect(left: 20, right: 80), to: rect(left: 30, right: 80), at: 101)

    // then: the change moves the changed left edge, so it folds whole, its right edge too, as the points of a change move
    // together: both edges glide from where they show, 5 and 95, over the 3 seconds it had left
    expect(changes.changes.count) == 1
    let glide = try changes.changes.first.unwrap()
    expect(glide.offset) == PathPoints(rect(left: 5, right: 95)).subtracting(PathPoints(rect(left: 30, right: 80)))
    expect(glide.curve.duration) == 3
  }

  func test_retarget_axesOfDifferentRemainingTimes_glideApart() throws {
    // given: a rect widening from 100 to 200 points over 2 seconds, and growing from 50 to 100 points high over 4
    // seconds, both from 100
    var changes = PathChanges()
    changes.record(from: rect(width: 100, height: 50), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 200, height: 50), path: rect(size:), timing: .linear(duration: 2), at: 100)
    changes.record(from: rect(width: 200, height: 50), resizingFrom: CGSize(width: 200, height: 50), to: CGSize(width: 200, height: 100), path: rect(size:), timing: .linear(duration: 4), at: 100)

    // when: retargeting to 120 by 75 points a second in
    changes.retarget(from: rect(width: 200, height: 100), resizingFrom: CGSize(width: 200, height: 100), to: CGSize(width: 120, height: 75), path: rect(size:), at: 101)

    // then: each dimension glides from where it shows over the time its change had left: the width from 150 points over
    // a second, and the height from 62.5 points over 3 seconds
    expect(changes.changes.count) == 2
    let widthGlide = changes.changes[0]
    expect(widthGlide.offset) == PathPoints(rect(width: 150, height: 75)).subtracting(PathPoints(rect(width: 120, height: 75)))
    expect(widthGlide.widthOffset) == widthGlide.offset
    expect(widthGlide.curve.duration) == 1
    let heightGlide = changes.changes[1]
    expect(heightGlide.offset) == PathPoints(rect(width: 120, height: 62.5)).subtracting(PathPoints(rect(width: 120, height: 75)))
    expect(heightGlide.heightOffset) == heightGlide.offset
    expect(heightGlide.curve.duration) == 3
  }

  func test_retarget_axesLandingTogether_glideInOneChange() throws {
    // given: a rect growing from 100 by 50 to 200 by 100 points over 4 seconds from 100
    var changes = PathChanges()
    changes.record(from: rect(width: 100, height: 50), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 200, height: 100), path: rect(size:), timing: .linear(duration: 4), at: 100)

    // when: retargeting to 150 by 80 points a second in
    changes.retarget(from: rect(width: 200, height: 100), resizingFrom: CGSize(width: 200, height: 100), to: CGSize(width: 150, height: 80), path: rect(size:), at: 101)

    // then: both dimensions glide from the 125 by 62.5 points shown over the 3 seconds left, in one change that keeps
    // the parts of each apart
    expect(changes.changes.count) == 1
    let glide = try changes.changes.first.unwrap()
    expect(glide.offset) == PathPoints(rect(width: 125, height: 62.5)).subtracting(PathPoints(rect(width: 150, height: 80)))
    expect(glide.widthOffset) == PathPoints(rect(width: 125, height: 80)).subtracting(PathPoints(rect(width: 150, height: 80)))
    expect(glide.heightOffset) == PathPoints(rect(width: 150, height: 62.5)).subtracting(PathPoints(rect(width: 150, height: 80)))
    expect(glide.curve.duration) == 3
  }

  func test_retarget_widthChange_keepsTheHeightsMotionAlongX() throws {
    // given: a square as high as a size at the size's right edge, so its left edge moves with the height too, growing
    // from 100 by 100 to 400 by 400 points over 2 seconds from 100
    var changes = PathChanges()
    changes.record(from: rightSquare(CGSize(width: 100, height: 100)), resizingFrom: CGSize(width: 100, height: 100), to: CGSize(width: 400, height: 400), path: rightSquare(_:), timing: .linear(duration: 2), at: 100)
    let resize = try changes.changes.first.unwrap()

    // when: retargeting to 300 points wide a second in
    changes.retarget(from: rightSquare(CGSize(width: 400, height: 400)), resizingFrom: CGSize(width: 400, height: 400), to: CGSize(width: 300, height: 400), path: rightSquare(_:), at: 101)

    // then: the height keeps its motion in a copy of the resize, its motion along x too, so the square stays as wide as
    // it is high
    expect(changes.changes.count) == 2
    let heightResize = changes.changes[0]
    expect(heightResize.offset) == resize.heightOffset
    expect(heightResize.heightOffset) == resize.heightOffset
    expect(heightResize.animation) === resize.animation

    // then: the width glides from the 250 points shown over the second the resize had left
    let widthGlide = changes.changes[1]
    expect(widthGlide.offset) == PathPoints(rightSquare(CGSize(width: 250, height: 400))).subtracting(PathPoints(rightSquare(CGSize(width: 300, height: 400))))
    expect(widthGlide.widthOffset) == widthGlide.offset
    expect(widthGlide.curve.duration) == 1
  }

  func test_retarget_resizeCanceledByAShapeChange_glidesTheResize() throws {
    // given: a rect as wide as a size plus an extension, widening from 100 to 300 points over 2 seconds from 100
    var changes = PathChanges()
    changes.record(from: rect(width: 100, height: 50), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 300, height: 50), path: { extendedRect($0, by: 0) }, timing: .linear(duration: 2), at: 100)

    // when: retargeting half a second in to 200 points wide with an extension of 100, which leaves the path 300 points
    // wide
    changes.retarget(from: rect(width: 300, height: 50), resizingFrom: CGSize(width: 300, height: 50), to: CGSize(width: 200, height: 50), path: { extendedRect($0, by: 100) }, at: 100.5)

    // then: the extension shows at once, and the width glides from the 150 points shown over the 1.5 seconds left, so
    // the path glides from 250 points wide
    expect(changes.changes.count) == 1
    let glide = try changes.changes.first.unwrap()
    expect(glide.offset) == PathPoints(rect(width: 250, height: 50)).subtracting(PathPoints(rect(width: 300, height: 50)))
    expect(glide.widthOffset) == glide.offset
    expect(glide.curve.duration) == 1.5
  }

  func test_retarget_changeThatNeverFinishes_foldsWhole() throws {
    // given: a rect springing from 100 by 50 to 200 by 100 points without damping from 100, so it bounces forever
    var changes = PathChanges()
    changes.record(from: rect(width: 100, height: 50), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 200, height: 100), path: rect(size:), timing: .spring(dampingRatio: 0, response: 0.5), at: 100)
    let spring = try changes.changes.first.unwrap()
    let remainingFactor = spring.remainingFactor(at: 0, now: 100.3)
    expect(remainingFactor) != 0

    // when: retargeting to 150 points wide at the spring's height 0.3 seconds in
    changes.retarget(from: rect(width: 200, height: 100), resizingFrom: CGSize(width: 200, height: 100), to: CGSize(width: 150, height: 100), path: rect(size:), at: 100.3)

    // then: the spring can't keep going next to a glide, so it folds whole, its height too, into a glide from where the
    // rect shows over the default duration
    expect(changes.changes.count) == 1
    let glide = try changes.changes.first.unwrap()
    let shownWidth = 200 - 100 * remainingFactor
    let shownHeight = 100 - 50 * remainingFactor
    let expectedOffset = PathPoints(rect(width: shownWidth, height: shownHeight)).subtracting(PathPoints(rect(width: 150, height: 100)))
    expect(isPoints(glide.offset, closeTo: expectedOffset)) == true
    expect(glide.curve.duration) == Animations.defaultAnimationDuration
  }

  func test_retarget_shapeChangeDuringResizeThatNeverFinishes_keepsTheResizeGoing() throws {
    // given: a rounded rect springing from 100 to 300 points wide while its corner radius goes from 12 to 24, without
    // damping from 100, so it bounces forever
    var changes = PathChanges()
    changes.record(from: roundedRect(width: 100, radius: 12), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 300, height: 50), path: { roundedRect(size: $0, radius: 24) }, timing: .spring(dampingRatio: 0, response: 1.6), at: 100)
    let spring = try changes.changes.first.unwrap()

    // when: retargeting to a corner radius of 36 at the spring's width 0.3 seconds in
    changes.retarget(from: roundedRect(width: 300, radius: 24), to: roundedRect(width: 300, radius: 36), at: 100.3)

    // then: folding the spring would stop its resize, which a frame on the same spring keeps, so the spring keeps going
    // as it is, and the corner radius shows at once
    expect(changes.changes.count) == 1
    expect(changes.changes.first?.offset) == spring.offset
    expect(changes.changes.first?.animation) === spring.animation
  }

  func test_retarget_landedChange_showsTheNewPathAtOnce() {
    // given: a rect widening from 100 to 200 points over a second from 100, which has landed by 102
    var changes = PathChanges()
    changes.record(from: rect(width: 100, height: 50), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 200, height: 50), path: rect(size:), timing: .linear(duration: 1), at: 100)

    // when: retargeting to 150 points wide at 102
    changes.retarget(from: rect(width: 200, height: 50), resizingFrom: CGSize(width: 200, height: 50), to: CGSize(width: 150, height: 50), path: rect(size:), at: 102)

    // then: the change has no motion left to glide from, so the new path shows at once
    expect(changes.isEmpty) == true
  }

  func test_retarget_toThePathShown_needsNoGlide() {
    // given: a rect widening from 100 to 200 points over 4 seconds from 100
    var changes = PathChanges()
    changes.record(from: rect(width: 100, height: 50), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 200, height: 50), path: rect(size:), timing: .linear(duration: 4), at: 100)

    // when: retargeting to the 125 points shown a second in
    changes.retarget(from: rect(width: 200, height: 50), resizingFrom: CGSize(width: 200, height: 50), to: CGSize(width: 125, height: 50), path: rect(size:), at: 101)

    // then: the path already shows the new path, so the change folds without a glide
    expect(changes.isEmpty) == true
  }

  func test_retarget_resizeThatDoesntLineUp_makesTheChangeAllTheShapes() throws {
    // given: a rect widening from 100 to 200 points over 4 seconds from 100
    var changes = PathChanges()
    changes.record(from: rect(width: 100, height: 50), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 200, height: 50), path: rect(size:), timing: .linear(duration: 4), at: 100)
    let resize = try changes.changes.first.unwrap()
    let oldPoints = PathPoints(rect(width: 200, height: 50))
    let newPoints = PathPoints(rect(width: 150, height: 50))

    // when: retargeting to 150 points wide a second in, with points between of other segments, and of points that
    // aren't finite
    var otherSegments = changes
    otherSegments.retarget(from: oldPoints, to: newPoints, resize: PathChanges.Resize(atOldSize: PathPoints(roundedRect()), atNewWidth: newPoints), at: 101)
    var notFinite = changes
    notFinite.retarget(from: oldPoints, to: newPoints, resize: PathChanges.Resize(atOldSize: oldPoints, atNewWidth: PathPoints(CGPath(rect: .null, transform: nil))), at: 101)

    // then: the points don't tell the parts apart, so the change is all the shape's, and no change of the shape is in
    // flight, so the new width shows at once and the resize keeps going as it is
    for retargeted in [otherSegments, notFinite] {
      expect(retargeted.changes.count) == 1
      expect(retargeted.changes.first?.offset) == resize.offset
      expect(retargeted.changes.first?.animation) === resize.animation
    }
  }

  func test_retarget_shapeAndResizeLandingTogether_glideInOneChange() throws {
    // given: a rounded rect widening from 100 to 200 points while its corner radius goes from 5 to 15, over 4 seconds
    // from 100, in one change
    var changes = PathChanges()
    changes.record(from: roundedRect(width: 100, radius: 5), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 200, height: 50), path: { roundedRect(size: $0, radius: 15) }, timing: .linear(duration: 4), at: 100)

    // when: retargeting to 150 points wide with a corner radius of 25 a second in
    changes.retarget(from: roundedRect(width: 200, radius: 15), resizingFrom: CGSize(width: 200, height: 50), to: CGSize(width: 150, height: 50), path: { roundedRect(size: $0, radius: 25) }, at: 101)

    // then: both parts glide from where they show, 125 points wide with a corner radius of 7.5, over the 3 seconds the
    // change had left, in one change that keeps the width's part apart
    expect(changes.changes.count) == 1
    let glide = try changes.changes.first.unwrap()
    let expectedOffset = PathPoints(roundedRect(width: 125, radius: 7.5)).subtracting(PathPoints(roundedRect(width: 150, radius: 25)))
    expect(isPoints(glide.offset, closeTo: expectedOffset)) == true
    let expectedWidthOffset = PathPoints(roundedRect(width: 125, radius: 25)).subtracting(PathPoints(roundedRect(width: 150, radius: 25)))
    expect(try isPoints(glide.widthOffset.unwrap(), closeTo: expectedWidthOffset)) == true
    expect(glide.heightOffset) == nil
    expect(glide.curve.duration) == 3
  }

  func test_retarget_shapeGlideWithoutASizeGlide_isAChangeOfTheShape() throws {
    // given: a rounded rect widening from 100 to 200 points while its corner radius goes from 5 to 15, over 4 seconds
    // from 100, in one change
    var changes = PathChanges()
    changes.record(from: roundedRect(width: 100, radius: 5), resizingFrom: CGSize(width: 100, height: 50), to: CGSize(width: 200, height: 50), path: { roundedRect(size: $0, radius: 15) }, timing: .linear(duration: 4), at: 100)

    // when: retargeting a second in to a corner radius of 25 at the 125 points shown
    changes.retarget(from: roundedRect(width: 200, radius: 15), resizingFrom: CGSize(width: 200, height: 50), to: CGSize(width: 125, height: 50), path: { roundedRect(size: $0, radius: 25) }, at: 101)

    // then: both parts fold into one glide, as they land together, and the width shows where it is, so the glide is a
    // change of the shape alone, from the 7.5 corner radius shown
    expect(changes.changes.count) == 1
    let glide = try changes.changes.first.unwrap()
    let expectedOffset = PathPoints(roundedRect(width: 125, radius: 7.5)).subtracting(PathPoints(roundedRect(width: 125, radius: 25)))
    expect(isPoints(glide.offset, closeTo: expectedOffset)) == true
    expect(glide.widthOffset) == nil
    expect(glide.heightOffset) == nil
    expect(glide.curve.duration) == 3
  }

  // MARK: - Remove Landed Changes

  func test_removeLandedChanges() {
    // given: changes of one, two and three seconds, recorded two seconds ago, and a delayed change that hasn't begun
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 5), timing: .linear(duration: 1), at: 98)
    changes.record(from: rect(inset: 5), to: rect(inset: 10), timing: .linear(duration: 2), at: 98)
    changes.record(from: rect(inset: 10), to: rect(inset: 15), timing: .linear(duration: 3), at: 98)
    changes.record(from: rect(inset: 15), to: rect(inset: 20), timing: .linear(duration: 0.5, delay: 1), at: 100)

    // when: removing the changes that have landed
    changes.removeLandedChanges(at: 100)

    // then: the change of one second and the change of two seconds, which lands now, are removed, and the change of
    // three seconds and the delayed change are kept
    expect(changes.changes.map(\.curve.duration)) == [3, 0.5]
  }

  // MARK: - State

  func test_remainingTime() {
    // given: no changes in flight
    var changes = PathChanges()

    // then: no time remains
    expect(changes.remainingTime(at: 100)) == 0

    // when: a change that ended a second ago, which no update has removed yet
    changes.record(from: rect(inset: 0), to: rect(inset: 5), timing: .linear(duration: 1, delay: 1), at: 97)

    // then: the ended change leaves no time
    expect(changes.remainingTime(at: 100)) == 0

    // when: a delayed change of two seconds, and a change of one second beginning now
    changes.record(from: rect(inset: 5), to: rect(inset: 10), timing: .linear(duration: 2, delay: 0.5), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 15), timing: .linear(duration: 1), at: 100)

    // then: the longest time left remains
    expect(changes.remainingTime(at: 100)) == 2.5
  }

  func test_hasSameSegments() {
    // given: no changes in flight
    var changes = PathChanges()

    // then: any path takes the offsets, as there are none
    expect(changes.hasSameSegments(as: PathPoints(roundedRect()))) == true

    // when: a change between rects, and a change between rounded rects, as when the path was set behind their backs
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1), at: 100)
    changes.record(from: roundedRect(), to: roundedRect(radius: 10), timing: .linear(duration: 1), at: 100)

    // then: a path only takes the offsets when it has the segments of every change
    expect(changes.changes.count) == 2
    expect(changes.hasSameSegments(as: PathPoints(rect(inset: 20)))) == false
    expect(changes.hasSameSegments(as: PathPoints(roundedRect()))) == false
  }

  // MARK: - Remaining Factor

  func test_remainingFactor() throws {
    // given: a linear change over one second, beginning now
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1), at: 100)
    let change = try changes.changes.first.unwrap()

    // then: all of the offset is left at the start, half of it in the middle, and none at the end
    expect(change.remainingFactor(at: 0, now: 100)) == 1
    expect(change.remainingFactor(at: 0.5, now: 100)) == 0.5
    expect(change.remainingFactor(at: 1, now: 100)) == 0
  }

  func test_remainingFactor_begunChange_isMeasuredFromItsBegin() throws {
    // given: a linear change over one second that began a quarter second ago
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1), at: 99.75)
    let change = try changes.changes.first.unwrap()

    // then: three quarters of the offset are left now, a quarter half a second later, and none once the change lands
    expect(change.remainingFactor(at: 0, now: 100)) == 0.75
    expect(change.remainingFactor(at: 0.5, now: 100)) == 0.25
    expect(change.remainingFactor(at: 0.75, now: 100)) == 0
  }

  func test_remainingFactor_delayedChange_holdsTheOffsetUntilItBegins() throws {
    // given: a linear change over one second with a delay of half a second
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1, delay: 0.5), at: 100)
    let change = try changes.changes.first.unwrap()

    // then: all of the offset is left until the change begins, then it runs out over the duration
    expect(change.remainingFactor(at: 0, now: 100)) == 1
    expect(change.remainingFactor(at: 0.5, now: 100)) == 1
    expect(change.remainingFactor(at: 1, now: 100)) == 0.5
    expect(change.remainingFactor(at: 1.5, now: 100)) == 0
  }

  func test_remainingFactor_fastChange() throws {
    // given: a linear change over one second at double speed
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1, speed: 2), at: 100)
    let change = try changes.changes.first.unwrap()

    // then: half of the offset is left after a quarter second, and none after half a second
    expect(change.speed) == 2
    expect(change.remainingFactor(at: 0.25, now: 100)) == 0.5
    expect(change.remainingFactor(at: 0.5, now: 100)) == 0
  }

  func test_remainingFactor_springChange_landsWhenItsTimeIsUp() throws {
    // given: a spring change
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .spring(dampingRatio: 0.5, response: 0.5), at: 100)
    let change = try changes.changes.first.unwrap()
    let duration = changes.remainingTime(at: 100)

    // then: a sliver of the offset is left just before the spring's time is up, as a spring settles without reaching its
    // end exactly, and none once it is up
    let factorBeforeTheEnd = change.remainingFactor(at: duration * 0.999, now: 100)
    expect(factorBeforeTheEnd) != 0
    expect(abs(factorBeforeTheEnd)) < 0.1
    expect(change.remainingFactor(at: duration, now: 100)) == 0
  }

  func test_remainingFactor_beforeLanding_showsTheLandingFactorAtTheLandingTime() throws {
    // given: a spring change cut short by a duration of 0.1s, before it settles
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .spring(dampingRatio: 1, response: 0.5, duration: 0.1), at: 100)
    let change = try changes.changes.first.unwrap()

    // then: at its landing time the change shows its landing factor before it lands and zero after, and at other times
    // it shows the same either way
    expect(change.remainingFactor(at: 0.1, now: 100, beforeLanding: true)) == change.landingFactor
    expect(change.remainingFactor(at: 0.1, now: 100)) == 0
    expect(change.remainingFactor(at: 0.05, now: 100, beforeLanding: true)) == change.remainingFactor(at: 0.05, now: 100)
    expect(change.remainingFactor(at: 0.2, now: 100, beforeLanding: true)) == 0
  }

  // MARK: - Landing Factor

  func test_landingFactor() {
    // given: a linear change, an eased change, and a spring change cut short by a duration of 0.1s, before it settles
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 5), timing: .linear(duration: 1), at: 100)
    changes.record(from: rect(inset: 5), to: rect(inset: 10), timing: .easeInEaseOut(duration: 1), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 15), timing: .spring(dampingRatio: 1, response: 0.5, duration: 0.1), at: 100)
    expect(changes.changes.count) == 3

    // then: the curves that reach their end land without a jump, and the cut-short spring jumps from what its curve
    // leaves at the end of its duration
    expect(changes.changes[0].landingFactor) == 0
    expect(changes.changes[1].landingFactor) == 0
    expect(changes.changes[2].landingFactor) == CGFloat(1 - changes.changes[2].curve.progress(forElapsedTime: 0.1))
    expect(changes.changes[2].landingFactor) > 0.5
  }

  func test_landingFactor_infiniteDuration_isZero() {
    // given: a spring change of an infinite duration, built directly, as `AnimationTiming` rejects an infinite duration
    // and Core Animation gives a spring at most `Float.greatestFiniteMagnitude`
    let animation = CABasicAnimation.makeAnimation(.spring(dampingRatio: 0.5, response: 0.5))
    animation.duration = .infinity
    let offset = PathPoints(rect(inset: 0)).subtracting(PathPoints(rect(inset: 5)))
    let change = PathChanges.Change(offset: offset, widthOffset: nil, heightOffset: nil, animation: animation, curve: AnimationCurve(animation), speed: 1, beginTime: 0)

    // then: the spring never lands, so it has no jump, instead of the undefined progress at its infinite end
    expect(change.landingFactor) == 0
  }

  // MARK: - Keyframes

  func test_keyframes_samplesAtTheDisplayRate() {
    // given: a linear change from a rect to an inset rect over half a second, beginning now
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 0.5), at: 100)
    let path = rect(inset: 10)

    // when: sampling the keyframes
    let keyframes = changes.keyframes(adding: path, points: PathPoints(path), at: 100)

    // then: the keyframes are spread evenly at the display rate until the change lands, from the old path to the path
    // itself
    expect(keyframes.duration) == 0.5
    expect(keyframes.keyTimes) == nil
    expect(keyframes.paths.count) == 31 // 0.5s at 60 per second, plus the end
    expect(keyframes.paths[0].maxPointDistance(to: rect(inset: 0))) < 1e-9
    expect(keyframes.paths[15].maxPointDistance(to: rect(inset: 5))) < 1e-9
    expect(keyframes.paths[30]) === path
  }

  func test_keyframes_begunChange_samplesFromNow() {
    // given: a linear change over one second that began half a second ago
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1), at: 99.5)
    let path = rect(inset: 10)

    // when: sampling the keyframes
    let keyframes = changes.keyframes(adding: path, points: PathPoints(path), at: 100)

    // then: the keyframes cover the half second left, from half of the offset
    expect(keyframes.paths.count) == 31
    expect(keyframes.paths[0].maxPointDistance(to: rect(inset: 5))) < 1e-9
    expect(keyframes.paths[30]) === path
  }

  func test_keyframes_twoChanges_addBoth() {
    // given: a change to an inset rect over one second, and a change to a more inset rect over two seconds
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .linear(duration: 2), at: 100)
    let path = rect(inset: 20)

    // when: sampling the keyframes
    let keyframes = changes.keyframes(adding: path, points: PathPoints(path), at: 100)

    // then: both offsets are left at the start, half of the second one after a second, once the first has landed, and
    // the path itself at the end. the first change lands on an evenly spread keyframe, so the keyframes stay evenly
    // spread
    expect(keyframes.keyTimes) == nil
    expect(keyframes.paths.count) == 121
    expect(keyframes.paths[0].maxPointDistance(to: rect(inset: 0))) < 1e-9
    expect(keyframes.paths[60].maxPointDistance(to: rect(inset: 15))) < 1e-9
    expect(keyframes.paths[120]) === path
  }

  func test_keyframes_longChanges_keepTheSamplingRate() {
    // given: a change of ten seconds, as a long spring has
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 10), at: 100)
    let path = rect(inset: 10)

    // then: the keyframes are still spread at the display rate, since a long spring keeps bouncing and sparser
    // keyframes would cut across its bounces
    expect(changes.keyframes(adding: path, points: PathPoints(path), at: 100).paths.count) == 601 // 10s at 60 per second, plus the end
  }

  func test_keyframes_unreasonableDuration_boundsTheSampleCount() {
    // given: a change of an absurd duration, as a tiny speed on a timing gives
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1, speed: 1e-30), at: 100)
    let path = rect(inset: 10)

    // when: sampling the keyframes
    let keyframes = changes.keyframes(adding: path, points: PathPoints(path), at: 100)

    // then: the keyframes are bounded to ten seconds' worth, instead of an unbounded count or a trapped conversion, and
    // still reach the path itself at the end
    expect(keyframes.paths.count) == 601
    expect(keyframes.paths.last) === path
  }

  func test_keyframes_noChanges_givesThePathItself() {
    // given: no changes in flight
    let changes = PathChanges()
    let path = rect(inset: 10)

    // when: sampling the keyframes
    let keyframes = changes.keyframes(adding: path, points: PathPoints(path), at: 100)

    // then: the path itself starts and ends the keyframes
    expect(keyframes.paths.count) == 2
    expect(keyframes.paths[0]) === path
    expect(keyframes.paths[1]) === path
  }

  func test_keyframes_delayedSnap_getsKeyframesWhereItBeginsAndLands() throws {
    // given: a linear change over two seconds, and a snap after a delay that ends between two evenly spread keyframes
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 2), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .linear(duration: 0, delay: 0.508), at: 100)
    let snapDuration = changes.changes[1].curve.duration
    let path = rect(inset: 20)

    // when: sampling the keyframes
    let keyframes = changes.keyframes(adding: path, points: PathPoints(path), at: 100)

    // then: the snap gets a keyframe where it begins, which still holds it, and one where it lands, with key times for
    // the keyframes that aren't evenly spread
    let times = try keyframes.keyTimes.unwrap().map { $0.doubleValue * keyframes.duration }
    expect(keyframes.paths.count) == 123 // 2s at 60 per second, plus the end, the snap's begin and its landing
    expect(times.count) == 123
    let beginIndex = try times.firstIndex { abs($0 - 0.508) < 1e-9 }.unwrap()
    expect(times[beginIndex + 1]).to(beApproximatelyEqual(to: 0.508 + snapDuration, within: 1e-9))
    expect(keyframes.paths[beginIndex].maxPointDistance(to: rect(inset: 10 - 10 * (1 - 0.508 / 2)))) < 1e-9
    expect(keyframes.paths[beginIndex + 1].maxPointDistance(to: rect(inset: 20 - 10 * (1 - times[beginIndex + 1] / 2)))) < 1e-9
  }

  func test_keyframes_slowSnap_stillLandsAtOnce() throws {
    // given: a linear change over two seconds, and a snap at a hundredth of the speed after a delay
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 2), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .linear(duration: 0, delay: 0.508, speed: 0.01), at: 100)
    let snapDuration = changes.changes[1].curve.duration
    let path = rect(inset: 20)

    // when: sampling the keyframes
    let keyframes = changes.keyframes(adding: path, points: PathPoints(path), at: 100)

    // then: the snap lands a snap's duration after it begins, as a zero duration has no timeline for the speed to scale
    let times = try keyframes.keyTimes.unwrap().map { $0.doubleValue * keyframes.duration }
    let beginIndex = try times.firstIndex { abs($0 - 0.508) < 1e-9 }.unwrap()
    expect(times[beginIndex + 1] - times[beginIndex]).to(beApproximatelyEqual(to: snapDuration, within: 1e-9))
  }

  func test_keyframes_delayedChange_getsKeyframesWhereItBeginsAndLands() throws {
    // given: a linear change over two seconds, and a linear change over half a second after a delay, which begins and
    // lands between evenly spread keyframes
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 2), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .linear(duration: 0.5, delay: 0.505), at: 100)
    let path = rect(inset: 20)

    // when: sampling the keyframes
    let keyframes = changes.keyframes(adding: path, points: PathPoints(path), at: 100)

    // then: the delayed change gets a keyframe where it begins, which still holds it, and one where it lands, which it
    // has left, so its motion starts and stops at those times instead of between keyframes
    let times = try keyframes.keyTimes.unwrap().map { $0.doubleValue * keyframes.duration }
    expect(keyframes.paths.count) == 123 // 2s at 60 per second, plus the end, the delayed change's begin and its landing
    let beginIndex = try times.firstIndex { abs($0 - 0.505) < 1e-9 }.unwrap()
    let landingIndex = try times.firstIndex { abs($0 - 1.005) < 1e-9 }.unwrap()
    expect(keyframes.paths[beginIndex].maxPointDistance(to: rect(inset: 10 - 10 * (1 - 0.505 / 2)))) < 1e-9
    expect(keyframes.paths[landingIndex].maxPointDistance(to: rect(inset: 20 - 10 * (1 - 1.005 / 2)))) < 1e-9
  }

  func test_keyframes_changeWithoutDelay_getsAKeyframeWhereItLands() throws {
    // given: a change of 0.37s without a delay, and a change of a second
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 0.37), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .linear(duration: 1), at: 100)
    let path = rect(inset: 20)

    // when: sampling the keyframes
    let keyframes = changes.keyframes(adding: path, points: PathPoints(path), at: 100)

    // then: the first change begins with the keyframes, so it only gets a keyframe where it lands
    let times = try keyframes.keyTimes.unwrap().map { $0.doubleValue * keyframes.duration }
    expect(times.count) == 62 // 1s at 60 per second, plus the end and the first change's landing
    expect(times.contains { abs($0 - 0.37) < 1e-9 }) == true
  }

  func test_keyframes_landedChange_addsNothing() {
    // given: a change that landed two seconds ago, which no update has removed yet, and a change over a second
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 0.01, delay: 1), at: 97)
    changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .linear(duration: 1), at: 100)
    let path = rect(inset: 20)

    // when: sampling the keyframes
    let keyframes = changes.keyframes(adding: path, points: PathPoints(path), at: 100)

    // then: the landed change adds no offset and no keyframes of its own
    expect(keyframes.keyTimes) == nil
    expect(keyframes.paths.count) == 61
    expect(keyframes.paths[0].maxPointDistance(to: rect(inset: 10))) < 1e-9
  }

  func test_keyframes_truncatedSpring_jumpsWhereItLands() throws {
    // a spring landing between evenly spread keyframes gets both keyframes of its jump, and one landing on an evenly
    // spread keyframe gets the keyframe before its jump, as the evenly spread one shows it landed
    let scenarios: [(springDuration: TimeInterval, keyframeCount: Int)] = [
      (0.105, 123), // 2s at 60 per second, plus the end, the spring's landing and the keyframe before its jump
      (0.1, 122), // 2s at 60 per second, plus the end and the keyframe before the spring's jump
    ]
    for (springDuration, keyframeCount) in scenarios {
      let scenario = "spring duration: \(springDuration)"

      // given: a linear change over two seconds, and a spring change cut short by its duration, before it settles
      var changes = PathChanges()
      changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 2), at: 100)
      changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .spring(dampingRatio: 1, response: 0.5, duration: springDuration), at: 100)
      let landingFactor = changes.changes[1].landingFactor
      let path = rect(inset: 20)

      // when: sampling the keyframes
      let keyframes = changes.keyframes(adding: path, points: PathPoints(path), at: 100)

      // then: the spring's landing time has two keyframes, the first with what the spring's curve leaves at its end and
      // the second with the spring landed, so the spring jumps at once when it lands instead of across the spacing
      let times = try keyframes.keyTimes.unwrap().map { $0.doubleValue * keyframes.duration }
      expect(keyframes.paths.count, scenario) == keyframeCount
      let jumpIndex = try times.firstIndex { abs($0 - springDuration) < 1e-9 }.unwrap()
      expect(times[jumpIndex + 1], scenario) == times[jumpIndex]
      let linearInset = 10 * (1 - springDuration / 2)
      expect(keyframes.paths[jumpIndex].maxPointDistance(to: rect(inset: 20 - linearInset - 10 * landingFactor)), scenario) < 1e-9
      expect(keyframes.paths[jumpIndex + 1].maxPointDistance(to: rect(inset: 20 - linearInset)), scenario) < 1e-9
    }
  }

  func test_keyframes_truncatedSpringLandingLast_jumpsAtTheEnd() throws {
    // given: a linear change over 0.05s, and a spring change cut short by a duration of 0.1s, which lands last
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 0.05), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .spring(dampingRatio: 1, response: 0.5, duration: 0.1), at: 100)
    let landingFactor = changes.changes[1].landingFactor
    let path = rect(inset: 20)

    // when: sampling the keyframes
    let keyframes = changes.keyframes(adding: path, points: PathPoints(path), at: 100)

    // then: the keyframes end with what the spring's curve leaves at its end, then the path itself at the same time, so
    // the spring jumps at once at the end
    let times = try keyframes.keyTimes.unwrap().map { $0.doubleValue * keyframes.duration }
    expect(keyframes.duration) == 0.1
    expect(Array(times.suffix(2))) == [0.1, 0.1]
    expect(keyframes.paths[keyframes.paths.count - 2].maxPointDistance(to: rect(inset: 20 - 10 * landingFactor))) < 1e-9
    expect(keyframes.paths.last) === path
  }

  func test_keyframes_springWithoutDamping_asserts() {
    // given: a linear change over two seconds, and a spring change without damping, which never settles
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 2), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .spring(dampingRatio: 0, response: 0.5), at: 100)
    let path = rect(inset: 20)

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: sampling the keyframes
    let keyframes = changes.keyframes(adding: path, points: PathPoints(path), at: 100)

    // then: it asserts, as a change that never finishes can't overlap others, and the keyframes still end with the path
    // itself
    expect(assertionMessages) == ["a path change that never finishes can't overlap others"]
    expect(keyframes.paths.last) === path
  }

  func test_keyframes_oneChange_isSpreadEvenly() {
    // given: a change of 0.37s, alone
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 0.37), at: 100)
    let path = rect(inset: 10)

    // when: sampling the keyframes
    let keyframes = changes.keyframes(adding: path, points: PathPoints(path), at: 100)

    // then: the change begins and lands with the keyframes, so it needs no keyframes of its own
    expect(keyframes.duration) == 0.37
    expect(keyframes.keyTimes) == nil
  }

  // MARK: - Helpers

  /// A rect of 100 by 50 points at the origin, inset by the given amount.
  private func rect(inset: CGFloat) -> CGPath {
    CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50).insetBy(dx: inset, dy: inset), transform: nil)
  }

  /// A rect of the given size at the origin.
  private func rect(width: CGFloat, height: CGFloat) -> CGPath {
    CGPath(rect: CGRect(x: 0, y: 0, width: width, height: height), transform: nil)
  }

  /// A rect of the given size at the origin.
  private func rect(size: CGSize) -> CGPath {
    rect(width: size.width, height: size.height)
  }

  /// A rect between the given left and right edges, 50 points high at the top.
  private func rect(left: CGFloat, right: CGFloat) -> CGPath {
    CGPath(rect: CGRect(x: left, y: 0, width: right - left, height: 50), transform: nil)
  }

  /// A rect at the origin as high as a size and as wide as the size plus an extension.
  private func extendedRect(_ size: CGSize, by extension: CGFloat) -> CGPath {
    rect(width: size.width + `extension`, height: size.height)
  }

  /// A square as high as a size at the size's right edge, so its left edge moves with the size's height too.
  private func rightSquare(_ size: CGSize) -> CGPath {
    CGPath(rect: CGRect(x: size.width - size.height, y: 0, width: size.height, height: size.height), transform: nil)
  }

  /// A rounded rect of the given width and 50 points high at the origin.
  private func roundedRect(width: CGFloat = 100, radius: CGFloat = 5) -> CGPath {
    roundedRect(size: CGSize(width: width, height: 50), radius: radius)
  }

  /// A rounded rect of the given size at the origin.
  private func roundedRect(size: CGSize, radius: CGFloat = 5) -> CGPath {
    CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: radius, cornerHeight: radius, transform: nil)
  }

  /// Whether points have the segments of others, with each point within rounding error of the other's.
  private func isPoints(_ points: PathPoints, closeTo other: PathPoints) -> Bool {
    points.hasSameSegments(as: other) && zip(points.points, other.points).allSatisfy {
      abs($0.x - $1.x) <= 1e-9 && abs($0.y - $1.y) <= 1e-9
    }
  }
}

private extension PathChanges {

  /// Records a change between two paths, see `record(from:to:resize:timing:at:)`.
  mutating func record(from oldPath: CGPath, to newPath: CGPath, timing: AnimationTiming, at now: TimeInterval) {
    record(from: PathPoints(oldPath), to: PathPoints(newPath), timing: timing, at: now)
  }

  /// Records a change of a path that follows a size, from the old path to the path for the new size, with the paths for
  /// the sizes between, see `record(from:to:resize:timing:at:)`.
  mutating func record(from oldPath: CGPath, resizingFrom oldSize: CGSize, to newSize: CGSize, path: (CGSize) -> CGPath, timing: AnimationTiming, at now: TimeInterval) {
    record(from: PathPoints(oldPath), to: PathPoints(path(newSize)), resize: .of(path, from: oldSize, to: newSize), timing: timing, at: now)
  }

  /// Retargets the changes to a path, see `retarget(from:to:resize:at:)`.
  mutating func retarget(from oldPath: CGPath, to newPath: CGPath, at now: TimeInterval) {
    retarget(from: PathPoints(oldPath), to: PathPoints(newPath), at: now)
  }

  /// Retargets the changes of a path that follows a size, from the old path to the path for the new size, with the paths
  /// for the sizes between, see `retarget(from:to:resize:at:)`.
  mutating func retarget(from oldPath: CGPath, resizingFrom oldSize: CGSize, to newSize: CGSize, path: (CGSize) -> CGPath, at now: TimeInterval) {
    retarget(from: PathPoints(oldPath), to: PathPoints(path(newSize)), resize: .of(path, from: oldSize, to: newSize), at: now)
  }
}

private extension PathChanges.Resize {

  /// The points of a path for the sizes between two sizes, see `PathChanges.Resize`.
  static func of(_ path: (CGSize) -> CGPath, from oldSize: CGSize, to newSize: CGSize) -> PathChanges.Resize {
    PathChanges.Resize(atOldSize: PathPoints(path(oldSize)), atNewWidth: PathPoints(path(CGSize(width: newSize.width, height: oldSize.height))))
  }
}
