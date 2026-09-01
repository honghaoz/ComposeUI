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

  func test_animateFrame() throws {
    // given: a layer hosted in a window, filling the window bounds
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.frame = testWindow.layer.bounds

    expect(layer.frame) == CGRect(x: 0, y: 0, width: 500, height: 500)

    // when: animating the frame
    layer.animateFrame(to: CGRect(x: 100, y: 100, width: 50, height: 50), timing: .easeInEaseOut(duration: 1))

    // then: additive position and bounds.size animations are added with the expected values and timing
    expect(layer.animationKeys()) == ["position", "bounds.size"]

    let positionAnimation = try (layer.animation(forKey: "position") as? CABasicAnimation).unwrap()
    expect(positionAnimation.fromValue as? CGPoint) == CGPoint(x: 125, y: 125)
    expect(positionAnimation.toValue as? CGPoint) == .zero
    expect(positionAnimation.timingFunction) == CAMediaTimingFunction(name: .easeInEaseOut)
    expect(positionAnimation.duration) == 1
    expect(positionAnimation.isAdditive) == true
    expect(positionAnimation.isRemovedOnCompletion) == true
    expect(positionAnimation.fillMode) == .both

    let boundsSizeAnimation = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(boundsSizeAnimation.fromValue as? CGSize) == CGSize(width: 450, height: 450)
    expect(boundsSizeAnimation.toValue as? CGSize) == .zero
    expect(boundsSizeAnimation.timingFunction) == CAMediaTimingFunction(name: .easeInEaseOut)
    expect(boundsSizeAnimation.duration) == 1
    expect(boundsSizeAnimation.isAdditive) == true
    expect(boundsSizeAnimation.isRemovedOnCompletion) == true
    expect(boundsSizeAnimation.fillMode) == .both
  }

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

    let now = layer.convertTime(CACurrentMediaTime(), from: nil)
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

    let now = layer.convertTime(CACurrentMediaTime(), from: nil)
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
    let layerNow = layer.convertTime(CACurrentMediaTime(), from: nil)
    expect(animation.beginTime - layerNow).to(beApproximatelyEqual(to: 0.5, within: 0.1))
    expect(abs(animation.beginTime - (CACurrentMediaTime() + 0.5))).toNot(beApproximatelyEqual(to: 0, within: 1))
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

  func test_animate_delayed_holdsFromValueDuringDelayWindow() throws {
    // given: a layer hosted in a window with partial opacity
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    layer.opacity = 0.2
    CATransaction.flush()

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

  // MARK: - setKeyPathValue

  func test_setKeyPathValue_position() throws {
    // given: a test window with a container view
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    #if os(macOS)
    // given: a layer-backed view with a centered anchor point
    do {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = view.layer()
      layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
      layer.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      view.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      expect(layer.position) == CGPoint(x: 150, y: 225)

      // when: setting the position key path value
      layer.setKeyPathValue("position", CGPoint(x: 180, y: 250)) // x: 30, y: 25

      // then: the layer frame moves and the view frame follows
      expect(layer.frame) == CGRect(x: 130, y: 225, width: 100, height: 50)
      expect(view.frame) == layer.frame
    }

    // given: a layer-hosted view with a centered anchor point
    do {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = CALayer()
      view.layer = CALayer()
      layer.delegate = view as? CALayerDelegate
      layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
      layer.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      view.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      expect(layer.position) == CGPoint(x: 150, y: 225)

      // when: setting the position key path value
      layer.setKeyPathValue("position", CGPoint(x: 180, y: 250)) // x: 30, y: 25

      // then: the layer frame moves and the view frame follows
      expect(layer.frame) == CGRect(x: 130, y: 225, width: 100, height: 50)
      expect(view.frame) == layer.frame
    }
    #endif

    #if canImport(UIKit)
    // given: a view in the container view
    let view = UIView(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    containerView.addSubview(view)
    let layer = view.layer

    // when: setting the position key path value
    layer.setKeyPathValue("position", CGPoint(x: 10, y: 20))

    // then: the layer position is updated
    expect(layer.position) == CGPoint(x: 10, y: 20)
    #endif
  }

  func test_setKeyPathValue_bounds_size() throws {
    // given: a test window with a container view
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    #if os(macOS)
    // given: a layer-backed view
    do {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = view.layer()
      layer.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      view.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      expect(layer.bounds.size) == CGSize(width: 100, height: 50)

      // when: setting the bounds.size key path value
      layer.setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))

      // then: the layer bounds and frame are updated and the view follows
      expect(layer.bounds.size) == CGSize(width: 150, height: 80)
      expect(view.bounds.size) == layer.bounds.size
      expect(layer.frame) == CGRect(x: 100, y: 200, width: 150, height: 80)
      expect(view.frame) == layer.frame
    }

    // given: a layer-hosted view
    do {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = CALayer()
      view.layer = layer
      layer.delegate = view as? CALayerDelegate
      layer.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      view.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      expect(layer.bounds.size) == CGSize(width: 100, height: 50)

      // when: setting the bounds.size key path value
      layer.setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))

      // then: the layer bounds and frame are updated and the view follows
      expect(layer.bounds.size) == CGSize(width: 150, height: 80)
      expect(view.bounds.size) == layer.bounds.size
      expect(layer.frame) == CGRect(x: 100, y: 200, width: 150, height: 80)
      expect(view.frame) == layer.frame
    }
    #endif

    #if canImport(UIKit)
    // given: a view in the container view
    let view = UIView(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    expect(layer.bounds.size) == CGSize(width: 100, height: 50)

    // when: setting the bounds.size key path value
    layer.setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))

    // then: the layer bounds and frame are updated and the view follows
    expect(layer.bounds.size) == CGSize(width: 150, height: 80)
    expect(view.bounds.size) == layer.bounds.size
    expect(view.frame) == CGRect(x: 75, y: 185, width: 150, height: 80)
    expect(view.frame) == layer.frame
    #endif
  }

  func test_setKeyPathValue_anchorPoint() throws {
    // given: a test window with a container view
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    // given: a plain layer, testing layer's behavior by changing anchor point
    do {
      let layer = CALayer()
      layer.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      expect(layer.anchorPoint) == CGPoint(x: 0.5, y: 0.5)

      // when: setting the anchorPoint key path value
      layer.setKeyPathValue("anchorPoint", CGPoint(x: 0, y: 0))

      // then: the frame moves to keep the anchor point position in parent the same
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0) // anchor point doesn't change
      expect(layer.frame) == CGRect(x: 225, y: 175, width: 50, height: 50)
    }

    #if os(macOS)
    // given: a layer-backed view
    do {
      let view = View(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = view.layer()
      layer.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      view.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0) // default for macOS

      // when: setting the anchorPoint key path value
      layer.setKeyPathValue("anchorPoint", CGPoint(x: 0.5, y: 0.5))

      // then: the frame moves to keep the anchor point position in parent the same
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0) // anchor point doesn't change
      expect(layer.frame) == CGRect(x: 175, y: 125, width: 50, height: 50)
      expect(view.frame) == layer.frame
    }

    // given: a layer-hosted view
    do {
      let view = View(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = CALayer()
      view.layer = layer
      layer.delegate = view as? CALayerDelegate
      layer.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      view.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0) // default for macOS

      // when: setting the anchorPoint key path value
      layer.setKeyPathValue("anchorPoint", CGPoint(x: 0.5, y: 0.5))

      // then: the frame moves to keep the anchor point position in parent the same
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0) // anchor point doesn't change
      expect(layer.frame) == CGRect(x: 175, y: 125, width: 50, height: 50)
      expect(view.frame) == layer.frame
    }
    #endif

    #if canImport(UIKit)
    // given: a view in the container view
    let view = UIView(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    expect(layer.anchorPoint) == CGPoint(x: 0.5, y: 0.5) // default for iOS

    // when: setting the anchorPoint key path value
    layer.setKeyPathValue("anchorPoint", CGPoint(x: 0, y: 0))

    // then: the anchor point is updated and the frame moves to keep the anchor point position in parent the same
    expect(layer.anchorPoint) == CGPoint(x: 0, y: 0)
    expect(layer.frame) == CGRect(x: 225, y: 175, width: 50, height: 50)
    expect(view.frame) == layer.frame
    #endif
  }

  func test_setKeyPathValue_opacity() throws {
    // given: a test window with a container view
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    #if os(macOS)
    // given: a layer-backed view with full opacity
    do {
      let view = View(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = view.layer()
      expect(layer.opacity) == 1.0
      expect(view.alpha) == 1.0

      // when: setting the opacity key path value
      layer.setKeyPathValue("opacity", Float(0.7))

      // then: the layer opacity is updated and the view alpha matches
      expect(layer.opacity) == 0.7
      expect(view.alpha) == CGFloat(layer.opacity) // view alpha should match layer opacity
    }

    // given: a layer-hosted view with full opacity
    do {
      let view = View(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = CALayer()
      view.layer = layer
      layer.delegate = view as? CALayerDelegate
      expect(layer.opacity) == 1.0
      expect(view.alpha) == 1.0
      expect(layer.backedView) === view

      // when: setting the opacity key path value
      layer.setKeyPathValue("opacity", Float(0.3))

      // then: the layer opacity is updated and the view alpha matches
      expect(layer.opacity) == 0.3
      expect(view.alpha) == CGFloat(layer.opacity) // view alpha should match layer opacity
    }
    #endif

    #if canImport(UIKit)
    // given: a view with full opacity in the container view
    let view = UIView(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    expect(layer.opacity) == 1.0
    expect(view.alpha) == 1.0

    // when: setting the opacity key path value
    layer.setKeyPathValue("opacity", Float(0.8))

    // then: the layer opacity is updated and the view alpha matches
    expect(layer.opacity) == 0.8
    expect(view.alpha) == CGFloat(layer.opacity) // view alpha should match layer opacity
    #endif
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

    // when: querying basic animations for the opacity key path
    let animations = layer.basicAnimations(forKeyPath: "opacity")

    // then: only the basic opacity animation matches
    expect(animations.count) == 1
    expect(animations.first?.keyPath) == "opacity"
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

    // when: removing animations for the opacity key path
    layer.removeAnimations(forKeyPath: "opacity")

    // then: both opacity animations are removed and the other key path animation survives
    expect(layer.animation(forKey: "fade")) == nil
    expect(layer.animation(forKey: "keyframe-fade")) == nil
    expect(layer.animation(forKey: "spin")) != nil
  }
}
