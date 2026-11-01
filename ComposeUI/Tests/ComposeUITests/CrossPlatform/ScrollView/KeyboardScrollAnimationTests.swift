//
//  KeyboardScrollAnimationTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/31/26.
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

#if canImport(AppKit)
import AppKit

import ChouTiTest

@testable import ComposeUI

/// Tests for the animation that moves a scroll view's content for the keyboard on a spring.
///
/// The display link of a window that isn't on screen doesn't fire, so the tests step the animation at the times that they
/// choose, except for the test of the display link.
class KeyboardScrollAnimationTests: XCTestCase {

  func test_scroll_followsTheSpringOfUIKitsKeyboardScrolling() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view in a window, showing content 1000 tall, with the focus in it
    let (window, scrollView) = makeScrollView(contentHeight: 1000)

    // when: pressing the down arrow
    press(.down, in: window, at: Constants.startTime)

    // then: the content starts moving to 40 points down, from where it is
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    expect(animation.isRunning) == true
    expect(animation.target) == CGPoint(x: 0, y: 40)
    expect(scrollView.contentOffset) == .zero

    // when: frames step the animation for a second
    var model = SpringModel(position: 0)
    var offsets: [CGFloat] = []
    for frame in 1 ... Constants.framesPerSecond {
      model.move(toward: 40, for: Constants.frameDuration)
      animation.step(at: Constants.startTime + TimeInterval(frame) * Constants.frameDuration)
      offsets.append(scrollView.contentOffset.y)

      // then: each frame shows the content where UIKit's spring has it, on whole pixels
      expect(abs(scrollView.contentOffset.y - model.position)) <= scrollView.pixelSize.height / 2 + Constants.tolerance
    }

