//
//  CALayer+InFlightSizeAnimationsTests.swift
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

class CALayer_InFlightSizeAnimationsTests: XCTestCase {

  // MARK: - In-Flight Size Animations

  func test_inFlightSizeAnimations_noSizeAnimation() {
    // given: a layer animating another key path only
    let layer = makeLayer()
    let spinAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    spinAnimation.duration = 60
    layer.add(spinAnimation, forKey: "spin")

    // then: there are no in-flight size animations
    expect(layer.inFlightSizeAnimations()) == nil
  }

  func test_inFlightSizeAnimations_frameAnimation() throws {
    // given: a layer whose frame animates from 100 by 50 to 200 by 100
    let layer = makeLayer()
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 100), timing: .linear(duration: 2))

    // when: asking for the in-flight size animations
    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    // then: the size animation is found with its sizes, and the whole duration remains since it isn't committed yet
    expect(sizeAnimations.animations.count) == 1
    expect(sizeAnimations.animations[0].from) == CGSize(width: -100, height: -50)
    expect(sizeAnimations.animations[0].to) == .zero
    expect(sizeAnimations.remainingTime) == 2
    expect(sizeAnimations.now).to(beApproximatelyEqual(to: layer.currentTime, within: 0.05))
  }

  func test_inFlightSizeAnimations_moveWithoutResize_isIgnored() {
    // given: a layer whose frame animates to another position at the same size
    let layer = makeLayer()
    layer.animateFrame(to: CGRect(x: 50, y: 50, width: 100, height: 50), timing: .linear(duration: 2))
    expect(layer.animationKeys()) == ["position", "bounds.size"]

    // then: the size animation has no delta, so there is nothing to follow
    expect(layer.inFlightSizeAnimations()) == nil
  }

  func test_inFlightSizeAnimations_stackedTails_longestRemains() throws {
    // given: a layer with two frame animations of different durations in flight
    let layer = makeLayer()
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 100), timing: .linear(duration: 2))
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 300, height: 100), timing: .linear(duration: 1))

    // when: asking for the in-flight size animations
    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    // then: both animations are found and the longest one's time remains
    expect(sizeAnimations.animations.count) == 2
    expect(sizeAnimations.remainingTime) == 2
  }

  func test_inFlightSizeAnimations_nonAdditiveSizeAnimation_returnsNil() {
    // given: a layer with an additive size animation and a non-additive one
    let layer = makeLayer()
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 100), timing: .linear(duration: 2))
    let sizeAnimation = CABasicAnimation(keyPath: "bounds.size")
    sizeAnimation.fromValue = CGSize(width: 10, height: 10)
    sizeAnimation.toValue = CGSize(width: 20, height: 20)
    sizeAnimation.duration = 2
    layer.add(sizeAnimation, forKey: "resize")

    // then: the composition can't be reproduced, so there are no in-flight size animations
    expect(layer.inFlightSizeAnimations()) == nil
  }

  func test_inFlightSizeAnimations_keyframeSizeAnimation_returnsNil() {
    // given: a layer with a keyframe size animation
    let layer = makeLayer()
    let sizeAnimation = CAKeyframeAnimation(keyPath: "bounds.size")
    sizeAnimation.values = [CGSize(width: 10, height: 10), CGSize(width: 20, height: 20)]
    sizeAnimation.duration = 2
    layer.add(sizeAnimation, forKey: "resize")

    // then: there are no in-flight size animations
    expect(layer.inFlightSizeAnimations()) == nil
  }

  func test_inFlightSizeAnimations_sizeAnimationWithoutSizes_returnsNil() {
    // given: a layer with an additive size animation without values
    let layer = makeLayer()
    let sizeAnimation = CABasicAnimation(keyPath: "bounds.size")
    sizeAnimation.isAdditive = true
    sizeAnimation.duration = 2
    layer.add(sizeAnimation, forKey: "resize")

    // then: there are no in-flight size animations
    expect(layer.inFlightSizeAnimations()) == nil
  }

  func test_inFlightSizeAnimations_endedAnimation_isIgnored() {
    // given: a layer with a size animation that ended but stays on the layer
    let layer = makeLayer()
    let sizeAnimation = CABasicAnimation(keyPath: "bounds.size")
    sizeAnimation.fromValue = CGSize(width: -100, height: 0)
    sizeAnimation.toValue = CGSize.zero
    sizeAnimation.isAdditive = true
    sizeAnimation.duration = 2
    sizeAnimation.beginTime = layer.currentTime - 5
    sizeAnimation.isRemovedOnCompletion = false
    layer.add(sizeAnimation, forKey: "resize")

    // then: there are no in-flight size animations
    expect(layer.inFlightSizeAnimations()) == nil
  }

  func test_inFlightSizeAnimations_speedAndDelay() throws {
    // given: a layer with a size animation running at double speed and another scheduled one second ahead
    let layer = makeLayer()

    let fastAnimation = CABasicAnimation(keyPath: "bounds.size")
    fastAnimation.fromValue = CGSize(width: -100, height: 0)
    fastAnimation.toValue = CGSize.zero
    fastAnimation.isAdditive = true
    fastAnimation.duration = 4
    fastAnimation.speed = 2
    layer.add(fastAnimation, forKey: "fast")

    let delayedAnimation = CABasicAnimation(keyPath: "bounds.size")
    delayedAnimation.fromValue = CGSize(width: -50, height: 0)
    delayedAnimation.toValue = CGSize.zero
    delayedAnimation.isAdditive = true
    delayedAnimation.duration = 2
    delayedAnimation.beginTime = layer.currentTime + 1
    layer.add(delayedAnimation, forKey: "delayed")

    // when: asking for the in-flight size animations
    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    // then: the speed scales the duration and the delay counts, so the delayed animation's three seconds remain
    expect(sizeAnimations.animations.count) == 2
    expect(sizeAnimations.remainingTime).to(beApproximatelyEqual(to: 3, within: 0.05))
  }

  func test_inFlightSizeAnimations_pausedAnimation_countsItsDuration() throws {
    // given: a layer with a paused size animation
    let layer = makeLayer()
    let pausedAnimation = CABasicAnimation(keyPath: "bounds.size")
    pausedAnimation.fromValue = CGSize(width: -100, height: 0)
    pausedAnimation.toValue = CGSize.zero
    pausedAnimation.isAdditive = true
    pausedAnimation.duration = 3
    pausedAnimation.speed = 0
    layer.add(pausedAnimation, forKey: "paused")

    // when: asking for the in-flight size animations
    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    // then: the duration stands in for the remaining time, as a paused animation has no end to measure to
    expect(sizeAnimations.remainingTime) == 3
  }

  // MARK: - Rendered Size

  func test_renderedSize_linearAnimation() throws {
    // given: a layer whose frame animates linearly from 100 by 50 to 200 by 100 over two seconds
    let layer = makeLayer()
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 100), timing: .linear(duration: 2))
    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    // then: the rendered size runs from the old size to the model size
    expect(layer.renderedSize(after: 0, with: sizeAnimations)) == CGSize(width: 100, height: 50)
    expect(layer.renderedSize(after: 1, with: sizeAnimations).width).to(beApproximatelyEqual(to: 150, within: 0.001))
    expect(layer.renderedSize(after: 1, with: sizeAnimations).height).to(beApproximatelyEqual(to: 75, within: 0.001))
    expect(layer.renderedSize(after: 2, with: sizeAnimations)) == CGSize(width: 200, height: 100)
    expect(layer.renderedSize(after: 3, with: sizeAnimations)) == CGSize(width: 200, height: 100)
  }

  func test_renderedSize_stackedAnimations() throws {
    // given: a layer whose frame animates to 200 wide over two seconds, then to 300 wide over one second
    let layer = makeLayer()
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 50), timing: .linear(duration: 2))
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 300, height: 50), timing: .linear(duration: 1))
    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    // then: the rendered size is the model size plus both animations, the way Core Animation composes them
    expect(layer.renderedSize(after: 0, with: sizeAnimations).width) == 100
    expect(layer.renderedSize(after: 0.5, with: sizeAnimations).width).to(beApproximatelyEqual(to: 175, within: 0.001)) // 300 - 75 - 50
    expect(layer.renderedSize(after: 1, with: sizeAnimations).width).to(beApproximatelyEqual(to: 250, within: 0.001)) // 300 - 50
    expect(layer.renderedSize(after: 2, with: sizeAnimations).width) == 300
  }

  func test_renderedSize_easeInEaseOutAnimation() throws {
    // given: a layer whose frame animates from 100 to 200 wide with an ease in ease out curve
    let layer = makeLayer()
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 50), timing: .easeInEaseOut(duration: 2))
    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    // then: the rendered size follows the curve: behind linear early on, at the midpoint half way, ahead later
    expect(layer.renderedSize(after: 0.5, with: sizeAnimations).width) < 125
    expect(layer.renderedSize(after: 0.5, with: sizeAnimations).width) > 100
    expect(layer.renderedSize(after: 1, with: sizeAnimations).width).to(beApproximatelyEqual(to: 150, within: 0.01))
    expect(layer.renderedSize(after: 1.5, with: sizeAnimations).width) > 175
    expect(layer.renderedSize(after: 1.5, with: sizeAnimations).width) < 200
  }

  func test_renderedSize_springAnimation_overshoots() throws {
    // given: a layer whose frame animates with a bouncy spring
    let layer = makeLayer()
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 50), timing: .spring(dampingRatio: 0.3, response: 0.5))
    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    // then: the rendered size overshoots the model size at some point and settles on it
    let sampleCount = 100
    let widths = (0 ... sampleCount).map { layer.renderedSize(after: sizeAnimations.remainingTime * TimeInterval($0) / TimeInterval(sampleCount), with: sizeAnimations).width }
    expect(try widths.max().unwrap()) > 200
    expect(try widths.last.unwrap()).to(beApproximatelyEqual(to: 200, within: 1))
  }

  func test_renderedSize_scheduledAnimation_holdsUntilItBegins() throws {
    // given: a layer with a size animation scheduled one second ahead
    let layer = makeLayer()

    let delayedAnimation = CABasicAnimation(keyPath: "bounds.size")
    delayedAnimation.fromValue = CGSize(width: -100, height: 0)
    delayedAnimation.toValue = CGSize.zero
    delayedAnimation.isAdditive = true
    delayedAnimation.duration = 2
    delayedAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
    delayedAnimation.beginTime = layer.currentTime + 1
    layer.add(delayedAnimation, forKey: "delayed")

    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    // then: the animation contributes its start value until it begins, then runs out over its duration
    expect(layer.renderedSize(after: 0, with: sizeAnimations).width) == 0
    expect(layer.renderedSize(after: 1, with: sizeAnimations).width).to(beApproximatelyEqual(to: 0, within: 0.5))
    expect(layer.renderedSize(after: 2, with: sizeAnimations).width).to(beApproximatelyEqual(to: 50, within: 0.5))
    expect(layer.renderedSize(after: 3, with: sizeAnimations).width).to(beApproximatelyEqual(to: 100, within: 0.5))
  }

  func test_renderedSize_committedAnimation() throws {
    // given: a hosted layer whose frame animation was committed and has run for a while
    let testWindow = TestWindow()
    let layer = makeLayer()
    testWindow.layer.addSublayer(layer)
    CATransaction.flush()

    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 50), timing: .linear(duration: 1))
    CATransaction.flush()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    // then: the animation's begin time is resolved, so the remaining time and the rendered size account for the time run
    expect(sizeAnimations.remainingTime).to(beApproximatelyEqual(to: 0.7, within: 0.1))
    expect(layer.renderedSize(after: 0, with: sizeAnimations).width).to(beApproximatelyEqual(to: 130, within: 10))
    expect(layer.renderedSize(after: sizeAnimations.remainingTime, with: sizeAnimations).width).to(beApproximatelyEqual(to: 200, within: 0.01))
  }

  // MARK: - Animate Following

  func test_animateFollowingSize_addsKeyframeAnimationOfSamples() throws {
    // given: a layer whose frame animates from 100 to 200 wide over half a second
    let layer = makeLayer()
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 50), timing: .linear(duration: 0.5))
    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    // when: animating the shadow path to follow the animating size, with a rect of the rendered size
    var sampledSizes: [CGSize] = []
    layer.animateFollowingSize(sizeAnimations, keyPath: "shadowPath", to: CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 50), transform: nil)) { size in
      sampledSizes.append(size)
      return CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
    }

    // then: the size is sampled at the display rate from the shown size to the model size
    expect(sampledSizes.count) == 31 // 0.5s at 60 per second, plus the end
    expect(sampledSizes.first) == CGSize(width: 100, height: 50)
    expect(sampledSizes.last) == CGSize(width: 200, height: 50)
    expect(sampledSizes[15].width).to(beApproximatelyEqual(to: 150, within: 0.01))

    // then: the samples are a linear keyframe animation over the remaining time, and the model has the final path
    let animation = try (layer.animation(forKey: "shadowPath") as? CAKeyframeAnimation).unwrap()
    expect(animation.values?.count) == 31
    expect(animation.keyTimes?.first) == 0
    expect(animation.keyTimes?[15]) == 0.5
    expect(animation.keyTimes?.last) == 1
    expect(animation.calculationMode) == .linear
    expect(animation.duration) == 0.5
    expect(animation.fillMode) == .both
    expect(animation.isRemovedOnCompletion) == true
    expect(animation.beginTime) == 0
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(animation.values?.first as! CGPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50), transform: nil) // swiftlint:disable:this force_cast
    expect(animation.values?.last as! CGPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 50), transform: nil) // swiftlint:disable:this force_cast
    expect(layer.shadowPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 50), transform: nil)
  }

  func test_animateFollowingSize_runningSizeAnimation_beginsAtTheSamplingTime() throws {
    // given: a layer with a size animation that already has a begin time, as a committed one does
    let layer = makeLayer()
    let sizeAnimation = CABasicAnimation(keyPath: "bounds.size")
    sizeAnimation.fromValue = CGSize(width: -100, height: 0)
    sizeAnimation.toValue = CGSize.zero
    sizeAnimation.isAdditive = true
    sizeAnimation.duration = 2
    sizeAnimation.beginTime = layer.currentTime - 0.5
    layer.add(sizeAnimation, forKey: "resize")
    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    // when: animating the shadow path to follow it
    layer.animateFollowingSize(sizeAnimations, keyPath: "shadowPath", to: CGPath(rect: layer.bounds, transform: nil)) { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) }

    // then: the animation begins at the sampling time rather than at the next commit, so it doesn't lag the size by the
    // time until the commit
    let animation = try (layer.animation(forKey: "shadowPath") as? CAKeyframeAnimation).unwrap()
    expect(animation.beginTime) == sizeAnimations.now
    expect(animation.duration).to(beApproximatelyEqual(to: 1.5, within: 0.01))
  }

  func test_animateFollowingSize_capsSampleCount() throws {
    // given: a layer whose frame animates over ten seconds
    let layer = makeLayer()
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 50), timing: .linear(duration: 10))
    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    // when: animating the shadow path to follow the animating size
    var sampleCount = 0
    layer.animateFollowingSize(sizeAnimations, keyPath: "shadowPath", to: CGPath(rect: layer.bounds, transform: nil)) { size in
      sampleCount += 1
      return CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
    }

    // then: the samples are capped, a slow animation interpolates well between sparser samples
    expect(sampleCount) == 120
    expect((layer.animation(forKey: "shadowPath") as? CAKeyframeAnimation)?.values?.count) == 120
  }

  func test_animateFollowingSize_replacesInFlightAnimationOfKeyPath() throws {
    // given: a layer with a shadow path animation in flight and an animating frame
    let layer = makeLayer()
    let pathAnimation = CABasicAnimation(keyPath: "shadowPath")
    pathAnimation.duration = 10
    layer.add(pathAnimation, forKey: "shadowPath")
    layer.animateFrame(to: CGRect(x: 0, y: 0, width: 200, height: 50), timing: .linear(duration: 1))
    let sizeAnimations = try layer.inFlightSizeAnimations().unwrap()

    // when: animating the shadow path to follow the animating size
    layer.animateFollowingSize(sizeAnimations, keyPath: "shadowPath", to: CGPath(rect: layer.bounds, transform: nil)) { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) }

    // then: the in-flight animation is replaced, the frame animations are left alone
    expect(layer.animationKeys()) == ["position", "bounds.size", "shadowPath"]
    expect(layer.animation(forKey: "shadowPath") is CAKeyframeAnimation) == true
  }

  // MARK: - Helpers

  /// A layer of 100 by 50 points at the origin.
  private func makeLayer() -> CALayer {
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    return layer
  }
}
