//
//  RenderableTransition+SlideTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 2/21/26.
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

class RenderableTransition_SlideTests: XCTestCase {

  // MARK: - Insert Transition

  func test_insertTransition_top() throws {
    // given: a layer renderable and a slide-in transition from the top
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let targetFrame = Constants.targetFrame
    let layer = TestLayer()
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.slide(
      from: .top,
      overshoot: Constants.overshoot,
      timing: Constants.timing,
      options: .insert
    )

    let insertTransition = try transition.insert.unwrap()
    let context = RenderableTransition.InsertTransition.Context(targetFrame: targetFrame, contentView: contentView)

    // when: the insert transition animates the renderable
    insertTransition.animate(renderable: renderable, context: context, completion: {})

    // then: the layer lands at the target frame with an additive position animation sliding in from above
    let expectedInitialFrame = CGRect(
      x: targetFrame.origin.x,
      y: -targetFrame.height - Constants.overshoot,
      width: targetFrame.width,
      height: targetFrame.height
    )
    expect(layer.capturedFrame) == targetFrame

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(layer.addedAnimationKey) == "position"
    expect(layer.animationKeys()) == ["position"]
    expect(animation.keyPath) == "position"
    expect(animation.fromValue as? CGPoint) == layer.position(from: expectedInitialFrame) - layer.position(from: targetFrame)
    expect(animation.toValue as? CGPoint) == .zero
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(animation.duration) == Constants.duration
    expect(animation.isAdditive) == true
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both
  }

  func test_insertTransition_bottom() throws {
    // given: a layer renderable and a slide-in transition from the bottom
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let targetFrame = Constants.targetFrame
    let layer = TestLayer()
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.slide(
      from: .bottom,
      overshoot: Constants.overshoot,
      timing: Constants.timing,
      options: .insert
    )

    let insertTransition = try transition.insert.unwrap()
    let context = RenderableTransition.InsertTransition.Context(targetFrame: targetFrame, contentView: contentView)

    // when: the insert transition animates the renderable
    insertTransition.animate(renderable: renderable, context: context, completion: {})

    // then: the layer lands at the target frame with an additive position animation sliding in from below
    let expectedInitialFrame = CGRect(
      x: targetFrame.origin.x,
      y: Constants.contentSize.height + Constants.overshoot,
      width: targetFrame.width,
      height: targetFrame.height
    )
    expect(layer.capturedFrame) == targetFrame

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(layer.addedAnimationKey) == "position"
    expect(layer.animationKeys()) == ["position"]
    expect(animation.keyPath) == "position"
    expect(animation.fromValue as? CGPoint) == layer.position(from: expectedInitialFrame) - layer.position(from: targetFrame)
    expect(animation.toValue as? CGPoint) == .zero
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(animation.duration) == Constants.duration
    expect(animation.isAdditive) == true
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both
  }

  func test_insertTransition_left() throws {
    // given: a layer renderable and a slide-in transition from the left
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let targetFrame = Constants.targetFrame
    let layer = TestLayer()
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.slide(
      from: .left,
      overshoot: Constants.overshoot,
      timing: Constants.timing,
      options: .insert
    )

    let insertTransition = try transition.insert.unwrap()
    let context = RenderableTransition.InsertTransition.Context(targetFrame: targetFrame, contentView: contentView)

    // when: the insert transition animates the renderable
    insertTransition.animate(renderable: renderable, context: context, completion: {})

    // then: the layer lands at the target frame with an additive position animation sliding in from the left
    let expectedInitialFrame = CGRect(
      x: -targetFrame.width - Constants.overshoot,
      y: targetFrame.origin.y,
      width: targetFrame.width,
      height: targetFrame.height
    )
    expect(layer.capturedFrame) == targetFrame

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(layer.addedAnimationKey) == "position"
    expect(layer.animationKeys()) == ["position"]
    expect(animation.keyPath) == "position"
    expect(animation.fromValue as? CGPoint) == layer.position(from: expectedInitialFrame) - layer.position(from: targetFrame)
    expect(animation.toValue as? CGPoint) == .zero
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(animation.duration) == Constants.duration
    expect(animation.isAdditive) == true
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both
  }

