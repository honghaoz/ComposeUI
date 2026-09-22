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

@_spi(Private) @testable import ComposeUI

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
      path: { _ in holePath },
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
      path: { _ in holePath },
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
        path: { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) },
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
        paths: { size in
          InnerShadowPaths(
            shadowPath: CGPath(rect: CGRect(origin: .zero, size: size).insetBy(dx: holeInset, dy: holeInset), transform: nil),
            clipPath: clipInset.map { CGPath(rect: CGRect(origin: .zero, size: size).insetBy(dx: $0, dy: $0), transform: nil) }
          )
        },
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
        path: { CGPath(rect: CGRect(origin: .zero, size: $0).insetBy(dx: holeInset, dy: holeInset), transform: nil) },
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

  func test_update_withoutAnimation_continuesInFlightShadowAnimations() throws {
    // the inverted shadow and the fallback compute the shadow path differently, the interruption must work for both
    for supportsInvertsShadow in [true, false] {
      try verifyUpdateWithoutAnimationContinuesInFlightShadowAnimations(supportsInvertsShadow: supportsInvertsShadow)
    }
  }

  private func verifyUpdateWithoutAnimationContinuesInFlightShadowAnimations(supportsInvertsShadow: Bool) throws {
    // given: an inner shadow layer resized and animated towards new values of every shadow property, with a second,
    // delayed animated update stacked on the radius, plus animations of other properties standing in for a transition
    // and for the render pass's frame animation
    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    struct Shadow {
      let color: Color
      let opacity: CGFloat
      let radius: CGFloat
      let offset: CGSize
      let holeInset: CGFloat
    }

    let red = Shadow(color: .red, opacity: 0.5, radius: 10, offset: .zero, holeInset: 0)
    let blue = Shadow(color: .blue, opacity: 0.8, radius: 20, offset: CGSize(width: 2, height: 3), holeInset: 5)
    let blueWiderRadius = Shadow(color: .blue, opacity: 0.8, radius: 30, offset: CGSize(width: 2, height: 3), holeInset: 5)
    let green = Shadow(color: .green, opacity: 0.6, radius: 14, offset: CGSize(width: 1, height: 1), holeInset: 3)

    func update(_ layer: InnerShadowLayer, _ shadow: Shadow, animationTiming: AnimationTiming?) {
      layer.update(
        color: shadow.color,
        opacity: shadow.opacity,
        radius: shadow.radius,
        offset: shadow.offset,
        path: { CGPath(rect: CGRect(origin: .zero, size: $0).insetBy(dx: shadow.holeInset, dy: shadow.holeInset), transform: nil) },
        animationTiming: animationTiming
      )
    }

    let layer = InnerShadowLayer()
    layer.test.supportsInvertsShadowOverride = supportsInvertsShadow
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    update(layer, red, animationTiming: nil)
    let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()

    // a layer given the final inputs without animation provides the expected model values, including the paths
    let resizedBounds = CGRect(x: 0, y: 0, width: 120, height: 120)
    let reference = InnerShadowLayer()
    reference.test.supportsInvertsShadowOverride = supportsInvertsShadow
    reference.frame = resizedBounds
    update(reference, green, animationTiming: nil)
    let referenceMask = try (reference.mask as? CAShapeLayer).unwrap()
    let referenceShadowPath = try reference.shadowPath.unwrap()
    let referenceMaskPath = try referenceMask.path.unwrap()

    layer.disableActions {
      layer.frame = resizedBounds
    }
    update(layer, blue, animationTiming: .linear(duration: 10))
    update(layer, blueWiderRadius, animationTiming: .linear(duration: 10, delay: 1))
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowOpacity", "shadowRadius", "shadowRadius-1", "shadowOffset", "shadowPath"]
    expect(Set(maskLayer.animationKeys() ?? [])) == ["position", "bounds.size", "path"]
    let delayedRadiusBeginTime = try layer.animation(forKey: "shadowRadius-1").unwrap().beginTime

    let opacityAnimation = CABasicAnimation(keyPath: "opacity")
    opacityAnimation.duration = 10
    layer.add(opacityAnimation, forKey: "opacity")
    let positionAnimation = CABasicAnimation(keyPath: "position")
    positionAnimation.duration = 10
    positionAnimation.isAdditive = true
    layer.add(positionAnimation, forKey: "position")

    // when: updating without animation timing to new values
    update(layer, green, animationTiming: nil)
    let retargetTime = layer.currentTime

    // then: the model has the new values
    expect(layer.shadowColor) == Color.green.cgColor
    expect(layer.shadowOpacity) == 0.6
    expect(layer.shadowRadius) == 14
    expect(layer.shadowOffset) == CGSize(width: 1, height: 1)
    expect(layer.shadowPath) == referenceShadowPath
    expect(maskLayer.frame) == referenceMask.frame
    expect(maskLayer.path) == referenceMaskPath

    // then: the additive radius and offset animations are folded into one glide each, from the value shown to the new
    // value, the non-additive color, opacity and path animations are replaced by ones towards the new values over their
    // remaining time, and the other properties' animations are left alone
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowOpacity", "shadowRadius", "shadowOffset", "shadowPath", "opacity", "position"]

    // no radius or offset animation has begun, so the radius shows 10 and the offset zero. the radius glide lands when
    // the delayed update would have, after its delay and duration
    let radiusGlide = try (layer.animation(forKey: "shadowRadius") as? CABasicAnimation).unwrap()
    expect(radiusGlide.isAdditive) == true
    expect(radiusGlide.fromValue as? CGFloat) == -4
    expect(radiusGlide.toValue as? CGFloat) == 0
    expect(radiusGlide.duration).to(beApproximatelyEqual(to: delayedRadiusBeginTime + 10 - retargetTime, within: 0.02))
    expect(radiusGlide.timingFunction) == CAMediaTimingFunction(name: .easeOut)

    let offsetGlide = try (layer.animation(forKey: "shadowOffset") as? CABasicAnimation).unwrap()
    expect(offsetGlide.isAdditive) == true
    expect(offsetGlide.fromValue as? CGSize) == CGSize(width: -1, height: -1)
    expect(offsetGlide.toValue as? CGSize) == .zero
    expect(offsetGlide.duration) == 10
    expect(offsetGlide.timingFunction) == CAMediaTimingFunction(name: .easeOut)

    let retargetedColorAnimation = try (layer.animation(forKey: "shadowColor") as? CABasicAnimation).unwrap()
    expect(retargetedColorAnimation.duration) == 10
    expect(retargetedColorAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(retargetedColorAnimation.toValue as! CGColor) == Color.green.cgColor // swiftlint:disable:this force_cast

    let retargetedOpacityAnimation = try (layer.animation(forKey: "shadowOpacity") as? CABasicAnimation).unwrap()
    expect(retargetedOpacityAnimation.isAdditive) == false
    expect(retargetedOpacityAnimation.toValue as? Float) == 0.6
    expect(retargetedOpacityAnimation.duration) == 10
    expect(retargetedOpacityAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)

    // the fallback's shadow path depends on the radius, so its time is the delayed update's remaining time, and it lands
    // when that one would have, after its delay and duration
    let retargetedPathAnimation = try (layer.animation(forKey: "shadowPath") as? CABasicAnimation).unwrap()
    let expectedPathDuration = supportsInvertsShadow ? 10 : delayedRadiusBeginTime + 10 - retargetTime
    expect(retargetedPathAnimation.duration).to(beApproximatelyEqual(to: expectedPathDuration, within: 0.02))
    expect(retargetedPathAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(retargetedPathAnimation.toValue as! CGPath) == referenceShadowPath // swiftlint:disable:this force_cast
    expect(layer.animation(forKey: "opacity")?.duration) == 10
    expect(layer.animation(forKey: "position")?.duration) == 10

    // then: the mask keeps its frame animations, which mirror the layer's, and its path is retargeted
    expect(Set(maskLayer.animationKeys() ?? [])) == ["position", "bounds.size", "path"]
    for key in ["position", "bounds.size"] {
      let keptAnimation = try (maskLayer.animation(forKey: key) as? CABasicAnimation).unwrap()
      expect(keptAnimation.isAdditive) == true
      expect(keptAnimation.duration) == 10
      expect(keptAnimation.timingFunction) == CAMediaTimingFunction(name: .linear)
    }
    let retargetedMaskPathAnimation = try (maskLayer.animation(forKey: "path") as? CABasicAnimation).unwrap()
    expect(retargetedMaskPathAnimation.duration) == 10
    expect(retargetedMaskPathAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(retargetedMaskPathAnimation.toValue as! CGPath) == referenceMaskPath // swiftlint:disable:this force_cast

    // when: updating with animation timing and the same values
    update(layer, green, animationTiming: .linear(duration: 2))

    // then: every in-flight animation already lands on the values, so none is added or replaced
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowOpacity", "shadowRadius", "shadowOffset", "shadowPath", "opacity", "position"]
    expect(layer.animation(forKey: "shadowColor")?.duration) == 10
    expect(layer.animation(forKey: "shadowColor")?.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(Set(maskLayer.animationKeys() ?? [])) == ["position", "bounds.size", "path"]
    expect(maskLayer.animation(forKey: "path")?.duration) == 10

    // when: updating with animation timing and the blue values again
    update(layer, blue, animationTiming: .linear(duration: 2))

    // then: every changed property animates towards its new value: the non-additive animations are replaced and the
    // additive ones stack on the glides
    let colorAnimation = try (layer.animation(forKey: "shadowColor") as? CABasicAnimation).unwrap()
    expect(colorAnimation.duration) == 2
    expect(colorAnimation.toValue as! CGColor) == Color.blue.cgColor // swiftlint:disable:this force_cast
    let shadowOpacityAnimation = try (layer.animation(forKey: "shadowOpacity") as? CABasicAnimation).unwrap()
    expect(shadowOpacityAnimation.duration) == 2
    expect(shadowOpacityAnimation.isAdditive) == false
    expect(shadowOpacityAnimation.toValue as? Float) == 0.8
    expect(layer.animation(forKey: "shadowPath")?.duration) == 2
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowOpacity", "shadowRadius", "shadowRadius-1", "shadowOffset", "shadowOffset-1", "shadowPath", "opacity", "position"]
    expect(maskLayer.animation(forKey: "path")?.duration) == 2
    expect(Set(maskLayer.animationKeys() ?? [])) == ["position", "bounds.size", "path"]
  }

  func test_update_pathsFollowAnimatingSize() throws {
    // the inverted shadow and the fallback compute the shadow path differently, both must follow the frame
    for supportsInvertsShadow in [true, false] {
      try verifyUpdatePathsFollowAnimatingSize(supportsInvertsShadow: supportsInvertsShadow)
    }
  }

  private func verifyUpdatePathsFollowAnimatingSize(supportsInvertsShadow: Bool) throws {
    // given: an inner shadow layer with a clip path, and reference layers giving the paths at the sizes it passes through
    func makeLayer(width: CGFloat) -> InnerShadowLayer {
      let layer = InnerShadowLayer()
      layer.test.supportsInvertsShadowOverride = supportsInvertsShadow
      layer.frame = CGRect(x: 0, y: 0, width: width, height: 100)
      return layer
    }
    func update(_ layer: InnerShadowLayer, animationTiming: AnimationTiming?) {
      layer.update(
        color: .black,
        opacity: 0.5,
        radius: 10,
        offset: .zero,
        paths: { InnerShadowPaths(shadowPath: CGPath(rect: CGRect(origin: .zero, size: $0).insetBy(dx: 5, dy: 5), transform: nil), clipPath: CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil)) },
        animationTiming: animationTiming
      )
    }
    func referencePaths(width: CGFloat) throws -> (shadow: CGPath, clip: CGPath) {
      let reference = makeLayer(width: width)
      update(reference, animationTiming: nil)
      return try (reference.shadowPath.unwrap(), (reference.mask as? CAShapeLayer).unwrap().path.unwrap())
    }

    let paths50 = try referencePaths(width: 50)
    let paths100 = try referencePaths(width: 100)
    let paths150 = try referencePaths(width: 150)
    let paths200 = try referencePaths(width: 200)

    let layer = makeLayer(width: 100)
    update(layer, animationTiming: nil)
    let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()

    // when: the frame animates to 200 wide, as the render pass animates it, and the layer is updated with the same timing
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 100), timing: .linear(duration: 2))
    update(layer, animationTiming: .linear(duration: 2))

    // then: the shadow path and the clip path follow the frame from the paths at the shown size to the paths at the
    // model size, while the mask's frame animates alongside
    let shadowPathAnimation = try (layer.animation(forKey: "shadowPath") as? CAKeyframeAnimation).unwrap()
    expect(shadowPathAnimation.duration) == 2
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(shadowPathAnimation.values?.first as! CGPath) == paths100.shadow // swiftlint:disable:this force_cast
    expect(shadowPathAnimation.values?.last as! CGPath) == paths200.shadow // swiftlint:disable:this force_cast
    expect(layer.shadowPath) == paths200.shadow

    let clipPathAnimation = try (maskLayer.animation(forKey: "path") as? CAKeyframeAnimation).unwrap()
    expect(clipPathAnimation.duration) == 2
    expect(clipPathAnimation.values?.first as! CGPath) == paths100.clip // swiftlint:disable:this force_cast
    expect(clipPathAnimation.values?.last as! CGPath) == paths200.clip // swiftlint:disable:this force_cast
    expect(Set(maskLayer.animationKeys() ?? [])) == ["position", "bounds.size", "path"]

    // when: a non-animated frame update sets the layer 150 wide while the size animation runs, and the layer is updated
    layer.disableActions {
      layer.frame = CGRect(x: 0, y: 0, width: 150, height: 100)
    }
    update(layer, animationTiming: nil)

    // then: the paths are sampled again from the size the layer shows now to the new model size
    let resampledShadowPathAnimation = try (layer.animation(forKey: "shadowPath") as? CAKeyframeAnimation).unwrap()
    expect(resampledShadowPathAnimation.values?.first as! CGPath) == paths50.shadow // swiftlint:disable:this force_cast
    expect(resampledShadowPathAnimation.values?.last as! CGPath) == paths150.shadow // swiftlint:disable:this force_cast
    expect(layer.shadowPath) == paths150.shadow

    let resampledClipPathAnimation = try (maskLayer.animation(forKey: "path") as? CAKeyframeAnimation).unwrap()
    expect(resampledClipPathAnimation.values?.first as! CGPath) == paths50.clip // swiftlint:disable:this force_cast
    expect(resampledClipPathAnimation.values?.last as! CGPath) == paths150.clip // swiftlint:disable:this force_cast
    expect(maskLayer.path) == paths150.clip
    expect(maskLayer.frame) == CGRect(x: 0, y: 0, width: 150, height: 100)
  }

  func test_update_withoutAnimation_sameValues_keepsInFlightShadowAnimations() throws {
    // given: an inner shadow layer animated towards a new color and radius
    let layer = InnerShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    func update(color: Color, radius: CGFloat, animationTiming: AnimationTiming?) {
      layer.update(color: color, opacity: 0.5, radius: radius, offset: .zero, path: { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) }, animationTiming: animationTiming)
    }

    update(color: .red, radius: 10, animationTiming: nil)
    update(color: .blue, radius: 20, animationTiming: .linear(duration: 10))
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowRadius"]

    // when: updating without animation timing with the values the animations head to
    update(color: .blue, radius: 20, animationTiming: nil)

    // then: the animations already land on the values, so they keep going as they are
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowRadius"]
    for key in ["shadowColor", "shadowRadius"] {
      let keptAnimation = try (layer.animation(forKey: key) as? CABasicAnimation).unwrap()
      expect(keptAnimation.duration) == 10
      expect(keptAnimation.timingFunction) == CAMediaTimingFunction(name: .linear)
    }
    expect(layer.shadowColor) == Color.blue.cgColor
    expect(layer.shadowRadius) == 20
  }

  func test_update_withoutAnimation_rendersContinuously() throws {
    // given: a hosted inner shadow layer whose shadow color is animating from red to blue
    let testWindow = TestWindow()
    let layer = InnerShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    testWindow.layer.addSublayer(layer)

    func update(color: Color, animationTiming: AnimationTiming?) {
      layer.update(color: color, opacity: 0.5, radius: 10, offset: .zero, path: { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) }, animationTiming: animationTiming)
    }

    func renderedBlue() throws -> CGFloat {
      let color = try layer.presentation().unwrap().shadowColor.unwrap()
      let sRGB = try CGColorSpace(name: CGColorSpace.sRGB).unwrap()
      return try color.converted(to: sRGB, intent: .defaultIntent, options: nil).unwrap().components.unwrap()[2]
    }

    update(color: .red, animationTiming: nil)
    CATransaction.flush()
    expect(layer.presentation()).toEventuallyNot(beNil())

    update(color: .blue, animationTiming: .linear(duration: 0.5))
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
    let blueBeforeUpdate = try renderedBlue()
    expect(blueBeforeUpdate) > 0.1
    let interruptedBeginTime = try layer.animation(forKey: "shadowColor").unwrap().beginTime

    // when: updating without animation timing back to red
    update(color: .red, animationTiming: nil)
    let retargetTime = layer.currentTime

    // then: the shadow heads back to red from where it is over the time the interrupted animation had left, neither
    // snapping nor finishing the animation towards blue: whenever the run loop lets the test look, the shown color is
    // where the retargeting animation puts it, until it lands on red. the run loop's timing isn't reliable, so the test
    // checks each look against the animation's own value for that time instead of expecting a value at a fixed delay
    expect(try layer.animation(forKey: "shadowColor").unwrap().duration).to(beApproximatelyEqual(to: interruptedBeginTime + 0.5 - retargetTime, within: 0.02))
    var landed = false
    for _ in 0 ..< 40 where !landed {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
      let blue = try renderedBlue()
      let predicted = try layer.predictedValue(forKeyPath: "shadowColor", at: layer.currentTime, scalar: blueComponent)
      expect(blue).to(beApproximatelyEqual(to: predicted, within: 0.05))
      expect(blue) <= blueBeforeUpdate + 0.05
      landed = blue < 0.01
    }
    expect(landed) == true
  }

  /// The blue component of a color value in the sRGB color space, for `predictedValue(forKeyPath:at:scalar:)`.
  private func blueComponent(of value: Any) throws -> CGFloat {
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    let color = value as! CGColor // swiftlint:disable:this force_cast
    let sRGB = try CGColorSpace(name: CGColorSpace.sRGB).unwrap()
    return try color.converted(to: sRGB, intent: .defaultIntent, options: nil).unwrap().components.unwrap()[2]
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
      path: { _ in holePath },
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
      path: { _ in holePath },
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
      paths: { _ in InnerShadowPaths(shadowPath: holePath, clipPath: clipPath) },
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
