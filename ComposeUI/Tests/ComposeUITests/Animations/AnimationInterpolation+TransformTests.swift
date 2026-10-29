//
//  AnimationInterpolation+TransformTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/28/26.
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

class AnimationInterpolation_TransformTests: XCTestCase {

  func test_transform_endpoints_areTheTransformsThemselves() throws {
    // given: a transform with perspective and one without, which a decomposition gives back only within rounding
    let from = Constants.perspectiveTurn
    let to = Constants.skewedTurnAndMove

    // then: the start and the end are the transforms themselves
    expect(try CATransform3DEqualToTransform(unwrap(AnimationInterpolation.transform(from: from, to: to, progress: 0)), from)) == true
    expect(try CATransform3DEqualToTransform(unwrap(AnimationInterpolation.transform(from: from, to: to, progress: 1)), to)) == true
  }

  func test_transform_sameTransform_givesItBack() throws {
    for transform in [Constants.skewedTurnAndMove, Constants.perspectiveTurn, Constants.flip, CATransform3DIdentity] {
      // when: interpolating from a transform to itself
      let interpolated = try unwrap(AnimationInterpolation.transform(from: transform, to: transform, progress: 0.5))

      // then: the transform comes back from its decomposition
      expectTransform(interpolated, toBe: transform, within: 1e-9)
    }
  }

  func test_transform_turn_goesTheShortWayAround() throws {
    // given: a turn of 10° and one of 350°
    let from = CATransform3DMakeRotation(10 * Constants.degree, 0, 0, 1)
    let to = CATransform3DMakeRotation(350 * Constants.degree, 0, 0, 1)

    // when: interpolating halfway
    let interpolated = try unwrap(AnimationInterpolation.transform(from: from, to: to, progress: 0.5))

    // then: the transform is no turn, which the short way around passes through
    expectTransform(interpolated, toBe: CATransform3DIdentity, within: 1e-9)
  }

  func test_transform_progressPastTheEnd_overshoots() throws {
    // given: no turn and a quarter turn, as 2D and 3D transforms
    let quarterTurn = CATransform3DMakeRotation(90 * Constants.degree, 0, 0, 1)
    let perspective = Constants.perspective

    // when: interpolating past the end, as a spring overshoots
    let affine = try unwrap(AnimationInterpolation.transform(from: CATransform3DIdentity, to: quarterTurn, progress: 1.2))
    let general = try unwrap(AnimationInterpolation.transform(from: perspective, to: CATransform3DConcat(quarterTurn, perspective), progress: 1.2))

    // then: the turn goes past the quarter turn, to 108°
    let overshoot = CATransform3DMakeRotation(108 * Constants.degree, 0, 0, 1)
    expectTransform(affine, toBe: overshoot, within: 1e-9)
    expectTransform(general, toBe: CATransform3DConcat(overshoot, perspective), within: 1e-9)
  }

  func test_transform_nonAffineWithoutAnInverse_isNil() {
    // given: a 3D transform that scales depth to zero, which doesn't decompose, and the identity
    let flat = CATransform3DMakeScale(1, 1, 0)

    // then: the transforms don't interpolate, either way
    expect(AnimationInterpolation.transform(from: flat, to: CATransform3DIdentity, progress: 0.5)) == nil
    expect(AnimationInterpolation.transform(from: CATransform3DIdentity, to: flat, progress: 0.5)) == nil
  }

  func test_transformInterpolator_isLinear_forAffineTransformsThatDifferOnlyInScaleAndTranslation() throws {
    // given: affine transforms that differ only in their scale and translation, under the same turn or none, and
    // transforms that differ in their turn or skew, flips that make a half turn, and transforms in 3D
    let turn = CATransform3DMakeRotation(30 * Constants.degree, 0, 0, 1)
    var skew = CATransform3DIdentity
    skew.m21 = 0.5
    let linearCases: [(name: String, from: CATransform3D, to: CATransform3D)] = [
      ("scale", CATransform3DIdentity, CATransform3DMakeScale(0.95, 0.95, 1)),
      ("move", CATransform3DMakeTranslation(5, 7, 0), CATransform3DMakeTranslation(-3, 11, 0)),
      ("scale and move", CATransform3DMakeTranslation(5, 7, 0), CATransform3DTranslate(CATransform3DMakeScale(1.2, 0.8, 1), 4, 4, 0)),
      ("scale under a turn", turn, CATransform3DScale(turn, 0.5, 2, 1)),
      ("flip of an axis", CATransform3DIdentity, Constants.flip),
    ]
    let otherCases: [(name: String, from: CATransform3D, to: CATransform3D)] = [
      ("turn", CATransform3DIdentity, turn),
      ("skew", CATransform3DIdentity, skew),
      ("flip to the other flip", Constants.flip, CATransform3DMakeScale(1, -1, 1)),
      ("flip of both axes", CATransform3DIdentity, CATransform3DMakeScale(-1, -1, 1)),
      ("scale in perspective", Constants.perspective, CATransform3DConcat(CATransform3DMakeScale(2, 2, 1), Constants.perspective)),
    ]

    for testCase in linearCases {
      // when: interpolating between transforms that differ only in their scale and translation
      let interpolator = try unwrap(TransformInterpolator(from: testCase.from, to: testCase.to), testCase.name)

      // then: the interpolation is linear, and blends the matrices element by element
      expect(interpolator.isLinear, testCase.name) == true
      expectTransform(interpolator.transform(atProgress: 0.3), toBe: linearBlend(from: testCase.from, to: testCase.to, progress: 0.3), within: 1e-9, testCase.name)
    }
    for testCase in otherCases {
      // when: interpolating between other transforms
      let interpolator = try unwrap(TransformInterpolator(from: testCase.from, to: testCase.to), testCase.name)

      // then: the interpolation isn't linear
      expect(interpolator.isLinear, testCase.name) == false
    }
  }

