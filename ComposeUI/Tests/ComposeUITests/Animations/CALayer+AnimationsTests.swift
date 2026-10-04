//
//  CALayer+AnimationsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/25/22.
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

class CALayer_AnimationsTests: XCTestCase {

  // MARK: - animate

  func test_animateFloatingPoint() throws {
    // given: a layer hosted in a window with full opacity
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.opacity = 1.0

    // when: animating the opacity
    layer.animate(keyPath: "opacity", to: CGFloat(0.5), timing: .easeInEaseOut(duration: 1))

    // then: an additive opacity animation is added and the model value is set
    let animation = try (layer.animation(forKey: "opacity") as? CABasicAnimation).unwrap()
    expect(animation.fromValue as? CGFloat) == 0.5 // current (1.0) - target (0.5) = 0.5
    expect(animation.toValue as? CGFloat) == 0.0
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .easeInEaseOut)
    expect(animation.duration) == 1
    expect(animation.isAdditive) == true
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both
    expect(layer.opacity) == 0.5 // model value should be set
  }

  func test_animateFloatingPoint_readsCurrentValueWithoutKVC() throws {
    // given: a layer that counts KVC reads, with a corner radius
    let layer = KVCCountingLayer()
    layer.cornerRadius = 3

    // when: animating the corner radius to a value of its property type
    layer.animate(keyPath: "cornerRadius", to: CGFloat(8), timing: .easeInEaseOut(duration: 1))

    // then: an additive animation starts from the current value, read without KVC, and the model value is set
    let animation = try (layer.animation(forKey: "cornerRadius") as? CABasicAnimation).unwrap()
    expect(animation.fromValue as? CGFloat) == -5 // current (3) - target (8) = -5
    expect(animation.toValue as? CGFloat) == 0
    expect(animation.isAdditive) == true
    expect(layer.cornerRadius) == 8
    expect(layer.kvcReadCount) == 0
  }

  func test_animateCGSize() throws {
    // given: a layer hosted in a window with a bounds size
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.bounds.size = CGSize(width: 100, height: 50)

    // when: animating the bounds size
    layer.animate(keyPath: "bounds.size", to: CGSize(width: 200, height: 100), timing: .easeInEaseOut(duration: 1))

    // then: an additive bounds.size animation is added and the model value is set
    let animation = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(animation.fromValue as? CGSize) == CGSize(width: -100, height: -50) // current (100,50) - target (200,100) = (-100,-50)
    expect(animation.toValue as? CGSize) == CGSize.zero
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .easeInEaseOut)
    expect(animation.duration) == 1
    expect(animation.isAdditive) == true
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both
    expect(layer.bounds.size) == CGSize(width: 200, height: 100) // model value should be set
  }

  func test_animateCGPoint() throws {
    // given: a layer hosted in a window with a position
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.position = CGPoint(x: 50, y: 75)

    // when: animating the position
    layer.animate(keyPath: "position", to: CGPoint(x: 150, y: 200), timing: .easeInEaseOut(duration: 1))

    // then: an additive position animation is added and the model value is set
    let animation = try (layer.animation(forKey: "position") as? CABasicAnimation).unwrap()
    expect(animation.fromValue as? CGPoint) == CGPoint(x: -100, y: -125) // current (50,75) - target (150,200) = (-100,-125)
    expect(animation.toValue as? CGPoint) == CGPoint.zero
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .easeInEaseOut)
    expect(animation.duration) == 1
    expect(animation.isAdditive) == true
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both
    expect(layer.position) == CGPoint(x: 150, y: 200) // model value should be set
  }

  func test_animate() throws {
    // given: a layer hosted in a window
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.frame = testWindow.layer.bounds

    // when: animating the position with explicit from and to values
    layer.animate(
      keyPath: "position",
      timing: .easeInEaseOut(duration: 1),
      from: { _ in CGPoint(x: 100, y: 100) },
      to: { _ in CGPoint(x: 200, y: 200) }
    )

    // then: a non-additive position animation is added with the from and to values
    let animation = try (layer.animation(forKey: "position") as? CABasicAnimation).unwrap()
    expect(animation.fromValue as? CGPoint) == CGPoint(x: 100, y: 100)
    expect(animation.toValue as? CGPoint) == CGPoint(x: 200, y: 200)
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .easeInEaseOut)
    expect(animation.duration) == 1
    expect(animation.isAdditive) == false
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both
  }

  func test_animate_delayZero() throws {
    // given: a layer hosted in a window
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.frame = testWindow.layer.bounds

    // when: animating the position with a zero duration
    layer.animate(
      keyPath: "position",
      timing: .easeInEaseOut(duration: 0),
      from: { _ in CGPoint(x: 100, y: 100) },
      to: { _ in CGPoint(x: 200, y: 200) }
    )

    // then: no animation is added and the model value is set
    expect(layer.animationKeys()?.isEmpty) == nil
    expect(layer.position) == CGPoint(x: 200, y: 200)
  }

  func test_animate_delayed_schedulesAnimation() throws {
    // given: a layer with partial opacity
    let layer = CALayer()
    layer.opacity = 0.2

    // when: animating the opacity with a delay
    layer.animate(keyPath: "opacity", to: Float(1), timing: .linear(duration: 1, delay: 0.5))

    // then: the model value is set at dispatch, and the animation is scheduled in the future by the delay, holding
    // the from delta so the layer keeps rendering the old value during the delay window
    expect(layer.opacity) == 1
    let animation = try unwrap(layer.animation(forKey: "opacity") as? CABasicAnimation)
    expect(try unwrap(animation.fromValue as? Float)).to(beApproximatelyEqual(to: -0.8, within: 1e-6))
    expect(animation.toValue as? Float) == 0
    expect(animation.fillMode) == .both

    let now = layer.currentTime
    expect(animation.beginTime - now).to(beApproximatelyEqual(to: 0.5, within: 0.1))
  }

  func test_animate_zeroDuration_appliesModelImmediately() {
    // given: a layer with partial opacity
    let layer = CALayer()
    layer.opacity = 0.2

    // when: animating the opacity with a zero duration and no delay
    layer.animate(keyPath: "opacity", to: Float(1), timing: .linear(duration: 0))

    // then: a zero-duration timing without a delay applies the model value immediately
    expect(layer.opacity) == 1
    expect(layer.animationKeys()) == nil
  }

  func test_animate_delayed_zeroDuration_schedulesSnap() throws {
    // given: a layer with partial opacity
    let layer = CALayer()
    layer.opacity = 0.2

    // when: animating the opacity with a zero duration and a delay
    layer.animate(keyPath: "opacity", to: Float(1), timing: .linear(duration: 0, delay: 0.5))

    // then: a zero-duration timing with a delay is a scheduled snap: the animation holds the old value for the
    // delay window, then applies the model value as an instant change
    expect(layer.opacity) == 1
    let animation = try unwrap(layer.animation(forKey: "opacity") as? CABasicAnimation)
    expect(try unwrap(animation.fromValue as? Float)).to(beApproximatelyEqual(to: -0.8, within: 1e-6))
    expect(animation.duration).to(beApproximatelyEqual(to: 0.001, within: 1e-6))

    let now = layer.currentTime
    expect(animation.beginTime - now).to(beApproximatelyEqual(to: 0.5, within: 0.1))
  }

  func test_animate_delayed_beginTime_usesLayerTimeSpace() throws {
    // given: a layer with a doubled time speed and partial opacity
    let layer = CALayer()
    layer.speed = 2
    layer.opacity = 0.2

    // when: animating the opacity with a delay
    layer.animate(keyPath: "opacity", to: Float(1), timing: .linear(duration: 1, delay: 0.5))

    // then: the delay is expressed in the layer's time space, which runs at twice the media time for this layer,
    // so the begin time is the layer's current time plus the delay (far from the media time plus the delay)
    let animation = try unwrap(layer.animation(forKey: "opacity") as? CABasicAnimation)
    let layerNow = layer.currentTime
    expect(animation.beginTime - layerNow).to(beApproximatelyEqual(to: 0.5, within: 0.1))
    expect(abs(animation.beginTime - (AnimationClock.now + 0.5))).toNot(beApproximatelyEqual(to: 0, within: 1))
  }

  func test_animate_beginsAtTheClocksTimeInTheLayersTimeSpace() throws {
    // given: a layer in a layer tree whose time runs at twice the media time
    let root = CALayer()
    root.speed = 2
    let layer = CALayer()
    root.addSublayer(layer)
    layer.opacity = 0.2

    // when: at the media time 1000, animating the opacity, and the corner radius after a delay
    AnimationClock.sharingTime(at: 1000) {
      layer.animate(keyPath: "opacity", to: Float(1), timing: .linear(duration: 1))
      layer.animate(keyPath: "cornerRadius", to: CGFloat(10), timing: .linear(duration: 1, delay: 0.5))
    }

    // then: the animations begin at 1000 in the layer's time space, 2000, the delayed one after its delay, instead of
    // at a time Core Animation sets when the transaction commits
    expect(try layer.animation(forKey: "opacity").unwrap().beginTime) == 2000
    expect(try layer.animation(forKey: "cornerRadius").unwrap().beginTime) == 2000.5
  }

  func test_animate_hosted_showsTheValueItsBeginTimeGives() throws {
    // given: a layer hosted in a window, at an x of 5, in a new turn of the run loop, so an animation added now begins
    // now
    let testWindow = TestWindow()
    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    RunLoop.main.run(until: Date())

    // when: animating the x to 1005 linearly over 10 seconds, 100 points per second, and the transaction commits 50 ms
    // later, as it does when the main thread is busy. the animation has no timing function, so Core Animation paces it
    // linearly instead of solving the linear timing function's curve, which it does only to within 1e-5 of the change,
    // 0.01 points here, too loose for the bounds below
    layer.animate(keyPath: "position.x", to: CGFloat(1005), timing: .linear(duration: 10), updateAnimation: { $0.timingFunction = nil })
    let beginTime = try layer.convertTime(layer.animation(forKey: "position.x").unwrap().beginTime, to: nil)
    Thread.sleep(forTimeInterval: 0.05)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

    // then: the layer shows the x the timing gives from the begin time at the time it's read, instead of from the commit
    for _ in 0 ..< 5 {
      let timeBefore = CACurrentMediaTime()
      let shownX = try Double(layer.presentation().unwrap().position.x)
      let timeAfter = CACurrentMediaTime()
      expect(shownX) >= 5 + 100 * (timeBefore - beginTime)
      expect(shownX) <= 5 + 100 * (timeAfter - beginTime)
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
    }
  }

  func test_animate_negativeDelay_beginsNow() throws {
    for delay in [-0.5, -2, -.infinity] {
      // given: a layer with partial opacity
      let layer = CALayer()
      layer.opacity = 0.2

      // when: animating the opacity with a negative delay
      layer.animate(keyPath: "opacity", to: Float(1), timing: .linear(duration: 1, delay: delay))

      // then: the animation begins now, as without a delay, instead of that far in the past
      expect(try layer.animation(forKey: "opacity").unwrap().beginTime, "delay \(delay)") == layer.currentTime
    }
  }

  func test_animate_pausedTimelineAtZero_beginsAtZero() throws {
    // given: a layer hosted in a window at an opacity of 0, on a timeline paused at zero
    let testWindow = TestWindow()
    let root = CALayer()
    root.speed = 0
    root.timeOffset = 0
    testWindow.layer.addSublayer(root)
    let layer = CALayer()
    root.addSublayer(layer)
    layer.opacity = 0
    CATransaction.flush()

    // when: animating the opacity to 1 over two seconds at the timeline's zero, then moving the timeline to 1 before the
    // transaction commits, and on to 1.5
    layer.animate(keyPath: "opacity", to: Float(1), timing: .linear(duration: 2))
    root.timeOffset = 1
    CATransaction.flush()
    root.timeOffset = 1.5
    CATransaction.flush()

    // then: the animation keeps a begin time at zero, instead of the time of the commit, which Core Animation gives a
    // begin time of zero, so it shows three quarters of the way
    expect(try layer.animation(forKey: "opacity").unwrap().beginTime) == .leastNormalMagnitude
    expect(try layer.presentation().unwrap().opacity).to(beApproximatelyEqual(to: 0.75, within: 1e-6))
  }

  func test_animate_delayed_nilFromValue_resolvesAtDispatch() throws {
    // given: an unhosted layer with a green background
    let red = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
    let green = CGColor(red: 0, green: 1, blue: 0, alpha: 1)

    let layer = CALayer()
    layer.backgroundColor = green

    // when: animating the background color with a delay, with a from closure that resolves to nil because an
    // unhosted layer has no presentation
    layer.animate(
      keyPath: "backgroundColor",
      timing: .linear(duration: 1, delay: 0.5),
      from: { $0.presentation()?.backgroundColor },
      to: { _ in red }
    )

    // then: the nil from value is resolved at dispatch from the model value, so the scheduled animation's fill can
    // hold the old value during the delay window instead of showing the target
    let animation = try unwrap(layer.animation(forKey: "backgroundColor") as? CABasicAnimation)
    expect(try unwrap(animation.fromValue) as! CGColor) == green // swiftlint:disable:this force_cast
    expect(layer.backgroundColor) == red
  }

  func test_animate_delayed_nilFromValue_animationInFlight_resolvesToTheShownValue() throws {
    // given: an unhosted layer whose background color animates from red to blue over two seconds, from 1000
    let red = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
    let blue = CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
    let layer = CALayer()
    AnimationClock.sharingTime(at: 1000) {
      layer.animate(keyPath: "backgroundColor", timing: .linear(duration: 2), from: { _ in red }, to: { _ in blue })
    }

    // when: a quarter of the way, animating the background color to green with a delay, from a nil value
    AnimationClock.sharingTime(at: 1000.5) {
      layer.animate(
        keyPath: "backgroundColor",
        timing: .linear(duration: 1, delay: 0.5),
        from: { _ -> CGColor? in nil },
        to: { _ in CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1) }
      )
    }

    // then: the nil from value is resolved to the color the layer shows at the clock's time, a quarter of the way to
    // blue, instead of the model color
    let animation = try unwrap(layer.animation(forKey: "backgroundColor") as? CABasicAnimation)
    try expectExtendedSRGBComponents(of: colorValue(animation.fromValue), toBe: [0.75, 0, 0.25, 1])
  }

  func test_animate_delayed_nilFromValue_unevaluableAnimationInFlight_resolvesToTheModelValue() throws {
    // given: an unhosted green layer with a keyframe animation of its background color, which can't be evaluated
    let green = CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)
    let layer = CALayer()
    layer.backgroundColor = green
    let keyframeAnimation = CAKeyframeAnimation(keyPath: "backgroundColor")
    keyframeAnimation.values = [green, CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)]
    keyframeAnimation.duration = 2
    layer.add(keyframeAnimation, forKey: "keyframes")

    // when: animating the background color to red with a delay, from a nil value
    layer.animate(
      keyPath: "backgroundColor",
      timing: .linear(duration: 1, delay: 0.5),
      from: { _ -> CGColor? in nil },
      to: { _ in CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1) }
    )

    // then: the layer has no presentation layer to fall back to, so the nil from value is resolved to the model color
    let animation = try unwrap(layer.animation(forKey: "backgroundColor") as? CABasicAnimation)
    expect(try colorValue(animation.fromValue)) == green
  }

  func test_animate_delayed_holdsFromValueDuringDelayWindow() throws {
    // given: a layer hosted in a window with partial opacity, in a new turn of the run loop, so an animation added now
    // begins now
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    layer.opacity = 0.2
    RunLoop.main.run(until: Date())

    // when: animating the opacity with a delay and a completion delegate
    var isCompleted = false
    layer.animate(
      keyPath: "opacity",
      to: Float(1),
      timing: .linear(duration: 0.2, delay: 0.5),
      updateAnimation: {
        $0.delegate = AnimationDelegate(animationDidStop: { _, _ in
          isCompleted = true
        })
      }
    )

    // then: during the delay window, the model is at the target while the presentation holds the old value
    expect(layer.presentation()).toEventuallyNot(beNil())
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
    expect(layer.opacity) == 1
    expect(try unwrap(layer.presentation()).opacity).to(beApproximatelyEqual(to: 0.2, within: 0.05))
    expect(isCompleted) == false

    // then: the animation completes after the delay and the duration, landing at the target
    expect(isCompleted).toEventually(beTrue(), timeout: 2)
    expect(try unwrap(layer.presentation()).opacity).to(beApproximatelyEqual(to: 1, within: 0.05))
  }

  func test_animationKey() {
    // when: animating without an explicit key
    do {
      let layer = CALayer()
      layer.animate(
        keyPath: "position",
        timing: .easeInEaseOut(duration: 1),
        from: { _ in CGPoint(x: 100, y: 100) },
        to: { _ in CGPoint(x: 200, y: 200) }
      )

      // then: the key path is used as the animation key
      expect(layer.animationKeys()) == ["position"]
    }

    // when: animating with an explicit key
    do {
      let layer = CALayer()
      layer.animate(
        key: "test",
        keyPath: "position",
        timing: .easeInEaseOut(duration: 1),
        from: { _ in CGPoint(x: 100, y: 100) },
        to: { _ in CGPoint(x: 200, y: 200) }
      )

      // then: the explicit key is used as the animation key
      expect(layer.animationKeys()) == ["test"]
    }
  }

  func test_animationKey_additive() {
    // when: adding an additive animation without an explicit key
    do {
      let layer = CALayer()
      layer.animate(
        keyPath: "position",
        timing: .easeInEaseOut(duration: 1),
        from: { $0.position - CGPoint(x: 100, y: 100) },
        to: { _ in .zero },
        model: { _ in CGPoint(x: 100, y: 100) },
        updateAnimation: { $0.isAdditive = true }
      )

      // then: the key path is used as the animation key
      expect(layer.animationKeys()) == ["position"]

      // when: adding another additive animation with the same key path
      layer.animate(
        keyPath: "position",
        timing: .easeInEaseOut(duration: 1),
        from: { $0.position - CGPoint(x: 100, y: 100) },
        to: { _ in .zero },
        model: { _ in CGPoint(x: 100, y: 100) },
        updateAnimation: { $0.isAdditive = true }
      )

      // then: a unique key is generated
      expect(layer.animationKeys()) == ["position", "position-1"]
    }

    // when: adding an additive animation with an explicit key
    do {
      let layer = CALayer()
      layer.animate(
        key: "test",
        keyPath: "position",
        timing: .easeInEaseOut(duration: 1),
        from: { $0.position - CGPoint(x: 100, y: 100) },
        to: { _ in .zero },
        model: { _ in CGPoint(x: 100, y: 100) },
        updateAnimation: { $0.isAdditive = true }
      )

      // then: the explicit key is used as the animation key
      expect(layer.animationKeys()) == ["test"]

      // when: adding another additive animation with the same explicit key
      layer.animate(
        key: "test",
        keyPath: "position",
        timing: .easeInEaseOut(duration: 1),
        from: { $0.position - CGPoint(x: 100, y: 100) },
        to: { _ in .zero },
        model: { _ in CGPoint(x: 100, y: 100) },
        updateAnimation: { $0.isAdditive = true }
      )

      // then: a unique key is generated
      expect(layer.animationKeys()) == ["test", "test-1"]
    }
  }

  // MARK: - uniqueAnimationKey

  func test_uniqueAnimationKey_noExistingAnimations() {
    // given: a layer with no animations
    let layer = CALayer()

    // then: the original key is returned
    expect(layer.uniqueAnimationKey(key: "opacity")) == "opacity"
  }

  func test_uniqueAnimationKey_withExistingAnimations() {
    // given: a layer with existing animations
    let layer = CALayer()

    let animation = CABasicAnimation()
    layer.add(animation, forKey: "position")
    layer.add(animation, forKey: "position-1")

    // then: the next available key is generated
    expect(layer.uniqueAnimationKey(key: "position")) == "position-2"
  }

  func test_uniqueAnimationKey_withNonSequentialKeys() {
    // given: a layer with existing animations with non-sequential keys
    let layer = CALayer()

    let animation = CABasicAnimation()
    layer.add(animation, forKey: "position")
    layer.add(animation, forKey: "position-2")

    // then: the next sequential number is still used
    expect(layer.uniqueAnimationKey(key: "position")) == "position-1"
  }

  // MARK: - currentTime

  func test_currentTime_maskLayer_isInTheMaskedLayersTimeSpace() {
    // given: a layer with a mask, in a layer tree whose time runs at twice the media time from a begin time of 5
    let root = CALayer()
    root.speed = 2
    root.beginTime = 5
    let layer = CALayer()
    root.addSublayer(layer)
    let mask = CAShapeLayer()
    layer.mask = mask

    AnimationClock.sharingTime(at: 1000) {
      // then: the mask's current time is the masked layer's, so the mask's animations begin with the layer's
      expect(layer.currentTime) == 1990
      expect(mask.currentTime) == layer.currentTime
    }
  }

  // MARK: - Key Path Animations

  func test_basicAnimations_forKeyPath() {
    // given: a layer with basic, keyframe, and different key path animations
    let layer = CALayer()

    let fadeAnimation = CABasicAnimation(keyPath: "opacity")
    fadeAnimation.duration = 60
    layer.add(fadeAnimation, forKey: "fade")

    // a keyframe animation on the same key path is not a basic animation
    let keyframeAnimation = CAKeyframeAnimation(keyPath: "opacity")
    keyframeAnimation.duration = 60
    layer.add(keyframeAnimation, forKey: "keyframe-fade")

    // a basic animation on a different key path doesn't match
    let spinAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    spinAnimation.duration = 60
    layer.add(spinAnimation, forKey: "spin")

    // a group animating the key path is not a basic animation
    layer.add(group(of: [CABasicAnimation(keyPath: "opacity")]), forKey: "group-fade")

    // when: querying basic animations for the opacity key path
    let animations = layer.basicAnimations(forKeyPath: "opacity")

    // then: only the basic opacity animation matches
    expect(animations.count) == 1
    expect(animations.first?.keyPath) == "opacity"
  }

  func test_propertyAnimations_forKeyPath() {
    // given: a layer with basic, keyframe, and different key path animations, and a group animating the key path
    let layer = CALayer()

    let fadeAnimation = CABasicAnimation(keyPath: "opacity")
    fadeAnimation.duration = 60
    layer.add(fadeAnimation, forKey: "fade")

    let keyframeAnimation = CAKeyframeAnimation(keyPath: "opacity")
    keyframeAnimation.duration = 60
    layer.add(keyframeAnimation, forKey: "keyframe-fade")

    let spinAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    spinAnimation.duration = 60
    layer.add(spinAnimation, forKey: "spin")

    layer.add(group(of: [CABasicAnimation(keyPath: "opacity")]), forKey: "group-fade")

    // when: querying property animations for the opacity key path
    let animations = layer.propertyAnimations(forKeyPath: "opacity")

    // then: both opacity animations match, in order, and neither the other key path nor the group does
    expect(animations.count) == 2
    expect(animations.first is CABasicAnimation) == true
    expect(animations.last is CAKeyframeAnimation) == true
  }

  func test_animationSequence_yieldsTheKeyPathsAnimationsWithTheirKeysInOrder() throws {
    // given: a layer with opacity animations, and groups with one, directly and in a group of their own, between other
    // animations: of another key path, a transition, a group of another key path and a transition, and an empty group
    let layer = CALayer()

    let fadeAnimation = CABasicAnimation(keyPath: "opacity")
    fadeAnimation.duration = 60
    layer.add(fadeAnimation, forKey: "fade")

    let spinAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    spinAnimation.duration = 60
    layer.add(spinAnimation, forKey: "spin")

    layer.add(group(of: [CABasicAnimation(keyPath: "position"), CABasicAnimation(keyPath: "opacity")]), forKey: "group-fade")

    let transition = CATransition()
    transition.duration = 60
    layer.add(transition, forKey: "transition")

    layer.add(group(of: [CABasicAnimation(keyPath: "position"), CATransition()]), forKey: "group-move")
    layer.add(group(of: nil), forKey: "empty-group")
    layer.add(group(of: [group(of: [CABasicAnimation(keyPath: "position")]), group(of: [CABasicAnimation(keyPath: "opacity")])]), forKey: "nested-group-fade")

    let keyframeAnimation = CAKeyframeAnimation(keyPath: "opacity")
    keyframeAnimation.duration = 60
    layer.add(keyframeAnimation, forKey: "keyframe-fade")

    // when: iterating the opacity animations
    let animations = try Array(layer.animationSequence(forKeyPath: "opacity").unwrap())

    // then: the opacity animations and the groups with one are yielded with their keys, in order, skipping the others,
    // the opacity animations as direct ones and the groups as indirect ones
    expect(animations.map(\.key)) == ["fade", "group-fade", "nested-group-fade", "keyframe-fade"]
    expect(animations.map { kind(of: $0.animation) }) == ["direct", "indirect", "indirect", "direct"]
    expect(animations[0].animation.animation is CABasicAnimation) == true
    expect(animations[1].animation.animation is CAAnimationGroup) == true
    expect(animations[2].animation.animation is CAAnimationGroup) == true
    expect(animations[3].animation.animation is CAKeyframeAnimation) == true
  }

  func test_animationSequence_relatedKeyPaths_areIndirect() throws {
    // given: a layer whose position animates directly, through its x component, and through a group of it, with a
    // sibling of its bounds size, its bounds, one of its bounds size's components, and a key path that only starts with
    // `position` animating too
    let layer = CALayer()
    for keyPath in ["position", "position.x", "positionX", "bounds", "bounds.origin", "bounds.size.width"] {
      let animation = CABasicAnimation(keyPath: keyPath)
      animation.duration = 60
      layer.add(animation, forKey: keyPath)
    }
    layer.add(group(of: [CABasicAnimation(keyPath: "position.y")]), forKey: "group-move-y")

    // when: iterating the animations of the position and of the bounds size
    let positionAnimations = try Array(layer.animationSequence(forKeyPath: "position").unwrap())
    let sizeAnimations = try Array(layer.animationSequence(forKeyPath: "bounds.size").unwrap())

    // then: the position's animation is direct, and its component's and the group's are indirect, while a key path
    // that doesn't continue with a dot isn't related
    expect(positionAnimations.map(\.key)) == ["position", "position.x", "group-move-y"]
    expect(positionAnimations.map { kind(of: $0.animation) }) == ["direct", "indirect", "indirect"]

    // then: the bounds and the size's component change the size indirectly, while a sibling of the size doesn't
    expect(sizeAnimations.map(\.key)) == ["bounds", "bounds.size.width"]
    expect(sizeAnimations.map { kind(of: $0.animation) }) == ["indirect", "indirect"]
  }

  func test_keyPathLookups_leaveRelatedKeyPathsOut() {
    // given: a layer whose position animates directly and through its x component
    let layer = CALayer()
    for keyPath in ["position", "position.x"] {
      let animation = CABasicAnimation(keyPath: keyPath)
      animation.duration = 60
      layer.add(animation, forKey: keyPath)
    }

    // then: the position's lookups only find the direct animation
    expect(layer.basicAnimations(forKeyPath: "position").map(\.keyPath)) == ["position"]
    expect(layer.propertyAnimations(forKeyPath: "position").map(\.keyPath)) == ["position"]

    // when: removing the position's animations
    layer.removeAnimations(forKeyPath: "position")

    // then: the component's animation is left alone
    expect(layer.animationKeys()) == ["position.x"]
  }

  func test_animationSequence_noAnimationOfTheKeyPath_isNil() {
    // given: a layer without animations, and a layer with an animation, a group and an empty group of other key paths,
    // and a group with an animation without a key path
    let layer = CALayer()
    let spinningLayer = CALayer()
    let spinAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    spinAnimation.duration = 60
    spinningLayer.add(spinAnimation, forKey: "spin")
    spinningLayer.add(group(of: [CABasicAnimation(keyPath: "position")]), forKey: "group-move")
    spinningLayer.add(group(of: nil), forKey: "empty-group")
    spinningLayer.add(group(of: [CABasicAnimation()]), forKey: "group-no-key-path")

    // then: neither has opacity animations
    expect(layer.animationSequence(forKeyPath: "opacity")).to(beNil())
    expect(spinningLayer.animationSequence(forKeyPath: "opacity")).to(beNil())
  }

  func test_animationSequence_doesntExtendTheLayersLifetime() {
    // given: a layer
    var layer: CALayer? = CALayer()
    weak let weakLayer = layer

    autoreleasepool {
      // when: looking up its animations, then letting the layer go before the enclosing autorelease pool drains
      _ = layer?.animationSequence(forKeyPath: "opacity")
      layer = nil

      // then: the layer is released right away
      expect(weakLayer).to(beNil())
    }
  }

  func test_removeAnimations_forKeyPath() {
    // given: a layer with basic, keyframe, and different key path animations
    let layer = CALayer()

    let fadeAnimation = CABasicAnimation(keyPath: "opacity")
    fadeAnimation.duration = 60
    layer.add(fadeAnimation, forKey: "fade")

    // a keyframe animation on the same key path is also removed
    let keyframeAnimation = CAKeyframeAnimation(keyPath: "opacity")
    keyframeAnimation.duration = 60
    layer.add(keyframeAnimation, forKey: "keyframe-fade")

    // an animation on a different key path survives
    let spinAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    spinAnimation.duration = 60
    layer.add(spinAnimation, forKey: "spin")

    // a group animating the key path survives, since it may animate other key paths
    layer.add(group(of: [CABasicAnimation(keyPath: "opacity")]), forKey: "group-fade")

    // when: removing animations for the opacity key path
    layer.removeAnimations(forKeyPath: "opacity")

    // then: both opacity animations are removed, and the other key path animation and the group survive
    expect(layer.animation(forKey: "fade")) == nil
    expect(layer.animation(forKey: "keyframe-fade")) == nil
    expect(layer.animation(forKey: "spin")) != nil
    expect(layer.animation(forKey: "group-fade")) != nil
  }

  // MARK: - Helpers

  private func group(of animations: [CAAnimation]?) -> CAAnimationGroup {
    let group = CAAnimationGroup()
    group.animations = animations
    group.duration = 60
    return group
  }

  private func kind(of animation: KeyPathAnimation) -> String {
    switch animation {
    case .direct:
      return "direct"
    case .indirect:
      return "indirect"
    }
  }
}
