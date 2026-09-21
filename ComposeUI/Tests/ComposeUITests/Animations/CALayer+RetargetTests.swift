//
//  CALayer+RetargetTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/21/26.
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

class CALayer_RetargetTests: XCTestCase {

  // MARK: - Remaining Animation Time

  func test_remainingAnimationTime_noAnimationOfKeyPath() {
    // given: a layer with an animation of another key path only
    let layer = CALayer()

    let spinAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    spinAnimation.duration = 60
    layer.add(spinAnimation, forKey: "spin")

    // then: no opacity animation is in flight
    expect(layer.remainingAnimationTime(forKeyPath: "opacity")) == nil
  }

  func test_remainingAnimationTime_unresolvedBeginTime() throws {
    // given: a layer with an opacity animation that isn't committed yet, so its begin time is unset
    let layer = CALayer()

    let fadeAnimation = CABasicAnimation(keyPath: "opacity")
    fadeAnimation.duration = 4
    layer.add(fadeAnimation, forKey: "fade")
    expect(try layer.animation(forKey: "fade").unwrap().beginTime) == 0

    // then: the animation begins at the commit, so its whole duration remains
    expect(layer.remainingAnimationTime(forKeyPath: "opacity")) == 4

    // when: the animation runs at double speed
    fadeAnimation.speed = 2
    layer.add(fadeAnimation, forKey: "fade")

    // then: the duration is scaled by the speed
    expect(layer.remainingAnimationTime(forKeyPath: "opacity")) == 2

    // when: the animation is paused
    fadeAnimation.speed = 0
    layer.add(fadeAnimation, forKey: "fade")

    // then: the duration stands in, as a paused animation has no end to measure to
    expect(layer.remainingAnimationTime(forKeyPath: "opacity")) == 4
  }

  func test_remainingAnimationTime_longestAnimationWins() {
    // given: a layer with basic and keyframe opacity animations of different durations, and an animation group
    let layer = CALayer()

    let shortFadeAnimation = CABasicAnimation(keyPath: "opacity")
    shortFadeAnimation.duration = 3
    layer.add(shortFadeAnimation, forKey: "short-fade")

    let longFadeAnimation = CAKeyframeAnimation(keyPath: "opacity")
    longFadeAnimation.duration = 10
    layer.add(longFadeAnimation, forKey: "long-fade")

    // an animation group has no key path of its own and doesn't count
    let groupAnimation = CAAnimationGroup()
    groupAnimation.duration = 60
    layer.add(groupAnimation, forKey: "group")

    // then: the longest opacity animation's time remains
    expect(layer.remainingAnimationTime(forKeyPath: "opacity")) == 10
  }

  func test_remainingAnimationTime_scheduledAnimation() throws {
    // given: a layer with an opacity animation scheduled one second ahead
    let layer = CALayer()

    let fadeAnimation = CABasicAnimation(keyPath: "opacity")
    fadeAnimation.duration = 2
    fadeAnimation.beginTime = layer.currentTime + 1
    layer.add(fadeAnimation, forKey: "fade")

    // then: the remaining delay counts towards the remaining time
    expect(try layer.remainingAnimationTime(forKeyPath: "opacity").unwrap()).to(beApproximatelyEqual(to: 3, within: 0.05))
  }

  func test_remainingAnimationTime_endedAnimation() {
    // given: a layer with an opacity animation that ended but stays on the layer
    let layer = CALayer()

    let fadeAnimation = CABasicAnimation(keyPath: "opacity")
    fadeAnimation.duration = 2
    fadeAnimation.beginTime = layer.currentTime - 5
    fadeAnimation.isRemovedOnCompletion = false
    layer.add(fadeAnimation, forKey: "fade")

    // then: nothing is in flight
    expect(layer.remainingAnimationTime(forKeyPath: "opacity")) == nil
  }

