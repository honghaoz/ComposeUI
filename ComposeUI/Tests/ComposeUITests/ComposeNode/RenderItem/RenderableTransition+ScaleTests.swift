//
//  RenderableTransition+ScaleTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/1/26.
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

class RenderableTransition_ScaleTests: XCTestCase {

  // MARK: - Insert Transition

  func test_insertTransition() throws {
    // given: a layer renderable and a scale-in transition
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let targetFrame = Constants.targetFrame
    let layer = TestLayer()
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.scale(timing: Constants.timing, options: .insert)

    let insertTransition = try transition.insert.unwrap()
    let context = RenderableTransition.InsertTransition.Context(targetFrame: targetFrame, contentView: contentView)

    // when: the insert transition animates the renderable
    insertTransition.animate(renderable: renderable, context: context, completion: {})

    // then: the layer lands at the target frame with an additive scale animation growing in from 0
    expect(insertTransition.takesOverKeyPaths) == ["transform.scale", "transform.translation"]
    expect(layer.capturedFrame) == targetFrame
    expect(try CATransform3DIsIdentity(layer.capturedTransform.unwrap())) == true

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(layer.addedAnimationKey) == "transform.scale"
    expect(layer.animationKeys()) == ["transform.scale"]
    expect(animation.keyPath) == "transform.scale"
    expect(animation.fromValue as? CGFloat) == -1
    expect(animation.toValue as? CGFloat) == 0
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(animation.duration) == Constants.duration
    expect(animation.isAdditive) == true
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both

    // then: the model transform rests at identity
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  func test_insertTransition_customFrom() throws {
    // given: a layer renderable and a scale-in transition zooming down from 1.5
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let targetFrame = Constants.targetFrame
    let layer = TestLayer()
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.scale(from: 1.5, timing: Constants.timing, options: .insert)

    // when: the insert transition animates the renderable
    let context = RenderableTransition.InsertTransition.Context(targetFrame: targetFrame, contentView: contentView)
    try transition.insert.unwrap().animate(renderable: renderable, context: context, completion: {})

    // then: the additive scale animation starts from the custom scale's offset
    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(animation.fromValue as? CGFloat) == 0.5
    expect(animation.toValue as? CGFloat) == 0
    expect(layer.frame) == targetFrame
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  func test_insertTransition_revival_continuesFromRevivalTransform() throws {
    // given: a layer mid-removal in the framework flow: the model transform is already reset to identity, with a
    // leftover additive scale animation attached and the removal's model scale captured in the revival transform
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let targetFrame = Constants.targetFrame
    let layer = TestLayer()

    let leftoverAnimation = CABasicAnimation(keyPath: "transform.scale")
    leftoverAnimation.fromValue = CGFloat(1) - Constants.revivalScale
    leftoverAnimation.toValue = CGFloat(0)
    leftoverAnimation.duration = 10
    leftoverAnimation.isAdditive = true
    layer.add(leftoverAnimation, forKey: "transform.scale")

    // the framework applies the target frame as the model value before the transition runs
    layer.frame = targetFrame

    // when: an insert transition animates with a revival transform
    let transition = RenderableTransition.scale(timing: Constants.timing, options: .insert)
    let revivalScale = Constants.revivalScale
    try transition.insert.unwrap().animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(
        targetFrame: targetFrame,
        revivalTransform: CATransform3DMakeScale(revivalScale, revivalScale, revivalScale),
        contentView: contentView
      ),
      completion: {}
    )

    // then: the revival keeps the leftover animation and anchors its own offset to the removal's model scale,
    // cancelling the model change, so the renderable continues from the removal's scale instead of the configured
    // `from` scale
    expect(layer.frame) == targetFrame
    expect(layer.basicAnimations(forKeyPath: "transform.scale").count) == 2

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(animation.fromValue as? CGFloat) == revivalScale - 1
    expect(animation.toValue as? CGFloat) == 0
    expect(animation.isAdditive) == true
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  func test_insertTransition_revival_directInvocation_restoresModelScale() throws {
    // given: a layer mid-removal invoked directly: the model transform still carries the removal's scale, with a
    // leftover additive scale animation attached
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let targetFrame = Constants.targetFrame
    let layer = TestLayer()

    let leftoverAnimation = CABasicAnimation(keyPath: "transform.scale")
    leftoverAnimation.fromValue = CGFloat(1) - Constants.revivalScale
    leftoverAnimation.toValue = CGFloat(0)
    leftoverAnimation.duration = 10
    leftoverAnimation.isAdditive = true
    layer.add(leftoverAnimation, forKey: "transform.scale")

    layer.setValue(Constants.revivalScale, forKeyPath: "transform.scale")

    // when: an insert transition animates with a revival transform
    let transition = RenderableTransition.scale(timing: Constants.timing, options: .insert)
    let revivalScale = Constants.revivalScale
    try transition.insert.unwrap().animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(
        targetFrame: targetFrame,
        revivalTransform: CATransform3DMakeScale(revivalScale, revivalScale, revivalScale),
        contentView: contentView
      ),
      completion: {}
    )

    // then: the model scale is restored to identity before the frame applies, so the frame application is well-defined,
    // and the additive offset continues from the removal's scale
    expect(layer.frame) == targetFrame
    expect(CATransform3DIsIdentity(layer.transform)) == true
    expect(layer.basicAnimations(forKeyPath: "transform.scale").count) == 2

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(animation.fromValue as? CGFloat) == revivalScale - 1
    expect(animation.toValue as? CGFloat) == 0
  }

  func test_insertTransition_zeroDuration_appliesTargetAndCompletes() throws {
    // given: a layer renderable and a zero-duration scale-in transition
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let layer = TestLayer()
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.scale(timing: .linear(duration: 0), options: .insert)

    // when: the insert transition animates the renderable
    var completionCallCount = 0
    try transition.insert.unwrap().animate(
      renderable: renderable,
      context: RenderableTransition.InsertTransition.Context(targetFrame: Constants.targetFrame, contentView: contentView),
      completion: { completionCallCount += 1 }
    )

    // then: the target frame applies and the transition completes immediately, with no animation added
    expect(layer.frame) == Constants.targetFrame
    expect(layer.animationKeys()) == nil
    expect(CATransform3DIsIdentity(layer.transform)) == true
    expect(completionCallCount) == 1
  }

  func test_insertTransition_zeroDurationRevival_clearsLeftoverAndSnapsToRest() throws {
    // given: a layer mid-removal invoked directly: the model transform still carries the removal's scale, with a
    // leftover additive scale animation attached
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let targetFrame = Constants.targetFrame
    let layer = TestLayer()

    let leftoverAnimation = CABasicAnimation(keyPath: "transform.scale")
    leftoverAnimation.fromValue = CGFloat(1) - Constants.revivalScale
    leftoverAnimation.toValue = CGFloat(0)
    leftoverAnimation.duration = 10
    leftoverAnimation.isAdditive = true
    layer.add(leftoverAnimation, forKey: "transform.scale")

    layer.setValue(Constants.revivalScale, forKeyPath: "transform.scale")

    // when: a zero-duration insert transition animates with a revival transform
    let transition = RenderableTransition.scale(timing: .linear(duration: 0), options: .insert)
    let revivalScale = Constants.revivalScale

    var completionCallCount = 0
    try transition.insert.unwrap().animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(
        targetFrame: targetFrame,
        revivalTransform: CATransform3DMakeScale(revivalScale, revivalScale, revivalScale),
        contentView: contentView
      ),
      completion: { completionCallCount += 1 }
    )

    // then: the leftover animations are cleared and the renderable snaps to rest at its natural size
    // the snap clears the taken-over leftover animations, so the renderable lands at rest at the target instead of
    // rendering off it until the leftover decays
    expect(layer.frame) == targetFrame
    expect(layer.basicAnimations(forKeyPath: "transform.scale").count) == 0
    expect(CATransform3DIsIdentity(layer.transform)) == true
    expect(completionCallCount) == 1
  }