    // then: the content moves down on every frame until it rests at 40 points, without passing them, and the animation stops
    expect(offsets) == offsets.sorted()
    expect(offsets.max()) == 40
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 40)
    expect(animation.isRunning) == false
  }

  func test_scroll_duringAScroll_goesOnFromWhereTheContentIsAsFastAsItMoves() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, 0.1 seconds into a scroll for the down arrow
    let (window, scrollView) = makeScrollView(contentHeight: 1000)
    press(.down, in: window, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.step(at: Constants.startTime + 0.1)
    let offset = scrollView.contentOffset
    expect(offset.y) > 0

    // when: pressing the down arrow again
    press(.down, in: window, at: Constants.startTime + 0.1)

    // then: the target moves on from the target in flight, and the content stays where it is
    expect(animation.target) == CGPoint(x: 0, y: 80)
    expect(scrollView.contentOffset) == offset

    // when: frames step the animation for a second
    var model = SpringModel(position: 0)
    model.move(toward: 40, for: 0.1)
    for frame in 1 ... Constants.framesPerSecond {
      model.move(toward: 80, for: Constants.frameDuration)
      animation.step(at: Constants.startTime + 0.1 + TimeInterval(frame) * Constants.frameDuration)

      // then: the content goes on from where it was, as fast as it moved, to the new target
      expect(abs(scrollView.contentOffset.y - model.position)) <= scrollView.pixelSize.height / 2 + Constants.tolerance
    }

    // then: the content rests at 80 points, the distance of both presses
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 80)
    expect(animation.isRunning) == false
  }

  func test_scroll_keyHeldDown_movesAtASteadySpeed() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, with the down arrow pressed and held down, which repeats the key every 83 ms after half a
    // second, as macOS repeats it by default
    let (window, scrollView) = makeScrollView(contentHeight: 10000)
    press(.down, in: window, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    var repeatTimes = Array(stride(from: Constants.startTime + 0.5, to: Constants.startTime + 1.2, by: 1.0 / 12))

    // when: frames step the animation while the key repeats
    var offsets: [(time: TimeInterval, offset: CGFloat)] = []
    for frame in 1 ... Int(1.2 * Double(Constants.framesPerSecond)) {
      let time = Constants.startTime + TimeInterval(frame) * Constants.frameDuration
      while let repeatTime = repeatTimes.first, repeatTime <= time {
        press(.down, in: window, at: repeatTime)
        repeatTimes.removeFirst()
      }
      animation.step(at: time)
      offsets.append((time, scrollView.contentOffset.y))
    }

    // then: once the key has repeated a few times, the content moves on every frame by about the distance that the repeats
    // move the target, 40 points every 83 ms, instead of slowing down after each repeat
    let heldOffsets = offsets.filter { $0.time >= Constants.startTime + 0.9 }.map(\.offset)
    let movements = zip(heldOffsets.dropFirst(), heldOffsets).map { $0 - $1 }
    let meanMovement = movements.reduce(0, +) / CGFloat(movements.count)
    expect(meanMovement) > 3
    expect(try unwrap(movements.min())) > meanMovement / 2
  }

  func test_scroll_nearTheEnd_comesToRestAtTheEndWithoutPassingIt() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view that scrolls from 0 to 200, scrolled to 190
    let (window, scrollView) = makeScrollView(contentHeight: 300)
    scrollView.contentOffset = CGPoint(x: 0, y: 190)

    // when: pressing the down arrow, and frames step the animation for a second
    press(.down, in: window, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    var offsets: [CGFloat] = []
    for frame in 1 ... Constants.framesPerSecond {
      animation.step(at: Constants.startTime + TimeInterval(frame) * Constants.frameDuration)
      offsets.append(scrollView.contentOffset.y)
    }

    // then: the target is the end of the range, and the content rests there, without passing it
    expect(animation.target) == CGPoint(x: 0, y: 200)
    expect(offsets.max()) == 200
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 200)
  }

  func test_scroll_fromBetweenPixels_comesToRestOnWholePixels() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, scrolled to a quarter of a pixel
    let (window, scrollView) = makeScrollView(contentHeight: 1000)
    let pixel = scrollView.pixelSize.height
    scrollView.setContentOffsetExactly(CGPoint(x: 0, y: pixel / 4))

    // when: pressing the down arrow
    press(.down, in: window, at: Constants.startTime)

    // then: the content moves to the whole pixel nearest to 40 points from where it is, and rests there
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    expect(animation.target) == CGPoint(x: 0, y: ((40 + pixel / 4) / pixel).rounded() * pixel)
    window.settleKeyboardScrolls()
    expect(scrollView.contentOffset) == animation.target
  }

  func test_step_somethingElseScrolls_stopsTheScroll() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, 50 ms into a scroll for the down arrow
    let (window, scrollView) = makeScrollView(contentHeight: 1000)
    press(.down, in: window, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.step(at: Constants.startTime + 0.05)

    // when: something else scrolls the scroll view, such as a trackpad or the app, and a frame steps the animation
    scrollView.contentOffset = CGPoint(x: 0, y: 500)
    animation.step(at: Constants.startTime + 0.1)

    // then: the scroll stops, and the content stays where the other scroll put it
    expect(animation.isRunning) == false
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 500)

    // when: a scroll for the down arrow is in flight, something else scrolls the scroll view, and the down arrow is
    // pressed before the next frame
    press(.down, in: window, at: Constants.startTime + 1)
    animation.step(at: Constants.startTime + 1.05)
    scrollView.contentOffset = CGPoint(x: 0, y: 100)
    press(.down, in: window, at: Constants.startTime + 1.06)

    // then: the key starts the scroll over from where the content is, instead of from the target of the scroll in flight
    expect(animation.isRunning) == true
    expect(animation.target) == CGPoint(x: 0, y: 140)
    window.settleKeyboardScrolls()
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 140)
  }

  func test_step_scrollingDisabled_stopsTheScroll() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, 50 ms into a scroll for the down arrow
    let (window, scrollView) = makeScrollView(contentHeight: 1000)
    press(.down, in: window, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.step(at: Constants.startTime + 0.05)
    let offset = scrollView.contentOffset

    // when: scrolling is disabled, and a frame steps the animation
    scrollView.isScrollEnabled = false
    animation.step(at: Constants.startTime + 0.1)

    // then: the scroll stops where the content is
    expect(animation.isRunning) == false
    expect(scrollView.contentOffset) == offset
  }

  func test_step_contentShrinksDuringTheScroll_comesToRestInTheNewRange() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, 50 ms into a scroll for the page down key, which goes to 90 points
    let (window, scrollView) = makeScrollView(contentHeight: 1000)
    press(.pageDown, in: window, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    expect(animation.target) == CGPoint(x: 0, y: 90)
    animation.step(at: Constants.startTime + 0.05)
    expect(scrollView.contentOffset.y) < 50

    // when: the content shrinks, so the scroll view scrolls from 0 to 50, and frames step the animation
    scrollView.contentSize = CGSize(width: 100, height: 150)
    animation.step(at: Constants.startTime + 0.1)

    // then: the target moves to the end of the new range, and the content rests there
    expect(animation.target) == CGPoint(x: 0, y: 50)
    window.settleKeyboardScrolls()
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 50)
  }

  func test_scroll_scrollViewLeavesTheWindow_stopsTheScroll() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, in a scroll for the down arrow
    let (window, scrollView) = makeScrollView(contentHeight: 1000)
    press(.down, in: window, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)

    // when: the scroll view leaves the window
    scrollView.removeFromSuperview()

    // then: the scroll stops
    expect(animation.isRunning) == false
  }

  func test_scroll_scrollViewGoes_releasesTheScroll() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view in a window, in a scroll for the down arrow, which its display link keeps
    let window = TestWindow()
    weak var weakAnimation: KeyboardScrollAnimation?
    autoreleasepool {
      let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      scrollView.contentSize = CGSize(width: 100, height: 1000)
      window.contentView().addSubview(scrollView)
      window.makeFirstResponder(scrollView)
      press(.down, in: window, at: Constants.startTime)
      weakAnimation = scrollView.keyboardScrollAnimation
      expect(weakAnimation?.isRunning) == true

      // when: the scroll view is removed from the window and goes, without the scroll ending
      window.makeFirstResponder(nil)
      scrollView.removeFromSuperview()
    }

    // then: the scroll stops and goes with the scroll view
    expect(weakAnimation) == nil
  }

  func test_displayLink_movesTheContentToTheTarget() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view in a window on screen, whose display link fires
    let (window, scrollView) = makeScrollView(contentHeight: 1000)
    window.makeKeyAndOrderFront(nil)
    defer {
      window.orderOut(nil)
    }

    // when: pressing the down arrow
    window.sendEvent(ScrollingKey.down.keyDownEvent(in: window))
    let animation = try unwrap(scrollView.keyboardScrollAnimation)

    // then: the display link moves the content to the target over the frames, and the scroll stops at rest
    expect(scrollView.contentOffset.y) == 0
    expect(scrollView.contentOffset.y).toEventually(beEqual(to: 40))
    expect(animation.isRunning).toEventually(beFalse())
  }

  // MARK: - Helpers

  /// Makes a 100 × 100 scroll view in a window that isn't on screen, showing content of the height, with the focus in it.
  private func makeScrollView(contentHeight: CGFloat) -> (TestWindow, ScrollView) {
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: contentHeight)
    window.contentView().addSubview(scrollView)
    window.makeFirstResponder(scrollView)
    return (window, scrollView)
  }

  /// Presses a key in a window at a time, without settling the scroll that it starts.
  private func press(_ key: ScrollingKey, in window: NSWindow, at time: CFTimeInterval) {
    AnimationClock.sharingTime(at: time) {
      window.sendEvent(key.keyDownEvent(in: window))
    }
  }

  // MARK: - Constants

  private enum Constants {

    /// The time that a test's first key is pressed at.
    static let startTime: CFTimeInterval = 1000

    /// The frames per second that the tests step the animation at.
    static let framesPerSecond = 120

    /// The duration of a frame.
    static let frameDuration: TimeInterval = 1 / TimeInterval(framesPerSecond)

    /// The tolerance of the comparisons with the spring model, which integrates the motion in small steps.
    static let tolerance: CGFloat = 0.01
  }
}

/// The motion of a spring of UIKit's keyboard scrolling, integrated in small steps, which checks the animation's motion
/// in closed form.
private struct SpringModel {

  /// The position.
  private(set) var position: CGFloat

  /// The velocity, in points per second.
  private var velocity: CGFloat = 0

  init(position: CGFloat) {
    self.position = position
  }

  /// Moves the position toward a target for a duration, by the spring's force and damping.
  mutating func move(toward target: CGFloat, for duration: TimeInterval) {
    let step: TimeInterval = 1e-5
    var elapsed: TimeInterval = 0
    while elapsed < duration {
      let delta = min(step, duration - elapsed)
      velocity += (-109 * (position - target) - 20 * velocity) * delta
      position += velocity * delta
      elapsed += delta
    }
  }
}
#endif
