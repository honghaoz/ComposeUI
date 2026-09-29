//
//  CGFloat+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/26.
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

class CGFloat_ExtensionsTests: XCTestCase {

  func test_extendsBeyond() {
    // then: a length extends beyond a shorter length, including one shorter by less than a pixel
    expect(CGFloat(100.5).extends(beyond: 100)) == true
    expect(CGFloat(100.1).extends(beyond: 100)) == true

    // then: a length doesn't extend beyond an equal or longer length
    expect(CGFloat(100).extends(beyond: 100)) == false
    expect(CGFloat(99.5).extends(beyond: 100)) == false

    // then: a length doesn't extend beyond a length it exceeds by floating-point noise
    expect(CGFloat(100).nextUp.extends(beyond: 100)) == false
    expect(CGFloat(100 + 1e-9).extends(beyond: 100)) == false
  }

  func test_extendsBeyond_tolerance() {
    // then: a length extends beyond another only by more than the geometry tolerance
    expect(Constants.geometryTolerance.extends(beyond: 0)) == false
    expect(Constants.geometryTolerance.nextUp.extends(beyond: 0)) == true
  }

  func test_extendsBeyond_nonFiniteValues() {
    // then: an infinite length extends beyond a finite length, but not beyond an equal infinity
    expect(CGFloat.infinity.extends(beyond: 100)) == true
    expect(CGFloat.infinity.extends(beyond: .infinity)) == false
    expect(CGFloat(100).extends(beyond: .infinity)) == false

    // then: a value that is not a number neither extends beyond a length nor is extended beyond
    expect(CGFloat.nan.extends(beyond: 100)) == false
    expect(CGFloat(100).extends(beyond: .nan)) == false
  }
}
