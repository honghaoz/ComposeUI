//
//  MouseEventViewTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 7/21/25.
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

class MouseEventViewTests: XCTestCase {

  func test_initialization() {
    let view = MouseEventView()

    expect(view.frame) == .zero
    expect(view.handler) == nil
    expect(view.mouseDownCanMoveWindow) == false
    expect(view.acceptsFirstMouse(for: nil)) == true
  }

  func test_mouseDownCanMoveWindow() {
    let view = MouseEventView()

    // Should not allow window dragging
    expect(view.mouseDownCanMoveWindow) == false
  }

  func test_acceptsFirstMouse() {
    let view = MouseEventView()

    // Should accept first mouse click even when window is inactive
    expect(view.acceptsFirstMouse(for: nil)) == true

    let mockEvent = createMouseEvent()
    expect(view.acceptsFirstMouse(for: mockEvent)) == true
  }

  func test_trackingAreaSetup() {
    let view = MouseEventView()
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // Initially no tracking areas
    expect(view.trackingAreas.count) == 0

    // Setup tracking area
    view.setupTrackingArea()

    expect(view.trackingAreas.count) == 1

    let trackingArea = view.trackingAreas.first
    expect(trackingArea?.rect) == view.bounds
    expect(trackingArea?.options.contains(.activeAlways)) == true
    expect(trackingArea?.options.contains(.mouseEnteredAndExited)) == true
    expect(trackingArea?.options.contains(.enabledDuringMouseDrag)) == true
    expect(trackingArea?.owner) === view
  }

  func test_trackingAreaUpdate_whenBoundsChange() {
    let view = MouseEventView()
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.setupTrackingArea()

    let initialTrackingArea = view.trackingAreas.first
    expect(initialTrackingArea?.rect) == CGRect(x: 0, y: 0, width: 100, height: 100)

    // Change bounds
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 150)
    view.setupTrackingArea()

