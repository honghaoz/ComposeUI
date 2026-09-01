//
//  RenderableTransition+OpacityTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/26/26.
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

class RenderableTransition_OpacityTests: XCTestCase {

  func test_freshInsert() throws {
    // given: a layer with a junk model opacity
    let layer = CALayer()
    layer.opacity = 0.3 // junk model value, a fresh insertion starts from `from`

    // when: a fresh insert transition animates the layer
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    try unwrap(transition.insert).animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: CGRect(x: 0, y: 0, width: 10, height: 10), contentView: nil),
      completion: {}
    )

    // then: a single additive animation starts from the transition's from value, with the model at the target
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    expect(try unwrap(animations.first).fromValue as? Float) == -1
    expect(try unwrap(animations.first).isAdditive) == true
    expect(layer.opacity) == 1
  }

  func test_freshRemove_startsFromModelValue() throws {
    // given: a layer with a model opacity of 0.8
    let layer = CALayer()
    layer.opacity = 0.8

    // when: a fresh remove transition animates the layer
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // then: a single animation starts from the model value, with the model at 0
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    expect(try unwrap(unwrap(animations.first).fromValue as? Float)).to(beApproximatelyEqual(to: 0.8, within: 1e-6))
    expect(layer.opacity) == 0
  }

  func test_removeDuringInsert_retargetsFromCurrentValue() throws {
    // given: a layer mid-insertion showing opacity 0.5
    let layer = CALayer()
    layer.opacity = 1 // an in-flight insertion has the model at the target

    // an insertion halfway through: contribution is -0.5, current visual opacity is 0.5
    addInFlightAdditiveAnimation(to: layer, from: -1, progress: 0.5)

    // when: a remove transition interrupts
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // then: the in-flight animation is replaced with a single animation from the current visual opacity
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    expect(try unwrap(unwrap(animations.first).fromValue as? Float)).to(beApproximatelyEqual(to: 0.5, within: 0.01))
    expect(try unwrap(animations.first).isAdditive) == true
    expect(layer.opacity) == 0
  }

  func test_insertDuringRemove_retargetsFromCurrentValue() throws {
    // given: a layer mid-removal showing opacity 0.25
    let layer = CALayer()
    layer.opacity = 0 // an in-flight removal has the model at the target

    // a removal 75% through: contribution is +0.25, current visual opacity is 0.25
    addInFlightAdditiveAnimation(to: layer, from: 1, progress: 0.75)

    // when: an insert transition interrupts
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    try unwrap(transition.insert).animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: CGRect(x: 0, y: 0, width: 10, height: 10), contentView: nil),
      completion: {}
    )

    // then: a single animation retargets from the current visual opacity, with the model at the target
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    expect(try unwrap(unwrap(animations.first).fromValue as? Float)).to(beApproximatelyEqual(to: -0.75, within: 0.01))
    expect(layer.opacity) == 1
  }

  func test_retarget_immediateInterrupt_evaluatesProductionAnimation() throws {
    // pins the begin time resolution of production-added animations: the insert's animation is added with an unset
    // begin time (resolved by Core Animation on add), and an immediate interrupt must evaluate it at ~zero elapsed
    // time, sampling the insert's start value rather than the model value.

    // given: a layer with a junk model opacity
    let layer = CALayer()
    layer.opacity = 0.3

    // when: an insert transition starts
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 10))
    try unwrap(transition.insert).animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: CGRect(x: 0, y: 0, width: 10, height: 10), contentView: nil),
      completion: {}
    )

    // then: the model moves to the target
    expect(layer.opacity) == 1 // the model is at the target, the animation contributes -1 for a rendered ≈ 0

    // when: a remove transition interrupts immediately
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // then: the remove continues from the insert's current rendered opacity (≈ 0), not the model value (1)
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    expect(try unwrap(unwrap(animations.first).fromValue as? Float)).to(beApproximatelyEqual(to: 0, within: 0.05))
    expect(layer.opacity) == 0
  }

  func test_resetForReuse_undoesOwnResidue() throws {
    // given: a layer with a remove transition in flight and an unrelated spin animation
    let layer = CALayer()
    layer.opacity = 1

    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    let removeTransition = try unwrap(transition.remove)
    removeTransition.animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )
    expect(layer.opacity) == 0
    expect(layer.basicAnimations(forKeyPath: "opacity").count) == 1

    // an animation of a property the transition doesn't animate
    let spinAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    spinAnimation.duration = 60
    layer.add(spinAnimation, forKey: "spin")

    // when: the transition resets the renderable for reuse
    removeTransition.resetForReuse(renderable: .layer(layer))

    // then: the reset restores the model opacity and removes the opacity animations, leaving other properties'
    // animations alone
    expect(layer.opacity) == 1
    expect(layer.basicAnimations(forKeyPath: "opacity").count) == 0
    expect(layer.animation(forKey: "spin")) != nil
  }

  func test_retarget_clampsCompositeValue() throws {
    // given: a layer whose composed opacity exceeds 1
    let layer = CALayer()
    layer.opacity = 1

    // a corrupted stack can compose beyond 1, the retarget starts from the visible (clamped) value
    addInFlightAdditiveAnimation(to: layer, from: 0.5, progress: 0)

    // when: a remove transition retargets
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // then: the animation starts from the visible (clamped) value
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    expect(try unwrap(unwrap(animations.first).fromValue as? Float)).to(beApproximatelyEqual(to: 1, within: 0.01))
  }

  func test_retarget_nonAdditiveAnimationReplacesBase() throws {
    // given: a layer with a position animation and a non-additive opacity animation showing 0.5
    let layer = CALayer()
    layer.opacity = 0.6

    // an animation of another property is not an opacity transition and survives the retarget
    let positionAnimation = CABasicAnimation(keyPath: "position.x")
    positionAnimation.fromValue = 0.0
    positionAnimation.toValue = 1.0
    positionAnimation.duration = 10
    layer.add(positionAnimation, forKey: "position.x")

    // a non-additive opacity animation halfway through, showing 0.5: it replaces the model value (0.6) as the base
    let nonAdditiveAnimation = CABasicAnimation(keyPath: "opacity")
    nonAdditiveAnimation.fromValue = 0.0
    nonAdditiveAnimation.toValue = 1.0
    nonAdditiveAnimation.duration = 10
    nonAdditiveAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
    nonAdditiveAnimation.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) - 5
    layer.add(nonAdditiveAnimation, forKey: "opacity")

    // when: a remove transition retargets
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // then: the retarget starts from the opacity the non-additive animation was showing, not the model value
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    expect(try unwrap(unwrap(animations.first).fromValue as? Float)).to(beApproximatelyEqual(to: 0.5, within: 0.01))

    // the position animation is untouched
    expect(layer.animation(forKey: "position.x")) != nil
  }

  func test_retarget_unsupportedAnimationAsserts() throws {
    // given: a layer with an opacity animation that can't be evaluated and a test assertion handler installed
    let layer = CALayer()
    layer.opacity = 0.6

    // an opacity animation with non-scalar values can't be evaluated
    let nonScalarAnimation = CABasicAnimation(keyPath: "opacity")
    nonScalarAnimation.fromValue = "not a number"
    nonScalarAnimation.toValue = "not a number"
    nonScalarAnimation.duration = 10
    nonScalarAnimation.isAdditive = true
    layer.add(nonScalarAnimation, forKey: "opacity-nonscalar")

    var assertionMessage: String?
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessage = message
    }

    // when: a remove transition retargets
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    Assert.resetTestAssertionFailureHandler()

    // then: the unsupported animation is flagged and skipped, the retarget starts from the model value
    expect(assertionMessage?.hasPrefix("unsupported in-flight opacity animation")) == true
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    expect(try unwrap(unwrap(animations.first).fromValue as? Float)).to(beApproximatelyEqual(to: 0.6, within: 1e-6))
  }

  func test_retarget_velocityAtSaturatedBound_isDropped() throws {
    // given: a saturated layer with a rising animation whose motion is not visible at the bound
    let layer = CALayer()
    layer.opacity = 1

    // an additive animation rising halfway through: the composite (1.25) is clamped to 1, and its rising motion
    // pushes past the saturated bound, so it isn't visible and carries no momentum
    let risingAnimation = CABasicAnimation(keyPath: "opacity")
    risingAnimation.fromValue = 0.0
    risingAnimation.toValue = 0.5
    risingAnimation.duration = 10
    risingAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
    risingAnimation.isAdditive = true
    risingAnimation.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) - 5
    layer.add(risingAnimation, forKey: "opacity")

    // when: a spring remove transition retargets
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .spring())
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // then: the spring starts from the clamped value with no carried velocity
    let spring = try unwrap(layer.basicAnimations(forKeyPath: "opacity").first as? CASpringAnimation)
    expect(try unwrap(spring.fromValue as? Float)).to(beApproximatelyEqual(to: 1, within: 0.01))
    expect(spring.initialVelocity) == 0
  }

  func test_delayedTransition_releasedLayer() {
    // given: a layer with a delayed remove transition dispatched
    var layer: CALayer? = CALayer()

    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 1, delay: 0.05))
    transition.remove?.animate(
      renderable: .layer(layer!), // swiftlint:disable:this force_unwrapping
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // when: the layer is released during the delay window
    weak let weakLayer = layer
    layer = nil

    // then: the layer is released with its scheduled animation once the pending transaction commits, without the
    // animation ever playing
    expect(weakLayer).toEventually(beNil())
  }

  func test_retarget_springTiming_matchesVelocity() throws {
    // given: a layer mid-insertion, showing 0.5 and rising
    let layer = CALayer()
    layer.opacity = 1

    // an insertion halfway through a 10s linear fade: value 0.5, rising at +0.1 per second
    addInFlightAdditiveAnimation(to: layer, from: -1, progress: 0.5)

    // when: a spring remove transition retargets
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .spring())
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // then: the spring starts from the sampled value and carries the sampled velocity
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    let spring = try unwrap(animations.first as? CASpringAnimation)
    expect(try unwrap(spring.fromValue as? Float)).to(beApproximatelyEqual(to: 0.5, within: 0.01))

    // opacity velocity +0.1/s over a delta of 0.5 towards 0 is -0.2 in Core Animation's convention
    expect(spring.initialVelocity).to(beApproximatelyEqual(to: -0.2, within: 0.02))

    // the spring's duration is derived from the spring that actually runs, including the carried velocity,
    // so the animation isn't cut off before the spring settles
    let springWithCarriedVelocity = SpringDescriptor(
      initialVelocity: spring.initialVelocity,
      mass: spring.mass,
      stiffness: spring.stiffness,
      damping: spring.damping
    )
    expect(spring.duration).to(beApproximatelyEqual(to: springWithCarriedVelocity.perceptualDuration(), within: 1e-6))
  }

  func test_retarget_springTiming_delayed_startsFromRest() throws {
    // given: a layer mid-insertion, showing 0.5 and rising
    let layer = CALayer()
    layer.opacity = 1

    // an insertion halfway through a 10s linear fade: value 0.5, rising at +0.1 per second
    addInFlightAdditiveAnimation(to: layer, from: -1, progress: 0.5)

    // when: a delayed spring remove transition retargets
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .spring(delay: 0.5))
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // then: the scheduled spring starts from the sampled value with no carried velocity
    // a delayed retarget freezes the interrupted motion at its sampled value for the delay window, so the scheduled
    // spring launches from rest instead of with the stale sampled velocity
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    let spring = try unwrap(animations.first as? CASpringAnimation)
    expect(try unwrap(spring.fromValue as? Float)).to(beApproximatelyEqual(to: 0.5, within: 0.01))
    expect(spring.initialVelocity) == 0

    let now = layer.convertTime(CACurrentMediaTime(), from: nil)
    expect(spring.beginTime - now).to(beApproximatelyEqual(to: 0.5, within: 0.1))
  }

  func test_retarget_springTiming_speedScalesVelocity() throws {
    // given: a layer mid-insertion, showing 0.5 and rising
    let layer = CALayer()
    layer.opacity = 1

    // an insertion halfway through a 10s linear fade: value 0.5, rising at +0.1 per second
    addInFlightAdditiveAnimation(to: layer, from: -1, progress: 0.5)

    // when: a spring remove transition with a 2x speed retargets
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .spring(speed: 2))
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // then: the carried velocity is scaled by the speed
    // the spring plays in a time space running at 2x, so the initial velocity halves to produce
    // the same wall-clock rate: -0.1/s over a delta of 0.5, divided by the speed of 2
    let spring = try unwrap(layer.basicAnimations(forKeyPath: "opacity").first as? CASpringAnimation)
    expect(spring.initialVelocity).to(beApproximatelyEqual(to: -0.1, within: 0.01))
  }

  func test_retarget_springTiming_tinyDelta_dropsVelocity() throws {
    // given: a layer whose composed value is within 1% of the target
    let layer = CALayer()
    layer.opacity = 0

    // an in-flight animation whose composed value is within 1% of the target: the normalized velocity
    // would diverge over the tiny distance, so the velocity carry is dropped
    addInFlightAdditiveAnimation(to: layer, from: 0.01, progress: 0.5)

    // when: a spring remove transition retargets
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .spring())
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // then: the velocity carry is dropped
    let spring = try unwrap(layer.basicAnimations(forKeyPath: "opacity").first as? CASpringAnimation)
    expect(spring.initialVelocity) == 0
  }

  func test_retarget_springTiming_freshStart_keepsConfiguredVelocity() throws {
    // given: a layer with no in-flight animation
    let layer = CALayer()
    layer.opacity = 1

    // when: a spring remove transition with a configured initial velocity animates
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .spring(initialVelocity: 3))
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // then: the configured initial velocity is kept
    let spring = try unwrap(layer.basicAnimations(forKeyPath: "opacity").first as? CASpringAnimation)
    expect(spring.initialVelocity) == 3
  }

  func test_retarget_springTiming_zeroDelta_keepsConfiguredVelocity() throws {
    // given: a layer whose composed value equals the target
    let layer = CALayer()
    layer.opacity = 0

    // an in-flight animation whose composed value equals the target: velocity matching is skipped
    addInFlightAdditiveAnimation(to: layer, from: 0, progress: 0.5)

    // when: a spring remove transition retargets
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .spring())
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // then: velocity matching is skipped and the configured velocity is kept
    let spring = try unwrap(layer.basicAnimations(forKeyPath: "opacity").first as? CASpringAnimation)
    expect(spring.initialVelocity) == 0
  }

  func test_delayedFreshInsert_schedulesHeldAnimation() throws {
    // given: a layer with a junk model opacity
    let layer = CALayer()
    layer.opacity = 0.3 // junk model value, a fresh insertion starts from `from`

    // when: a delayed fresh insert transition animates the layer
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 1, delay: 0.5))
    transition.insert?.animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: CGRect(x: 0, y: 0, width: 10, height: 10), contentView: nil),
      completion: {}
    )

    // then: the model moves to the target and a scheduled animation holds the start delta
    // the model is at the target immediately, and the scheduled animation holds the start value's delta for the delay
    // window (the fill-mode hold itself is pinned by the hosted animate tests)
    expect(layer.opacity) == 1
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    let animation = try unwrap(animations.first)
    expect(try unwrap(animation.fromValue as? Float)) == -1
    expect(animation.toValue as? Float) == 0
    expect(animation.fillMode) == .both

    // the animation is scheduled in the future by the delay, and evaluates to its held start delta until then
    let now = layer.convertTime(CACurrentMediaTime(), from: nil)
    expect(animation.beginTime - now).to(beApproximatelyEqual(to: 0.5, within: 0.1))
    expect(try unwrap(animation.scalarValue(at: now))).to(beApproximatelyEqual(to: -1, within: 1e-6))
  }

  func test_delayedInsert_withInFlightAnimation_freezesAtSampledValue() throws {
    // given: a layer mid-removal showing opacity 0.5
    let layer = CALayer()
    layer.opacity = 0

    // an in-flight removal, halfway through: rendered opacity is 0.5
    addInFlightAdditiveAnimation(to: layer, from: 1, progress: 0.5)

    // when: a delayed insert transition interrupts
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 1, delay: 0.5))
    transition.insert?.animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: CGRect(x: 0, y: 0, width: 10, height: 10), contentView: nil),
      completion: {}
    )

    // then: the in-flight removal is sampled at dispatch and replaced: the scheduled animation holds the sampled
    // value (0.5) for the delay window, then fades to the target
    expect(layer.opacity) == 1
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    let animation = try unwrap(animations.first)
    expect(try unwrap(animation.fromValue as? Float)).to(beApproximatelyEqual(to: -0.5, within: 0.01))

    let now = layer.convertTime(CACurrentMediaTime(), from: nil)
    expect(animation.beginTime - now).to(beApproximatelyEqual(to: 0.5, within: 0.1))
  }

  func test_delayedRetarget_scheduledAnimationIsSuperseded() throws {
    // given: a layer mid-removal with a delayed insert scheduled over it
    let layer = CALayer()
    layer.opacity = 0

    // an in-flight removal, halfway through: rendered opacity is 0.5
    addInFlightAdditiveAnimation(to: layer, from: 1, progress: 0.5)

    // a delayed insert replaces it with a scheduled animation holding the sampled value (0.5), model at 1
    var insertCompletionCallCount = 0
    let insertTransition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 1, delay: 0.5))
    insertTransition.insert?.animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: CGRect(x: 0, y: 0, width: 10, height: 10), contentView: nil),
      completion: { insertCompletionCallCount += 1 }
    )

    // when: a remove interrupts during the insert's delay window
    // it samples the scheduled animation's held value (model 1 + held delta -0.5 = 0.5) and replaces it with its own
    // animation towards 0
    let removeTransition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    try unwrap(removeTransition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // then: a single animation runs from the held value towards 0
    expect(layer.opacity) == 0
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    expect(try unwrap(animations.first?.fromValue as? Float)).to(beApproximatelyEqual(to: 0.5, within: 0.01))

    // the superseded insert's animation was removed without finishing, so its completion reports as stopped (Core
    // Animation delivers the callback on a later run loop turn)
    expect(insertCompletionCallCount) == 0
    expect(insertCompletionCallCount).toEventually(beEqual(to: 1))
  }

  func test_delayedRetarget_scheduledRemove_supersededByInsert_continuesFromHeldValue() throws {
    // given: a layer with a delayed remove scheduled
    let layer = CALayer()
    layer.opacity = 1

    // a delayed remove: the model moves to 0 at dispatch, and the scheduled animation holds the old value (1) for the
    // delay window
    let removeTransition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5, delay: 0.5))
    try unwrap(removeTransition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )
    expect(layer.opacity) == 0
    expect(layer.basicAnimations(forKeyPath: "opacity").count) == 1

    // when: an insert supersedes the scheduled remove before its delay elapses
    // the layer still shows the held value (1), so the insert continues from it (a no-op fade from 1 to 1) instead of
    // restarting from its fresh start value (a snap to 0 followed by a fade-in)
    let insertTransition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    try unwrap(insertTransition.insert).animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: CGRect(x: 0, y: 0, width: 10, height: 10), contentView: nil),
      completion: {}
    )

    // then: the insert continues from the held value with the model at the target
    expect(layer.opacity) == 1
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    expect(try unwrap(animations.first?.fromValue as? Float)) == 0
  }

  func test_delayedInsert_overScheduledRemove_continuesFromHeldValue() throws {
    // given: a layer with a delayed remove scheduled
    let layer = CALayer()
    layer.opacity = 1

    // a delayed remove: the scheduled animation holds the old value (1) for the delay window
    let removeTransition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5, delay: 0.5))
    try unwrap(removeTransition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // when: a delayed insert supersedes the scheduled remove
    // it samples the held value (1) at dispatch and schedules its own animation from it, so the layer keeps
    // rendering 1 through both delay windows
    let insertTransition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5, delay: 0.5))
    try unwrap(insertTransition.insert).animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: CGRect(x: 0, y: 0, width: 10, height: 10), contentView: nil),
      completion: {}
    )

    // then: a single scheduled animation continues from the held value
    expect(layer.opacity) == 1
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    let animation = try unwrap(animations.first)
    expect(try unwrap(animation.fromValue as? Float)) == 0

    let now = layer.convertTime(CACurrentMediaTime(), from: nil)
    expect(animation.beginTime - now).to(beApproximatelyEqual(to: 0.5, within: 0.1))
  }

  func test_delayedRetarget_scheduledAnimationIsRemovedByReset() throws {
    // given: a layer with a delayed remove scheduled
    let layer = CALayer()
    layer.opacity = 1

    // a delayed remove: the model moves to 0 at dispatch, and the scheduled animation holds the old value
    var removeCompletionCallCount = 0
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 1, delay: 0.5))
    let removeTransition = try unwrap(transition.remove)
    removeTransition.animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: { removeCompletionCallCount += 1 }
    )
    expect(layer.opacity) == 0
    expect(layer.basicAnimations(forKeyPath: "opacity").count) == 1

    // when: the renderable is reset during the delay window
    // e.g. recycled to the pool, or revived without a taking-over insert transition
    removeTransition.resetForReuse(renderable: .layer(layer))

    // then: the scheduled animation is removed with the rest of the residue
    expect(layer.opacity) == 1
    expect(layer.basicAnimations(forKeyPath: "opacity").count) == 0

    // the torn-down animation reports as stopped, so the completion fires on a later run loop turn. the framework
    // cancels the transition's completion before resetting, so the late call is inert there
    expect(removeCompletionCallCount) == 0
    expect(removeCompletionCallCount).toEventually(beEqual(to: 1))
  }

  func test_zeroDurationTransition_appliesTargetAndCompletes() throws {
    // given: a layer with an in-flight animation
    let layer = CALayer()
    layer.opacity = 1

    // an in-flight animation is torn down by the zero-duration retarget
    addInFlightAdditiveAnimation(to: layer, from: 1, progress: 0.5)

    // when: a zero-duration remove transition runs
    var removeCompletionCallCount = 0
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 0))
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: { removeCompletionCallCount += 1 }
    )

    // then: the target value applies and the transition completes immediately, with no animation left behind
    expect(layer.opacity) == 0
    expect(layer.basicAnimations(forKeyPath: "opacity").count) == 0
    expect(removeCompletionCallCount) == 1
  }

  func test_zeroDurationTransition_delayed_schedulesSnap() throws {
    // given: a layer mid-removal showing opacity 0.5
    let layer = CALayer()
    layer.opacity = 0

    // an in-flight removal, halfway through: rendered opacity is 0.5
    addInFlightAdditiveAnimation(to: layer, from: 1, progress: 0.5)

    // when: a delayed zero-duration insert transition runs
    var insertCompletionCallCount = 0
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 0, delay: 0.5))
    transition.insert?.animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: CGRect(x: 0, y: 0, width: 10, height: 10), contentView: nil),
      completion: { insertCompletionCallCount += 1 }
    )

    // then: a zero-duration timing with a delay is a scheduled snap
    // the sampled value (0.5) holds for the delay window, then snaps to the target, completing through the animation
    expect(layer.opacity) == 1
    let animations = layer.basicAnimations(forKeyPath: "opacity")
    expect(animations.count) == 1
    let animation = try unwrap(animations.first)
    expect(try unwrap(animation.fromValue as? Float)).to(beApproximatelyEqual(to: -0.5, within: 0.01))
    expect(animation.duration).to(beApproximatelyEqual(to: 0.001, within: 1e-6))
    expect(insertCompletionCallCount) == 0

    let now = layer.convertTime(CACurrentMediaTime(), from: nil)
    expect(animation.beginTime - now).to(beApproximatelyEqual(to: 0.5, within: 0.1))
  }

  /// Adds an in-flight additive opacity animation with a known progress to `layer`.
  ///
  /// The animation is linear from `from` to 0, with its begin time set in the past so its current contribution is
  /// exactly `from * (1 - progress)`.
  private func addInFlightAdditiveAnimation(to layer: CALayer, from: Double, progress: Double, duration: TimeInterval = 10) {
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.fromValue = from
    animation.toValue = 0.0
    animation.duration = duration
    animation.timingFunction = CAMediaTimingFunction(name: .linear)
    animation.isAdditive = true
    animation.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) - duration * progress
    layer.add(animation, forKey: "opacity")
  }
}
