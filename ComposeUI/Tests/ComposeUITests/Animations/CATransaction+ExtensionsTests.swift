//
//  CATransaction+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/22/21.
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
