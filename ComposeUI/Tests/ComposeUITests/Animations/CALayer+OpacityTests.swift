//
//  CALayer+OpacityTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/25/26.
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

import ChouTiTest

@_spi(Private) @testable import ComposeUI

class CALayer_OpacityTests: XCTestCase {

  // MARK: - animateOpacity

  func test_animateOpacity_withoutInFlightAnimation_startsFromTheModelValue() throws {
    // given: a layer at 0.3 with nothing in flight
    let layer = CALayer()
    layer.opacity = 0.3

    // when: animating to 1 without a fresh start value or completion
    layer.animateOpacity(to: 1, timing: .linear(duration: 1))

    // then: one animation starts from the model's 0.3, with no delegate
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    let animation = try animations.first.unwrap()
    expect(animation.isAdditive) == true
    expect(try (animation.fromValue as? Float).unwrap()).to(beApproximatelyEqual(to: -0.7, within: 1e-6))
    expect(animation.delegate) == nil
    expect(layer.opacity) == 1
  }

  // MARK: - retargetOpacity

  func test_retargetOpacity_withoutInFlightAnimation_setsTheValue() {
    // given: a layer at 0.3 with nothing in flight
    let layer = CALayer()
    layer.opacity = 0.3

    // when: retargeting the opacity to 0.6
    layer.retargetOpacity(to: 0.6)

    // then: the value is set without an animation
    expect(layer.opacity) == 0.6
    expect(layer.animationKeys()) == nil
  }

  func test_retargetOpacity_toTheModelValue_leavesTheInFlightAnimation() throws {
    // given: a layer fading in to 1, halfway through
    let layer = CALayer()
    layer.opacity = 1
    addInFlightAnimation(to: layer, from: -1, progress: 0.5, duration: 10)
    let inFlightAnimation = try layer.animation(forKey: "opacity").unwrap()

    // when: retargeting to 1, where the fade lands
    layer.retargetOpacity(to: 1)

    // then: the fade is kept
    expect(layer.animationKeys()) == ["opacity"]
    expect(layer.animation(forKey: "opacity")) === inFlightAnimation
    expect(layer.opacity) == 1
  }

  func test_retargetOpacity_withInFlightAnimation_glidesFromTheShownOpacityOverTheRemainingTime() throws {
    // given: a layer fading from 1 to 0.2 over 10 s, halfway through at 0.6
    let layer = CALayer()
    layer.opacity = 0.2
    addInFlightAnimation(to: layer, from: 0.8, progress: 0.5, duration: 10)

    // when: retargeting the opacity to 1
    layer.retargetOpacity(to: 1)

    // then: an ease-out glide replaces the fade, from the shown 0.6 to 1, landing when the fade would have
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    let glide = try animations.first.unwrap()
    expect(glide.isAdditive) == true
    expect(try (glide.fromValue as? Float).unwrap()).to(beApproximatelyEqual(to: -0.4, within: 0.01))
    expect(glide.toValue as? Float) == 0
    expect(glide.duration).to(beApproximatelyEqual(to: 5, within: 0.05))
    expect(glide.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(layer.opacity) == 1
  }

  func test_retargetOpacity_withAnimationThatNeverFinishes_glidesOverTheDefaultDuration() throws {
    // given: a layer with an opacity animation that never finishes
    let layer = CALayer()
    layer.opacity = 0.2
    addInFlightAnimation(to: layer, from: 0.8, progress: 0, duration: TimeInterval(Float.greatestFiniteMagnitude))

    // when: retargeting the opacity to 1
    layer.retargetOpacity(to: 1)

    // then: the glide takes the default duration
    let glide = try layer.basicAnimations(forKeyPath: "opacity").first.unwrap()
    expect(glide.duration) == Animations.defaultAnimationDuration
    expect(layer.opacity) == 1
  }

  func test_retargetOpacity_withEndedAnimation_setsTheValue() {
    // given: a layer with an ended opacity animation that hasn't been removed yet
    let layer = CALayer()
    layer.opacity = 0.2
    addInFlightAnimation(to: layer, from: 0.8, progress: 2, duration: 1)

    // when: retargeting the opacity to 1
    layer.retargetOpacity(to: 1)

    // then: the value is set without a new animation
    expect(layer.opacity) == 1
    expect(layer.animationKeys()) == ["opacity"]
  }

  // MARK: - interruptedOpacityState

  func test_interruptedOpacityState_clampsAfterEachAnimation() throws {
    // given: a layer at 1 with two additive animations adding -2, then +0.5
    let layer = CALayer()
    layer.opacity = 1
    addInFlightAnimation(to: layer, from: -2, progress: 0, duration: 10, key: "a")
    addInFlightAnimation(to: layer, from: 0.5, progress: 0, duration: 10, key: "b")

    // then: the first animation clamps at 0 before the second adds 0.5, as the render server does
    expect(try layer.interruptedOpacityState().unwrap().value).to(beApproximatelyEqual(to: 0.5, within: 1e-3))
  }

  func test_interruptedOpacityState_justReachedABound_hasNoVelocity() throws {
    // given: a layer on a timeline paused at t = 10, whose opacity rose to 1 within the last sampling interval
    let root = CALayer()
    root.speed = 0
    root.timeOffset = 10
    let layer = CALayer()
    root.addSublayer(layer)
    layer.opacity = 0.75
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.fromValue = 0.0
    animation.toValue = 0.5
    animation.duration = 1
    animation.timingFunction = CAMediaTimingFunction(name: .linear)
    animation.isAdditive = true
    animation.beginTime = 9.498
    layer.add(animation, forKey: "opacity")

    // then: it's at 1 with no velocity, as the motion past the bound doesn't show
    let state = try layer.interruptedOpacityState().unwrap()
    expect(state.value) == 1
    expect(state.velocity) == 0
  }

  #if canImport(AppKit)
  func test_interruptedOpacityState_matchesTheRenderedOpacity() throws {
    // given: a rendered layer at 1 with two additive animations adding -2, then +0.5, both fading out over 10 s
    let renderer = try PausedLayerRenderer(time: 10)
    let layer = renderer.layer
    layer.opacity = 1
    addInFlightAnimation(to: layer, from: -2, progress: 0, duration: 10, key: "a")
    addInFlightAnimation(to: layer, from: 0.5, progress: 0, duration: 10, key: "b")

    for time in [10.0, 15.0] {
      // when: moving the timeline
      renderer.move(to: time)

      // then: the computed opacity is the rendered one
      let computedOpacity = try Double(layer.interruptedOpacityState().unwrap().value)
      expect(renderer.renderedOpacity(), "\(time)").to(beApproximatelyEqual(to: computedOpacity, within: 0.01))
    }
  }
  #endif

  // MARK: - Helpers

  /// Adds a linear additive opacity animation from `from` to 0 that is `progress` of the way through.
  private func addInFlightAnimation(to layer: CALayer, from: Double, progress: Double, duration: TimeInterval, key: String = "opacity") {
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.fromValue = from
    animation.toValue = 0.0
    animation.duration = duration
    animation.timingFunction = CAMediaTimingFunction(name: .linear)
    animation.isAdditive = true
    animation.beginTime = layer.currentTime - duration * progress
    layer.add(animation, forKey: key)
  }
}
