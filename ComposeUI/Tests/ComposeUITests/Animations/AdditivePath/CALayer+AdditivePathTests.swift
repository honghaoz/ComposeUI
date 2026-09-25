//
//  CALayer+AdditivePathTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/24/26.
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

class CALayer_AdditivePathTests: XCTestCase {

  // MARK: - Animate Path

  func test_animatePath_animatesFromTheCurrentPath() throws {
    // given: a shape layer with a rect path
    let layer = makeLayer()

    // when: animating the path to an inset rect
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .easeIn(duration: 2))

    // then: a basic animation goes from the rect to the inset rect with the timing, beginning at the next commit, and
    // the model has the inset rect
    let animation = try (layer.animation(forKey: "path") as? CABasicAnimation).unwrap()
    expect(try PathPoints(path(animation.fromValue))) == PathPoints(rect())
    expect(try path(animation.toValue)) == rect(inset: 10)
    expect(animation.duration) == 2
    expect(animation.timingFunction) == CAMediaTimingFunction(name: .easeIn)
    expect(animation.fillMode) == .both
    expect(animation.beginTime) == 0
    expect(layer.path) == rect(inset: 10)
  }

  func test_animatePath_withoutPath_setsThePath() {
    // given: a shape layer without a path
    let layer = CAShapeLayer()

    // when: animating the path to a rect
    layer.animatePath(keyPath: "path", to: rect(), timing: .linear(duration: 1))

    // then: there is no path to animate from, so the rect shows at once
    expect(layer.path) == rect()
    expect(layer.animationKeys()) == nil
  }

  func test_animatePath_modelPathCleared_setsThePathAtOnce() {
    // given: a shape layer whose rect path changes to an inset rect, and whose model path is then cleared without
    // animation, which leaves the animation of the change on the layer
    let layer = makeLayer()
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 2))
    CATransaction.disableAnimations {
      layer.path = nil
    }
    expect(layer.animation(forKey: "path")) != nil

    // when: animating to a more inset rect
    layer.animatePath(keyPath: "path", to: rect(inset: 20), timing: .linear(duration: 2))

    // then: the change in flight has no model path to add to, so it is dropped with its animation, and the inset rect
    // shows at once
    expect(layer.path) == rect(inset: 20)
    expect(layer.animation(forKey: "path")) == nil
  }

  func test_animatePath_samePath_keepsTheChangeInFlight() throws {
    // given: a shape layer whose rect path changes to an inset rect over two seconds
    let layer = makeLayer()
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 2))

    // when: animating to the inset rect again with another timing
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 5))

    // then: the change in flight already lands on the path, so it is left alone
    let animation = try (layer.animation(forKey: "path") as? CABasicAnimation).unwrap()
    expect(animation.duration) == 2
  }

  func test_animatePath_changeInFlight_addsTheChanges() throws {
    // given: a shape layer whose rect path changes to an inset rect over one second
    let layer = makeLayer()
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 1))

    // when: animating to a more inset rect over two seconds
    layer.animatePath(keyPath: "path", to: rect(inset: 20), timing: .linear(duration: 2))

    // then: the path animates with keyframes of both changes added up, spread evenly from the path shown to the new
    // path, until the longer change lands. no change has begun, so the keyframes begin at the next commit with them
    let animation = try (layer.animation(forKey: "path") as? CAKeyframeAnimation).unwrap()
    let values = try paths(of: animation)
    expect(values.count) == 121
    expect(animation.keyTimes) == nil
    expect(animation.calculationMode) == .linear
    expect(animation.duration) == 2
    expect(animation.fillMode) == .both
    expect(animation.beginTime) == 0
    expect(try values.first.unwrap().maxPointDistance(to: rect(inset: 0))) < 1e-9
    expect(values[60].maxPointDistance(to: rect(inset: 15))) < 1e-3 // at one second
    expect(values.last) == rect(inset: 20)
    expect(layer.path) == rect(inset: 20)
  }

  func test_animatePath_interruptedResize_staysOnTheResizedShape() throws {
    // given: a shape layer whose rounded rect path grew from 100 to 200 wide, over two seconds from half a second ago
    let layer = makeLayer(path: roundedRect(width: 100))
    layer.animatePath(keyPath: "path", to: roundedRect(width: 200), timing: .linear(duration: 2))
    let now = layer.currentTime
    try resolveBeginTime(of: layer, to: now - 0.5)

    // when: it grows on to 300 wide over one second
    layer.animatePath(keyPath: "path", to: roundedRect(width: 300), timing: .linear(duration: 1))

    // then: the path is the rounded rect of the width the two changes add up to: 125 wide now, as the first change is a
    // quarter done, 200 wide half a second later, and 300 wide when the first change lands. the first change has begun,
    // so the keyframes begin now
    let animation = try (layer.animation(forKey: "path") as? CAKeyframeAnimation).unwrap()
    let values = try paths(of: animation)
    expect(animation.beginTime).to(beApproximatelyEqual(to: now, within: 0.05))
    expect(animation.duration).to(beApproximatelyEqual(to: 1.5, within: 0.05))
    expect(try values.first.unwrap().maxPointDistance(to: roundedRect(width: 125))) < 0.01
    expect(values.last) == roundedRect(width: 300)
    expect(try interpolatedPoints(of: animation, at: 0.5).path.maxPointDistance(to: roundedRect(width: 200))) < 0.01
  }

  func test_animatePath_changesSurviveTheCommit() throws {
    // given: a hosted shape layer whose rect path changes to an inset rect over two seconds, committed a while ago
    let testWindow = TestWindow()
    let layer = makeLayer()
    testWindow.layer.addSublayer(layer)
    CATransaction.flush()

    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 2))
    CATransaction.flush()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    let committedBeginTime = try layer.animation(forKey: "path").unwrap().beginTime
    expect(committedBeginTime) > 0

    // when: animating on to a more inset rect
    layer.animatePath(keyPath: "path", to: rect(inset: 20), timing: .linear(duration: 1))

    // then: the change kept on the committed animation begins when Core Animation began it, so the keyframes begin now,
    // from the path shown: the first change's part done at the keyframes' begin
    let animation = try (layer.animation(forKey: "path") as? CAKeyframeAnimation).unwrap()
    let elapsedTime = animation.beginTime - committedBeginTime
    expect(elapsedTime) > 0
    let shownInset = 10 * elapsedTime / 2
    expect(try paths(of: animation).first.unwrap().maxPointDistance(to: rect(inset: shownInset))) < 1e-3
  }

  func test_animatePath_changesInFlight_showTheirSum() throws {
    // given: a hosted shape layer with a rect path
    let testWindow = TestWindow()
    let layer = makeLayer()
    testWindow.layer.addSublayer(layer)
    CATransaction.flush()
    expect(layer.presentation()).toEventuallyNot(beNil())

    // when: the path changes to an inset rect over one second, and on to a more inset rect over three seconds
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 1))
    layer.animatePath(keyPath: "path", to: rect(inset: 20), timing: .linear(duration: 3))
    CATransaction.flush()

    // then: whenever the run loop lets the test look, the path shown is the rect inset by the sum of the changes left
    // at that time. a sample only shows at its time if Core Animation spreads the keyframes evenly
    for _ in 0 ..< 6 {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
      let beginTime = try layer.animation(forKey: "path").unwrap().beginTime
      expect(beginTime) > 0
      let elapsedTime = layer.currentTime - beginTime
      let expectedInset = 20 - 10 * max(0, 1 - elapsedTime) - 10 * max(0, 1 - elapsedTime / 3)
      let expectedBounds = CGRect(x: 0, y: 0, width: 100, height: 50).insetBy(dx: expectedInset, dy: expectedInset)

      // Core Animation turns the lines of a path it interpolates into curves, so the shape shown is compared by its bounds
      let shownBounds = try layer.presentation().unwrap().path.unwrap().boundingBoxOfPath
      expect(shownBounds.minX).to(beApproximatelyEqual(to: expectedBounds.minX, within: 0.5))
      expect(shownBounds.minY).to(beApproximatelyEqual(to: expectedBounds.minY, within: 0.5))
      expect(shownBounds.maxX).to(beApproximatelyEqual(to: expectedBounds.maxX, within: 0.5))
      expect(shownBounds.maxY).to(beApproximatelyEqual(to: expectedBounds.maxY, within: 0.5))
    }
  }

  func test_animatePath_delayedChange_leavesTheOtherChangeOnTheCommit() throws {
    // given: a shape layer with a rect path
    let layer = makeLayer()

    // when: in one transaction, the path changes to an inset rect over two seconds, and on to a more inset rect over
    // two seconds after a delay of a second
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 2))
    layer.animatePath(keyPath: "path", to: rect(inset: 20), timing: .linear(duration: 2, delay: 1))

    // then: the keyframes begin at the commit, where the change without a delay begins, as an animation without a delay
    // does
    let animation = try (layer.animation(forKey: "path") as? CAKeyframeAnimation).unwrap()
    expect(animation.beginTime) == 0
  }

  func test_animatePath_heldTransaction_followsTheFrame() throws {
    // given: a hosted shape layer with the path of its size, and a hosted layer of the same size
    let testWindow = TestWindow()
    let layer = makeLayer()
    let frameLayer = CALayer()
    frameLayer.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    testWindow.layer.addSublayer(layer)
    testWindow.layer.addSublayer(frameLayer)
    CATransaction.flush()
    expect(layer.presentation()).toEventuallyNot(beNil())

    // when: in a transaction held open for 0.3s, both grow 200 wide over two seconds, and 300 wide over two seconds
    // after a delay of a second
    for (width, timing) in [(CGFloat(200), AnimationTiming.linear(duration: 2)), (300, .linear(duration: 2, delay: 1))] {
      frameLayer.animateFrame(to: CGRect(x: 0, y: 0, width: width, height: 50), timing: timing)
      layer.animatePath(keyPath: "path", to: rect(width: width), timing: timing)
    }
    Thread.sleep(forTimeInterval: 0.3)
    CATransaction.flush()

    // then: while only the change without a delay moves, the path keeps the frame's width, as both begin at the commit
    for _ in 0 ..< 3 {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
      let shownWidth = try layer.presentation().unwrap().path.unwrap().boundingBoxOfPath.width
      let frameWidth = try frameLayer.presentation().unwrap().bounds.width
      expect(shownWidth).to(beApproximatelyEqual(to: frameWidth, within: 1))
    }

    // when: both grow on to 310 wide over half a second, in a transaction committed at once
    frameLayer.animateFrame(to: CGRect(x: 0, y: 0, width: 310, height: 50), timing: .linear(duration: 0.5))
    layer.animatePath(keyPath: "path", to: rect(width: 310), timing: .linear(duration: 0.5))
    CATransaction.flush()

    // then: the path keeps the frame's width past the delayed change's begin too, as the update draws the delayed change
    // at its own begin time again
    for _ in 0 ..< 8 {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
      let shownWidth = try layer.presentation().unwrap().path.unwrap().boundingBoxOfPath.width
      let frameWidth = try frameLayer.presentation().unwrap().bounds.width
      expect(shownWidth).to(beApproximatelyEqual(to: frameWidth, within: 1))
    }
  }

  func test_animatePath_delayedSnap_holdsUntilItsDelayEnds() throws {
    // given: a shape layer whose rect path changes to an inset rect over two seconds
    let layer = makeLayer()
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 2))

    // when: the path snaps on to a more inset rect after a delay that ends between two samples
    layer.animatePath(keyPath: "path", to: rect(inset: 20), timing: .linear(duration: 0, delay: 0.508))

    // then: right before the delay ends, the path shown is the first change's alone, and right after, the snap has
    // landed, as the keyframes hold the snap until its delay ends
    let animation = try (layer.animation(forKey: "path") as? CAKeyframeAnimation).unwrap()
    expect(try interpolatedPoints(of: animation, at: 0.507).path.maxPointDistance(to: rect(inset: 10 - 10 * (1 - 0.507 / 2)))) < 1e-6
    expect(try interpolatedPoints(of: animation, at: 0.51).path.maxPointDistance(to: rect(inset: 20 - 10 * (1 - 0.51 / 2)))) < 1e-6
  }

  func test_animatePath_truncatedSpring_jumpsWhenItLands() throws {
    // given: a shape layer whose rect path grows from 100 to 200 points wide over two seconds
    let layer = makeLayer()
    layer.animatePath(keyPath: "path", to: rect(width: 200), timing: .linear(duration: 2))

    // when: the path grows on to 300 points wide with a spring cut short by a duration of 0.1s, before it settles
    let springTiming = AnimationTiming.spring(dampingRatio: 1, response: 0.5, duration: 0.1)
    layer.animatePath(keyPath: "path", to: rect(width: 300), timing: springTiming)

    // then: until the spring lands, the path shown follows the spring's curve, as Core Animation shows a spring cut short,
    // instead of heading to where the spring lands, and right after, the spring has landed
    let animation = try (layer.animation(forKey: "path") as? CAKeyframeAnimation).unwrap()
    let springCurve = AnimationCurve(CABasicAnimation.makeAnimation(springTiming))
    for time in [0.09, 0.095, 0.099] {
      let expectedWidth = 300 - 100 * (1 - time / 2) - 100 * (1 - springCurve.progress(forElapsedTime: time))
      let shownWidth = try interpolatedPoints(of: animation, at: time).path.boundingBoxOfPath.width
      expect(shownWidth, "time: \(time)").to(beApproximatelyEqual(to: expectedWidth, within: 0.5))
    }
    let shownWidthAfterLanding = try interpolatedPoints(of: animation, at: 0.101).path.boundingBoxOfPath.width
    expect(shownWidthAfterLanding).to(beApproximatelyEqual(to: 300 - 100 * (1 - 0.101 / 2), within: 1e-6))
  }

  func test_animatePath_otherSegments_setsThePathAtOnce() {
    // given: a shape layer whose rect path changes to an inset rect
    let layer = makeLayer()
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 2))

    // when: animating to a rounded rect
    layer.animatePath(keyPath: "path", to: roundedRect(width: 100), timing: .linear(duration: 2))

    // then: the rounded rect can't take the rects' changes, so they are dropped and the rounded rect shows at once
    expect(layer.path) == roundedRect(width: 100)
    expect(layer.animation(forKey: "path")) == nil
  }

  func test_animatePath_pointsNotFinite_setsThePathAtOnce() {
    // given: a shape layer whose rect path changes to an inset rect
    let layer = makeLayer()
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 2))

    // when: animating to the path of a null rect, whose points are at infinity
    let nullRect = CGPath(rect: .null, transform: nil)
    layer.animatePath(keyPath: "path", to: nullRect, timing: .linear(duration: 2))

    // then: the points don't blend, so the changes are dropped and the path shows at once
    expect(layer.path) == nullRect
    expect(layer.animation(forKey: "path")) == nil
  }

  func test_animatePath_zeroDuration() throws {
    // given: a shape layer with a rect path
    let layer = makeLayer()

    // when: animating to an inset rect with a zero duration
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 0))

    // then: the inset rect shows at once
    expect(layer.path) == rect(inset: 10)
    expect(layer.animation(forKey: "path")) == nil

    // when: a change is in flight, and another change has a zero duration
    layer.animatePath(keyPath: "path", to: rect(inset: 20), timing: .linear(duration: 2))
    layer.animatePath(keyPath: "path", to: rect(width: 120, inset: 20), timing: .linear(duration: 0))

    // then: the new path shows at once, and the change in flight keeps adding to it
    let animation = try (layer.animation(forKey: "path") as? CABasicAnimation).unwrap()
    expect(try PathPoints(path(animation.fromValue))) == PathPoints(rect(width: 120, inset: 10))
    expect(try path(animation.toValue)) == rect(width: 120, inset: 20)
    expect(animation.duration) == 2
  }

  func test_animatePath_delayedChange_holdsThePathUntilItBegins() throws {
    // given: a shape layer with a rect path
    let layer = makeLayer()

    // when: animating to an inset rect with a delay
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 1, delay: 0.5))

    // then: the animation begins after the delay, and fills backwards to hold the rect until then
    let animation = try (layer.animation(forKey: "path") as? CABasicAnimation).unwrap()
    expect(animation.beginTime).to(beApproximatelyEqual(to: layer.currentTime + 0.5, within: 0.05))
    expect(animation.fillMode) == .both
    expect(try PathPoints(path(animation.fromValue))) == PathPoints(rect())
  }

  func test_animatePath_spring() throws {
    // given: a shape layer with a rect path, and a spring timing
    let layer = makeLayer()
    let timing = AnimationTiming.spring(dampingRatio: 0.5, response: 0.4)
    let expectedAnimation = try (CABasicAnimation.makeAnimation(timing) as? CASpringAnimation).unwrap()

    // when: animating to an inset rect with the spring
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: timing)

    // then: the path animates with the spring, which Core Animation evaluates on every frame
    let animation = try (layer.animation(forKey: "path") as? CASpringAnimation).unwrap()
    expect(animation.mass) == expectedAnimation.mass
    expect(animation.stiffness) == expectedAnimation.stiffness
    expect(animation.damping) == expectedAnimation.damping
    expect(animation.duration) == expectedAnimation.duration
  }

  func test_animatePath_shadowPath() throws {
    // given: a layer with a rect shadow path
    let layer = CALayer()
    layer.setPath(keyPath: "shadowPath", to: rect())

    // when: animating the shadow path to an inset rect
    layer.animatePath(keyPath: "shadowPath", to: rect(inset: 10), timing: .linear(duration: 1))

    // then: the shadow path animates from the rect
    let animation = try (layer.animation(forKey: "shadowPath") as? CABasicAnimation).unwrap()
    expect(try PathPoints(path(animation.fromValue))) == PathPoints(rect())
    expect(layer.shadowPath) == rect(inset: 10)
  }

  func test_animatePath_otherAnimation_replacesTheChanges() throws {
    // given: a shape layer whose rect path changes to an inset rect, whose animation is replaced by another one
    let layer = makeLayer()
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 2))
    let otherAnimation = CABasicAnimation(keyPath: "path")
    otherAnimation.duration = 10
    layer.add(otherAnimation, forKey: "path")

    // when: animating to a more inset rect
    layer.animatePath(keyPath: "path", to: rect(inset: 20), timing: .linear(duration: 1))

    // then: the changes went with the replaced animation, so the path animates from the model path alone
    let animation = try (layer.animation(forKey: "path") as? CABasicAnimation).unwrap()
    expect(try PathPoints(path(animation.fromValue))) == PathPoints(rect(inset: 10))
    expect(animation.duration) == 1

    // when: the layer's animations are removed, and the path animates again
    layer.removeAllAnimations()
    layer.animatePath(keyPath: "path", to: rect(inset: 5), timing: .linear(duration: 1))

    // then: the changes went with the animations too
    let newAnimation = try (layer.animation(forKey: "path") as? CABasicAnimation).unwrap()
    expect(try PathPoints(path(newAnimation.fromValue))) == PathPoints(rect(inset: 20))
  }

  func test_animatePath_keyPathWithoutPath_asserts() {
    // given: a layer with a number at a key path
    let layer = CALayer()
    layer.setValue(NSNumber(value: 1), forKey: "custom")

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: animating a path at the key path
    layer.animatePath(keyPath: "custom", to: rect(), timing: .linear(duration: 1))

    // then: it asserts, as the key path doesn't hold a path, and leaves the layer alone
    expect(assertionMessages) == ["expected a path at \"custom\", got 1"]
    expect(layer.value(forKey: "custom") as? NSNumber) == 1
    expect(layer.animationKeys()) == nil
  }

  // MARK: - Set Path

  func test_setPath_withoutChangesInFlight_setsThePath() throws {
    // given: a shape layer with a rect path and another animation of the path
    let layer = makeLayer()
    let otherAnimation = CABasicAnimation(keyPath: "path")
    otherAnimation.duration = 10
    layer.add(otherAnimation, forKey: "path")

    // when: setting an inset rect
    layer.setPath(keyPath: "path", to: rect(inset: 10))

    // then: the model has the inset rect, and the other animation is left alone, as with any model value set
    expect(layer.path) == rect(inset: 10)
    expect(try layer.animation(forKey: "path").unwrap().duration) == 10
  }

  func test_setPath_changeInFlight_movesThePathShownByTheModelChange() throws {
    // given: a shape layer whose rect path changes to an inset rect over two seconds
    let layer = makeLayer()
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 2))

    // when: setting the inset rect 120 wide
    layer.setPath(keyPath: "path", to: rect(width: 120, inset: 10))

    // then: the change keeps adding to the new path, so the path shown widens by 20 at once and still loses its inset
    // over the change's time
    let animation = try (layer.animation(forKey: "path") as? CABasicAnimation).unwrap()
    expect(try PathPoints(path(animation.fromValue))) == PathPoints(rect(width: 120))
    expect(try path(animation.toValue)) == rect(width: 120, inset: 10)
    expect(animation.duration) == 2
    expect(animation.beginTime) == 0
    expect(layer.path) == rect(width: 120, inset: 10)
  }

  func test_setPath_modelPathCleared_setsThePathAtOnce() {
    // given: a shape layer whose rect path changes to an inset rect, and whose model path is then cleared without
    // animation, which leaves the animation of the change on the layer
    let layer = makeLayer()
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 2))
    CATransaction.disableAnimations {
      layer.path = nil
    }
    expect(layer.animation(forKey: "path")) != nil

    // when: setting a more inset rect
    layer.setPath(keyPath: "path", to: rect(inset: 20))

    // then: the change in flight has no model path to add to, so it is dropped with its animation, and the inset rect
    // shows at once
    expect(layer.path) == rect(inset: 20)
    expect(layer.animation(forKey: "path")) == nil
  }

  func test_setPath_samePath_doesNothing() throws {
    // given: a shape layer whose rect path changes to an inset rect over two seconds
    let layer = makeLayer()
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 2))

    // when: setting the inset rect
    layer.setPath(keyPath: "path", to: rect(inset: 10))

    // then: the change in flight is left alone
    let animation = try (layer.animation(forKey: "path") as? CABasicAnimation).unwrap()
    expect(try PathPoints(path(animation.fromValue))) == PathPoints(rect())
  }

  func test_setPath_otherSegments_setsThePathAtOnce() {
    // given: a shape layer whose rect path changes to an inset rect
    let layer = makeLayer()
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 2))

    // when: setting a rounded rect
    layer.setPath(keyPath: "path", to: roundedRect(width: 100))

    // then: the rounded rect can't take the rects' change, so it is dropped and the rounded rect shows at once
    expect(layer.path) == roundedRect(width: 100)
    expect(layer.animation(forKey: "path")) == nil
  }

  func test_setPath_pointsNotFinite_setsThePathAtOnce() {
    // given: a shape layer whose rect path changes to an inset rect
    let layer = makeLayer()
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 2))

    // when: setting the path of a null rect, whose points are at infinity
    let nullRect = CGPath(rect: .null, transform: nil)
    layer.setPath(keyPath: "path", to: nullRect)

    // then: the change can't blend with it, so it is dropped and the path shows at once
    expect(layer.path) == nullRect
    expect(layer.animation(forKey: "path")) == nil
  }

  func test_setPath_keyPathWithoutPath_asserts() {
    // given: a layer with a number at a key path
    let layer = CALayer()
    layer.setValue(NSNumber(value: 1), forKey: "custom")

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: setting a path at the key path
    layer.setPath(keyPath: "custom", to: rect())

    // then: it asserts, as the key path doesn't hold a path, and leaves the layer alone
    expect(assertionMessages) == ["expected a path at \"custom\", got 1"]
    expect(layer.value(forKey: "custom") as? NSNumber) == 1
  }

  func test_setPath_landedChanges_removesTheirAnimation() throws {
    // given: a shape layer whose path change landed, while its animation is still on the layer
    let layer = makeLayer()
    layer.animatePath(keyPath: "path", to: rect(inset: 10), timing: .linear(duration: 2))
    try resolveBeginTime(of: layer, to: layer.currentTime - 5)

    // when: setting another path
    layer.setPath(keyPath: "path", to: rect(inset: 20))

    // then: nothing is in flight, so the animation of the landed change is removed and the path shows at once
    expect(layer.path) == rect(inset: 20)
    expect(layer.animation(forKey: "path")) == nil
  }

  // MARK: - Helpers

  /// A shape layer of 100 by 50 points at the origin, with the given path.
  private func makeLayer(path: CGPath? = nil) -> CAShapeLayer {
    let layer = CAShapeLayer()
    layer.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    layer.setPath(keyPath: "path", to: path ?? rect())
    return layer
  }

  /// Gives the layer's path animation a begin time, as a commit does.
  private func resolveBeginTime(of layer: CALayer, to beginTime: TimeInterval) throws {
    // `copy()` returns `Any`, and a copy of an animation is an animation
    let animation = try layer.animation(forKey: "path").unwrap().copy() as! CAAnimation // swiftlint:disable:this force_cast
    animation.beginTime = beginTime
    layer.add(animation, forKey: "path")
  }

  /// A rect of the given width and 50 points high at the origin, inset by the given amount.
  private func rect(width: CGFloat = 100, inset: CGFloat = 0) -> CGPath {
    CGPath(rect: CGRect(x: 0, y: 0, width: width, height: 50).insetBy(dx: inset, dy: inset), transform: nil)
  }

  /// A rounded rect of the given width and 50 points high at the origin, with a corner radius of 10.
  private func roundedRect(width: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: 0, y: 0, width: width, height: 50), cornerWidth: 10, cornerHeight: 10, transform: nil)
  }

  /// The paths of a keyframe animation.
  private func paths(of animation: CAKeyframeAnimation) throws -> [CGPath] {
    try animation.values.unwrap().map { try path($0) }
  }

  /// The points a keyframe animation of paths shows at a time from its begin, interpolated the way Core Animation
  /// interpolates linear keyframes: at the key times, or spread evenly without them.
  private func interpolatedPoints(of animation: CAKeyframeAnimation, at time: TimeInterval) throws -> PathPoints {
    let values = try paths(of: animation).map { PathPoints($0) }
    let times = animation.keyTimes?.map { $0.doubleValue * animation.duration }
      ?? values.indices.map { animation.duration * TimeInterval($0) / TimeInterval(values.count - 1) }
    let index = try times.lastIndex { $0 <= time }.unwrap()
    guard index < values.count - 1 else {
      return values[index]
    }
    let fraction = (time - times[index]) / (times[index + 1] - times[index])
    return values[index].adding(values[index + 1].subtracting(values[index]), multipliedBy: fraction)
  }

  /// A path given as an animation value.
  private func path(_ value: Any?) throws -> CGPath {
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    try (value.unwrap() as! CGPath) // swiftlint:disable:this force_cast
  }
}
