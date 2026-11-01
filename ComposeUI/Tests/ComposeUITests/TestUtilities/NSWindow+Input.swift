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
  /// - Parameter window: The window.
  /// - Returns: The key down event.
  func keyDownEvent(in window: NSWindow) -> NSEvent {
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
      with: .keyDown,
      location: .zero,
      modifierFlags: modifierFlags,
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: window.windowNumber,
      context: nil,
      characters: characters,
      charactersIgnoringModifiers: characters,
      isARepeat: false,
      keyCode: UInt16(keyCode)
    )! // swiftlint:disable:this force_unwrapping
  }
}

extension NSWindow {

  /// Presses a key in the window, which sends its key down event to the first responder, and settles the keyboard scrolls
  /// that it starts, as their animations do over time.
  ///
  /// - Parameter key: The key.
  func press(_ key: ScrollingKey) {
    sendEvent(key.keyDownEvent(in: self))
    settleKeyboardScrolls()
  }

  /// Settles the keyboard scrolls in flight in the window, as their animations do over time.
  func settleKeyboardScrolls() {
    guard #available(macOS 14.0, *), let contentView else {
      return
    }

    func settle(in view: NSView) {
      if let scrollView = view as? ScrollView, let animation = scrollView.keyboardScrollAnimation, animation.isRunning {
        animation.step(at: CACurrentMediaTime() + Constants.settlingTime)
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

    /// How long after a key a keyboard scroll's spring has long come to rest, which takes it about a second.
    static let settlingTime: TimeInterval = 10
  }
}
#endif
