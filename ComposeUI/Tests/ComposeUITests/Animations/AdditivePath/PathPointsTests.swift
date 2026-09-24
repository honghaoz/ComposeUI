//
//  PathPointsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/23/26.
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

@_spi(Private) @testable import ComposeUI

class PathPointsTests: XCTestCase {

  func test_init_splitsTheSegments() {
    // given: a path with every kind of segment
    let path = makePathOfEverySegment()

    // when: splitting it
    let pathPoints = PathPoints(path)

    // then: the kinds are in order, and each segment contributes its points, control points first
    expect(pathPoints.kinds) == [.moveToPoint, .addLineToPoint, .addQuadCurveToPoint, .addCurveToPoint, .closeSubpath]
    expect(pathPoints.points) == [
      CGPoint(x: 0, y: 0), // move
      CGPoint(x: 10, y: 0), // line
      CGPoint(x: 20, y: 0), CGPoint(x: 20, y: 10), // quad curve
      CGPoint(x: 20, y: 20), CGPoint(x: 10, y: 20), CGPoint(x: 0, y: 20), // cubic curve
    ]
  }

  func test_path_rebuildsThePath() {
    // given: a path with every kind of segment, and a rounded rect
    let paths = [
      makePathOfEverySegment(),
      CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 50), cornerWidth: 10, cornerHeight: 10, transform: nil),
    ]

    for path in paths {
      // then: the split path rebuilds a path of the same segments and points. `CGPath` equality also compares how a path
      // is stored, so the points are compared instead
      expect(PathPoints(PathPoints(path).path)) == PathPoints(path)
    }
  }

  func test_isZero() {
    // given: a rect and an inset rect
    let rect = PathPoints(CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50), transform: nil))
    let insetRect = PathPoints(CGPath(rect: CGRect(x: 10, y: 10, width: 80, height: 30), transform: nil))

    // then: the difference of a path and itself is zero, the difference of other paths isn't
    expect(rect.subtracting(rect).isZero) == true
    expect(rect.subtracting(insetRect).isZero) == false
  }

  func test_isFinite() {
    // then: a rect's points are finite, and a null rect's points are at infinity
    expect(PathPoints(CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50), transform: nil)).isFinite) == true
    expect(PathPoints(CGPath(rect: .null, transform: nil)).isFinite) == false
  }

  func test_hasSameSegments() {
    // given: rounded rects of different sizes and corner radii, and a rect
    let roundedRect = PathPoints(CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 50), cornerWidth: 10, cornerHeight: 10, transform: nil))
    let biggerRoundedRect = PathPoints(CGPath(roundedRect: CGRect(x: 0, y: 0, width: 200, height: 80), cornerWidth: 20, cornerHeight: 20, transform: nil))
    let rect = PathPoints(CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50), transform: nil))

    // then: the rounded rects have the same segments, the rect has other segments
    expect(roundedRect.hasSameSegments(as: biggerRoundedRect)) == true
    expect(roundedRect.hasSameSegments(as: rect)) == false
  }

  func test_adding() {
    // given: two rects
    let rect = PathPoints(CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50), transform: nil))
    let otherRect = PathPoints(CGPath(rect: CGRect(x: 10, y: 20, width: 30, height: 40), transform: nil))

    // when: adding the other rect's points
    let sum = rect.adding(otherRect)

    // then: the points are added point by point
    expect(sum.kinds) == rect.kinds
    expect(sum.points) == [
      CGPoint(x: 10, y: 20),
      CGPoint(x: 140, y: 20),
      CGPoint(x: 140, y: 110),
      CGPoint(x: 10, y: 110),
    ]

    // when: adding the other rect's points multiplied by a factor
    let scaledSum = rect.adding(otherRect, multipliedBy: 0.5)

    // then: the other rect's points are scaled before they are added
    expect(scaledSum.points) == [
      CGPoint(x: 5, y: 10),
      CGPoint(x: 120, y: 10),
      CGPoint(x: 120, y: 80),
      CGPoint(x: 5, y: 80),
    ]
  }

  func test_subtracting() {
    // given: a rect and an inset rect
    let rect = PathPoints(CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50), transform: nil))
    let insetRect = PathPoints(CGPath(rect: CGRect(x: 10, y: 10, width: 80, height: 30), transform: nil))

    // when: subtracting the inset rect from the rect
    let difference = rect.subtracting(insetRect)

    // then: each point is the rect's point minus the inset rect's point, and adding it back gives the rect
    expect(difference.points) == [
      CGPoint(x: -10, y: -10),
      CGPoint(x: 10, y: -10),
      CGPoint(x: 10, y: 10),
      CGPoint(x: -10, y: 10),
    ]
    expect(insetRect.adding(difference)) == rect
  }

  func test_adding_otherSegments_asserts() {
    // given: a rect and a rounded rect
    let rect = PathPoints(CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50), transform: nil))
    let roundedRect = PathPoints(CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 50), cornerWidth: 10, cornerHeight: 10, transform: nil))

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: adding paths with other segments
    _ = rect.adding(roundedRect)

    // then: it asserts, as their points don't line up
    expect(assertionMessages) == ["expected paths with the same segments"]
  }

  // MARK: - Helpers

  /// A path with a move, a line, a quad curve, a cubic curve and a close.
  private func makePathOfEverySegment() -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 0, y: 0))
    path.addLine(to: CGPoint(x: 10, y: 0))
    path.addQuadCurve(to: CGPoint(x: 20, y: 10), control: CGPoint(x: 20, y: 0))
    path.addCurve(to: CGPoint(x: 0, y: 20), control1: CGPoint(x: 20, y: 20), control2: CGPoint(x: 10, y: 20))
    path.closeSubpath()
    return path
  }
}
