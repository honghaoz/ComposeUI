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

  func test_retarget_endedAnimationKeptOnTheLayer_isRemoved() throws {
    // given: a layer whose corner radius animation ended but stays on the layer, holding its end value with a forwards fill
    let layer = CALayer()
    let endedAnimation = CABasicAnimation(keyPath: "cornerRadius")
    endedAnimation.fromValue = CGFloat(0)
    endedAnimation.toValue = CGFloat(20)
    endedAnimation.duration = 10
    endedAnimation.beginTime = layer.currentTime - 20
    endedAnimation.isRemovedOnCompletion = false
    endedAnimation.fillMode = .forwards
    layer.add(endedAnimation, forKey: "ended")

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: the ended animation is removed, or it would keep showing 20 over the new value, which is set directly
    expect(layer.animationKeys()) == nil
    expect(layer.cornerRadius) == 5
  }

  func test_retarget_endedAnimationKeptOnTheLayer_isRemovedNextToAnInFlightOne() throws {
    // given: a layer whose corner radius has an ended animation kept on it and an additive one in flight
    let layer = CALayer()
    let endedAnimation = CABasicAnimation(keyPath: "cornerRadius")
    endedAnimation.fromValue = CGFloat(0)
    endedAnimation.toValue = CGFloat(20)
    endedAnimation.duration = 10
    endedAnimation.beginTime = layer.currentTime - 20
    endedAnimation.isRemovedOnCompletion = false
    endedAnimation.fillMode = .forwards
    layer.add(endedAnimation, forKey: "ended")
    layer.animate(keyPath: "cornerRadius", to: CGFloat(20), timing: .linear(duration: 10))

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: the ended animation is removed, and the in-flight one is retargeted as if it were alone
    expect(layer.animationKeys()) == ["cornerRadius", "cornerRadius-1"]
    expect((layer.animation(forKey: "cornerRadius-1") as? CABasicAnimation)?.fromValue as? CGFloat) == 15
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

  func test_retarget_additiveAnimationInFlight_number_keepsItAndStacksAScaledCopy() throws {
    // given: a layer whose corner radius is animating additively from 0 to 20, with a delegate on the animation
    let layer = CALayer()
    let delegate = AnimationDelegate()
    layer.animate(keyPath: "cornerRadius", to: CGFloat(20), timing: .linear(duration: 10)) { $0.delegate = delegate }
    expect(layer.cornerRadius) == 20
    expect(layer.animationKeys()) == ["cornerRadius"]

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: the model has the new value and the in-flight animation is kept as it is
    expect(layer.cornerRadius) == 5
    expect(layer.animationKeys()) == ["cornerRadius", "cornerRadius-1"]
    let keptAnimation = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
    expect(keptAnimation.isAdditive) == true
    expect(keptAnimation.fromValue as? CGFloat) == -20
    expect(keptAnimation.duration) == 10
    expect(keptAnimation.timingFunction) == CAMediaTimingFunction(name: .linear)

    // then: a copy of it is stacked on top, scaled to the jump the model change would show, 20 - 5, from its whole
    // offset since it hasn't begun, so the two add up to a glide to 5 along the animation's own curve
    let correction = try (layer.animation(forKey: "cornerRadius-1") as? CABasicAnimation).unwrap()
    expect(correction.isAdditive) == true
    expect(correction.fromValue as? CGFloat) == 15
    expect(correction.toValue as? CGFloat) == 0
    expect(correction.duration) == 10
    expect(correction.beginTime) == 0
    expect(correction.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(correction.fillMode) == .both
    expect(correction.isRemovedOnCompletion) == true
    expect(correction.delegate).to(beNil())
  }

  func test_retarget_additiveAnimationInFlight_size_stacksAScaledCopy() throws {
    // given: a layer whose shadow offset is animating additively to (10, 10)
    let layer = CALayer()
    layer.animate(keyPath: "shadowOffset", to: CGSize(width: 10, height: 10), timing: .linear(duration: 10))

    // when: retargeting the shadow offset to (4, 2)
    layer.retarget(keyPath: "shadowOffset", to: CGSize(width: 4, height: 2))

    // then: a copy of the kept animation is stacked on it, scaled per component to the jump, (6, 8)
    expect(layer.shadowOffset) == CGSize(width: 4, height: 2)
    expect(layer.animationKeys()) == ["shadowOffset", "shadowOffset-1"]
    let correction = try (layer.animation(forKey: "shadowOffset-1") as? CABasicAnimation).unwrap()
    expect(correction.isAdditive) == true
    expect(correction.fromValue as? CGSize) == CGSize(width: 6, height: 8)
    expect(correction.toValue as? CGSize) == .zero
    expect(correction.duration) == 10
    expect(correction.timingFunction) == CAMediaTimingFunction(name: .linear)
  }

  func test_retarget_additiveAnimationInFlight_point_stacksAScaledCopy() throws {
    // given: a layer whose position is animating additively to (100, 100)
    let layer = CALayer()
    layer.position = CGPoint(x: 10, y: 20)
    layer.animate(keyPath: "position", to: CGPoint(x: 100, y: 100), timing: .linear(duration: 10))

    // when: retargeting the position to (40, 60)
    layer.retarget(keyPath: "position", to: CGPoint(x: 40, y: 60))

    // then: a copy of the kept animation is stacked on it, scaled per component to the jump, (60, 40)
    expect(layer.position) == CGPoint(x: 40, y: 60)
    expect(layer.animationKeys()) == ["position", "position-1"]
    let correction = try (layer.animation(forKey: "position-1") as? CABasicAnimation).unwrap()
    expect(correction.isAdditive) == true
    expect(correction.fromValue as? CGPoint) == CGPoint(x: 60, y: 40)
    expect(correction.toValue as? CGPoint) == .zero
    expect(correction.duration) == 10
    expect(correction.timingFunction) == CAMediaTimingFunction(name: .linear)
  }

  func test_retarget_additiveAnimationInFlight_unchangedComponent_getsNoCorrection() throws {
    // given: a layer whose shadow offset's width is animating additively, 10 wide to go, with the height still
    let layer = CALayer()
    layer.shadowOffset = CGSize(width: 10, height: 10)
    let tail = CABasicAnimation(keyPath: "shadowOffset")
    tail.fromValue = CGSize(width: -10, height: 0)
    tail.toValue = CGSize.zero
    tail.isAdditive = true
    tail.duration = 10
    layer.add(tail, forKey: "tail")

    // when: retargeting the shadow offset to (4, 10), which keeps the height
    layer.retarget(keyPath: "shadowOffset", to: CGSize(width: 4, height: 10))

    // then: the copy cancels the width's jump, and the height, which has no jump and no motion, gets no correction
    let correction = try (layer.animation(forKey: "shadowOffset") as? CABasicAnimation).unwrap()
    expect(correction.fromValue as? CGSize) == CGSize(width: 6, height: 0)
    expect(correction.timingFunction) == nil
  }

  func test_retarget_additiveAnimationInFlight_scheduledWithBackwardsFill_stacksAScaledCopy() throws {
    // given: a layer whose corner radius has an additive animation scheduled a second ahead, holding its offset until
    // then with a backwards fill
    let layer = CALayer()
    layer.cornerRadius = 20
    let tail = CABasicAnimation(keyPath: "cornerRadius")
    tail.fromValue = CGFloat(-20)
    tail.toValue = CGFloat(0)
    tail.isAdditive = true
    tail.duration = 10
    tail.beginTime = layer.currentTime + 1
    tail.fillMode = .backwards
    layer.add(tail, forKey: "tail")

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: the copy waits with the animation, worth its whole offset scaled to the jump
    let correction = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
    expect(correction.fromValue as? CGFloat) == 15
    expect(correction.beginTime) == tail.beginTime
    expect(correction.fillMode) == .backwards
  }

  func test_retarget_additiveAnimationInFlight_committedAnimation_scalesTheMotionLeft() throws {
    // given: a layer whose corner radius has animated additively from 0 to 20 for 3 of 10 seconds: it shows 6 and the
    // animation has 14 of motion left
    let layer = CALayer()
    layer.cornerRadius = 20
    let tail = CABasicAnimation(keyPath: "cornerRadius")
    tail.fromValue = CGFloat(-20)
    tail.toValue = CGFloat(0)
    tail.isAdditive = true
    tail.duration = 10
    tail.timingFunction = CAMediaTimingFunction(name: .linear)
    tail.beginTime = layer.currentTime - 3
    layer.add(tail, forKey: "tail")

    // when: retargeting the corner radius to 5, a jump of 15
    let now = layer.currentTime
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: the copy runs on the animation's own timeline, scaled by 15 / 14 so it is worth the jump now
    let correction = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
    expect(correction.beginTime) == tail.beginTime
    expect(correction.duration) == 10
    expect(correction.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(try (correction.fromValue as? CGFloat).unwrap()).to(beApproximatelyEqual(to: 20 * 15 / 14, within: 0.01))
    expect(correction.toValue as? CGFloat) == 0

    // then: the animations add up to the shown radius now, then glide to 5 without crossing it, and land on it together
    func shownRadius(at time: TimeInterval) throws -> CGFloat {
      try layer.predictedValue(forKeyPath: "cornerRadius", at: time, scalar: numberScalar)
    }
    expect(try shownRadius(at: now)).to(beApproximatelyEqual(to: 6, within: 0.01))
    var previous = try shownRadius(at: now)
    for step in 1 ... 70 {
      let radius = try shownRadius(at: now + 0.1 * TimeInterval(step))
      expect(radius) <= previous + 1e-9
      expect(radius) >= 5 - 1e-9
      previous = radius
    }
    expect(try shownRadius(at: now + 7)).to(beApproximatelyEqual(to: 5, within: 1e-9))
  }

  func test_retarget_additiveAnimationsInFlight_scalesEachByTheSameFactor() throws {
    // given: a layer whose corner radius has two additive animations in flight, with 20 and 10 of motion left
    let layer = CALayer()
    layer.cornerRadius = 20
    for offset in [CGFloat(-20), CGFloat(-10)] {
      let tail = CABasicAnimation(keyPath: "cornerRadius")
      tail.fromValue = offset
      tail.toValue = CGFloat(0)
      tail.isAdditive = true
      tail.duration = 10
      layer.add(tail, forKey: "tail-\(offset)")
    }

    // when: retargeting the corner radius to 5, a jump of 15 against 30 of motion left
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: each animation gets a copy scaled by the same factor, 15 / 30, so the copies add up to the jump
    expect(layer.animationKeys()) == ["tail--20.0", "tail--10.0", "cornerRadius", "cornerRadius-1"]
    expect((layer.animation(forKey: "cornerRadius") as? CABasicAnimation)?.fromValue as? CGFloat) == 10
    expect((layer.animation(forKey: "cornerRadius-1") as? CABasicAnimation)?.fromValue as? CGFloat) == 5
  }

  func test_retarget_additiveSpringAnimationInFlight_stacksAScaledSpring() throws {
    // given: a layer whose corner radius is animating additively to 20 with a spring
    let layer = CALayer()
    layer.animate(keyPath: "cornerRadius", to: CGFloat(20), timing: .spring(dampingRatio: 0.5, response: 0.5))
    let tail = try (layer.animation(forKey: "cornerRadius") as? CASpringAnimation).unwrap()

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: the copy is a spring with the animation's parameters, so the bounce carries over, scaled to the jump
    let correction = try (layer.animation(forKey: "cornerRadius-1") as? CASpringAnimation).unwrap()
    expect(correction.mass) == tail.mass
    expect(correction.stiffness) == tail.stiffness
    expect(correction.damping) == tail.damping
    expect(correction.initialVelocity) == tail.initialVelocity
    expect(correction.duration) == tail.duration
    expect(correction.fromValue as? CGFloat) == 15
    expect(correction.toValue as? CGFloat) == 0
  }

  func test_retarget_additiveAnimationsInFlight_noMotionLeft_easesOutTheJump() throws {
    // given: a layer whose corner radius has two additive animations in flight that cancel each other
    let layer = CALayer()
    layer.cornerRadius = 20
    for offset in [CGFloat(-10), CGFloat(10)] {
      let tail = CABasicAnimation(keyPath: "cornerRadius")
      tail.fromValue = offset
      tail.toValue = CGFloat(0)
      tail.isAdditive = true
      tail.duration = 10
      layer.add(tail, forKey: "tail-\(offset)")
    }

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: there is no motion to scale, so one correction of the jump eases out over the remaining time instead
    expect(layer.animationKeys()) == ["tail--10.0", "tail-10.0", "cornerRadius"]
    let correction = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
    expect(correction.isAdditive) == true
    expect(correction.fromValue as? CGFloat) == 15
    expect(correction.toValue as? CGFloat) == 0
    expect(correction.duration) == 10
    expect(correction.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(layer.cornerRadius) == 5
  }

  func test_retarget_additiveSpringAnimationInFlight_aboutToSwingBack_easesOutTheJump() throws {
    // given: a layer whose corner radius is animating additively with a lightly damped spring that is passing through
    // its target: little motion is left now, but the swing back is bigger
    let layer = CALayer()
    layer.cornerRadius = 20
    let tail = CASpringAnimation(keyPath: "cornerRadius")
    tail.fromValue = CGFloat(-20)
    tail.toValue = CGFloat(0)
    tail.isAdditive = true
    tail.mass = 1
    tail.stiffness = 100
    tail.damping = 2
    tail.duration = 3
    tail.beginTime = layer.currentTime - 0.14
    layer.add(tail, forKey: "tail")

    // when: retargeting the corner radius to 5
    layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

    // then: scaling the swing to the jump would amplify it, so the jump eases out on its own instead
    let correction = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
    expect(correction is CASpringAnimation) == false
    expect(correction.fromValue as? CGFloat) == 15
    expect(correction.timingFunction) == CAMediaTimingFunction(name: .easeOut)
  }

  func test_retarget_additiveAnimationInFlight_shapeWithoutMotionLeft_replaces() throws {
    // given: additive animations whose remaining motion can't be computed or doesn't end at zero
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
      ("to value not zero", { _ in
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.fromValue = CGFloat(-20)
        animation.toValue = CGFloat(2)
        return animation
      }),
    ]

    for (shape, makeAnimation) in shapes {
      let layer = CALayer()
      layer.cornerRadius = 20
      let tail = makeAnimation(layer)
      tail.isAdditive = true
      tail.duration = 10
      layer.add(tail, forKey: "tail")

      // when: retargeting the corner radius to 5
      layer.retarget(keyPath: "cornerRadius", to: CGFloat(5))

      // then: the animation can't be trusted to land on the model value, so it is replaced by one non-additive
      // animation to the new value, as a mix with non-additive animations is
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

  func test_retarget_additiveAnimationInFlight_clampedOpacity_replaces() throws {
    // given: layers whose opacity and shadow opacity are fading in additively, as an opacity transition does
    for keyPath in ["opacity", "shadowOpacity"] {
      let layer = CALayer()
      layer.setValue(Float(1), forKeyPath: keyPath)
      let tail = CABasicAnimation(keyPath: keyPath)
      tail.fromValue = Float(-1)
      tail.toValue = Float(0)
      tail.isAdditive = true
      tail.duration = 10
      layer.add(tail, forKey: "fade")

      // when: retargeting the opacity back to zero
      layer.retarget(keyPath: keyPath, to: Float(0))

      // then: the render server clamps the opacity after each animation, so a correction stacked on the fade wouldn't
      // compose on screen: the fade is replaced by one non-additive animation to zero instead
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

    // then: the model is zero, and the animations add up to the shown radius at the commit: no jump
    expect(layer.cornerRadius) == 0
    expect(try layer.predictedValue(forKeyPath: "cornerRadius", at: layer.currentTime, scalar: numberScalar))
      .to(beApproximatelyEqual(to: radiusBeforeRetarget, within: 0.5))

    // then: whenever the run loop lets the test look, the shown radius is where the animations put it, below where it
    // was and not below zero, until it lands on zero when the interrupted animation would have. the run loop's timing
    // isn't reliable, so the test checks each look against the animations' own value for that time instead of
    // expecting a value at a fixed delay. the copy ends a few milliseconds before the animation, which starts that much
    // after its recorded begin time, so the last frame can show the animation's last sliver alone
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

/// An animation delegate, to check that a copied animation doesn't keep it.
private final class AnimationDelegate: NSObject, CAAnimationDelegate {}
