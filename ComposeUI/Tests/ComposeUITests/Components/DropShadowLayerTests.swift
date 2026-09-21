//
//  DropShadowLayerTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 6/14/26.
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

final class DropShadowLayerTests: XCTestCase {

  func test_update_clearsMaskWhenCutoutRemoved() throws {
    // given: a layer updated with a cutout, with an animation added on the mask
    let layer = DropShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)

    // with a cutout, a mask is installed to clip the shadow.
    layer.update(
      color: .black,
      opacity: 0.5,
      radius: 4,
      offset: .zero,
      path: { _ in CGPath(rect: rect, transform: nil) },
      cutoutPath: { _ in CGPath(rect: rect.insetBy(dx: 10, dy: 10), transform: nil) },
      animationTiming: nil
    )
    expect(layer.mask) != nil
    let mask = try layer.mask.unwrap()
    let animation = CABasicAnimation(keyPath: "path")
    animation.duration = 10
    mask.add(animation, forKey: "path")
    expect(mask.animationKeys()?.isEmpty) == false

    // when: updating without a cutout
    layer.update(
      color: .black,
      opacity: 0.5,
      radius: 4,
      offset: .zero,
      path: { _ in CGPath(rect: rect, transform: nil) },
      cutoutPath: nil,
      animationTiming: nil
    )

