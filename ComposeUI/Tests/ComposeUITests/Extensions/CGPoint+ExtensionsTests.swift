//
//  CGPoint+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/1/26.
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

import CoreGraphics

import ChouTiTest

@testable import ComposeUI

class CGPoint_ExtensionsTests: XCTestCase {

  func test_roundedToPixelSize() {
    // then: at 2x, each coordinate rounds to the nearest half point, and a point on whole pixels stays
    let pixelSize = CGSize(width: 0.5, height: 0.5)
    expect(CGPoint(x: 10.3, y: 20.2).rounded(toPixelSize: pixelSize)) == CGPoint(x: 10.5, y: 20)
    expect(CGPoint(x: 10.5, y: 20).rounded(toPixelSize: pixelSize)) == CGPoint(x: 10.5, y: 20)

    // then: at 1x, each coordinate rounds to the nearest point
    expect(CGPoint(x: 10.4, y: 10.6).rounded(toPixelSize: CGSize(width: 1, height: 1))) == CGPoint(x: 10, y: 11)
  }

  func test_roundedToPixelSize_halfwayAndNegativeCoordinates() {
    // then: a coordinate halfway between two pixels rounds away from zero, and a negative one rounds to its nearest pixel
    let pixelSize = CGSize(width: 0.5, height: 0.5)
    expect(CGPoint(x: 0.25, y: -0.25).rounded(toPixelSize: pixelSize)) == CGPoint(x: 0.5, y: -0.5)
    expect(CGPoint(x: -10.3, y: -10.2).rounded(toPixelSize: pixelSize)) == CGPoint(x: -10.5, y: -10)
  }

  func test_roundedToPixelSize_differentPixelSizeAlongEachAxis() {
    // then: each coordinate rounds to the pixel size along its own axis, as in a scroll view whose bounds are scaled
    // along one axis
    let pixelSize = CGSize(width: 0.5, height: 1.0 / 3)
    expect(CGPoint(x: 1.2, y: 1.2).rounded(toPixelSize: pixelSize)) == CGPoint(x: 1, y: 4.0 / 3)
  }
}
