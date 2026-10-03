//
//  EdgeInsets+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
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

@testable import ComposeUI

class EdgeInsets_ExtensionsTests: XCTestCase {

  func test_horizontal() {
    // given: insets with different edge values
    let insets = EdgeInsets(top: 1, left: 2, bottom: 3, right: 4)

    // then: horizontal is the sum of left and right
    expect(insets.horizontal) == 6
  }

  func test_vertical() {
    // given: insets with different edge values
    let insets = EdgeInsets(top: 1, left: 2, bottom: 3, right: 4)

    // then: vertical is the sum of top and bottom
    expect(insets.vertical) == 4
  }

  func test_initInset() {
    // given: insets created with a uniform inset value
    let insets = EdgeInsets(inset: 8)

    // then: all edges have the inset value
    expect(insets.top) == 8
    expect(insets.left) == 8
    expect(insets.bottom) == 8
    expect(insets.right) == 8
    expect(insets.horizontal) == 16
    expect(insets.vertical) == 16
  }

  func test_isEqual() {
    // given: insets with different edge values
    let insets = EdgeInsets(top: 1, left: 2, bottom: 3, right: 4)

    // then: insets with the same values are equal
    expect(insets.isEqual(to: EdgeInsets(top: 1, left: 2, bottom: 3, right: 4))) == true

    // then: a different value on any edge makes them unequal
    expect(insets.isEqual(to: EdgeInsets(top: 0, left: 2, bottom: 3, right: 4))) == false
    expect(insets.isEqual(to: EdgeInsets(top: 1, left: 0, bottom: 3, right: 4))) == false
    expect(insets.isEqual(to: EdgeInsets(top: 1, left: 2, bottom: 0, right: 4))) == false
    expect(insets.isEqual(to: EdgeInsets(top: 1, left: 2, bottom: 3, right: 0))) == false
  }

  func test_add() {
    // given: insets with different edge values
    let insets = EdgeInsets(top: 1, left: 2, bottom: 3, right: 4)

    // when: other insets are added
    let sum = insets + EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)

    // then: each edge is the sum of the two edges
    expect([sum.top, sum.left, sum.bottom, sum.right]) == [11, 22, 33, 44]
  }

  func test_subtract() {
    // given: insets with different edge values
    let insets = EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)

    // when: other insets are subtracted
    let difference = insets - EdgeInsets(top: 1, left: 2, bottom: 3, right: 50)

    // then: each edge is the difference of the two edges, negative where the subtracted edge is larger
    expect([difference.top, difference.left, difference.bottom, difference.right]) == [9, 18, 27, -10]
  }
}
