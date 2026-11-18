//
//  AnimationClock.swift
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

import Foundation
import QuartzCore

/// The clock the animations ComposeUI adds begin on.
///
/// Every animation ComposeUI adds gets its begin time from this clock, except while `addsAtCommit` is on, instead of
/// leaving it for Core Animation to set when the transaction commits. An animation left without a begin time can start
/// on screen a few milliseconds after the begin time Core Animation records on it, so anything computed later from the
/// recorded time, such as a path that follows an in-flight frame animation, would be off by that delay. A begin time
/// that is set is honored as it is, at the cost of the first frame showing the animation as far in as the time from
/// adding it to that frame.
///
/// On the main thread, the clock reads one time per turn of the main run loop: the first read in a turn reads the media
/// time, and the later reads return it until Core Animation has committed the turn's changes. The changes of a turn
/// reach the screen together, so the animations added in a turn begin together, and the in-flight animations evaluated
/// in a turn are evaluated at the time the new ones begin: an update right after another one in the same turn finds
/// that no time has passed, as the screen does. The animations added late in a long turn begin that much in the past,
/// including the ones added after a `CATransaction.flush()`, which commits without ending the turn. Where the main run
/// loop doesn't turn, such as between the test methods XCTest runs, the time holds until it turns.
enum AnimationClock {

  /// Whether the animations that ComposeUI adds without a delay begin at the commit, as UIKit's do, instead of at the
  /// turn's time, also outside a commit window, see `addsAtCommit`. Main thread only.
  ///
  /// Such an animation has a begin time of zero until the commit, which evaluations take as their current time.
  @exclusivity(unchecked)
  static var beginsAtCommit = false

  /// The animations of UIKit's whose commits close the open commit windows, see `waitForCommit(of:on:)`.
  @exclusivity(unchecked)
  private static var commitWindows: [CommitWindow] = []

  /// Whether the animations that ComposeUI adds now without a delay begin at the commit: while `beginsAtCommit` is on,
  /// or a commit window is open. Main thread only.
  static var addsAtCommit: Bool {
    if beginsAtCommit {
      return true
    } else if commitWindows.isEmpty {
      return false
    } else {
      closeCommittedWindows()
      return !commitWindows.isEmpty
    }
  }

  /// Opens a commit window, in which the animations that ComposeUI adds begin at the commit, until Core Animation
  /// commits an animation of UIKit's.
  ///
  /// UIKit can commit a resize animation, such as a rotation's, in a later turn of the main run loop than the layout
  /// that follows it, and what changes until then commits with it.
  ///
  /// - Parameters:
  ///   - animationKey: The key of the animation.
  ///   - layer: The layer that has the animation.
  static func waitForCommit(of animationKey: String, on layer: CALayer) {
    commitWindows.append(CommitWindow(layer: layer, animationKey: animationKey))
    if turnObservers.isEmpty {
      observeTurns()
    }
  }

  #if DEBUG
  /// The number of commit windows open, without closing the committed ones, for tests.
  static var commitWindowCount: Int {
    commitWindows.count
  }
  #endif

  /// Closes the commit windows whose animations were committed or removed.
  private static func closeCommittedWindows() {
    commitWindows.removeAll { window in
      guard let animation = window.layer?.animation(forKey: window.animationKey) else {
        return true
      }
      return animation.beginTime != 0
    }
  }

  /// The time of the current turn of the main run loop, `nil` until the turn's first read.
  private static var turnTime: CFTimeInterval?

  /// The main run loop observers that end the turns, installed at the first read.
  private static var turnObservers: [CFRunLoopObserver] = []

  /// The current media time, see `CACurrentMediaTime()`.
  ///
  /// On the main thread, it's the time of the first read in the current turn of the main run loop.
  static var now: CFTimeInterval {
    // the turn's time is main thread state, so it needs no synchronization, and ComposeUI renders on the main thread
    guard Thread.isMain else {
      return CACurrentMediaTime()
    }

    #if DEBUG
    if let testTime {
      return testTime
    }
    #endif

    if let turnTime {
      return turnTime
    }

    let time = CACurrentMediaTime()
    turnTime = time
    if turnObservers.isEmpty {
      observeTurns()
    }
    return time
  }

  /// Installs the main run loop observers that end a turn once Core Animation has committed its changes.
  private static func observeTurns() {
    // Core Animation commits in a main run loop observer of order 2000000, before the loop waits and when it exits.
    // this observer is ordered right after it, so the layout the commit runs still reads the turn's time, and anything
    // added after the commit belongs to the next commit and reads a new time
    let commitObserver: CFRunLoopObserver = CFRunLoopObserverCreateWithHandler(
      nil,
      CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.exit.rawValue,
      true,
      Constants.commitObserverOrder,
      { _, _ in
        turnTime = nil
        if !commitWindows.isEmpty {
          closeCommittedWindows()
        }
      }
    )

    // the run loop takes an activity's observers before it calls them, so when the first read happens in one of them,
    // such as a layout Core Animation's commit runs, the observer above misses that commit, and the time would outlast
    // the wait after it. this observer ends the turn when the loop wakes too, before the wake's other observers
    let wakeObserver: CFRunLoopObserver = CFRunLoopObserverCreateWithHandler(
      nil,
      CFRunLoopActivity.afterWaiting.rawValue,
      true,
      Constants.wakeObserverOrder,
      { _, _ in
        turnTime = nil
      }
    )

    turnObservers = [commitObserver, wakeObserver]
    for observer in turnObservers {
      CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }
  }

  #if DEBUG
  /// The time `sharingTime(at:_:)` gives the reads, which overrides the turn's time.
  private static var testTime: CFTimeInterval?

  /// Execute the block with every read of `now` returning the given time, for tests.
  ///
  /// The time holds for the whole block, across turns of the main run loop, and a nested block's time overrides it.
  ///
  /// - Parameters:
  ///   - time: The media time the reads return.
  ///   - block: The block to execute.
  /// - Returns: The result of the block.
  static func sharingTime<T>(at time: CFTimeInterval, _ block: () throws -> T) rethrows -> T {
    guard Thread.isMain else {
      ComposeUI.assertFailure("sharingTime(at:_:) must be called on the main thread")
      return try block()
    }

    let outerTime = testTime
    testTime = time
    defer {
      testTime = outerTime
    }
    return try block()
  }

  /// Removes the main run loop observers and forgets the turn's time, so the next read is the first one, for tests.
  static func resetForTesting() {
    for observer in turnObservers {
      CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
    }
    turnObservers = []
    turnTime = nil
  }
  #endif

  /// An animation of UIKit's whose commit closes a commit window.
  private struct CommitWindow {

    /// The layer that has the animation.
    weak var layer: CALayer?

    /// The key of the animation.
    let animationKey: String

    /// Creates a commit window.
    ///
    /// - Parameters:
    ///   - layer: The layer that has the animation.
    ///   - animationKey: The key of the animation.
    init(layer: CALayer, animationKey: String) {
      self.layer = layer
      self.animationKey = animationKey
    }
  }

  // MARK: - Constants

  private enum Constants {

    /// The order of the main run loop observer that ends a turn at the commit, right after Core Animation's commit
    /// observer.
    static let commitObserverOrder: CFIndex = 2000001

    /// The order of the main run loop observer that ends a turn when the loop wakes, before any other observer.
    static let wakeObserverOrder: CFIndex = .min
  }
}
