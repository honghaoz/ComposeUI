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
    // given: a new inner shadow layer
    let layer = InnerShadowLayer()

    // then: the contents scale matches the platform screen scale
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
    do {
      // given: a source layer with the override set
      let source = InnerShadowLayer()
      source.test.supportsInvertsShadowOverride = false

      // when: making a copy of the source layer
      let copy = InnerShadowLayer(layer: source)

      // then: the copy carries the override over
      expect(copy.test.supportsInvertsShadowOverride) == false
    }

    do {
      // given: a source layer with no override
      let source = InnerShadowLayer()

      // when: making a copy of the source layer
      let copy = InnerShadowLayer(layer: source)

      // then: the copy is also unset
      expect(copy.test.supportsInvertsShadowOverride) == nil
    }
  }

  // MARK: - Default path (uses `invertsShadow` private API)

  func test_update_default_noAnimation() throws {
    // given: an inner shadow layer with a hole path
    let layer = InnerShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    let holePath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)

    // when: updating without animation timing
    layer.update(
      color: .red,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      holePath: { _ in holePath },
      clipPath: nil,
      animationTiming: nil
    )

    // then: shadow properties are set without animations and the mask matches the hole path
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
    // given: an inner shadow layer with a hole path
    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    let layer = InnerShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    let holePath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)

    // when: updating with animation timing
    layer.update(
      color: .red,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      holePath: { _ in holePath },
      clipPath: nil,
      animationTiming: .easeInEaseOut()
    )

    // then: shadow properties are set with animations and the mask animates to the hole path
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

  func test_update_withAnimation_animatesMask_onResize() throws {
    // given: an inner shadow layer with a mask laid out for its bounds
    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    let layer = InnerShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    func update(animationTiming: AnimationTiming?) {
      layer.update(
        color: .red,
        opacity: 0.5,
        radius: 10,
        offset: .zero,
        holePath: { CGPath(rect: $0.bounds, transform: nil) },
        clipPath: nil,
        animationTiming: animationTiming
      )
    }

    update(animationTiming: nil)
    let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
    expect(maskLayer.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: updating with animation timing at the same size
    update(animationTiming: .easeInEaseOut())

    // then: the mask's frame and path are unchanged, so nothing animates
    expect(maskLayer.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(maskLayer.animationKeys()) == nil

    // when: updating with animation timing after a resize
    layer.frame = CGRect(x: 0, y: 0, width: 150, height: 80)
    update(animationTiming: .easeInEaseOut())

    // then: the mask follows the new bounds, animating its size, the position its center moved to, and its path
    expect(maskLayer.frame) == CGRect(x: 0, y: 0, width: 150, height: 80)
    expect(maskLayer.animation(forKey: "position")) != nil
    expect(maskLayer.animation(forKey: "bounds.size")) != nil
    expect(maskLayer.animation(forKey: "path")) != nil
  }

  func test_update_withAnimation_animatesOnlyChangedProperties() throws {
    // given: an inner shadow layer updated without animation
    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    let layer = InnerShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // the inputs persist across the stages below, so each stage changes exactly one of them
    var color: Color = .red
    var opacity: CGFloat = 0.5
    var radius: CGFloat = 10
    var offset = CGSize(width: 2, height: 5)
    var holeInset: CGFloat = 0
    var clipInset: CGFloat?
    func update(animationTiming: AnimationTiming?) {
      layer.update(
        color: color,
        opacity: opacity,
        radius: radius,
        offset: offset,
        holePath: { CGPath(rect: $0.bounds.insetBy(dx: holeInset, dy: holeInset), transform: nil) },
        clipPath: clipInset.map { inset in { CGPath(rect: $0.bounds.insetBy(dx: inset, dy: inset), transform: nil) } },
        animationTiming: animationTiming
      )
    }

    update(animationTiming: nil)
    let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()

    // when: updating with animation timing and the same inputs
    update(animationTiming: .easeInEaseOut())

    // then: nothing changed, so no animation is added
    expect(layer.animationKeys()) == nil
    expect(maskLayer.animationKeys()) == nil

    // when: updating with animation timing and only a new opacity
    opacity = 0.8
    update(animationTiming: .easeInEaseOut())

    // then: only the opacity animates, to the new value
    expect(layer.animationKeys()) == ["shadowOpacity"]
    expect(layer.shadowOpacity) == 0.8
    expect(maskLayer.animationKeys()) == nil

    // when: updating with animation timing and only a new color
    color = .blue
    update(animationTiming: .easeInEaseOut())

    // then: only the color animates, next to the in-flight opacity animation
    expect(layer.animationKeys()) == ["shadowOpacity", "shadowColor"]
    expect(layer.shadowColor) == Color.blue.cgColor
    expect(maskLayer.animationKeys()) == nil

    // when: updating with animation timing and only a new radius
    radius = 15
    update(animationTiming: .easeInEaseOut())

    // then: only the radius animates, the inverted shadow's path doesn't depend on it
    expect(layer.animationKeys()) == ["shadowOpacity", "shadowColor", "shadowRadius"]
    expect(layer.shadowRadius) == 15
    expect(maskLayer.animationKeys()) == nil

    // when: updating with animation timing and only a new offset
    offset = CGSize(width: 3, height: 6)
    update(animationTiming: .easeInEaseOut())

    // then: only the offset animates
    expect(layer.animationKeys()) == ["shadowOpacity", "shadowColor", "shadowRadius", "shadowOffset"]
    expect(layer.shadowOffset) == CGSize(width: 3, height: 6)
    expect(maskLayer.animationKeys()) == nil

    // when: updating with animation timing and only a new hole path
    holeInset = 5
    update(animationTiming: .easeInEaseOut())

    // then: the shadow path animates, and so does the mask path, which follows the hole when there is no clip path
    expect(layer.animationKeys()) == ["shadowOpacity", "shadowColor", "shadowRadius", "shadowOffset", "shadowPath"]
    expect(layer.shadowPath) == CGPath(rect: CGRect(x: 5, y: 5, width: 90, height: 90), transform: nil)
    expect(maskLayer.animationKeys()) == ["path"]

    // when: updating with animation timing and only a new clip path, with the mask's animations cleared to observe it alone
    maskLayer.removeAllAnimations()
    clipInset = 2
    update(animationTiming: .easeInEaseOut())

    // then: only the mask path animates
    expect(layer.animationKeys()) == ["shadowOpacity", "shadowColor", "shadowRadius", "shadowOffset", "shadowPath"]
    expect(maskLayer.animationKeys()) == ["path"]
    expect(maskLayer.path) == CGPath(rect: CGRect(x: 2, y: 2, width: 96, height: 96), transform: nil)
  }

  func test_update_withAnimation_keepsInFlightAnimation_toUnchangedTarget() throws {
    // given: an inner shadow layer updated without animation, with in-flight color and mask path animations of a
    // distinctive duration
    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    let layer = InnerShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    func update(color: Color = .red, holeInset: CGFloat = 0, animationTiming: AnimationTiming?) {
      layer.update(
        color: color,
        opacity: 0.5,
        radius: 10,
        offset: .zero,
        holePath: { CGPath(rect: $0.bounds.insetBy(dx: holeInset, dy: holeInset), transform: nil) },
        clipPath: nil,
        animationTiming: animationTiming
      )
    }

    update(animationTiming: nil)
    let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()

    let inFlightColorAnimation = CABasicAnimation(keyPath: "shadowColor")
    inFlightColorAnimation.duration = 10
    layer.add(inFlightColorAnimation, forKey: "shadowColor")
    let inFlightPathAnimation = CABasicAnimation(keyPath: "path")
    inFlightPathAnimation.duration = 10
    maskLayer.add(inFlightPathAnimation, forKey: "path")

    // when: updating with animation timing and the same inputs
    update(animationTiming: .easeInEaseOut(duration: 2))

    // then: the in-flight animations are kept instead of being replaced by ones towards the same target
    let keptColorAnimation = try layer.animation(forKey: "shadowColor").unwrap()
    expect(keptColorAnimation.duration) == 10
    let keptPathAnimation = try maskLayer.animation(forKey: "path").unwrap()
    expect(keptPathAnimation.duration) == 10

    // when: updating with animation timing and a new color and hole path
    update(color: .blue, holeInset: 5, animationTiming: .easeInEaseOut(duration: 2))

    // then: the in-flight animations are replaced by the ones towards the new targets
    let replacedColorAnimation = try layer.animation(forKey: "shadowColor").unwrap()
    expect(replacedColorAnimation.duration) == 2
    let replacedPathAnimation = try maskLayer.animation(forKey: "path").unwrap()
    expect(replacedPathAnimation.duration) == 2
  }

  func test_update_withoutAnimation_stopsInFlightShadowAnimations() throws {
    // given: an inner shadow layer animated towards a new color, radius and hole path, plus animations of other
    // properties standing in for a transition and for the render pass's frame animation
    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    let layer = InnerShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    func update(color: Color, radius: CGFloat, holeInset: CGFloat, animationTiming: AnimationTiming?) {
      layer.update(
        color: color,
        opacity: 0.5,
        radius: radius,
        offset: .zero,
        holePath: { CGPath(rect: $0.bounds.insetBy(dx: holeInset, dy: holeInset), transform: nil) },
        clipPath: nil,
        animationTiming: animationTiming
      )
    }

    update(color: .red, radius: 10, holeInset: 0, animationTiming: nil)
    let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
    let redShadowPath = try layer.shadowPath.unwrap()
    let redMaskPath = try maskLayer.path.unwrap()

    update(color: .blue, radius: 20, holeInset: 5, animationTiming: .linear(duration: 10))
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowRadius", "shadowPath"]
    expect(maskLayer.animationKeys()) == ["path"]

    let opacityAnimation = CABasicAnimation(keyPath: "opacity")
    opacityAnimation.duration = 10
    layer.add(opacityAnimation, forKey: "opacity")
    let positionAnimation = CABasicAnimation(keyPath: "position")
    positionAnimation.duration = 10
    positionAnimation.isAdditive = true
    layer.add(positionAnimation, forKey: "position")

    // when: updating without animation timing back to the old values
    update(color: .red, radius: 10, holeInset: 0, animationTiming: nil)

    // then: the shadow and mask animations are gone and the model has the new values, so the layer renders them on the
    // next frame, while the other properties' animations are left alone
    expect(layer.shadowColor) == Color.red.cgColor
    expect(layer.shadowRadius) == 10
    expect(layer.shadowPath) == redShadowPath
    expect(maskLayer.path) == redMaskPath
    expect(Set(layer.animationKeys() ?? [])) == ["opacity", "position"]
    expect(maskLayer.animationKeys()) == nil

    // when: updating with animation timing and the same values
    update(color: .red, radius: 10, holeInset: 0, animationTiming: .linear(duration: 2))

    // then: nothing is left to animate
    expect(Set(layer.animationKeys() ?? [])) == ["opacity", "position"]
    expect(maskLayer.animationKeys()) == nil

    // when: updating with animation timing and the new values again
    update(color: .blue, radius: 20, holeInset: 5, animationTiming: .linear(duration: 2))

    // then: the changed properties animate towards the new values
    let colorAnimation = try (layer.animation(forKey: "shadowColor") as? CABasicAnimation).unwrap()
    expect(colorAnimation.duration) == 2
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(colorAnimation.toValue as! CGColor) == Color.blue.cgColor // swiftlint:disable:this force_cast
    expect(Set(layer.animationKeys() ?? [])) == ["opacity", "position", "shadowColor", "shadowRadius", "shadowPath"]
    expect(maskLayer.animationKeys()) == ["path"]
  }

  func test_update_withoutAnimation_sameValues_stopsInFlightShadowAnimations() throws {
    // given: an inner shadow layer animated towards a new color and radius
    let layer = InnerShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    func update(color: Color, radius: CGFloat, animationTiming: AnimationTiming?) {
      layer.update(color: color, opacity: 0.5, radius: radius, offset: .zero, holePath: { CGPath(rect: $0.bounds, transform: nil) }, clipPath: nil, animationTiming: animationTiming)
    }

    update(color: .red, radius: 10, animationTiming: nil)
    update(color: .blue, radius: 20, animationTiming: .linear(duration: 10))
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowRadius"]

    // when: updating without animation timing with the values the animations head to
    update(color: .blue, radius: 20, animationTiming: nil)

    // then: the animations are removed all the same, so the layer shows the values on the next frame
    expect(layer.animationKeys()) == nil
    expect(layer.shadowColor) == Color.blue.cgColor
    expect(layer.shadowRadius) == 20
  }

  // MARK: - Fallback path (manual punched bigger rect)

  func test_update_fallback_noAnimation() throws {
    // given: a layer forced to the fallback path, with a hole path
    let layer = InnerShadowLayer()
    layer.test.supportsInvertsShadowOverride = false
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    let holePath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)
    let radius: CGFloat = 10
    let offset = CGSize(width: 2, height: -5)

    // when: updating without animation timing
    layer.update(
      color: .red,
      opacity: 0.5,
      radius: radius,
      offset: offset,
      holePath: { _ in holePath },
      clipPath: nil,
      animationTiming: nil
    )

    // then: shadow properties are set without animation, using the fallback shadow path
    // fallback never sets `invertsShadow`
    expect(layer.invertsShadow) == false

    expect(layer.shadowColor) == Color.red.cgColor
    expect(layer.shadowOpacity) == 0.5
    expect(layer.shadowRadius) == radius
    expect(layer.shadowOffset) == offset

    // shadowPath is the bigger rect punched by holePath, its bounding box equals the bigger rect
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
    // given: a layer forced to the fallback path, with a hole path
    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    let layer = InnerShadowLayer()
    layer.test.supportsInvertsShadowOverride = false
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    let holePath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)
    let radius: CGFloat = 10
    let offset = CGSize(width: 2, height: 5)

    // when: updating with animation timing
    layer.update(
      color: .red,
      opacity: 0.5,
      radius: radius,
      offset: offset,
      holePath: { _ in holePath },
      clipPath: nil,
      animationTiming: .easeInEaseOut()
    )

    // then: the fallback shadow path is used and shadow properties animate
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
    // given: a layer forced to the fallback path, with a clip path larger than the hole path
    let layer = InnerShadowLayer()
    layer.test.supportsInvertsShadowOverride = false
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    let holePath = CGPath(rect: CGRect(x: 30, y: 30, width: 40, height: 40), transform: nil)
    let clipPath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)
    let radius: CGFloat = 10
    let offset = CGSize(width: 2, height: 5)

    // when: updating with both a hole path and a clip path
    layer.update(
      color: .black,
      opacity: 0.5,
      radius: radius,
      offset: offset,
      holePath: { _ in holePath },
      clipPath: { _ in clipPath },
      animationTiming: nil
    )

    // then: the bigger rect is computed from the clip path and the mask clips to the clip path
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