    // then: the previously installed mask is cleared, so the rendered state matches the inputs
    expect(layer.mask) == nil
    expect(mask.animationKeys() ?? []) == []
  }

  func test_update_withAnimation_animatesMask_onResize() throws {
    // given: a layer updated with a cutout, with the mask laid out for its bounds
    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    let layer = DropShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    func update(animationTiming: AnimationTiming?) {
      layer.update(
        color: .black,
        opacity: 0.5,
        radius: 4,
        offset: .zero,
        path: { CGPath(rect: $0.bounds, transform: nil) },
        cutoutPath: { CGPath(rect: $0.bounds.insetBy(dx: 10, dy: 10), transform: nil) },
        animationTiming: animationTiming
      )
    }

    update(animationTiming: nil)
    let mask = try (layer.mask as? CAShapeLayer).unwrap()
    expect(mask.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: updating with animation timing at the same size
    update(animationTiming: .easeInEaseOut())

    // then: the mask's frame and path are unchanged, so nothing animates
    expect(mask.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(mask.animationKeys()) == nil

    // when: updating with animation timing after a resize
    layer.frame = CGRect(x: 0, y: 0, width: 150, height: 80)
    update(animationTiming: .easeInEaseOut())

    // then: the mask follows the new bounds, animating its size, the position its center moved to, and its path
    expect(mask.frame) == CGRect(x: 0, y: 0, width: 150, height: 80)
    expect(mask.animation(forKey: "position")) != nil
    expect(mask.animation(forKey: "bounds.size")) != nil
    expect(mask.animation(forKey: "path")) != nil
  }

  func test_update_withAnimation_animatesOnlyChangedProperties() throws {
    // given: a layer updated with a cutout, without animation
    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    let layer = DropShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // the inputs persist across the stages below, so each stage changes exactly one of them
    var color: Color = .black
    var opacity: CGFloat = 0.5
    var radius: CGFloat = 4
    var offset = CGSize(width: 2, height: 5)
    var pathInset: CGFloat = 0
    var cutoutInset: CGFloat = 10
    func update(animationTiming: AnimationTiming?) {
      layer.update(
        color: color,
        opacity: opacity,
        radius: radius,
        offset: offset,
        path: { CGPath(rect: $0.bounds.insetBy(dx: pathInset, dy: pathInset), transform: nil) },
        cutoutPath: { CGPath(rect: $0.bounds.insetBy(dx: cutoutInset, dy: cutoutInset), transform: nil) },
        animationTiming: animationTiming
      )
    }

    update(animationTiming: nil)
    let mask = try (layer.mask as? CAShapeLayer).unwrap()

    // when: updating with animation timing and the same inputs
    update(animationTiming: .easeInEaseOut())

    // then: nothing changed, so no animation is added
    expect(layer.animationKeys()) == nil
    expect(mask.animationKeys()) == nil

    // when: updating with animation timing and only a new opacity
    opacity = 0.8
    update(animationTiming: .easeInEaseOut())

    // then: only the opacity animates, to the new value
    expect(layer.animationKeys()) == ["shadowOpacity"]
    expect(layer.shadowOpacity) == 0.8
    expect(mask.animationKeys()) == nil

    // when: updating with animation timing and only a new color
    color = .red
    update(animationTiming: .easeInEaseOut())

    // then: only the color animates, next to the in-flight opacity animation
    expect(layer.animationKeys()) == ["shadowOpacity", "shadowColor"]
    expect(layer.shadowColor) == Color.red.cgColor
    expect(mask.animationKeys()) == nil

    // when: updating with animation timing and only a new shadow path
    pathInset = 5
    update(animationTiming: .easeInEaseOut())

    // then: only the shadow path animates, the mask is unaffected since the cutout is unchanged
    expect(layer.animationKeys()) == ["shadowOpacity", "shadowColor", "shadowPath"]
    expect(layer.shadowPath) == CGPath(rect: CGRect(x: 5, y: 5, width: 90, height: 90), transform: nil)
    expect(mask.animationKeys()) == nil

    // when: updating with animation timing and only a new radius
    radius = 6
    update(animationTiming: .easeInEaseOut())

    // then: the radius animates, and so does the mask path, whose inset depends on the radius
    expect(layer.animationKeys()) == ["shadowOpacity", "shadowColor", "shadowPath", "shadowRadius"]
    expect(layer.shadowRadius) == 6
    expect(mask.animationKeys()) == ["path"]

    // when: updating with animation timing and only a new offset
    offset = CGSize(width: 3, height: 6)
    update(animationTiming: .easeInEaseOut())

    // then: the offset animates, and the mask path is re-targeted for the same reason
    expect(layer.animationKeys()) == ["shadowOpacity", "shadowColor", "shadowPath", "shadowRadius", "shadowOffset"]
    expect(layer.shadowOffset) == CGSize(width: 3, height: 6)
    expect(mask.animationKeys()) == ["path"]

    // when: updating with animation timing and only a new cutout, with the mask's animations cleared to observe it alone
    mask.removeAllAnimations()
    cutoutInset = 20
    update(animationTiming: .easeInEaseOut())

    // then: only the mask path animates
    expect(layer.animationKeys()) == ["shadowOpacity", "shadowColor", "shadowPath", "shadowRadius", "shadowOffset"]
    expect(mask.animationKeys()) == ["path"]
  }

  func test_update_pathProvider_seesAppliedProperties() {
    // given: a layer whose shadow path provider insets the bounds by the layer's shadow radius
    let layer = DropShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(layer.shadowRadius) == 3

    func update(radius: CGFloat, animationTiming: AnimationTiming?) {
      layer.update(
        color: .black,
        opacity: 0.5,
        radius: radius,
        offset: .zero,
        path: { CGPath(rect: $0.bounds.insetBy(dx: $0.shadowRadius, dy: $0.shadowRadius), transform: nil) },
        animationTiming: animationTiming
      )
    }

    // when: updating to a new radius without animation
    update(radius: 12, animationTiming: nil)

    // then: the provider saw the new radius, not the previous one
    expect(layer.shadowPath) == CGPath(rect: CGRect(x: 12, y: 12, width: 76, height: 76), transform: nil)

    // when: updating to another radius with animation
    update(radius: 20, animationTiming: .easeInEaseOut())

    // then: the provider saw the new radius again
    expect(layer.shadowPath) == CGPath(rect: CGRect(x: 20, y: 20, width: 60, height: 60), transform: nil)
    expect(layer.animation(forKey: "shadowPath")) != nil
  }

  func test_update_withAnimation_keepsInFlightAnimation_toUnchangedTarget() throws {
    // given: a layer updated with a cutout, with in-flight color and mask path animations of a distinctive duration
    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    let layer = DropShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    func update(color: Color = .black, cutoutInset: CGFloat = 10, animationTiming: AnimationTiming?) {
      layer.update(
        color: color,
        opacity: 0.5,
        radius: 4,
        offset: .zero,
        path: { CGPath(rect: $0.bounds, transform: nil) },
        cutoutPath: { CGPath(rect: $0.bounds.insetBy(dx: cutoutInset, dy: cutoutInset), transform: nil) },
        animationTiming: animationTiming
      )
    }

    update(animationTiming: nil)
    let mask = try (layer.mask as? CAShapeLayer).unwrap()

    let inFlightColorAnimation = CABasicAnimation(keyPath: "shadowColor")
    inFlightColorAnimation.duration = 10
    layer.add(inFlightColorAnimation, forKey: "shadowColor")
    let inFlightPathAnimation = CABasicAnimation(keyPath: "path")
    inFlightPathAnimation.duration = 10
    mask.add(inFlightPathAnimation, forKey: "path")

    // when: updating with animation timing and the same inputs
    update(animationTiming: .easeInEaseOut(duration: 2))

    // then: the in-flight animations are kept instead of being replaced by ones towards the same target
    let keptColorAnimation = try layer.animation(forKey: "shadowColor").unwrap()
    expect(keptColorAnimation.duration) == 10
    let keptPathAnimation = try mask.animation(forKey: "path").unwrap()
    expect(keptPathAnimation.duration) == 10

    // when: updating with animation timing and a new color and cutout
    update(color: .red, cutoutInset: 20, animationTiming: .easeInEaseOut(duration: 2))

    // then: the in-flight animations are replaced by the ones towards the new targets
    let replacedColorAnimation = try layer.animation(forKey: "shadowColor").unwrap()
    expect(replacedColorAnimation.duration) == 2
    let replacedPathAnimation = try mask.animation(forKey: "path").unwrap()
    expect(replacedPathAnimation.duration) == 2
  }

  func test_update_withoutAnimation_continuesInFlightShadowAnimations() throws {
    // given: a layer with a cutout, resized and animated towards new values of every shadow property, with a second,
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
      let inset: CGFloat
    }

    let red = Shadow(color: .red, opacity: 0.5, radius: 4, offset: .zero, inset: 5)
    let blue = Shadow(color: .blue, opacity: 0.8, radius: 20, offset: CGSize(width: 2, height: 3), inset: 10)
    let blueWiderRadius = Shadow(color: .blue, opacity: 0.8, radius: 30, offset: CGSize(width: 2, height: 3), inset: 10)

    func update(_ layer: DropShadowLayer, _ shadow: Shadow, animationTiming: AnimationTiming?) {
      layer.update(
        color: shadow.color,
        opacity: shadow.opacity,
        radius: shadow.radius,
        offset: shadow.offset,
        path: { CGPath(rect: $0.bounds.insetBy(dx: shadow.inset, dy: shadow.inset), transform: nil) },
        cutoutPath: { CGPath(rect: $0.bounds.insetBy(dx: shadow.inset * 2, dy: shadow.inset * 2), transform: nil) },
        animationTiming: animationTiming
      )
    }

    let layer = DropShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    update(layer, red, animationTiming: nil)
    let mask = try (layer.mask as? CAShapeLayer).unwrap()

    // a layer given the final inputs without animation provides the expected model values, including the mask path
    let resizedBounds = CGRect(x: 0, y: 0, width: 120, height: 120)
    let reference = DropShadowLayer()
    reference.frame = resizedBounds
    update(reference, red, animationTiming: nil)
    let referenceMask = try (reference.mask as? CAShapeLayer).unwrap()
    let referenceShadowPath = try reference.shadowPath.unwrap()
    let referenceMaskPath = try referenceMask.path.unwrap()

    layer.disableActions {
      layer.frame = resizedBounds
    }
    update(layer, blue, animationTiming: .linear(duration: 10))
    update(layer, blueWiderRadius, animationTiming: .linear(duration: 10, delay: 1))
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowOpacity", "shadowRadius", "shadowRadius-1", "shadowOffset", "shadowPath"]
    expect(Set(mask.animationKeys() ?? [])) == ["position", "bounds.size", "path"]

    let opacityAnimation = CABasicAnimation(keyPath: "opacity")
    opacityAnimation.duration = 10
    layer.add(opacityAnimation, forKey: "opacity")
    let positionAnimation = CABasicAnimation(keyPath: "position")
    positionAnimation.duration = 10
    positionAnimation.isAdditive = true
    layer.add(positionAnimation, forKey: "position")

    // when: updating without animation timing back to the old values
    update(layer, red, animationTiming: nil)

    // then: the model has the new values
    expect(layer.shadowColor) == Color.red.cgColor
    expect(layer.shadowOpacity) == 0.5
    expect(layer.shadowRadius) == 4
    expect(layer.shadowOffset) == .zero
    expect(layer.shadowPath) == referenceShadowPath
    expect(mask.frame) == referenceMask.frame
    expect(mask.path) == referenceMaskPath

    // then: the additive radius and offset animations are kept, with a decaying delta from the old values stacked on
    // them so nothing jumps, the non-additive color, opacity and path animations are replaced by ones towards the new
    // values over their remaining time, and the other properties' animations are left alone
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowOpacity", "shadowRadius", "shadowRadius-1", "shadowRadius-2", "shadowOffset", "shadowOffset-1", "shadowPath", "opacity", "position"]
    for key in ["shadowRadius", "shadowRadius-1", "shadowOffset"] {
      let keptAnimation = try (layer.animation(forKey: key) as? CABasicAnimation).unwrap()
      expect(keptAnimation.isAdditive) == true
      expect(keptAnimation.duration) == 10
      expect(keptAnimation.timingFunction) == CAMediaTimingFunction(name: .linear)
    }
    // the radius delta decays over the delayed animation's remaining time, the longest of the radius tails
    let radiusDeltaAnimation = try (layer.animation(forKey: "shadowRadius-2") as? CABasicAnimation).unwrap()
    expect(radiusDeltaAnimation.isAdditive) == true
    expect(radiusDeltaAnimation.fromValue as? CGFloat) == 26 // 30 - 4
    expect(radiusDeltaAnimation.toValue as? CGFloat) == 0
    expect(radiusDeltaAnimation.duration).to(beApproximatelyEqual(to: 11, within: 0.05))
    expect(radiusDeltaAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)

    let offsetDeltaAnimation = try (layer.animation(forKey: "shadowOffset-1") as? CABasicAnimation).unwrap()
    expect(offsetDeltaAnimation.isAdditive) == true
    expect(offsetDeltaAnimation.fromValue as? CGSize) == CGSize(width: 2, height: 3)
    expect(offsetDeltaAnimation.toValue as? CGSize) == .zero
    expect(offsetDeltaAnimation.duration) == 10
    expect(offsetDeltaAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)

    let retargetedColorAnimation = try (layer.animation(forKey: "shadowColor") as? CABasicAnimation).unwrap()
    expect(retargetedColorAnimation.duration) == 10
    expect(retargetedColorAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(retargetedColorAnimation.toValue as! CGColor) == Color.red.cgColor // swiftlint:disable:this force_cast

    let retargetedOpacityAnimation = try (layer.animation(forKey: "shadowOpacity") as? CABasicAnimation).unwrap()
    expect(retargetedOpacityAnimation.isAdditive) == false
    expect(retargetedOpacityAnimation.toValue as? Float) == 0.5
    expect(retargetedOpacityAnimation.duration) == 10
    expect(retargetedOpacityAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)

    let retargetedPathAnimation = try (layer.animation(forKey: "shadowPath") as? CABasicAnimation).unwrap()
    expect(retargetedPathAnimation.duration) == 10
    expect(retargetedPathAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(retargetedPathAnimation.toValue as! CGPath) == referenceShadowPath // swiftlint:disable:this force_cast
    expect(layer.animation(forKey: "opacity")?.duration) == 10
    expect(layer.animation(forKey: "position")?.duration) == 10

    // then: the mask keeps its frame animations, which mirror the layer's, and its path is retargeted. the mask path
    // depends on the radius, so its in-flight animation is the delayed update's, and the retarget lands when that one
    // would have, after its delay and duration
    expect(Set(mask.animationKeys() ?? [])) == ["position", "bounds.size", "path"]
    for key in ["position", "bounds.size"] {
      let keptAnimation = try (mask.animation(forKey: key) as? CABasicAnimation).unwrap()
      expect(keptAnimation.isAdditive) == true
      expect(keptAnimation.duration) == 10
      expect(keptAnimation.timingFunction) == CAMediaTimingFunction(name: .linear)
    }
    let retargetedMaskPathAnimation = try (mask.animation(forKey: "path") as? CABasicAnimation).unwrap()
    expect(retargetedMaskPathAnimation.duration).to(beApproximatelyEqual(to: 11, within: 0.05))
    expect(retargetedMaskPathAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(retargetedMaskPathAnimation.toValue as! CGPath) == referenceMaskPath // swiftlint:disable:this force_cast

    // when: updating with animation timing and the same values
    update(layer, red, animationTiming: .linear(duration: 2))

    // then: every in-flight animation already lands on the values, so none is added or replaced
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowOpacity", "shadowRadius", "shadowRadius-1", "shadowRadius-2", "shadowOffset", "shadowOffset-1", "shadowPath", "opacity", "position"]
    expect(layer.animation(forKey: "shadowColor")?.duration) == 10
    expect(layer.animation(forKey: "shadowColor")?.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(Set(mask.animationKeys() ?? [])) == ["position", "bounds.size", "path"]
    expect(mask.animation(forKey: "path")?.duration) == retargetedMaskPathAnimation.duration

    // when: updating with animation timing and the new values again
    update(layer, blue, animationTiming: .linear(duration: 2))

    // then: every changed property animates towards its new value: the non-additive animations are replaced and the
    // additive ones stack on the kept ones
    let colorAnimation = try (layer.animation(forKey: "shadowColor") as? CABasicAnimation).unwrap()
    expect(colorAnimation.duration) == 2
    expect(colorAnimation.toValue as! CGColor) == Color.blue.cgColor // swiftlint:disable:this force_cast

    let shadowOpacityAnimation = try (layer.animation(forKey: "shadowOpacity") as? CABasicAnimation).unwrap()
    expect(shadowOpacityAnimation.duration) == 2
    expect(shadowOpacityAnimation.isAdditive) == false
    expect(shadowOpacityAnimation.toValue as? Float) == 0.8
    expect(layer.animation(forKey: "shadowPath")?.duration) == 2
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowOpacity", "shadowRadius", "shadowRadius-1", "shadowRadius-2", "shadowRadius-3", "shadowOffset", "shadowOffset-1", "shadowOffset-2", "shadowPath", "opacity", "position"]
    expect(mask.animation(forKey: "path")?.duration) == 2
    expect(Set(mask.animationKeys() ?? [])) == ["position", "bounds.size", "path"]
  }

  func test_update_withoutAnimation_sameValues_keepsInFlightShadowAnimations() throws {
    // given: a layer animated towards a new color and radius
    let layer = DropShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    func update(color: Color, radius: CGFloat, animationTiming: AnimationTiming?) {
      layer.update(color: color, opacity: 0.5, radius: radius, offset: .zero, path: { CGPath(rect: $0.bounds, transform: nil) }, animationTiming: animationTiming)
    }

    update(color: .red, radius: 4, animationTiming: nil)
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
    // given: a hosted layer whose shadow color is animating from red to blue
    let testWindow = TestWindow()
    let layer = DropShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    testWindow.layer.addSublayer(layer)

    func update(color: Color, animationTiming: AnimationTiming?) {
      layer.update(color: color, opacity: 0.5, radius: 4, offset: .zero, path: { CGPath(rect: $0.bounds, transform: nil) }, animationTiming: animationTiming)
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

    // when: updating without animation timing back to red
    update(color: .red, animationTiming: nil)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

    // then: the shadow heads back to red from where it is, neither snapping nor finishing the animation towards blue
    let blueAfterUpdate = try renderedBlue()
    expect(blueAfterUpdate) > 0.01
    expect(blueAfterUpdate) < blueBeforeUpdate
    expect(try layer.animation(forKey: "shadowColor").unwrap().duration).to(beApproximatelyEqual(to: 0.35, within: 0.1))

    // then: the shadow is red when the interrupted animation would have ended
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.4))
    expect(try renderedBlue()).to(beApproximatelyEqual(to: 0, within: 0.01))
  }

  func test_update_withoutAnimation_opacityAndRadius_renderContinuously() throws {
    // given: a hosted layer whose shadow opacity and radius are animating up from zero
    let testWindow = TestWindow()
    let layer = DropShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    testWindow.layer.addSublayer(layer)

    func update(opacity: CGFloat, radius: CGFloat, animationTiming: AnimationTiming?) {
      layer.update(color: .black, opacity: opacity, radius: radius, offset: .zero, path: { CGPath(rect: $0.bounds, transform: nil) }, animationTiming: animationTiming)
    }

    func shown() throws -> (opacity: Float, radius: CGFloat) {
      let presentation = try layer.presentation().unwrap()
      return (presentation.shadowOpacity, presentation.shadowRadius)
    }

    update(opacity: 0, radius: 0, animationTiming: nil)
    CATransaction.flush()
    expect(layer.presentation()).toEventuallyNot(beNil())

    update(opacity: 1, radius: 20, animationTiming: .linear(duration: 0.5))
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
    let shownBeforeUpdate = try shown()
    expect(shownBeforeUpdate.opacity) > 0.1
    expect(shownBeforeUpdate.radius) > 2

    // when: updating without animation timing back to zero, while the animations are in flight
    update(opacity: 0, radius: 0, animationTiming: nil)

    // then: the shown values don't jump: the opacity is retargeted from what it shows and the radius keeps its additive
    // animation with a delta from the old radius stacked on it, so neither drops to zero at the update
    let shownAtUpdate = try shown()
    expect(shownAtUpdate.opacity).to(beApproximatelyEqual(to: shownBeforeUpdate.opacity, within: 0.1))
    expect(shownAtUpdate.radius).to(beApproximatelyEqual(to: shownBeforeUpdate.radius, within: 2))
    expect(layer.shadowOpacity) == 0
    expect(layer.shadowRadius) == 0

    // then: both head back to zero, and never below it
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    let shownAfterUpdate = try shown()
    expect(shownAfterUpdate.opacity) > 0.01
    expect(shownAfterUpdate.opacity) < shownBeforeUpdate.opacity
    expect(shownAfterUpdate.radius) > 0.1
    expect(shownAfterUpdate.radius) < shownBeforeUpdate.radius

    // then: both are zero when the interrupted animations would have ended
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.4))
    let shownAtEnd = try shown()
    expect(shownAtEnd.opacity).to(beApproximatelyEqual(to: 0, within: 0.01))
    expect(shownAtEnd.radius).to(beApproximatelyEqual(to: 0, within: 0.1))
  }
}
