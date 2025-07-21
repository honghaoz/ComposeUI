//
//  ButtonViewTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
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
#endif

#if canImport(UIKit)
import UIKit
#endif

import ChouTiTest

@testable import ComposeUI

final class ButtonViewTests: XCTestCase {

  func test_buttonState() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    expect(buttonView.buttonTest.buttonState) == .normal
  }

  func test_singleTapMode_singleTap() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var tapCount = 0
    buttonView.configure(
      content: { _, _ in Empty() },
      onTap: {
        tapCount += 1
      }
    )

    var state = GestureRecognizer.State.possible
    #if canImport(UIKit)
    buttonView.buttonTest.pressGestureRecognizer.override(
      locationInView: { view in
        CGPoint(x: 10, y: 10)
      },
      state: {
        state
      }
    )
    #endif

    // down
    state = .began
    #if canImport(UIKit)
    buttonView.buttonTest.press()
    #endif
    #if canImport(AppKit)
    buttonView.buttonTest.handlePress(with: state)
    #endif
    expect(buttonView.buttonTest.buttonState) == .pressed
    expect(tapCount) == 0

    // up
    state = .ended
    #if canImport(UIKit)
    buttonView.buttonTest.press()
    #endif
    #if canImport(AppKit)
    buttonView.buttonTest.handlePress(with: state)
    #endif
    expect(buttonView.buttonTest.buttonState) == .normal
    expect(tapCount) == 1 // first up triggers the tap block

    // down
    state = .began
    #if canImport(UIKit)
    buttonView.buttonTest.press()
    #endif
    #if canImport(AppKit)
    buttonView.buttonTest.handlePress(with: state)
    #endif
    expect(buttonView.buttonTest.buttonState) == .pressed
    expect(tapCount) == 1

    // up
    state = .ended
    #if canImport(UIKit)
    buttonView.buttonTest.press()
    #endif
    #if canImport(AppKit)
    buttonView.buttonTest.handlePress(with: state)
    #endif
    expect(buttonView.buttonTest.buttonState) == .normal
    expect(tapCount) == 2 // second up triggers the tap block
  }

  func test_doubleTapMode_singleTap() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var tapCount = 0
    var doubleTapCount = 0
    buttonView.configure(
      content: { _, _ in Empty() },
      onTap: {
        tapCount += 1
      },
      onDoubleTap: {
        doubleTapCount += 1
      }
    )

    var state = GestureRecognizer.State.possible
    #if canImport(UIKit)
    buttonView.buttonTest.pressGestureRecognizer.override(
      locationInView: { view in
        CGPoint(x: 10, y: 10)
      },
      state: {
        state
      }
    )
    #endif

    buttonView.doubleTapInterval = 0.01

    // down
    state = .began
    #if canImport(UIKit)
    buttonView.buttonTest.press()
    #endif
    #if canImport(AppKit)
    buttonView.buttonTest.handlePress(with: state)
    #endif
    expect(buttonView.buttonTest.buttonState) == .pressed
    expect(tapCount) == 0
    expect(doubleTapCount) == 0

    // up
    state = .ended
    #if canImport(UIKit)
    buttonView.buttonTest.press()
    #endif
    #if canImport(AppKit)
    buttonView.buttonTest.handlePress(with: state)
    #endif
    expect(buttonView.buttonTest.buttonState) == .normal
    expect(tapCount) == 0 // first up does not trigger the tap block
    expect(doubleTapCount) == 0

    expect(tapCount).toEventually(beEqual(to: 1)) // single tap block is triggered later
  }

  func test_doubleTapMode_doubleTap() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var tapCount = 0
    var doubleTapCount = 0
    buttonView.configure(
      content: { _, _ in Empty() },
      onTap: {
        tapCount += 1
      },
      onDoubleTap: {
        doubleTapCount += 1
      }
    )

    var state = GestureRecognizer.State.possible
    #if canImport(UIKit)
    buttonView.buttonTest.pressGestureRecognizer.override(
      locationInView: { view in
        CGPoint(x: 10, y: 10)
      },
      state: {
        state
      }
    )
    #endif

    buttonView.doubleTapInterval = 0.01

    // down
    state = .began
    #if canImport(UIKit)
    buttonView.buttonTest.press()
    #endif
    #if canImport(AppKit)
    buttonView.buttonTest.handlePress(with: state)
    #endif
    expect(buttonView.buttonTest.buttonState) == .pressed
    expect(tapCount) == 0
    expect(doubleTapCount) == 0

    // up
    state = .ended
    #if canImport(UIKit)
    buttonView.buttonTest.press()
    #endif
    #if canImport(AppKit)
    buttonView.buttonTest.handlePress(with: state)
    #endif
    expect(buttonView.buttonTest.buttonState) == .normal
    expect(tapCount) == 0
    expect(doubleTapCount) == 0

    // down
    state = .began
    #if canImport(UIKit)
    buttonView.buttonTest.press()
    #endif
    #if canImport(AppKit)
    buttonView.buttonTest.handlePress(with: state)
    #endif
    expect(buttonView.buttonTest.buttonState) == .pressed
    expect(tapCount) == 0
    expect(doubleTapCount) == 0

    // up
    state = .ended
    #if canImport(UIKit)
    buttonView.buttonTest.press()
    #endif
    #if canImport(AppKit)
    buttonView.buttonTest.handlePress(with: state)
    #endif
    expect(buttonView.buttonTest.buttonState) == .normal
    expect(tapCount) == 0
    expect(doubleTapCount) == 1 // second up triggers the double tap block
  }

  #if canImport(AppKit)
  func test_performKeyEquivalent_withoutHandler() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in Empty() }, onTap: {})

    let keyEvent = createMockKeyEvent()

    // should return false and call super when no shouldPerformKeyEquivalent is set
    let result = buttonView.performKeyEquivalent(with: keyEvent)
    expect(result) == false
  }

  func test_performKeyEquivalent_handlerReturnsFalse() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var tapCount = 0
    buttonView.configure(content: { _, _ in Empty() }, onTap: {
      tapCount += 1
    })

    var receivedEvent: NSEvent?
    buttonView.shouldPerformKeyEquivalent = { event in
      receivedEvent = event
      return false
    }

    let keyEvent = createMockKeyEvent()
    let result = buttonView.performKeyEquivalent(with: keyEvent)

    expect(result) == false
    expect(receivedEvent) === keyEvent
    expect(tapCount) == 0 // should not trigger tap when handler returns false
  }

  func test_performKeyEquivalent_handlerReturnsTrue() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var tapCount = 0
    buttonView.configure(content: { _, _ in Empty() }, onTap: {
      tapCount += 1
    })

    var receivedEvent: NSEvent?
    buttonView.shouldPerformKeyEquivalent = { event in
      receivedEvent = event
      return true
    }

    let keyEvent = createMockKeyEvent()
    let result = buttonView.performKeyEquivalent(with: keyEvent)

    expect(result) == true
    expect(receivedEvent) === keyEvent

    // should trigger button press sequence
    expect(buttonView.buttonTest.buttonState) == .pressed

    // wait for async completion
    expect(tapCount).toEventually(beEqual(to: 1))
    expect(buttonView.buttonTest.buttonState).toEventually(beEqual(to: .normal))
  }

  func test_performKeyEquivalent_withDoubleTap() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var tapCount = 0
    var doubleTapCount = 0
    buttonView.configure(
      content: { _, _ in Empty() },
      onTap: { tapCount += 1 },
      onDoubleTap: { doubleTapCount += 1 }
    )

    buttonView.shouldPerformKeyEquivalent = { _ in true }

    let keyEvent = createMockKeyEvent()

    // first key equivalent
    let result1 = buttonView.performKeyEquivalent(with: keyEvent)
    expect(result1) == true

    // second key equivalent - should be treated as separate tap for better UX
    // rapid keyboard shortcuts should not trigger double-tap behavior
    let result2 = buttonView.performKeyEquivalent(with: keyEvent)
    expect(result2) == true

    // wait for async completion
    expect(tapCount).toEventually(beEqual(to: 2))
    expect(doubleTapCount) == 0 // keyboard shortcuts should not trigger double-tap
  }

  func test_performKeyEquivalent_buttonStateSequence() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in Empty() }, onTap: {})

    buttonView.shouldPerformKeyEquivalent = { _ in true }

    expect(buttonView.buttonTest.buttonState) == .normal

    let keyEvent = createMockKeyEvent()
    let result = buttonView.performKeyEquivalent(with: keyEvent)

    expect(result) == true
    expect(buttonView.buttonTest.buttonState) == .pressed

    // Should return to normal after delay
    expect(buttonView.buttonTest.buttonState).toEventually(beEqual(to: .normal))
  }

  func test_performKeyEquivalent_multipleHandlerCalls() {
    let buttonView = ButtonView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    buttonView.configure(content: { _, _ in Empty() }, onTap: {})

    var handlerCallCount = 0
    buttonView.shouldPerformKeyEquivalent = { _ in
      handlerCallCount += 1
      return handlerCallCount % 2 == 0 // Return true every other call
    }

    let keyEvent = createMockKeyEvent()

    // First call - should return false
    let result1 = buttonView.performKeyEquivalent(with: keyEvent)
    expect(result1) == false
    expect(handlerCallCount) == 1

    // Second call - should return true
    let result2 = buttonView.performKeyEquivalent(with: keyEvent)
    expect(result2) == true
    expect(handlerCallCount) == 2
  }
  #endif
}