  // MARK: - Core Animation

  func test_transform_matchesCoreAnimation() throws {
    // given: layers on a paused timeline, each with a linear animation between two transforms, from 100 over 10 s
    let testWindow = TestWindow()
    let root = CALayer()
    root.speed = 0
    root.timeOffset = 100
    testWindow.layer.addSublayer(root)
    CATransaction.flush()

    let cases: [(name: String, from: CATransform3D, to: CATransform3D)] = [
      ("quarter turn", CATransform3DIdentity, CATransform3DMakeRotation(90 * Constants.degree, 0, 0, 1)),
      ("turn past a full turn", CATransform3DMakeRotation(10 * Constants.degree, 0, 0, 1), CATransform3DMakeRotation(350 * Constants.degree, 0, 0, 1)),
      ("half turn", CATransform3DIdentity, CATransform3DMakeRotation(180 * Constants.degree, 0, 0, 1)),
      ("skew, turn and move", CATransform3DMakeTranslation(5, 5, 0), Constants.skewedTurnAndMove),
      ("flip to the other flip", Constants.flip, CATransform3DMakeScale(1, -1, 1)),
      ("turned other flip to the flip", CATransform3DConcat(CATransform3DMakeRotation(30 * Constants.degree, 0, 0, 1), CATransform3DMakeScale(1, -1, 1)), Constants.flip),
      ("scale from zero", CATransform3DMakeScale(0, 0, 1), CATransform3DIdentity),
      ("perspective turn", CATransform3DIdentity, Constants.perspectiveTurn),
      ("small perspective turn", Constants.perspective, CATransform3DRotate(Constants.perspective, Constants.degree, 1, 0, 0)),
      ("perspective flip", Constants.perspective, CATransform3DScale(Constants.perspective, -1, 1, 1)),
      ("perspective turn about x past 120°", Constants.perspective, CATransform3DRotate(Constants.perspective, 150 * Constants.degree, 1, 0, 0)),
      ("perspective turn about y past 120°", Constants.perspective, CATransform3DRotate(Constants.perspective, 150 * Constants.degree, 0, 1, 0)),
      ("perspective turn about z past 120°", Constants.perspective, CATransform3DRotate(Constants.perspective, 150 * Constants.degree, 0, 0, 1)),
      ("perspective half turn about y", Constants.perspective, CATransform3DRotate(Constants.perspective, .pi, 0, 1, 0)),
      ("perspective half turn about z", Constants.perspective, CATransform3DRotate(Constants.perspective, .pi, 0, 0, 1)),
      ("perspective turn through a half turn", CATransform3DRotate(Constants.perspective, 100 * Constants.degree, 0, 0, 1), CATransform3DRotate(Constants.perspective, -100 * Constants.degree, 0, 0, 1)),
      ("2D to 3D", CATransform3DMakeRotation(20 * Constants.degree, 0, 0, 1), Constants.perspectiveTurn),
      ("turns about two axes", CATransform3DMakeRotation(40 * Constants.degree, 1, 1, 0), CATransform3DMakeRotation(100 * Constants.degree, 0, 1, 1)),
      ("projective", Constants.projective, CATransform3DConcat(Constants.skewedTurnAndMove, Constants.projective)),
      ("homogeneous scale without perspective, which goes in between", CATransform3DIdentity, Constants.homogeneousScale),
    ]
    let layers = cases.map { testCase -> CALayer in
      let layer = CALayer()
      layer.frame = CGRect(x: 0, y: 0, width: 10, height: 10)
      root.addSublayer(layer)
      CATransaction.disableAnimations {
        layer.transform = testCase.to
      }
      let animation = CABasicAnimation(keyPath: "transform")
      animation.fromValue = NSValue(caTransform3D: testCase.from)
      animation.toValue = NSValue(caTransform3D: testCase.to)
      animation.beginTime = 100
      animation.duration = 10
      animation.fillMode = .both
      layer.add(animation, forKey: "transform")
      return layer
    }

    for progress in [0.25, 0.5, 0.75] {
      // when: moving the timeline
      root.timeOffset = 100 + 10 * progress
      CATransaction.flush()

      for (testCase, layer) in zip(cases, layers) {
        // then: the interpolated transform is the one Core Animation shows, paced exactly without a timing function
        let description = "\(testCase.name) at \(progress)"
        let shown = try unwrap(layer.presentation()?.transform, description)
        let interpolated = try unwrap(AnimationInterpolation.transform(from: testCase.from, to: testCase.to, progress: progress), description)
        expectTransform(interpolated, toBe: shown, within: 1e-5, description)
      }
    }
  }