  func test_remainingAnimationTime_committedAnimation() throws {
    // given: a hosted layer with a committed opacity animation that has run for a while
    let testWindow = TestWindow()
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    testWindow.layer.addSublayer(layer)
    CATransaction.flush()

    let fadeAnimation = CABasicAnimation(keyPath: "opacity")
    fadeAnimation.fromValue = Float(1)
    fadeAnimation.toValue = Float(0)
    fadeAnimation.duration = 2
    layer.add(fadeAnimation, forKey: "fade")
    CATransaction.flush()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    expect(try layer.animation(forKey: "fade").unwrap().beginTime) > 0

    // then: the time to the animation's end remains
    expect(try layer.remainingAnimationTime(forKeyPath: "opacity").unwrap()).to(beApproximatelyEqual(to: 1.9, within: 0.1))
  }

  // MARK: - Retarget

  func test_retarget_withoutInFlightAnimation_setsValue() {
    // given: a hosted layer with a background color and an animation of another key path
    let testWindow = TestWindow()
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    layer.backgroundColor = Color.red.cgColor
    testWindow.layer.addSublayer(layer)
    CATransaction.flush()

    let spinAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    spinAnimation.duration = 60
    layer.add(spinAnimation, forKey: "spin")

    // when: retargeting the background color to a new color
    layer.retarget(keyPath: "backgroundColor", to: Color.blue.cgColor)

    // then: the color is set without an animation, implicit or otherwise, and the other animation is left alone
    expect(layer.backgroundColor) == Color.blue.cgColor
    expect(layer.animationKeys()) == ["spin"]
  }

  func test_retarget_inFlightAnimationToSameValue_isKept() throws {
    // given: a layer with a linear background color animation heading to the model color
    let layer = CALayer()
    layer.backgroundColor = Color.red.cgColor
    layer.animate(
      keyPath: "backgroundColor",
      timing: .linear(duration: 10),
      from: { _ in Color.red.cgColor },
      to: { _ in Color.blue.cgColor }
    )
    expect(layer.backgroundColor) == Color.blue.cgColor

    // when: retargeting the background color to the color the animation heads to
    layer.retarget(keyPath: "backgroundColor", to: Color.blue.cgColor)

    // then: the animation keeps its easing instead of being replaced by one to the same color
    let animation = try (layer.animation(forKey: "backgroundColor") as? CABasicAnimation).unwrap()
    expect(animation.duration) == 10
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(layer.animationKeys()) == ["backgroundColor"]
    expect(layer.backgroundColor) == Color.blue.cgColor
  }

  func test_retarget_inFlightAnimation_replacesWithEaseOutOverRemainingTime() throws {
    // given: a layer with two uncommitted background color animations of different durations, and an animation of
    // another key path
    let layer = CALayer()
    layer.backgroundColor = Color.blue.cgColor

    let shortAnimation = CABasicAnimation(keyPath: "backgroundColor")
    shortAnimation.duration = 3
    layer.add(shortAnimation, forKey: "short")
    let longAnimation = CABasicAnimation(keyPath: "backgroundColor")
    longAnimation.duration = 10
    layer.add(longAnimation, forKey: "long")

    let spinAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    spinAnimation.duration = 60
    layer.add(spinAnimation, forKey: "spin")

    // when: retargeting the background color to a new color
    layer.retarget(keyPath: "backgroundColor", to: Color.green.cgColor)

    // then: the color animations are replaced by one easing out to the new color over the longest one's remaining
    // time, the model has the new color, and the other animation is left alone
    expect(layer.animationKeys()) == ["spin", "backgroundColor"]
    let animation = try (layer.animation(forKey: "backgroundColor") as? CABasicAnimation).unwrap()
    expect(animation.duration) == 10
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(animation.isAdditive) == false
    expect(animation.fillMode) == .both
    expect(animation.isRemovedOnCompletion) == true
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(animation.toValue as! CGColor) == Color.green.cgColor // swiftlint:disable:this force_cast
    expect(layer.backgroundColor) == Color.green.cgColor
  }

