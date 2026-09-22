//
//  CALayer+UpdateShadowTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/22/26.
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

@testable import ComposeUI

class CALayer_UpdateShadowTests: XCTestCase {

  func test_updateShadow_withoutAnimation_setsValues() {
    // given: a layer with the default shadow
    let layer = CALayer()

    // when: updating the shadow without animation
    layer.updateShadow(color: Color.red.cgColor, opacity: 0.5, radius: 4, offset: CGSize(width: 2, height: 5), animationTiming: nil)

    // then: the values are set with no animation
    expect(layer.shadowColor) == Color.red.cgColor
    expect(layer.shadowOpacity) == 0.5
    expect(layer.shadowRadius) == 4
    expect(layer.shadowOffset) == CGSize(width: 2, height: 5)
    expect(layer.animationKeys()) == nil
  }

  func test_updateShadow_withAnimation_animatesOnlyChangedProperties() throws {
    // given: a layer with a shadow set without animation
    let layer = CALayer()
    var color = Color.red.cgColor
    var opacity: Float = 0.5
    var radius: CGFloat = 4
    var offset = CGSize(width: 2, height: 5)
    func update(animationTiming: AnimationTiming?) {
      layer.updateShadow(color: color, opacity: opacity, radius: radius, offset: offset, animationTiming: animationTiming)
    }
    update(animationTiming: nil)

    // when: updating with animation timing and the same values
    update(animationTiming: .linear(duration: 1))

    // then: nothing changed, so no animation is added
    expect(layer.animationKeys()) == nil

    // when: updating with animation timing and only a new opacity
    opacity = 0.8
    update(animationTiming: .linear(duration: 1))

    // then: only the opacity animates, non-additively since the render server clamps it per animation
    expect(layer.animationKeys()) == ["shadowOpacity"]
    let opacityAnimation = try (layer.animation(forKey: "shadowOpacity") as? CABasicAnimation).unwrap()
    expect(opacityAnimation.isAdditive) == false
    expect(opacityAnimation.toValue as? Float) == 0.8
    expect(layer.shadowOpacity) == 0.8

    // when: updating with animation timing and only a new color
    color = Color.blue.cgColor
    update(animationTiming: .linear(duration: 1))

    // then: only the color animates, non-additively, next to the in-flight opacity animation
    expect(layer.animationKeys()) == ["shadowOpacity", "shadowColor"]
    let colorAnimation = try (layer.animation(forKey: "shadowColor") as? CABasicAnimation).unwrap()
    expect(colorAnimation.isAdditive) == false
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(colorAnimation.toValue as! CGColor) == Color.blue.cgColor // swiftlint:disable:this force_cast
    expect(layer.shadowColor) == Color.blue.cgColor

    // when: updating with animation timing and only a new radius
    radius = 6
    update(animationTiming: .linear(duration: 1))

    // then: only the radius animates, additively
    expect(layer.animationKeys()) == ["shadowOpacity", "shadowColor", "shadowRadius"]
    let radiusAnimation = try (layer.animation(forKey: "shadowRadius") as? CABasicAnimation).unwrap()
    expect(radiusAnimation.isAdditive) == true
    expect(radiusAnimation.fromValue as? CGFloat) == -2 // 4 - 6
    expect(radiusAnimation.toValue as? CGFloat) == 0
    expect(layer.shadowRadius) == 6

    // when: updating with animation timing and only a new offset
    offset = CGSize(width: 3, height: 6)
    update(animationTiming: .linear(duration: 1))

    // then: only the offset animates, additively
    expect(layer.animationKeys()) == ["shadowOpacity", "shadowColor", "shadowRadius", "shadowOffset"]
    let offsetAnimation = try (layer.animation(forKey: "shadowOffset") as? CABasicAnimation).unwrap()
    expect(offsetAnimation.isAdditive) == true
    expect(offsetAnimation.fromValue as? CGSize) == CGSize(width: -1, height: -1) // (2, 5) - (3, 6)
    expect(offsetAnimation.toValue as? CGSize) == .zero
    expect(layer.shadowOffset) == CGSize(width: 3, height: 6)
  }

  func test_updateShadow_withoutAnimation_continuesInFlightAnimations() throws {
    // given: a layer animating every shadow property to new values
    let layer = CALayer()
    layer.updateShadow(color: Color.red.cgColor, opacity: 0.5, radius: 4, offset: .zero, animationTiming: nil)
    layer.updateShadow(color: Color.blue.cgColor, opacity: 0.8, radius: 20, offset: CGSize(width: 2, height: 3), animationTiming: .linear(duration: 10))
    expect(layer.animationKeys()) == ["shadowColor", "shadowOpacity", "shadowRadius", "shadowOffset"]

    // when: updating without animation to other values
    layer.updateShadow(color: Color.green.cgColor, opacity: 0.6, radius: 8, offset: CGSize(width: 1, height: 1), animationTiming: nil)

    // then: the model has the new values
    expect(layer.shadowColor) == Color.green.cgColor
    expect(layer.shadowOpacity) == 0.6
    expect(layer.shadowRadius) == 8
    expect(layer.shadowOffset) == CGSize(width: 1, height: 1)

    // then: the additive radius and offset animations are folded into one glide each, from the value shown to the new
    // value: nothing has begun, so the radius shows 4 and the offset zero. the non-additive color and opacity animations
    // are replaced by ones easing out to the new values over their remaining time
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowOpacity", "shadowRadius", "shadowOffset"]
    let radiusGlide = try (layer.animation(forKey: "shadowRadius") as? CABasicAnimation).unwrap()
    expect(radiusGlide.isAdditive) == true
    expect(radiusGlide.fromValue as? CGFloat) == -4
    expect(radiusGlide.toValue as? CGFloat) == 0
    expect(radiusGlide.duration) == 10
    expect(radiusGlide.timingFunction) == CAMediaTimingFunction(name: .easeOut)

    let offsetGlide = try (layer.animation(forKey: "shadowOffset") as? CABasicAnimation).unwrap()
    expect(offsetGlide.isAdditive) == true
    expect(offsetGlide.fromValue as? CGSize) == CGSize(width: -1, height: -1)
    expect(offsetGlide.toValue as? CGSize) == .zero

    let colorAnimation = try (layer.animation(forKey: "shadowColor") as? CABasicAnimation).unwrap()
    expect(colorAnimation.isAdditive) == false
    expect(colorAnimation.duration) == 10
    expect(colorAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(colorAnimation.toValue as! CGColor) == Color.green.cgColor // swiftlint:disable:this force_cast

    let opacityAnimation = try (layer.animation(forKey: "shadowOpacity") as? CABasicAnimation).unwrap()
    expect(opacityAnimation.isAdditive) == false
    expect(opacityAnimation.duration) == 10
    expect(opacityAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(opacityAnimation.toValue as? Float) == 0.6
  }
}