  func test_insertTransition_delayedRevival_holdsAndKeepsLeftover() throws {
    // given: a layer mid-removal in the framework flow, with a leftover additive scale animation attached
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let targetFrame = Constants.targetFrame
    let layer = TestLayer()

    let leftoverAnimation = CABasicAnimation(keyPath: "transform.scale")
    leftoverAnimation.fromValue = CGFloat(1) - Constants.revivalScale
    leftoverAnimation.toValue = CGFloat(0)
    leftoverAnimation.duration = 10
    leftoverAnimation.isAdditive = true
    layer.add(leftoverAnimation, forKey: "transform.scale")

    layer.frame = targetFrame

    // when: a delayed insert transition animates with a revival transform
    let transition = RenderableTransition.scale(timing: .linear(duration: Constants.duration, delay: 0.5), options: .insert)
    let revivalScale = Constants.revivalScale
    try transition.insert.unwrap().animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(
        targetFrame: targetFrame,
        revivalTransform: CATransform3DMakeScale(revivalScale, revivalScale, revivalScale),
        contentView: contentView
      ),
      completion: {}
    )

    // then: the leftover animation is kept and the scheduled insert offset holds the revival scale
    // the leftover keeps playing during the delay window while the scheduled insert offset holds the revival scale
    // through its fill mode, so the composed motion stays continuous until the insert begins
    expect(layer.basicAnimations(forKeyPath: "transform.scale").count) == 2

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(animation.fromValue as? CGFloat) == revivalScale - 1
    expect(animation.toValue as? CGFloat) == 0
    expect(animation.isAdditive) == true
    expect(animation.fillMode) == .both

