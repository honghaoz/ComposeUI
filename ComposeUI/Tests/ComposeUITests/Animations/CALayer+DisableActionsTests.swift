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

import ComposeUI

class CALayer_DisableActionsTests: XCTestCase {

  func test_disableActions() throws {
    #if os(visionOS)
    throw XCTSkip("visionOS on CI machines may hang when creating a UIWindow.")
    #endif

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

  func test_disableAllActions() throws {
    #if os(visionOS)
    throw XCTSkip("visionOS on CI machines may hang when creating a UIWindow.")
    #endif

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
}