    expect(view.trackingAreas.count) == 1
    let updatedTrackingArea = view.trackingAreas.first
    expect(updatedTrackingArea?.rect) == CGRect(x: 0, y: 0, width: 200, height: 150)
    if let updated = updatedTrackingArea, let initial = initialTrackingArea {
      expect(updated) !== initial // Should be a new tracking area
    }
  }

  func test_trackingAreaUpdate_whenBoundsUnchanged() {
    let view = MouseEventView()
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.setupTrackingArea()

    let initialTrackingArea = view.trackingAreas.first

    // Setup tracking area again with same bounds
    view.setupTrackingArea()

    expect(view.trackingAreas.count) == 1
    if let current = view.trackingAreas.first, let initial = initialTrackingArea {
      expect(current) === initial // Should be the same tracking area
    }
  }

  func test_updateTrackingAreas() {
    let view = MouseEventView()
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    expect(view.trackingAreas.count) == 0

    view.updateTrackingAreas()

    expect(view.trackingAreas.count) == 1
  }

  func test_mouseEntered_callsHandler() {
    let view = MouseEventView()
    var receivedEvents: [(MouseEventView, MouseEventView.MouseEvent)] = []

    view.handler = { view, event in
      receivedEvents.append((view, event))
    }

    let event = createMouseEvent()
    view.mouseEntered(with: event)

    expect(receivedEvents.count) == 1
    expect(receivedEvents[0].0) === view
    expect(receivedEvents[0].1) == .mouseEntered
  }

  func test_mouseMoved_callsHandler() {
    let view = MouseEventView()
    var receivedEvents: [(MouseEventView, MouseEventView.MouseEvent)] = []

    view.handler = { view, event in
      receivedEvents.append((view, event))
    }

    let event = createMouseEvent()
    view.mouseMoved(with: event)

    expect(receivedEvents.count) == 1
    expect(receivedEvents[0].0) === view
    expect(receivedEvents[0].1) == .mouseMoved
  }

  func test_mouseExited_callsHandler() {
    let view = MouseEventView()
    var receivedEvents: [(MouseEventView, MouseEventView.MouseEvent)] = []

    view.handler = { view, event in
      receivedEvents.append((view, event))
    }

    let event = createMouseEvent()
    view.mouseExited(with: event)

    expect(receivedEvents.count) == 1
    expect(receivedEvents[0].0) === view
    expect(receivedEvents[0].1) == .mouseExited
  }

  func test_mouseDown_callsHandler() {
    let view = MouseEventView()
    var receivedEvents: [(MouseEventView, MouseEventView.MouseEvent)] = []

    view.handler = { view, event in
      receivedEvents.append((view, event))
    }

    let event = createMouseEvent()
    view.mouseDown(with: event)

    expect(receivedEvents.count) == 1
    expect(receivedEvents[0].0) === view
    expect(receivedEvents[0].1) == .mouseDown
  }

  func test_mouseDragged_callsHandler() {
    let view = MouseEventView()
    var receivedEvents: [(MouseEventView, MouseEventView.MouseEvent)] = []

    view.handler = { view, event in
      receivedEvents.append((view, event))
    }

    let event = createMouseEvent()
    view.mouseDragged(with: event)

    expect(receivedEvents.count) == 1
    expect(receivedEvents[0].0) === view
    expect(receivedEvents[0].1) == .mouseDragged
  }

  func test_mouseUp_callsHandler() {
    let view = MouseEventView()
    var receivedEvents: [(MouseEventView, MouseEventView.MouseEvent)] = []

    view.handler = { view, event in
      receivedEvents.append((view, event))
    }

    let event = createMouseEvent()
    view.mouseUp(with: event)

    expect(receivedEvents.count) == 1
    expect(receivedEvents[0].0) === view
    expect(receivedEvents[0].1) == .mouseUp
  }

  func test_multipleEvents_callsHandlerForEach() {
    let view = MouseEventView()
    var receivedEvents: [(MouseEventView, MouseEventView.MouseEvent)] = []

    view.handler = { view, event in
      receivedEvents.append((view, event))
    }

    let event = createMouseEvent()

    // Simulate a complete mouse interaction sequence
    view.mouseEntered(with: event)
    view.mouseMoved(with: event)
    view.mouseDown(with: event)
    view.mouseDragged(with: event)
    view.mouseUp(with: event)
    view.mouseExited(with: event)

    expect(receivedEvents.count) == 6
    expect(receivedEvents[0].1) == .mouseEntered
    expect(receivedEvents[1].1) == .mouseMoved
    expect(receivedEvents[2].1) == .mouseDown
    expect(receivedEvents[3].1) == .mouseDragged
    expect(receivedEvents[4].1) == .mouseUp
    expect(receivedEvents[5].1) == .mouseExited
  }

  func test_noHandler_doesNotCrash() {
    let view = MouseEventView()
    let event = createMouseEvent()

    // These should not crash even without a handler
    view.mouseEntered(with: event)
    view.mouseMoved(with: event)
    view.mouseExited(with: event)
    view.mouseDown(with: event)
    view.mouseDragged(with: event)
    view.mouseUp(with: event)
  }

  func test_mouseEventEnum_equality() {
    expect(MouseEventView.MouseEvent.mouseEntered) == .mouseEntered
    expect(MouseEventView.MouseEvent.mouseMoved) == .mouseMoved
    expect(MouseEventView.MouseEvent.mouseExited) == .mouseExited
    expect(MouseEventView.MouseEvent.mouseDown) == .mouseDown
    expect(MouseEventView.MouseEvent.mouseDragged) == .mouseDragged
    expect(MouseEventView.MouseEvent.mouseUp) == .mouseUp

    expect(MouseEventView.MouseEvent.mouseEntered) != .mouseMoved
    expect(MouseEventView.MouseEvent.mouseDown) != .mouseUp
  }

  func test_handlerReceivesCorrectView() {
    let view1 = MouseEventView()
    let view2 = MouseEventView()
    var receivedView: MouseEventView?

    let handler: (MouseEventView, MouseEventView.MouseEvent) -> Void = { view, _ in
      receivedView = view
    }

    view1.handler = handler
    view2.handler = handler

    let event = createMouseEvent()

    view1.mouseDown(with: event)
    expect(receivedView) === view1

    view2.mouseDown(with: event)
    expect(receivedView) === view2
  }

  func test_trackingAreaCleanup() {
    let view = MouseEventView()
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.setupTrackingArea()

    expect(view.trackingAreas.count) == 1

    // Change bounds to trigger tracking area recreation
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
    view.setupTrackingArea()

    // Should still have exactly one tracking area (old one removed, new one added)
    expect(view.trackingAreas.count) == 1
  }
}

// MARK: - Test Utilities

private func createMouseEvent() -> NSEvent {

  // Create a mock mouse event using the leftMouseDown event type
  // which is a commonly available NSEvent factory method
  return NSEvent.mouseEvent(
    with: .leftMouseDown,
    location: CGPoint(x: 50, y: 50),
    modifierFlags: [],
    timestamp: 0,
    windowNumber: 0,
    context: nil,
    eventNumber: 0,
    clickCount: 1,
    pressure: 1.0
  ) ?? NSEvent()
}

#endif
