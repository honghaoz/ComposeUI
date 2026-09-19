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

  func test_positionFromFrame_matchesCoreAnimation() {
    // given: a layer with an anchor point that is not a power of two, at a third-pixel frame, for which
    // `origin + anchorPoint * size` rounded twice differs from Core Animation's fused arithmetic by an ulp
    let layer = CALayer()
    layer.anchorPoint = CGPoint(x: 0.25, y: 0.75)
    let third: CGFloat = 1 / 3
    let frame = CGRect(x: 10, y: 10 + third, width: 10, height: 10 + 2 * third)
    let twiceRounded = CGPoint(x: frame.origin.x + 0.25 * frame.width, y: frame.origin.y + 0.75 * frame.height)

    // when: setting the frame
    layer.frame = frame

    // then: the position computed from the frame is the one Core Animation stored, not the twice-rounded one
    expect(layer.position(from: frame)) == layer.position
    expect(layer.position) != twiceRounded
  }

  func test_hasFrame() {
    // given: a layer with a frame
    let layer = CALayer()
    layer.frame = CGRect(x: 10, y: 20, width: 30, height: 40)

    // then: the layer has its frame, and not a frame with another origin or another size
    expect(layer.hasFrame(CGRect(x: 10, y: 20, width: 30, height: 40))) == true
    expect(layer.hasFrame(CGRect(x: 11, y: 20, width: 30, height: 40))) == false
    expect(layer.hasFrame(CGRect(x: 10, y: 20, width: 30, height: 41))) == false

    // then: a difference below the geometry tolerance is arithmetic noise, a difference above it is a change
    expect(layer.hasFrame(CGRect(x: 10 + 1e-9, y: 20 - 1e-9, width: 30 + 1e-9, height: 40 - 1e-9))) == true
    expect(layer.hasFrame(CGRect(x: 10 + 1e-3, y: 20, width: 30, height: 40))) == false
    expect(layer.hasFrame(CGRect(x: 10, y: 20, width: 30, height: 40 - 1e-3))) == false

    // when: the size changes, which grows the frame around the centered anchor point
    layer.bounds.size = CGSize(width: 50, height: 60)

    // then: the layer has the grown frame, and not the old frame nor the new size at the old origin
    expect(layer.position) == CGPoint(x: 25, y: 40)
    expect(layer.hasFrame(CGRect(x: 0, y: 10, width: 50, height: 60))) == true
    expect(layer.hasFrame(CGRect(x: 10, y: 20, width: 30, height: 40))) == false
    expect(layer.hasFrame(CGRect(x: 10, y: 20, width: 50, height: 60))) == false
  }

  func test_hasFrame_thirdPixelValues() {
    // given: a layer at a third-pixel frame (a frame rounded for a 3x display), which doesn't round-trip exactly
    // through the layer's position and size
    let layer = CALayer()
    let third: CGFloat = 1 / 3
    let frame = CGRect(x: 10 + third, y: 20, width: 100 + third, height: 30)
    layer.frame = frame
    expect(layer.frame) != frame

    // then: the layer has the frame, because the position and the size are compared instead of the derived frame
    expect(layer.hasFrame(frame)) == true
  }

  func test_hasFrame_nonIdentityTransform() {
    // given: a layer with a frame, then rotated, and a test assertion failure handler
    let layer = CALayer()
    layer.frame = CGRect(x: 10, y: 20, width: 30, height: 40)
    layer.transform = CATransform3DMakeRotation(CGFloat.pi / 4, 0, 0, 1)

    var assertionCount = 0
    Assert.setTestAssertionFailureHandler { _, _, _, _ in
      assertionCount += 1
    }
    defer { Assert.resetTestAssertionFailureHandler() }

    // then: the model position and size are independent of the transform, so the comparison works without asserting
    expect(layer.hasFrame(CGRect(x: 10, y: 20, width: 30, height: 40))) == true
    expect(layer.hasFrame(CGRect(x: 11, y: 20, width: 30, height: 40))) == false
    expect(assertionCount) == 0
  }

  func test_hasFrame_customAnchorPoint() {
    // given: a layer anchored at its origin, with a frame
    let layer = CALayer()
    layer.anchorPoint = .zero
    layer.frame = CGRect(x: 10, y: 20, width: 30, height: 40)
    expect(layer.position) == CGPoint(x: 10, y: 20)

    // when: the size changes, which grows the frame from the origin anchor point
    layer.bounds.size = CGSize(width: 50, height: 60)

    // then: the frame is compared through the layer's own anchor point
    expect(layer.hasFrame(CGRect(x: 10, y: 20, width: 50, height: 60))) == true
    expect(layer.hasFrame(CGRect(x: 0, y: 10, width: 50, height: 60))) == false // the same size grown around the center instead
  }

  func test_hasFrame_customAnchorPoint_thirdPixelValues() {
    // given: a layer with an anchor point that is not a power of two, at a third-pixel frame, whose stored position
    // depends on the arithmetic used to compute it
    let layer = CALayer()
    layer.anchorPoint = CGPoint(x: 0.25, y: 0.75)
    let third: CGFloat = 1 / 3
    let frame = CGRect(x: 10, y: 10 + third, width: 10, height: 10 + 2 * third)
    layer.frame = frame

    // then: the layer has the frame, and not one moved by a third of a pixel
    expect(layer.hasFrame(frame)) == true
    expect(layer.hasFrame(frame.offsetBy(dx: 0, dy: third))) == false

    // when: the position is written by arithmetic that rounds twice, an ulp away from the fused result
    layer.position = CGPoint(x: frame.origin.x + 0.25 * frame.width, y: frame.origin.y + 0.75 * frame.height)
    expect(layer.position) != layer.position(from: frame)

    // then: the ulp of difference is within the geometry tolerance, so the layer still has the frame
    expect(layer.hasFrame(frame)) == true
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
