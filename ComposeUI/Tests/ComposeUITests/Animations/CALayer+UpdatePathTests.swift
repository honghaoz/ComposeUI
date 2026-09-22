//
//  CALayer+UpdatePathTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/21/26.
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

class CALayer_UpdatePathTests: XCTestCase {

  func test_updatePath_unchangedPath_doesNothing() throws {
    // given: a layer with a shadow path, an animating frame, and a shadow path animation following it
    let layer = makeLayer()
    let path = CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 50), transform: nil)
    layer.shadowPath = path
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 50), timing: .linear(duration: 1))
    let followingAnimation = CAKeyframeAnimation(keyPath: "shadowPath")
    followingAnimation.values = [path]
    followingAnimation.duration = 12.34
    layer.add(followingAnimation, forKey: "shadowPath")

    // when: updating the shadow path to the same path, with and without animation
    for animationTiming in [nil, AnimationTiming.linear(duration: 1)] {
      layer.updatePath(
        keyPath: "shadowPath",
        from: layer.shadowPath,
        madeFor: layer.bounds.size,
        to: path,
        followingSizeAnimations: layer.inFlightSizeAnimations(),
        animationTiming: animationTiming,
        path: { _ in path }
      )
    }

    // then: the in-flight animation is left alone, it already lands on the path
    expect(layer.animationKeys()) == ["position", "bounds.size", "shadowPath"]
    expect(try layer.animation(forKey: "shadowPath").unwrap().duration) == 12.34
  }

  func test_updatePath_withSizeAnimations_followsTheFrame() throws {
    // given: a layer with a shadow path made for its size, resized without animation while its frame animates
    let layer = makeLayer()
    layer.shadowPath = CGPath(rect: layer.bounds, transform: nil)
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 50), timing: .linear(duration: 1))

    for animationTiming in [nil, AnimationTiming.linear(duration: 1)] {
      // when: updating the shadow path with or without animation, without a shape change
      layer.updatePath(
        keyPath: "shadowPath",
        from: layer.shadowPath,
        madeFor: CGSize(width: 100, height: 50),
        to: CGPath(rect: layer.bounds, transform: nil),
        followingSizeAnimations: layer.inFlightSizeAnimations(),
        animationTiming: animationTiming,
        path: { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) }
      )

      // then: the path follows the frame either way, from the shown size to the model size
      let animation = try (layer.animation(forKey: "shadowPath") as? CAKeyframeAnimation).unwrap()
      // a Core Foundation type can't be checked at runtime, so the cast is forced
      expect(animation.values?.first as! CGPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50), transform: nil) // swiftlint:disable:this force_cast
      expect(animation.values?.last as! CGPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 50), transform: nil) // swiftlint:disable:this force_cast
      expect(layer.shadowPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 50), transform: nil)
      layer.removeAnimation(forKey: "shadowPath")
      layer.shadowPath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50), transform: nil)
    }
  }

  func test_updatePath_noCurrentPath_withSizeAnimations_followsTheFrame() throws {
    // given: a layer without a shadow path yet, whose frame animates
    let layer = makeLayer()
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 50), timing: .linear(duration: 1))

    // when: an animated update sets the first path
    layer.updatePath(
      keyPath: "shadowPath",
      from: layer.shadowPath,
      madeFor: nil,
      to: CGPath(rect: layer.bounds, transform: nil),
      followingSizeAnimations: layer.inFlightSizeAnimations(),
      animationTiming: .linear(duration: 1),
      path: { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) }
    )

    // then: there is no shape to morph from, so the path follows the frame with the new shape from the start
    let animation = try (layer.animation(forKey: "shadowPath") as? CAKeyframeAnimation).unwrap()
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(animation.values?.first as! CGPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50), transform: nil) // swiftlint:disable:this force_cast
    expect(animation.values?.last as! CGPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 50), transform: nil) // swiftlint:disable:this force_cast
    expect(layer.shadowPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 50), transform: nil)
  }

  func test_updatePath_withSizeAnimations_animatedShapeChange_animatesOnItsOwn() throws {
    // given: a layer with a rect shadow path made for its size, and an animating frame
    let layer = makeLayer()
    layer.shadowPath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50), transform: nil)
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 50), timing: .linear(duration: 1))

    // when: an animated update changes the shape to an inset rect
    let insetRect: (CGSize) -> CGPath = { CGPath(rect: CGRect(origin: .zero, size: $0).insetBy(dx: 10, dy: 10), transform: nil) }
    layer.updatePath(
      keyPath: "shadowPath",
      from: layer.shadowPath,
      madeFor: CGSize(width: 100, height: 50),
      to: insetRect(layer.bounds.size),
      followingSizeAnimations: layer.inFlightSizeAnimations(),
      animationTiming: .linear(duration: 1),
      path: insetRect
    )

    // then: the path animates on its own with the update's timing instead of following the frame
    let animation = try (layer.animation(forKey: "shadowPath") as? CABasicAnimation).unwrap()
    expect(animation.duration) == 1
    expect(animation.isAdditive) == false
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(animation.toValue as! CGPath) == insetRect(layer.bounds.size) // swiftlint:disable:this force_cast
    expect(layer.shadowPath) == insetRect(layer.bounds.size)

    // when: a non-animated update changes the shape again
    let moreInsetRect: (CGSize) -> CGPath = { CGPath(rect: CGRect(origin: .zero, size: $0).insetBy(dx: 20, dy: 20), transform: nil) }
    layer.updatePath(
      keyPath: "shadowPath",
      from: layer.shadowPath,
      madeFor: layer.bounds.size,
      to: moreInsetRect(layer.bounds.size),
      followingSizeAnimations: layer.inFlightSizeAnimations(),
      animationTiming: nil,
      path: moreInsetRect
    )

    // then: the new shape applies at once, at the shown size, and follows the frame to the model size
    let followingAnimation = try (layer.animation(forKey: "shadowPath") as? CAKeyframeAnimation).unwrap()
    expect(followingAnimation.values?.first as! CGPath) == moreInsetRect(CGSize(width: 100, height: 50)) // swiftlint:disable:this force_cast
    expect(followingAnimation.values?.last as! CGPath) == moreInsetRect(CGSize(width: 200, height: 50)) // swiftlint:disable:this force_cast
    expect(layer.shadowPath) == moreInsetRect(CGSize(width: 200, height: 50))
  }

  func test_updatePath_withSizeAnimations_unknownLastSize_animatesOnItsOwn() throws {
    // given: a layer with a shadow path whose size isn't known, and an animating frame
    let layer = makeLayer()
    layer.shadowPath = CGPath(rect: layer.bounds, transform: nil)
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 50), timing: .linear(duration: 1))

    // when: an animated update sets a new path
    layer.updatePath(
      keyPath: "shadowPath",
      from: layer.shadowPath,
      madeFor: nil,
      to: CGPath(rect: layer.bounds, transform: nil),
      followingSizeAnimations: layer.inFlightSizeAnimations(),
      animationTiming: .linear(duration: 1),
      path: { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) }
    )

    // then: the shape change can't be ruled out, so the path animates on its own to the new path
    let animation = try (layer.animation(forKey: "shadowPath") as? CABasicAnimation).unwrap()
    expect(animation.duration) == 1
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(animation.toValue as! CGPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 50), transform: nil) // swiftlint:disable:this force_cast
    expect(layer.shadowPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 50), transform: nil)
  }

  func test_updatePath_withoutSizeAnimations() throws {
    // given: a layer with a shadow path and no frame animation
    let layer = makeLayer()
    layer.shadowPath = CGPath(rect: layer.bounds, transform: nil)
    let newPath = CGPath(rect: layer.bounds.insetBy(dx: 10, dy: 10), transform: nil)

    // when: an animated update sets a new path
    layer.updatePath(
      keyPath: "shadowPath",
      from: layer.shadowPath,
      madeFor: layer.bounds.size,
      to: newPath,
      followingSizeAnimations: nil,
      animationTiming: .linear(duration: 2),
      path: { _ in newPath }
    )

    // then: the path animates from the shown path with the update's timing
    let animation = try (layer.animation(forKey: "shadowPath") as? CABasicAnimation).unwrap()
    expect(animation.duration) == 2
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(layer.shadowPath) == newPath

    // when: a non-animated update sets another path while that animation is in flight
    let newerPath = CGPath(rect: layer.bounds.insetBy(dx: 20, dy: 20), transform: nil)
    layer.updatePath(
      keyPath: "shadowPath",
      from: layer.shadowPath,
      madeFor: layer.bounds.size,
      to: newerPath,
      followingSizeAnimations: nil,
      animationTiming: nil,
      path: { _ in newerPath }
    )

    // then: the path is retargeted over the remaining time
    let retargetedAnimation = try (layer.animation(forKey: "shadowPath") as? CABasicAnimation).unwrap()
    expect(retargetedAnimation.duration) == 2
    expect(retargetedAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(layer.shadowPath) == newerPath
  }

  func test_updatePath_keyPathOfAnotherProperty_asserts() {
    // given: a layer, a shape layer, and a path
    let layer = makeLayer()
    let shapeLayer = CAShapeLayer()
    shapeLayer.frame = layer.frame
    let path = CGPath(rect: layer.bounds, transform: nil)

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: updating a key path that isn't a path, and `path` on a layer that isn't a shape layer
    layer.updatePath(keyPath: "shadowRadius", from: nil, madeFor: nil, to: path, followingSizeAnimations: nil, animationTiming: nil) { _ in path }
    layer.updatePath(keyPath: "path", from: nil, madeFor: nil, to: path, followingSizeAnimations: nil, animationTiming: nil) { _ in path }

    // then: each asserts and leaves the layer alone
    expect(assertionMessages) == [
      "\"shadowRadius\" isn't a path key path, expected \"shadowPath\" or a CAShapeLayer's \"path\"",
      "\"path\" isn't a path key path, expected \"shadowPath\" or a CAShapeLayer's \"path\"",
    ]
    expect(layer.shadowRadius) == 3
    expect(layer.value(forKeyPath: "path")) == nil

    // when: updating the path key paths
    layer.updatePath(keyPath: "shadowPath", from: nil, madeFor: nil, to: path, followingSizeAnimations: nil, animationTiming: nil) { _ in path }
    shapeLayer.updatePath(keyPath: "path", from: nil, madeFor: nil, to: path, followingSizeAnimations: nil, animationTiming: nil) { _ in path }

    // then: neither asserts, and the paths are set
    expect(assertionMessages.count) == 2
    expect(layer.shadowPath) == path
    expect(shapeLayer.path) == path
  }

  // MARK: - Helpers

  /// A layer of 100 by 50 points at the origin.
  private func makeLayer() -> CALayer {
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    return layer
  }
}
