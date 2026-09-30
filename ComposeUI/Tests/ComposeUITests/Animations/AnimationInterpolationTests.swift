//
//  AnimationInterpolationTests.swift
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

import QuartzCore

import ChouTiTest

@_spi(Private) @testable import ComposeUI

class AnimationInterpolationTests: XCTestCase {

  private let red = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
  private let blue = CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)

  // MARK: - Value

  func test_value_atTheEnds_isTheValueItself() throws {
    // given: values that interpolate, and values that don't
    let pairs: [(from: AnyObject, to: AnyObject)] = [
      (red, blue),
      (NSNumber(value: 1), NSNumber(value: 2)),
      (NSString(string: "a"), NSString(string: "b")),
    ]

    for (from, to) in pairs {
      // then: at a progress of 0 and 1 it's the from or to value itself
      expect(AnimationInterpolation.value(from: from, to: to, progress: 0) as AnyObject) === from
      expect(AnimationInterpolation.value(from: from, to: to, progress: 1) as AnyObject) === to
    }
  }

  func test_value_numbersSizesAndPoints_interpolateComponentByComponent() {
    // then: numbers, sizes and points, as Core Animation boxes them, interpolate component by component, past the to
    // value for an overshoot
    expect(AnimationInterpolation.value(from: NSNumber(value: 2), to: NSNumber(value: 10), progress: 0.25) as? Double) == 4
    expect(AnimationInterpolation.value(from: NSNumber(value: 2), to: NSNumber(value: 10), progress: 1.5) as? Double) == 14
    expect(AnimationInterpolation.value(from: CGSize(width: 0, height: 8) as AnyObject, to: CGSize(width: 8, height: 0) as AnyObject, progress: 0.25) as? CGSize) == CGSize(width: 2, height: 6)
    expect(AnimationInterpolation.value(from: CGPoint(x: 10, y: 20) as AnyObject, to: CGPoint(x: 50, y: -20) as AnyObject, progress: 0.25) as? CGPoint) == CGPoint(x: 20, y: 10)
  }

  func test_value_valuesThatDontInterpolate_isNil() throws {
    // then: values of other kinds, or of mismatched kinds, don't interpolate
    expect(AnimationInterpolation.value(from: NSString(string: "a"), to: NSString(string: "b"), progress: 0.5)) == nil
    expect(AnimationInterpolation.value(from: NSNumber(value: 1), to: CGSize.zero as AnyObject, progress: 0.5)) == nil
    expect(AnimationInterpolation.value(from: red, to: NSNumber(value: 1), progress: 0.5)) == nil
  }

  func test_value_colorsAndPaths_interpolateAsColorsAndPaths() throws {
    // given: colors and paths
    let square = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)
    let rect = CGPath(rect: CGRect(x: 10, y: 20, width: 20, height: 50), transform: nil)

    // then: they interpolate as colors and paths
    try expectExtendedSRGBComponents(of: colorValue(AnimationInterpolation.value(from: red, to: blue, progress: 0.25)), toBe: [0.75, 0, 0.25, 1])
    expect(try PathPoints(pathValue(AnimationInterpolation.value(from: square, to: rect, progress: 0.25)))) == PathPoints(CGPath(rect: CGRect(x: 2.5, y: 5, width: 80, height: 87.5), transform: nil))
  }

  // MARK: - Color

  func test_color_interpolatesTheExtendedSRGBComponents() throws {
    // given: colors of several color spaces, with alpha
    let pairs = try [
      (red, CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 0.5)),
      (CGColor(gray: 0.2, alpha: 1), CGColor(colorSpace: unwrap(CGColorSpace(name: CGColorSpace.displayP3)), components: [0, 1, 0, 1]).unwrap()),
    ]

    for (from, to) in pairs {
      // when: interpolating a quarter of the way
      let color = try AnimationInterpolation.color(from: from, to: to, progress: 0.25).unwrap()

      // then: the color is in extended sRGB, a quarter of the way component by component, with straight alpha
      expect(color.colorSpace?.name) == CGColorSpace.extendedSRGB
      try expectExtendedSRGBComponents(of: color, toBe: interpolatedExtendedSRGBComponents(from: from, to: to, progress: 0.25))
    }
  }

  func test_color_pattern_isNil() throws {
    // given: a pattern color, which has no extended sRGB components
    var callbacks = CGPatternCallbacks(version: 0, drawPattern: { _, _ in }, releaseInfo: nil)
    let pattern = try CGPattern(info: nil, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), matrix: .identity, xStep: 1, yStep: 1, tiling: .noDistortion, isColored: true, callbacks: &callbacks).unwrap()
    var alpha: CGFloat = 1
    let patternColor = try CGColor(patternSpace: CGColorSpace(patternBaseSpace: nil).unwrap(), pattern: pattern, components: &alpha).unwrap()

    // then: a color and a pattern don't interpolate, either way
    expect(AnimationInterpolation.color(from: red, to: patternColor, progress: 0.5)) == nil
    expect(AnimationInterpolation.color(from: patternColor, to: red, progress: 0.5)) == nil
  }

  // MARK: - Path

  func test_path_interpolatesPointByPoint() throws {
    // given: rounded rects with the same segments
    let from = CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 100), cornerWidth: 10, cornerHeight: 10, transform: nil)
    let to = CGPath(roundedRect: CGRect(x: 0, y: 0, width: 200, height: 100), cornerWidth: 20, cornerHeight: 20, transform: nil)

    // when: interpolating a quarter of the way
    let path = try AnimationInterpolation.path(from: from, to: to, progress: 0.25).unwrap()

    // then: each point is a quarter of the way
    let expected = PathPoints(from).adding(PathPoints(to).subtracting(PathPoints(from)), multipliedBy: 0.25)
    expect(PathPoints(path)) == expected
  }

  func test_path_otherSegmentsOrInfinitePoints_isNil() {
    // given: a square, and paths that can't be added to it point by point
    let square = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)
    let ellipse = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)
    let nullRect = CGPath(rect: .null, transform: nil)

    // then: they don't interpolate, either way
    expect(AnimationInterpolation.path(from: square, to: ellipse, progress: 0.5)) == nil
    expect(AnimationInterpolation.path(from: square, to: nullRect, progress: 0.5)) == nil
    expect(AnimationInterpolation.path(from: nullRect, to: square, progress: 0.5)) == nil
  }

  // MARK: - Core Animation

  func test_value_matchesCoreAnimation() throws {
    // given: layers on a paused timeline, each with a linear animation between two values, from 100 over 10 s
    let testWindow = TestWindow()
    let root = CALayer()
    root.speed = 0
    root.timeOffset = 100
    testWindow.layer.addSublayer(root)
    CATransaction.flush()

    let displayP3 = try unwrap(CGColorSpace(name: CGColorSpace.displayP3))
    let extendedSRGB = try unwrap(CGColorSpace(name: CGColorSpace.extendedSRGB))
    let linearSRGB = try unwrap(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
    let cases: [(keyPath: String, from: AnyObject, to: AnyObject)] = try [
      ("cornerRadius", NSNumber(value: 2), NSNumber(value: 18)),
      ("shadowOffset", CGSize(width: 0, height: 8) as AnyObject, CGSize(width: 8, height: -4) as AnyObject),
      ("position", CGPoint(x: 10, y: 20) as AnyObject, CGPoint(x: 50, y: -20) as AnyObject),
      ("backgroundColor", red, CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 0.2)),
      ("backgroundColor", CGColor(gray: 0.2, alpha: 1), CGColor(colorSpace: displayP3, components: [0, 1, 0, 1]).unwrap()),
      ("backgroundColor", CGColor(red: 1, green: 0, blue: 0, alpha: 1), CGColor(colorSpace: extendedSRGB, components: [1.2, -0.1, 0.5, 1]).unwrap()),
      ("backgroundColor", CGColor(colorSpace: linearSRGB, components: [1, 0.5, 0, 1]).unwrap(), blue),
      ("shadowPath", CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil), CGPath(rect: CGRect(x: 10, y: 20, width: 20, height: 50), transform: nil)),
      ("shadowPath", CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 100), cornerWidth: 10, cornerHeight: 10, transform: nil), CGPath(roundedRect: CGRect(x: 0, y: 0, width: 200, height: 60), cornerWidth: 20, cornerHeight: 20, transform: nil)),
    ]
    let layers = cases.map { testCase -> CALayer in
      let layer = CALayer()
      layer.frame = CGRect(x: 0, y: 0, width: 10, height: 10)
      root.addSublayer(layer)
      CATransaction.disableAnimations {
        layer.setValue(testCase.to, forKeyPath: testCase.keyPath)
      }
      let animation = CABasicAnimation(keyPath: testCase.keyPath)
      animation.fromValue = testCase.from
      animation.toValue = testCase.to
      animation.beginTime = 100
      animation.duration = 10
      animation.fillMode = .both
      layer.add(animation, forKey: testCase.keyPath)
      return layer
    }

    for progress in [0.25, 0.5, 0.75] {
      // when: moving the timeline
      root.timeOffset = 100 + 10 * progress
      CATransaction.flush()

      for (testCase, layer) in zip(cases, layers) {
        // then: the interpolated value is the one Core Animation shows, paced exactly without a timing function
        let description = "\(testCase.keyPath) from \(testCase.from) at \(progress)"
        let shown = try unwrap(layer.presentation()?.value(forKeyPath: testCase.keyPath), description)
        let interpolated = try unwrap(AnimationInterpolation.value(from: testCase.from, to: testCase.to, progress: progress), description)
        switch testCase.keyPath {
        case "cornerRadius":
          expect(try numberScalar(interpolated), description).to(try beApproximatelyEqual(to: numberScalar(shown), within: 1e-4))
        case "shadowOffset":
          let size = try unwrap(interpolated as? CGSize)
          let shownSize = try unwrap(shown as? CGSize)
          expect(size.width, description).to(beApproximatelyEqual(to: shownSize.width, within: 1e-4))
          expect(size.height, description).to(beApproximatelyEqual(to: shownSize.height, within: 1e-4))
        case "position":
          let point = try unwrap(interpolated as? CGPoint)
          let shownPoint = try unwrap(shown as? CGPoint)
          expect(point.x, description).to(beApproximatelyEqual(to: shownPoint.x, within: 1e-4))
          expect(point.y, description).to(beApproximatelyEqual(to: shownPoint.y, within: 1e-4))
        case "backgroundColor":
          try expectExtendedSRGBComponents(of: colorValue(interpolated), toBe: colorValue(shown).extendedSRGBComponents(), within: 1e-5)
        default:
          // Core Animation turns the lines of a path it shows into curves, so the paths are compared by their bounds
          let bounds = try pathValue(interpolated).boundingBoxOfPath
          let shownBounds = try pathValue(shown).boundingBoxOfPath
          for (value, shownValue) in zip([bounds.minX, bounds.minY, bounds.width, bounds.height], [shownBounds.minX, shownBounds.minY, shownBounds.width, shownBounds.height]) {
            expect(value, description).to(beApproximatelyEqual(to: shownValue, within: 1e-4))
          }
        }
      }
    }
  }
}
