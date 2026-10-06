//
//  AnimationClockTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/27/26.
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

@testable import ComposeUI

class AnimationClockTests: XCTestCase {

  // MARK: - Now

  func test_now_withinATurn_readsTheTimeOfTheFirstRead() {
    // given: a new turn of the main run loop
    RunLoop.main.run(until: Date())

    // when: reading the clock twice in the turn, a millisecond apart
    let timeBefore = CACurrentMediaTime()
    let firstRead = AnimationClock.now
    Thread.sleep(forTimeInterval: 0.001)
    let secondRead = AnimationClock.now

    // then: the first read is the media time, and the second read returns it
    expect(firstRead) >= timeBefore
    expect(secondRead) == firstRead
  }

  func test_now_afterTheLoopExits_readsANewTime() {
    // given: the time of the current turn of the main run loop
    let turnTime = AnimationClock.now

    // when: a millisecond later, the main run loop runs without waiting and exits, then the clock is read
    Thread.sleep(forTimeInterval: 0.001)
    RunLoop.main.run(until: Date())
    let timeBefore = CACurrentMediaTime()
    let nextRead = AnimationClock.now

    // then: the exit ended the turn, so the read is the media time of a new turn
    expect(nextRead) >= timeBefore
    expect(nextRead - turnTime) >= 0.001
  }

  func test_now_afterTheLoopWaits_readsANewTime() throws {
    // given: the time of the current turn of the main run loop, and a read of the clock scheduled 10 ms later
    let turnTime = AnimationClock.now
    var scheduledRead: CFTimeInterval?
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
      scheduledRead = AnimationClock.now
    }

    // when: the main run loop runs past the scheduled read, waiting for it in between
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

