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

  // MARK: - Update

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
    // given: a new inner shadow layer
    let layer = InnerShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    func update(holeInset: CGFloat) {
      layer.update(
        color: .red,
        opacity: 0.5,
        radius: 10,
        offset: CGSize(width: 2, height: 5),
        path: { CGPath(rect: CGRect(origin: .zero, size: $0).insetBy(dx: holeInset, dy: holeInset), transform: nil) },
        animationTiming: .easeInEaseOut()
      )
    }

    // when: updating with animation timing
    update(holeInset: 0)

    // then: the shadow properties animate from the layer's defaults, and the paths show at once
    expect(layer.invertsShadow) == true
    expect(layer.shadowPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)

    expect(layer.animation(forKey: "shadowColor")) != nil
    expect(layer.animation(forKey: "shadowOpacity")) != nil
    expect(layer.animation(forKey: "shadowRadius")) != nil
    expect(layer.animation(forKey: "shadowOffset")) != nil
    expect(layer.animation(forKey: "shadowPath")) == nil

    let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
    expect(maskLayer.path) == CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)
    expect(maskLayer.animation(forKey: "path")) == nil

    // when: updating with animation timing and a new hole path
    update(holeInset: 5)

    // then: the shadow path and the mask, which follows the hole, animate to the new hole
    expect(layer.shadowPath) == CGPath(rect: CGRect(x: 5, y: 5, width: 90, height: 90), transform: nil)
    expect(layer.animation(forKey: "shadowPath")) != nil
    expect(maskLayer.path) == CGPath(rect: CGRect(x: 5, y: 5, width: 90, height: 90), transform: nil)
    expect(maskLayer.animation(forKey: "path")) != nil
  }

  func test_update_withAnimation_animatesMask_onResize() throws {
    // given: an inner shadow layer with a mask laid out for its bounds
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
    // given: an inner shadow layer resized and animated towards new values of every shadow property, with a second,
    // delayed animated update stacked on the radius, plus animations of other properties standing in for a transition
    // and for the render pass's frame animation
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
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    update(layer, red, animationTiming: nil)
    let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()

    // a layer given the final inputs without animation provides the expected model values, including the paths
    let resizedBounds = CGRect(x: 0, y: 0, width: 120, height: 120)
    let reference = InnerShadowLayer()
    reference.frame = resizedBounds
    update(reference, green, animationTiming: nil)
    let referenceMask = try (reference.mask as? CAShapeLayer).unwrap()
    let referenceMaskPath = try referenceMask.path.unwrap()
    let referenceShadowPath = try reference.shadowPath.unwrap()

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
    // value, the non-additive color and opacity animations are replaced by ones towards the new values over their
    // remaining time, the path keeps its animation, and the other properties' animations are left alone
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
    expect(layer.animation(forKey: "opacity")?.duration) == 10
    expect(layer.animation(forKey: "position")?.duration) == 10

    // then: the shadow path changes at once and keeps its change in flight, the hole's, shown on top of the new path,
    // so it shows the hole the frame shows
    let shadowPathAnimation = try (layer.animation(forKey: "shadowPath") as? CABasicAnimation).unwrap()
    let shownHolePath = CGPath(rect: CGRect(x: -2, y: -2, width: 104, height: 104), transform: nil)
    expect(shadowPathAnimation.duration) == 10
    expect(shadowPathAnimation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(try PathPoints(path(shadowPathAnimation.fromValue))) == PathPoints(shownHolePath)
    expect(try path(shadowPathAnimation.toValue)) == referenceShadowPath

    // then: the mask keeps its frame animations, and its path, the hole, does as the shadow path
    expect(Set(maskLayer.animationKeys() ?? [])) == ["position", "bounds.size", "path"]
    for key in ["position", "bounds.size"] {
      let keptAnimation = try (maskLayer.animation(forKey: key) as? CABasicAnimation).unwrap()
      expect(keptAnimation.isAdditive) == true
      expect(keptAnimation.duration) == 10
      expect(keptAnimation.timingFunction) == CAMediaTimingFunction(name: .linear)
    }
    let maskPathAnimation = try (maskLayer.animation(forKey: "path") as? CABasicAnimation).unwrap()
    expect(maskPathAnimation.duration) == 10
    expect(maskPathAnimation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(try PathPoints(path(maskPathAnimation.fromValue))) == PathPoints(CGPath(rect: CGRect(x: -2, y: -2, width: 104, height: 104), transform: nil))
    expect(try path(maskPathAnimation.toValue)) == referenceMaskPath

    // when: updating with animation timing and the same values
    update(layer, green, animationTiming: .linear(duration: 2))

    // then: every in-flight animation already lands on the values, so none is added or replaced
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowOpacity", "shadowRadius", "shadowOffset", "shadowPath", "opacity", "position"]
    expect(layer.animation(forKey: "shadowColor")?.duration) == 10
    expect(layer.animation(forKey: "shadowColor")?.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(layer.animation(forKey: "shadowPath")) === shadowPathAnimation
    expect(Set(maskLayer.animationKeys() ?? [])) == ["position", "bounds.size", "path"]
    expect(maskLayer.animation(forKey: "path")) === maskPathAnimation

    // when: updating with animation timing and the blue values again
    update(layer, blue, animationTiming: .linear(duration: 2))

    // then: every changed property animates towards its new value: the non-additive animations are replaced, the
    // additive ones stack on the glides, and the paths add the new change to the ones in flight
    let colorAnimation = try (layer.animation(forKey: "shadowColor") as? CABasicAnimation).unwrap()
    expect(colorAnimation.duration) == 2
    expect(colorAnimation.toValue as! CGColor) == Color.blue.cgColor // swiftlint:disable:this force_cast
    let shadowOpacityAnimation = try (layer.animation(forKey: "shadowOpacity") as? CABasicAnimation).unwrap()
    expect(shadowOpacityAnimation.duration) == 2
    expect(shadowOpacityAnimation.isAdditive) == false
    expect(shadowOpacityAnimation.toValue as? Float) == 0.8
    let stackedShadowPathAnimation = try (layer.animation(forKey: "shadowPath") as? CAKeyframeAnimation).unwrap()
    expect(stackedShadowPathAnimation.duration) == 10
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowOpacity", "shadowRadius", "shadowRadius-1", "shadowOffset", "shadowOffset-1", "shadowPath", "opacity", "position"]
    let stackedMaskPathAnimation = try (maskLayer.animation(forKey: "path") as? CAKeyframeAnimation).unwrap()
    expect(stackedMaskPathAnimation.duration) == 10
    expect(Set(maskLayer.animationKeys() ?? [])) == ["position", "bounds.size", "path"]
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

  // MARK: - Missing invertsShadow

  func test_update_withoutInvertsShadow_assertsAndDrawsNothing() {
    // given: an inner shadow layer where Core Animation's invertsShadow is missing
    let layer = InnerShadowLayer()
    layer.test.supportsInvertsShadowOverride = false
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: updating the layer without and with animation
    for animationTiming in [nil, AnimationTiming.easeInEaseOut()] {
      layer.update(
        color: .red,
        opacity: 0.5,
        radius: 10,
        offset: CGSize(width: 2, height: 3),
        path: { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) },
        animationTiming: animationTiming
      )
    }

    // then: each update asserts and leaves the layer as it was, with no shadow opacity, so it draws no shadow
    let message = "Core Animation's invertsShadow is missing, so the inner shadow draws nothing"
    expect(assertionMessages) == [message, message]
    expect(layer.shadowOpacity) == 0
    expect(layer.shadowPath) == nil
    expect(layer.mask) == nil
    expect(layer.invertsShadow) == false
    expect(layer.animationKeys()) == nil
  }

  // MARK: - Paths Following the Frame

  func test_update_withAnimation_pathsAnimateOnTheFrameTiming() throws {
    for timing in [AnimationTiming.easeInEaseOut(duration: 2), .spring(dampingRatio: 0.8, response: 0.5)] {
      let scenario = "timing: \(timing)"

      // given: an inner shadow layer whose frame animates from 100 to 200 points wide
      let layer = makeLayer(width: 100)
      let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
      let paths100 = try referencePaths(width: 100)
      let paths200 = try referencePaths(width: 200)
      layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 100), timing: timing)

      // when: updating the layer with the frame's timing
      updateRounded(layer, animationTiming: timing)

      // then: the shadow path animates from the old size's path to the new size's path on the frame's timing
      let sizeAnimation = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
      let shadowPathAnimation = try (layer.animation(forKey: "shadowPath") as? CABasicAnimation).unwrap()
      expectSameTiming(shadowPathAnimation, as: sizeAnimation)
      expect(try isPath(path(shadowPathAnimation.fromValue), closeTo: paths100.shadow), scenario) == true
      expect(try path(shadowPathAnimation.toValue), scenario) == paths200.shadow

      // then: so does the clip path, with the mask's frame
      let maskSizeAnimation = try (maskLayer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
      let clipPathAnimation = try (maskLayer.animation(forKey: "path") as? CABasicAnimation).unwrap()
      expectSameTiming(clipPathAnimation, as: maskSizeAnimation)
      expect(try isPath(path(clipPathAnimation.fromValue), closeTo: paths100.clip), scenario) == true
      expect(try path(clipPathAnimation.toValue), scenario) == paths200.clip
    }
  }

  func test_update_withAnimation_interruptedResize_pathsStayOnTheFrame() throws {
    // given: an inner shadow layer whose frame and paths animate linearly from 100 to 200 points wide over 2 seconds
    let layer = makeLayer(width: 100)
    let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
    resize(layer, toWidth: 200, timing: .linear(duration: 2))

    // when: resizing to 150 points wide over 1 second while the first resize is in flight
    resize(layer, toWidth: 150, timing: .linear(duration: 1))

    // then: each keyframe has the paths for the width the frame shows at its time
    let shadowPathAnimation = try (layer.animation(forKey: "shadowPath") as? CAKeyframeAnimation).unwrap()
    let clipPathAnimation = try (maskLayer.animation(forKey: "path") as? CAKeyframeAnimation).unwrap()
    expect(shadowPathAnimation.duration) == 2
    expect(clipPathAnimation.duration) == 2
    expect(shadowPathAnimation.keyTimes) == nil
    expect(clipPathAnimation.keyTimes) == nil

    let shadowPaths = try paths(of: shadowPathAnimation)
    let clipPaths = try paths(of: clipPathAnimation)
    expect(shadowPaths.count) == clipPaths.count
    for index in shadowPaths.indices {
      let time = 2 * CGFloat(index) / CGFloat(shadowPaths.count - 1)
      let shownWidth = 150 + (100 - 200) * (1 - time / 2) + (200 - 150) * (1 - min(time, 1))
      let expectedPaths = try referencePaths(width: shownWidth)
      let scenario = "keyframe \(index)"
      expect(isPath(shadowPaths[index], closeTo: expectedPaths.shadow), scenario) == true
      expect(isPath(clipPaths[index], closeTo: expectedPaths.clip), scenario) == true
    }
  }

  func test_update_withoutAnimation_whileFrameAnimates_pathsKeepFollowingTheFrame() throws {
    // given: an inner shadow layer whose frame and paths animate linearly from 100 to 200 points wide over 2 seconds
    let layer = makeLayer(width: 100)
    let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
    resize(layer, toWidth: 200, timing: .linear(duration: 2))

    // when: a non-animated update sets the frame 250 points wide while the resize is in flight
    layer.disableActions {
      layer.frame = CGRect(x: 0, y: 0, width: 250, height: 100)
    }
    updateRounded(layer, animationTiming: nil)

    // then: the shadow path changes at once like the frame and keeps the resize going from the 150 points shown
    let paths150 = try referencePaths(width: 150)
    let paths250 = try referencePaths(width: 250)
    let sizeAnimation = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    let shadowPathAnimation = try (layer.animation(forKey: "shadowPath") as? CABasicAnimation).unwrap()
    expectSameTiming(shadowPathAnimation, as: sizeAnimation)
    expect(try isPath(path(shadowPathAnimation.fromValue), closeTo: paths150.shadow)) == true
    expect(try path(shadowPathAnimation.toValue)) == paths250.shadow
    expect(layer.shadowPath) == paths250.shadow

    // then: so does the clip path, and the mask's frame changes at once too, keeping its animations
    expect(maskLayer.frame) == CGRect(x: 0, y: 0, width: 250, height: 100)
    let maskSizeAnimation = try (maskLayer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    let clipPathAnimation = try (maskLayer.animation(forKey: "path") as? CABasicAnimation).unwrap()
    expectSameTiming(clipPathAnimation, as: maskSizeAnimation)
    expect(try isPath(path(clipPathAnimation.fromValue), closeTo: paths150.clip)) == true
    expect(try path(clipPathAnimation.toValue)) == paths250.clip
  }

  // MARK: - Helpers

  /// An inner shadow layer of the given width and 100 points high, updated by `updateRounded` without animation.
  private func makeLayer(width: CGFloat) -> InnerShadowLayer {
    let layer = InnerShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: width, height: 100)
    updateRounded(layer, animationTiming: nil)
    return layer
  }

  /// Updates the layer with a hole of the rounded rect of its size inset by 5 points, clipped by the rounded rect.
  private func updateRounded(_ layer: InnerShadowLayer, animationTiming: AnimationTiming?) {
    layer.update(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 3),
      paths: { InnerShadowPaths(shadowPath: roundedRect(size: $0, inset: 5), clipPath: roundedRect(size: $0)) },
      animationTiming: animationTiming
    )
  }

  /// Animates the frame to the width, as the render pass does, and updates the layer with the same timing.
  private func resize(_ layer: InnerShadowLayer, toWidth width: CGFloat, timing: AnimationTiming) {
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: width, height: 100), timing: timing)
    updateRounded(layer, animationTiming: timing)
  }

  /// The shadow path and the clip path `updateRounded` gives a layer of the given width.
  private func referencePaths(width: CGFloat) throws -> (shadow: CGPath, clip: CGPath) {
    let layer = makeLayer(width: width)
    return try (layer.shadowPath.unwrap(), (layer.mask as? CAShapeLayer).unwrap().path.unwrap())
  }

  /// A rounded rect of the given size at the origin, with a corner radius of 10, inset by the given amount.
  private func roundedRect(size: CGSize, inset: CGFloat = 0) -> CGPath {
    CGPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset), cornerWidth: 10, cornerHeight: 10, transform: nil)
  }

  /// Expects an animation to have the timing of another.
  private func expectSameTiming(_ animation: CABasicAnimation, as other: CABasicAnimation) {
    expect(type(of: animation) == type(of: other)) == true
    expect(animation.duration) == other.duration
    expect(animation.speed) == other.speed
    expect(animation.beginTime) == other.beginTime
    expect(animation.timingFunction) == other.timingFunction
    if let spring = animation as? CASpringAnimation, let otherSpring = other as? CASpringAnimation {
      expect(spring.mass) == otherSpring.mass
      expect(spring.stiffness) == otherSpring.stiffness
      expect(spring.damping) == otherSpring.damping
      expect(spring.initialVelocity) == otherSpring.initialVelocity
    }
  }

  /// Whether a path has the elements of another, with its points within rounding error of the other's.
  private func isPath(_ path: CGPath, closeTo other: CGPath) -> Bool {
    let points = PathPoints(path)
    let otherPoints = PathPoints(other)
    return points.hasSameSegments(as: otherPoints) && zip(points.points, otherPoints.points).allSatisfy {
      abs($0.x - $1.x) <= 1e-6 && abs($0.y - $1.y) <= 1e-6
    }
  }

  /// The paths of a keyframe animation.
  private func paths(of animation: CAKeyframeAnimation) throws -> [CGPath] {
    try animation.values.unwrap().map { try path($0) }
  }

  /// A path given as an animation value.
  private func path(_ value: Any?) throws -> CGPath {
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    try (value.unwrap() as! CGPath) // swiftlint:disable:this force_cast
  }
}