#if canImport(AppKit)
private func createMockKeyEvent() -> NSEvent {
  // Create a mock key event using keyDown type
  return NSEvent.keyEvent(
    with: .keyDown,
    location: CGPoint(x: 0, y: 0),
    modifierFlags: [],
    timestamp: 0,
    windowNumber: 0,
    context: nil,
    characters: "a",
    charactersIgnoringModifiers: "a",
    isARepeat: false,
    keyCode: 0
  ) ?? NSEvent()
}
#endif

private extension GestureRecognizer {

  private static var subclassKey: UInt8 = 0
  private static var locationInViewBlockKey: UInt8 = 0
  private static var stateBlockKey: UInt8 = 0

  /// Mock `location(in:)`, `state`.
  func override(locationInView: @escaping (View?) -> CGPoint,
                state: @escaping () -> GestureRecognizer.State)
  {
    guard objc_getAssociatedObject(self, &GestureRecognizer.subclassKey) == nil else {
      // already subclassed, just update the properties
      objc_setAssociatedObject(self, &GestureRecognizer.locationInViewBlockKey, locationInView, .OBJC_ASSOCIATION_COPY_NONATOMIC)
      objc_setAssociatedObject(self, &GestureRecognizer.stateBlockKey, state, .OBJC_ASSOCIATION_COPY_NONATOMIC)
      return
    }

    guard let originalClass = object_getClass(self) else {
      return
    }
    let originalClassName = String(cString: class_getName(originalClass))
    let subclassName = originalClassName.appending("_Subclass")

    let subclass: AnyClass
    if let existingSubclass = NSClassFromString(subclassName) {
      subclass = existingSubclass
    } else {
      guard let subclassNameUtf8 = (subclassName as NSString).utf8String,
            let newSubclass = objc_allocateClassPair(originalClass, subclassNameUtf8, 0)
      else {
        return
      }

      // override `location(in:)`
      do {
        let selector = #selector(GestureRecognizer.location(in:))
        guard let method = class_getInstanceMethod(originalClass, selector) else {
          return
        }

        let originalMethodIMP = method_getImplementation(method) // can also use: class_getMethodImplementation(originalClass, selector)
        typealias OriginalMethodIMP = @convention(c) (AnyObject, Selector, View?) -> CGPoint
        let originalMethod = unsafeBitCast(originalMethodIMP, to: OriginalMethodIMP.self)

        let block: @convention(block) (AnyObject, View?) -> CGPoint = { object, parameter1 in
          if let locationInViewBlock = objc_getAssociatedObject(object, &GestureRecognizer.locationInViewBlockKey) as? ((View?) -> CGPoint) {
            return locationInViewBlock(parameter1)
          }
          return originalMethod(object, selector, parameter1)
        }
        class_addMethod(newSubclass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
      }

      // override `state`
      do {
        let selector = #selector(getter: GestureRecognizer.state)
        guard let method = class_getInstanceMethod(originalClass, selector) else {
          return
        }

        let originalMethodIMP = method_getImplementation(method)
        typealias OriginalMethodIMP = @convention(c) (AnyObject, Selector) -> GestureRecognizer.State
        let originalMethod = unsafeBitCast(originalMethodIMP, to: OriginalMethodIMP.self)

        let block: @convention(block) (AnyObject) -> GestureRecognizer.State = { object in
          if let stateBlock = objc_getAssociatedObject(object, &GestureRecognizer.stateBlockKey) as? (() -> GestureRecognizer.State) {
            return stateBlock()
          }
          return originalMethod(object, selector)
        }
        class_addMethod(newSubclass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
      }

      objc_registerClassPair(newSubclass)
      subclass = newSubclass
    }

    // set the instance's class to the subclass
    object_setClass(self, subclass)

    objc_setAssociatedObject(self, &GestureRecognizer.locationInViewBlockKey, locationInView, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    objc_setAssociatedObject(self, &GestureRecognizer.stateBlockKey, state, .OBJC_ASSOCIATION_COPY_NONATOMIC)

    // mark this instance as subclassed
    objc_setAssociatedObject(self, &GestureRecognizer.subclassKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
  }
}
