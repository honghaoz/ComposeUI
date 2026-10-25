//
//  CGRect+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/17/26.
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

class CGRect_ExtensionsTests: XCTestCase {

  // MARK: - Parts Outside Another Rectangle

  func test_forEachPart_otherInside_givesTheFourPartsAroundIt() {
    // given: a rectangle, and another rectangle inside it
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
    let other = CGRect(x: 20, y: 30, width: 40, height: 50)

    // when: going through the parts of the rectangle outside the other
    let parts = parts(of: rect, outside: other)

    // then: the parts are the bands above and below the other across the whole width, then the parts to its left and
    // right between the bands
    expect(parts) == [
      CGRect(x: 0, y: 0, width: 100, height: 30),
      CGRect(x: 0, y: 80, width: 100, height: 20),
      CGRect(x: 0, y: 30, width: 20, height: 50),
      CGRect(x: 60, y: 30, width: 40, height: 50),
    ]
  }

  func test_forEachPart_otherOverAnEdge_givesThePartPastIt() {
    // given: a rectangle, and another rectangle of the same width that covers all of it but its bottom
    let rect = CGRect(x: 0, y: -270, width: 200, height: 900)
    let other = CGRect(x: 0, y: -300, width: 200, height: 900)

    // when: going through the parts of the rectangle outside the other
    let parts = parts(of: rect, outside: other)

    // then: the only part is the bottom band
    expect(parts) == [CGRect(x: 0, y: 600, width: 200, height: 30)]
  }

  func test_forEachPart_otherOverACorner_givesTheTwoPartsAroundIt() {
    // given: a rectangle, and another rectangle over its top left corner
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
    let other = CGRect(x: -10, y: -10, width: 50, height: 40)

    // when: going through the parts of the rectangle outside the other
    let parts = parts(of: rect, outside: other)

    // then: the parts are the band below the other across the whole width, then the part to its right beside it
    expect(parts) == [
      CGRect(x: 0, y: 30, width: 100, height: 70),
      CGRect(x: 40, y: 0, width: 60, height: 30),
    ]
  }

  func test_forEachPart_otherCoveringTheRectangle_givesNothing() {
    // given: a rectangle, the same rectangle, and a larger rectangle around it
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)

