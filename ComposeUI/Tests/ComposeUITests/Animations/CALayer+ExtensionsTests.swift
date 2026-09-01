//
//  CALayer+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/25/22.
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

class CALayer_ExtensionsTests: XCTestCase {

  func test_backedView() {
    // given: a view with a backing layer
    #if os(macOS)
    let view = View()
    view.wantsLayer = true
    #else
    let view = View()
    #endif
    let layer = view.layer()

    // then: the layer's backed view is the view
    expect(layer.backedView) === view
  }

  func test_positionFromFrame() {
    // given: a layer with a frame and a centered anchor point
    let layer = CALayer()
    let frame = CGRect(x: 10, y: 20, width: 30, height: 40)
    layer.frame = frame
    layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)

    // then: the position computed from the frame matches the anchor point
    expect(layer.position(from: frame)) == CGPoint(x: 25, y: 40)
  }

  func test_bringSublayerToFront() {
    // given: a layer with two sublayers
    let layer = CALayer()
    let sublayer1 = CALayer()
    let sublayer2 = CALayer()
    layer.addSublayer(sublayer1)
    layer.addSublayer(sublayer2)

    // when: bringing the first sublayer to front
    layer.bringSublayerToFront(sublayer1)

    // then: the first sublayer moves to the front
    expect(layer.sublayers) == [sublayer2, sublayer1]

    // when: bringing a layer that is not a sublayer to front
    let sublayer3 = CALayer()
    layer.bringSublayerToFront(sublayer3)

    // then: the sublayers are unchanged
    expect(layer.sublayers) == [sublayer2, sublayer1]
  }

  func test_positionFromFrame_nonIdentityTransform() {
    // given: a layer with a non-identity transform and a test assertion failure handler
    let layer = CALayer()
    layer.transform = CATransform3DMakeRotation(CGFloat.pi / 4, 0, 0, 1)
    let frame = CGRect(x: 10, y: 20, width: 30, height: 40)
    layer.frame = frame
    layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)

    var assertionCount = 0
    Assert.setTestAssertionFailureHandler { message, file, line, column in
      expect(message) == "CALayer.position(from:frame:) only works with identity transform."
      assertionCount += 1
    }

    // then: computing the position triggers an assertion and still returns the position
    expect(layer.position(from: frame)) == CGPoint(x: 25, y: 40)
    expect(assertionCount) == 1

    Assert.resetTestAssertionFailureHandler()
  }
}
