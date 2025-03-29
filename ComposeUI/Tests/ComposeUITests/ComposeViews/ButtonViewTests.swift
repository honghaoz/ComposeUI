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
      content: { _ in Empty() },
      onTap: {
        tapCount += 1
      }
    )

    var state = GestureRecognizer.State.possible
    buttonView.buttonTest.pressGestureRecognizer.override(
      locationInView: { view in
        CGPoint(x: 10, y: 10)
      },
      state: {
        state
      }
    )

    // down
    state = .began
    buttonView.buttonTest.press()
    expect(buttonView.buttonTest.buttonState) == .pressed
    expect(tapCount) == 0

    // up
    state = .ended
    buttonView.buttonTest.press()
    expect(buttonView.buttonTest.buttonState) == .normal
    expect(tapCount) == 1 // first up triggers the tap block

    // down
    state = .began
    buttonView.buttonTest.press()
    expect(buttonView.buttonTest.buttonState) == .pressed
    expect(tapCount) == 1

    // up
    state = .ended
    buttonView.buttonTest.press()
    expect(buttonView.buttonTest.buttonState) == .normal
    expect(tapCount) == 2 // second up triggers the tap block
  }
}

private extension GestureRecognizer {

  private static var subclassKey: UInt8 = 0

  /// Mock `location(in:)`, `state`.
  func override(locationInView: @escaping (View?) -> CGPoint,
                state: @escaping () -> GestureRecognizer.State)
  {
    guard objc_getAssociatedObject(self, &GestureRecognizer.subclassKey) == nil else {
      return // already subclassed
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
          _ = originalMethod(object, selector, parameter1)
          return locationInView(parameter1)
        }
        class_addMethod(newSubclass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
      }

      // override `state`
      do {
        let selector = #selector(getter: GestureRecognizer.state)
        guard let method = class_getInstanceMethod(originalClass, selector) else {
          return
        }

        let block: @convention(block) (AnyObject) -> GestureRecognizer.State = { object in
          return state()
        }
        class_addMethod(newSubclass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
      }

      objc_registerClassPair(newSubclass)
      subclass = newSubclass
    }

    // set the instance's class to the subclass
    object_setClass(self, subclass)

    // mark this instance as subclassed
    objc_setAssociatedObject(self, &GestureRecognizer.subclassKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
  }
}
