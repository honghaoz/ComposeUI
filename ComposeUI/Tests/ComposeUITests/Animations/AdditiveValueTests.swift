//
//  AdditiveValueTests.swift
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

class AdditiveValueTests: XCTestCase {

  func test_init_kinds() throws {
    // then: numbers, sizes and points, as Swift values or boxed as Core Animation keeps them, make values of their kind
    expect(try unwrap(AdditiveValue(2.5)).value as? Double) == 2.5
    expect(try unwrap(AdditiveValue(Float(0.5))).value as? Double) == 0.5
    expect(try unwrap(AdditiveValue(NSNumber(value: 3))).value as? Double) == 3
    expect(try unwrap(AdditiveValue(CGSize(width: 1, height: 2))).value as? CGSize) == CGSize(width: 1, height: 2)
    expect(try unwrap(AdditiveValue(CGSize(width: 1, height: 2) as AnyObject)).value as? CGSize) == CGSize(width: 1, height: 2)
    expect(try unwrap(AdditiveValue(CGPoint(x: 3, y: 4))).value as? CGPoint) == CGPoint(x: 3, y: 4)
    expect(try unwrap(AdditiveValue(CGPoint(x: 3, y: 4) as AnyObject)).value as? CGPoint) == CGPoint(x: 3, y: 4)

    // then: other values don't
    expect(AdditiveValue("a")) == nil
    expect(AdditiveValue(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))) == nil
  }

  func test_kinds_areToldApart() throws {
    // given: a number, a size and a point
    let number = try unwrap(AdditiveValue(1.0))
    let size = try unwrap(AdditiveValue(CGSize(width: 1, height: 0)))
    let point = try unwrap(AdditiveValue(CGPoint(x: 1, y: 0)))

    // then: only values of one kind are the same kind
    expect(try number.isSameKind(as: unwrap(AdditiveValue(2.0)))) == true
    expect(number.isSameKind(as: size)) == false
    expect(size.isSameKind(as: point)) == false
    expect(point.isSameKind(as: number)) == false
  }

  func test_arithmetic() throws {
    // given: two sizes
    let lhs = try unwrap(AdditiveValue(CGSize(width: 1, height: 2)))
    let rhs = try unwrap(AdditiveValue(CGSize(width: 3, height: 5)))

    // then: they add, subtract and scale component by component, and have a zero of their kind
    expect((lhs + rhs).value as? CGSize) == CGSize(width: 4, height: 7)
    expect((rhs - lhs).value as? CGSize) == CGSize(width: 2, height: 3)
    expect(lhs.scaled(by: 2).value as? CGSize) == CGSize(width: 2, height: 4)
    expect(lhs.zero.value as? CGSize) == CGSize.zero
    expect(lhs.zero.isZero) == true
    expect(lhs.isZero) == false

    // when: adding in place
    var sum = lhs
    sum += rhs

    // then: it's the sum
    expect(sum.value as? CGSize) == CGSize(width: 4, height: 7)
  }
}