    // then: no part of the rectangle is outside either
    expect(parts(of: rect, outside: rect)) == []
    expect(parts(of: rect, outside: rect.insetBy(dx: -10, dy: -10))) == []
  }

  func test_forEachPart_otherOutside_givesTheWholeRectangle() {
    // given: a rectangle, and rectangles that it doesn't overlap: one apart from it, one next to it, and the null
    // rectangle
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)

    // then: the only part is the whole rectangle
    expect(parts(of: rect, outside: CGRect(x: 200, y: 0, width: 100, height: 100))) == [rect]
    expect(parts(of: rect, outside: CGRect(x: 0, y: 100, width: 100, height: 100))) == [rect]
    expect(parts(of: rect, outside: .null)) == [rect]
  }

  func test_forEachPart_emptyRectangle_givesNothing() {
    // given: a rectangle without an area, and a rectangle that it doesn't overlap
    let rect = CGRect(x: 0, y: 0, width: 100, height: 0)

    // then: there is no part
    expect(parts(of: rect, outside: CGRect(x: 200, y: 0, width: 100, height: 100))) == []
  }

  // MARK: - Inline Geometry

  func test_isNullInline_matchesIsNull() {
    // given: rectangles of special and random values
    let rects = Self.specialRects + Self.randomRects()

    // then: each is null inline exactly when CoreGraphics tells it's null
    expect(rects.filter { $0.isNullInline != $0.isNull }) == []
  }

  func test_edgesInline_matchesMinAndMax() {
    // given: rectangles of special and random values
    let rects = Self.specialRects + Self.randomRects()

    // then: each rectangle's edges inline are CoreGraphics' edges
    let mismatches = rects.filter { rect in
      let edges = rect.edgesInline
      return !Self.isSame(edges.minX, rect.minX) || !Self.isSame(edges.minY, rect.minY)
        || !Self.isSame(edges.maxX, rect.maxX) || !Self.isSame(edges.maxY, rect.maxY)
    }
    expect(mismatches) == []
  }

  func test_unionInline_matchesUnion() {
    // given: each pair of special rectangles, and pairs of random rectangles
    let specialPairs = Self.specialRects.flatMap { rect in Self.specialRects.map { (rect, $0) } }
    let randomRects = Self.randomRects()
    let randomPairs = zip(randomRects, randomRects.dropFirst()).map { ($0, $1) }

    // then: each pair's union inline is CoreGraphics' union, including a null rectangle's other rectangle as it is
    let mismatches = (specialPairs + randomPairs).filter { !Self.isSame($0.unionInline($1), $0.union($1)) }
    expect(mismatches.map { "\($0) \($1)" }) == []
  }

  // MARK: - Helpers

  private func parts(of rect: CGRect, outside other: CGRect) -> [CGRect] {
    var parts: [CGRect] = []
    rect.forEachPart(outside: other) { parts.append($0) }
    return parts
  }

  /// Rectangles whose values make CoreGraphics' geometry take its special paths: the null and infinite rectangles,
  /// negative sizes, zeros of either sign, infinities and NaNs.
  private static let specialRects: [CGRect] = {
    let infinity = CGFloat.infinity
    let nan = CGFloat.nan
    let largest = CGFloat.greatestFiniteMagnitude
    let negativeZero = -CGFloat.zero
    return [
      .null,
      .infinite,
      .zero,
      CGRect(x: 10, y: 20, width: 30, height: 40),
      CGRect(x: 10, y: 20, width: -4, height: -6),
      CGRect(x: negativeZero, y: negativeZero, width: 5, height: 5),
      CGRect(x: negativeZero, y: negativeZero, width: negativeZero, height: negativeZero),
      CGRect(x: 0, y: 0, width: negativeZero, height: 3),
      CGRect(x: infinity, y: 0, width: 1, height: 1),
      CGRect(x: 0, y: infinity, width: 1, height: 1),
      CGRect(x: -infinity, y: 0, width: 1, height: 1),
      CGRect(x: 0, y: 0, width: infinity, height: 1),
      CGRect(x: 0, y: 0, width: -infinity, height: 1),
      CGRect(x: nan, y: 0, width: 1, height: 1),
      CGRect(x: 0, y: 0, width: nan, height: 1),
      CGRect(x: -largest, y: largest, width: largest, height: -1),
    ]
  }()

  /// Returns rectangles of random values, a quarter of them special, from a seeded generator, so a failure repeats.
  private static func randomRects() -> [CGRect] {
    var generator = SeededRandomNumberGenerator(seed: 0x5EED)
    let specialValues: [CGFloat] = [0, -0.0, 1, -1, 0.1, 1e-300, .infinity, -.infinity, .nan, .greatestFiniteMagnitude, -.greatestFiniteMagnitude]
    func value() -> CGFloat {
      Int.random(in: 0 ..< 4, using: &generator) == 0
        ? specialValues[Int.random(in: 0 ..< specialValues.count, using: &generator)]
        : CGFloat.random(in: -1000 ... 1000, using: &generator)
    }
    return (0 ..< 20000).map { _ in CGRect(x: value(), y: value(), width: value(), height: value()) }
  }

  /// Whether two values are the same, bit for bit, or both NaN, whose bits x86 and arm64 make differently.
  private static func isSame(_ value: CGFloat, _ other: CGFloat) -> Bool {
    (value.isNaN && other.isNaN) || value.bitPattern == other.bitPattern
  }

  private static func isSame(_ rect: CGRect, _ other: CGRect) -> Bool {
    isSame(rect.origin.x, other.origin.x) && isSame(rect.origin.y, other.origin.y)
      && isSame(rect.size.width, other.size.width) && isSame(rect.size.height, other.size.height)
  }
}

/// A random number generator that makes the same numbers for the same seed, with SplitMix64.
private struct SeededRandomNumberGenerator: RandomNumberGenerator {

  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state &+= 0x9E3779B97F4A7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
    value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
    return value ^ (value >> 31)
  }
}
