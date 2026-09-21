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