  func test_retarget_hosted_continuesFromShownValue() throws {
    // given: a hosted layer whose background color is animating from red to blue
    let testWindow = TestWindow()
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    layer.backgroundColor = Color.red.cgColor
    testWindow.layer.addSublayer(layer)
    CATransaction.flush()
    expect(layer.presentation()).toEventuallyNot(beNil())

    func shownBlue() throws -> CGFloat {
      try blueComponent(of: layer.presentation().unwrap().backgroundColor.unwrap())
    }

    layer.animate(
      keyPath: "backgroundColor",
      timing: .linear(duration: 0.5),
      from: { _ in Color.red.cgColor },
      to: { _ in Color.blue.cgColor }
    )
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
    let blueBeforeRetarget = try shownBlue()
    expect(blueBeforeRetarget) > 0.1

    // when: retargeting the background color back to red
    layer.retarget(keyPath: "backgroundColor", to: Color.red.cgColor)

    // then: the retargeting animation starts from the shown color and lands when the interrupted one would have
    let animation = try (layer.animation(forKey: "backgroundColor") as? CABasicAnimation).unwrap()
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(try blueComponent(of: animation.fromValue as! CGColor)).to(beApproximatelyEqual(to: blueBeforeRetarget, within: 0.1)) // swiftlint:disable:this force_cast
    expect(animation.duration).to(beApproximatelyEqual(to: 0.35, within: 0.1))
    expect(layer.backgroundColor) == Color.red.cgColor

    // then: the shown color continues towards red instead of snapping or heading on to blue
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    let blueMidRetarget = try shownBlue()
    expect(blueMidRetarget) > 0.01
    expect(blueMidRetarget) < blueBeforeRetarget

    // then: the layer shows red once the retargeting animation lands
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.4))
    expect(try shownBlue()).to(beApproximatelyEqual(to: 0, within: 0.01))
  }

  func test_retarget_hosted_stackedAnimations_continueFromComposedValue() throws {
    // given: a hosted layer with two background color animations in flight, a long one towards blue and a short one
    // towards green added on top of it, so the layer shows the later one
    let testWindow = TestWindow()
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    layer.backgroundColor = Color.red.cgColor
    testWindow.layer.addSublayer(layer)
    CATransaction.flush()
    expect(layer.presentation()).toEventuallyNot(beNil())

    func shownColor() throws -> (blue: CGFloat, green: CGFloat) {
      let color = try layer.presentation().unwrap().backgroundColor.unwrap()
      return try (blue: blueComponent(of: color), green: greenComponent(of: color))
    }

    let toBlue = CABasicAnimation(keyPath: "backgroundColor")
    toBlue.fromValue = Color.red.cgColor
    toBlue.toValue = Color.blue.cgColor
    toBlue.duration = 1
    layer.add(toBlue, forKey: "to-blue")

    let toGreen = CABasicAnimation(keyPath: "backgroundColor")
    toGreen.fromValue = Color.red.cgColor
    toGreen.toValue = Color.green.cgColor
    toGreen.duration = 0.5
    layer.add(toGreen, forKey: "to-green")

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))

    let shownBeforeRetarget = try shownColor()
    expect(shownBeforeRetarget.green) > 0.1
    expect(shownBeforeRetarget.blue) < 0.1

    // when: retargeting the background color to yellow
    layer.retarget(keyPath: "backgroundColor", to: Color.yellow.cgColor)

    // then: both animations are replaced by one starting from the composed shown color, the later animation's, and
    // landing when the longer one would have
    expect(layer.animationKeys()) == ["backgroundColor"]
    let animation = try (layer.animation(forKey: "backgroundColor") as? CABasicAnimation).unwrap()
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    let fromColor = animation.fromValue as! CGColor // swiftlint:disable:this force_cast
    expect(try greenComponent(of: fromColor)).to(beApproximatelyEqual(to: shownBeforeRetarget.green, within: 0.1))
    expect(try blueComponent(of: fromColor)) < 0.1
    expect(animation.duration).to(beApproximatelyEqual(to: 0.85, within: 0.1))
    expect(animation.toValue as! CGColor) == Color.yellow.cgColor // swiftlint:disable:this force_cast
    expect(layer.backgroundColor) == Color.yellow.cgColor
  }

  // MARK: - Retarget, additive animations in flight

  func test_retarget_additiveAnimationInFlight_number_keepsItAndStacksDelta() throws {
    // given: a layer whose corner radius is animating additively from 0 to 20
    let layer = CALayer()
    layer.animate(keyPath: "cornerRadius", to: CGFloat(20), timing: .linear(duration: 10))
    expect(layer.cornerRadius) == 20
    expect(layer.animationKeys()) == ["cornerRadius"]

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: the model has the new value, the in-flight animation is kept as it is, and a delta from the old model value
    // decays to zero on top of it over the in-flight animation's remaining time
    expect(layer.cornerRadius) == 5
    expect(layer.animationKeys()) == ["cornerRadius", "cornerRadius-1"]
    let keptAnimation = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
    expect(keptAnimation.isAdditive) == true
    expect(keptAnimation.fromValue as? CGFloat) == -20
    expect(keptAnimation.duration) == 10
    expect(keptAnimation.timingFunction) == CAMediaTimingFunction(name: .linear)
    let deltaAnimation = try (layer.animation(forKey: "cornerRadius-1") as? CABasicAnimation).unwrap()
    expect(deltaAnimation.isAdditive) == true
    expect(deltaAnimation.fromValue as? CGFloat) == 15 // 20 - 5
    expect(deltaAnimation.toValue as? CGFloat) == 0
    expect(deltaAnimation.duration) == 10
    expect(deltaAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(deltaAnimation.fillMode) == .both
    expect(deltaAnimation.isRemovedOnCompletion) == true
  }

  func test_retarget_additiveAnimationInFlight_size_stacksDelta() throws {
    // given: a layer whose shadow offset is animating additively to (10, 10)
    let layer = CALayer()
    layer.animate(keyPath: "shadowOffset", to: CGSize(width: 10, height: 10), timing: .linear(duration: 10))

    // when: retargeting the shadow offset to (4, 2)
    layer.retarget(keyPath: "shadowOffset", to: CGSize(width: 4, height: 2))

    // then: a size delta from the old model value decays to zero on top of the kept animation
    expect(layer.shadowOffset) == CGSize(width: 4, height: 2)
    expect(layer.animationKeys()) == ["shadowOffset", "shadowOffset-1"]
    let deltaAnimation = try (layer.animation(forKey: "shadowOffset-1") as? CABasicAnimation).unwrap()
    expect(deltaAnimation.isAdditive) == true
    expect(deltaAnimation.fromValue as? CGSize) == CGSize(width: 6, height: 8)
    expect(deltaAnimation.toValue as? CGSize) == .zero
    expect(deltaAnimation.duration) == 10
  }

  func test_retarget_additiveAnimationInFlight_point_stacksDelta() throws {
    // given: a layer whose position is animating additively to (100, 100)
    let layer = CALayer()
    layer.position = CGPoint(x: 10, y: 20)
    layer.animate(keyPath: "position", to: CGPoint(x: 100, y: 100), timing: .linear(duration: 10))

    // when: retargeting the position to (40, 60)
    layer.retarget(keyPath: "position", to: CGPoint(x: 40, y: 60))

    // then: a point delta from the old model value decays to zero on top of the kept animation
    expect(layer.position) == CGPoint(x: 40, y: 60)
    expect(layer.animationKeys()) == ["position", "position-1"]
    let deltaAnimation = try (layer.animation(forKey: "position-1") as? CABasicAnimation).unwrap()
    expect(deltaAnimation.isAdditive) == true
    expect(deltaAnimation.fromValue as? CGPoint) == CGPoint(x: 60, y: 40)
    expect(deltaAnimation.toValue as? CGPoint) == .zero
    expect(deltaAnimation.duration) == 10
  }

  func test_retarget_additiveAnimationInFlight_toSameValue_isKept() throws {
    // given: a layer whose corner radius is animating additively to 20
    let layer = CALayer()
    layer.animate(keyPath: "cornerRadius", to: CGFloat(20), timing: .linear(duration: 10))

    // when: retargeting the corner radius to the value the animation lands on
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(20))

    // then: the animation already lands on the value, so nothing is stacked on it
    expect(layer.animationKeys()) == ["cornerRadius"]
    expect(layer.cornerRadius) == 20
  }

  func test_retarget_additiveAnimationInFlight_unsupportedKind_replaces() throws {
    // given: a layer with an additive animation of a color, a kind without an additive delta
    let layer = CALayer()
    layer.backgroundColor = Color.blue.cgColor
    let colorAnimation = CABasicAnimation(keyPath: "backgroundColor")
    colorAnimation.duration = 10
    colorAnimation.isAdditive = true
    layer.add(colorAnimation, forKey: "additive-color")

    // when: retargeting the background color
    layer.retarget(keyPath: "backgroundColor", to: Color.green.cgColor)

    // then: the additive animation is replaced by a non-additive one to the new color, as a non-additive one would be
    expect(layer.animationKeys()) == ["backgroundColor"]
    let animation = try (layer.animation(forKey: "backgroundColor") as? CABasicAnimation).unwrap()
    expect(animation.isAdditive) == false
    expect(animation.duration) == 10
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(animation.toValue as! CGColor) == Color.green.cgColor // swiftlint:disable:this force_cast
    expect(layer.backgroundColor) == Color.green.cgColor
  }

  func test_retarget_mixedAnimationsInFlight_replaces() throws {
    // given: a layer whose corner radius has an additive and a non-additive animation in flight
    let layer = CALayer()
    layer.cornerRadius = 20
    let additiveAnimation = CABasicAnimation(keyPath: "cornerRadius")
    additiveAnimation.duration = 10
    additiveAnimation.isAdditive = true
    layer.add(additiveAnimation, forKey: "additive")
    let replacingAnimation = CABasicAnimation(keyPath: "cornerRadius")
    replacingAnimation.duration = 3
    layer.add(replacingAnimation, forKey: "replacing")

    // when: retargeting the corner radius
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: the mix is replaced by a single non-additive animation to the new value over the longest remaining time
    expect(layer.animationKeys()) == ["cornerRadius"]
    let animation = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
    expect(animation.isAdditive) == false
    expect(animation.toValue as? CGFloat) == 5
    expect(animation.duration) == 10
    expect(layer.cornerRadius) == 5
  }

  func test_retarget_hosted_additiveAnimationInFlight_showsNoJump() throws {
    // given: a hosted layer whose corner radius is animating additively from 0 to 20
    let testWindow = TestWindow()
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    testWindow.layer.addSublayer(layer)
    CATransaction.flush()
    expect(layer.presentation()).toEventuallyNot(beNil())

    func shownRadius() throws -> CGFloat {
      try layer.presentation().unwrap().cornerRadius
    }

    layer.animate(keyPath: "cornerRadius", to: CGFloat(20), timing: .linear(duration: 0.5))
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
    let radiusBeforeRetarget = try shownRadius()
    expect(radiusBeforeRetarget) > 2

    // when: retargeting the corner radius back to zero
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(0))

    // then: once committed, the shown radius is about where it was, since the delta cancels the model change, where a
    // plain model change would have dropped it below zero
    expect(layer.cornerRadius) == 0
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
    expect(try shownRadius()).to(beApproximatelyEqual(to: radiusBeforeRetarget, within: 1.5))

    // then: it heads back to zero without dropping below it, and lands when the interrupted animation would have
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    let radiusMidRetarget = try shownRadius()
    expect(radiusMidRetarget) > 0.1
    expect(radiusMidRetarget) < radiusBeforeRetarget
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.4))
    expect(try shownRadius()).to(beApproximatelyEqual(to: 0, within: 0.1))
  }

  /// The blue component of the color in the sRGB color space.
  private func blueComponent(of color: CGColor) throws -> CGFloat {
    try sRGBComponents(of: color)[2]
  }

  /// The green component of the color in the sRGB color space.
  private func greenComponent(of color: CGColor) throws -> CGFloat {
    try sRGBComponents(of: color)[1]
  }

  private func sRGBComponents(of color: CGColor) throws -> [CGFloat] {
    let sRGB = try CGColorSpace(name: CGColorSpace.sRGB).unwrap()
    return try color.converted(to: sRGB, intent: .defaultIntent, options: nil).unwrap().components.unwrap()
  }
}
