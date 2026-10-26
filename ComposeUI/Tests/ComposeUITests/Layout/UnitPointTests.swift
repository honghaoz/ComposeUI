//
//  UnitPointTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/25/21.
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

class UnitPointTests: XCTestCase {

  func test_init() {
    // when: creating unit points with and without argument labels
    let point = UnitPoint(x: 0.3, y: 0.7)
    let unlabeledPoint = UnitPoint(0.4, 0.6)

    // then: the coordinates are the given values
    expect(point.x) == 0.3
    expect(point.y) == 0.7
    expect(unlabeledPoint.x) == 0.4
    expect(unlabeledPoint.y) == 0.6
  }

  func test_init_pointInBounds() {
    // given: bounds and the point at their center
    let bounds = CGRect(x: 0, y: 0, width: 100, height: 200)

    // when: converting the point to a unit point
    let point = UnitPoint(point: CGPoint(x: 50, y: 100), in: bounds)

    // then: the unit point is the center of the unit space
    expect(point.x) == 0.5
    expect(point.y) == 0.5
  }

  func test_init_pointInOffsetBounds() {
    // given: bounds away from the origin and a point in the same coordinate space
    let bounds = CGRect(x: 100, y: 200, width: 400, height: 600)
    let point = CGPoint(x: 200, y: 650)

    // when: converting the point to a unit point
    let unitPoint = UnitPoint(point: point, in: bounds)

    // then: the unit point is measured from the bounds' origin, so converting it back gives the point
    expect(unitPoint) == UnitPoint(x: 0.25, y: 0.75)
    expect(unitPoint.point(in: bounds)) == point
  }

  func test_presets() {
    // then: each preset is its point in the unit space
    expect(UnitPoint.center) == UnitPoint(x: 0.5, y: 0.5)
    expect(UnitPoint.left) == UnitPoint(x: 0, y: 0.5)
    expect(UnitPoint.right) == UnitPoint(x: 1, y: 0.5)
    expect(UnitPoint.top) == UnitPoint(x: 0.5, y: 0)
    expect(UnitPoint.bottom) == UnitPoint(x: 0.5, y: 1)
    expect(UnitPoint.topLeft) == UnitPoint(x: 0, y: 0)
    expect(UnitPoint.topRight) == UnitPoint(x: 1, y: 0)
    expect(UnitPoint.bottomLeft) == UnitPoint(x: 0, y: 1)
    expect(UnitPoint.bottomRight) == UnitPoint(x: 1, y: 1)
  }

  func test_cgPoint() {
    // given: a unit point
    let unitPoint = UnitPoint(x: 0.3, y: 0.7)

    // when: converting it to a CGPoint
    let cgPoint = unitPoint.cgPoint

    // then: the CGPoint has the same coordinates
    expect(cgPoint.x) == 0.3
    expect(cgPoint.y) == 0.7
  }

  func test_pointInFrame() {
    // given: a unit point and a frame away from the origin
    let unitPoint = UnitPoint(x: 0.25, y: 0.75)
    let frame = CGRect(x: 100, y: 200, width: 400, height: 600)

    // when: getting the point in the frame
    let point = unitPoint.point(in: frame)

    // then: the point is scaled by the frame's size and offset by its origin
    expect(point.x) == 200
    expect(point.y) == 650
  }

  func test_equality() {
    // then: unit points with the same coordinates are equal, whichever initializer made them
    expect(UnitPoint(x: 0.3, y: 0.7)) == UnitPoint(0.3, 0.7)
    expect(UnitPoint(x: 0.3, y: 0.7)) != UnitPoint(x: 0.7, y: 0.3)
  }

  func test_hashable() {
    // when: putting two equal unit points and a different one in a set
    let set = Set([UnitPoint(x: 0.3, y: 0.7), UnitPoint(0.3, 0.7), UnitPoint(x: 0.7, y: 0.3)])

    // then: the equal unit points collapse into one element
    expect(set.count) == 2
  }
}
