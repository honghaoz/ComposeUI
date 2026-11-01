//
//  NSWindow+Input.swift
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
import Carbon.HIToolbox.Events

@testable import ComposeUI

/// A key that scrolls, with the key code and the character of its key events.
enum ScrollingKey {

  case up
  case down
  case left
  case right
  case pageUp
  case pageDown

  /// Returns a key down event of the key in the window.
  ///
  /// - Parameters:
  ///   - window: The window.
  ///   - isARepeat: Whether the event repeats a key held down.
  ///   - modifierFlags: The modifier keys that are down with the key.
  /// - Returns: The key down event.
  func keyDownEvent(in window: NSWindow, isARepeat: Bool = false, modifierFlags: NSEvent.ModifierFlags = []) -> NSEvent {
    event(.keyDown, in: window, isARepeat: isARepeat, modifierFlags: modifierFlags)
  }

  /// Returns a key up event of the key in the window.
  ///
  /// - Parameter window: The window.
  /// - Returns: The key up event.
  func keyUpEvent(in window: NSWindow) -> NSEvent {
    event(.keyUp, in: window, isARepeat: false, modifierFlags: [])
  }

  /// Returns a key event of the key in the window.
  ///
  /// - Parameters:
  ///   - type: The type of the event, key down or key up.
  ///   - window: The window.
  ///   - isARepeat: Whether the event repeats a key held down.
  ///   - otherModifierFlags: The modifier keys that are down with the key.
  /// - Returns: The key event.
  private func event(_ type: NSEvent.EventType, in window: NSWindow, isARepeat: Bool, modifierFlags otherModifierFlags: NSEvent.ModifierFlags) -> NSEvent {
    let (keyCode, character, modifierFlags): (Int, Int, NSEvent.ModifierFlags)
    switch self {
    case .up:
      (keyCode, character, modifierFlags) = (kVK_UpArrow, NSUpArrowFunctionKey, [.numericPad, .function])
    case .down:
      (keyCode, character, modifierFlags) = (kVK_DownArrow, NSDownArrowFunctionKey, [.numericPad, .function])
    case .left:
      (keyCode, character, modifierFlags) = (kVK_LeftArrow, NSLeftArrowFunctionKey, [.numericPad, .function])
    case .right:
      (keyCode, character, modifierFlags) = (kVK_RightArrow, NSRightArrowFunctionKey, [.numericPad, .function])
    case .pageUp:
      (keyCode, character, modifierFlags) = (kVK_PageUp, NSPageUpFunctionKey, [.function])
    case .pageDown:
      (keyCode, character, modifierFlags) = (kVK_PageDown, NSPageDownFunctionKey, [.function])
    }
    let characters = String(utf16CodeUnits: [unichar(character)], count: 1)
    return NSEvent.keyEvent(
      with: type,
      location: .zero,
      modifierFlags: modifierFlags.union(otherModifierFlags),
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: window.windowNumber,
      context: nil,
      characters: characters,
      charactersIgnoringModifiers: characters,
      isARepeat: isARepeat,
      keyCode: UInt16(keyCode)
    )! // swiftlint:disable:this force_unwrapping
  }
}

extension NSWindow {

  /// Presses a key in the window and lets it go at once, as a tap, and settles the keyboard scrolls that it starts, as
  /// their animations do over time.
  ///
  /// - Parameter key: The key.
  func press(_ key: ScrollingKey) {
    keyDown(key)
    keyUp(key)
    settleKeyboardScrolls()
  }

