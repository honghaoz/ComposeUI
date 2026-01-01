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
    let layer = makeTestLayer()

    // without disableAnimations - should create implicit animations
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    layer.opacity = 0.5

    expect(layer.animationKeys()?.sorted()) == ["bounds", "opacity", "position"]
    expect(layer.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(layer.opacity) == 0.5
  }

  func test_implicitAnimations_disabled() throws {
    let layer = makeTestLayer()

    // with disableAnimations - should NOT create implicit animations
    CATransaction.disableAnimations {
      layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      layer.opacity = 0.5
    }

    expect(layer.animationKeys()) == nil
    expect(layer.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(layer.opacity) == 0.5
  }

  private func makeTestLayer() -> CALayer {
    let frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    let layer = CALayer()
    layer.frame = frame

    testWindow.layer.addSublayer(layer)

    // wait for the layer to have a presentation layer
    wait(timeout: 0.05)

    expect(layer.presentation()) != nil

    return layer
  }

  func test_disableAnimations_returnsValue() {
    let result = CATransaction.disableAnimations {
      return 42
    }
    expect(result) == 42
  }

  func test_disableAnimations_throwsError() {
    struct TestError: Error {}

    var didThrow = false
    do {
      try CATransaction.disableAnimations {
        throw TestError()
      }
      fail("Should have thrown")
    } catch {
      didThrow = true
      expect(error is TestError) == true
    }
    expect(didThrow) == true
  }
}