    let now = layer.convertTime(CACurrentMediaTime(), from: nil)
    expect(animation.beginTime - now).to(beApproximatelyEqual(to: 0.5, within: 0.1))
  }

  // MARK: - Remove Transition

  func test_removeTransition() throws {
    // given: a layer at its natural size and a scale-out transition
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let currentFrame = Constants.targetFrame
    let layer = TestLayer()
    layer.frame = currentFrame
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.scale(timing: Constants.timing, options: .remove)

    let removeTransition = try transition.remove.unwrap()
    let context = RenderableTransition.RemoveTransition.Context(contentView: contentView)

    // the position is captured before the removal writes a non-identity model transform, because reading a
    // frame-derived position requires an identity transform
    let positionBeforeRemoval = layer.position

    // when: the remove transition animates the renderable
    removeTransition.animate(renderable: renderable, context: context, completion: {})

    // then: the model scale becomes the removal's end scale with an additive animation holding the rendered scale,
    // decaying from the current scale
    expect(removeTransition.animatedKeyPaths) == ["transform.scale", "transform.translation"]
    expect(layer.capturedFrame) == currentFrame
    expect(try CATransform3DIsIdentity(layer.capturedTransform.unwrap())) == true

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(layer.addedAnimationKey) == "transform.scale"
    expect(layer.animationKeys()) == ["transform.scale"]
    expect(animation.keyPath) == "transform.scale"
    expect(animation.fromValue as? CGFloat) == 1
    expect(animation.toValue as? CGFloat) == 0
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(animation.duration) == Constants.duration
    expect(animation.isAdditive) == true
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both

    // then: the model holds the end scale so the layer stays at the end scale when the animation is removed, and the
    // layout-owned bounds and position are untouched
    expect(layer.value(forKeyPath: "transform.scale") as? CGFloat) == 0
    expect(layer.bounds.size) == currentFrame.size
    expect(layer.position) == positionBeforeRemoval
  }

  func test_removeTransition_customFrom() throws {
    // given: a layer at its natural size and a scale-out transition removing to 0.5
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let layer = TestLayer()
    layer.frame = Constants.targetFrame
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.scale(from: 0.5, timing: Constants.timing, options: .remove)

    // when: the remove transition animates the renderable
    let context = RenderableTransition.RemoveTransition.Context(contentView: contentView)
    try transition.remove.unwrap().animate(renderable: renderable, context: context, completion: {})

    // then: the additive animation decays the current scale's offset to the custom end scale
    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(animation.fromValue as? CGFloat) == 0.5
    expect(animation.toValue as? CGFloat) == 0
    expect(layer.value(forKeyPath: "transform.scale") as? CGFloat) == 0.5
  }

  func test_removeTransition_midInsert_stacksOnInsertResidue() throws {
    // given: a layer with an in-flight additive scale-in animation, the model scale resting at identity
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let layer = TestLayer()
    layer.frame = Constants.targetFrame

    let insertResidue = CABasicAnimation(keyPath: "transform.scale")
    insertResidue.fromValue = CGFloat(-1)
    insertResidue.toValue = CGFloat(0)
    insertResidue.duration = 10
    insertResidue.isAdditive = true
    layer.add(insertResidue, forKey: "transform.scale")

    // when: a remove transition animates the renderable
    let transition = RenderableTransition.scale(timing: Constants.timing, options: .remove)
    let context = RenderableTransition.RemoveTransition.Context(contentView: contentView)
    try transition.remove.unwrap().animate(renderable: .layer(layer), context: context, completion: {})

    // then: the removal stacks its own additive animation on the kept insert residue, anchored to the model scale, so
    // the rendered scale is continuous while both animations settle
    expect(layer.basicAnimations(forKeyPath: "transform.scale").count) == 2

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(animation.fromValue as? CGFloat) == 1
    expect(animation.toValue as? CGFloat) == 0
    expect(layer.value(forKeyPath: "transform.scale") as? CGFloat) == 0
  }

  func test_removeTransition_zeroDuration_appliesEndScaleAndCompletes() throws {
    // given: a layer at its natural size and a zero-duration scale-out transition
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let layer = TestLayer()
    layer.frame = Constants.targetFrame
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.scale(timing: .linear(duration: 0), options: .remove)

    // when: the remove transition animates the renderable
    var completionCallCount = 0
    try transition.remove.unwrap().animate(
      renderable: renderable,
      context: RenderableTransition.RemoveTransition.Context(contentView: contentView),
      completion: { completionCallCount += 1 }
    )

    // then: the end scale applies and the transition completes immediately, with no animation added
    expect(layer.value(forKeyPath: "transform.scale") as? CGFloat) == 0
    expect(layer.animationKeys()) == nil
    expect(completionCallCount) == 1
  }

  func test_removeTransition_delayedZeroDuration_schedulesSnap() throws {
    // given: a layer at its natural size and a delayed zero-duration scale-out transition
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let layer = TestLayer()
    layer.frame = Constants.targetFrame
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.scale(timing: .linear(duration: 0, delay: 0.5), options: .remove)

    // when: the remove transition animates the renderable
    var completionCallCount = 0
    try transition.remove.unwrap().animate(
      renderable: renderable,
      context: RenderableTransition.RemoveTransition.Context(contentView: contentView),
      completion: { completionCallCount += 1 }
    )

    // then: a zero-duration timing with a delay is a scheduled snap
    // the renderable holds its current scale for the delay window, then snaps to the end scale, completing through the
    // animation
    expect(layer.value(forKeyPath: "transform.scale") as? CGFloat) == 0

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(animation.keyPath) == "transform.scale"
    expect(animation.fromValue as? CGFloat) == 1
    expect(animation.duration).to(beApproximatelyEqual(to: 0.001, within: 1e-6))
    expect(completionCallCount) == 0

    let now = layer.convertTime(CACurrentMediaTime(), from: nil)
    expect(animation.beginTime - now).to(beApproximatelyEqual(to: 0.5, within: 0.1))
  }

  func test_removeTransition_resetForReuse() throws {
    // given: a layer with a scale remove transition in flight and an unrelated spin animation
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let layer = TestLayer()
    layer.frame = Constants.targetFrame
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.scale(timing: Constants.timing, options: .remove)

    let removeTransition = try transition.remove.unwrap()
    let context = RenderableTransition.RemoveTransition.Context(contentView: contentView)
    removeTransition.animate(renderable: renderable, context: context, completion: {})
    expect(layer.animationKeys()) == ["transform.scale"]
    expect(layer.value(forKeyPath: "transform.scale") as? CGFloat) == 0

    // an animation the transition didn't add, e.g. a persistent content animation owned by the renderable
    let spinAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    spinAnimation.duration = 60
    layer.add(spinAnimation, forKey: "spin")

    // when: the transition resets the renderable for reuse
    removeTransition.resetForReuse(renderable: renderable)

    // then: the reset removes the scale's in-flight animations, restores the model transform to identity so frame
    // applications on the reused renderable are well-defined, and leaves other animations alone
    expect(layer.animation(forKey: "transform.scale")) == nil
    expect(layer.animation(forKey: "spin")) != nil
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  // MARK: - Center Pivot Compensation

  func test_insertTransition_anchoredLayer_addsCenterPivotCompensation() throws {
    // given: a layer anchored at the bottom left corner, like an AppKit view-backing layer, and a scale-in transition
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let targetFrame = Constants.targetFrame
    let layer = TestLayer()
    layer.anchorPoint = .zero
    let transition = RenderableTransition.scale(timing: Constants.timing, options: .insert)

    // when: the insert transition animates the renderable
    let context = RenderableTransition.InsertTransition.Context(targetFrame: targetFrame, contentView: contentView)
    try transition.insert.unwrap().animate(renderable: .layer(layer), context: context, completion: {})

    // then: the scale animation is paired with a same-timing translation compensation that starts at the center's
    // offset from the anchor and decays to rest, so the rendered scaling pivots about the visual center
    expect(layer.frame) == targetFrame
    expect(layer.basicAnimations(forKeyPath: "transform.scale").count) == 1
    let translationAnimations = layer.basicAnimations(forKeyPath: "transform.translation")
    expect(translationAnimations.count) == 1

    let expectedTranslation = CGSize(width: 0.5 * targetFrame.width, height: 0.5 * targetFrame.height)
    let animation = try unwrap(translationAnimations.first)
    expect(animation.fromValue as? CGSize) == expectedTranslation
    expect(animation.toValue as? CGSize) == .zero
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(animation.duration) == Constants.duration
    expect(animation.isAdditive) == true

    // then: the model transform rests at identity
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  func test_removeTransition_anchoredLayer_addsCenterPivotCompensation() throws {
    // given: a layer anchored at the bottom left corner and a scale-out transition
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let currentFrame = Constants.targetFrame
    let layer = TestLayer()
    layer.anchorPoint = .zero
    layer.frame = currentFrame
    let transition = RenderableTransition.scale(timing: Constants.timing, options: .remove)

    // when: the remove transition animates the renderable
    let context = RenderableTransition.RemoveTransition.Context(contentView: contentView)
    try transition.remove.unwrap().animate(renderable: .layer(layer), context: context, completion: {})

    // then: the model transform holds the end scale and its center-pivot translation, each with an additive animation
    // decaying the current offset, so the miniature shrinks about the visual center and rests there
    let expectedTranslation = CGSize(width: 0.5 * currentFrame.width, height: 0.5 * currentFrame.height)
    expect(layer.value(forKeyPath: "transform.scale") as? CGFloat) == 0
    expect(layer.value(forKeyPath: "transform.translation") as? CGSize) == expectedTranslation

    expect(layer.basicAnimations(forKeyPath: "transform.scale").count) == 1
    let translationAnimations = layer.basicAnimations(forKeyPath: "transform.translation")
    expect(translationAnimations.count) == 1

    let animation = try unwrap(translationAnimations.first)
    expect(animation.fromValue as? CGSize) == CGSize(width: -expectedTranslation.width, height: -expectedTranslation.height)
    expect(animation.toValue as? CGSize) == .zero
    expect(animation.isAdditive) == true
  }

  func test_insertTransition_anchoredRevival_cancelsScaleAndTranslation() throws {
    // given: a layer mid-removal in the framework flow, with leftover scale and translation animations attached and
    // the removal's model transform captured in the revival transform
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let targetFrame = Constants.targetFrame
    let layer = TestLayer()
    layer.anchorPoint = .zero

    let leftoverScale = CABasicAnimation(keyPath: "transform.scale")
    leftoverScale.fromValue = CGFloat(1) - Constants.revivalScale
    leftoverScale.toValue = CGFloat(0)
    leftoverScale.duration = 10
    leftoverScale.isAdditive = true
    layer.add(leftoverScale, forKey: "transform.scale")

    let leftoverTranslation = CABasicAnimation(keyPath: "transform.translation")
    leftoverTranslation.fromValue = CGSize(width: -12, height: -15)
    leftoverTranslation.toValue = CGSize.zero
    leftoverTranslation.duration = 10
    leftoverTranslation.isAdditive = true
    layer.add(leftoverTranslation, forKey: "transform.translation")

    layer.frame = targetFrame

    // the removal's model transform: the end scale with its center-pivot translation
    let revivalScale = Constants.revivalScale
    var revivalTransform = CATransform3DMakeScale(revivalScale, revivalScale, revivalScale)
    revivalTransform.m41 = 12
    revivalTransform.m42 = 15

    // when: an insert transition animates with the revival transform
    let transition = RenderableTransition.scale(timing: Constants.timing, options: .insert)
    try transition.insert.unwrap().animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(
        targetFrame: targetFrame,
        revivalTransform: revivalTransform,
        contentView: contentView
      ),
      completion: {}
    )

    // then: the revival keeps the leftover animations and cancels both model component changes, so the rendered
    // transform is continuous at the revival instant
    let scaleAnimations = layer.basicAnimations(forKeyPath: "transform.scale")
    expect(scaleAnimations.count) == 2
    let translationAnimations = layer.basicAnimations(forKeyPath: "transform.translation")
    expect(translationAnimations.count) == 2

    let insertScale = try unwrap(scaleAnimations.last)
    expect(insertScale.fromValue as? CGFloat) == revivalScale - 1
    expect(insertScale.toValue as? CGFloat) == 0

    let insertTranslation = try unwrap(translationAnimations.last)
    expect(insertTranslation.fromValue as? CGSize) == CGSize(width: 12, height: 15)
    expect(insertTranslation.toValue as? CGSize) == .zero
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  func test_removeTransition_anchoredLayer_zeroDuration_appliesCompensatedEndState() throws {
    // given: a layer anchored at the bottom left corner and a zero-duration scale-out transition removing to 0.5
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let currentFrame = Constants.targetFrame
    let layer = TestLayer()
    layer.anchorPoint = .zero
    layer.frame = currentFrame
    let transition = RenderableTransition.scale(from: 0.5, timing: .linear(duration: 0), options: .remove)

    // when: the remove transition animates the renderable
    var completionCallCount = 0
    try transition.remove.unwrap().animate(
      renderable: .layer(layer),
      context: RenderableTransition.RemoveTransition.Context(contentView: contentView),
      completion: { completionCallCount += 1 }
    )

    // then: the end scale applies together with its center-pivot translation, with no animation added
    let expectedTranslation = CGSize(width: 0.5 * currentFrame.width * 0.5, height: 0.5 * currentFrame.height * 0.5)
    expect(layer.value(forKeyPath: "transform.scale") as? CGFloat) == 0.5
    expect(layer.value(forKeyPath: "transform.translation") as? CGSize) == expectedTranslation
    expect(layer.animationKeys()) == nil
    expect(completionCallCount) == 1
  }

  func test_insertTransition_anchoredLayer_zeroDurationRevival_clearsResidueAndRestoresIdentity() throws {
    // given: a layer mid-removal invoked directly: the model transform carries the removal's scale and translation,
    // with leftover animations on both key paths
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let targetFrame = Constants.targetFrame
    let layer = TestLayer()
    layer.anchorPoint = .zero

    let leftoverScale = CABasicAnimation(keyPath: "transform.scale")
    leftoverScale.fromValue = CGFloat(1) - Constants.revivalScale
    leftoverScale.toValue = CGFloat(0)
    leftoverScale.duration = 10
    leftoverScale.isAdditive = true
    layer.add(leftoverScale, forKey: "transform.scale")

    let leftoverTranslation = CABasicAnimation(keyPath: "transform.translation")
    leftoverTranslation.fromValue = CGSize(width: -12, height: -15)
    leftoverTranslation.toValue = CGSize.zero
    leftoverTranslation.duration = 10
    leftoverTranslation.isAdditive = true
    layer.add(leftoverTranslation, forKey: "transform.translation")

    let revivalScale = Constants.revivalScale
    layer.setValue(revivalScale, forKeyPath: "transform.scale")
    layer.setValue(CGSize(width: 12, height: 15), forKeyPath: "transform.translation")

    var revivalTransform = CATransform3DMakeScale(revivalScale, revivalScale, revivalScale)
    revivalTransform.m41 = 12
    revivalTransform.m42 = 15

    // when: a zero-duration insert transition animates with the revival transform
    let transition = RenderableTransition.scale(timing: .linear(duration: 0), options: .insert)
    var completionCallCount = 0
    try transition.insert.unwrap().animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(
        targetFrame: targetFrame,
        revivalTransform: revivalTransform,
        contentView: contentView
      ),
      completion: { completionCallCount += 1 }
    )

    // then: the leftover animations on both key paths are cleared and the model transform snaps to identity at the
    // target frame
    expect(layer.frame) == targetFrame
    expect(layer.basicAnimations(forKeyPath: "transform.scale").count) == 0
    expect(layer.basicAnimations(forKeyPath: "transform.translation").count) == 0
    expect(CATransform3DIsIdentity(layer.transform)) == true
    expect(completionCallCount) == 1
  }

  func test_removeTransition_anchoredLayer_resetForReuse_restoresIdentity() throws {
    // given: a layer anchored at the bottom left corner with a scale remove transition in flight
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let layer = TestLayer()
    layer.anchorPoint = .zero
    layer.frame = Constants.targetFrame
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.scale(timing: Constants.timing, options: .remove)

    let removeTransition = try transition.remove.unwrap()
    removeTransition.animate(renderable: renderable, context: RenderableTransition.RemoveTransition.Context(contentView: contentView), completion: {})
    expect(layer.basicAnimations(forKeyPath: "transform.scale").count) == 1
    expect(layer.basicAnimations(forKeyPath: "transform.translation").count) == 1

    // when: the transition resets the renderable for reuse
    removeTransition.resetForReuse(renderable: renderable)

    // then: the reset removes both key paths' animations and restores the model transform to identity, clearing the
    // scale and its center-pivot translation
    expect(layer.basicAnimations(forKeyPath: "transform.scale").count) == 0
    expect(layer.basicAnimations(forKeyPath: "transform.translation").count) == 0
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  // MARK: - Anchor

  func test_insertTransition_anchor_mapsToUnitPoints() throws {
    // given: expected pivot compensations for every anchor, for a center-anchored layer scaling in from 0:
    // the compensation is (anchor unit point - 0.5) * target size
    let targetFrame = Constants.targetFrame
    let expectedTranslations: [Layout.Alignment: CGSize] = [
      .center: .zero,
      .left: CGSize(width: -0.5 * targetFrame.width, height: 0),
      .right: CGSize(width: 0.5 * targetFrame.width, height: 0),
      .top: CGSize(width: 0, height: -0.5 * targetFrame.height),
      .bottom: CGSize(width: 0, height: 0.5 * targetFrame.height),
      .topLeft: CGSize(width: -0.5 * targetFrame.width, height: -0.5 * targetFrame.height),
      .topRight: CGSize(width: 0.5 * targetFrame.width, height: -0.5 * targetFrame.height),
      .bottomLeft: CGSize(width: -0.5 * targetFrame.width, height: 0.5 * targetFrame.height),
      .bottomRight: CGSize(width: 0.5 * targetFrame.width, height: 0.5 * targetFrame.height),
    ]

    for anchor in Layout.Alignment.allCases {
      let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
      let layer = TestLayer()
      let transition = RenderableTransition.scale(anchor: anchor, timing: Constants.timing, options: .insert)

      // when: the insert transition animates the renderable
      let context = RenderableTransition.InsertTransition.Context(targetFrame: targetFrame, contentView: contentView)
      try transition.insert.unwrap().animate(renderable: .layer(layer), context: context, completion: {})

      // then: the compensation matches the anchor's unit point, and a zero compensation adds no animation
      let expectedTranslation = try expectedTranslations[anchor].unwrap()
      let translationAnimations = layer.basicAnimations(forKeyPath: "transform.translation")
      if expectedTranslation == .zero {
        expect(translationAnimations.count, "\(anchor)") == 0
      } else {
        expect(translationAnimations.count, "\(anchor)") == 1
        let animation = try unwrap(translationAnimations.first)
        expect(animation.fromValue as? CGSize, "\(anchor)") == expectedTranslation
        expect(animation.toValue as? CGSize, "\(anchor)") == .zero
      }
    }
  }

  func test_removeTransition_anchoredLayer_customAnchor_compensatesTowardsPivot() throws {
    // given: a layer anchored at the top left corner and a scale-out transition pivoting about the bottom right corner
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let currentFrame = Constants.targetFrame
    let layer = TestLayer()
    layer.anchorPoint = .zero
    layer.frame = currentFrame
    let transition = RenderableTransition.scale(anchor: .bottomRight, timing: Constants.timing, options: .remove)

    // when: the remove transition animates the renderable
    let context = RenderableTransition.RemoveTransition.Context(contentView: contentView)
    try transition.remove.unwrap().animate(renderable: .layer(layer), context: context, completion: {})

    // then: the compensation offsets the full anchor-to-pivot distance, keeping the bottom right corner fixed
    let expectedTranslation = CGSize(width: currentFrame.width, height: currentFrame.height)
    expect(layer.value(forKeyPath: "transform.translation") as? CGSize) == expectedTranslation

    let animation = try unwrap(layer.basicAnimations(forKeyPath: "transform.translation").first)
    expect(animation.fromValue as? CGSize) == CGSize(width: -expectedTranslation.width, height: -expectedTranslation.height)
    expect(animation.toValue as? CGSize) == .zero
  }

  func test_composeViewIntegration_topAnchor_renderedTopEdgeStaysFixed() throws {
    // given: a hosted compose view showing content with a slow top-anchored scale transition
    let window = TestWindow()
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    window.contentView().addSubview(contentView)

    let makeContent: () -> ComposeContent = {
      ColorNode(.red)
        .transition(.scale(anchor: .top, timing: .linear(duration: 10)))
        .frame(width: 100, height: 100)
    }

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    // when: the content is removed with animation and the removal renders mid-flight
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    let layer = try unwrap(contentView.test.removingRenderableMap.values.first?.renderable.layer)
    expect(layer.presentation()).toEventuallyNot(beNil())
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

    // then: the rendered frame stays anchored at the visual top while it shrinks: the top edge and the horizontal
    // center hold still on both platforms, pinning the anchor's top-left-origin unit space
    let frameBefore = try unwrap(layer.presentation()).frame
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
    let frameAfter = try unwrap(layer.presentation()).frame

    expect(frameAfter.height) < frameBefore.height
    expect(abs(frameAfter.minY - frameBefore.minY)).to(beApproximatelyEqual(to: 0, within: 0.5))
    expect(abs(frameAfter.midX - frameBefore.midX)).to(beApproximatelyEqual(to: 0, within: 0.5))
    expect(abs(frameBefore.minY)).to(beApproximatelyEqual(to: 0, within: 0.5))
  }

  func test_composeViewIntegration_bottomRightAnchor_renderedBottomRightCornerStaysFixed() throws {
    // given: a hosted compose view showing content with a slow bottom-right-anchored scale transition
    let window = TestWindow()
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    window.contentView().addSubview(contentView)

    let makeContent: () -> ComposeContent = {
      ColorNode(.red)
        .transition(.scale(anchor: .bottomRight, timing: .linear(duration: 10)))
        .frame(width: 100, height: 100)
    }

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    // when: the content is removed with animation and the removal renders mid-flight
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    let layer = try unwrap(contentView.test.removingRenderableMap.values.first?.renderable.layer)
    expect(layer.presentation()).toEventuallyNot(beNil())
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

    // then: the rendered frame stays anchored at the visual bottom right corner while it shrinks
    let frameBefore = try unwrap(layer.presentation()).frame
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
    let frameAfter = try unwrap(layer.presentation()).frame

    expect(frameAfter.height) < frameBefore.height
    expect(abs(frameAfter.maxX - frameBefore.maxX)).to(beApproximatelyEqual(to: 0, within: 0.5))
    expect(abs(frameAfter.maxY - frameBefore.maxY)).to(beApproximatelyEqual(to: 0, within: 0.5))
    expect(abs(frameBefore.maxX - 100)).to(beApproximatelyEqual(to: 0, within: 0.5))
    expect(abs(frameBefore.maxY - 100)).to(beApproximatelyEqual(to: 0, within: 0.5))
  }

  // MARK: - ComposeView Integration

  func test_composeViewIntegration() throws {
    // given: a compose view with a layer node using a scale-in transition
    let layer = TestLayer()
    let targetSize = Constants.targetFrame.size
    layer.bounds = CGRect(origin: .zero, size: targetSize)

    let composeView = ComposeView {
      LayerNode(layer)
        .alignment(.topLeft)
        .transition(.scale(timing: Constants.timing, options: .insert))
    }

    // when: the view is sized and refreshed with animation
    composeView.frame = CGRect(origin: .zero, size: Constants.contentSize)
    composeView.refresh(animated: true)

    // then: the layer lands at the target frame with an additive scale-in animation
    let expectedTargetFrame = CGRect(origin: .zero, size: targetSize)
    expect(layer.capturedFrame) == expectedTargetFrame

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(layer.addedAnimationKey) == "transform.scale"
    expect(layer.animationKeys()) == ["transform.scale"]
    expect(animation.keyPath) == "transform.scale"
    expect(animation.fromValue as? CGFloat) == -1
    expect(animation.toValue as? CGFloat) == 0
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(animation.duration) == Constants.duration
    expect(animation.isAdditive) == true
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  func test_composeViewIntegration_revival_composesWithInFlightRemoval() throws {
    // given: a compose view showing content with a slow scale transition
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    let makeContent: () -> ComposeContent = {
      ColorNode(.red)
        .transition(.scale(timing: .linear(duration: 10)))
        .frame(width: 100, height: 100)
    }

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    // when: the content is removed with animation
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: the remove transition is in flight: the model scale is the end scale, with a single additive animation
    // holding the rendered scale
    let layer = try unwrap(contentView.test.removingRenderableMap.values.first?.renderable.layer)
    expect(layer.basicAnimations(forKeyPath: "transform.scale").count) == 1
    expect(layer.value(forKeyPath: "transform.scale") as? CGFloat) == 0

    // when: revive the renderable with an animated insert
    // the scale insert takes over the in-flight removal by composing additively with it. the leftover remove animation
    // is kept, the insert stacks its own animation on top, and the insert's starting offset exactly compensates the
    // model scale change, so the rendered scale is continuous at the revival instant.
    contentView.setContent(content: makeContent)
    contentView.refresh(animated: true)

    // then: the insert animation stacks on the kept remove animation, anchored to the removal's model scale
    let animations = layer.basicAnimations(forKeyPath: "transform.scale")
    expect(animations.count) == 2
    expect(CATransform3DIsIdentity(layer.transform)) == true

    let insertAnimation = try unwrap(animations.last)
    expect(insertAnimation.fromValue as? CGFloat) == -1
    expect(insertAnimation.toValue as? CGFloat) == 0
    expect(insertAnimation.isAdditive) == true

    expect(contentView.test.removingRenderableMap.count) == 0
  }

  func test_composeViewIntegration_revivalWithDifferentConfig_continuesFromCapturedRemovalState() throws {
    // given: a compose view showing content with a slow top-left-anchored scale transition
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    contentView.setContent {
      ColorNode(.red)
        .transition(.scale(anchor: .topLeft, timing: .linear(duration: 10)))
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: false)

    // when: the content is removed with animation
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: the removal writes its end state into the model transform: the end scale and the top-left pivot's
    // compensation for the center-anchored layer
    let layer = try unwrap(contentView.test.removingRenderableMap.values.first?.renderable.layer)
    expect(layer.value(forKeyPath: "transform.scale") as? CGFloat) == 0
    expect(layer.value(forKeyPath: "transform.translation") as? CGSize) == CGSize(width: -50, height: -50)

    // when: revive the renderable with a different scale configuration, a 0.5 scale about the center
    // a fresh insert for this configuration would start the scale offset at -0.5 and would add no translation animation
    // at all (a center pivot on a center-anchored layer needs no compensation), so the assertions below can only pass
    // when the insert anchors to the captured removal state instead of the fresh configuration
    contentView.setContent {
      ColorNode(.red)
        .transition(.scale(from: 0.5, timing: .linear(duration: 10)))
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: true)

    // then: the insert cancels the captured removal state on both channels, so the rendered transform is continuous
    let scaleAnimations = layer.basicAnimations(forKeyPath: "transform.scale")
    expect(scaleAnimations.count) == 2
    let insertScale = try unwrap(scaleAnimations.last)
    expect(insertScale.fromValue as? CGFloat) == -1
    expect(insertScale.toValue as? CGFloat) == 0

    let translationAnimations = layer.basicAnimations(forKeyPath: "transform.translation")
    expect(translationAnimations.count) == 2
    let insertTranslation = try unwrap(translationAnimations.last)
    expect(insertTranslation.fromValue as? CGSize) == CGSize(width: -50, height: -50)
    expect(insertTranslation.toValue as? CGSize) == .zero

    // then: the model transform rests at identity
    expect(CATransform3DIsIdentity(layer.transform)) == true
    expect(contentView.test.removingRenderableMap.count) == 0
  }

  func test_composeViewIntegration_revival_renderedScaleIsContinuous() throws {
    // given: a hosted compose view showing content with a slow scale transition
    let window = TestWindow()
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    window.contentView().addSubview(contentView)

    let makeContent: () -> ComposeContent = {
      ColorNode(.red)
        .transition(.scale(timing: .linear(duration: 10)))
        .frame(width: 100, height: 100)
    }

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    // when: the content is removed with animation and then revived mid-flight
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    let layer = try unwrap(contentView.test.removingRenderableMap.values.first?.renderable.layer)

    // let the removal render, so the presentation is mid-flight
    expect(layer.presentation()).toEventuallyNot(beNil())
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
    let scaleBefore = try unwrap(unwrap(layer.presentation()).value(forKeyPath: "transform.scale") as? CGFloat)

    // revive mid-flight and let the revival commit
    contentView.setContent(content: makeContent)
    contentView.refresh(animated: true)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    let scaleAfter = try unwrap(unwrap(layer.presentation()).value(forKeyPath: "transform.scale") as? CGFloat)

    // then: the rendered scale is continuous at the revival: the 10s linear motion drifts a few percent between the
    // samples, far from the near-full-scale jump a restart from the configured `from` scale would show
    expect(abs(scaleAfter - scaleBefore) < 0.15) == true
  }

  func test_composeViewIntegration_scaleRemovalRevivedBySlideInsert_resetsScaleResidue() throws {
    // given: a compose view showing content with a slow scale transition
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    contentView.setContent {
      ColorNode(.red)
        .transition(.scale(timing: .linear(duration: 10)))
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: false)

    // when: the content is removed with animation
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: the scale removal is in flight, with the end scale in the model transform
    let layer = try unwrap(contentView.test.removingRenderableMap.values.first?.renderable.layer)
    expect(layer.basicAnimations(forKeyPath: "transform.scale").count) == 1
    expect(layer.value(forKeyPath: "transform.scale") as? CGFloat) == 0

    // when: revive the renderable with a slide insert
    // the slide insert doesn't take over the scale removal's animated key path, so the scale removal's residue (the
    // in-flight animation and the degenerate model scale) is undone via its `resetForReuse` before the slide insert
    // runs, making the frame application on the revived renderable well-defined
    contentView.setContent {
      ColorNode(.red)
        .transition(.slide(from: .left, timing: .linear(duration: 10)))
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: true)

    // then: the scale residue is fully reset and the slide insert runs fresh
    expect(contentView.test.removingRenderableMap.count) == 0
    expect(layer.basicAnimations(forKeyPath: "transform.scale").count) == 0
    expect(CATransform3DIsIdentity(layer.transform)) == true
    expect(layer.basicAnimations(forKeyPath: "position").count) == 1
    expect(layer.position) == layer.position(from: CGRect(x: 0, y: 0, width: 100, height: 100))
  }

  func test_composeViewIntegration_viewRenderable_centerPivotCompensation() throws {
    // given: a compose view showing a view renderable with a slow scale transition
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    contentView.setContent {
      ViewNode<BaseView>()
        .transition(.scale(timing: .linear(duration: 10)))
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: false)

    // when: the content is removed with animation
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: the anchor point of the view's backing layer drives the compensation
    let layer = try unwrap(contentView.test.removingRenderableMap.values.first?.renderable.layer)
    expect(layer.basicAnimations(forKeyPath: "transform.scale").count) == 1
    #if canImport(AppKit)
    // AppKit anchors view-backing layers at the bottom left corner, so the removal pairs the scale with a center-pivot
    // translation towards the visual center
    expect(layer.anchorPoint) == .zero
    expect(layer.basicAnimations(forKeyPath: "transform.translation").count) == 1
    expect(layer.value(forKeyPath: "transform.translation") as? CGSize) == CGSize(width: 50, height: 50)
    #else
    // UIKit view-backing layers anchor at the center, so no compensation is needed
    expect(layer.anchorPoint) == CGPoint(x: 0.5, y: 0.5)
    expect(layer.basicAnimations(forKeyPath: "transform.translation").count) == 0
    #endif
  }

  func test_composeViewIntegration_anchoredLayer_renderedCenterStaysFixed() throws {
    // given: a hosted compose view showing a bottom-left-anchored layer with a slow scale transition
    let window = TestWindow()
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    window.contentView().addSubview(contentView)

    let layer = TestLayer()
    layer.anchorPoint = .zero
    layer.bounds = CGRect(x: 0, y: 0, width: 100, height: 100)

    let makeContent: () -> ComposeContent = {
      LayerNode(layer)
        .transition(.scale(timing: .linear(duration: 10)))
        .frame(width: 100, height: 100)
    }

    contentView.setContent(content: makeContent)
    contentView.refresh(animated: false)

    // when: the content is removed with animation and the removal renders mid-flight
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    expect(layer.presentation()).toEventuallyNot(beNil())
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

    // then: at any mid-flight moment, the rendered translation offsets the rendered scale about the visual center:
    // translation == (0.5 - anchor) * size * (1 - scale), here (50, 50) * (1 - scale)
    let assertCenterInvariant: () throws -> Void = { [weak layer] in
      let presentation = try unwrap(layer?.presentation())
      let scale = presentation.transform.m11
      let expectedOffset = 50 * (1 - scale)
      expect(scale) < 1
      expect(abs(presentation.transform.m41 - expectedOffset)).to(beApproximatelyEqual(to: 0, within: 0.5))
      expect(abs(presentation.transform.m42 - expectedOffset)).to(beApproximatelyEqual(to: 0, within: 0.5))
    }
    try assertCenterInvariant()

    // then: the invariant still holds later in the animation
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
    try assertCenterInvariant()
  }

  // MARK: - Constants

  private enum Constants {

    static let contentSize = CGSize(width: 200, height: 120)
    static let targetFrame = CGRect(x: 20, y: 30, width: 40, height: 50)
    static let revivalScale: CGFloat = 0.4
    static let duration: TimeInterval = 0.5
    static let timing: AnimationTiming = .linear(duration: duration)
  }
}

private final class TestLayer: CALayer {

  var capturedFrame: CGRect?
  var capturedTransform: CATransform3D?
  var addedAnimation: CAAnimation?
  var addedAnimationKey: String?

  override func add(_ animation: CAAnimation, forKey key: String?) {
    capturedFrame = frame
    capturedTransform = transform
    addedAnimation = animation
    addedAnimationKey = key
    super.add(animation, forKey: key)
  }
}