  // MARK: - Helpers

  /// The transform a progress of the way from one transform to another, blending their elements one by one.
  private func linearBlend(from: CATransform3D, to: CATransform3D, progress: CGFloat) -> CATransform3D {
    func blend(_ from: CGFloat, _ to: CGFloat) -> CGFloat {
      from + (to - from) * progress
    }
    return CATransform3D(
      m11: blend(from.m11, to.m11), m12: blend(from.m12, to.m12), m13: blend(from.m13, to.m13), m14: blend(from.m14, to.m14),
      m21: blend(from.m21, to.m21), m22: blend(from.m22, to.m22), m23: blend(from.m23, to.m23), m24: blend(from.m24, to.m24),
      m31: blend(from.m31, to.m31), m32: blend(from.m32, to.m32), m33: blend(from.m33, to.m33), m34: blend(from.m34, to.m34),
      m41: blend(from.m41, to.m41), m42: blend(from.m42, to.m42), m43: blend(from.m43, to.m43), m44: blend(from.m44, to.m44)
    )
  }

  private func expectTransform(_ transform: CATransform3D,
                               toBe expected: CATransform3D,
                               within tolerance: CGFloat,
                               _ description: String = "",
                               file: StaticString = #filePath,
                               line: UInt = #line)
  {
    let values = [transform.m11, transform.m12, transform.m13, transform.m14, transform.m21, transform.m22, transform.m23, transform.m24, transform.m31, transform.m32, transform.m33, transform.m34, transform.m41, transform.m42, transform.m43, transform.m44]
    let expectedValues = [expected.m11, expected.m12, expected.m13, expected.m14, expected.m21, expected.m22, expected.m23, expected.m24, expected.m31, expected.m32, expected.m33, expected.m34, expected.m41, expected.m42, expected.m43, expected.m44]
    for (value, expectedValue) in zip(values, expectedValues) {
      expect(value, description, file: file, line: line).to(beApproximatelyEqual(to: expectedValue, within: tolerance))
    }
  }

  // MARK: - Constants

  private enum Constants {

    /// One degree, in radians.
    static let degree = CGFloat.pi / 180

    /// A skew, a turn of 30° and a move, an affine transform with every part of an affine decomposition.
    static let skewedTurnAndMove: CATransform3D = {
      var skew = CATransform3DIdentity
      skew.m21 = 0.5
      let turned = CATransform3DConcat(skew, CATransform3DMakeRotation(30 * degree, 0, 0, 1))
      return CATransform3DConcat(turned, CATransform3DMakeTranslation(15, -25, 0))
    }()

    /// A perspective with the eye 500 points away.
    static let perspective: CATransform3D = {
      var perspective = CATransform3DIdentity
      perspective.m34 = -1 / 500
      return perspective
    }()

    /// A turn of 60° about the y axis, seen in perspective.
    static let perspectiveTurn = CATransform3DRotate(perspective, 60 * degree, 0, 1, 0)

    /// A flip of the x axis.
    static let flip = CATransform3DMakeScale(-1, 1, 1)

    /// A last element of 2 without perspective, which halves the size through the divide by it.
    static let homogeneousScale: CATransform3D = {
      var transform = CATransform3DIdentity
      transform.m44 = 2
      return transform
    }()

    /// A move in depth seen in perspective, whose last element isn't 1.
    static let projective: CATransform3D = {
      var perspective = CATransform3DIdentity
      perspective.m34 = -1 / 400
      let moved = CATransform3DConcat(CATransform3DMakeRotation(40 * degree, 1, 0, 0), CATransform3DMakeTranslation(10, 20, 30))
      return CATransform3DConcat(moved, perspective)
    }()
  }
}
