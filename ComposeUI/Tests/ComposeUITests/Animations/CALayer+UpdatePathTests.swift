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

  // MARK: - Is Shape Changed

  func test_isShapeChanged() {
    // given: two paths of different shapes
    let rect = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50), transform: nil)
    let insetRect = CGPath(rect: CGRect(x: 10, y: 10, width: 80, height: 30), transform: nil)

    // then: without a current path there is no shape to have changed
    expect(CALayer.isShapeChanged(current: nil, previous: nil)) == false
    expect(CALayer.isShapeChanged(current: nil, previous: rect)) == false

    // then: without the path for the current path's size, a change can't be ruled out
    expect(CALayer.isShapeChanged(current: rect, previous: nil)) == true

    // then: the same path for the current path's size means the same shape, another path another shape
    expect(CALayer.isShapeChanged(current: rect, previous: rect)) == false
    expect(CALayer.isShapeChanged(current: rect, previous: insetRect)) == true
  }

  // MARK: - Update Shadow Path

  func test_updateShadowPath_unchangedPath_doesNothing() throws {
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
      layer.updateShadowPath(
        to: path,
        followingSizeAnimations: layer.inFlightSizeAnimations(),
        isShapeChanged: false,
        sampledPaths: { [path, path] },
        animationTiming: animationTiming
      )
    }

    // then: the in-flight animation is left alone, it already lands on the path
    expect(layer.animationKeys()) == ["position", "bounds.size", "shadowPath"]
    expect(try layer.animation(forKey: "shadowPath").unwrap().duration) == 12.34
  }

  func test_updateShadowPath_withSizeAnimations_followsTheFrame() throws {
    // given: a layer with a shadow path made for its size, resized without animation while its frame animates
    let layer = makeLayer()
    layer.shadowPath = CGPath(rect: layer.bounds, transform: nil)
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 50), timing: .linear(duration: 1))
    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    for animationTiming in [nil, AnimationTiming.linear(duration: 1)] {
      // when: updating the shadow path with or without animation, without a shape change
      layer.updateShadowPath(
        to: CGPath(rect: layer.bounds, transform: nil),
        followingSizeAnimations: sizeAnimations,
        isShapeChanged: false,
        sampledPaths: { sizeAnimations.sampledSizes().map { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) } },
        animationTiming: animationTiming
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

  func test_updateShadowPath_withSizeAnimations_animatedShapeChange_animatesOnItsOwn() throws {
    // given: a layer with a rect shadow path made for its size, and an animating frame
    let layer = makeLayer()
    layer.shadowPath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50), transform: nil)
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 50), timing: .linear(duration: 1))
    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    // when: an animated update changes the shape to an inset rect
    let insetRect: (CGSize) -> CGPath = { CGPath(rect: CGRect(origin: .zero, size: $0).insetBy(dx: 10, dy: 10), transform: nil) }
    var sampledPathsRequests = 0
    layer.updateShadowPath(
      to: insetRect(layer.bounds.size),
      followingSizeAnimations: sizeAnimations,
      isShapeChanged: true,
      sampledPaths: {
        sampledPathsRequests += 1
        return sizeAnimations.sampledSizes().map(insetRect)
      },
      animationTiming: .linear(duration: 1)
    )

    // then: the path animates on its own with the update's timing instead of following the frame, without asking for
    // the sampled paths
    let animation = try (layer.animation(forKey: "shadowPath") as? CABasicAnimation).unwrap()
    expect(animation.duration) == 1
    expect(animation.isAdditive) == false
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(animation.toValue as! CGPath) == insetRect(layer.bounds.size) // swiftlint:disable:this force_cast
    expect(layer.shadowPath) == insetRect(layer.bounds.size)
    expect(sampledPathsRequests) == 0

    // when: a non-animated update changes the shape again
    let moreInsetRect: (CGSize) -> CGPath = { CGPath(rect: CGRect(origin: .zero, size: $0).insetBy(dx: 20, dy: 20), transform: nil) }
    layer.updateShadowPath(
      to: moreInsetRect(layer.bounds.size),
      followingSizeAnimations: sizeAnimations,
      isShapeChanged: true,
      sampledPaths: { sizeAnimations.sampledSizes().map(moreInsetRect) },
      animationTiming: nil
    )

    // then: the new shape applies at once, at the shown size, and follows the frame to the model size
    let followingAnimation = try (layer.animation(forKey: "shadowPath") as? CAKeyframeAnimation).unwrap()
    expect(followingAnimation.values?.first as! CGPath) == moreInsetRect(CGSize(width: 100, height: 50)) // swiftlint:disable:this force_cast
    expect(followingAnimation.values?.last as! CGPath) == moreInsetRect(CGSize(width: 200, height: 50)) // swiftlint:disable:this force_cast
    expect(layer.shadowPath) == moreInsetRect(CGSize(width: 200, height: 50))
  }

  func test_updateShadowPath_withoutSizeAnimations() throws {
    // given: a layer with a shadow path and no frame animation
    let layer = makeLayer()
    layer.shadowPath = CGPath(rect: layer.bounds, transform: nil)
    let newPath = CGPath(rect: layer.bounds.insetBy(dx: 10, dy: 10), transform: nil)

    // when: an animated update sets a new path
    layer.updateShadowPath(
      to: newPath,
      followingSizeAnimations: nil,
      isShapeChanged: true,
      sampledPaths: { [] },
      animationTiming: .linear(duration: 2)
    )

    // then: the path animates from the shown path with the update's timing
    let animation = try (layer.animation(forKey: "shadowPath") as? CABasicAnimation).unwrap()
    expect(animation.duration) == 2
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .linear)
    expect(layer.shadowPath) == newPath

    // when: a non-animated update sets another path while that animation is in flight
    let newerPath = CGPath(rect: layer.bounds.insetBy(dx: 20, dy: 20), transform: nil)
    layer.updateShadowPath(
      to: newerPath,
      followingSizeAnimations: nil,
      isShapeChanged: true,
      sampledPaths: { [] },
      animationTiming: nil
    )

    // then: the path is retargeted over the remaining time
    let retargetedAnimation = try (layer.animation(forKey: "shadowPath") as? CABasicAnimation).unwrap()
    expect(retargetedAnimation.duration) == 2
    expect(retargetedAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    expect(layer.shadowPath) == newerPath
  }

  // MARK: - Update Path

  func test_updatePath_shapeLayer_followsTheFrame() throws {
    // given: a shape layer with a path made for its size, whose frame animates
    let layer = CAShapeLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    layer.path = CGPath(rect: layer.bounds, transform: nil)
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 50), timing: .linear(duration: 1))
    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    // when: updating the path without animation
    layer.updatePath(
      to: CGPath(rect: layer.bounds, transform: nil),
      followingSizeAnimations: sizeAnimations,
      isShapeChanged: false,
      sampledPaths: { sizeAnimations.sampledSizes().map { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) } },
      animationTiming: nil
    )

    // then: the path follows the frame, from the shown size to the model size
    let animation = try (layer.animation(forKey: "path") as? CAKeyframeAnimation).unwrap()
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(animation.values?.first as! CGPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50), transform: nil) // swiftlint:disable:this force_cast
    expect(animation.values?.last as! CGPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 50), transform: nil) // swiftlint:disable:this force_cast
    expect(layer.path) == CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 50), transform: nil)
  }

  // MARK: - Helpers

  /// A layer of 100 by 50 points at the origin.
  private func makeLayer() -> CALayer {
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    return layer
  }
}
