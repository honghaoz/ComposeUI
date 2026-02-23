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

import XCTest

@_spi(Private) @testable import ComposeUI

class CALayer_AnimationsTests: XCTestCase {

  // MARK: - animate

  func test_animateFrame() throws {
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.frame = testWindow.layer.bounds

    XCTAssertEqual(layer.frame, CGRect(x: 0, y: 0, width: 500, height: 500))
    layer.animateFrame(to: CGRect(x: 100, y: 100, width: 50, height: 50), timing: .easeInEaseOut(duration: 1))

    XCTAssertEqual(layer.animationKeys(), ["position", "bounds.size"])

    let positionAnimation = try XCTUnwrap(layer.animation(forKey: "position") as? CABasicAnimation)
    XCTAssertEqual(positionAnimation.fromValue as? CGPoint, CGPoint(x: 125, y: 125))
    XCTAssertEqual(positionAnimation.toValue as? CGPoint, .zero)
    XCTAssertEqual(positionAnimation.timingFunction, CAMediaTimingFunction(name: .easeInEaseOut))
    XCTAssertEqual(positionAnimation.duration, 1)
    XCTAssertEqual(positionAnimation.isAdditive, true)
    XCTAssertEqual(positionAnimation.isRemovedOnCompletion, true)
    XCTAssertEqual(positionAnimation.fillMode, .both)

    let boundsSizeAnimation = try XCTUnwrap(layer.animation(forKey: "bounds.size") as? CABasicAnimation)
    XCTAssertEqual(boundsSizeAnimation.fromValue as? CGSize, CGSize(width: 450, height: 450))
    XCTAssertEqual(boundsSizeAnimation.toValue as? CGSize, .zero)
    XCTAssertEqual(boundsSizeAnimation.timingFunction, CAMediaTimingFunction(name: .easeInEaseOut))
    XCTAssertEqual(boundsSizeAnimation.duration, 1)
    XCTAssertEqual(boundsSizeAnimation.isAdditive, true)
    XCTAssertEqual(boundsSizeAnimation.isRemovedOnCompletion, true)
    XCTAssertEqual(boundsSizeAnimation.fillMode, .both)
  }

  func test_animateFloatingPoint() throws {
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.opacity = 1.0

    layer.animate(keyPath: "opacity", to: CGFloat(0.5), timing: .easeInEaseOut(duration: 1))

    let animation = try XCTUnwrap(layer.animation(forKey: "opacity") as? CABasicAnimation)
    XCTAssertEqual(animation.fromValue as? CGFloat, 0.5) // current (1.0) - target (0.5) = 0.5
    XCTAssertEqual(animation.toValue as? CGFloat, 0.0)
    XCTAssertEqual(animation.timingFunction, CAMediaTimingFunction(name: .easeInEaseOut))
    XCTAssertEqual(animation.duration, 1)
    XCTAssertEqual(animation.isAdditive, true)
    XCTAssertEqual(animation.isRemovedOnCompletion, true)
    XCTAssertEqual(animation.fillMode, .both)
    XCTAssertEqual(layer.opacity, 0.5) // model value should be set
  }

  func test_animateCGSize() throws {
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.bounds.size = CGSize(width: 100, height: 50)

    layer.animate(keyPath: "bounds.size", to: CGSize(width: 200, height: 100), timing: .easeInEaseOut(duration: 1))

    let animation = try XCTUnwrap(layer.animation(forKey: "bounds.size") as? CABasicAnimation)
    XCTAssertEqual(animation.fromValue as? CGSize, CGSize(width: -100, height: -50)) // current (100,50) - target (200,100) = (-100,-50)
    XCTAssertEqual(animation.toValue as? CGSize, CGSize.zero)
    XCTAssertEqual(animation.timingFunction, CAMediaTimingFunction(name: .easeInEaseOut))
    XCTAssertEqual(animation.duration, 1)
    XCTAssertEqual(animation.isAdditive, true)
    XCTAssertEqual(animation.isRemovedOnCompletion, true)
    XCTAssertEqual(animation.fillMode, .both)
    XCTAssertEqual(layer.bounds.size, CGSize(width: 200, height: 100)) // model value should be set
  }

