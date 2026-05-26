//
//  InnerShadowLayerTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 5/25/26.
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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import QuartzCore

import ChouTiTest

@testable import ComposeUI

final class InnerShadowLayerTests: XCTestCase {

  // MARK: - init

  func test_init_setsContentsScale() {
    let layer = InnerShadowLayer()

    #if canImport(AppKit)
    expect(layer.contentsScale) == NSScreen.main?.backingScaleFactor ?? ComposeUI.Constants.defaultScaleFactor
    #endif

    #if canImport(UIKit)
    #if os(visionOS)
    expect(layer.contentsScale) == ComposeUI.Constants.defaultScaleFactor
    expect(layer.wantsDynamicContentScaling) == true
    #else
    expect(layer.contentsScale) == UIScreen.main.scale
    #endif
    #endif
  }

  // MARK: - init(layer:)

  func test_initWithLayer_copiesCustomProperties() {
    // when the source has the override set, the copy carries it over
    do {
      let source = InnerShadowLayer()
      source.test.supportsInvertsShadowOverride = false

      let copy = InnerShadowLayer(layer: source)
      expect(copy.test.supportsInvertsShadowOverride) == false
    }

    // when the source has no override, the copy is also unset
    do {
      let source = InnerShadowLayer()
      let copy = InnerShadowLayer(layer: source)
      expect(copy.test.supportsInvertsShadowOverride) == nil
    }
  }

  // MARK: - Default path (uses `invertsShadow` private API)

  func test_update_default_noAnimation() throws {
    let layer = InnerShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    let holePath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)

    layer.update(
      color: .red,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      holePath: { _ in holePath },
      clipPath: nil,
      animationTiming: nil
    )

    expect(layer.invertsShadow) == true
    expect(layer.shadowColor) == Color.red.cgColor
    expect(layer.shadowOpacity) == 0.5
    expect(layer.shadowRadius) == 10
    expect(layer.shadowOffset) == CGSize(width: 2, height: 5)
    expect(layer.shadowPath) == holePath

    expect(layer.animation(forKey: "shadowColor")) == nil
    expect(layer.animation(forKey: "shadowOpacity")) == nil
    expect(layer.animation(forKey: "shadowRadius")) == nil
    expect(layer.animation(forKey: "shadowOffset")) == nil
    expect(layer.animation(forKey: "shadowPath")) == nil

    let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
    expect(maskLayer.frame) == layer.bounds
    expect(maskLayer.path) == holePath
  }

  func test_update_default_withAnimation() throws {
    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
    defer { ComposeUI.Assert.resetTestAssertionFailureHandler() }

    let layer = InnerShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    let holePath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)

    layer.update(
      color: .red,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      holePath: { _ in holePath },
      clipPath: nil,
      animationTiming: .easeInEaseOut()
    )

    expect(layer.invertsShadow) == true
    expect(layer.shadowPath) == holePath

    expect(layer.animation(forKey: "shadowColor")) != nil
    expect(layer.animation(forKey: "shadowOpacity")) != nil
    expect(layer.animation(forKey: "shadowRadius")) != nil
    expect(layer.animation(forKey: "shadowOffset")) != nil
    expect(layer.animation(forKey: "shadowPath")) != nil

    let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
    expect(maskLayer.path) == holePath
    expect(maskLayer.animation(forKey: "path")) != nil
  }

  // MARK: - Fallback path (manual punched bigger rect)

  func test_update_fallback_noAnimation() throws {
    let layer = InnerShadowLayer()
    layer.test.supportsInvertsShadowOverride = false
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    let holePath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)
    let radius: CGFloat = 10
    let offset = CGSize(width: 2, height: -5)

    layer.update(
      color: .red,
      opacity: 0.5,
      radius: radius,
      offset: offset,
      holePath: { _ in holePath },
      clipPath: nil,
      animationTiming: nil
    )

    // fallback never sets `invertsShadow`
    expect(layer.invertsShadow) == false

    expect(layer.shadowColor) == Color.red.cgColor
    expect(layer.shadowOpacity) == 0.5
    expect(layer.shadowRadius) == radius
    expect(layer.shadowOffset) == offset

    // shadowPath is the bigger rect punched by holePath; its bounding box equals the bigger rect
    let expectedHExtra = radius + abs(offset.width) + 20
    let expectedVExtra = radius + abs(offset.height) + 20
    let expectedBiggerBounds = holePath.boundingBoxOfPath.insetBy(dx: -expectedHExtra, dy: -expectedVExtra)
    let shadowPath = try layer.shadowPath.unwrap()
    expect(shadowPath.boundingBoxOfPath) == expectedBiggerBounds

    // mask still clips to the clipPath (which defaults to holePath)
    let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
    expect(maskLayer.frame) == layer.bounds
    expect(maskLayer.path) == holePath

    expect(layer.animation(forKey: "shadowPath")) == nil
  }

  func test_update_fallback_withAnimation() throws {
    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
    defer { ComposeUI.Assert.resetTestAssertionFailureHandler() }

    let layer = InnerShadowLayer()
    layer.test.supportsInvertsShadowOverride = false
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    let holePath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)
    let radius: CGFloat = 10
    let offset = CGSize(width: 2, height: 5)

    layer.update(
      color: .red,
      opacity: 0.5,
      radius: radius,
      offset: offset,
      holePath: { _ in holePath },
      clipPath: nil,
      animationTiming: .easeInEaseOut()
    )

    expect(layer.invertsShadow) == false

    let expectedBiggerBounds = holePath.boundingBoxOfPath.insetBy(
      dx: -(radius + abs(offset.width) + 20),
      dy: -(radius + abs(offset.height) + 20)
    )
    let shadowPath = try layer.shadowPath.unwrap()
    expect(shadowPath.boundingBoxOfPath) == expectedBiggerBounds

    expect(layer.animation(forKey: "shadowColor")) != nil
    expect(layer.animation(forKey: "shadowOpacity")) != nil
    expect(layer.animation(forKey: "shadowRadius")) != nil
    expect(layer.animation(forKey: "shadowOffset")) != nil
    expect(layer.animation(forKey: "shadowPath")) != nil

    let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
    expect(maskLayer.path) == holePath
    expect(maskLayer.animation(forKey: "path")) != nil
  }

  /// The fallback's bigger rect must be computed from `clipPath` (not `holePath`), so the
  /// "spread" case where the clip region is larger than the hole still fully contains the shadow.
  func test_update_fallback_withSpread() throws {
    let layer = InnerShadowLayer()
    layer.test.supportsInvertsShadowOverride = false
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    let holePath = CGPath(rect: CGRect(x: 30, y: 30, width: 40, height: 40), transform: nil)
    let clipPath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)
    let radius: CGFloat = 10
    let offset = CGSize(width: 2, height: 5)

    layer.update(
      color: .black,
      opacity: 0.5,
      radius: radius,
      offset: offset,
      holePath: { _ in holePath },
      clipPath: { _ in clipPath },
      animationTiming: nil
    )

    let expectedBiggerBounds = clipPath.boundingBoxOfPath.insetBy(
      dx: -(radius + abs(offset.width) + 20),
      dy: -(radius + abs(offset.height) + 20)
    )
    let shadowPath = try layer.shadowPath.unwrap()
    expect(shadowPath.boundingBoxOfPath) == expectedBiggerBounds

    let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
    expect(maskLayer.path) == clipPath
  }
}
