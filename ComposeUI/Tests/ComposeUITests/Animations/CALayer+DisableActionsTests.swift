//
//  CALayer+DisableActionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/8/25.
//

import ChouTiTest

@testable import ComposeUI

class CALayer_DisableActionsTests: XCTestCase {

  func test_disableActions() throws {
    let frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    let layer = CALayer()
    layer.frame = frame

    let window = TestWindow()
    window.layer.addSublayer(layer)

    // wait for the layer to have a presentation layer
    wait(timeout: 0.05)

    // with disableAction
    do {
      layer.disableActions(for: "position", "bounds") {
        layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      }
      expect(layer.animationKeys()) == nil
    }

    // with partial disableAction
    do {
      layer.disableActions(for: "position") {
        layer.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
      }
      expect(layer.animationKeys()) == ["bounds"]
    }

    // without disableAction
    do {
      layer.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
      expect(layer.animationKeys()) == ["position", "bounds"]
    }
  }

  func test_disableAllActions_mainThread() throws {
    let frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    let layer = CALayer()
    layer.frame = frame

    let window = TestWindow()
    window.layer.addSublayer(layer)

    // wait for the layer to have a presentation layer
    wait(timeout: 0.05)

    // without delegate
    do {
      layer.disableActions {
        layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      }
      expect(layer.animationKeys()) == nil
    }

    // with delegate
    do {
      class LayerDelegate: NSObject, CALayerDelegate {}
      let delegate = LayerDelegate()
      layer.delegate = delegate
      layer.disableActions {
        layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      }
      expect(layer.animationKeys()) == nil
    }
  }

  func test_disableAllActions_backgroundThread() throws {
    let frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    let layer = CALayer()
    layer.frame = frame

    let window = TestWindow()
    window.layer.addSublayer(layer)

    // wait for the layer to have a presentation layer
    wait(timeout: 0.05)

    // with delegate - should trigger assertion when called from background thread
    do {
      class LayerDelegate: NSObject, CALayerDelegate {}
      let delegate = LayerDelegate()
      layer.delegate = delegate

      var assertionCount = 0
      Assert.setTestAssertionFailureHandler { message, file, line, column in
        expect(message) == "CALayer.disableActions() must be called on the main thread"
        assertionCount += 1
      }

      let queue = DispatchQueue(label: "test_disableAllActions_backgroundThread")
      let expectation = expectation(description: "assertion triggered")
      queue.async { [layer] in
        layer.disableActions { [layer] in
          layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        }
        expectation.fulfill()
      }

      waitForExpectations(timeout: 1)
      expect(assertionCount) == 1
      expect(layer.animationKeys()) == nil

      Assert.resetTestAssertionFailureHandler()
    }
  }
}
