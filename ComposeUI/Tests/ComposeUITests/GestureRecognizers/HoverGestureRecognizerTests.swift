//
//  HoverGestureRecognizerTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 7/20/25.
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

class HoverGestureRecognizerTests: XCTestCase {

  func test_initialization() {
    let recognizer = HoverGestureRecognizer()

    expect(recognizer.isHovering) == false
    expect(recognizer.state) == .possible
  }

  func test_initialization_with_targetAction() {
    let target = TestTarget()
    let recognizer = HoverGestureRecognizer(target: target, action: #selector(TestTarget.handleHover))

    expect(recognizer.target) === target
    expect(recognizer.action) == #selector(TestTarget.handleHover)
    expect(recognizer.isHovering) == false
    expect(recognizer.state) == .possible
  }

  func test_autoTrackingAreaSetup() throws {
    let view = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let recognizer = HoverGestureRecognizer()

    expect(view.trackingAreas.count) == 0

    view.addGestureRecognizer(recognizer)

    expect(view.trackingAreas.count) == 1

    let trackingArea = try view.trackingAreas.first.unwrap()
    expect(trackingArea.rect) == view.bounds
    expect(trackingArea.options == [.activeAlways, .mouseEnteredAndExited, .enabledDuringMouseDrag]) == true
  }

  func test_trackingAreaRectUpdate_frame() throws {
    let view = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let recognizer = HoverGestureRecognizer()
    view.addGestureRecognizer(recognizer)

    let initialTrackingArea = try view.trackingAreas.first.unwrap()
    expect(initialTrackingArea.rect) == CGRect(x: 0, y: 0, width: 100, height: 100)

    view.frame = CGRect(x: 0, y: 0, width: 200, height: 150)

    expect(view.trackingAreas.count) == 1
    let updatedTrackingArea = try view.trackingAreas.first.unwrap()
    expect(updatedTrackingArea.rect) == CGRect(x: 0, y: 0, width: 200, height: 150)
  }

  func test_trackingAreaRectUpdate_bounds() throws {
    let view = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let recognizer = HoverGestureRecognizer()
    view.addGestureRecognizer(recognizer)

    let initialTrackingArea = try view.trackingAreas.first.unwrap()
    expect(initialTrackingArea.rect) == CGRect(x: 0, y: 0, width: 100, height: 100)

    view.bounds = CGRect(x: 0, y: 0, width: 200, height: 150)

    expect(view.trackingAreas.count) == 1
    let updatedTrackingArea = try view.trackingAreas.first.unwrap()
    expect(updatedTrackingArea.rect) == CGRect(x: 0, y: 0, width: 200, height: 150)
  }

  func test_trackingAreaRectUpdate_boundsSize() throws {
    let view = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let recognizer = HoverGestureRecognizer()
    view.addGestureRecognizer(recognizer)

    let initialTrackingArea = try view.trackingAreas.first.unwrap()
    expect(initialTrackingArea.rect) == CGRect(x: 0, y: 0, width: 100, height: 100)

    view.bounds.size = CGSize(width: 200, height: 150)

    expect(view.trackingAreas.count) == 1
    let updatedTrackingArea = try view.trackingAreas.first.unwrap()
    expect(updatedTrackingArea.rect) == CGRect(x: 0, y: 0, width: 200, height: 150)
  }

  func test_mouseEntered() throws {
    #if os(visionOS)
    throw XCTSkip("visionOS on CI machines may hang when creating a UIWindow.")
    #endif

    let target = TestTarget()
    let view = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let window = TestWindow()
    window.contentView?.addSubview(view)
    let recognizer = HoverGestureRecognizer(target: target, action: #selector(TestTarget.handleHover))
    view.addGestureRecognizer(recognizer)

    expect(recognizer.isHovering) == false
    expect(target.actionCallCount) == 0

    let trackingArea = try view.trackingAreas.first.unwrap()
    let event = createMouseEvent(trackingArea: trackingArea)

    recognizer.test.handleMouseEntered(with: event)

    expect(recognizer.isHovering) == true
    expect(recognizer.state) == .began
    expect(target.actionCallCount).toEventually(beEqual(to: 1))
  }

  func test_mouseExited() throws {
    #if os(visionOS)
    throw XCTSkip("visionOS on CI machines may hang when creating a UIWindow.")
    #endif

    let target = TestTarget()
    let view = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let window = TestWindow()
    window.contentView?.addSubview(view)
    let recognizer = HoverGestureRecognizer(target: target, action: #selector(TestTarget.handleHover))
    view.addGestureRecognizer(recognizer)

    let trackingArea = try view.trackingAreas.first.unwrap()
    let event = createMouseEvent(trackingArea: trackingArea)

    recognizer.test.handleMouseEntered(with: event)
    expect(recognizer.isHovering) == true
    expect(target.actionCallCount).toEventually(beEqual(to: 1))

    recognizer.test.handleMouseExited(with: event)
    expect(recognizer.isHovering) == false
    expect(recognizer.state) == .ended
    expect(target.actionCallCount).toEventually(beEqual(to: 2))
  }

  func test_multiple_mouse_entered_events_only_trigger_once() throws {
    #if os(visionOS)
    throw XCTSkip("visionOS on CI machines may hang when creating a UIWindow.")
    #endif

    let target = TestTarget()
    let view = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let window = TestWindow()
    window.contentView?.addSubview(view)
    let recognizer = HoverGestureRecognizer(target: target, action: #selector(TestTarget.handleHover))
    view.addGestureRecognizer(recognizer)

    let trackingArea = try view.trackingAreas.first.unwrap()
    let event = createMouseEvent(trackingArea: trackingArea)

    recognizer.test.handleMouseEntered(with: event)
    recognizer.test.handleMouseEntered(with: event)
    recognizer.test.handleMouseEntered(with: event)

    expect(recognizer.isHovering) == true
    wait(timeout: 0.1)
    expect(target.actionCallCount) == 1
  }

  func test_multiple_mouse_exited_events_only_trigger_once() throws {
    #if os(visionOS)
    throw XCTSkip("visionOS on CI machines may hang when creating a UIWindow.")
    #endif

    let target = TestTarget()
    let view = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let window = TestWindow()
    window.contentView?.addSubview(view)
    let recognizer = HoverGestureRecognizer(target: target, action: #selector(TestTarget.handleHover))
    view.addGestureRecognizer(recognizer)

    let trackingArea = try view.trackingAreas.first.unwrap()
    let event = createMouseEvent(trackingArea: trackingArea)

    recognizer.test.handleMouseExited(with: event)
    recognizer.test.handleMouseExited(with: event)
    recognizer.test.handleMouseExited(with: event)
    recognizer.test.handleMouseExited(with: event)

    expect(recognizer.isHovering) == false
    wait(timeout: 0.1)
    expect(target.actionCallCount) == 0
  }

  func test_trackingArea_cleanup_onViewRemoval() {
    let view = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let recognizer = HoverGestureRecognizer()
    view.addGestureRecognizer(recognizer)

    expect(view.trackingAreas.count) == 1

    view.removeGestureRecognizer(recognizer)

    expect(view.trackingAreas.count) == 0
  }

  func test_multiple_gesture_recognizers_on_same_view() {
    #if os(visionOS)
    throw XCTSkip("visionOS on CI machines may hang when creating a UIWindow.")
    #endif

    let view = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let window = TestWindow()
    window.contentView?.addSubview(view)
    let target1 = TestTarget()
    let target2 = TestTarget()
    let recognizer1 = HoverGestureRecognizer(target: target1, action: #selector(TestTarget.handleHover))
    let recognizer2 = HoverGestureRecognizer(target: target2, action: #selector(TestTarget.handleHover))

    view.addGestureRecognizer(recognizer1)
    view.addGestureRecognizer(recognizer2)

    expect(view.trackingAreas.count) == 2

    let event1 = createMouseEvent(trackingArea: view.trackingAreas[0])
    let event2 = createMouseEvent(trackingArea: view.trackingAreas[1])

    recognizer1.test.handleMouseEntered(with: event1)
    expect(target1.actionCallCount).toEventually(beEqual(to: 1))
    expect(target2.actionCallCount).toEventually(beEqual(to: 0))

    recognizer2.test.handleMouseEntered(with: event2)
    expect(target1.actionCallCount).toEventually(beEqual(to: 1))
    expect(target2.actionCallCount).toEventually(beEqual(to: 1))
  }

  func test_no_action_when_no_target_or_action_set() throws {
    #if os(visionOS)
    throw XCTSkip("visionOS on CI machines may hang when creating a UIWindow.")
    #endif

    let view = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let window = TestWindow()
    window.contentView?.addSubview(view)
    let recognizer = HoverGestureRecognizer()
    view.addGestureRecognizer(recognizer)

    let trackingArea = try view.trackingAreas.first.unwrap()
    let event = createMouseEvent(trackingArea: trackingArea)

    recognizer.test.handleMouseEntered(with: event)

    expect(recognizer.isHovering) == true
    expect(recognizer.state) == .began
  }
}

// MARK: - Test Utilities

private class TestTarget: NSObject {

  var actionCallCount = 0

  @objc func handleHover() {
    actionCallCount += 1
  }
}

private func createMouseEvent(trackingArea: NSTrackingArea) -> NSEvent {
  // Create a mock event that includes the tracking area
  return MockNSEvent(trackingArea: trackingArea)
}

private class MockNSEvent: NSEvent {

  private let _trackingArea: NSTrackingArea

  init(trackingArea: NSTrackingArea) {
    self._trackingArea = trackingArea
    super.init()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented") // swiftlint:disable:this fatal_error
  }

  override var trackingArea: NSTrackingArea? {
    return _trackingArea
  }

  override var type: NSEvent.EventType {
    return .mouseEntered
  }

  override var modifierFlags: NSEvent.ModifierFlags {
    return []
  }

  override var timestamp: TimeInterval {
    return 0
  }

  override var windowNumber: Int {
    return 0
  }

  override var eventNumber: Int {
    return 0
  }
}

#endif
