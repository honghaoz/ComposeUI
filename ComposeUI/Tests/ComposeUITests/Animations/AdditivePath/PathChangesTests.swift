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
    expect(change.curve.duration) == 2
    expect(change.speed) == 1
    expect(change.beginTime) == 0
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

  // MARK: - Update

  func test_update_resolvesTheBeginTime() {
    // given: a change recorded before the commit, and a delayed change with its own begin time
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 2), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .linear(duration: 2, delay: 1), at: 100)

    // when: updating before the animation that shows the changes is committed
    changes.update(beginTime: 0, at: 100)

    // then: the first change still begins at the next commit
    expect(changes.changes.map(\.beginTime)) == [0, 101]

    // when: updating after the commit gave the animation a begin time
    changes.update(beginTime: 100.02, at: 100.5)

    // then: the first change begins when the animation began, and the delayed change keeps its own begin time
    expect(changes.changes.map(\.beginTime)) == [100.02, 101]
  }

  func test_update_laterCommit_keepsTheDelayedChangesBeginTime() {
    // given: a change recorded before the commit, and a delayed change with its own begin time
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 2), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .linear(duration: 2, delay: 1), at: 100)

    // when: updating after the animation that shows them, made at 100, was committed at 100.3
    changes.update(beginTime: 100.3, at: 100.5)

    // then: the first change begins at the commit, and the delayed change keeps its own begin time, as a delayed
    // animation does
    expect(changes.changes.map(\.beginTime)) == [100.3, 101]
  }

  func test_update_removesLandedChanges() {
    // given: a change of one second and a change of three seconds, recorded before the commit
    var changes = PathChanges()
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1), at: 100)
    changes.record(from: rect(inset: 10), to: rect(inset: 20), timing: .linear(duration: 3), at: 100)

    // when: updating two seconds after the animation that shows them began
    changes.update(beginTime: 98, at: 100)

    // then: the change of one second has landed and is removed, the other is kept
    expect(changes.changes.map(\.curve.duration)) == [3]
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

  func test_beginsAtCommit() {
    // given: no changes in flight
    var changes = PathChanges()

    // then: no change begins at the commit
    expect(changes.beginsAtCommit(at: 100)) == false

    // when: a change with a delay of a second
    changes.record(from: rect(inset: 0), to: rect(inset: 5), timing: .linear(duration: 1, delay: 1), at: 100)

    // then: it begins after its delay, so the keyframes begin now
    expect(changes.beginsAtCommit(at: 100)) == false

    // when: a change without a delay
    changes.record(from: rect(inset: 5), to: rect(inset: 10), timing: .linear(duration: 1), at: 100)

    // then: the keyframes begin at the commit with it, as no change moves yet
    expect(changes.beginsAtCommit(at: 100)) == true

    // then: once the delayed change moves, the keyframes begin now, to keep it where it is shown
    expect(changes.beginsAtCommit(at: 101)) == false
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
    // given: a linear change over one second, beginning at the next commit
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
    changes.update(beginTime: 99.75, at: 100)
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

    // then: the curves that reach their end land without a jump, and the spring jumps from what its curve leaves at the
    // end of its duration
    expect(changes.changes[0].landingFactor) == 0
    expect(changes.changes[1].landingFactor) == 0
    expect(changes.changes[2].landingFactor) == CGFloat(1 - changes.changes[2].curve.progress(forElapsedTime: 0.1))
    expect(changes.changes[2].landingFactor) > 0.5
  }

  // MARK: - Keyframes

  func test_keyframes_samplesAtTheDisplayRate() {
    // given: a linear change from a rect to an inset rect over half a second, beginning at the next commit
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
    changes.update(beginTime: 99.5, at: 100)
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
    changes.record(from: rect(inset: 0), to: rect(inset: 10), timing: .linear(duration: 1e300), at: 100)
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

  /// A rounded rect of 100 by 50 points at the origin.
  private func roundedRect(radius: CGFloat = 5) -> CGPath {
    CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 50), cornerWidth: radius, cornerHeight: radius, transform: nil)
  }
}

private extension PathChanges {

  /// Records a change between two paths, see `record(from:to:timing:at:)`.
  mutating func record(from oldPath: CGPath, to newPath: CGPath, timing: AnimationTiming, at now: TimeInterval) {
    record(from: PathPoints(oldPath), to: PathPoints(newPath), timing: timing, at: now)
  }
}
