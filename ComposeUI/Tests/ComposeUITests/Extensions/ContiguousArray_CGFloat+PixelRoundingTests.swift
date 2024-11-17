//
//  ContiguousArray_CGFloat+PixelRoundingTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 5/23/23.
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

import XCTest
@testable import ComposeUI

class ContiguousArray_CGFloat_PixelRoundingTests: XCTestCase {

  func testEmptyArray() {
    let array: ContiguousArray<CGFloat> = []
    XCTAssertEqual(array.rounded(scaleFactor: 2), [])
  }

  func testArrayWithOneElement() {
    let array: ContiguousArray<CGFloat> = [10.33333]
    XCTAssertEqual(array.rounded(scaleFactor: 2), [10.33333])
  }

  func testArrayWithMultipleElements() {
    let array: ContiguousArray<CGFloat> = [10.3333333333, 10.333333333, 10.3333333333]
    XCTAssertEqual(array.rounded(scaleFactor: 2), [10.5, 10.5, 9.999999999600002])
  }

  func testArrayWithMoreElements() {
    let array: ContiguousArray<CGFloat> = [51.6666666667, 51.6666666667, 51.6666666667, 51.6666666667, 51.6666666667, 51.6666666667]
    XCTAssertEqual(array.rounded(scaleFactor: 2), [51.5, 51.5, 51.5, 52, 51.5, 52.00000000020002])
  }

  func testArrayWithTooSmallPixelWidths() {
    let array: ContiguousArray<CGFloat> = [0.3, 0.3, 0.3]
    XCTAssertEqual(array.rounded(scaleFactor: 2), [0.3, 0.3, 0.3])
  }

  func testArrayWithTooSmallPixelWidths2() {
    let array: ContiguousArray<CGFloat> = [0.3]
    XCTAssertEqual(array.rounded(scaleFactor: 2), [0.3])
  }

  func testArrayWithTooSmallPixelWidths3() {
    let array: ContiguousArray<CGFloat> = [0.3, 0.3]
    let roundedArray = array.rounded(scaleFactor: 2)
    XCTAssertEqual(roundedArray[0], 0.5)
    XCTAssertEqual(roundedArray[1], 0.1, accuracy: 1e-12)
  }
}
