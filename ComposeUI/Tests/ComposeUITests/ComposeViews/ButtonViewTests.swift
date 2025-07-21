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
}

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
