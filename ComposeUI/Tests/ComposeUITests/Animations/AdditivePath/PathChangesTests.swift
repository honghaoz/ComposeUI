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

    // then: the change is the rect minus the inset rect, point by point, timed by the timing, and it begins at the next
    // commit
    expect(changes.changes.count) == 1
    let change = try changes.changes.first.unwrap()
    expect(change.offset) == PathPoints(rect(inset: 0)).subtracting(PathPoints(rect(inset: 10)))
    expect(change.animation.duration) == 2
    expect(change.animation.timingFunction) == CAMediaTimingFunction(name: .easeIn)
    expect(change.animation.beginTime) == 0
  }

  func test_record_delayedChange_beginsAfterTheDelay() throws {
    // given: no changes in flight
    var changes = PathChanges()

    // when: recording a change with a delay
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1, delay: 0.5), at: 100)

    // then: the change begins after the delay
    expect(try changes.changes.first.unwrap().animation.beginTime) == 100.5
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

    // then: the change snaps after the delay
    let change = try changes.changes.first.unwrap()
    expect(change.animation.duration) == scheduledSnapDuration
    expect(change.animation.beginTime) == 101
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

  // MARK: - Update

  func test_update_resolvesTheBeginTime() {
    // given: a change recorded before the commit, and a delayed change with its own begin time
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 2), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .linear(duration: 2, delay: 1), at: 100)

    // when: updating before the animation that shows the changes is committed
    changes.update(beginTime: 0, at: 100)

    // then: the first change still begins at the next commit
    expect(changes.changes.map(\.animation.beginTime)) == [0, 101]

    // when: updating after the commit gave the animation a begin time
    changes.update(beginTime: 100.02, at: 100.5)

    // then: the first change begins when the animation began, and the delayed change keeps its own begin time
    expect(changes.changes.map(\.animation.beginTime)) == [100.02, 101]
  }

  func test_update_removesLandedChanges() {
    // given: a change of one second and a change of three seconds, recorded before the commit
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .linear(duration: 3), at: 100)

    // when: updating two seconds after the animation that shows them began
    changes.update(beginTime: 98, at: 100)

    // then: the change of one second has landed and is removed, the other is kept
    expect(changes.changes.map(\.animation.duration)) == [3]
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

    // when: a delayed change of two seconds, and a change of one second beginning at the next commit
    changes.record(from: rect(inset: 5), to: rect(inset: 10), timing: .linear(duration: 2, delay: 0.5), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 15), timing: .linear(duration: 1), at: 100)

    // then: the longest time left remains
    expect(changes.remainingTime(at: 100)) == 2.5
  }

  func test_hasResolvedBeginTime() {
    // given: a change beginning at the next commit
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1), at: 100)

    // then: no change has a begin time
    expect(changes.hasResolvedBeginTime) == false

    // when: a delayed change
    changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .linear(duration: 1, delay: 1), at: 100)

    // then: a change has a begin time
    expect(changes.hasResolvedBeginTime) == true
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

  // MARK: - Points

  func test_points_addTheOffsetsLeft() throws {
    // given: a linear change from a rect to an inset rect over one second, beginning at the next commit
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1), at: 100)
    let points = PathPoints(rect(inset: 10))

    // then: the inset rect takes all of the offset at the start, half of it in the middle, and none at the end
    expect(try changes.points(adding: points, at: 0, now: 100).unwrap().path.maxPointDistance(to: rect(inset: 0))) < 1e-9
    expect(try changes.points(adding: points, at: 0.5, now: 100).unwrap().path.maxPointDistance(to: rect(inset: 5))) < 1e-3
    expect(changes.points(adding: points, at: 1, now: 100)) == nil
  }

  func test_points_begunChange_isMeasuredFromItsBegin() throws {
    // given: a linear change over one second that began half a second ago
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1), at: 99.5)
    changes.update(beginTime: 99.5, at: 100)
    let points = PathPoints(rect(inset: 10))

    // then: half of the offset is left now, and none half a second later
    expect(try changes.points(adding: points, at: 0, now: 100).unwrap().path.maxPointDistance(to: rect(inset: 5))) < 1e-3
    expect(changes.points(adding: points, at: 0.5, now: 100)) == nil
  }

  func test_points_delayedChange_holdsTheOffsetUntilItBegins() throws {
    // given: a linear change over one second with a delay of half a second
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1, delay: 0.5), at: 100)
    let points = PathPoints(rect(inset: 10))

    // then: all of the offset is left until the change begins, then it runs out over the duration
    expect(try changes.points(adding: points, at: 0, now: 100).unwrap().path.maxPointDistance(to: rect(inset: 0))) < 1e-9
    expect(try changes.points(adding: points, at: 0.5, now: 100).unwrap().path.maxPointDistance(to: rect(inset: 0))) < 1e-9
    expect(try changes.points(adding: points, at: 1, now: 100).unwrap().path.maxPointDistance(to: rect(inset: 5))) < 1e-3
    expect(changes.points(adding: points, at: 1.5, now: 100)) == nil
  }

  func test_points_fastChange() throws {
    // given: a linear change over one second at double speed
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1, speed: 2), at: 100)
    let points = PathPoints(rect(inset: 10))

    // then: half of the offset is left after a quarter second, and none after half a second
    expect(try changes.points(adding: points, at: 0.25, now: 100).unwrap().path.maxPointDistance(to: rect(inset: 5))) < 1e-3
    expect(changes.points(adding: points, at: 0.5, now: 100)) == nil
  }

  func test_points_springChange_landsWhenItsTimeIsUp() throws {
    // given: a spring change
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .spring(dampingRatio: 0.5, response: 0.5), at: 100)
    let points = PathPoints(rect(inset: 10))
    let duration = changes.remainingTime(at: 100)

    // then: a sliver of the offset is left just before the spring's time is up, as a spring settles without reaching its
    // end exactly, and none once it is up
    let pointsBeforeTheEnd = try changes.points(adding: points, at: duration * 0.999, now: 100).unwrap()
    expect(pointsBeforeTheEnd.path.maxPointDistance(to: rect(inset: 10))) < 1
    expect(changes.points(adding: points, at: duration, now: 100)) == nil
  }

  func test_points_twoChanges_addBoth() throws {
    // given: a change to an inset rect over one second, and a change to a more inset rect over two seconds
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .linear(duration: 2), at: 100)
    let points = PathPoints(rect(inset: 20))

    // then: both offsets are left at the start, and half of the second one after a second
    expect(try changes.points(adding: points, at: 0, now: 100).unwrap().path.maxPointDistance(to: rect(inset: 0))) < 1e-9
    expect(try changes.points(adding: points, at: 1, now: 100).unwrap().path.maxPointDistance(to: rect(inset: 15))) < 1e-3
  }

  // MARK: - Sample Times

  func test_sampleTimes_samplesAtTheDisplayRate() {
    // given: a change of half a second
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 0.5), at: 100)

    // when: sampling the times
    let times = changes.sampleTimes(at: 100)

    // then: the times are spread at the display rate from zero until the change lands
    expect(times.count) == 31 // 0.5s at 60 per second, plus the end
    expect(times.first) == 0
    expect(times[15]) == 0.25
    expect(times.last) == 0.5
  }

  func test_sampleTimes_longChanges_keepTheSamplingRate() {
    // given: a change of ten seconds, as a long spring has
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 10), at: 100)

    // then: the times are still at the display rate, since a long spring keeps bouncing and sparser samples would cut
    // across its bounces
    expect(changes.sampleTimes(at: 100).count) == 601 // 10s at 60 per second, plus the end
  }

  func test_sampleTimes_unreasonableDuration_boundsTheSampleCount() {
    // given: a change of an absurd duration, as a tiny speed on a timing gives
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1e300), at: 100)

    // when: sampling the times
    let times = changes.sampleTimes(at: 100)

    // then: the times are bounded to ten seconds' worth, instead of an unbounded count or a trapped conversion, and still
    // reach the end
    expect(times.count) == 601
    expect(times.last) == 1e300
  }

  // MARK: - Helpers

  /// A rect of 100 by 50 points at the origin, inset by the given amount.
  private func rect(inset: CGFloat) -> CGPath {
    CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50).insetBy(dx: inset, dy: inset), transform: nil)
  }

  /// A rounded rect of 100 by 50 points at the origin.
  private func roundedRect(radius: CGFloat = 5) -> CGPath {
    CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 50), cornerWidth: radius, cornerHeight: radius, transform: nil)
  }
}
