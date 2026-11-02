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

#if canImport(AppKit) && DEBUG
import AppKit

import ChouTiTest

@testable import ComposeUI

/// Tests for the animation that moves a scroll view's content for the keyboard.
///
/// The display link of a window that isn't on screen doesn't fire, so the tests step the animation at the times that
/// they choose, except for the test of the display link.
class KeyboardScrollAnimationTests: XCTestCase {

  override func setUp() {
    super.setUp()

    // the keys scroll without the animation when the user reduces motion, as the machine that runs the tests may
    ScrollView.scrollsWithKeyboardAnimationForTesting = true
  }

  override func tearDown() {
    ScrollView.scrollsWithKeyboardAnimationForTesting = nil

    super.tearDown()
  }

  // MARK: - Held Keys

  func test_keyHeldDown_movesTheContentFromTheFirstFrameUpToTheTopSpeed() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view in a window, showing content 10000 tall, with the focus in it
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 10000))

    // when: the down arrow goes down, and frames step the animation for half a second, while the key repeats, as it does
    // after the system's delay
    window.keyDown(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    var offsets: [CGFloat] = []
    var frame = 1
    while frame <= 60 {
      let time = Constants.startTime + TimeInterval(frame) * KeyboardScrollAnimation.testFrameDuration
      if frame == 40 || frame == 50 {
        window.keyDown(.down, at: time, isARepeat: true)
      }
      animation.step(at: time)
      offsets.append(scrollView.contentOffset.y)
      frame += 1
    }

    // then: each frame shows the content where the push of a key held down moves it, from the start, which the repeats
    // don't change, up to the top speed of 1000 points per second, by the same distance on each frame, to the pixel
    var physics = KeyboardScrollPhysics(position: .zero, time: Constants.startTime)
    physics.startPush(toward: .down, step: 40)
    var expectedOffsets: [CGFloat] = []
    frame = 1
    while frame <= 60 {
      let time = Constants.startTime + TimeInterval(frame) * KeyboardScrollAnimation.testFrameDuration
      physics.advance(to: time, in: scrollView.keyboardScrollRange)
      expectedOffsets.append(physics.position(at: time).rounded(toPixelSize: scrollView.pixelSize).y)
      frame += 1
    }
    expect(offsets) == expectedOffsets
    expect(offsets[2]) > 0
    expect(offsets[59] - offsets[58]).to(beApproximatelyEqual(to: 1000 * KeyboardScrollAnimation.testFrameDuration, within: scrollView.pixelSize.height))
    expect(animation.isKeyHeld) == true
  }

  func test_tap_movesTheContentAStep() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, with the focus in it
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1000))

    // when: the down arrow goes down and up at once, and frames step the animation until it stops
    window.keyDown(.down, at: Constants.startTime)
    window.keyUp(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    let offsets = animation.stepFrames(in: scrollView, from: Constants.startTime)

    // then: the content comes to rest a step down, without passing it
    expect(animation.isKeyHeld) == false
    expect(animation.isRunning) == false
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 40)
    expect(offsets.map(\.y).max()) == 40
  }

  func test_keyGoesUp_atTheTopSpeed_bringsTheContentToRestWhereTheSpringTakesItsSpeed() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, with the down arrow held down for a quarter of a second
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 10000))
    window.keyDown(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.stepFrames(in: scrollView, from: Constants.startTime, until: Constants.startTime + 0.25)

    // when: the key goes up, and frames step the animation until it stops
    let releaseTime = Constants.startTime + 0.25
    window.keyUp(.down, at: releaseTime)
    let offsets = animation.stepFrames(in: scrollView, from: releaseTime)

    // then: the content comes to rest where the push's motion does, past the minimum step, without passing it
    var physics = KeyboardScrollPhysics(position: .zero, time: Constants.startTime)
    physics.startPush(toward: .down, step: 40)
    physics.advance(to: releaseTime, in: scrollView.keyboardScrollRange)
    physics.endPush(in: scrollView.keyboardScrollRange)
    let restingOffset = physics.restingOffset(in: scrollView.keyboardScrollRange)
    expect(restingOffset.y) > 150
    expect(scrollView.contentOffset) == restingOffset
    expect(offsets.map(\.y).max()) == restingOffset.y
    expect(animation.isRunning) == false
  }

  func test_keyDown_whileAKeyIsHeld_doesNothing() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, with the down arrow held down for a tenth of a second
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 10000))
    window.keyDown(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.stepFrames(in: scrollView, from: Constants.startTime, until: Constants.startTime + 0.1)

    // when: the up arrow goes down too, and frames step the animation
    window.keyDown(.up, at: Constants.startTime + 0.1)
    animation.stepFrames(in: scrollView, from: Constants.startTime + 0.1, until: Constants.startTime + 0.2)

    // then: the down arrow keeps pushing the content down alone
    var physics = KeyboardScrollPhysics(position: .zero, time: Constants.startTime)
    physics.startPush(toward: .down, step: 40)
    physics.advance(to: Constants.startTime + 0.2, in: scrollView.keyboardScrollRange)
    expect(animation.isKeyHeld) == true
    expect(scrollView.contentOffset) == physics.position(at: Constants.startTime + 0.2).rounded(toPixelSize: scrollView.pixelSize)
  }

  func test_pressDuringTheSpring_goesOnFromWhereTheContentIsAsFastAsItMoves() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, whose content moves down after the down arrow went up at speed
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 10000))
    window.keyDown(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.stepFrames(in: scrollView, from: Constants.startTime, until: Constants.startTime + 0.1)
    window.keyUp(.down, at: Constants.startTime + 0.1)
    animation.stepFrames(in: scrollView, from: Constants.startTime + 0.1, until: Constants.startTime + 0.15)

    // when: the down arrow goes down again, and frames step the animation
    window.keyDown(.down, at: Constants.startTime + 0.15)
    animation.stepFrames(in: scrollView, from: Constants.startTime + 0.15, until: Constants.startTime + 0.3)

    // then: the content moves as one motion that the second push joins, keeping its position and speed
    var physics = KeyboardScrollPhysics(position: .zero, time: Constants.startTime)
    let range = scrollView.keyboardScrollRange
    physics.startPush(toward: .down, step: 40)
    physics.advance(to: Constants.startTime + 0.1, in: range)
    physics.endPush(in: range)
    physics.advance(to: Constants.startTime + 0.15, in: range)
    physics.startPush(toward: .down, step: 40)
    physics.advance(to: Constants.startTime + 0.3, in: range)
    expect(scrollView.contentOffset) == physics.position(at: Constants.startTime + 0.3).rounded(toPixelSize: scrollView.pixelSize)
  }

  // MARK: - End of a Press

  func test_keyUpOfAnotherKey_endsThePress() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, with the down arrow held down
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 10000))
    window.keyDown(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)

    // when: another key goes up
    window.keyUp(.up, at: Constants.startTime + 0.05)

    // then: the push ends, as any key going up ends it, and the content comes to rest a step down
    expect(animation.isKeyHeld) == false
    animation.stepFrames(in: scrollView, from: Constants.startTime + 0.05)
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 40)
  }

  func test_windowLosesTheKeyboard_endsThePress() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, with the down arrow held down
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 10000))
    window.keyDown(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)

    // when: another window loses the keyboard
    AnimationClock.sharingTime(at: Constants.startTime + 0.05) {
      NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: TestWindow())
    }

    // then: the push goes on
    expect(animation.isKeyHeld) == true

    // when: the scroll view's window loses the keyboard, where the key going up doesn't reach the scroll view
    AnimationClock.sharingTime(at: Constants.startTime + 0.05) {
      NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
    }

    // then: the push ends, and the content comes to rest a step down
    expect(animation.isKeyHeld) == false
    animation.stepFrames(in: scrollView, from: Constants.startTime + 0.05)
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 40)

    // when: the window loses the keyboard again, once the push ended
    NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)

    // then: the content stays at rest
    expect(animation.isRunning) == false
  }

  func test_modifierKeyDuringAPress_endsThePress() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, with the down arrow held down
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 10000))
    window.keyDown(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)

    // when: the Command key goes down, after which AppKit doesn't send the down arrow going up
    AnimationClock.sharingTime(at: Constants.startTime + 0.05) {
      window.commandKey(isDown: true)
    }

    // then: the push ends, and the content comes to rest a step down
    expect(animation.isKeyHeld) == false
    animation.stepFrames(in: scrollView, from: Constants.startTime + 0.05)
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 40)

    // when: the down arrow repeats with the Command key down, as it does while it's held down
    window.keyDown(.down, at: Constants.startTime + 0.5, isARepeat: true, modifierFlags: .command)

    // then: the repeat doesn't push the content
    expect(animation.isKeyHeld) == false
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 40)
  }

  func test_focusLeavesTheScrollView_endsThePress() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, with the down arrow held down
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 10000))
    window.keyDown(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)

    // when: the focus leaves the scroll view, where the key going up doesn't reach it, and a frame steps the animation
    window.makeFirstResponder(nil)
    animation.step(at: Constants.startTime + KeyboardScrollAnimation.testFrameDuration)

    // then: the push ends, and the content comes to rest a step down
    expect(animation.isKeyHeld) == false
    animation.stepFrames(in: scrollView, from: Constants.startTime + KeyboardScrollAnimation.testFrameDuration)
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 40)
  }

  func test_actionWithoutAKey_actsAsATap() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    for isInWindow in [true, false] {
      // given: a scroll view, in a window or not
      let (_, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1000))
      if !isInWindow {
        scrollView.removeFromSuperview()
      }

      // when: code sends the down arrow's action, which no key going up ends
      AnimationClock.sharingTime(at: Constants.startTime) {
        scrollView.moveDown(nil)
      }

      // then: the action acts as a tap, and the content comes to rest a step down
      let animation = try unwrap(scrollView.keyboardScrollAnimation)
      expect(animation.isKeyHeld) == false
      animation.stepFrames(in: scrollView, from: Constants.startTime)
      expect(scrollView.contentOffset) == CGPoint(x: 0, y: 40)
    }
  }

  // MARK: - Stops

  func test_somethingElseScrolls_stopsTheScroll() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, with the down arrow held down for a tenth of a second
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 10000))
    window.keyDown(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.stepFrames(in: scrollView, from: Constants.startTime, until: Constants.startTime + 0.1)

    // when: something else scrolls the scroll view, such as a trackpad or the app, and a frame steps the animation
    scrollView.contentOffset = CGPoint(x: 0, y: 500)
    animation.step(at: Constants.startTime + 0.11)

    // then: the scroll stops, and the content stays where the other scroll put it
    expect(animation.isRunning) == false
    expect(animation.isKeyHeld) == false
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 500)

    // when: the down arrow repeats, as it does while it's held down
    window.keyDown(.down, at: Constants.startTime + 0.2, isARepeat: true)

    // then: the repeat pushes the content again from where it is, as the key is still down
    expect(animation.isKeyHeld) == true
    animation.stepFrames(in: scrollView, from: Constants.startTime + 0.2, until: Constants.startTime + 0.3)
    expect(scrollView.contentOffset.y) > 500
  }

  func test_scrollingDisabled_bringsStretchedContentIntoTheRangeAndStops() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view at the bottom end, with the down arrow held down, which stretches the content past the end
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1000))
    scrollView.contentOffset = CGPoint(x: 0, y: 900)
    window.keyDown(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.stepFrames(in: scrollView, from: Constants.startTime, until: Constants.startTime + 0.2)
    expect(scrollView.contentOffset.y) > 905

    // when: scrolling is disabled, and a frame steps the animation
    scrollView.isScrollEnabled = false
    animation.step(at: Constants.startTime + 0.21)

    // then: the scroll stops with the content back at the end
    expect(animation.isRunning) == false
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 900)
  }

  func test_somethingElseScrollsAndScrollingIsDisabled_leavesTheContentWhereTheOtherScrollPutIt() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view at the bottom end, with the down arrow held down, which stretches the content past the end
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1000))
    scrollView.contentOffset = CGPoint(x: 0, y: 900)
    window.keyDown(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.stepFrames(in: scrollView, from: Constants.startTime, until: Constants.startTime + 0.2)

    // when: the app scrolls the content past the end and disables scrolling, and a frame steps the animation
    scrollView.contentOffset = CGPoint(x: 0, y: 920)
    scrollView.isScrollEnabled = false
    animation.step(at: Constants.startTime + 0.21)

    // then: the scroll stops, and the content stays where the app put it, since the animation no longer places it
    expect(animation.isRunning) == false
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 920)
  }

  func test_contentShrinks_endingAheadOfTheContent_bringsTheContentToRestAtTheNewEnd() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, whose content moves down toward where it comes to rest, after the down arrow went up at speed
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 10000))
    window.keyDown(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.stepFrames(in: scrollView, from: Constants.startTime, until: Constants.startTime + 0.25)
    window.keyUp(.down, at: Constants.startTime + 0.25)
    let offset = scrollView.contentOffset.y

    // when: the content shrinks, so that the range ends 30 points ahead of the content, short of where it comes to rest,
    // and frames step the animation until it stops
    scrollView.contentSize = CGSize(width: 100, height: offset + 30 + 100)
    let offsets = animation.stepFrames(in: scrollView, from: Constants.startTime + 0.25)

    // then: the content comes to rest at the new end, without passing it
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: offset + 30)
    expect(offsets.map(\.y).max()) == offset + 30
    expect(animation.isRunning) == false
  }

  func test_contentShrinks_endingBehindTheContent_stopsTheScroll() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, whose content moves down after the down arrow went up at speed
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 10000))
    window.keyDown(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.stepFrames(in: scrollView, from: Constants.startTime, until: Constants.startTime + 0.25)
    window.keyUp(.down, at: Constants.startTime + 0.25)
    let offset = scrollView.contentOffset.y

    // when: the content shrinks, so that the range ends 50 points behind the content, and a frame steps the animation
    scrollView.contentSize = CGSize(width: 100, height: offset - 50 + 100)
    animation.step(at: Constants.startTime + 0.26)

    // then: AppKit moves the content to the new end at once, which stops the scroll, as another scroll does
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: offset - 50)
    expect(animation.isRunning) == false
  }

  func test_scrollViewLeavesTheWindow_stopsTheScroll() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, with the down arrow held down
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1000))
    window.keyDown(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)

    // when: the scroll view leaves the window
    scrollView.removeFromSuperview()

    // then: the scroll stops, since its display link follows the window
    expect(animation.isRunning) == false
    expect(animation.isKeyHeld) == false

    // when: the scroll view moves into a window again
    window.contentView().addSubview(scrollView)

    // then: the scroll stays stopped
    expect(animation.isRunning) == false
  }

  func test_scrollViewGoes_releasesTheScroll() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view, with the down arrow held down, which the scroll view's animation holds
    weak var weakAnimation: KeyboardScrollAnimation?
    try autoreleasepool {
      let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1000))
      window.keyDown(.down, at: Constants.startTime)
      let animation = try unwrap(scrollView.keyboardScrollAnimation)
      weakAnimation = animation
      expect(animation.isRunning) == true

      // when: the scroll view goes
      scrollView.removeFromSuperview()
    }

    // then: the animation goes with it, since the stopped display link no longer holds it
    expect(weakAnimation) == nil
  }

  // MARK: - Page Keys

  func test_pageKey_glidesTheContentByAPage_easingInAndOut() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view, with the focus in it
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1000))

    // when: the page down key goes down and up, and frames step the animation a quarter, half and all of the way through
    // the glide, which takes 80 ms for a page of 80% of the height, at 1000 points per second
    window.keyDown(.pageDown, at: Constants.startTime)
    window.keyUp(.pageDown, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    expect(animation.isKeyHeld) == false
    animation.step(at: Constants.startTime + 0.02)
    let quarterOffset = scrollView.contentOffset.y
    animation.step(at: Constants.startTime + 0.04)
    let halfOffset = scrollView.contentOffset.y
    animation.step(at: Constants.startTime + 0.09)

    // then: the content eases in, is halfway at half the time, and ends a page down
    expect(quarterOffset) < 20
    expect(halfOffset) == 40
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 80)
    expect(animation.isRunning) == false
  }

  func test_pageKey_duringAGlide_glidesOnFromWhereTheContentIs_easingOut() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view, halfway through the glide of the page down key
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1000))
    window.keyDown(.pageDown, at: Constants.startTime)
    window.keyUp(.pageDown, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.step(at: Constants.startTime + 0.04)
    expect(scrollView.contentOffset.y) == 40

    // when: the page down key goes down and up again, and frames step the animation a quarter and all of the way through
    // the new glide
    window.keyDown(.pageDown, at: Constants.startTime + 0.04)
    window.keyUp(.pageDown, at: Constants.startTime + 0.04)
    animation.step(at: Constants.startTime + 0.06)
    let quarterOffset = scrollView.contentOffset.y
    animation.step(at: Constants.startTime + 0.13)

    // then: the content glides a page on from where it was, easing out, so it moves faster than evenly at first
    expect(quarterOffset) > 40 + 80 / 4
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 120)
    expect(animation.isRunning) == false
  }

  func test_pageKey_heldDown_pushesTheContentByPages() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view, after the glide of the page down key, which is still down
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 10000))
    window.keyDown(.pageDown, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.step(at: Constants.startTime + 0.09)
    expect(scrollView.contentOffset.y) == 80

    // when: the key repeats, as it does while it's held down, and frames step the animation for a tenth of a second
    window.keyDown(.pageDown, at: Constants.startTime + 0.5, isARepeat: true)
    expect(animation.isKeyHeld) == true
    animation.stepFrames(in: scrollView, from: Constants.startTime + 0.5, until: Constants.startTime + 0.6)

    // then: the key pushes the content as an arrow key does, by pages, which speeds it up 2 times as fast as a line
    var physics = KeyboardScrollPhysics(position: CGPoint(x: 0, y: 80), time: Constants.startTime + 0.5)
    physics.startPush(toward: .down, step: 80)
    physics.advance(to: Constants.startTime + 0.6, in: scrollView.keyboardScrollRange)
    expect(scrollView.contentOffset) == physics.position(at: Constants.startTime + 0.6).rounded(toPixelSize: scrollView.pixelSize)

    // when: the key goes up, and frames step the animation until it stops
    window.keyUp(.pageDown, at: Constants.startTime + 0.6)
    animation.stepFrames(in: scrollView, from: Constants.startTime + 0.6)

    // then: the content comes to rest at least a page from where the push started
    expect(scrollView.contentOffset.y) >= 160
  }

  func test_contentShrinksDuringAGlide_endingAheadOfTheContent_glidesToTheNewEnd() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view, a quarter of the way through the glide of the page down key to 80
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1000))
    window.keyDown(.pageDown, at: Constants.startTime)
    window.keyUp(.pageDown, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.step(at: Constants.startTime + 0.02)
    let offsetBeforeShrinking = scrollView.contentOffset
    expect(offsetBeforeShrinking.y) < 40

    // when: the content shrinks, so that the range ends at 40, short of the glide's end, and frames step the animation
    // until it stops
    scrollView.contentSize = CGSize(width: 100, height: 140)
    let offsets = animation.stepFrames(in: scrollView, from: Constants.startTime + 0.02)

    // then: the glide turns to the new end, moving the content on from the first frame, and stops there without passing it
    expect(try unwrap(offsets.first).y) > offsetBeforeShrinking.y
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 40)
    expect(offsets.map(\.y).max()) == 40
    expect(animation.isRunning) == false
  }

  func test_contentShrinksOnEachFrameOfAGlide_keepsTheContentMoving() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view whose range ends at 80, at the start of the glide of the page down key to 80
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 180))
    window.keyDown(.pageDown, at: Constants.startTime)
    window.keyUp(.pageDown, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)

    // when: the content shrinks by a point before each of 5 frames, which moves the range's end ahead of the content
    // from 80 to 75
    var offsets: [CGPoint] = []
    for frame in 1 ... 5 {
      scrollView.contentSize = CGSize(width: 100, height: 180 - CGFloat(frame))
      animation.step(at: Constants.startTime + TimeInterval(frame) * KeyboardScrollAnimation.testFrameDuration)
      offsets.append(scrollView.contentOffset)
    }

    // then: the content moves on each frame, though the glide turns to a new end on each of them
    expect(try unwrap(offsets.first).y) > 0
    for index in 1 ..< offsets.count {
      expect(offsets[index].y) > offsets[index - 1].y
    }

    // when: frames step the animation until it stops
    let restingOffsets = animation.stepFrames(in: scrollView, from: Constants.startTime + 5 * KeyboardScrollAnimation.testFrameDuration)

    // then: the content comes to rest at the new end without passing it
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 75)
    expect(restingOffsets.map(\.y).max()) == 75
    expect(animation.isRunning) == false
  }

  func test_arrowKey_duringAGlide_pushesFromWhereTheContentIs() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view, halfway through the glide of the page down key
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1000))
    window.keyDown(.pageDown, at: Constants.startTime)
    window.keyUp(.pageDown, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.step(at: Constants.startTime + 0.04)

    // when: the down arrow goes down and up, and frames step the animation until it stops
    window.keyDown(.down, at: Constants.startTime + 0.04)
    window.keyUp(.down, at: Constants.startTime + 0.04)
    animation.stepFrames(in: scrollView, from: Constants.startTime + 0.04)

    // then: the glide stops, and the content comes to rest a step from where the glide had it
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 80)
  }

  func test_pageKey_duringASpring_glidesFromWhereTheContentIs() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view, whose content moves after a tap of the down arrow
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1000))
    window.keyDown(.down, at: Constants.startTime)
    window.keyUp(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.step(at: Constants.startTime + 0.05)
    let offset = scrollView.contentOffset.y
    expect(offset) > 0
    expect(offset) < 40

    // when: the page down key goes down and up, and frames step the animation until it stops
    window.keyDown(.pageDown, at: Constants.startTime + 0.05)
    window.keyUp(.pageDown, at: Constants.startTime + 0.05)
    animation.stepFrames(in: scrollView, from: Constants.startTime + 0.05)

    // then: the spring stops, and the content glides a page from where it was
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: offset + 80)
  }

  func test_arrowKey_onTheOtherAxisDuringAGlide_leavesTheGlideItsPage() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view of content that scrolls both ways, a quarter of the way through the glide of the page
    // down key to 80, which ends at 80 ms
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 1000, height: 1000))
    window.keyDown(.pageDown, at: Constants.startTime)
    window.keyUp(.pageDown, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.step(at: Constants.startTime + 0.02)
    expect(scrollView.contentOffset.y) > 0
    expect(scrollView.contentOffset.y) < 40

    // when: the right arrow goes down, and frames step the animation until after the glide's end
    window.keyDown(.right, at: Constants.startTime + 0.02)
    let offsets = animation.stepFrames(in: scrollView, from: Constants.startTime + 0.02, until: Constants.startTime + 0.2)

    // then: the glide goes on to its page, where the content stays, while the key pushes the content to the right
    expect(offsets.map(\.y)) == offsets.map(\.y).sorted()
    expect(try unwrap(offsets.last).y) == 80
    expect(try unwrap(offsets.last).x) > 40

    // when: the key goes up, and frames step the animation until it stops
    window.keyUp(.right, at: Constants.startTime + 0.2)
    animation.stepFrames(in: scrollView, from: Constants.startTime + 0.2)

    // then: the content comes to rest a page down, and to the right
    expect(scrollView.contentOffset.y) == 80
    expect(scrollView.contentOffset.x) > 40
    expect(animation.isRunning) == false
  }

  func test_pageKey_duringTheSpringOfATapOnTheOtherAxis_leavesTheTapItsStep() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view of content that scrolls both ways, whose content moves to the right after a tap of
    // the right arrow
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 1000, height: 1000))
    window.keyDown(.right, at: Constants.startTime)
    window.keyUp(.right, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.step(at: Constants.startTime + 0.02)
    let tapOffset = scrollView.contentOffset
    expect(tapOffset.x) > 0
    expect(tapOffset.x) < 40

    // when: the page down key goes down and up before the content rests, and frames step the animation for 20 ms
    window.keyDown(.pageDown, at: Constants.startTime + 0.02)
    window.keyUp(.pageDown, at: Constants.startTime + 0.02)
    animation.stepFrames(in: scrollView, from: Constants.startTime + 0.02, until: Constants.startTime + 0.04)

    // then: the spring goes on moving the content to the right while the glide moves it down
    let offset = scrollView.contentOffset
    expect(offset.x) > tapOffset.x
    expect(offset.y) > 0

    // when: the page down key goes down and up again during the glide, and frames step the animation until it stops
    window.keyDown(.pageDown, at: Constants.startTime + 0.04)
    window.keyUp(.pageDown, at: Constants.startTime + 0.04)
    let offsets = animation.stepFrames(in: scrollView, from: Constants.startTime + 0.04)

    // then: the content comes to rest a whole step to the right without passing it, and a page down from where the
    // second glide started
    expect(scrollView.contentOffset) == CGPoint(x: 40, y: offset.y + 80)
    expect(offsets.map(\.x).max()) == 40
    expect(animation.isRunning) == false
  }

  func test_horizontalGlide_duringTheSpringOfATapOnTheOtherAxis_leavesTheTapItsStep() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view of content that scrolls both ways, whose content moves down after a tap of the down
    // arrow
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 1000, height: 1000))
    window.keyDown(.down, at: Constants.startTime)
    window.keyUp(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.step(at: Constants.startTime + 0.02)
    expect(scrollView.contentOffset.y) > 0
    expect(scrollView.contentOffset.y) < 40

    // when: the content glides 80 points to the right before it rests, and frames step the animation until it stops
    animation.glide(toward: .right, by: 80, at: Constants.startTime + 0.02)
    let offsets = animation.stepFrames(in: scrollView, from: Constants.startTime + 0.02)

    // then: the content comes to rest 80 points to the right, and a whole step down without passing it
    expect(scrollView.contentOffset) == CGPoint(x: 80, y: 40)
    expect(offsets.map(\.y).max()) == 40
    expect(animation.isRunning) == false
  }

  func test_arrowKey_alongAGlidesAxis_whileATapSpringsOnTheOtherAxis_pushesFromWhereTheGlideHasTheContent() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view of content that scrolls both ways, with the spring of a tap of the right arrow, and
    // halfway through the glide of the page down key that went down during the spring
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 1000, height: 1000))
    window.keyDown(.right, at: Constants.startTime)
    window.keyUp(.right, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.step(at: Constants.startTime + 0.02)
    window.keyDown(.pageDown, at: Constants.startTime + 0.02)
    window.keyUp(.pageDown, at: Constants.startTime + 0.02)
    animation.step(at: Constants.startTime + 0.06)
    let glideOffset = scrollView.contentOffset
    expect(glideOffset.x) < 40
    expect(glideOffset.y) > 0
    expect(glideOffset.y) < 80

    // when: the down arrow goes down and up, and frames step the animation until it stops
    window.keyDown(.down, at: Constants.startTime + 0.06)
    window.keyUp(.down, at: Constants.startTime + 0.06)
    animation.stepFrames(in: scrollView, from: Constants.startTime + 0.06)

    // then: the glide stops, and the content comes to rest a step down from where the glide had it, and a whole step to
    // the right
    expect(scrollView.contentOffset) == CGPoint(x: 40, y: glideOffset.y + 40)
    expect(animation.isRunning) == false
  }

  func test_pageKey_withTheOtherAxisOutsideTheRange_bringsItBackIntoTheRange() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view of content that scrolls both ways to 900, set 50 points past the right end
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 1000, height: 1000))
    scrollView.contentOffset = CGPoint(x: 950, y: 0)

    // when: the page down key goes down and up, and frames step the animation until it stops
    window.keyDown(.pageDown, at: Constants.startTime)
    window.keyUp(.pageDown, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    let offsets = animation.stepFrames(in: scrollView, from: Constants.startTime)

    // then: the content glides a page down, and the spring brings it back to the right end without passing it
    expect(scrollView.contentOffset) == CGPoint(x: 900, y: 80)
    expect(offsets.map(\.x).min()) == 900
    expect(animation.isRunning) == false
  }

  func test_rangeChangeOnTheOtherAxisDuringAGlide_leavesTheGlide() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    /// Returns the vertical offsets of the frames of a glide 400 points down, during which a tap of a key that pushes
    /// the content left moves it from 200, and the content narrows on the frame that the content passes 190, when it
    /// does.
    func verticalOffsets(narrowing: Bool) -> [CGFloat] {
      let (_, scrollView) = makeScrollView(contentSize: CGSize(width: 1000, height: 1000))
      scrollView.contentOffset = CGPoint(x: 200, y: 0)
      let animation = KeyboardScrollAnimation(scrollView: scrollView)
      animation.glide(toward: .down, by: 400, at: Constants.startTime)
      animation.step(at: Constants.startTime + 0.01)
      animation.pressKey(toward: .left, step: 40, at: Constants.startTime + 0.01)
      animation.releaseKey(at: Constants.startTime + 0.01)

      var offsets: [CGFloat] = []
      var frame = 1
      while frame <= 30, animation.isRunning {
        if narrowing, scrollView.contentOffset.x < 190, scrollView.contentSize.width == 1000 {
          scrollView.contentSize = CGSize(width: 290, height: 1000)
        }
        animation.step(at: Constants.startTime + 0.01 + TimeInterval(frame) * KeyboardScrollAnimation.testFrameDuration)
        offsets.append(scrollView.contentOffset.y)
        frame += 1
      }
      return offsets
    }

    // given: the frames of a glide down, during which a tap moves the content left
    let offsets = verticalOffsets(narrowing: false)

    // when: the content narrows during the glide, so that the horizontal range ends at 190, ahead of the content
    let narrowedOffsets = verticalOffsets(narrowing: true)

    // then: the glide moves the content down on the same frames, to its destination
    expect(narrowedOffsets) == offsets
    expect(offsets.last) == 400
  }

  func test_pageKey_afterSomethingElseScrolls_glidesFromWhereTheContentIs_atRest() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view of content that scrolls both ways, whose content moves to the right after a tap of
    // the right arrow
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 1000, height: 1000))
    window.keyDown(.right, at: Constants.startTime)
    window.keyUp(.right, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.step(at: Constants.startTime + 0.02)
    expect(scrollView.contentOffset.x) > 0

    // when: something else scrolls the scroll view, the page down key goes down and up, and frames step the animation
    // until it stops
    scrollView.contentOffset = CGPoint(x: 0, y: 300)
    window.keyDown(.pageDown, at: Constants.startTime + 0.02)
    window.keyUp(.pageDown, at: Constants.startTime + 0.02)
    let offsets = animation.stepFrames(in: scrollView, from: Constants.startTime + 0.02)

    // then: the tap's spring stops where the other scroll put the content, and the content glides a page down from there
    expect(offsets.map(\.x).max()) == 0
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 380)
  }

  // MARK: - Edge Glides

  func test_arrowKeyWithCommand_glidesToTheEdgeAlongASpring() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view at the top of content 1100 tall, which scrolls to 1000
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1100))

    // when: the down arrow goes down and up with Command, and frames step the animation until it stops
    window.keyDown(.down, at: Constants.startTime, modifierFlags: .command)
    window.keyUp(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    let offsets = animation.stepFrames(in: scrollView, from: Constants.startTime)

    // then: each frame shows the content on whole pixels where a critically damped spring with a response of 0.6 s has
    // it, with its time warped along cubic-bezier(0, 0.2, 1, 1) over 1.6 s, which starts it at speed, until the content
    // is within a quarter of a pixel of the bottom edge, where it rests after about a second
    let timeWarp = AnimationCurve(timingFunction: CAMediaTimingFunction(controlPoints: 0, 0.2, 1, 1), duration: 1.6)
    let angularFrequency = 2 * Double.pi / 0.6
    let pixelHeight = scrollView.pixelSize.height
    var expectedOffsets: [CGFloat] = []
    var frame = 1
    while true {
      let elapsedTime = Constants.startTime + Double(frame) * KeyboardScrollAnimation.testFrameDuration - Constants.startTime
      let warpedTime = timeWarp.progress(forElapsedTime: elapsedTime) * 1.6
      let offset = 1000 * CGFloat(1 - exp(-angularFrequency * warpedTime) * (1 + angularFrequency * warpedTime))
      if 1000 - offset < pixelHeight / 4 {
        expectedOffsets.append(1000)
        break
      }
      expectedOffsets.append((offset / pixelHeight).rounded() * pixelHeight)
      frame += 1
    }
    expect(offsets.map(\.y)) == expectedOffsets
    expect(Double(offsets.count) * KeyboardScrollAnimation.testFrameDuration) < 1.1
    expect(animation.isKeyHeld) == false
    expect(animation.isRunning) == false
  }

  func test_contentShrinksDuringAnEdgeGlide_turnsToTheNewEdgeAlongTheSpring() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view at the top of content 1100 tall, 50 ms into the glide of the down arrow with
    // Command to the bottom edge at 1000
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1100))
    window.keyDown(.down, at: Constants.startTime, modifierFlags: .command)
    window.keyUp(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.step(at: Constants.startTime + 0.05)
    expect(scrollView.contentOffset.y) > 0
    expect(scrollView.contentOffset.y) < 600

    // when: the content shrinks, so that the range ends at 600, and frames step the animation until it stops
    scrollView.contentSize = CGSize(width: 100, height: 700)
    let offsets = animation.stepFrames(in: scrollView, from: Constants.startTime + 0.05)

    // then: the glide turns to the new edge, where the spring brings the content to rest without passing it, for longer
    // than the 200 ms of a page's glide
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 600)
    expect(offsets.map(\.y).max()) == 600
    expect(Double(offsets.count) * KeyboardScrollAnimation.testFrameDuration) > 0.3
  }

  func test_contentGrowsDuringAnEdgeGlide_goesOnToTheNewEdge() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view at the top of content 1100 tall, 50 ms into the glide of the down arrow with
    // Command to the bottom edge at 1000
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1100))
    window.keyDown(.down, at: Constants.startTime, modifierFlags: .command)
    window.keyUp(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.step(at: Constants.startTime + 0.05)
    expect(scrollView.contentOffset.y) > 0

    // when: the content grows, so that the range ends at 1500, such as when more rows load, and frames step the
    // animation until it stops
    scrollView.contentSize = CGSize(width: 100, height: 1600)
    let offsets = animation.stepFrames(in: scrollView, from: Constants.startTime + 0.05)

    // then: the glide goes on to the new edge, where the spring brings the content to rest without passing it
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 1500)
    expect(offsets.map(\.y).max()) == 1500
    expect(offsets.map(\.y)) == offsets.map(\.y).sorted()
  }

  func test_contentGrowsOnEachFrameOfAnEdgeGlide_endsTheGlideAtTheEdge1600MsAfterTheKey() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view at the top of content 1100 tall, with the glide of the down arrow with Command to
    // the bottom edge at 1000
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1100))
    window.keyDown(.down, at: Constants.startTime, modifierFlags: .command)
    window.keyUp(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)

    // when: the content grows by 10 points before each frame, for up to 3 s, such as a log that streams in
    var frame = 1
    while frame <= 360, animation.isRunning {
      scrollView.contentSize = CGSize(width: 100, height: 1100 + 10 * CGFloat(frame))
      animation.step(at: Constants.startTime + TimeInterval(frame) * KeyboardScrollAnimation.testFrameDuration)
      frame += 1
    }

    // then: the glide follows the edge, which the spring trails, and ends 1.6 s after the key, with the content at the
    // edge of its last frame
    let lastFrame = frame - 1
    expect(TimeInterval(lastFrame) * KeyboardScrollAnimation.testFrameDuration).to(beApproximatelyEqual(to: 1.6, within: KeyboardScrollAnimation.testFrameDuration))
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 1000 + 10 * CGFloat(lastFrame))
    expect(animation.isRunning) == false
  }

  func test_frameAfterTheLongestDurationOfAnEdgeGlide_bringsTheContentToTheEdge() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view at the top of content 1100 tall, with the glide of the down arrow with Command to
    // the bottom edge at 1000
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1100))
    window.keyDown(.down, at: Constants.startTime, modifierFlags: .command)
    window.keyUp(.down, at: Constants.startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)

    // when: the first frame comes 2 s after the key, past the glide's longest duration of 1.6 s
    animation.step(at: Constants.startTime + 2)

    // then: the glide ends with the content at the edge
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 1000)
    expect(animation.isRunning) == false
  }

  func test_arrowKeyWithCommand_repeat_leavesTheGlideOfItsPress() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: two 100 × 100 scroll views at the top of content 1100 tall, each 100 ms into the glide of the down arrow
    // with Command to the bottom edge, whose key is still down
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1100))
    let (otherWindow, otherScrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1100))
    window.keyDown(.down, at: Constants.startTime, modifierFlags: .command)
    otherWindow.keyDown(.down, at: Constants.startTime, modifierFlags: .command)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    let otherAnimation = try unwrap(otherScrollView.keyboardScrollAnimation)
    animation.step(at: Constants.startTime + 0.1)
    otherAnimation.step(at: Constants.startTime + 0.1)

    // when: the key repeats in one of them, and frames step both animations until they stop
    window.keyDown(.down, at: Constants.startTime + 0.1, isARepeat: true, modifierFlags: .command)
    let offsets = animation.stepFrames(in: scrollView, from: Constants.startTime + 0.1)
    let otherOffsets = otherAnimation.stepFrames(in: otherScrollView, from: Constants.startTime + 0.1)

    // then: the repeat leaves the glide, which moves the content as the glide without a repeat does, to the edge
    expect(offsets) == otherOffsets
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 1000)
    expect(animation.isKeyHeld) == false
  }

  // MARK: - Display Link

  func test_displayLink_movesTheContent() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view in a window on screen, whose display link fires
    let (window, scrollView) = makeScrollView(contentSize: CGSize(width: 100, height: 1000))
    window.orderFront(nil)
    defer {
      window.orderOut(nil)
    }

    // when: the down arrow goes down and up
    window.keyDown(.down)
    window.keyUp(.down)

    // then: the display link moves the content a step down, and stops once it rests
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    expect(scrollView.contentOffset).toEventually(beEqual(to: CGPoint(x: 0, y: 40)))
    expect(animation.isRunning).toEventually(beFalse())
  }

  // MARK: - Helpers

  /// Makes a 100 × 100 scroll view in a window, showing content of a size, with the focus in it.
  ///
  /// - Parameter contentSize: The size of the content.
  /// - Returns: The window and the scroll view.
  private func makeScrollView(contentSize: CGSize) -> (TestWindow, ScrollView) {
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = contentSize
    window.contentView().addSubview(scrollView)
    window.makeFirstResponder(scrollView)
    return (window, scrollView)
  }

  // MARK: - Constants

  private enum Constants {

    /// The time that a test's first key goes down at.
    static let startTime: CFTimeInterval = 1000
  }
}
#endif
