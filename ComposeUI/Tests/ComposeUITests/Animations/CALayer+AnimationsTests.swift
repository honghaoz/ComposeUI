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
    // given: a layer that counts KVC reads and writes, hosted in a window, filling the window bounds
    let testWindow = TestWindow()

    let layer = KVCCountingLayer()
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

    // then: the model frame is the target frame, and the frame is read and set without KVC
    expect(layer.frame) == CGRect(x: 100, y: 100, width: 50, height: 50)
    expect(layer.kvcReadCount) == 0
    expect(layer.kvcWriteCount) == 0
  }

  func test_animateFrame_viewBacked_setsViewFrameOnce() throws {
    // given: a view in a window that counts its frame sets, and on AppKit its frame-change notifications
    let testWindow = TestWindow()
    let view = FrameTrackingView(frame: CGRect(x: 10, y: 20, width: 100, height: 50))
    testWindow.contentView().addSubview(view)
    let layer = view.layer()
    #if canImport(AppKit)
    var notificationCount = 0
    let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: nil) { _ in
      notificationCount += 1
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
    }
    #endif
    let frame = CGRect(x: 30, y: 60, width: 140, height: 80)
    let positionOffset = layer.position - layer.position(from: frame)
    view.resetFrameSetCount()

    // when: animating the frame to a new origin and size
    layer.animateFrame(to: frame, timing: .easeInEaseOut(duration: 1))

    // then: the layer animates from its old frame, and the layer and the view land at the new frame
    expect(layer.animationKeys()) == ["position", "bounds.size"]
    let positionAnimation = try (layer.animation(forKey: "position") as? CABasicAnimation).unwrap()
    expect(positionAnimation.fromValue as? CGPoint) == positionOffset
    let boundsSizeAnimation = try (layer.animation(forKey: "bounds.size") as? CABasicAnimation).unwrap()
    expect(boundsSizeAnimation.fromValue as? CGSize) == CGSize(width: -40, height: -30)
    expect(layer.frame) == frame
    expect(view.frame) == frame

    // then: an AppKit view's frame is set once, to the new frame, so it posts one frame-change notification. a UIKit
    // view's frame follows its layer without its frame setter
    #if canImport(AppKit)
    expect(view.frameSetCount) == 1
    expect(notificationCount) == 1
    #else
    expect(view.frameSetCount) == 0
    #endif

    // given: the animations removed and the counts reset
    layer.removeAllAnimations()
    view.resetFrameSetCount()
    #if canImport(AppKit)
    notificationCount = 0
    #endif

    // when: setting another frame with a zero-duration timing
    layer.animateFrame(to: CGRect(x: 50, y: 70, width: 60, height: 40), timing: .easeInEaseOut(duration: 0))

    // then: no animation is added, the layer and the view land at the frame, and an AppKit view's frame is set once
    expect(layer.animationKeys()) == nil
    expect(layer.frame) == CGRect(x: 50, y: 70, width: 60, height: 40)
    expect(view.frame) == CGRect(x: 50, y: 70, width: 60, height: 40)
    #if canImport(AppKit)
    expect(view.frameSetCount) == 1
    expect(notificationCount) == 1
    #else
    expect(view.frameSetCount) == 0
    #endif
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
    // later, as it does when the main thread is busy
    layer.animate(keyPath: "position.x", to: CGFloat(1005), timing: .linear(duration: 10))
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

  // MARK: - Key Path Values

  func test_pointValue() {
    // given: a layer that counts KVC reads, with a position and an anchor point
    let layer = KVCCountingLayer()
    layer.position = CGPoint(x: 10, y: 20)
    layer.anchorPoint = CGPoint(x: 0.25, y: 0.75)

    // when: reading the position
    let position = layer.pointValue(forKeyPath: "position")

    // then: the position is read directly
    expect(position) == CGPoint(x: 10, y: 20)
    expect(layer.kvcReadCount) == 0

    // when: reading another point key path
    let anchorPoint = layer.pointValue(forKeyPath: "anchorPoint")

    // then: the value is read through KVC
    expect(anchorPoint) == CGPoint(x: 0.25, y: 0.75)
    expect(layer.kvcReadCount) == 1
  }

  func test_sizeValue() {
    // given: a layer that counts KVC reads, with a bounds size, a shadow offset, and a translation
    let layer = KVCCountingLayer()
    layer.bounds.size = CGSize(width: 30, height: 40)
    layer.shadowOffset = CGSize(width: 5, height: 6)
    layer.transform = CATransform3DMakeTranslation(7, 8, 0)

    // when: reading the bounds size and the shadow offset
    let boundsSize = layer.sizeValue(forKeyPath: "bounds.size")
    let shadowOffset = layer.sizeValue(forKeyPath: "shadowOffset")

    // then: they are read directly
    expect(boundsSize) == CGSize(width: 30, height: 40)
    expect(shadowOffset) == CGSize(width: 5, height: 6)
    expect(layer.kvcReadCount) == 0

    // when: reading another size key path
    let translation = layer.sizeValue(forKeyPath: "transform.translation")

    // then: the value is read through KVC
    expect(translation) == CGSize(width: 7, height: 8)
    expect(layer.kvcReadCount) == 1
  }

  func test_floatingPointValue() {
    // given: a layer that counts KVC reads, with non-default values for the numbers read directly, and a scale
    let layer = KVCCountingLayer()
    layer.opacity = 0.5
    layer.shadowOpacity = 0.25
    layer.borderWidth = 2
    layer.cornerRadius = 3
    layer.shadowRadius = 4
    layer.transform = CATransform3DMakeScale(2, 2, 2)

    // when: reading the numbers as their property types
    let opacity: Float = layer.floatingPointValue(forKeyPath: "opacity")
    let shadowOpacity: Float = layer.floatingPointValue(forKeyPath: "shadowOpacity")
    let borderWidth: CGFloat = layer.floatingPointValue(forKeyPath: "borderWidth")
    let cornerRadius: CGFloat = layer.floatingPointValue(forKeyPath: "cornerRadius")
    let shadowRadius: CGFloat = layer.floatingPointValue(forKeyPath: "shadowRadius")

    // then: they are read directly
    expect(opacity) == 0.5
    expect(shadowOpacity) == 0.25
    expect(borderWidth) == 2
    expect(cornerRadius) == 3
    expect(shadowRadius) == 4
    expect(layer.kvcReadCount) == 0

    // when: reading the numbers as other floating-point types
    let opacityAsCGFloat: CGFloat = layer.floatingPointValue(forKeyPath: "opacity")
    let shadowOpacityAsCGFloat: CGFloat = layer.floatingPointValue(forKeyPath: "shadowOpacity")
    let borderWidthAsFloat: Float = layer.floatingPointValue(forKeyPath: "borderWidth")
    let cornerRadiusAsFloat: Float = layer.floatingPointValue(forKeyPath: "cornerRadius")
    let shadowRadiusAsFloat: Float = layer.floatingPointValue(forKeyPath: "shadowRadius")

    // then: they are read through KVC, which converts the boxed numbers
    expect(opacityAsCGFloat) == 0.5
    expect(shadowOpacityAsCGFloat) == 0.25
    expect(borderWidthAsFloat) == 2
    expect(cornerRadiusAsFloat) == 3
    expect(shadowRadiusAsFloat) == 4
    expect(layer.kvcReadCount) == 5

    // when: reading another number key path
    let scale: CGFloat = layer.floatingPointValue(forKeyPath: "transform.scale")

    // then: the value is read through KVC
    expect(scale) == 2
    expect(layer.kvcReadCount) == 6
  }

  func test_keyPathValues_directReadsMatchKVC() {
    // given: a plain layer and a view's backing layer, with non-default values for the properties read directly
    let testWindow = TestWindow()
    let view = View(frame: CGRect(x: 10, y: 20, width: 30, height: 40))
    #if canImport(AppKit)
    view.wantsLayer = true
    #endif
    testWindow.contentView().addSubview(view)

    let plainLayer = CALayer()
    plainLayer.frame = CGRect(x: 10, y: 20, width: 30, height: 40)

    for layer in [plainLayer, view.layer()] {
      layer.opacity = 0.5
      layer.shadowOpacity = 0.25
      layer.borderWidth = 2
      layer.cornerRadius = 3
      layer.shadowRadius = 4
      layer.shadowOffset = CGSize(width: 5, height: 6)

      // then: the direct reads return what KVC returns
      expect(layer.value(forKeyPath: "position") as? CGPoint) == layer.pointValue(forKeyPath: "position")
      expect(layer.value(forKeyPath: "bounds.size") as? CGSize) == layer.sizeValue(forKeyPath: "bounds.size")
      expect(layer.value(forKeyPath: "shadowOffset") as? CGSize) == layer.sizeValue(forKeyPath: "shadowOffset")
      expect(layer.value(forKeyPath: "opacity") as? Float) == layer.floatingPointValue(forKeyPath: "opacity") as Float
      expect(layer.value(forKeyPath: "shadowOpacity") as? Float) == layer.floatingPointValue(forKeyPath: "shadowOpacity") as Float
      expect(layer.value(forKeyPath: "borderWidth") as? CGFloat) == layer.floatingPointValue(forKeyPath: "borderWidth") as CGFloat
      expect(layer.value(forKeyPath: "cornerRadius") as? CGFloat) == layer.floatingPointValue(forKeyPath: "cornerRadius") as CGFloat
      expect(layer.value(forKeyPath: "shadowRadius") as? CGFloat) == layer.floatingPointValue(forKeyPath: "shadowRadius") as CGFloat
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

    // when: querying basic animations for the opacity key path
    let animations = layer.basicAnimations(forKeyPath: "opacity")

    // then: only the basic opacity animation matches
    expect(animations.count) == 1
    expect(animations.first?.keyPath) == "opacity"
  }

  func test_propertyAnimations_forKeyPath() {
    // given: a layer with basic, keyframe, and different key path animations
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

    // when: querying property animations for the opacity key path
    let animations = layer.propertyAnimations(forKeyPath: "opacity")

    // then: both opacity animations match, in order, and the other key path doesn't
    expect(animations.count) == 2
    expect(animations.first is CABasicAnimation) == true
    expect(animations.last is CAKeyframeAnimation) == true
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
