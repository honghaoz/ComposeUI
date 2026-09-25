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
    // given: a layer with an opacity animation that ended, still on the layer as nothing has committed since
    let layer = CALayer()

    let fadeAnimation = CABasicAnimation(keyPath: "opacity")
    fadeAnimation.duration = 2
    fadeAnimation.beginTime = layer.currentTime - 5
    layer.add(fadeAnimation, forKey: "fade")

    // then: nothing is in flight
    expect(layer.remainingAnimationTime(forKeyPath: "opacity")) == nil
  }

  func test_remainingAnimationTime_endedAnimationKeptOnCompletion_assertsAndIsLeftAlone() {
    // given: a layer with a kept opacity animation that ended
    let layer = CALayer()

    let fadeAnimation = CABasicAnimation(keyPath: "opacity")
    fadeAnimation.duration = 2
    fadeAnimation.beginTime = layer.currentTime - 5
    fadeAnimation.isRemovedOnCompletion = false
    layer.add(fadeAnimation, forKey: "fade")

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: reading the remaining animation time
    let remainingTime = layer.remainingAnimationTime(forKeyPath: "opacity")

    // then: nothing is in flight, and it asserts but leaves the animation alone
    expect(remainingTime) == nil
    expect(assertionMessages) == ["animation \"fade\" of \"opacity\" is kept with isRemovedOnCompletion off, which isn't supported"]
    expect(layer.animationKeys()) == ["fade"]
  }

  func test_remainingAnimationTime_pausedAnimation_pastItsDuration() throws {
    // given: a layer with a paused opacity animation that began longer ago than its duration
    let layer = CALayer()
    let fadeAnimation = CABasicAnimation(keyPath: "opacity")
    fadeAnimation.fromValue = Float(1)
    fadeAnimation.toValue = Float(0)
    fadeAnimation.duration = 2
    fadeAnimation.speed = 0
    fadeAnimation.beginTime = layer.currentTime - 5
    layer.add(fadeAnimation, forKey: "fade")

    // then: it hasn't ended, its time is frozen, so it still counts its duration
    expect(layer.remainingAnimationTime(forKeyPath: "opacity")) == 2

    // when: retargeting the opacity
    layer.retarget(keyPath: "opacity", to: Float(0.5))

    // then: the frozen animation isn't taken for an ended one, which would be skipped, it is replaced like any in-flight
    // animation
    expect(layer.animationKeys()) == ["opacity"]
    let animation = try (layer.animation(forKey: "opacity") as? CABasicAnimation).unwrap()
    expect(animation.toValue as? Float) == 0.5
    expect(animation.duration) == 2
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
    let beginTime = try layer.animation(forKey: "fade").unwrap().beginTime
    expect(beginTime) > 0

    // then: the time to the animation's end remains, measured from its begin time since the run loop's wait isn't exact
    let remainingTime = try layer.remainingAnimationTime(forKeyPath: "opacity").unwrap()
    expect(remainingTime).to(beApproximatelyEqual(to: beginTime + 2 - layer.currentTime, within: 0.02))
    expect(remainingTime) < 2
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

  func test_retarget_endedAnimation_isSkipped() {
    // given: a layer whose corner radius animation ended, still on the layer as nothing has committed since
    let layer = CALayer()
    let endedAnimation = CABasicAnimation(keyPath: "cornerRadius")
    endedAnimation.fromValue = CGFloat(0)
    endedAnimation.toValue = CGFloat(20)
    endedAnimation.duration = 10
    endedAnimation.beginTime = layer.currentTime - 20
    layer.add(endedAnimation, forKey: "ended")

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: the ended animation isn't in flight, so the value is set directly, and the animation is left for Core
    // Animation to remove
    expect(layer.animationKeys()) == ["ended"]
    expect(layer.cornerRadius) == 5
  }

  func test_retarget_endedAnimationKeptOnCompletion_assertsAndIsRemoved() {
    // given: a layer with a kept corner radius animation that ended, holding its end value with a forwards fill
    let layer = CALayer()
    let keptAnimation = CABasicAnimation(keyPath: "cornerRadius")
    keptAnimation.fromValue = CGFloat(0)
    keptAnimation.toValue = CGFloat(20)
    keptAnimation.duration = 10
    keptAnimation.beginTime = layer.currentTime - 20
    keptAnimation.isRemovedOnCompletion = false
    keptAnimation.fillMode = .forwards
    layer.add(keptAnimation, forKey: "kept")

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: it asserts, and removes the kept animation so the new value shows
    expect(assertionMessages) == ["animation \"kept\" of \"cornerRadius\" is kept with isRemovedOnCompletion off, which isn't supported"]
    expect(layer.animationKeys()) == nil
    expect(layer.cornerRadius) == 5
  }

  func test_retarget_endedAnimation_isSkippedNextToAReplacedOne() throws {
    // given: a layer whose corner radius has an ended animation, still on the layer as nothing has committed since, and
    // a non-additive one in flight
    let layer = CALayer()
    let endedAnimation = CABasicAnimation(keyPath: "cornerRadius")
    endedAnimation.fromValue = CGFloat(0)
    endedAnimation.toValue = CGFloat(20)
    endedAnimation.duration = 10
    endedAnimation.beginTime = layer.currentTime - 20
    layer.add(endedAnimation, forKey: "ended")
    layer.animate(keyPath: "cornerRadius", timing: .linear(duration: 10), from: { _ in CGFloat(0) }, to: { _ in CGFloat(20) })

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: the in-flight animation is replaced by one heading to 5, and the ended one is left for Core Animation to
    // remove
    expect(Set(layer.animationKeys() ?? [])) == ["ended", "cornerRadius"]
    let animation = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
    expect(animation.isAdditive) == false
    expect(animation.toValue as? CGFloat) == 5
    expect(layer.cornerRadius) == 5
  }

  func test_retarget_endedAnimation_isSkippedNextToAnInFlightOne() {
    // given: a layer whose corner radius has an ended animation, still on the layer as nothing has committed since, and
    // an additive one in flight
    let layer = CALayer()
    let endedAnimation = CABasicAnimation(keyPath: "cornerRadius")
    endedAnimation.fromValue = CGFloat(0)
    endedAnimation.toValue = CGFloat(20)
    endedAnimation.duration = 10
    endedAnimation.beginTime = layer.currentTime - 20
    layer.add(endedAnimation, forKey: "ended")
    layer.animate(keyPath: "cornerRadius", to: CGFloat(20), timing: .linear(duration: 10))

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: the in-flight animation is folded into a glide as if it were alone, and the ended one is left for Core
    // Animation to remove
    expect(Set(layer.animationKeys() ?? [])) == ["ended", "cornerRadius"]
    expect((layer.animation(forKey: "cornerRadius") as? CABasicAnimation)?.fromValue as? CGFloat) == -5
    expect(layer.cornerRadius) == 5
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
    let interruptedBeginTime = try layer.animation(forKey: "backgroundColor").unwrap().beginTime

    // when: retargeting the background color back to red
    layer.retarget(keyPath: "backgroundColor", to: Color.red.cgColor)
    let retargetTime = layer.currentTime

    // then: the retargeting animation starts from the shown color and lands when the interrupted one would have
    let animation = try (layer.animation(forKey: "backgroundColor") as? CABasicAnimation).unwrap()
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(try blueComponent(of: animation.fromValue as! CGColor)).to(beApproximatelyEqual(to: blueBeforeRetarget, within: 0.1)) // swiftlint:disable:this force_cast
    expect(animation.duration).to(beApproximatelyEqual(to: interruptedBeginTime + 0.5 - retargetTime, within: 0.02))
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
    let toBlueBeginTime = try layer.animation(forKey: "to-blue").unwrap().beginTime

    // when: retargeting the background color to yellow
    layer.retarget(keyPath: "backgroundColor", to: Color.yellow.cgColor)
    let retargetTime = layer.currentTime

    // then: both animations are replaced by one starting from the composed shown color, the later animation's, and
    // landing when the longer one would have
    expect(layer.animationKeys()) == ["backgroundColor"]
    let animation = try (layer.animation(forKey: "backgroundColor") as? CABasicAnimation).unwrap()
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    let fromColor = animation.fromValue as! CGColor // swiftlint:disable:this force_cast
    expect(try greenComponent(of: fromColor)).to(beApproximatelyEqual(to: shownBeforeRetarget.green, within: 0.1))
    expect(try blueComponent(of: fromColor)) < 0.1
    expect(animation.duration).to(beApproximatelyEqual(to: toBlueBeginTime + 1 - retargetTime, within: 0.02))
    expect(animation.toValue as! CGColor) == Color.yellow.cgColor // swiftlint:disable:this force_cast
    expect(layer.backgroundColor) == Color.yellow.cgColor
  }

  // MARK: - Retarget, additive animations in flight

  func test_retarget_additiveAnimationInFlight_number_foldsIntoOneGlideFromTheShownValue() throws {
    // given: a layer whose corner radius is animating additively from 0 to 20, which hasn't begun, so it shows 0
    let layer = CALayer()
    layer.animate(keyPath: "cornerRadius", to: CGFloat(20), timing: .linear(duration: 10))
    expect(layer.cornerRadius) == 20
    expect(layer.animationKeys()) == ["cornerRadius"]

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: the model has the new value, and the animation is replaced by one additive ease-out from the shown radius,
    // 5 below the new one, over the animation's remaining time
    expect(layer.cornerRadius) == 5
    expect(layer.animationKeys()) == ["cornerRadius"]
    let glide = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
    expect(glide.isAdditive) == true
    expect(glide.fromValue as? CGFloat) == -5
    expect(glide.toValue as? CGFloat) == 0
    expect(glide.duration) == 10
    expect(glide.beginTime) == 0
    expect(glide.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(glide.fillMode) == .both
    expect(glide.isRemovedOnCompletion) == true
  }

  func test_retarget_additiveAnimationInFlight_size_foldsEachComponent() throws {
    // given: a layer whose shadow offset is animating additively from zero to (10, 10), which hasn't begun
    let layer = CALayer()
    layer.shadowOffset = .zero
    layer.animate(keyPath: "shadowOffset", to: CGSize(width: 10, height: 10), timing: .linear(duration: 10))

    // when: retargeting the shadow offset to (4, 2)
    layer.retarget(keyPath: "shadowOffset", to: CGSize(width: 4, height: 2))

    // then: the glide starts from the shown offset, zero, which is (-4, -2) from the new one
    expect(layer.shadowOffset) == CGSize(width: 4, height: 2)
    expect(layer.animationKeys()) == ["shadowOffset"]
    let glide = try (layer.animation(forKey: "shadowOffset") as? CABasicAnimation).unwrap()
    expect(glide.isAdditive) == true
    expect(glide.fromValue as? CGSize) == CGSize(width: -4, height: -2)
    expect(glide.toValue as? CGSize) == .zero
    expect(glide.duration) == 10
  }

  func test_retarget_additiveAnimationInFlight_point_foldsEachComponent() throws {
    // given: a layer at (10, 20) whose position is animating additively to (100, 100), which hasn't begun
    let layer = CALayer()
    layer.position = CGPoint(x: 10, y: 20)
    layer.animate(keyPath: "position", to: CGPoint(x: 100, y: 100), timing: .linear(duration: 10))

    // when: retargeting the position to (40, 60)
    layer.retarget(keyPath: "position", to: CGPoint(x: 40, y: 60))

    // then: the glide starts from the shown position, (10, 20), which is (-30, -40) from the new one
    expect(layer.position) == CGPoint(x: 40, y: 60)
    expect(layer.animationKeys()) == ["position"]
    let glide = try (layer.animation(forKey: "position") as? CABasicAnimation).unwrap()
    expect(glide.isAdditive) == true
    expect(glide.fromValue as? CGPoint) == CGPoint(x: -30, y: -40)
    expect(glide.toValue as? CGPoint) == .zero
    expect(glide.duration) == 10
  }

  func test_retarget_componentKeyPath_viewBackedLayer() throws {
    // given: a view-backed layer in a test window, whose position's x is animating additively to 250, which hasn't begun
    let testWindow = TestWindow()
    let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    #if os(macOS)
    view.wantsLayer = true
    #endif
    testWindow.contentView().addSubview(view)
    let layer = view.layer()
    let shownX = layer.position.x
    layer.animate(keyPath: "position.x", to: CGFloat(250), timing: .linear(duration: 10))

    // when: retargeting the position's x to 180
    layer.retarget(keyPath: "position.x", to: CGFloat(180))

    // then: the component is set, the view's frame follows the layer's, and the animation folds into one glide from the
    // shown x
    expect(layer.position.x) == 180
    expect(view.frame) == layer.frame
    expect(layer.animationKeys()) == ["position.x"]
    let glide = try (layer.animation(forKey: "position.x") as? CABasicAnimation).unwrap()
    expect(glide.isAdditive) == true
    expect(glide.fromValue as? CGFloat) == shownX - 180
    expect(glide.toValue as? CGFloat) == 0
  }

  func test_retarget_additiveAnimationInFlight_committedAnimation_foldsTheValueItAddsNow() throws {
    // given: a layer whose corner radius has animated additively from 0 to 20 for 3 of 10 seconds, so it shows 6
    let layer = CALayer()
    layer.cornerRadius = 20
    let inFlightAnimation = CABasicAnimation(keyPath: "cornerRadius")
    inFlightAnimation.fromValue = CGFloat(-20)
    inFlightAnimation.toValue = CGFloat(0)
    inFlightAnimation.isAdditive = true
    inFlightAnimation.duration = 10
    inFlightAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
    inFlightAnimation.beginTime = layer.currentTime - 3
    layer.add(inFlightAnimation, forKey: "in-flight")

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))
    let retargetTime = layer.currentTime

    // then: the animation is replaced by a glide from the shown radius, 1 above the new one, so the layer still shows 6,
    // and the glide lands when the animation would have, 7 seconds later
    expect(layer.animationKeys()) == ["cornerRadius"]
    let glide = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
    expect(try (glide.fromValue as? CGFloat).unwrap()).to(beApproximatelyEqual(to: 1, within: 0.01))
    expect(glide.toValue as? CGFloat) == 0
    expect(glide.duration).to(beApproximatelyEqual(to: inFlightAnimation.beginTime + 10 - retargetTime, within: 0.01))
    expect(glide.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(try layer.predictedValue(forKeyPath: "cornerRadius", at: retargetTime, scalar: numberScalar))
      .to(beApproximatelyEqual(to: 6, within: 0.01))
  }

  func test_retarget_additiveAnimationInFlight_scheduledWithBackwardsFill_foldsTheOffsetItHolds() throws {
    // given: a layer whose corner radius has an additive animation scheduled a second ahead, holding its offset of -20
    // until then with a backwards fill, so it shows 0
    let layer = CALayer()
    layer.cornerRadius = 20
    let inFlightAnimation = CABasicAnimation(keyPath: "cornerRadius")
    inFlightAnimation.fromValue = CGFloat(-20)
    inFlightAnimation.toValue = CGFloat(0)
    inFlightAnimation.isAdditive = true
    inFlightAnimation.duration = 10
    inFlightAnimation.beginTime = layer.currentTime + 1
    inFlightAnimation.fillMode = .backwards
    layer.add(inFlightAnimation, forKey: "in-flight")

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))
    let retargetTime = layer.currentTime

    // then: the glide starts from the shown radius, 5 below the new one, and lands when the scheduled animation would
    // have, after its delay and duration
    expect(layer.animationKeys()) == ["cornerRadius"]
    let glide = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
    expect(glide.fromValue as? CGFloat) == -5
    expect(glide.duration).to(beApproximatelyEqual(to: inFlightAnimation.beginTime + 10 - retargetTime, within: 0.01))
  }

  func test_retarget_additiveAnimationsInFlight_foldIntoOneGlide() throws {
    // given: a layer whose corner radius has two additive animations in flight on different timelines, pulling opposite
    // ways: one half way through -20 to 0 over 10 seconds, adding -10, and one a quarter through 8 to 0 over 4 seconds,
    // adding 6. the layer shows 20 - 10 + 6 = 16
    let layer = CALayer()
    layer.cornerRadius = 20
    for (offset, duration, elapsed) in [(CGFloat(-20), 10.0, 5.0), (CGFloat(8), 4.0, 1.0)] {
      let inFlightAnimation = CABasicAnimation(keyPath: "cornerRadius")
      inFlightAnimation.fromValue = offset
      inFlightAnimation.toValue = CGFloat(0)
      inFlightAnimation.isAdditive = true
      inFlightAnimation.duration = duration
      inFlightAnimation.beginTime = layer.currentTime - elapsed
      layer.add(inFlightAnimation, forKey: "in-flight-\(offset)")
    }

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: both animations are folded into one glide from the shown radius, 11 above the new one, over the longer
    // remaining time
    expect(layer.animationKeys()) == ["cornerRadius"]
    let glide = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
    expect(try (glide.fromValue as? CGFloat).unwrap()).to(beApproximatelyEqual(to: 11, within: 0.01))
    expect(glide.duration).to(beApproximatelyEqual(to: 5, within: 0.01))
    expect(layer.cornerRadius) == 5
  }

  func test_retarget_additiveAnimationInFlight_repeatedly_keepsOneGlide() throws {
    // given: a layer whose corner radius is animating additively from 0 to 20, which hasn't begun
    let layer = CALayer()
    layer.animate(keyPath: "cornerRadius", to: CGFloat(20), timing: .linear(duration: 10))

    // when: retargeting the corner radius to a new value ten times while the animation is in flight
    for radius in [5, 12, 3, 18, 7, 1, 14, 9, 16, 2] {
      let shownBefore = try layer.predictedValue(forKeyPath: "cornerRadius", at: layer.currentTime, scalar: numberScalar)
      layer.retarget(keyPath: "cornerRadius", to: CGFloat(radius))

      // then: the earlier glide is folded into the new one, so one glide is all there is, and the shown radius is unchanged
      expect(layer.animationKeys()) == ["cornerRadius"]
      expect(try layer.predictedValue(forKeyPath: "cornerRadius", at: layer.currentTime, scalar: numberScalar))
        .to(beApproximatelyEqual(to: shownBefore, within: 1e-9))
    }

    // then: nothing has begun, so the glide starts from the radius shown all along, 0, 2 below the last value
    let glide = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
    expect(glide.fromValue as? CGFloat) == -2
    expect(glide.duration) == 10
    expect(layer.cornerRadius) == 2
  }

  func test_retarget_additiveAnimationInFlight_toTheShownValue_setsItDirectly() throws {
    // given: a layer whose corner radius is animating additively from 0 to 20, which hasn't begun, so it shows 0
    let layer = CALayer()
    layer.animate(keyPath: "cornerRadius", to: CGFloat(20), timing: .linear(duration: 10))

    // when: retargeting the corner radius back to 0
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(0))

    // then: the layer already shows the new value, so the animation is removed and nothing glides
    expect(layer.animationKeys()) == nil
    expect(layer.cornerRadius) == 0
  }

  func test_retarget_additiveSpringAnimationInFlight_keepsItAndGlidesTheJump() throws {
    // given: a layer whose corner radius is springing additively to 20, with a delegate on the spring
    let layer = CALayer()
    let delegate = AnimationDelegate()
    layer.animate(keyPath: "cornerRadius", to: CGFloat(20), timing: .spring(dampingRatio: 0.5, response: 0.5)) { $0.delegate = delegate }
    let spring = try (layer.animation(forKey: "cornerRadius") as? CASpringAnimation).unwrap()

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: the spring keeps going as it is, delegate included, so its momentum carries on and it lands on the new model
    // value on its own. a glide stacked on it covers the jump the model change would show, 20 - 5, over its remaining time
    expect(layer.cornerRadius) == 5
    expect(layer.animationKeys()) == ["cornerRadius", "cornerRadius-1"]
    let keptSpring = try (layer.animation(forKey: "cornerRadius") as? CASpringAnimation).unwrap()
    expect(keptSpring.fromValue as? CGFloat) == -20
    expect(keptSpring.damping) == spring.damping
    expect(keptSpring.delegate) === delegate

    let glide = try (layer.animation(forKey: "cornerRadius-1") as? CABasicAnimation).unwrap()
    expect(glide is CASpringAnimation) == false
    expect(glide.isAdditive) == true
    expect(glide.fromValue as? CGFloat) == 15
    expect(glide.toValue as? CGFloat) == 0
    expect(glide.duration) == spring.duration
    expect(glide.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(glide.delegate).to(beNil())
  }

  func test_retarget_additiveSpringAnimationInFlight_notLandingOnTheModel_isFolded() throws {
    // given: a layer whose corner radius has an additive spring from -20 to 2, which ends 2 above the model value
    let layer = CALayer()
    layer.cornerRadius = 20
    let spring = CASpringAnimation(keyPath: "cornerRadius")
    spring.fromValue = CGFloat(-20)
    spring.toValue = CGFloat(2)
    spring.isAdditive = true
    spring.duration = 10
    layer.add(spring, forKey: "spring")

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: the spring wouldn't land on the new model value on its own, so it is folded like any other animation, into a
    // glide from the shown radius, 0, 5 below the new one
    expect(layer.animationKeys()) == ["cornerRadius"]
    let glide = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
    expect(glide is CASpringAnimation) == false
    expect(glide.fromValue as? CGFloat) == -5
  }

  func test_retarget_additiveSpringAnimationInFlight_repeatedly_keepsTheSpringAndOneGlide() throws {
    // given: a layer whose corner radius is springing additively to 20 on a lightly damped spring
    let layer = CALayer()
    layer.cornerRadius = 20
    let spring = CASpringAnimation(keyPath: "cornerRadius")
    spring.fromValue = CGFloat(-20)
    spring.toValue = CGFloat(0)
    spring.isAdditive = true
    spring.mass = 1
    spring.stiffness = 100
    spring.damping = 2
    spring.duration = 3
    spring.beginTime = layer.currentTime - 0.14
    layer.add(spring, forKey: "spring")

    // when: retargeting the corner radius 60 times while the spring swings, back and forth between 12 and 16, as a
    // non-animated update every frame would
    for step in 1 ... 60 {
      layer.retarget(keyPath: "cornerRadius", to: CGFloat(step.isMultiple(of: 2) ? 12 : 16))

      // then: the spring and one glide are all there is, each glide folded into the next
      expect(Set(layer.animationKeys() ?? []), "\(step)") == ["spring", "cornerRadius"]
    }
  }

  func test_retarget_pausedAdditiveAnimationInFlight_foldsItIntoARunningGlide() throws {
    // given: layers whose corner radius has a paused additive animation, a basic one or a spring, frozen at its offset
    // of -20, so it shows 0
    let kinds: [(String, () -> CABasicAnimation)] = [
      ("basic", { CABasicAnimation(keyPath: "cornerRadius") }),
      ("spring", { CASpringAnimation(keyPath: "cornerRadius") }),
    ]
    for (kind, makeAnimation) in kinds {
      let layer = CALayer()
      layer.cornerRadius = 20
      let pausedAnimation = makeAnimation()
      pausedAnimation.fromValue = CGFloat(-20)
      pausedAnimation.toValue = CGFloat(0)
      pausedAnimation.isAdditive = true
      pausedAnimation.duration = 10
      pausedAnimation.speed = 0
      layer.add(pausedAnimation, forKey: "paused")

      // when: retargeting the corner radius to 5
      layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

      // then: the paused animation is folded like any other, as a paused non-additive one is replaced, and a paused
      // spring has no momentum to keep: a running glide starts from the shown radius, 5 below the new one, and lands on
      // it over the paused animation's duration
      expect(layer.animationKeys(), kind) == ["cornerRadius"]
      let glide = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
      expect(glide is CASpringAnimation, kind) == false
      expect(glide.speed, kind) == 1
      expect(glide.fromValue as? CGFloat, kind) == -5
      expect(glide.toValue as? CGFloat, kind) == 0
      expect(glide.duration, kind) == 10
      expect(layer.cornerRadius, kind) == 5
    }
  }

  func test_retarget_additiveAnimationInFlight_unevaluableShape_replaces() throws {
    // given: additive animations whose value at a time can't be computed
    let shapes: [(String, (CALayer) -> CAPropertyAnimation)] = [
      ("keyframe", { _ in CAKeyframeAnimation(keyPath: "cornerRadius") }),
      ("by value", { _ in
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.byValue = CGFloat(-20)
        return animation
      }),
      ("repeat count", { _ in
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.fromValue = CGFloat(-20)
        animation.toValue = CGFloat(0)
        animation.repeatCount = 2
        return animation
      }),
      ("repeat duration", { _ in
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.fromValue = CGFloat(-20)
        animation.toValue = CGFloat(0)
        animation.repeatDuration = 20
        return animation
      }),
      ("autoreverses", { _ in
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.fromValue = CGFloat(-20)
        animation.toValue = CGFloat(0)
        animation.autoreverses = true
        return animation
      }),
      ("time offset", { _ in
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.fromValue = CGFloat(-20)
        animation.toValue = CGFloat(0)
        animation.timeOffset = 1
        return animation
      }),
      ("scheduled without a backwards fill", { layer in
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.fromValue = CGFloat(-20)
        animation.toValue = CGFloat(0)
        animation.beginTime = layer.currentTime + 1
        return animation
      }),
      ("no from value", { _ in
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.toValue = CGFloat(0)
        return animation
      }),
      ("from value of another kind", { _ in
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.fromValue = CGSize(width: -20, height: 0)
        animation.toValue = CGFloat(0)
        return animation
      }),
      ("no to value", { _ in
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.fromValue = CGFloat(-20)
        return animation
      }),
      ("to value of another kind", { _ in
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.fromValue = CGFloat(-20)
        animation.toValue = CGSize.zero
        return animation
      }),
    ]

    for (shape, makeAnimation) in shapes {
      let layer = CALayer()
      layer.cornerRadius = 20
      let inFlightAnimation = makeAnimation(layer)
      inFlightAnimation.isAdditive = true
      inFlightAnimation.duration = 10
      layer.add(inFlightAnimation, forKey: "in-flight")

      // when: retargeting the corner radius to 5
      layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

      // then: the value the animation shows can't be computed to glide from, so it is replaced by one non-additive
      // animation from the shown value to the new one, as a mix with non-additive animations is
      expect(layer.animationKeys(), shape) == ["cornerRadius"]
      let animation = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
      expect(animation.isAdditive, shape) == false
      expect(animation.toValue as? CGFloat, shape) == 5
      expect(animation.timingFunction, shape) == CAMediaTimingFunction(name: .easeOut)
      expect(layer.cornerRadius, shape) == 5
    }
  }

  func test_retarget_additiveAnimationInFlight_toSameValue_isKept() throws {
    // given: a layer whose corner radius is animating additively to 20
    let layer = CALayer()
    layer.animate(keyPath: "cornerRadius", to: CGFloat(20), timing: .linear(duration: 10))

    // when: retargeting the corner radius to the value the animation lands on
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(20))

    // then: the animation already lands on the value, so it is left as it is
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

  func test_retarget_additiveAnimationInFlight_clampedOpacity_replaces() throws {
    // given: layers whose opacity and shadow opacity are fading in additively, as an opacity transition does
    for keyPath in ["opacity", "shadowOpacity"] {
      let layer = CALayer()
      layer.setValue(Float(1), forKeyPath: keyPath)
      let inFlightAnimation = CABasicAnimation(keyPath: keyPath)
      inFlightAnimation.fromValue = Float(-1)
      inFlightAnimation.toValue = Float(0)
      inFlightAnimation.isAdditive = true
      inFlightAnimation.duration = 10
      layer.add(inFlightAnimation, forKey: "fade")

      // when: retargeting the opacity back to zero
      layer.retarget(keyPath: keyPath, to: Float(0))

      // then: the render server clamps the opacity after each animation, so an additive glide stacked with other
      // animations wouldn't compose on screen: the fade is replaced by one non-additive animation to zero instead
      expect(layer.animationKeys(), keyPath) == [keyPath]
      let animation = try (layer.animation(forKey: keyPath) as? CABasicAnimation).unwrap()
      expect(animation.isAdditive, keyPath) == false
      expect(animation.toValue as? Float, keyPath) == 0
      expect(animation.duration, keyPath) == 10
      expect(layer.value(forKeyPath: keyPath) as? Float, keyPath) == 0
    }
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

    // then: the model is zero, and the glide starts from the shown radius: no jump
    expect(layer.cornerRadius) == 0
    expect(try layer.predictedValue(forKeyPath: "cornerRadius", at: layer.currentTime, scalar: numberScalar))
      .to(beApproximatelyEqual(to: radiusBeforeRetarget, within: 0.5))

    // then: whenever the run loop lets the test look, the shown radius is where the animations put it, below where it
    // was and not below zero, until it lands on zero when the interrupted animation would have. the run loop's timing
    // isn't reliable, so the test checks each look against the animations' own value for that time instead of
    // expecting a value at a fixed delay
    var landed = false
    for _ in 0 ..< 40 where !landed {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
      let shown = try shownRadius()
      let predicted = try layer.predictedValue(forKeyPath: "cornerRadius", at: layer.currentTime, scalar: numberScalar)
      expect(shown).to(beApproximatelyEqual(to: predicted, within: 0.5))
      expect(shown) <= radiusBeforeRetarget + 0.5
      expect(shown) >= -0.5
      landed = shown < 0.1
    }
    expect(landed) == true
  }

  func test_retarget_hosted_additiveSpringAnimationInFlight_lateInItsMotion_landsWithoutOvershoot() throws {
    // given: a hosted layer whose corner radius has been springing additively from 0 to 20 for 0.4 seconds, so it is
    // close to 20, with a small swing past it still to come
    let testWindow = TestWindow()
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    testWindow.layer.addSublayer(layer)
    CATransaction.flush()
    expect(layer.presentation()).toEventuallyNot(beNil())

    func shownRadius() throws -> CGFloat {
      try layer.presentation().unwrap().cornerRadius
    }

    layer.animate(keyPath: "cornerRadius", to: CGFloat(20), timing: .spring())
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.4))
    expect(try shownRadius()) > 15

    // when: retargeting the corner radius to -20
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(-20))

    // then: whenever the run loop lets the test look, the shown radius isn't past -20: the spring keeps its small swing,
    // which isn't magnified into an overshoot of the new value, and the radius lands on -20
    var landed = false
    for _ in 0 ..< 100 where !landed {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
      let shown = try shownRadius()
      expect(shown) >= -20.5
      landed = abs(shown + 20) < 0.01
    }
    expect(landed) == true
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

/// An animation delegate, to check that a kept animation keeps it and a new one doesn't get it.
private final class AnimationDelegate: NSObject, CAAnimationDelegate {}