  func test_insertTransition_right() throws {
    // given: a layer renderable and a slide-in transition from the right
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let targetFrame = Constants.targetFrame
    let layer = TestLayer()
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.slide(
      from: .right,
      overshoot: Constants.overshoot,
      timing: Constants.timing,
      options: .insert
    )

    let insertTransition = try transition.insert.unwrap()
    let context = RenderableTransition.InsertTransition.Context(targetFrame: targetFrame, contentView: contentView)

    // when: the insert transition animates the renderable
    insertTransition.animate(renderable: renderable, context: context, completion: {})

    // then: the layer lands at the target frame with an additive position animation sliding in from the right
    let expectedInitialFrame = CGRect(
      x: Constants.contentSize.width + Constants.overshoot,
      y: targetFrame.origin.y,
      width: targetFrame.width,
      height: targetFrame.height
    )
    expect(layer.capturedFrame) == targetFrame

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(layer.addedAnimationKey) == "position"
    expect(layer.animationKeys()) == ["position"]
    expect(animation.keyPath) == "position"
    expect(animation.fromValue as? CGPoint) == layer.position(from: expectedInitialFrame) - layer.position(from: targetFrame)
    expect(animation.toValue as? CGPoint) == .zero
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(animation.duration) == Constants.duration
    expect(animation.isAdditive) == true
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both
  }

  func test_insertTransition_scrolled_startsJustOutsideTheVisibleArea() throws {
    // the visible area spans x 300 to 500 and y 400 to 520 of the content
    let expectedInitialFrames: [(RenderableTransition.SlideSide, CGRect)] = [
      (.top, CGRect(x: 320, y: 400 - Constants.overshoot - 50, width: 40, height: 50)),
      (.bottom, CGRect(x: 320, y: 520 + Constants.overshoot, width: 40, height: 50)),
      (.left, CGRect(x: 300 - Constants.overshoot - 40, y: 430, width: 40, height: 50)),
      (.right, CGRect(x: 500 + Constants.overshoot, y: 430, width: 40, height: 50)),
    ]
    for (side, expectedInitialFrame) in expectedInitialFrames {
      // given: a compose view scrolled into its content, a layer renderable with a target frame in the visible area,
      // and a slide-in transition from the side
      let contentView = Self.makeScrolledContentView()
      let targetFrame = Constants.scrolledTargetFrame
      let layer = TestLayer()
      let transition = RenderableTransition.slide(from: side, overshoot: Constants.overshoot, timing: Constants.timing, options: .insert)
      let context = RenderableTransition.InsertTransition.Context(targetFrame: targetFrame, contentView: contentView)

      // when: the insert transition animates the renderable
      try transition.insert.unwrap().animate(renderable: .layer(layer), context: context, completion: {})

      // then: the layer lands at the target frame, sliding in from just outside the visible area on the side
      expect(layer.capturedFrame) == targetFrame
      let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
      expect(animation.fromValue as? CGPoint) == layer.position(from: expectedInitialFrame) - layer.position(from: targetFrame)
      expect(animation.toValue as? CGPoint) == .zero
      expect(animation.isAdditive) == true
    }
  }