  /// Sends a key down event of a key to the first responder, as the application dispatches it: as its current event,
  /// which tells a scroll view that the key goes up later.
  ///
  /// - Parameters:
  ///   - key: The key.
  ///   - isARepeat: Whether the event repeats a key held down.
  ///   - modifierFlags: The modifier keys that are down with the key.
  func keyDown(_ key: ScrollingKey, isARepeat: Bool = false, modifierFlags: NSEvent.ModifierFlags = []) {
    let application = NSApplication.shared
    application.postEvent(key.keyDownEvent(in: self, isARepeat: isARepeat, modifierFlags: modifierFlags), atStart: false)
    let event = application.nextEvent(matching: .keyDown, until: Date(timeIntervalSinceNow: 1), inMode: .default, dequeue: true)! // swiftlint:disable:this force_unwrapping
    sendEvent(event)

    // the application keeps the latest event that it dequeued as its current event, so another event replaces the key
    // event, for the code that runs after it
    let otherEvent = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0)! // swiftlint:disable:this force_unwrapping
    application.postEvent(otherEvent, atStart: false)
    _ = application.nextEvent(matching: .applicationDefined, until: Date(timeIntervalSinceNow: 1), inMode: .default, dequeue: true)
  }

  /// Sends a key up event of a key to the first responder.
  ///
  /// - Parameter key: The key.
  func keyUp(_ key: ScrollingKey) {
    sendEvent(key.keyUpEvent(in: self))
  }

  /// Sends an event of the Command key going down or up to the first responder.
  ///
  /// - Parameter isDown: Whether the key goes down, or up.
  func commandKey(isDown: Bool) {
    let event = NSEvent.keyEvent(
      with: .flagsChanged,
      location: .zero,
      modifierFlags: isDown ? [.command] : [],
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: windowNumber,
      context: nil,
      characters: "",
      charactersIgnoringModifiers: "",
      isARepeat: false,
      keyCode: UInt16(kVK_Command)
    )! // swiftlint:disable:this force_unwrapping
    sendEvent(event)
  }

  /// Sends a key down event of a key to the first responder at a time, which the keyboard scrolls take as the time of the
  /// key, see `keyDown(_:isARepeat:)`.
  ///
  /// - Parameters:
  ///   - key: The key.
  ///   - time: The time of the key.
  ///   - isARepeat: Whether the event repeats a key held down.
  ///   - modifierFlags: The modifier keys that are down with the key.
  func keyDown(_ key: ScrollingKey, at time: CFTimeInterval, isARepeat: Bool = false, modifierFlags: NSEvent.ModifierFlags = []) {
    AnimationClock.sharingTime(at: time) {
      keyDown(key, isARepeat: isARepeat, modifierFlags: modifierFlags)
    }
  }

  /// Sends a key up event of a key to the first responder at a time, which the keyboard scrolls take as the time of the
  /// key going up.
  ///
  /// - Parameters:
  ///   - key: The key.
  ///   - time: The time of the key going up.
  func keyUp(_ key: ScrollingKey, at time: CFTimeInterval) {
    AnimationClock.sharingTime(at: time) {
      keyUp(key)
    }
  }

  /// Settles the keyboard scrolls in flight in the window, as their animations do over time.
  ///
  /// - Parameter time: The time of the latest key, the current time by default. A test that presses keys at times of
  ///   its own passes the latest one, which can be past the current time.
  func settleKeyboardScrolls(after time: CFTimeInterval = CACurrentMediaTime()) {
    guard #available(macOS 14.0, *), let contentView else {
      return
    }

    func settle(in view: NSView) {
      if let scrollView = view as? ScrollView, let animation = scrollView.keyboardScrollAnimation, animation.isRunning {
        animation.step(at: time + Constants.settlingTime)
      }
      for subview in view.subviews {
        settle(in: subview)
      }
    }
    settle(in: contentView)
  }

  /// Clicks at a point in the window as AppKit handles a mouse down: the view under the point becomes the first responder
  /// if it accepts it, then gets the event, which it passes up the responder chain unless it handles it.
  ///
  /// The test runner's app isn't active, so AppKit takes a mouse down sent to its window as the click that activates the
  /// app, and handles none of it. A view that tracks the mouse itself, such as a text view, waits for the mouse up in its
  /// `mouseDown(with:)`, so make it the first responder instead, as a click on it does.
  ///
  /// - Parameter point: The point in the window's coordinates.
  /// - Returns: The view under the point, which got the event.
  @discardableResult
  func click(at point: CGPoint) -> NSView? {
    guard let hitView = contentView?.superview?.hitTest(point) else {
      return nil
    }
    if hitView.acceptsFirstResponder {
      makeFirstResponder(hitView)
    }
    let event = NSEvent.mouseEvent(
      with: .leftMouseDown,
      location: point,
      modifierFlags: [],
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: windowNumber,
      context: nil,
      eventNumber: 0,
      clickCount: 1,
      pressure: 1
    )! // swiftlint:disable:this force_unwrapping
    hitView.mouseDown(with: event)
    return hitView
  }

  /// Clicks at the center of a view in the window, see `click(at:)`.
  ///
  /// - Parameter view: The view.
  /// - Returns: The view under the view's center, which got the event.
  @discardableResult
  func click(_ view: NSView) -> NSView? {
    click(at: view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil))
  }

  // MARK: - Constants

  private enum Constants {

    /// How long after a key a keyboard scroll has long come to rest, which takes it under a second once the key goes up.
    static let settlingTime: TimeInterval = 10
  }
}
#endif
