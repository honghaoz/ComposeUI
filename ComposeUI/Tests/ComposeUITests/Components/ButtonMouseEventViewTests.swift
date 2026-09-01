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
    // given: a button's mouse event view that is not hovering
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView
    let event = createMouseEvent()

    expect(mouseEventView.isHovering) == false

    // when: simulating mouse entered
    mouseEventView.mouseEntered(with: event)

    // then: the view is hovering
    expect(mouseEventView.isHovering) == true
  }

  func test_hoverState_mouseExited() {
    // given: a button's mouse event view that is hovering after mouse entered first
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView
    let event = createMouseEvent()

    mouseEventView.mouseEntered(with: event)
    expect(mouseEventView.isHovering) == true

    // when: simulating mouse exited
    mouseEventView.mouseExited(with: event)

    // then: the view is not hovering
    expect(mouseEventView.isHovering) == false
  }

  func test_hoverState_mouseMoved() {
    // given: a button's mouse event view that is not hovering
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView
    let event = createMouseEvent()

    expect(mouseEventView.isHovering) == false

    // when: simulating mouse moved
    mouseEventView.mouseMoved(with: event)

    // then: the mouse move sets hovering to true
    expect(mouseEventView.isHovering) == true
  }

  func test_pressGestureRecognizer_mouseDown() {
    // given: a button's mouse event view in the possible state
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView
    let event = createMouseEvent()

    expect(mouseEventView.state) == .possible

    // when: simulating mouse down
    mouseEventView.mouseDown(with: event)

    // then: the gesture state is began
    expect(mouseEventView.state) == .began
  }

  func test_pressGestureRecognizer_mouseDragged() {
    // given: a button's mouse event view
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView
    let event = createMouseEvent()

    // when: simulating mouse down then mouse dragged
    mouseEventView.mouseDown(with: event)
    mouseEventView.mouseDragged(with: event)

    // then: the gesture state is changed
    expect(mouseEventView.state) == .changed
  }

  func test_pressGestureRecognizer_mouseUp() {
    // given: a button's mouse event view
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView
    let event = createMouseEvent()

    // when: simulating mouse down then mouse up
    mouseEventView.mouseDown(with: event)
    mouseEventView.mouseUp(with: event)

    // then: the gesture state is ended
    expect(mouseEventView.state) == .ended
  }

  func test_pressGestureRecognizer_cancel() {
    // given: a button's mouse event view
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView

    // when: cancelling the gesture
    mouseEventView.cancel()

    // then: the gesture state is cancelled
    expect(mouseEventView.state) == .cancelled
  }

  func test_location_inView() throws {
    // given: a button view added to a test window
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView

    let window = TestWindow()
    window.contentView?.addSubview(buttonView)

    // when: getting the location in the button view
    let location = mouseEventView.location(in: buttonView)

    // then: a valid point is returned (may be zero if no mouse location available)
    expect(location).toNot(beNil())
  }

  func test_location_inView_nilView() {
    // given: a button's mouse event view
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView

    // when: getting the location in a nil view
    let location = mouseEventView.location(in: nil)

    // then: the location is zero
    expect(location) == .zero
  }

  func test_hoverHandler_callback() {
    // given: a button's mouse event view with a hover handler recording callbacks
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView

    var hoverCallbackCount = 0
    var lastHoverState: Bool?

    mouseEventView.hoverHandler = { _, isHovering in
      hoverCallbackCount += 1
      lastHoverState = isHovering
    }

    let event = createMouseEvent()

    // when: simulating hover by mouse entered
    mouseEventView.mouseEntered(with: event)

    // then: the handler reports hovering
    expect(hoverCallbackCount) == 1
    expect(lastHoverState) == true

    // when: simulating mouse exited
    mouseEventView.mouseExited(with: event)

    // then: the handler reports not hovering
    expect(hoverCallbackCount) == 2
    expect(lastHoverState) == false
  }

  func test_pressHandler_callback() {
    // given: a button's mouse event view with a press handler recording callbacks
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView

    var pressCallbackCount = 0
    var lastState: GestureRecognizer.State?

    mouseEventView.pressHandler = { view in
      pressCallbackCount += 1
      lastState = view.state
    }

    let event = createMouseEvent()

    // when: simulating a press sequence with mouse down
    mouseEventView.mouseDown(with: event)

    // then: the handler reports began
    expect(pressCallbackCount) == 1
    expect(lastState) == .began

    // when: simulating mouse dragged
    mouseEventView.mouseDragged(with: event)

    // then: the handler reports changed
    expect(pressCallbackCount) == 2
    expect(lastState) == .changed

    // when: simulating mouse up
    mouseEventView.mouseUp(with: event)

    // then: the handler reports ended
    expect(pressCallbackCount) == 3
    expect(lastState) == .ended
  }

  func test_inheritedMouseEventView_behavior() {
    // given: a button's mouse event view
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView

    // Test that it's a subclass of MouseEventView
//    expect(mouseEventView).to(beAnInstanceOf(MouseEventView.self))

    // then: the inherited properties are configured
    expect(mouseEventView.mouseDownCanMoveWindow) == false
    expect(mouseEventView.acceptsFirstMouse(for: nil)) == true
  }

  func test_stateTransitions_sequence() {
    // given: a button's mouse event view in the possible state, for a complete interaction sequence
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView
    let event = createMouseEvent()

    expect(mouseEventView.state) == .possible

    // when: simulating mouse down
    mouseEventView.mouseDown(with: event)

    // then: the gesture state is began
    expect(mouseEventView.state) == .began

    // when: simulating mouse dragged
    mouseEventView.mouseDragged(with: event)

    // then: the gesture state is changed
    expect(mouseEventView.state) == .changed

    // when: simulating mouse up
    mouseEventView.mouseUp(with: event)

    // then: the gesture state is ended
    expect(mouseEventView.state) == .ended
  }

  func test_multipleHoverEvents() {
    // given: a button's mouse event view that is not hovering
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in
      Text("Test Button")
    }, onTap: {})

    let mouseEventView = buttonView.buttonTest.mouseEventView
    let event = createMouseEvent()

    expect(mouseEventView.isHovering) == false

    // when: simulating mouse entered
    mouseEventView.mouseEntered(with: event)

    // then: the view is hovering
    expect(mouseEventView.isHovering) == true

    // when: simulating mouse entered again
    mouseEventView.mouseEntered(with: event)

    // then: multiple enters maintain the hovering state
    expect(mouseEventView.isHovering) == true

    // when: simulating mouse exited
    mouseEventView.mouseExited(with: event)

    // then: the exit turns off hovering
    expect(mouseEventView.isHovering) == false

    // when: simulating mouse exited again
    mouseEventView.mouseExited(with: event)

    // then: multiple exits maintain the non-hovering state
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
