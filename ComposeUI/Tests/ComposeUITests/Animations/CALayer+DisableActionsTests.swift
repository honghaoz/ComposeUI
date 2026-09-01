//
//  CALayer+DisableActionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/8/25.
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

class CALayer_DisableActionsTests: XCTestCase {

  func test_disableActions() throws {
    // given: a layer hosted in a window
    let frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    let layer = CALayer()
    layer.frame = frame

    let window = TestWindow()
    window.layer.addSublayer(layer)

    // wait for the layer to have a presentation layer
    expect(layer.presentation()).toEventuallyNot(beNil())

    // when: changing the frame with actions disabled for position and bounds
    do {
      layer.disableActions(for: "position", "bounds") {
        layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      }

      // then: no implicit animations are added
      expect(layer.animationKeys()) == nil
    }

    // when: changing the frame with actions disabled for position only
    do {
      layer.disableActions(for: "position") {
        layer.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
      }

      // then: only the bounds animation is added
      expect(layer.animationKeys()) == ["bounds"]
    }

    // when: changing the frame without disabling actions
    do {
      layer.frame = CGRect(x: 0, y: 0, width: 300, height: 300)

      // then: implicit position and bounds animations are added
      expect(layer.animationKeys()) == ["position", "bounds"]
    }
  }

  func test_disableActions_insideDisablingTransaction_skipsActionsInstall() throws {
    // given: a layer hosted in a window, with a sentinel actions dictionary installed
    let frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    let layer = CALayer()
    layer.frame = frame

    let window = TestWindow()
    window.layer.addSublayer(layer)

    // wait for the layer to have a presentation layer
    expect(layer.presentation()).toEventuallyNot(beNil())

    // install a single-entry sentinel actions dictionary so we can tell whether the call swaps `actions` (slow path,
    // which would install a 2-key disabling dictionary) or leaves them untouched (fast path).
    let sentinel: [String: CAAction] = ["sentinel": NSNull()]
    layer.actions = sentinel

    var workRan = false
    var actionsCountDuringWork: Int?

    // when: disabling actions inside a transaction that already disables actions for all keys, mimicking the render pass
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.disableActions(for: "position", "bounds") {
      workRan = true
      actionsCountDuringWork = layer.actions?.count
      layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    }
    CATransaction.commit()

    // then: the work runs and the fast path leaves the actions untouched
    expect(workRan) == true
    // fast path: `actions` stays as the sentinel (count 1), not swapped to the 2-key disabling dictionary.
    expect(actionsCountDuringWork) == 1
    // `actions` is left intact after the call.
    expect(layer.actions?.count) == 1
    // no implicit animation is added because the transaction already suppressed it.
    expect(layer.animationKeys()) == nil
  }

  func test_disableActions_throwingWork_restoresActions() throws {
    // given: a layer with a sentinel actions dictionary installed
    struct TestError: Error {}

    let layer = CALayer()
    let sentinel: [String: CAAction] = ["sentinel": NSNull()]
    layer.actions = sentinel

    // when: the work block throws
    // a throwing work block must not leave the layer with the disabling actions installed
    do {
      try layer.disableActions(for: "position") {
        expect(layer.actions?.count) == 1 // the disabling actions dictionary is installed
        expect(layer.actions?["position"] is NSNull) == true
        throw TestError()
      }
      fail("expected to throw")
    } catch {
      expect(error is TestError) == true
    }

    // then: the original actions are restored
    expect(layer.actions?.count) == 1
    expect(layer.actions?["sentinel"] is NSNull) == true
  }

  func test_disableAllActions_mainThread() throws {
    // given: a layer hosted in a window
    let frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    let layer = CALayer()
    layer.frame = frame

    let window = TestWindow()
    window.layer.addSublayer(layer)

    // wait for the layer to have a presentation layer
    expect(layer.presentation()).toEventuallyNot(beNil())

    // when: changing the frame with all actions disabled, without a delegate
    do {
      layer.disableActions {
        layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      }

      // then: no implicit animations are added
      expect(layer.animationKeys()) == nil
    }

    // when: changing the frame with all actions disabled, with a delegate
    do {
      class LayerDelegate: NSObject, CALayerDelegate {}
      let delegate = LayerDelegate()
      layer.delegate = delegate
      layer.disableActions {
        layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      }

      // then: no implicit animations are added
      expect(layer.animationKeys()) == nil
    }
  }

  func test_disableAllActions_throwingWork_restoresDelegateAndClass() throws {
    struct TestError: Error {}

    // given: a layer without a delegate
    do {
      let layer = CALayer()

      // when: the work block throws
      // a throwing work block must not leave the layer with the actions-disabling delegate
      do {
        try layer.disableActions {
          expect(layer.delegate) != nil // the actions-disabling delegate is installed
          throw TestError()
        }
        fail("expected to throw")
      } catch {
        expect(error is TestError) == true
      }

      // then: the delegate is restored
      expect(layer.delegate) == nil
    }

    // given: a layer with a delegate
    do {
      class LayerDelegate: NSObject, CALayerDelegate {}
      let delegate = LayerDelegate()
      let layer = CALayer()
      layer.delegate = delegate

      // when: the work block throws
      // a throwing work block must not leave the layer with the actions-disabling subclass
      do {
        try layer.disableActions {
          expect(NSStringFromClass(object_getClass(layer)!)) == "CALayer_DisabledActions" // swiftlint:disable:this force_unwrapping
          throw TestError()
        }
        fail("expected to throw")
      } catch {
        expect(error is TestError) == true
      }

      // then: the class is restored and the delegate is untouched
      expect(object_getClass(layer) === CALayer.self) == true
      expect(layer.delegate) === delegate
    }
  }

  func test_disableAllActions_backgroundThread() throws {
    // given: a layer hosted in a window
    let frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    let layer = CALayer()
    layer.frame = frame

    let window = TestWindow()
    window.layer.addSublayer(layer)

    // wait for the layer to have a presentation layer
    expect(layer.presentation()).toEventuallyNot(beNil())

    // given: a delegate on the layer and a test assertion failure handler
    do {
      class LayerDelegate: NSObject, CALayerDelegate {}
      let delegate = LayerDelegate()
      layer.delegate = delegate

      var assertionCount = 0
      Assert.setTestAssertionFailureHandler { message, file, line, column in
        expect(message) == "CALayer.disableActions() must be called on the main thread"
        assertionCount += 1
      }

      // when: disabling actions from a background thread
      let queue = DispatchQueue(label: "test_disableAllActions_backgroundThread")
      let expectation = expectation(description: "assertion triggered")
      queue.async { [layer] in
        layer.disableActions { [layer] in
          layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        }
        expectation.fulfill()
      }

      // then: the main thread assertion is triggered and no implicit animations are added
      waitForExpectations(timeout: 1)
      expect(assertionCount) == 1
      expect(layer.animationKeys()) == nil

      Assert.resetTestAssertionFailureHandler()
    }
  }
}
