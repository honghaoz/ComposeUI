//
//  CATransaction+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/22/21.
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

import QuartzCore

import ChouTiTest

@_spi(Private) @testable import ComposeUI

class CATransaction_ExtensionsTests: XCTestCase {

  private var testWindow: TestWindow!

  override func setUp() {
    super.setUp()
    testWindow = TestWindow()
  }

  override func tearDown() {
    testWindow = nil
    super.tearDown()
  }

  func test_implicitAnimations() throws {
    // given: a layer hosted in the test window
    let layer = makeTestLayer()

    // when: changing the frame and opacity without disabling animations
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    layer.opacity = 0.5

    // then: implicit animations are created and the values are set
    expect(layer.animationKeys()?.sorted()) == ["bounds", "opacity", "position"]
    expect(layer.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(layer.opacity) == 0.5
  }

  func test_implicitAnimations_disabled() throws {
    // given: a layer hosted in the test window
    let layer = makeTestLayer()

    // when: changing the frame and opacity with animations disabled
    CATransaction.disableAnimations {
      layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      layer.opacity = 0.5
    }

    // then: no implicit animations are created and the values are set
    expect(layer.animationKeys()) == nil
    expect(layer.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(layer.opacity) == 0.5
  }

  func test_disableAnimationsIfNeeded() {
    // given: a layer hosted in the test window
    let layer = makeTestLayer()

    // when: changing the frame and opacity with animations disabled if needed, outside a transaction that disables actions
    var disablesActions = false
    var animationDuration: CFTimeInterval = -1
    CATransaction.disableAnimationsIfNeeded {
      disablesActions = CATransaction.disableActions()
      animationDuration = CATransaction.animationDuration()
      layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      layer.opacity = 0.5
    }

    // then: the block runs in a nested transaction that disables animations, so no implicit animations are created
    expect(disablesActions) == true
    expect(animationDuration) == 0
    expect(layer.animationKeys()) == nil
    expect(layer.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(layer.opacity) == 0.5
  }

  func test_disableAnimationsIfNeeded_actionsAlreadyDisabled() {
    // given: a layer hosted in the test window
    let layer = makeTestLayer()

    // when: changing the opacity with animations disabled if needed, inside a transaction that already disables actions
    // and has a duration
    var animationDuration: CFTimeInterval = -1
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    CATransaction.setAnimationDuration(2)
    CATransaction.disableAnimationsIfNeeded {
      animationDuration = CATransaction.animationDuration()
      layer.opacity = 0.5
    }
    CATransaction.commit()

    // then: the block runs in the current transaction, whose duration a nested transaction would have zeroed, and no
    // implicit animation is created
    expect(animationDuration) == 2
    expect(layer.animationKeys()) == nil
    expect(layer.opacity) == 0.5
  }

  private func makeTestLayer() -> CALayer {
    let frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    let layer = CALayer()
    layer.frame = frame

    testWindow.layer.addSublayer(layer)

    // wait for the layer to have a presentation layer
    expect(layer.presentation()).toEventuallyNot(beNil())

    return layer
  }

  func test_disableAnimations_returnsValue() {
    // when: running a block that returns a value with animations disabled
    let result = CATransaction.disableAnimations {
      return 42
    }

    // then: the block's value is returned
    expect(result) == 42
  }

  func test_disableAnimations_throwsError() {
    // given: an error type and a thrown flag
    struct TestError: Error {}

    var didThrow = false

    // when: the block throws with animations disabled
    do {
      try CATransaction.disableAnimations {
        throw TestError()
      }
      fail("Should have thrown")
    } catch {
      didThrow = true
      expect(error is TestError) == true
    }

    // then: the error propagates to the caller
    expect(didThrow) == true
  }
}
