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
    let layer = CALayer()
    layer.opacity = 0.3 // junk model value, a fresh insertion starts from `from`

    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    try unwrap(transition.insert).animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: CGRect(x: 0, y: 0, width: 10, height: 10), contentView: nil),
      completion: {}
    )

    let animations = opacityAnimations(on: layer)
    expect(animations.count) == 1
    expect(try unwrap(animations.first).fromValue as? Float) == -1
    expect(try unwrap(animations.first).isAdditive) == true
    expect(layer.opacity) == 1
  }

  func test_freshRemove_startsFromModelValue() throws {
    let layer = CALayer()
    layer.opacity = 0.8

    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    let animations = opacityAnimations(on: layer)
    expect(animations.count) == 1
    expect(try unwrap(unwrap(animations.first).fromValue as? Float)).to(beApproximatelyEqual(to: 0.8, within: 1e-6))
    expect(layer.opacity) == 0
  }

  func test_removeDuringInsert_retargetsFromCurrentValue() throws {
    let layer = CALayer()
    layer.opacity = 1 // an in-flight insertion has the model at the target

    // an insertion halfway through: contribution is -0.5, current visual opacity is 0.5
    addInFlightAdditiveAnimation(to: layer, from: -1, progress: 0.5)

    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // the in-flight animation is replaced with a single animation from the current visual opacity
    let animations = opacityAnimations(on: layer)
    expect(animations.count) == 1
    expect(try unwrap(unwrap(animations.first).fromValue as? Float)).to(beApproximatelyEqual(to: 0.5, within: 0.01))
    expect(try unwrap(animations.first).isAdditive) == true
    expect(layer.opacity) == 0
  }

  func test_insertDuringRemove_retargetsFromCurrentValue() throws {
    let layer = CALayer()
    layer.opacity = 0 // an in-flight removal has the model at the target

    // a removal 75% through: contribution is +0.25, current visual opacity is 0.25
    addInFlightAdditiveAnimation(to: layer, from: 1, progress: 0.75)

    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    try unwrap(transition.insert).animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: CGRect(x: 0, y: 0, width: 10, height: 10), contentView: nil),
      completion: {}
    )

    let animations = opacityAnimations(on: layer)
    expect(animations.count) == 1
    expect(try unwrap(unwrap(animations.first).fromValue as? Float)).to(beApproximatelyEqual(to: -0.75, within: 0.01))
    expect(layer.opacity) == 1
  }

  func test_retarget_clampsCompositeValue() throws {
    let layer = CALayer()
    layer.opacity = 1

    // a corrupted stack can compose beyond 1, the retarget starts from the visible (clamped) value
    addInFlightAdditiveAnimation(to: layer, from: 0.5, progress: 0)

    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    let animations = opacityAnimations(on: layer)
    expect(animations.count) == 1
    expect(try unwrap(unwrap(animations.first).fromValue as? Float)).to(beApproximatelyEqual(to: 1, within: 0.01))
  }

  func test_retarget_ignoresNonAdditiveAndNonScalarContributions() throws {
    let layer = CALayer()
    layer.opacity = 0.6

    // an animation of another property is not an opacity transition and survives the retarget
    let positionAnimation = CABasicAnimation(keyPath: "position.x")
    positionAnimation.fromValue = 0.0
    positionAnimation.toValue = 1.0
    positionAnimation.duration = 10
    layer.add(positionAnimation, forKey: "position.x")

    // a non-additive opacity animation is replaced without contributing
    let nonAdditive = CABasicAnimation(keyPath: "opacity")
    nonAdditive.fromValue = 0.0
    nonAdditive.toValue = 1.0
    nonAdditive.duration = 10
    layer.add(nonAdditive, forKey: "opacity")

    // a non-scalar additive opacity animation is replaced without contributing
    let nonScalar = CABasicAnimation(keyPath: "opacity")
    nonScalar.fromValue = "not a number"
    nonScalar.toValue = "not a number"
    nonScalar.duration = 10
    nonScalar.isAdditive = true
    layer.add(nonScalar, forKey: "opacity-nonscalar")

    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // the retarget starts from the model value since no animation contributes
    let animations = opacityAnimations(on: layer)
    expect(animations.count) == 1
    expect(try unwrap(unwrap(animations.first).fromValue as? Float)).to(beApproximatelyEqual(to: 0.6, within: 1e-6))

    // the position animation is untouched
    expect(layer.animation(forKey: "position.x")) != nil
  }

  func test_delayedTransition_releasedLayer() {
    var layer: CALayer? = CALayer()

    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 1, delay: 0.05))
    transition.remove?.animate(
      renderable: .layer(layer!), // swiftlint:disable:this force_unwrapping
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // releasing the layer during the delay window is a no-op when the delay fires
    weak var weakLayer = layer
    layer = nil
    expect(weakLayer) == nil

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
    weakLayer = nil
  }

  func test_retarget_springTiming_matchesVelocity() throws {
    let layer = CALayer()
    layer.opacity = 1

    // an insertion halfway through a 10s linear fade: value 0.5, rising at +0.1 per second
    addInFlightAdditiveAnimation(to: layer, from: -1, progress: 0.5)

    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .spring())
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    let animations = opacityAnimations(on: layer)
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

  func test_retarget_springTiming_speedScalesVelocity() throws {
    let layer = CALayer()
    layer.opacity = 1

    // an insertion halfway through a 10s linear fade: value 0.5, rising at +0.1 per second
    addInFlightAdditiveAnimation(to: layer, from: -1, progress: 0.5)

    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .spring(speed: 2))
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    // the spring plays in a time space running at 2x, so the initial velocity halves to produce
    // the same wall-clock rate: -0.1/s over a delta of 0.5, divided by the speed of 2
    let spring = try unwrap(opacityAnimations(on: layer).first as? CASpringAnimation)
    expect(spring.initialVelocity).to(beApproximatelyEqual(to: -0.1, within: 0.01))
  }

  func test_retarget_springTiming_tinyDelta_dropsVelocity() throws {
    let layer = CALayer()
    layer.opacity = 0

    // an in-flight animation whose composed value is within 1% of the target: the normalized velocity
    // would diverge over the tiny distance, so the velocity carry is dropped
    addInFlightAdditiveAnimation(to: layer, from: 0.01, progress: 0.5)

    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .spring())
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    let spring = try unwrap(opacityAnimations(on: layer).first as? CASpringAnimation)
    expect(spring.initialVelocity) == 0
  }

  func test_retarget_springTiming_freshStart_keepsConfiguredVelocity() throws {
    let layer = CALayer()
    layer.opacity = 1

    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .spring(initialVelocity: 3))
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    let spring = try unwrap(opacityAnimations(on: layer).first as? CASpringAnimation)
    expect(spring.initialVelocity) == 3
  }

  func test_retarget_springTiming_zeroDelta_keepsConfiguredVelocity() throws {
    let layer = CALayer()
    layer.opacity = 0

    // an in-flight animation whose composed value equals the target: velocity matching is skipped
    addInFlightAdditiveAnimation(to: layer, from: 0, progress: 0.5)

    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .spring())
    try unwrap(transition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )

    let spring = try unwrap(opacityAnimations(on: layer).first as? CASpringAnimation)
    expect(spring.initialVelocity) == 0
  }

  func test_delayedFreshInsert_hidesLayerDuringDelay() {
    let layer = CALayer()
    layer.opacity = 1

    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 1, delay: 0.1))
    transition.insert?.animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: CGRect(x: 0, y: 0, width: 10, height: 10), contentView: nil),
      completion: {}
    )

    // during the delay window, the layer is hidden at the start value with no animation yet
    expect(layer.opacity) == 0
    expect(opacityAnimations(on: layer).count) == 0

    // after the delay, the model is at the target. The animation itself is not asserted because Core Animation drops
    // animations on layers outside of a layer tree when a transaction commits, and waiting for the delay pumps the run
    // loop. The non-delayed tests cover the added animation.
    expect(layer.opacity).toEventually(beEqual(to: 1))
  }

  func test_delayedInsert_withInFlightAnimation_keepsCurrentModelDuringDelay() {
    let layer = CALayer()
    layer.opacity = 0

    // an in-flight removal keeps playing during the delay window, so the model is not touched
    addInFlightAdditiveAnimation(to: layer, from: 1, progress: 0.5)

    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 1, delay: 0.1))
    transition.insert?.animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: CGRect(x: 0, y: 0, width: 10, height: 10), contentView: nil),
      completion: {}
    )

    expect(layer.opacity) == 0
    expect(opacityAnimations(on: layer).count) == 1

    // after the delay, the model is at the target. The animation itself is not asserted because Core Animation drops
    // animations on layers outside of a layer tree when a transaction commits, and waiting for the delay pumps the run
    // loop. The non-delayed tests cover the added animation.
    expect(layer.opacity).toEventually(beEqual(to: 1))
  }

  func test_delayedRetarget_supersededByNewRetarget_doesNotFire() throws {
    let layer = CALayer()
    layer.opacity = 0

    // an in-flight removal, halfway through
    addInFlightAdditiveAnimation(to: layer, from: 1, progress: 0.5)

    // a delayed insert schedules its retarget for after the delay window
    var insertCompletionCallCount = 0
    let insertTransition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 1, delay: 0.1))
    insertTransition.insert?.animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: CGRect(x: 0, y: 0, width: 10, height: 10), contentView: nil),
      completion: { insertCompletionCallCount += 1 }
    )

    // a remove interrupts during the delay window, superseding the pending insert retarget
    let removeTransition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 5))
    try unwrap(removeTransition.remove).animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: {}
    )
    expect(layer.opacity) == 0
    expect(opacityAnimations(on: layer).count) == 1

    // past the delay window, the superseded insert retarget must not fire: it would tear down the remove's
    // animation, complete the removal with stale values, and set the model to its own target (1).
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.25))
    expect(layer.opacity) == 0
    expect(insertCompletionCallCount) == 0
  }

  func test_delayedRetarget_cancelledByResetForReuse_doesNotFire() throws {
    let layer = CALayer()
    layer.opacity = 1

    // a delayed remove schedules its retarget for after the delay window
    var removeCompletionCallCount = 0
    let transition = RenderableTransition.opacity(from: 0, to: 1, timing: .linear(duration: 1, delay: 0.1))
    let removeTransition = try unwrap(transition.remove)
    removeTransition.animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: nil),
      completion: { removeCompletionCallCount += 1 }
    )

    // the renderable is reset during the delay window (e.g. recycled to the pool, or revived without an insert
    // transition), cancelling the pending retarget
    removeTransition.resetForReuse(renderable: .layer(layer))
    expect(layer.opacity) == 1

    // past the delay window, the cancelled remove retarget must not fire: it would fade the reset renderable
    // towards its own target (0).
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.25))
    expect(layer.opacity) == 1
    expect(opacityAnimations(on: layer).count) == 0
    expect(removeCompletionCallCount) == 0
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

  private func opacityAnimations(on layer: CALayer) -> [CABasicAnimation] {
    (layer.animationKeys() ?? []).compactMap { key in
      guard let animation = layer.animation(forKey: key) as? CABasicAnimation, animation.keyPath == "opacity" else {
        return nil
      }
      return animation
    }
  }
}
