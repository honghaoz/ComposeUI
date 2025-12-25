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
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.frame = testWindow.layer.bounds

    expect(layer.frame) == CGRect(x: 0, y: 0, width: 500, height: 500)
    layer.animateFrame(to: CGRect(x: 100, y: 100, width: 50, height: 50), timing: .easeInEaseOut(duration: 1))

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
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.opacity = 1.0

    layer.animate(keyPath: "opacity", to: CGFloat(0.5), timing: .easeInEaseOut(duration: 1))

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
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.bounds.size = CGSize(width: 100, height: 50)

    layer.animate(keyPath: "bounds.size", to: CGSize(width: 200, height: 100), timing: .easeInEaseOut(duration: 1))

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
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.position = CGPoint(x: 50, y: 75)

    layer.animate(keyPath: "position", to: CGPoint(x: 150, y: 200), timing: .easeInEaseOut(duration: 1))

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
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.frame = testWindow.layer.bounds

    layer.animate(
      keyPath: "position",
      timing: .easeInEaseOut(duration: 1),
      from: { _ in CGPoint(x: 100, y: 100) },
      to: { _ in CGPoint(x: 200, y: 200) }
    )

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
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.frame = testWindow.layer.bounds

    layer.animate(
      keyPath: "position",
      timing: .easeInEaseOut(duration: 0),
      from: { _ in CGPoint(x: 100, y: 100) },
      to: { _ in CGPoint(x: 200, y: 200) }
    )

    expect(layer.animationKeys()?.isEmpty) == nil
    expect(layer.position) == CGPoint(x: 200, y: 200)
  }

  func test_animationKey() {
    // with implicit key
    do {
      let layer = CALayer()
      layer.animate(
        keyPath: "position",
        timing: .easeInEaseOut(duration: 1),
        from: { _ in CGPoint(x: 100, y: 100) },
        to: { _ in CGPoint(x: 200, y: 200) }
      )
      expect(layer.animationKeys()) == ["position"]
    }

    // with explicit key
    do {
      let layer = CALayer()
      layer.animate(
        key: "test",
        keyPath: "position",
        timing: .easeInEaseOut(duration: 1),
        from: { _ in CGPoint(x: 100, y: 100) },
        to: { _ in CGPoint(x: 200, y: 200) }
      )
      expect(layer.animationKeys()) == ["test"]
    }
  }

  func test_animationKey_additive() {
    // with implicit key
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
      expect(layer.animationKeys()) == ["position"]

      layer.animate(
        keyPath: "position",
        timing: .easeInEaseOut(duration: 1),
        from: { $0.position - CGPoint(x: 100, y: 100) },
        to: { _ in .zero },
        model: { _ in CGPoint(x: 100, y: 100) },
        updateAnimation: { $0.isAdditive = true }
      )
      expect(layer.animationKeys()) == ["position", "position-1"]
    }

    // with explicit key
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
      expect(layer.animationKeys()) == ["test"]

      layer.animate(
        key: "test",
        keyPath: "position",
        timing: .easeInEaseOut(duration: 1),
        from: { $0.position - CGPoint(x: 100, y: 100) },
        to: { _ in .zero },
        model: { _ in CGPoint(x: 100, y: 100) },
        updateAnimation: { $0.isAdditive = true }
      )
      expect(layer.animationKeys()) == ["test", "test-1"]
    }
  }

  // MARK: - setKeyPathValue

  func test_setKeyPathValue_position() throws {
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    #if os(macOS)
    // layer-backed view
    do {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = view.layer()
      layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
      layer.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      view.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      expect(layer.position) == CGPoint(x: 150, y: 225)

      layer.setKeyPathValue("position", CGPoint(x: 180, y: 250)) // x: 30, y: 25
      expect(layer.frame) == CGRect(x: 130, y: 225, width: 100, height: 50)
      expect(view.frame) == layer.frame
    }

    // layer-hosted view
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

      layer.setKeyPathValue("position", CGPoint(x: 180, y: 250)) // x: 30, y: 25
      expect(layer.frame) == CGRect(x: 130, y: 225, width: 100, height: 50)
      expect(view.frame) == layer.frame
    }
    #endif

    #if canImport(UIKit)
    let view = UIView(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    layer.setKeyPathValue("position", CGPoint(x: 10, y: 20))
    expect(layer.position) == CGPoint(x: 10, y: 20)
    #endif
  }

  func test_setKeyPathValue_bounds_size() throws {
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    #if os(macOS)
    // layer-backed view
    do {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = view.layer()
      layer.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      view.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      expect(layer.bounds.size) == CGSize(width: 100, height: 50)

      layer.setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))
      expect(layer.bounds.size) == CGSize(width: 150, height: 80)
      expect(view.bounds.size) == layer.bounds.size
      expect(layer.frame) == CGRect(x: 100, y: 200, width: 150, height: 80)
      expect(view.frame) == layer.frame
    }

    // layer-hosted view
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

      layer.setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))
      expect(layer.bounds.size) == CGSize(width: 150, height: 80)
      expect(view.bounds.size) == layer.bounds.size
      expect(layer.frame) == CGRect(x: 100, y: 200, width: 150, height: 80)
      expect(view.frame) == layer.frame
    }
    #endif

    #if canImport(UIKit)
    let view = UIView(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    expect(layer.bounds.size) == CGSize(width: 100, height: 50)

    layer.setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))
    expect(layer.bounds.size) == CGSize(width: 150, height: 80)
    expect(view.bounds.size) == layer.bounds.size
    expect(view.frame) == CGRect(x: 75, y: 185, width: 150, height: 80)
    expect(view.frame) == layer.frame
    #endif
  }

  func test_setKeyPathValue_anchorPoint() throws {
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    // test layer's behavior by changing anchor point
    do {
      let layer = CALayer()
      layer.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      expect(layer.anchorPoint) == CGPoint(x: 0.5, y: 0.5)

      layer.setKeyPathValue("anchorPoint", CGPoint(x: 0, y: 0))
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0) // anchor point doesn't change
      // frame should move to keep anchor point position in parent the same
      expect(layer.frame) == CGRect(x: 225, y: 175, width: 50, height: 50)
    }

    #if os(macOS)
    // layer-backed view
    do {
      let view = View(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = view.layer()
      layer.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      view.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0) // default for macOS

      layer.setKeyPathValue("anchorPoint", CGPoint(x: 0.5, y: 0.5))
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0) // anchor point doesn't change
      // frame should move to keep anchor point position in parent the same
      expect(layer.frame) == CGRect(x: 175, y: 125, width: 50, height: 50)
      expect(view.frame) == layer.frame
    }

    // layer-hosted view
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

      layer.setKeyPathValue("anchorPoint", CGPoint(x: 0.5, y: 0.5))
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0) // anchor point doesn't change
      // frame should move to keep anchor point position in parent the same
      expect(layer.frame) == CGRect(x: 175, y: 125, width: 50, height: 50)
      expect(view.frame) == layer.frame
    }
    #endif

    #if canImport(UIKit)
    let view = UIView(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    expect(layer.anchorPoint) == CGPoint(x: 0.5, y: 0.5) // default for iOS

    layer.setKeyPathValue("anchorPoint", CGPoint(x: 0, y: 0))
    expect(layer.anchorPoint) == CGPoint(x: 0, y: 0)
    // Frame should move to keep anchor point position in parent the same
    expect(layer.frame) == CGRect(x: 225, y: 175, width: 50, height: 50)
    expect(view.frame) == layer.frame
    #endif
  }

  func test_setKeyPathValue_opacity() throws {
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    #if os(macOS)
    // layer-backed view
    do {
      let view = View(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = view.layer()
      expect(layer.opacity) == 1.0
      expect(view.alpha) == 1.0

      layer.setKeyPathValue("opacity", Float(0.7))
      expect(layer.opacity) == 0.7
      expect(view.alpha) == CGFloat(layer.opacity) // view alpha should match layer opacity
    }

    // layer-hosted view
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

      layer.setKeyPathValue("opacity", Float(0.3))
      expect(layer.opacity) == 0.3
      expect(view.alpha) == CGFloat(layer.opacity) // view alpha should match layer opacity
    }
    #endif

    #if canImport(UIKit)
    let view = UIView(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    expect(layer.opacity) == 1.0
    expect(view.alpha) == 1.0

    layer.setKeyPathValue("opacity", Float(0.8))
    expect(layer.opacity) == 0.8
    expect(view.alpha) == CGFloat(layer.opacity) // view alpha should match layer opacity
    #endif
  }

  // MARK: - uniqueAnimationKey

  func test_uniqueAnimationKey_noExistingAnimations() {
    let layer = CALayer()

    // given no animations exist
    // then should return original key
    expect(layer.uniqueAnimationKey(key: "opacity")) == "opacity"
  }

  func test_uniqueAnimationKey_withExistingAnimations() {
    let layer = CALayer()

    // given existing animations
    let animation = CABasicAnimation()
    layer.add(animation, forKey: "position")
    layer.add(animation, forKey: "position-1")

    // then should generate next available key
    expect(layer.uniqueAnimationKey(key: "position")) == "position-2"
  }

  func test_uniqueAnimationKey_withNonSequentialKeys() {
    let layer = CALayer()

    // given existing animations with non-sequential keys
    let animation = CABasicAnimation()
    layer.add(animation, forKey: "position")
    layer.add(animation, forKey: "position-2")

    // then should still use next sequential number
    expect(layer.uniqueAnimationKey(key: "position")) == "position-1"
  }
}