  func test_animateCGPoint() throws {
    let testWindow = TestWindow()

    let layer = CALayer()
    testWindow.layer.addSublayer(layer)
    layer.position = CGPoint(x: 50, y: 75)

    layer.animate(keyPath: "position", to: CGPoint(x: 150, y: 200), timing: .easeInEaseOut(duration: 1))

    let animation = try XCTUnwrap(layer.animation(forKey: "position") as? CABasicAnimation)
    XCTAssertEqual(animation.fromValue as? CGPoint, CGPoint(x: -100, y: -125)) // current (50,75) - target (150,200) = (-100,-125)
    XCTAssertEqual(animation.toValue as? CGPoint, CGPoint.zero)
    XCTAssertEqual(animation.timingFunction, CAMediaTimingFunction(name: .easeInEaseOut))
    XCTAssertEqual(animation.duration, 1)
    XCTAssertEqual(animation.isAdditive, true)
    XCTAssertEqual(animation.isRemovedOnCompletion, true)
    XCTAssertEqual(animation.fillMode, .both)
    XCTAssertEqual(layer.position, CGPoint(x: 150, y: 200)) // model value should be set
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

    let animation = try XCTUnwrap(layer.animation(forKey: "position") as? CABasicAnimation)
    XCTAssertEqual(animation.fromValue as? CGPoint, CGPoint(x: 100, y: 100))
    XCTAssertEqual(animation.toValue as? CGPoint, CGPoint(x: 200, y: 200))
    XCTAssertEqual(animation.timingFunction, CAMediaTimingFunction(name: .easeInEaseOut))
    XCTAssertEqual(animation.duration, 1)
    XCTAssertEqual(animation.isAdditive, false)
    XCTAssertEqual(animation.isRemovedOnCompletion, true)
    XCTAssertEqual(animation.fillMode, .both)
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

    XCTAssertEqual(layer.animationKeys()?.isEmpty, nil)
    XCTAssertEqual(layer.position, CGPoint(x: 200, y: 200))
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
      XCTAssertEqual(layer.animationKeys(), ["position"])
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
      XCTAssertEqual(layer.animationKeys(), ["test"])
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
      XCTAssertEqual(layer.animationKeys(), ["position"])

      layer.animate(
        keyPath: "position",
        timing: .easeInEaseOut(duration: 1),
        from: { $0.position - CGPoint(x: 100, y: 100) },
        to: { _ in .zero },
        model: { _ in CGPoint(x: 100, y: 100) },
        updateAnimation: { $0.isAdditive = true }
      )
      XCTAssertEqual(layer.animationKeys(), ["position", "position-1"])
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
      XCTAssertEqual(layer.animationKeys(), ["test"])

      layer.animate(
        key: "test",
        keyPath: "position",
        timing: .easeInEaseOut(duration: 1),
        from: { $0.position - CGPoint(x: 100, y: 100) },
        to: { _ in .zero },
        model: { _ in CGPoint(x: 100, y: 100) },
        updateAnimation: { $0.isAdditive = true }
      )
      XCTAssertEqual(layer.animationKeys(), ["test", "test-1"])
    }
  }

  // MARK: - setKeyPathValue

  func test_setKeyPathValue_position() throws {
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    let view = UIView(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    layer.setKeyPathValue("position", CGPoint(x: 10, y: 20))
    XCTAssertEqual(layer.position, CGPoint(x: 10, y: 20))
  }

  func test_setKeyPathValue_bounds_size() throws {
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    let view = UIView(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    XCTAssertEqual(layer.bounds.size, CGSize(width: 100, height: 50))

    layer.setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))
    XCTAssertEqual(layer.bounds.size, CGSize(width: 150, height: 80))
    XCTAssertEqual(view.bounds.size, layer.bounds.size)
    XCTAssertEqual(view.frame, CGRect(x: 75, y: 185, width: 150, height: 80))
    XCTAssertEqual(view.frame, layer.frame)
  }

  func test_setKeyPathValue_anchorPoint() throws {
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    // test layer's behavior by changing anchor point
    do {
      let layer = CALayer()
      layer.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      XCTAssertEqual(layer.anchorPoint, CGPoint(x: 0.5, y: 0.5))

      layer.setKeyPathValue("anchorPoint", CGPoint(x: 0, y: 0))
      XCTAssertEqual(layer.anchorPoint, CGPoint(x: 0, y: 0)) // anchor point doesn't change
      // frame should move to keep anchor point position in parent the same
      XCTAssertEqual(layer.frame, CGRect(x: 225, y: 175, width: 50, height: 50))
    }

    let view = UIView(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    XCTAssertEqual(layer.anchorPoint, CGPoint(x: 0.5, y: 0.5)) // default for iOS

    layer.setKeyPathValue("anchorPoint", CGPoint(x: 0, y: 0))
    XCTAssertEqual(layer.anchorPoint, CGPoint(x: 0, y: 0))
    // Frame should move to keep anchor point position in parent the same
    XCTAssertEqual(layer.frame, CGRect(x: 225, y: 175, width: 50, height: 50))
    XCTAssertEqual(view.frame, layer.frame)
  }

  func test_setKeyPathValue_opacity() throws {
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    let view = UIView(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    XCTAssertEqual(layer.opacity, 1.0)
    XCTAssertEqual(view.alpha, 1.0)

    layer.setKeyPathValue("opacity", Float(0.8))
    XCTAssertEqual(layer.opacity, 0.8)
    XCTAssertEqual(view.alpha, CGFloat(layer.opacity)) // view alpha should match layer opacity
  }

  // MARK: - uniqueAnimationKey

  func test_uniqueAnimationKey_noExistingAnimations() {
    let layer = CALayer()

    // given no animations exist
    // then should return original key
    XCTAssertEqual(layer.uniqueAnimationKey(key: "opacity"), "opacity")
  }

  func test_uniqueAnimationKey_withExistingAnimations() {
    let layer = CALayer()

    // given existing animations
    let animation = CABasicAnimation()
    layer.add(animation, forKey: "position")
    layer.add(animation, forKey: "position-1")

    // then should generate next available key
    XCTAssertEqual(layer.uniqueAnimationKey(key: "position"), "position-2")
  }

  func test_uniqueAnimationKey_withNonSequentialKeys() {
    let layer = CALayer()

    // given existing animations with non-sequential keys
    let animation = CABasicAnimation()
    layer.add(animation, forKey: "position")
    layer.add(animation, forKey: "position-2")

    // then should still use next sequential number
    XCTAssertEqual(layer.uniqueAnimationKey(key: "position"), "position-1")
  }
}