    // then: the loop ended the turn before it waited, so the scheduled read is the time of a new turn, 10 ms later
    expect(try scheduledRead.unwrap() - turnTime) >= 0.01
  }

  func test_now_duringTheCommit_readsTheTurnsTime() throws {
    // given: a layer in a window, whose layout reads the clock, laid out by the commit that ends the current turn
    let window = TestWindow()
    let layer = ClockReadingLayer()
    window.layer.addSublayer(layer)
    RunLoop.main.run(until: Date())
    layer.layoutReads.removeAll()
    let turnTime = AnimationClock.now
    layer.setNeedsLayout()

    // when: a millisecond later, the turn ends
    Thread.sleep(forTimeInterval: 0.001)
    RunLoop.main.run(until: Date())

    // then: the layout ran in the commit, before the turn ended, so it read the turn's time
    expect(layer.layoutReads) == [turnTime]

    // then: the turn has ended since, so a read is a new time
    expect(AnimationClock.now - turnTime) >= 0.001
  }

  func test_now_firstReadDuringTheCommit_theTurnEndsWhenTheLoopWakes() throws {
    // given: the clock's first read, in an observer of the pass that commits before the main run loop waits, as in a
    // layout Core Animation's commit runs, an event 30 ms after it, and an observer of the wake that reads the clock
    AnimationClock.resetForTesting()
    var firstRead: CFTimeInterval?
    var eventRead: CFTimeInterval?
    let commitReader = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeWaiting.rawValue, false, 2000000) { _, _ in
      firstRead = AnimationClock.now
      // scheduled after the first read instead of before the loop runs, so that the event comes after the wait however
      // late the main thread gets to the first read
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
        eventRead = AnimationClock.now
      }
    }
    var wakeRead: (timeBefore: CFTimeInterval, read: CFTimeInterval)?
    let wakeReader = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.afterWaiting.rawValue, false, 0) { _, _ in
      wakeRead = (CACurrentMediaTime(), AnimationClock.now)
    }
    CFRunLoopAddObserver(CFRunLoopGetMain(), commitReader, .commonModes)
    CFRunLoopAddObserver(CFRunLoopGetMain(), wakeReader, .commonModes)

    // when: the loop waits and wakes without exiting in between, as an app's main run loop does
    CFRunLoopRunInMode(.defaultMode, 0.1, false)

    // then: the observers the first read installed missed its pass, but the turn ended when the loop woke, before the
    // wake's other observers, so the reads after the wait are new times
    let wake = try wakeRead.unwrap()
    expect(wake.read) >= wake.timeBefore
    let first = try firstRead.unwrap()
    expect(try eventRead.unwrap()) > first
  }

  func test_now_afterAFlush_readsTheTurnsTime() {
    // given: the time of the current turn of the main run loop
    let turnTime = AnimationClock.now

    // when: a millisecond later, a flush commits the pending changes, then the clock is read
    Thread.sleep(forTimeInterval: 0.001)
    CATransaction.flush()
    let nextRead = AnimationClock.now

    // then: a flush commits without ending the turn, so the read returns the turn's time
    expect(nextRead) == turnTime
  }

  func test_now_offTheMainThread_readsTheMediaTimeAtEachRead() throws {
    // given: the main thread reading a time far ahead of the media time
    let givenTime = CACurrentMediaTime() + 1000
    try AnimationClock.sharingTime(at: givenTime) {
      // when: reading the clock twice on a background thread, a millisecond apart
      var reads: (first: CFTimeInterval, second: CFTimeInterval)?
      let readsDone = XCTestExpectation(description: "reads")
      DispatchQueue.global().async {
        let firstRead = AnimationClock.now
        Thread.sleep(forTimeInterval: 0.001)
        reads = (firstRead, AnimationClock.now)
        readsDone.fulfill()
      }
      wait(for: [readsDone], timeout: 5)

      // then: each read is the media time when it's read, as the times the clock holds are the main thread's
      let backgroundReads = try reads.unwrap()
      expect(backgroundReads.first) < givenTime
      expect(backgroundReads.second - backgroundReads.first) >= 0.001

      // then: the main thread still reads its time
      expect(AnimationClock.now) == givenTime
    }
  }

  // MARK: - Sharing a Given Time

  func test_sharingTimeAt_readsTheGivenTime_andRestoresTheTurnsTime() {
    // given: the time of the current turn of the main run loop
    let turnTime = AnimationClock.now

    // when: reading the clock in a block of the time 1000, in a block of the time 2000 nested in it, and in the outer
    // block after the nested one
    let reads = AnimationClock.sharingTime(at: 1000) { () -> (outer: CFTimeInterval, nested: CFTimeInterval, outerAfterNested: CFTimeInterval) in
      let outerRead = AnimationClock.now
      let nestedRead = AnimationClock.sharingTime(at: 2000) { AnimationClock.now }
      return (outerRead, nestedRead, AnimationClock.now)
    }

    // then: each block reads its own time, and the turn's time is read again after the blocks
    expect(reads.outer) == 1000
    expect(reads.nested) == 2000
    expect(reads.outerAfterNested) == 1000
    expect(AnimationClock.now) == turnTime
  }

  func test_sharingTimeAt_acrossATurn_readsTheGivenTime() {
    AnimationClock.sharingTime(at: 1000) {
      // when: the turn ends within a block of the time 1000
      RunLoop.main.run(until: Date())

      // then: the block still reads its time
      expect(AnimationClock.now) == 1000
    }
  }

  func test_sharingTimeAt_beforeTheTurnsFirstRead_theTurnReadsTheMediaTime() {
    // given: a new turn of the main run loop
    RunLoop.main.run(until: Date())

    // when: a block of the time 1000 reads the clock before anything else in the turn does, then the clock is read after
    // the block
    let givenRead = AnimationClock.sharingTime(at: 1000) { AnimationClock.now }
    let timeBefore = CACurrentMediaTime()
    let turnRead = AnimationClock.now

    // then: the block's time doesn't become the turn's, so the turn's first read is the media time
    expect(givenRead) == 1000
    expect(turnRead) >= timeBefore
  }

  func test_sharingTimeAt_blockThrows_rethrowsAndRestoresTheTurnsTime() {
    // given: the time of the current turn of the main run loop, and a block of the time 1000 that throws
    struct TestError: Error, Equatable {}
    let turnTime = AnimationClock.now

    // when: running the block
    expect(try AnimationClock.sharingTime(at: 1000) { () throws in
      throw TestError()
    }).to(throwError(TestError()))

    // then: the error is thrown on, and the turn's time is read again
    expect(AnimationClock.now) == turnTime
  }

  func test_sharingTimeAt_offTheMainThread_assertsAndRunsTheBlockWithoutTheTime() {
    // given: a time far ahead of the media time
    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }
    let givenTime = CACurrentMediaTime() + 1000

    // when: running a block of the time on a background thread
    let blockDone = XCTestExpectation(description: "block")
    DispatchQueue.global().async {
      AnimationClock.sharingTime(at: givenTime) {
        // then: the block runs, reading the media time instead of the given time
        expect(AnimationClock.now) < givenTime
      }
      blockDone.fulfill()
    }
    wait(for: [blockDone], timeout: 5)

    // then: it asserts, as the given time is main thread state
    expect(assertionMessages) == ["sharingTime(at:_:) must be called on the main thread"]
  }
}

/// A layer that records the clock's time whenever it lays out its sublayers.
private final class ClockReadingLayer: CALayer {

  /// The times the clock read in the layouts, in order.
  var layoutReads: [CFTimeInterval] = []

  override func layoutSublayers() {
    super.layoutSublayers()
    layoutReads.append(AnimationClock.now)
  }
}
