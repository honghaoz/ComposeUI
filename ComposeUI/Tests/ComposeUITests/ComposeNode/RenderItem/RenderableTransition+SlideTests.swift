//
//  RenderableTransition+SlideTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 2/21/26.
//

import QuartzCore

import ChouTiTest

@_spi(Private) @testable import ComposeUI

class RenderableTransition_SlideTests: XCTestCase {

  // MARK: - Insert Transition

  func test_insertTransition_top() throws {
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

    insertTransition.animate(renderable: renderable, context: context, completion: {})

    let expectedInitialFrame = CGRect(
      x: targetFrame.origin.x,
      y: -targetFrame.height - Constants.overshoot,
      width: targetFrame.width,
      height: targetFrame.height
    )
    expect(layer.capturedFrame) == expectedInitialFrame

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

    insertTransition.animate(renderable: renderable, context: context, completion: {})

    let expectedInitialFrame = CGRect(
      x: targetFrame.origin.x,
      y: Constants.contentSize.height + Constants.overshoot,
      width: targetFrame.width,
      height: targetFrame.height
    )
    expect(layer.capturedFrame) == expectedInitialFrame

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

    insertTransition.animate(renderable: renderable, context: context, completion: {})

    let expectedInitialFrame = CGRect(
      x: -targetFrame.width - Constants.overshoot,
      y: targetFrame.origin.y,
      width: targetFrame.width,
      height: targetFrame.height
    )
    expect(layer.capturedFrame) == expectedInitialFrame

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

    insertTransition.animate(renderable: renderable, context: context, completion: {})

    let expectedInitialFrame = CGRect(
      x: Constants.contentSize.width + Constants.overshoot,
      y: targetFrame.origin.y,
      width: targetFrame.width,
      height: targetFrame.height
    )
    expect(layer.capturedFrame) == expectedInitialFrame

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

  // MARK: - Remove Transition

  func test_removeTransition_top() throws {
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

    removeTransition.animate(renderable: renderable, context: context, completion: {})

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

    removeTransition.animate(renderable: renderable, context: context, completion: {})

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

    removeTransition.animate(renderable: renderable, context: context, completion: {})

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

    removeTransition.animate(renderable: renderable, context: context, completion: {})

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

  func test_removeTransition_with_toSide() throws {
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

    removeTransition.animate(renderable: renderable, context: context, completion: {})

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

  // MARK: - ComposeView Integration

  func test_composeViewIntegration() throws {
    let layer = TestLayer()
    let targetSize = Constants.targetFrame.size
    layer.bounds = CGRect(origin: .zero, size: targetSize)

    let composeView = ComposeView {
      LayerNode(layer)
        .alignment(.topLeft)
        .transition(.slide(from: .right, overshoot: Constants.overshoot, timing: Constants.timing, options: .insert))
    }

    composeView.frame = CGRect(origin: .zero, size: Constants.contentSize)
    composeView.refresh(animated: true)

    let expectedTargetFrame = CGRect(origin: .zero, size: targetSize)
    let expectedInitialFrame = expectedTargetFrame.translate(dx: Constants.contentSize.width + Constants.overshoot)

    expect(layer.capturedFrame) == expectedInitialFrame

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

  // MARK: - Constants

  private enum Constants {

    static let contentSize = CGSize(width: 200, height: 120)
    static let targetFrame = CGRect(x: 20, y: 30, width: 40, height: 50)
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
