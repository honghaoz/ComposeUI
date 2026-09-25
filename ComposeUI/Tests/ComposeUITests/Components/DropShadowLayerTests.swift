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

@_spi(Private) @testable import ComposeUI

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
      paths: { _ in DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: CGPath(rect: rect.insetBy(dx: 10, dy: 10), transform: nil)) },
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
      animationTiming: nil
    )

    // then: the previously installed mask is cleared, so the rendered state matches the inputs
    expect(layer.mask) == nil
    expect(mask.animationKeys() ?? []) == []
  }

  func test_update_withAnimation_animatesMask_onResize() throws {
    // given: a layer updated with a cutout, with the mask laid out for its bounds
    let layer = DropShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    func update(animationTiming: AnimationTiming?) {
      layer.update(
        color: .black,
        opacity: 0.5,
        radius: 4,
        offset: .zero,
        paths: { DropShadowPaths(shadowPath: CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil), cutoutPath: CGPath(rect: CGRect(origin: .zero, size: $0).insetBy(dx: 10, dy: 10), transform: nil)) },
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
        paths: { DropShadowPaths(shadowPath: CGPath(rect: CGRect(origin: .zero, size: $0).insetBy(dx: pathInset, dy: pathInset), transform: nil), cutoutPath: CGPath(rect: CGRect(origin: .zero, size: $0).insetBy(dx: cutoutInset, dy: cutoutInset), transform: nil)) },
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

    // then: only the radius animates, the mask is unaffected since its path doesn't depend on the radius
    expect(layer.animationKeys()) == ["shadowOpacity", "shadowColor", "shadowPath", "shadowRadius"]
    expect(layer.shadowRadius) == 6
    expect(mask.animationKeys()) == nil

    // when: updating with animation timing and only a new offset
    offset = CGSize(width: 3, height: 6)
    update(animationTiming: .easeInEaseOut())

    // then: only the offset animates, the mask is unaffected for the same reason
    expect(layer.animationKeys()) == ["shadowOpacity", "shadowColor", "shadowPath", "shadowRadius", "shadowOffset"]
    expect(layer.shadowOffset) == CGSize(width: 3, height: 6)
    expect(mask.animationKeys()) == nil

    // when: updating with animation timing and only a new cutout
    cutoutInset = 20
    update(animationTiming: .easeInEaseOut())

    // then: only the mask path animates
    expect(layer.animationKeys()) == ["shadowOpacity", "shadowColor", "shadowPath", "shadowRadius", "shadowOffset"]
    expect(mask.animationKeys()) == ["path"]
  }

  func test_update_withAnimation_keepsInFlightAnimation_toUnchangedTarget() throws {
    // given: a layer updated with a cutout, with in-flight color and mask path animations of a distinctive duration
    let layer = DropShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    func update(color: Color = .black, cutoutInset: CGFloat = 10, animationTiming: AnimationTiming?) {
      layer.update(
        color: color,
        opacity: 0.5,
        radius: 4,
        offset: .zero,
        paths: { DropShadowPaths(shadowPath: CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil), cutoutPath: CGPath(rect: CGRect(origin: .zero, size: $0).insetBy(dx: cutoutInset, dy: cutoutInset), transform: nil)) },
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
    let green = Shadow(color: .green, opacity: 0.6, radius: 8, offset: CGSize(width: 1, height: 1), inset: 6)

    func update(_ layer: DropShadowLayer, _ shadow: Shadow, animationTiming: AnimationTiming?) {
      layer.update(
        color: shadow.color,
        opacity: shadow.opacity,
        radius: shadow.radius,
        offset: shadow.offset,
        paths: { DropShadowPaths(shadowPath: CGPath(rect: CGRect(origin: .zero, size: $0).insetBy(dx: shadow.inset, dy: shadow.inset), transform: nil), cutoutPath: CGPath(rect: CGRect(origin: .zero, size: $0).insetBy(dx: shadow.inset * 2, dy: shadow.inset * 2), transform: nil)) },
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
    expect(Set(mask.animationKeys() ?? [])) == ["position", "bounds.size", "path"]
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
    expect(layer.shadowRadius) == 8
    expect(layer.shadowOffset) == CGSize(width: 1, height: 1)
    expect(layer.shadowPath) == referenceShadowPath
    expect(mask.frame) == referenceMask.frame
    expect(mask.path) == referenceMaskPath

    // then: the additive radius and offset animations are folded into one glide each, from the value shown to the new
    // value, the non-additive color and opacity animations are replaced by ones towards the new values over their
    // remaining time, the path keeps its animation, and the other properties' animations are left alone
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowOpacity", "shadowRadius", "shadowOffset", "shadowPath", "opacity", "position"]

    // no radius or offset animation has begun, so the radius shows 4 and the offset zero. the radius glide lands when the
    // delayed update would have, after its delay and duration
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

    // then: the shadow path changes at once and keeps its change in flight, shown on top of the new path
    let shadowPathAnimation = try (layer.animation(forKey: "shadowPath") as? CABasicAnimation).unwrap()
    expect(shadowPathAnimation.duration) == 10
    expect(shadowPathAnimation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(try PathPoints(path(shadowPathAnimation.fromValue))) == PathPoints(CGPath(rect: CGRect(x: 1, y: 1, width: 98, height: 98), transform: nil))
    expect(try path(shadowPathAnimation.toValue)) == referenceShadowPath

    // then: the mask keeps its frame animations, and its path does as the shadow path
    expect(Set(mask.animationKeys() ?? [])) == ["position", "bounds.size", "path"]
    for key in ["position", "bounds.size"] {
      let keptAnimation = try (mask.animation(forKey: key) as? CABasicAnimation).unwrap()
      expect(keptAnimation.isAdditive) == true
      expect(keptAnimation.duration) == 10
      expect(keptAnimation.timingFunction) == CAMediaTimingFunction(name: .linear)
    }
    let maskPathAnimation = try (mask.animation(forKey: "path") as? CABasicAnimation).unwrap()
    expect(maskPathAnimation.duration) == 10
    expect(maskPathAnimation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(try PathPoints(path(maskPathAnimation.fromValue))) == PathPoints(maskPath(cutout: CGPath(rect: CGRect(x: 2, y: 2, width: 96, height: 96), transform: nil)))
    expect(try path(maskPathAnimation.toValue)) == referenceMaskPath

    // when: updating with animation timing and the same values
    update(layer, green, animationTiming: .linear(duration: 2))

    // then: every in-flight animation already lands on the values, so none is added or replaced
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowOpacity", "shadowRadius", "shadowOffset", "shadowPath", "opacity", "position"]
    expect(layer.animation(forKey: "shadowColor")?.duration) == 10
    expect(layer.animation(forKey: "shadowColor")?.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(layer.animation(forKey: "shadowPath")) === shadowPathAnimation
    expect(Set(mask.animationKeys() ?? [])) == ["position", "bounds.size", "path"]
    expect(mask.animation(forKey: "path")) === maskPathAnimation

    // when: updating with animation timing and the blue values again
    update(layer, blue, animationTiming: .linear(duration: 2))

    // then: every changed property animates towards its new value: the non-additive animations are replaced, the
    // additive ones stack on the glides, and the paths add the new change to the one in flight
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
    let stackedMaskPathAnimation = try (mask.animation(forKey: "path") as? CAKeyframeAnimation).unwrap()
    expect(stackedMaskPathAnimation.duration) == 10
    expect(Set(mask.animationKeys() ?? [])) == ["position", "bounds.size", "path"]
  }

  func test_update_withoutAnimation_sameValues_keepsInFlightShadowAnimations() throws {
    // given: a layer animated towards a new color and radius
    let layer = DropShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    func update(color: Color, radius: CGFloat, animationTiming: AnimationTiming?) {
      layer.update(color: color, opacity: 0.5, radius: radius, offset: .zero, path: { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) }, animationTiming: animationTiming)
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
      layer.update(color: color, opacity: 0.5, radius: 4, offset: .zero, path: { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) }, animationTiming: animationTiming)
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

  func test_update_withoutAnimation_opacityAndRadius_renderContinuously() throws {
    // given: a hosted layer whose shadow opacity and radius are animating up from zero
    let testWindow = TestWindow()
    let layer = DropShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    testWindow.layer.addSublayer(layer)

    func update(opacity: CGFloat, radius: CGFloat, animationTiming: AnimationTiming?) {
      layer.update(color: .black, opacity: opacity, radius: radius, offset: .zero, path: { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) }, animationTiming: animationTiming)
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
    // animation with a scaled copy of it stacked on top, so neither drops to zero at the update
    expect(layer.shadowOpacity) == 0
    expect(layer.shadowRadius) == 0
    let now = layer.currentTime
    expect(try layer.predictedValue(forKeyPath: "shadowOpacity", at: now, scalar: numberScalar))
      .to(beApproximatelyEqual(to: CGFloat(shownBeforeUpdate.opacity), within: 0.05))
    expect(try layer.predictedValue(forKeyPath: "shadowRadius", at: now, scalar: numberScalar))
      .to(beApproximatelyEqual(to: shownBeforeUpdate.radius, within: 0.5))

    // then: both head back to zero along their animations and land when the interrupted animations would have. the run
    // loop's timing isn't reliable, so the test checks each look against the animations' own values for that time
    // instead of expecting values at a fixed delay. the radius' copy ends a few milliseconds before its animation, so
    // the last frame can show the animation's last sliver alone
    var landed = false
    for _ in 0 ..< 40 where !landed {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
      let shownNow = try shown()
      let now = layer.currentTime
      let predictedOpacity = try layer.predictedValue(forKeyPath: "shadowOpacity", at: now, scalar: numberScalar)
      let predictedRadius = try layer.predictedValue(forKeyPath: "shadowRadius", at: now, scalar: numberScalar)
      expect(CGFloat(shownNow.opacity)).to(beApproximatelyEqual(to: predictedOpacity, within: 0.05))
      expect(shownNow.radius).to(beApproximatelyEqual(to: predictedRadius, within: 0.5))
      expect(shownNow.opacity) >= 0
      expect(shownNow.radius) >= -0.5
      landed = shownNow.opacity < 0.01 && shownNow.radius < 0.1
    }
    expect(landed) == true
  }

  // MARK: - Paths Following the Frame

  func test_update_withAnimation_pathsAnimateOnTheFrameTiming() throws {
    for timing in [AnimationTiming.easeInEaseOut(duration: 2), .spring(dampingRatio: 0.8, response: 0.5)] {
      // given: a layer with a cutout whose frame animates from 100 to 200 points wide
      let layer = makeLayer(width: 100)
      let mask = try (layer.mask as? CAShapeLayer).unwrap()
      layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 100), timing: timing)

      // when: updating the layer with the frame's timing
      updateRounded(layer, animationTiming: timing)

      // then: the shadow path animates from the old size's path to the new size's path on the frame's timing
      let sizeAnimation = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
      let shadowPathAnimation = try (layer.animation(forKey: "shadowPath") as? CABasicAnimation).unwrap()
      expectSameTiming(shadowPathAnimation, as: sizeAnimation)
      expect(try isPath(path(shadowPathAnimation.fromValue), closeTo: roundedRect(width: 100))) == true
      expect(try path(shadowPathAnimation.toValue)) == roundedRect(width: 200)

      // then: so does the mask path, with the mask's frame
      let maskSizeAnimation = try (mask.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
      let maskPathAnimation = try (mask.animation(forKey: "path") as? CABasicAnimation).unwrap()
      expectSameTiming(maskPathAnimation, as: maskSizeAnimation)
      expect(try isPath(path(maskPathAnimation.fromValue), closeTo: maskPath(width: 100))) == true
      expect(try PathPoints(path(maskPathAnimation.toValue))) == PathPoints(maskPath(width: 200))
    }
  }

  func test_update_withAnimation_interruptedResize_pathsStayOnTheFrame() throws {
    // given: a layer with a cutout whose frame and paths animate linearly from 100 to 200 points wide over 2 seconds
    let layer = makeLayer(width: 100)
    let mask = try (layer.mask as? CAShapeLayer).unwrap()
    resize(layer, toWidth: 200, timing: .linear(duration: 2))

    // when: resizing to 150 points wide over 1 second while the first resize is in flight
    resize(layer, toWidth: 150, timing: .linear(duration: 1))

    // then: each keyframe has the paths for the width the frame shows at its time
    let shadowPathAnimation = try (layer.animation(forKey: "shadowPath") as? CAKeyframeAnimation).unwrap()
    let maskPathAnimation = try (mask.animation(forKey: "path") as? CAKeyframeAnimation).unwrap()
    expect(shadowPathAnimation.duration) == 2
    expect(maskPathAnimation.duration) == 2
    expect(shadowPathAnimation.keyTimes) == nil
    expect(maskPathAnimation.keyTimes) == nil

    let shadowPaths = try paths(of: shadowPathAnimation)
    let maskPaths = try paths(of: maskPathAnimation)
    expect(shadowPaths.count) == maskPaths.count
    for index in shadowPaths.indices {
      let time = 2 * CGFloat(index) / CGFloat(shadowPaths.count - 1)
      let shownWidth = 150 + (100 - 200) * (1 - time / 2) + (200 - 150) * (1 - min(time, 1))
      expect(isPath(shadowPaths[index], closeTo: roundedRect(width: shownWidth)), "keyframe \(index)") == true
      expect(isPath(maskPaths[index], closeTo: maskPath(width: shownWidth)), "keyframe \(index)") == true
    }
  }

  func test_update_withAnimation_shapeChangeWhileResizing_resizeKeepsGoing() throws {
    // given: a layer with a corner radius of 10 whose frame and paths animate linearly from 100 to 200 points wide
    let layer = makeLayer(width: 100)
    let mask = try (layer.mask as? CAShapeLayer).unwrap()
    resize(layer, toWidth: 200, timing: .linear(duration: 2))

    // when: the corner radius animates to 20 over half a second
    updateRounded(layer, cornerRadius: 20, animationTiming: .linear(duration: 0.5))

    // then: the change adds to the resize: a second in, the paths have the new corner radius at the 150 points shown
    let shadowPathAnimation = try (layer.animation(forKey: "shadowPath") as? CAKeyframeAnimation).unwrap()
    let maskPathAnimation = try (mask.animation(forKey: "path") as? CAKeyframeAnimation).unwrap()
    expect(shadowPathAnimation.duration) == 2
    expect(maskPathAnimation.duration) == 2
    expect(shadowPathAnimation.keyTimes) == nil
    expect(maskPathAnimation.keyTimes) == nil

    let shadowPaths = try paths(of: shadowPathAnimation)
    let maskPaths = try paths(of: maskPathAnimation)
    expect(isPath(shadowPaths[0], closeTo: roundedRect(width: 100))) == true
    expect(isPath(shadowPaths[shadowPaths.count / 2], closeTo: roundedRect(width: 150, cornerRadius: 20))) == true
    expect(shadowPaths.last) == roundedRect(width: 200, cornerRadius: 20)
    expect(isPath(maskPaths[0], closeTo: maskPath(width: 100))) == true
    expect(isPath(maskPaths[maskPaths.count / 2], closeTo: maskPath(width: 150, cornerRadius: 20))) == true
    expect(try PathPoints(maskPaths.last.unwrap())) == PathPoints(maskPath(width: 200, cornerRadius: 20))
  }

  func test_update_withoutAnimation_whileFrameAnimates_pathsKeepFollowingTheFrame() throws {
    // given: a layer with a cutout, whose frame animates linearly from 100 to 200 points wide over 2 seconds
    let layer = makeLayer(width: 100)
    let mask = try (layer.mask as? CAShapeLayer).unwrap()
    resize(layer, toWidth: 200, timing: .linear(duration: 2))

    // when: a non-animated update sets the frame 250 points wide while the resize is in flight
    layer.disableActions {
      layer.frame = CGRect(x: 0, y: 0, width: 250, height: 100)
    }
    updateRounded(layer, animationTiming: nil)

    // then: the shadow path changes at once like the frame and keeps the resize going from the 150 points shown
    let sizeAnimation = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    let shadowPathAnimation = try (layer.animation(forKey: "shadowPath") as? CABasicAnimation).unwrap()
    expectSameTiming(shadowPathAnimation, as: sizeAnimation)
    expect(try isPath(path(shadowPathAnimation.fromValue), closeTo: roundedRect(width: 150))) == true
    expect(try path(shadowPathAnimation.toValue)) == roundedRect(width: 250)
    expect(layer.shadowPath) == roundedRect(width: 250)

    // then: so does the mask path, and the mask's frame changes at once too, keeping its animations
    expect(mask.frame) == CGRect(x: 0, y: 0, width: 250, height: 100)
    let maskSizeAnimation = try (mask.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    let maskPathAnimation = try (mask.animation(forKey: "path") as? CABasicAnimation).unwrap()
    expectSameTiming(maskPathAnimation, as: maskSizeAnimation)
    expect(try isPath(path(maskPathAnimation.fromValue), closeTo: maskPath(width: 150))) == true
    expect(try PathPoints(path(maskPathAnimation.toValue))) == PathPoints(maskPath(width: 250))
  }

  func test_update_withAnimation_pathsOfOtherElements_changeAtOnce() throws {
    // given: a layer whose paths are rects at 100 points wide and ellipses at other widths
    let layer = DropShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    func update(animationTiming: AnimationTiming?) {
      layer.update(
        color: .black,
        opacity: 0.5,
        radius: 4,
        offset: .zero,
        paths: { size in
          let bounds = CGRect(origin: .zero, size: size)
          let path = size.width == 100 ? CGPath(rect: bounds, transform: nil) : CGPath(ellipseIn: bounds, transform: nil)
          return DropShadowPaths(shadowPath: path, cutoutPath: path)
        },
        animationTiming: animationTiming
      )
    }
    update(animationTiming: nil)
    let mask = try (layer.mask as? CAShapeLayer).unwrap()

    // when: the frame animates to 200 points wide, and the layer is updated with the frame's timing
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 100), timing: .linear(duration: 2))
    update(animationTiming: .linear(duration: 2))

    // then: the points of the paths don't line up, so the paths change at once, while the mask's frame animates
    expect(layer.shadowPath) == CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 200, height: 100), transform: nil)
    expect(layer.animation(forKey: "shadowPath")) == nil
    expect(try PathPoints(mask.path.unwrap())) == PathPoints(maskPath(cutout: CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 200, height: 100), transform: nil)))
    expect(mask.animation(forKey: "path")) == nil
    expect(mask.animation(forKey: "bounds.size")) != nil
  }

  // MARK: - Helpers

  /// A layer of the given width and 100 points high at the origin, updated by `updateRounded` without animation.
  private func makeLayer(width: CGFloat) -> DropShadowLayer {
    let layer = DropShadowLayer()
    layer.frame = CGRect(x: 0, y: 0, width: width, height: 100)
    updateRounded(layer, animationTiming: nil)
    return layer
  }

  /// Updates the layer with a rounded rect shadow of its size, cut out by the rounded rect inset by 10 points.
  private func updateRounded(_ layer: DropShadowLayer, cornerRadius: CGFloat = 10, animationTiming: AnimationTiming?) {
    layer.update(
      color: .black,
      opacity: 0.5,
      radius: 4,
      offset: .zero,
      paths: { DropShadowPaths(shadowPath: roundedRect(size: $0, cornerRadius: cornerRadius), cutoutPath: roundedRect(size: $0, cornerRadius: cornerRadius, inset: 10)) },
      animationTiming: animationTiming
    )
  }

  /// Animates the frame to the width, as the render pass does, and updates the layer with the same timing.
  private func resize(_ layer: DropShadowLayer, toWidth width: CGFloat, timing: AnimationTiming) {
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: width, height: 100), timing: timing)
    updateRounded(layer, animationTiming: timing)
  }

  /// A rounded rect of the given size at the origin, inset by the given amount.
  private func roundedRect(size: CGSize, cornerRadius: CGFloat = 10, inset: CGFloat = 0) -> CGPath {
    CGPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
  }

  /// A rounded rect of the given width and 100 points high at the origin, inset by the given amount.
  private func roundedRect(width: CGFloat, cornerRadius: CGFloat = 10, inset: CGFloat = 0) -> CGPath {
    roundedRect(size: CGSize(width: width, height: 100), cornerRadius: cornerRadius, inset: inset)
  }

  /// The mask path `updateRounded` gives a layer of the given width.
  private func maskPath(width: CGFloat, cornerRadius: CGFloat = 10) -> CGPath {
    maskPath(cutout: roundedRect(width: width, cornerRadius: cornerRadius, inset: 10))
  }

  /// The mask path of a cutout: a rect reaching a million points past the cutout, with the cutout punched out.
  private func maskPath(cutout: CGPath) -> CGPath {
    let path = CGMutablePath()
    path.addPath(CGPath(rect: cutout.boundingBoxOfPath.insetBy(dx: -1000000, dy: -1000000), transform: nil))
    path.addPath(cutout)
    return path
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