  func test_insertTransition_revival_continuesFromRevivalPosition() throws {
    // given: a layer mid-removal with a leftover animation and the target frame applied as the model value
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let targetFrame = Constants.targetFrame
    let layer = TestLayer()

    // an in-flight removal: the model frame is off-screen right, with a leftover additive animation attached
    let removalFrame = targetFrame.translate(dx: Constants.contentSize.width - targetFrame.minX + Constants.overshoot)
    let leftoverAnimation = CABasicAnimation(keyPath: "position")
    leftoverAnimation.fromValue = layer.position(from: targetFrame) - layer.position(from: removalFrame)
    leftoverAnimation.toValue = CGPoint.zero
    leftoverAnimation.duration = 10
    leftoverAnimation.isAdditive = true
    layer.add(leftoverAnimation, forKey: "position")

    // the framework applies the target frame as the model value before the transition runs
    layer.frame = targetFrame

    // when: an insert transition animates with a revival position
    let transition = RenderableTransition.slide(
      from: .left,
      to: .right,
      overshoot: Constants.overshoot,
      timing: Constants.timing,
      options: .insert
    )
    try transition.insert.unwrap().animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: targetFrame, revivalPosition: layer.position(from: removalFrame), contentView: contentView),
      completion: {}
    )

    // then: the renderable re-enters from the exit side
    // the revival keeps the leftover animation and anchors its own offset to the removal's model position, cancelling
    // the model change, so the renderable re-enters from the exit side
    expect(layer.frame) == targetFrame
    expect(layer.basicAnimations(forKeyPath: "position").count) == 2

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(animation.fromValue as? CGPoint) == layer.position(from: removalFrame) - layer.position(from: targetFrame)
    expect(animation.toValue as? CGPoint) == .zero
    expect(animation.isAdditive) == true
  }

  func test_insertTransition_zeroDurationRevival_clearsLeftoverAndSnapsToTarget() throws {
    // given: a layer mid-removal with a leftover animation and the target frame applied as the model value
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let targetFrame = Constants.targetFrame
    let layer = TestLayer()

    // an in-flight removal: the model frame is off-screen right, with a leftover additive animation attached
    let removalFrame = targetFrame.translate(dx: Constants.contentSize.width - targetFrame.minX + Constants.overshoot)
    let leftoverAnimation = CABasicAnimation(keyPath: "position")
    leftoverAnimation.fromValue = layer.position(from: targetFrame) - layer.position(from: removalFrame)
    leftoverAnimation.toValue = CGPoint.zero
    leftoverAnimation.duration = 10
    leftoverAnimation.isAdditive = true
    layer.add(leftoverAnimation, forKey: "position")

    // the framework applies the target frame as the model value before the transition runs
    layer.frame = targetFrame

    // when: a zero-duration insert transition animates with a revival position
    let transition = RenderableTransition.slide(
      from: .left,
      to: .right,
      overshoot: Constants.overshoot,
      timing: .linear(duration: 0),
      options: .insert
    )

    var completionCallCount = 0
    try transition.insert.unwrap().animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: targetFrame, revivalPosition: layer.position(from: removalFrame), contentView: contentView),
      completion: { completionCallCount += 1 }
    )

    // then: the leftover animations are cleared and the renderable snaps to the target
    // the snap clears the taken-over leftover animations, so the renderable lands at rest at the target instead of
    // rendering off it until the leftover decays
    expect(layer.frame) == targetFrame
    expect(layer.basicAnimations(forKeyPath: "position").count) == 0
    expect(completionCallCount) == 1
  }

  func test_insertTransition_delayedRevival_holdsAndKeepsLeftover() throws {
    // given: a layer mid-removal with a leftover animation and the target frame applied as the model value
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let targetFrame = Constants.targetFrame
    let layer = TestLayer()

    // an in-flight removal: the model frame is off-screen right, with a leftover additive animation attached
    let removalFrame = targetFrame.translate(dx: Constants.contentSize.width - targetFrame.minX + Constants.overshoot)
    let leftoverAnimation = CABasicAnimation(keyPath: "position")
    leftoverAnimation.fromValue = layer.position(from: targetFrame) - layer.position(from: removalFrame)
    leftoverAnimation.toValue = CGPoint.zero
    leftoverAnimation.duration = 10
    leftoverAnimation.isAdditive = true
    layer.add(leftoverAnimation, forKey: "position")

    // the framework applies the target frame as the model value before the transition runs
    layer.frame = targetFrame

    // when: a delayed insert transition animates with a revival position
    let transition = RenderableTransition.slide(
      from: .left,
      to: .right,
      overshoot: Constants.overshoot,
      timing: .linear(duration: Constants.duration, delay: 0.5),
      options: .insert
    )
    try transition.insert.unwrap().animate(
      renderable: .layer(layer),
      context: RenderableTransition.InsertTransition.Context(targetFrame: targetFrame, revivalPosition: layer.position(from: removalFrame), contentView: contentView),
      completion: {}
    )

    // then: the leftover animation is kept and the scheduled insert offset holds the revival position
    // the leftover keeps playing during the delay window while the scheduled insert offset holds the revival
    // position through its fill mode, so the composed motion stays continuous until the insert begins
    expect(layer.basicAnimations(forKeyPath: "position").count) == 2

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(animation.fromValue as? CGPoint) == layer.position(from: removalFrame) - layer.position(from: targetFrame)
    expect(animation.toValue as? CGPoint) == .zero
    expect(animation.isAdditive) == true
    expect(animation.fillMode) == .both

    let now = layer.currentTime
    expect(animation.beginTime - now).to(beApproximatelyEqual(to: 0.5, within: 0.1))
  }

  // MARK: - Remove Transition

  func test_removeTransition_top() throws {
    // given: a layer at its current frame and a slide-out transition towards the top
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let currentFrame = Constants.targetFrame
    let layer = TestLayer()
    layer.frame = currentFrame
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.slide(
      from: .top,
      overshoot: Constants.overshoot,
      timing: Constants.timing,
      options: .remove
    )

    let removeTransition = try transition.remove.unwrap()
    let context = RenderableTransition.RemoveTransition.Context(contentView: contentView)

    // when: the remove transition animates the renderable
    removeTransition.animate(renderable: renderable, context: context, completion: {})

    // then: the layer moves off-screen above with an additive position animation from the current position
    let expectedTargetFrame = CGRect(
      x: currentFrame.origin.x,
      y: -currentFrame.height - Constants.overshoot,
      width: currentFrame.width,
      height: currentFrame.height
    )
    expect(layer.capturedFrame) == currentFrame

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(layer.addedAnimationKey) == "position"
    expect(layer.animationKeys()) == ["position"]
    expect(animation.keyPath) == "position"
    expect(animation.fromValue as? CGPoint) == layer.position(from: currentFrame) - layer.position(from: expectedTargetFrame)
    expect(animation.toValue as? CGPoint) == .zero
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(animation.duration) == Constants.duration
    expect(animation.isAdditive) == true
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both
    expect(layer.frame) == expectedTargetFrame
  }

  func test_removeTransition_bottom() throws {
    // given: a layer at its current frame and a slide-out transition towards the bottom
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let currentFrame = Constants.targetFrame
    let layer = TestLayer()
    layer.frame = currentFrame
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.slide(
      from: .bottom,
      overshoot: Constants.overshoot,
      timing: Constants.timing,
      options: .remove
    )

    let removeTransition = try transition.remove.unwrap()
    let context = RenderableTransition.RemoveTransition.Context(contentView: contentView)

    // when: the remove transition animates the renderable
    removeTransition.animate(renderable: renderable, context: context, completion: {})

    // then: the layer moves off-screen below with an additive position animation from the current position
    let expectedTargetFrame = CGRect(
      x: currentFrame.origin.x,
      y: Constants.contentSize.height + Constants.overshoot,
      width: currentFrame.width,
      height: currentFrame.height
    )
    expect(layer.capturedFrame) == currentFrame

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(layer.addedAnimationKey) == "position"
    expect(layer.animationKeys()) == ["position"]
    expect(animation.keyPath) == "position"
    expect(animation.fromValue as? CGPoint) == layer.position(from: currentFrame) - layer.position(from: expectedTargetFrame)
    expect(animation.toValue as? CGPoint) == .zero
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(animation.duration) == Constants.duration
    expect(animation.isAdditive) == true
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both
    expect(layer.frame) == expectedTargetFrame
  }

  func test_removeTransition_left() throws {
    // given: a layer at its current frame and a slide-out transition towards the left
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let currentFrame = Constants.targetFrame
    let layer = TestLayer()
    layer.frame = currentFrame
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.slide(
      from: .left,
      overshoot: Constants.overshoot,
      timing: Constants.timing,
      options: .remove
    )

    let removeTransition = try transition.remove.unwrap()
    let context = RenderableTransition.RemoveTransition.Context(contentView: contentView)

    // when: the remove transition animates the renderable
    removeTransition.animate(renderable: renderable, context: context, completion: {})

    // then: the layer moves off-screen left with an additive position animation from the current position
    let expectedTargetFrame = CGRect(
      x: -currentFrame.width - Constants.overshoot,
      y: currentFrame.origin.y,
      width: currentFrame.width,
      height: currentFrame.height
    )
    expect(layer.capturedFrame) == currentFrame

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(layer.addedAnimationKey) == "position"
    expect(layer.animationKeys()) == ["position"]
    expect(animation.keyPath) == "position"
    expect(animation.fromValue as? CGPoint) == layer.position(from: currentFrame) - layer.position(from: expectedTargetFrame)
    expect(animation.toValue as? CGPoint) == .zero
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(animation.duration) == Constants.duration
    expect(animation.isAdditive) == true
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both
    expect(layer.frame) == expectedTargetFrame
  }

  func test_removeTransition_right() throws {
    // given: a layer at its current frame and a slide-out transition towards the right
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let currentFrame = Constants.targetFrame
    let layer = TestLayer()
    layer.frame = currentFrame
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.slide(
      from: .right,
      overshoot: Constants.overshoot,
      timing: Constants.timing,
      options: .remove
    )

    let removeTransition = try transition.remove.unwrap()
    let context = RenderableTransition.RemoveTransition.Context(contentView: contentView)

    // when: the remove transition animates the renderable
    removeTransition.animate(renderable: renderable, context: context, completion: {})

    // then: the layer moves off-screen right with an additive position animation from the current position
    let expectedTargetFrame = CGRect(
      x: Constants.contentSize.width + Constants.overshoot,
      y: currentFrame.origin.y,
      width: currentFrame.width,
      height: currentFrame.height
    )
    expect(layer.capturedFrame) == currentFrame

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(layer.addedAnimationKey) == "position"
    expect(layer.animationKeys()) == ["position"]
    expect(animation.keyPath) == "position"
    expect(animation.fromValue as? CGPoint) == layer.position(from: currentFrame) - layer.position(from: expectedTargetFrame)
    expect(animation.toValue as? CGPoint) == .zero
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(animation.duration) == Constants.duration
    expect(animation.isAdditive) == true
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both
    expect(layer.frame) == expectedTargetFrame
  }

  func test_removeTransition_scrolled_endsJustOutsideTheVisibleArea() throws {
    // the visible area spans x 300 to 500 and y 400 to 520 of the content
    let expectedTargetFrames: [(RenderableTransition.SlideSide, CGRect)] = [
      (.top, CGRect(x: 320, y: 400 - Constants.overshoot - 50, width: 40, height: 50)),
      (.bottom, CGRect(x: 320, y: 520 + Constants.overshoot, width: 40, height: 50)),
      (.left, CGRect(x: 300 - Constants.overshoot - 40, y: 430, width: 40, height: 50)),
      (.right, CGRect(x: 500 + Constants.overshoot, y: 430, width: 40, height: 50)),
    ]
    for (side, expectedTargetFrame) in expectedTargetFrames {
      // given: a compose view scrolled into its content, a layer in the visible area, and a slide-out transition
      // towards the side
      let contentView = Self.makeScrolledContentView()
      let currentFrame = Constants.scrolledTargetFrame
      let layer = TestLayer()
      layer.frame = currentFrame
      let transition = RenderableTransition.slide(from: side, overshoot: Constants.overshoot, timing: Constants.timing, options: .remove)
      let context = RenderableTransition.RemoveTransition.Context(contentView: contentView)

      // when: the remove transition animates the renderable
      try transition.remove.unwrap().animate(renderable: .layer(layer), context: context, completion: {})

      // then: the layer slides from its current frame to just outside the visible area on the side
      expect(layer.frame) == expectedTargetFrame
      let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
      expect(animation.fromValue as? CGPoint) == layer.position(from: currentFrame) - layer.position(from: expectedTargetFrame)
      expect(animation.toValue as? CGPoint) == .zero
      expect(animation.isAdditive) == true
    }
  }

  func test_insertTransition_zeroDuration_appliesTargetAndCompletes() throws {
    // given: a layer renderable and a zero-duration slide-in transition
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let layer = TestLayer()
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.slide(
      from: .top,
      overshoot: Constants.overshoot,
      timing: .linear(duration: 0),
      options: .insert
    )

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
    expect(completionCallCount) == 1
  }

  func test_removeTransition_zeroDuration_appliesTargetAndCompletes() throws {
    // given: a layer at its current frame and a zero-duration slide-out transition
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let currentFrame = Constants.targetFrame
    let layer = TestLayer()
    layer.frame = currentFrame
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.slide(
      from: .top,
      overshoot: Constants.overshoot,
      timing: .linear(duration: 0),
      options: .remove
    )

    // when: the remove transition animates the renderable
    var completionCallCount = 0
    try transition.remove.unwrap().animate(
      renderable: renderable,
      context: RenderableTransition.RemoveTransition.Context(contentView: contentView),
      completion: { completionCallCount += 1 }
    )

    // then: the off-screen end frame applies and the transition completes immediately, with no animation added
    let expectedTargetFrame = CGRect(
      x: currentFrame.origin.x,
      y: -currentFrame.height - Constants.overshoot,
      width: currentFrame.width,
      height: currentFrame.height
    )
    expect(layer.frame) == expectedTargetFrame
    expect(layer.animationKeys()) == nil
    expect(completionCallCount) == 1
  }

  func test_removeTransition_delayedZeroDuration_schedulesSnap() throws {
    // given: a layer at its current frame and a delayed zero-duration slide-out transition
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let currentFrame = Constants.targetFrame
    let layer = TestLayer()
    layer.frame = currentFrame
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.slide(
      from: .top,
      overshoot: Constants.overshoot,
      timing: .linear(duration: 0, delay: 0.5),
      options: .remove
    )

    // when: the remove transition animates the renderable
    var completionCallCount = 0
    try transition.remove.unwrap().animate(
      renderable: renderable,
      context: RenderableTransition.RemoveTransition.Context(contentView: contentView),
      completion: { completionCallCount += 1 }
    )

    // then: a zero-duration timing with a delay is a scheduled snap
    // the renderable holds its current frame for the delay window, then snaps off-screen, completing through
    // the animation
    let expectedTargetFrame = CGRect(
      x: currentFrame.origin.x,
      y: -currentFrame.height - Constants.overshoot,
      width: currentFrame.width,
      height: currentFrame.height
    )
    expect(layer.frame) == expectedTargetFrame

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(animation.keyPath) == "position"
    expect(animation.fromValue as? CGPoint) == layer.position(from: currentFrame) - layer.position(from: expectedTargetFrame)
    expect(animation.duration).to(beApproximatelyEqual(to: 0.001, within: 1e-6))
    expect(completionCallCount) == 0

    let now = layer.currentTime
    expect(animation.beginTime - now).to(beApproximatelyEqual(to: 0.5, within: 0.1))
  }

  func test_removeTransition_with_toSide() throws {
    // given: a layer at its current frame and a slide transition entering from the left and leaving towards the bottom
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let currentFrame = Constants.targetFrame
    let layer = TestLayer()
    layer.frame = currentFrame
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.slide(
      from: .left,
      to: .bottom,
      overshoot: Constants.overshoot,
      timing: Constants.timing,
      options: .remove
    )

    let removeTransition = try transition.remove.unwrap()
    let context = RenderableTransition.RemoveTransition.Context(contentView: contentView)

    // when: the remove transition animates the renderable
    removeTransition.animate(renderable: renderable, context: context, completion: {})

    // then: the layer slides out towards the to side, off-screen below
    let expectedTargetFrame = CGRect(
      x: currentFrame.origin.x,
      y: Constants.contentSize.height + Constants.overshoot,
      width: currentFrame.width,
      height: currentFrame.height
    )
    expect(layer.capturedFrame) == currentFrame

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(layer.addedAnimationKey) == "position"
    expect(layer.animationKeys()) == ["position"]
    expect(animation.keyPath) == "position"
    expect(animation.fromValue as? CGPoint) == layer.position(from: currentFrame) - layer.position(from: expectedTargetFrame)
    expect(animation.toValue as? CGPoint) == .zero
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(animation.duration) == Constants.duration
    expect(animation.isAdditive) == true
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both
    expect(layer.frame) == expectedTargetFrame
  }

  func test_removeTransition_resetForReuse() throws {
    // given: a layer with a slide remove transition in flight and an unrelated spin animation
    let contentView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    let layer = TestLayer()
    layer.frame = Constants.targetFrame
    let renderable = Renderable.layer(layer)
    let transition = RenderableTransition.slide(
      from: .top,
      overshoot: Constants.overshoot,
      timing: Constants.timing,
      options: .remove
    )

    let removeTransition = try transition.remove.unwrap()
    let context = RenderableTransition.RemoveTransition.Context(contentView: contentView)
    removeTransition.animate(renderable: renderable, context: context, completion: {})
    expect(layer.animationKeys()) == ["position"]

    // an animation the transition didn't add, e.g. a persistent content animation owned by the renderable
    let spinAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    spinAnimation.duration = 60
    layer.add(spinAnimation, forKey: "spin")

    // when: the transition resets the renderable for reuse
    removeTransition.resetForReuse(renderable: renderable)

    // then: the reset removes the slide's in-flight position animations and leaves other animations alone.
    // the model position isn't restored: it is layout-owned and the next layout pass sets it.
    expect(layer.animation(forKey: "position")) == nil
    expect(layer.animation(forKey: "spin")) != nil
  }

  // MARK: - ComposeView Integration

  func test_composeViewIntegration() throws {
    // given: a compose view with a layer node using a slide-in transition from the right
    let layer = TestLayer()
    let targetSize = Constants.targetFrame.size
    layer.bounds = CGRect(origin: .zero, size: targetSize)

    let composeView = ComposeView {
      LayerNode(layer)
        .alignment(.topLeft)
        .transition(.slide(from: .right, overshoot: Constants.overshoot, timing: Constants.timing, options: .insert))
    }

    // when: the view is sized and refreshed with animation
    composeView.frame = CGRect(origin: .zero, size: Constants.contentSize)
    composeView.refresh(animated: true)

    // then: the layer lands at the target frame with an additive slide-in position animation
    let expectedTargetFrame = CGRect(origin: .zero, size: targetSize)
    let expectedInitialFrame = expectedTargetFrame.translate(dx: Constants.contentSize.width + Constants.overshoot)

    expect(layer.capturedFrame) == expectedTargetFrame

    let animation = try (layer.addedAnimation as? CABasicAnimation).unwrap()
    expect(layer.addedAnimationKey) == "position"
    expect(layer.animationKeys()) == ["position"]
    expect(animation.keyPath) == "position"

    let expectedFromValue = layer.position(from: expectedInitialFrame) - layer.position(from: expectedTargetFrame)
    expect(animation.fromValue as? CGPoint) == expectedFromValue
    expect(animation.toValue as? CGPoint) == .zero
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(animation.duration) == Constants.duration
    expect(animation.isAdditive) == true
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.fillMode) == .both
  }

  func test_composeViewIntegration_layerScrollsIntoView_slidesInFromJustBelowTheVisibleArea() throws {
    // given: a compose view showing a layer 400 pt down its content with a slide-in transition from the bottom, rendered
    // at the top of its content, where the layer is out of view
    let layer = TestLayer()
    layer.bounds = CGRect(origin: .zero, size: Constants.targetFrame.size)
    let composeView = ComposeView {
      VStack(spacing: 0) {
        Spacer(height: 400)
        LayerNode(layer)
          .transition(.slide(from: .bottom, overshoot: Constants.overshoot, timing: Constants.timing, options: .insert))
        Spacer(height: 600)
      }
    }
    composeView.frame = CGRect(origin: .zero, size: Constants.contentSize)
    composeView.refresh(animated: false)
    expect(layer.superlayer) == nil

    // when: the view scrolls the layer into view, so the visible area spans y 380 to 500, and lays out, which renders the
    // scroll and inserts the layer with its transition
    composeView.contentOffset = CGPoint(x: 0, y: 380)
    composeView.setNeedsLayout()
    composeView.layoutIfNeeded()

    // then: the layer slides in from just below the visible area
    let targetFrame = try unwrap(layer.capturedFrame)
    expect(targetFrame.minY) == 400
    let expectedInitialFrame = targetFrame.translate(dy: 500 + Constants.overshoot - targetFrame.minY)
    let animation = try unwrap(layer.addedAnimation as? CABasicAnimation)
    expect(layer.addedAnimationKey) == "position"
    expect(animation.fromValue as? CGPoint) == layer.position(from: expectedInitialFrame) - layer.position(from: targetFrame)
    expect(animation.isAdditive) == true
  }

  func test_composeViewIntegration_nonAnimatedResizesDuringSlideIn_keepTheSlide() throws {
    // given: a compose view sliding in a layer from the bottom over 10 seconds, with frame changes animating over 10
    // seconds
    let composeView = ComposeView(frame: CGRect(origin: .zero, size: Constants.contentSize))
    composeView.setContent {
      Empty()
    }
    composeView.refresh(animated: false)
    var insertedLayer: CALayer?
    func showLayer(height: CGFloat) {
      composeView.setContent {
        ColorNode(.red)
          .transition(.slide(from: .bottom, timing: .linear(duration: 10), options: .insert))
          .animation(.linear(duration: 10))
          .willInsert { renderable, _ in
            insertedLayer = renderable.layer
          }
          .frame(width: 40, height: height)
      }
    }
    showLayer(height: 50)
    composeView.refresh(animated: true)
    let layer = try unwrap(insertedLayer)
    let slide = try unwrap(layer.animation(forKey: "position"))

    // when: a non-animated refresh makes the layer 80 points high while it slides in
    showLayer(height: 80)
    composeView.refresh(animated: false)

    // then: the slide isn't a frame animation, so it keeps going as it is, delegate and all, while the frame is set
    expect(layer.bounds.size) == CGSize(width: 40, height: 80)
    expect(layer.animationKeys()) == ["position"]
    expect(layer.animation(forKey: "position")) === slide

    // when: an animated refresh makes the layer 120 points high, and a non-animated one 60 points high while the resize
    // is in flight
    showLayer(height: 120)
    composeView.refresh(animated: true)
    showLayer(height: 60)
    composeView.refresh(animated: false)

    // then: the resize, which moves the centered layer too, folds into glides of its position and size, and the slide
    // still keeps going as it is
    expect(layer.bounds.size) == CGSize(width: 40, height: 60)
    expect(layer.animation(forKey: "position")) === slide
    expect(Set(layer.animationKeys() ?? [])) == ["position", "position-1", "bounds.size"]
  }

  // MARK: - Helpers

  /// Makes a compose view of `Constants.contentSize` showing 1000 × 1000 content, scrolled to (300, 400), so its visible
  /// area spans x 300 to 500 and y 400 to 520 of the content.
  ///
  /// The view renders again when it scrolls, which sets the content size from the content, so the content is that large
  /// to keep the offset.
  private static func makeScrolledContentView() -> ComposeView {
    let contentView = ComposeView {
      ColorNode(.clear).frame(width: 1000, height: 1000)
    }
    contentView.frame = CGRect(origin: .zero, size: Constants.contentSize)
    contentView.refresh()
    contentView.contentOffset = CGPoint(x: 300, y: 400)
    return contentView
  }

  // MARK: - Constants

  private enum Constants {

    static let contentSize = CGSize(width: 200, height: 120)
    static let targetFrame = CGRect(x: 20, y: 30, width: 40, height: 50)
    static let scrolledTargetFrame = CGRect(x: 320, y: 430, width: 40, height: 50)
    static let overshoot: CGFloat = 12
    static let duration: TimeInterval = 0.5
    static let timing: AnimationTiming = .linear(duration: duration)
  }
}

private final class TestLayer: CALayer {

  var capturedFrame: CGRect?
  var addedAnimation: CAAnimation?
  var addedAnimationKey: String?

  override func add(_ animation: CAAnimation, forKey key: String?) {
    capturedFrame = frame
    addedAnimation = animation
    addedAnimationKey = key
    super.add(animation, forKey: key)
  }
}
