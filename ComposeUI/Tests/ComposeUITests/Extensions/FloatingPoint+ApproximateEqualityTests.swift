//
//  FloatingPoint+ApproximateEqualityTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/19/26.
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

class FloatingPoint_ApproximateEqualityTests: XCTestCase {

  func test_isApproximatelyEqual() {
    // then: equal values, and values within the tolerance, are approximately equal
    expect(CGFloat(1).isApproximatelyEqual(to: 1, absoluteTolerance: 0)) == true
    expect(CGFloat(1).isApproximatelyEqual(to: 1.5, absoluteTolerance: 0.5)) == true
    expect(CGFloat(1.5).isApproximatelyEqual(to: 1, absoluteTolerance: 0.5)) == true
    expect(Float(1).isApproximatelyEqual(to: 1.25, absoluteTolerance: 0.5)) == true

    // then: values beyond the tolerance are not
    expect(CGFloat(1).isApproximatelyEqual(to: 1.6, absoluteTolerance: 0.5)) == false
    expect(CGFloat(1.6).isApproximatelyEqual(to: 1, absoluteTolerance: 0.5)) == false
    expect(Float(1).isApproximatelyEqual(to: 1.6, absoluteTolerance: 0.5)) == false
  }

  func test_isApproximatelyEqual_nonFiniteValues() {
    // then: equal infinities are approximately equal even though their difference is not a number
    expect(CGFloat.infinity.isApproximatelyEqual(to: .infinity, absoluteTolerance: 0)) == true
    expect(CGFloat.infinity.isApproximatelyEqual(to: -.infinity, absoluteTolerance: 1)) == false

    // then: nothing is approximately equal to a value that is not a number
    expect(CGFloat.nan.isApproximatelyEqual(to: .nan, absoluteTolerance: 1)) == false
    expect(CGFloat(1).isApproximatelyEqual(to: .nan, absoluteTolerance: 1)) == false
  }
}
