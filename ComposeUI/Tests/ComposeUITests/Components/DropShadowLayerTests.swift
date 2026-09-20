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
    defer { ComposeUI.Assert.resetTestAssertionFailureHandler() }

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
    defer { ComposeUI.Assert.resetTestAssertionFailureHandler() }

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
    defer { ComposeUI.Assert.resetTestAssertionFailureHandler() }

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
}
