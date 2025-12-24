//
//  ButtonMouseEventViewTests.swift
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

class ButtonMouseEventViewTests: XCTestCase {

  func test_hoverState_mouseEntered() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView
    let event = createMouseEvent()

    expect(mouseEventView.isHovering) == false

    // Simulate mouse entered
    mouseEventView.mouseEntered(with: event)

    expect(mouseEventView.isHovering) == true
  }

  func test_hoverState_mouseExited() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView
    let event = createMouseEvent()

    // First enter, then exit
    mouseEventView.mouseEntered(with: event)
    expect(mouseEventView.isHovering) == true

    mouseEventView.mouseExited(with: event)
    expect(mouseEventView.isHovering) == false
  }

  func test_hoverState_mouseMoved() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView
    let event = createMouseEvent()

    expect(mouseEventView.isHovering) == false

    // Mouse move should set hovering to true
    mouseEventView.mouseMoved(with: event)

    expect(mouseEventView.isHovering) == true
  }

  func test_pressGestureRecognizer_mouseDown() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView
    let event = createMouseEvent()

    expect(mouseEventView.state) == .possible

    mouseEventView.mouseDown(with: event)

    expect(mouseEventView.state) == .began
  }

  func test_pressGestureRecognizer_mouseDragged() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView
    let event = createMouseEvent()

    mouseEventView.mouseDown(with: event)
    mouseEventView.mouseDragged(with: event)

    expect(mouseEventView.state) == .changed
  }

  func test_pressGestureRecognizer_mouseUp() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView
    let event = createMouseEvent()

    mouseEventView.mouseDown(with: event)
    mouseEventView.mouseUp(with: event)

    expect(mouseEventView.state) == .ended
  }

  func test_pressGestureRecognizer_cancel() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView

    mouseEventView.cancel()

    expect(mouseEventView.state) == .cancelled
  }

  func test_location_inView() throws {
    #if os(visionOS)
    throw XCTSkip("visionOS on CI machines may hang when creating a UIWindow.")
    #endif

    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView

    // Create a test window and add the button view
    let window = TestWindow()
    window.contentView?.addSubview(buttonView)

    let location = mouseEventView.location(in: buttonView)

    // Should return a valid point (may be zero if no mouse location available)
    expect(location).toNot(beNil())
  }

  func test_location_inView_nilView() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView

    let location = mouseEventView.location(in: nil)

    expect(location) == .zero
  }

  func test_hoverHandler_callback() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView

    var hoverCallbackCount = 0
    var lastHoverState: Bool?

    // Set up hover handler
    mouseEventView.hoverHandler = { _, isHovering in
      hoverCallbackCount += 1
      lastHoverState = isHovering
    }

    let event = createMouseEvent()

    // Simulate hover
    mouseEventView.mouseEntered(with: event)

    expect(hoverCallbackCount) == 1
    expect(lastHoverState) == true

    mouseEventView.mouseExited(with: event)

    expect(hoverCallbackCount) == 2
    expect(lastHoverState) == false
  }

  func test_pressHandler_callback() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView

    var pressCallbackCount = 0
    var lastState: GestureRecognizer.State?

    // Set up press handler
    mouseEventView.pressHandler = { view in
      pressCallbackCount += 1
      lastState = view.state
    }

    let event = createMouseEvent()

    // Simulate press sequence
    mouseEventView.mouseDown(with: event)

    expect(pressCallbackCount) == 1
    expect(lastState) == .began

    mouseEventView.mouseDragged(with: event)

    expect(pressCallbackCount) == 2
    expect(lastState) == .changed

    mouseEventView.mouseUp(with: event)

    expect(pressCallbackCount) == 3
    expect(lastState) == .ended
  }

  func test_inheritedMouseEventView_behavior() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView

    // Test that it's a subclass of MouseEventView
//    expect(mouseEventView).to(beAnInstanceOf(MouseEventView.self))

    // Test inherited properties
    expect(mouseEventView.mouseDownCanMoveWindow) == false
    expect(mouseEventView.acceptsFirstMouse(for: nil)) == true
  }

  func test_stateTransitions_sequence() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView
    let event = createMouseEvent()

    // Test complete interaction sequence
    expect(mouseEventView.state) == .possible

    mouseEventView.mouseDown(with: event)
    expect(mouseEventView.state) == .began

    mouseEventView.mouseDragged(with: event)
    expect(mouseEventView.state) == .changed

    mouseEventView.mouseUp(with: event)
    expect(mouseEventView.state) == .ended
  }

  func test_multipleHoverEvents() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView
    let event = createMouseEvent()

    // Multiple enters should maintain hovering state
    expect(mouseEventView.isHovering) == false

    mouseEventView.mouseEntered(with: event)
    expect(mouseEventView.isHovering) == true

    mouseEventView.mouseEntered(with: event)
    expect(mouseEventView.isHovering) == true

    // Exit should turn off hovering
    mouseEventView.mouseExited(with: event)
    expect(mouseEventView.isHovering) == false

    // Multiple exits should maintain non-hovering state
    mouseEventView.mouseExited(with: event)
    expect(mouseEventView.isHovering) == false
  }
}

// MARK: - Test Utilities

private func createMouseEvent() -> NSEvent {
  NSEvent.mouseEvent(
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
