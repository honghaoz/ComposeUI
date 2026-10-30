//
//  CALayer+AnchoredTransformTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/28/26.
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

class CALayer_AnchoredTransformTests: XCTestCase {

  // MARK: - At Once

  func test_updateTransform_unchanged_leavesTheLayerAlone() throws {
    // given: a layer turned a quarter turn about its top left corner, and a count of its transform writes
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: nil)
    var transformWrites = 0
    let observation = layer.observe(\.transform) { _, _ in
      transformWrites += 1
    }

    // when: updates keep the transform, without and with a timing
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: nil)
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 1))

    // then: the transform isn't written, and nothing animates
    expect(transformWrites) == 0
    expect(layer.animationKeys()) == nil
    observation.invalidate()
  }

  func test_updateTransform_withoutATiming_atRest_appliesAtOnce() throws {
    // given: a layer at rest, whose anchor point is at its center
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size

    // when: a quarter turn about its top left corner applies without a timing
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: nil)

    // then: the layer shows the turn about the corner at once, without an animation
    expect(layer.animationKeys()) == nil
    timeline.show(at: 100)
    try expectShownTransform(of: layer, Constants.quarterTurn, about: .topLeft, within: 1e-9)
  }

  func test_updateTransform_withoutAnAnchor_appliesAboutTheCenter() throws {
    // given: a layer whose anchor point is at its top left corner
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: .zero)
    let layer = timeline.layer

    // when: a quarter turn applies without an anchor
    layer.updateTransform(Constants.quarterTurn, oldSize: layer.bounds.size, animationTiming: nil)

    // then: the layer shows the turn about its center
    timeline.show(at: 100)
    try expectShownTransform(of: layer, Constants.quarterTurn, about: .center, within: 1e-9)
  }

  func test_updateTransform_zeroDuration_appliesAtOnce() throws {
    // given: a layer at rest
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size

    // when: a quarter turn about its top left corner applies with a timing of no duration
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 0))

    // then: the layer shows the turn at once, without an animation
    expect(layer.animationKeys()) == nil
    timeline.show(at: 100)
    try expectShownTransform(of: layer, Constants.quarterTurn, about: .topLeft, within: 1e-9)
  }

  func test_updateTransform_transformsThatDontInterpolate_applyAtOnce() throws {
    // given: a layer at rest, whose anchor point is at its center, and a point off the anchor point and the anchor point
    for (anchor, pivotOffset) in [(UnitPoint.topLeft, SIMD2(-0.5, -0.5)), (.center, .zero)] {
      let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
      let layer = timeline.layer
      let size = layer.bounds.size

      // when: a transform that flattens the depth, which doesn't decompose, applies about the point with a timing
      layer.updateTransform(Constants.flat, anchor: anchor, oldSize: size, animationTiming: .linear(duration: 1))

      // then: the layer has the transform about the point at once, without an animation
      expect(layer.animationKeys()) == nil
      expectTransform(layer.transform, CALayer.anchoredTransform(Constants.flat, pivotOffset: pivotOffset, size: size))
    }
  }

  func test_updateTransform_sizeChangedWithoutASizeAnimation_appliesAtOnce() throws {
    // given: a layer turned about its top left corner, resized without an animation
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 40, height: 20), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: nil)
    layer.retargetFrame(to: CGRect(origin: .zero, size: Constants.largeSize))

    // when: an animated update follows the size
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: .linear(duration: 1))

    // then: the turn applies about the corner for the new size at once, as nothing animates the size
    expect(layer.animationKeys()) == nil
    timeline.show(at: 100)
    try expectShownTransform(of: layer, Constants.quarterTurn, about: .topLeft, within: 1e-9)
  }

  func test_updateTransform_withoutATimingAfterAChange_appliesAtOnce() throws {
    // given: a layer that turned a quarter turn about its top left corner over a second
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 1))

    // when: once the turn ended, an update without a timing scales it instead
    timeline.show(at: 102)
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, animationTiming: nil)

    // then: the layer shows the scale at once, and the turn's animation is gone
    expect(layer.animation(forKey: "transform")) == nil
    timeline.show(at: 102)
    try expectShownTransform(of: layer, Constants.doubleScale, about: .topLeft, within: 1e-9)
  }

  // MARK: - Keyframes

  func test_updateTransform_withATiming_turnsAboutThePoint() throws {
    // given: a layer at rest, whose anchor point is at its center
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size

    // when: a quarter turn about its top left corner animates over a second
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 1))

    // then: the layer shows the turn so far about the corner, on the keyframes and between them, and the turn once it ends
    for time in [0.25, 0.5, 0.508, 0.75, 1.5] {
      timeline.show(at: 100 + time)
      try expectShownTransform(of: layer, interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: min(time, 1)), about: .topLeft, within: 0.01)
    }

    // then: the keyframes come at 60 per second
    let animation = try unwrap(layer.animation(forKey: "transform") as? AnchoredTransformKeyframeAnimation)
    expect(animation.values?.count) == 61
    expect(animation.duration) == 1
    expect(animation.beginTime) == 100
  }

  func test_updateTransform_withATiming_perspectiveTurnsAboutThePoint() throws {
    // given: a layer at rest, anchored at its corner, as an AppKit view's layer is
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: .zero)
    let layer = timeline.layer
    let size = layer.bounds.size

    // when: a turn in perspective about its center animates over a second
    layer.updateTransform(Constants.perspectiveTurn, anchor: .center, oldSize: size, animationTiming: .linear(duration: 1))

    // then: the layer shows the turn so far about its center
    for time in [0.25, 0.5, 0.75] {
      timeline.show(at: 100 + time)
      try expectShownTransform(of: layer, interpolated(from: CATransform3DIdentity, to: Constants.perspectiveTurn, progress: time), about: .center, within: 0.01)
    }
  }

  func test_updateTransform_withATimingDuringAResize_keepsThePointInPlace() throws {
    // given: a layer growing from 40 x 20 to 80 x 40 over a second, as an animated update's frame does
    let timeline = PausedTimeline(frame: CGRect(origin: CGPoint(x: 10, y: 10), size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.animateFrame(to: CGRect(origin: CGPoint(x: 10, y: 10), size: Constants.largeSize), timing: .linear(duration: 1))

    // when: the update scales it to twice its size about its top left corner, with the same timing
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: .linear(duration: 1))

    // then: the layer shows the scale so far about the corner at the size it shows, so the corner stays in place
    for time in [0.25, 0.5, 0.75] {
      timeline.show(at: 100 + time)
      try expectShownTransform(of: layer, interpolated(from: CATransform3DIdentity, to: Constants.doubleScale, progress: time), about: .topLeft, within: 0.01)
    }

    // then: halfway, the bottom right corner is 1.5 times the shown 60 x 30 from the corner
    timeline.show(at: 100.5)
    let presentation = try unwrap(layer.presentation())
    let bottomRight = presentation.convert(CGPoint(x: presentation.bounds.maxX, y: presentation.bounds.maxY), to: presentation.superlayer)
    expect(bottomRight.x).to(beApproximatelyEqual(to: 100, within: 0.01))
    expect(bottomRight.y).to(beApproximatelyEqual(to: 55, within: 0.01))
  }

  func test_updateTransform_withATimingAfterAResize_turnsAboutThePointAtTheNewSize() throws {
    // given: a layer that grew from 40 x 20 to 80 x 40 over a second
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.animateFrame(to: CGRect(origin: .zero, size: Constants.largeSize), timing: .linear(duration: 1))

    // when: once the resize ended, an animated update turns it a quarter turn about its top left corner over a second
    timeline.move(to: 102)
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.largeSize, animationTiming: .linear(duration: 1))

    // then: the layer shows the turn so far about the corner at the new size, which the ended resize doesn't change
    for time in [0.25, 0.5] {
      timeline.show(at: 102 + time)
      try expectShownTransform(of: layer, interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: time), about: .topLeft, within: 0.01)
    }
  }

  func test_updateTransform_resizeInterruptingAResize_keepsThePointInPlace() throws {
    // given: a layer turned a quarter turn about its top left corner, growing from 40 x 20 to 80 x 40 over 2 seconds
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: nil)
    layer.animateFrame(to: CGRect(origin: .zero, size: Constants.largeSize), timing: .linear(duration: 2))
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: .linear(duration: 2))

    // when: a second in, another animated update grows it to 120 x 60 over a second, which stacks on the first resize
    timeline.move(to: 101)
    let largerSize = CGSize(width: 120, height: 60)
    layer.animateFrame(to: CGRect(origin: .zero, size: largerSize), timing: .linear(duration: 1))
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.largeSize, animationTiming: .linear(duration: 1))

    // then: the layer shows the turn about the corner at the size that the stacked resizes show
    for time in [101, 101.25, 101.5, 101.9, 102.5] {
      timeline.show(at: time)
      try expectShownTransform(of: layer, Constants.quarterTurn, about: .topLeft, within: 0.01)
    }
  }

  func test_updateTransform_otherAnimationOfTheSize_keepsThePointInPlace() throws {
    // given: a layer turned a quarter turn about its top left corner, made 80 x 40 by an additive animation of its size
    // that isn't one of the frame's, from 40 x 20 over a second
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: nil)
    layer.retargetFrame(to: CGRect(origin: .zero, size: Constants.largeSize))
    let resize = CABasicAnimation(keyPath: "bounds.size")
    resize.fromValue = CGSize(width: -40, height: -20)
    resize.toValue = CGSize.zero
    resize.isAdditive = true
    resize.beginTime = 100
    resize.duration = 1
    layer.add(resize, forKey: "resize")

    // when: the transform follows the new size
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: nil)

    // then: the layer shows the turn about the corner at the size that the animation shows
    for time in [100.25, 100.5, 100.75] {
      timeline.show(at: time)
      try expectShownTransform(of: layer, Constants.quarterTurn, about: .topLeft, within: 0.01)
    }
  }

  func test_updateTransform_perspectiveDuringAResize_keepsThePointInPlace() throws {
    // given: a layer anchored at its corner, turned in perspective about its center
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: .zero)
    let layer = timeline.layer
    let size = layer.bounds.size
    let largeSize = CGSize(width: 200, height: 100)
    layer.updateTransform(Constants.perspectiveTurn, anchor: .center, oldSize: size, animationTiming: nil)

    // when: an animated update grows it to 200 x 100 over a second
    layer.animateFrame(to: CGRect(origin: .zero, size: largeSize), timing: .linear(duration: 1))
    layer.updateTransform(Constants.perspectiveTurn, anchor: .center, oldSize: size, animationTiming: .linear(duration: 1))

    // then: the layer shows the turn about its center at the size it shows, which perspective makes no straight line
    for time in [0.25, 0.5, 0.75] {
      timeline.show(at: 100 + time)
      try expectShownTransform(of: layer, Constants.perspectiveTurn, about: .center, within: 0.01)
    }
  }

  func test_updateTransform_delayedTiming_holdsTheTransformUntilTheDelayPasses() throws {
    // given: a layer at rest
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size

    // when: a quarter turn about its top left corner animates over a second, after half a second
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 1, delay: 0.5))

    // then: the layer shows no turn until the delay passes, then the turn so far, as the keyframes begin after the delay
    for (time, progress) in [(100.25, 0.0), (101, 0.5), (101.5, 1)] {
      timeline.show(at: time)
      try expectShownTransform(of: layer, interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: progress), about: .topLeft, within: 0.01)
    }
    expect(try unwrap(layer.animation(forKey: "transform")).beginTime) == 100.5
  }

  func test_updateTransform_springTiming_followsTheSpring() throws {
    // given: a layer at rest
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size

    // when: an eighth turn about its top left corner animates with a bouncy spring
    let timing = AnimationTiming.spring(dampingRatio: 0.5, response: 0.4)
    layer.updateTransform(Constants.eighthTurn, anchor: .topLeft, oldSize: size, animationTiming: timing)

    // then: on each keyframe, the layer shows the turn that the spring gives, past the eighth turn while it overshoots
    let curve = AnimationCurve(CABasicAnimation.makeAnimation(timing))
    let animation = try unwrap(layer.animation(forKey: "transform") as? AnchoredTransformKeyframeAnimation)
    let intervals = try unwrap(animation.values?.count) - 1
    var overshoots = false
    for index in stride(from: 1, to: intervals, by: 3) {
      let time = animation.duration * Double(index) / Double(intervals)
      let progress = curve.progress(forElapsedTime: time)
      overshoots = overshoots || progress > 1
      timeline.show(at: 100 + time)
      try expectShownTransform(of: layer, interpolated(from: CATransform3DIdentity, to: Constants.eighthTurn, progress: progress), about: .topLeft, within: 1e-3)
    }
    expect(overshoots) == true
  }

  func test_updateTransform_changesThatStrayTheMostBetweenKeyframes_keepThePointWithinAQuarterPoint() throws {
    // given: the changes whose points Core Animation's interpolation between keyframes moves the most: a fast turn about
    // a far point, a flip in perspective about a far edge and back, a turn in perspective during a large resize, and a
    // scale during a larger resize, each about a point that the transform keeps in place
    let flip = CATransform3DRotate(Constants.perspective, .pi, 0, 1, 0)
    let cases: [(name: String, frame: CGRect, anchorPoint: CGPoint, anchor: UnitPoint, bound: CGFloat, change: (CALayer) -> Void)] = [
      ("fast turn", CGRect(x: 0, y: 0, width: 400, height: 400), .zero, .center, 0.25, { layer in
        let size = layer.bounds.size
        layer.updateTransform(Constants.halfTurn, anchor: .center, oldSize: size, animationTiming: .easeInEaseOut(duration: 0.3))
      }),
      ("perspective flip", CGRect(x: 0, y: 0, width: 800, height: 400), Constants.center, .left, 0.25, { layer in
        let size = layer.bounds.size
        layer.updateTransform(flip, anchor: .left, oldSize: size, animationTiming: .easeInEaseOut(duration: 0.25))
      }),
      ("perspective flip back to flat", CGRect(x: 0, y: 0, width: 800, height: 400), Constants.center, .left, 0.25, { layer in
        let size = layer.bounds.size
        layer.updateTransform(flip, anchor: .left, oldSize: size, animationTiming: nil)
        layer.updateTransform(CATransform3DIdentity, anchor: .left, oldSize: size, animationTiming: .easeInEaseOut(duration: 0.25))
      }),
      ("perspective turn during a resize", CGRect(x: 0, y: 0, width: 100, height: 50), .zero, .center, 0.27, { layer in
        let size = layer.bounds.size
        let largeSize = CGSize(width: 600, height: 300)
        layer.updateTransform(Constants.perspectiveTurn, anchor: .center, oldSize: size, animationTiming: nil)
        layer.animateFrame(to: CGRect(origin: .zero, size: largeSize), timing: .easeInEaseOut(duration: 0.3))
        layer.updateTransform(Constants.perspectiveTurn, anchor: .center, oldSize: size, animationTiming: .easeInEaseOut(duration: 0.3))
      }),
      ("scale during a resize", CGRect(x: 0, y: 0, width: 100, height: 100), .zero, .center, 0.27, { layer in
        let size = layer.bounds.size
        let largeSize = CGSize(width: 1000, height: 1000)
        layer.animateFrame(to: CGRect(origin: .zero, size: largeSize), timing: .linear(duration: 0.25))
        layer.updateTransform(CATransform3DMakeScale(4, 4, 1), anchor: .center, oldSize: size, animationTiming: .linear(duration: 0.25))
      }),
    ]

    for testCase in cases {
      // when: the change animates
      let timeline = PausedTimeline(frame: testCase.frame, anchorPoint: testCase.anchorPoint)
      testCase.change(timeline.layer)

      // then: halfway between each two keyframes, where the interpolation moves the point the most, the layer shows the
      // point within a quarter point of its place, and during a large resize within the hundredth or two more that Core
      // Animation adds by solving the frame animation's timing in single precision
      let animation = try unwrap(timeline.layer.animation(forKey: "transform") as? AnchoredTransformKeyframeAnimation, testCase.name)
      let intervals = try unwrap(animation.values?.count, testCase.name) - 1
      for index in 0 ..< intervals {
        timeline.show(at: animation.beginTime + animation.duration * (Double(index) + 0.5) / Double(intervals))
        expect(try drift(of: timeline.layer, at: testCase.anchor), "\(testCase.name) at \(index)") <= testCase.bound
      }
    }
  }

  func test_updateTransform_slowTurnWithASpringWithoutDamping_followsTenSecondsAtTheRate() throws {
    // given: a layer at rest
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size

    // when: an eighth turn about its top left corner animates with a slow spring without damping, which never finishes,
    // and turns slowly enough that 60 keyframes per second keep the corner in place between them
    layer.updateTransform(Constants.eighthTurn, anchor: .topLeft, oldSize: size, animationTiming: .spring(dampingRatio: 0, response: 2))

    // then: the keyframes follow the spring for 10 seconds at 60 per second, as the jump to the eighth turn at the end,
    // which no number of keyframes shortens, doesn't make them denser
    let animation = try unwrap(layer.animation(forKey: "transform") as? AnchoredTransformKeyframeAnimation)
    expect(animation.duration) == 10
    expect(animation.values?.count) == 601
  }

  func test_updateTransform_changeThatTakesThePointToTheDepthOfTheEye_takesTheMostKeyframes() throws {
    // given: a layer whose anchor point is at its center, in perspective about its top left corner
    let smallSize = CGSize(width: 128, height: 128)
    let largeSize = CGSize(width: 384, height: 384)
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    var perspective = CATransform3DIdentity
    perspective.m34 = -1 / 512
    layer.updateTransform(perspective, anchor: .topLeft, oldSize: smallSize, animationTiming: nil)

    // when: during a fast resize, a change moves the corner behind the eye, which projects it to infinity halfway
    // between two keyframes, where it's at the depth of the eye
    let target = CATransform3DConcat(CATransform3DMakeTranslation(-1, -1, 2048), perspective)
    layer.animateFrame(to: CGRect(origin: .zero, size: largeSize), timing: .linear(duration: 1 / 32))
    layer.updateTransform(target, anchor: .topLeft, oldSize: smallSize, animationTiming: .linear(duration: 1 / 32))

    // then: the keyframes stop at the most for the 1/32 second, 15 intervals at 8 times 60 per second, and land at the
    // transform about the corner at the new size
    let animation = try unwrap(layer.animation(forKey: "transform") as? AnchoredTransformKeyframeAnimation)
    let values = try unwrap(animation.values as? [NSValue])
    expect(values.count) == 16
    try expectTransform(unwrap(values.last).caTransform3DValue, CALayer.anchoredTransform(target, pivotOffset: SIMD2(-0.5, -0.5), size: largeSize))
  }

  // MARK: - Changes in Flight

  func test_updateTransform_withATimingDuringAChange_stacksOnIt() throws {
    // given: a layer turning a quarter turn about its top left corner over 10 seconds
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 10))

    // when: 2 seconds in, an animated update scales it instead over a second
    timeline.move(to: 102)
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 1))

    // then: the turn goes on over its 10 seconds, followed by the scale's way from the quarter turn over its second, so
    // the layer starts from the turn shown, without a jump, and lands at the scale when the turn ends
    timeline.show(at: 102)
    try expectShownTransform(of: layer, interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: 0.2), about: .topLeft, within: 0.01)
    for time in [102.5, 103, 106] {
      timeline.show(at: time)
      let shown = stacked([
        (CATransform3DIdentity, Constants.quarterTurn, (time - 100) / 10),
        (Constants.quarterTurn, Constants.doubleScale, min(time - 102, 1)),
      ])
      try expectShownTransform(of: layer, shown, about: .topLeft, within: 0.01, "at \(time)")
    }
    timeline.show(at: 110)
    try expectShownTransform(of: layer, Constants.doubleScale, about: .topLeft, within: 0.01)
  }

  func test_updateTransform_withoutATimingDuringAChange_glidesToTheNewTransform() throws {
    // given: a layer turning a quarter turn about its top left corner over 10 seconds
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 10))

    // when: 2 seconds in, an update without a timing scales it instead
    timeline.move(to: 102)
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, animationTiming: nil)

    // then: the layer glides from the turn shown to the scale with an ease out, over the 8 seconds the turn had left
    let start = interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: 0.2)
    let easeOut = AnimationCurve(timingFunction: CAMediaTimingFunction(name: .easeOut))
    for time in [0.0, 2, 4, 8] {
      timeline.show(at: 102 + time)
      let progress = easeOut.progress(atFraction: time / 8)
      try expectShownTransform(of: layer, interpolated(from: start, to: Constants.doubleScale, progress: progress), about: .topLeft, within: 0.01)
    }
  }

  func test_updateTransform_withoutATimingDuringAChangeThatNeverFinishes_glidesOverTheDefaultDuration() throws {
    // given: a layer scaling about its top left corner with a spring without damping, which never finishes
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, animationTiming: .spring(dampingRatio: 0, response: 0.5))

    // when: a second in, an update without a timing scales it more
    timeline.move(to: 101)
    layer.updateTransform(Constants.tripleScale, anchor: .topLeft, oldSize: size, animationTiming: nil)

    // then: the glide lands after the default duration, as a change that never finishes has no landing to glide to
    let animation = try unwrap(layer.animation(forKey: "transform") as? AnchoredTransformBasicAnimation)
    expect(animation.duration).to(beApproximatelyEqual(to: Animations.defaultAnimationDuration, within: 1e-9))
    timeline.show(at: 101 + Animations.defaultAnimationDuration)
    try expectShownTransform(of: layer, Constants.tripleScale, about: .topLeft, within: 0.01)
  }

  func test_updateTransform_zeroDurationDuringAChange_appliesAtOnce() throws {
    // given: a layer turning a quarter turn about its top left corner over 10 seconds
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 10))

    // when: 2 seconds in, an update with a timing of no duration scales it instead
    timeline.move(to: 102)
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 0))

    // then: the layer shows the scale at once, and the turn's animation is gone
    expect(layer.animation(forKey: "transform")) == nil
    timeline.show(at: 102)
    try expectShownTransform(of: layer, Constants.doubleScale, about: .topLeft, within: 1e-9)
  }

  func test_updateTransform_resizeDuringAChange_keepsTheCourse() throws {
    // given: a layer of 40 x 20 turning a quarter turn about its top left corner over 4 seconds
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: .linear(duration: 4))

    // when: a second in, an animated update grows it to 80 x 40 over a second, keeping the transform
    timeline.move(to: 101)
    layer.animateFrame(to: CGRect(origin: .zero, size: Constants.largeSize), timing: .linear(duration: 1))
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: .linear(duration: 1))

    // then: the turn keeps its course over its 4 seconds, about the corner at the size the layer shows
    for time in [101, 101.5, 102, 103, 105] {
      timeline.show(at: time)
      let progress = min((time - 100) / 4, 1)
      try expectShownTransform(of: layer, interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: progress), about: .topLeft, within: 0.01)
    }
  }

  func test_updateTransform_resizeWithoutATimingDuringAChangeToATransformThatTheSizeDoesntMove_followsTheResize() throws {
    // given: a layer of 40 x 20 turning back from a quarter turn to no turn about its top left corner over 2 seconds,
    // whose transform at the end, the identity, the size doesn't move
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: nil)
    layer.updateTransform(CATransform3DIdentity, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: .linear(duration: 2))

    // when: a second in, an update without a timing makes it 80 x 40, keeping the transform
    timeline.move(to: 101)
    layer.retargetFrame(to: CGRect(origin: .zero, size: Constants.largeSize))
    layer.updateTransform(CATransform3DIdentity, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: nil)

    // then: the turn keeps its course about the corner at the new size
    for time in [101.0, 101.5] {
      timeline.show(at: time)
      try expectShownTransform(of: layer, interpolated(from: Constants.quarterTurn, to: CATransform3DIdentity, progress: (time - 100) / 2), about: .topLeft, within: 0.01)
    }
  }

  func test_updateTransform_resizeWithoutATimingDuringAChange_keepsTheCourse() throws {
    // given: a layer of 40 x 20 turning a quarter turn about its top left corner over 4 seconds
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: .linear(duration: 4))

    // when: a second in, an update without a timing makes it 80 x 40, keeping the transform
    timeline.move(to: 101)
    layer.retargetFrame(to: CGRect(origin: .zero, size: Constants.largeSize))
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: nil)

    // then: the turn keeps its course about the corner at the new size
    for time in [101.0, 102, 103] {
      timeline.show(at: time)
      try expectShownTransform(of: layer, interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: (time - 100) / 4), about: .topLeft, within: 0.01)
    }
  }

  func test_updateTransform_withoutATimingDuringAResize_changesAtOnceAndFollowsTheSize() throws {
    // given: a layer turned a quarter turn about its top left corner, growing from 40 x 20 to 80 x 40 over a second
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: nil)
    layer.animateFrame(to: CGRect(origin: .zero, size: Constants.largeSize), timing: .linear(duration: 1))

    // when: the update turns it an eighth turn without a timing
    layer.updateTransform(Constants.eighthTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: nil)

    // then: the layer shows the eighth turn at once, as nothing turned it, about the corner at the size it shows
    for time in [100, 100.5] {
      timeline.show(at: time)
      try expectShownTransform(of: layer, Constants.eighthTurn, about: .topLeft, within: 0.01)
    }
  }

  func test_updateTransform_withoutATimingAfterTheChangeDuringAResize_changesAtOnceAndFollowsTheSize() throws {
    // given: a layer that turned a quarter turn about its top left corner over a second, while growing over 3 seconds
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.animateFrame(to: CGRect(origin: .zero, size: Constants.largeSize), timing: .linear(duration: 3))
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: .linear(duration: 1))

    // when: 2 seconds in, after the turn ended, an update without a timing turns it an eighth turn instead
    timeline.move(to: 102)
    layer.updateTransform(Constants.eighthTurn, anchor: .topLeft, oldSize: Constants.largeSize, animationTiming: nil)

    // then: the layer shows the eighth turn at once, as the turn was at rest, about the corner at the size it shows
    for time in [102, 102.5] {
      timeline.show(at: time)
      try expectShownTransform(of: layer, Constants.eighthTurn, about: .topLeft, within: 0.01)
    }
  }

  func test_updateTransform_withATimingAfterTheChangeDuringAResize_startsFromTheTransform() throws {
    // given: a layer that turned a quarter turn about its top left corner over a second, while growing over 3 seconds
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.animateFrame(to: CGRect(origin: .zero, size: Constants.largeSize), timing: .linear(duration: 3))
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: .linear(duration: 1))

    // when: 2 seconds in, after the turn ended, an animated update turns it an eighth turn instead over a second
    timeline.move(to: 102)
    layer.updateTransform(Constants.eighthTurn, anchor: .topLeft, oldSize: Constants.largeSize, animationTiming: .linear(duration: 1))

    // then: the change starts from the quarter turn, about the corner at the size the layer shows
    for time in [0, 0.5, 1] {
      timeline.show(at: 102 + time)
      try expectShownTransform(of: layer, interpolated(from: Constants.quarterTurn, to: Constants.eighthTurn, progress: time), about: .topLeft, within: 0.01)
    }
  }

  func test_updateTransform_anchorChangedDuringAChange_startsFromTheShownTransform() throws {
    // given: a layer turning a quarter turn about its top left corner over 10 seconds, 2 seconds in
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 10))
    timeline.show(at: 102)
    let shownTransform = interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: 0.2)
    try expectShownTransform(of: layer, shownTransform, about: .topLeft, within: 0.01)

    // when: an animated update turns it about its bottom right corner instead, over a second
    layer.updateTransform(Constants.quarterTurn, anchor: .bottomRight, oldSize: size, animationTiming: .linear(duration: 1))

    // then: the layer shows the same at first, then lands at the turn about the new corner
    timeline.show(at: 102)
    try expectShownTransform(of: layer, shownTransform, about: .topLeft, within: 0.01)
    timeline.show(at: 103)
    try expectShownTransform(of: layer, Constants.quarterTurn, about: .bottomRight, within: 0.01)
  }

  func test_updateTransform_anchorChangedFromTheAnchorPointDuringAResize_startsFromTheShownTransform() throws {
    // given: a layer whose anchor point is at its center, turned a quarter turn about its center, which the size doesn't
    // move, halfway through growing from 40 x 20 to 80 x 40 over a second
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.updateTransform(Constants.quarterTurn, anchor: .center, oldSize: Constants.smallSize, animationTiming: nil)
    layer.animateFrame(to: CGRect(origin: .zero, size: Constants.largeSize), timing: .linear(duration: 1))
    timeline.show(at: 100.5)
    try expectShownTransform(of: layer, Constants.quarterTurn, about: .center, within: 0.01)

    // when: an animated update turns it about its top left corner instead, over a second
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.largeSize, animationTiming: .linear(duration: 1))

    // then: the layer shows the same at first, then lands at the turn about the corner
    timeline.show(at: 100.5)
    try expectShownTransform(of: layer, Constants.quarterTurn, about: .center, within: 0.01)
    timeline.show(at: 101.5)
    try expectShownTransform(of: layer, Constants.quarterTurn, about: .topLeft, within: 0.01)
  }

  func test_updateTransform_animationsThatArentEvaluatedOnALayerNotShownYet_startFromTheModel() throws {
    // given: a layer that Core Animation hasn't shown yet, so it has no presentation layer, turned a quarter turn about
    // its top left corner, with keyframe animations of its transform and its size, which the framework doesn't evaluate
    let layer = CALayer()
    layer.frame = CGRect(origin: .zero, size: Constants.largeSize)
    let size = Constants.largeSize
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: nil)
    let modelTransform = layer.transform
    for keyPath in ["transform", "bounds.size"] {
      let animation = CAKeyframeAnimation(keyPath: keyPath)
      animation.values = [layer.value(forKeyPath: keyPath) as Any, layer.value(forKeyPath: keyPath) as Any]
      animation.beginTime = layer.currentTime
      animation.duration = 10
      layer.add(animation, forKey: "keyframes \(keyPath)")
    }

    // when: an animated update scales it instead
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 1))

    // then: the change starts from the model transform, at the layer's size, as nothing tells what the layer shows
    let animation = try unwrap(layer.animation(forKey: "transform") as? AnchoredTransformKeyframeAnimation)
    let values = try unwrap(animation.values as? [NSValue])
    try expectTransform(unwrap(values.first).caTransform3DValue, modelTransform)
    try expectTransform(unwrap(values.last).caTransform3DValue, layer.transform)

    // when: an animated update turns it about its bottom right corner instead, during the change
    let keyframeTransform = values[0].caTransform3DValue
    layer.updateTransform(Constants.doubleScale, anchor: .bottomRight, oldSize: size, animationTiming: .linear(duration: 1))

    // then: the change starts from the transform that the scale shows, about the new corner at the layer's size
    let newValues = try unwrap((layer.animation(forKey: "transform") as? AnchoredTransformKeyframeAnimation)?.values as? [NSValue])
    let firstTransform = try unwrap(newValues.first).caTransform3DValue
    for (value, expected) in zip(
      [firstTransform.m11, firstTransform.m12, firstTransform.m21, firstTransform.m22, firstTransform.m41, firstTransform.m42],
      [keyframeTransform.m11, keyframeTransform.m12, keyframeTransform.m21, keyframeTransform.m22, keyframeTransform.m41, keyframeTransform.m42]
    ) {
      expect(value).to(beApproximatelyEqual(to: expected, within: 1e-9))
    }
  }

  // MARK: - Stacking

  func test_updateTransform_turnDuringATurn_keepsItsSpeed() throws {
    // given: a layer halfway through a quarter turn about its top left corner, eased in and out over a second, where the
    // turn is the fastest
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: .easeInEaseOut(duration: 1))
    timeline.show(at: 100.45)
    let angleBefore = try shownAngle(of: layer)

    // when: an animated update turns it a quarter turn further, eased in and out over a second
    timeline.move(to: 100.5)
    layer.updateTransform(Constants.halfTurn, anchor: .topLeft, oldSize: size, animationTiming: .easeInEaseOut(duration: 1))

    // then: the turn keeps its speed through the update instead of stopping, and lands at the half turn
    timeline.show(at: 100.5)
    let angleAtUpdate = try shownAngle(of: layer)
    timeline.show(at: 100.55)
    let angleAfter = try shownAngle(of: layer)
    expect((angleAfter - angleAtUpdate) / (angleAtUpdate - angleBefore)).to(beApproximatelyEqual(to: 1, within: 0.1))
    timeline.show(at: 101.5)
    try expectShownTransform(of: layer, Constants.halfTurn, about: .topLeft, within: 0.01)
  }

  func test_updateTransform_changeDuringAChange_followsBothCourses() throws {
    // given: changes made during a change in flight: a turn further, a turn back, a scale on a scale, a tilt in
    // perspective on a turn, a tilt on a tilt, and a turn that waits out a delay
    let tilt = CATransform3DRotate(Constants.perspective, .pi / 6, 0, 1, 0)
    let cases: [(name: String, first: CATransform3D, second: CATransform3D, delay: TimeInterval)] = [
      ("turn further", Constants.quarterTurn, Constants.halfTurn, 0),
      ("turn back", Constants.quarterTurn, CATransform3DIdentity, 0),
      ("scale on a scale", Constants.doubleScale, Constants.tripleScale, 0),
      ("tilt on a turn", Constants.quarterTurn, tilt, 0),
      ("tilt on a tilt", tilt, Constants.perspectiveTurn, 0),
      ("delayed turn", Constants.quarterTurn, Constants.halfTurn, 0.25),
    ]

    for testCase in cases {
      // when: halfway through the first change about the top left corner, linear over a second, the second is made,
      // linear over a second too
      let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
      let layer = timeline.layer
      let size = layer.bounds.size
      layer.updateTransform(testCase.first, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 1))
      timeline.move(to: 100.5)
      layer.updateTransform(testCase.second, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 1, delay: testCase.delay))

      // then: the first change goes on along its course, followed by the second's way from the first's end, until the
      // second lands
      for time in [100.5, 100.75, 101, 101.25, 101.5 + testCase.delay] {
        timeline.show(at: time)
        let shown = stacked([
          (CATransform3DIdentity, testCase.first, min(time - 100, 1)),
          (testCase.first, testCase.second, min(max(time - 100.5 - testCase.delay, 0), 1)),
        ])
        try expectShownTransform(of: layer, shown, about: .topLeft, within: 0.01, "\(testCase.name) at \(time)")
      }
    }
  }

  func test_updateTransform_changeAfterStackedChangesLanded_leavesThemOut() throws {
    // given: changes stacked about the top left corner, of which one has landed: the first, one in the middle, the first
    // two, or the last, which the next change starts from
    let cases: [(name: String, changes: [(transform: CATransform3D, time: TimeInterval, duration: TimeInterval)])] = [
      ("first", [(Constants.quarterTurn, 100, 0.5), (Constants.halfTurn, 100.25, 2)]),
      ("middle", [(Constants.quarterTurn, 100, 3), (Constants.halfTurn, 100.25, 0.5), (Constants.threeQuarterTurn, 100.5, 2)]),
      ("first two", [(Constants.quarterTurn, 100, 0.25), (Constants.halfTurn, 100.25, 0.5), (Constants.threeQuarterTurn, 100.5, 2)]),
      ("last", [(Constants.quarterTurn, 100, 3), (Constants.halfTurn, 100.25, 0.5)]),
    ]

    for testCase in cases {
      let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
      let layer = timeline.layer
      let size = layer.bounds.size
      for change in testCase.changes {
        timeline.move(to: change.time)
        layer.updateTransform(change.transform, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: change.duration))
      }

      // when: at 101, a change turns the layer back to no turn over a second
      timeline.move(to: 101)
      layer.updateTransform(CATransform3DIdentity, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 1))

      // then: the changes in flight go on along their courses, followed by the new change's way, as with the landed
      // changes at their ends, until the last of them lands
      let changes = testCase.changes + [(CATransform3DIdentity, 101, 1)]
      let landingTime = changes.map { $0.time + $0.duration }.max() ?? 0
      for time in [101, 101.5, 102, landingTime] {
        timeline.show(at: time)
        var from = CATransform3DIdentity
        let courses = changes.map { change -> (from: CATransform3D, to: CATransform3D, progress: Double) in
          defer { from = change.transform }
          return (from, change.transform, min(max((time - change.time) / change.duration, 0), 1))
        }
        try expectShownTransform(of: layer, stacked(courses), about: .topLeft, within: 0.01, "\(testCase.name) at \(time)")
      }
    }
  }

  func test_updateTransform_changeDuringAChangeThatNeverFinishes_startsFromTheTransformShown() throws {
    // given: a change that never finishes in flight, a turn about the top left corner with a spring without damping, made
    // at rest, or during a turn, where it starts from the transform shown instead of stacking on the turn
    let spring = AnimationTiming.spring(dampingRatio: 0, response: 0.5)
    let springCurve = AnimationCurve(CABasicAnimation.makeAnimation(spring))
    let target = CATransform3DMakeRotation(.pi / 3, 0, 0, 1)
    for isDuringATurn in [false, true] {
      let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
      let layer = timeline.layer
      let size = layer.bounds.size
      let start: CATransform3D
      if isDuringATurn {
        layer.updateTransform(Constants.eighthTurn, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 2))
        timeline.move(to: 100.25)
        layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: spring)
        let springStart = interpolated(from: CATransform3DIdentity, to: Constants.eighthTurn, progress: 0.125)
        start = interpolated(from: springStart, to: Constants.quarterTurn, progress: springCurve.progress(forElapsedTime: 0.75))
      } else {
        layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: spring)
        start = interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: springCurve.progress(forElapsedTime: 1))
      }

      // when: at 101, an animated update turns it to 60° instead over a second
      timeline.move(to: 101)
      layer.updateTransform(target, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 1))

      // then: the turn starts over from the transform shown, as the spring can't keep going next to it, and lands a
      // second later
      for time in [101, 101.5, 102] {
        timeline.show(at: time)
        let shown = interpolated(from: start, to: target, progress: time - 101)
        try expectShownTransform(of: layer, shown, about: .topLeft, within: 0.01, "during a turn \(isDuringATurn) at \(time)")
      }
    }
  }

  func test_updateTransform_changeDuringAChangeToATransformWithoutAnInverse_startsFromTheTransformShown() throws {
    // given: a layer scaling to nothing about its top left corner over 2 seconds, an end that has no inverse to take off
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(CATransform3DMakeScale(0, 0, 1), anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 2))

    // when: a second in, an animated update scales it to twice its size instead over a second
    timeline.move(to: 101)
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 1))

    // then: the scale starts over from the transform shown, and lands a second later
    let start = interpolated(from: CATransform3DIdentity, to: CATransform3DMakeScale(0, 0, 1), progress: 0.5)
    for time in [101, 101.5, 102] {
      timeline.show(at: time)
      try expectShownTransform(of: layer, interpolated(from: start, to: Constants.doubleScale, progress: time - 101), about: .topLeft, within: 0.01, "at \(time)")
    }
  }

  func test_updateTransform_changeDuringAChangeThatStacksPastTenSeconds_startsFromTheTransformShown() throws {
    // given: a layer turning a quarter turn about its top left corner over 9 seconds
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 9))

    // when: a second in, an animated update turns it to the half turn after a delay of 2 seconds, over 9 seconds, which
    // would stack the turns over the next 11 seconds, past the 10 seconds that keyframes follow
    timeline.move(to: 101)
    layer.updateTransform(Constants.halfTurn, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 9, delay: 2))

    // then: the turn starts over from the transform shown, which it holds through the delay, and lands at its end
    let start = interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: 1.0 / 9)
    for time in [101, 103, 107.5, 111.5, 112] {
      timeline.show(at: time)
      let shown = interpolated(from: start, to: Constants.halfTurn, progress: min(max((time - 103) / 9, 0), 1))
      try expectShownTransform(of: layer, shown, about: .topLeft, within: 0.01, "at \(time)")
    }
  }

  func test_updateTransform_resizeDuringStackedChanges_keepsTheirCourses() throws {
    // given: a layer of 40 x 20 turning a quarter turn about its top left corner over 2 seconds, with a turn to the half
    // turn stacked on it a second in, over 2 seconds
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: .linear(duration: 2))
    timeline.move(to: 101)
    layer.updateTransform(Constants.halfTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: .linear(duration: 2))

    // when: half a second later, an animated update grows it to 80 x 40 over a second, keeping the transform
    timeline.move(to: 101.5)
    layer.animateFrame(to: CGRect(origin: .zero, size: Constants.largeSize), timing: .linear(duration: 1))
    layer.updateTransform(Constants.halfTurn, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: .linear(duration: 1))

    // then: both turns keep their courses, about the corner at the size that the layer shows
    for time in [101.5, 102, 102.5, 103] {
      timeline.show(at: time)
      let shown = stacked([
        (CATransform3DIdentity, Constants.quarterTurn, min((time - 100) / 2, 1)),
        (Constants.quarterTurn, Constants.halfTurn, min((time - 101) / 2, 1)),
      ])
      try expectShownTransform(of: layer, shown, about: .topLeft, within: 0.01, "at \(time)")
    }
  }

  func test_updateTransform_withoutATimingDuringStackedChanges_glidesOverTheTimeTheyHaveLeft() throws {
    // given: a layer turning a quarter turn about its top left corner over 2 seconds, with a turn to the half turn stacked
    // on it a second in, over 2 seconds, which ends last
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 2))
    timeline.move(to: 101)
    layer.updateTransform(Constants.halfTurn, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 2))

    // when: at 102, an update without a timing scales it instead
    timeline.move(to: 102)
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, animationTiming: nil)

    // then: the layer glides from the transform shown to the scale with an ease out, over the second that the stacked
    // turn has left
    let start = stacked([(CATransform3DIdentity, Constants.quarterTurn, 1), (Constants.quarterTurn, Constants.halfTurn, 0.5)])
    let easeOut = AnimationCurve(timingFunction: CAMediaTimingFunction(name: .easeOut))
    for time in [0, 0.5, 1] {
      timeline.show(at: 102 + time)
      let progress = easeOut.progress(atFraction: time)
      try expectShownTransform(of: layer, interpolated(from: start, to: Constants.doubleScale, progress: progress), about: .topLeft, within: 0.01, "at \(time)")
    }
  }

  // MARK: - One Animation

  func test_updateTransform_changesThatBlendLinearly_animateAsOneAnimationAboutThePoint() throws {
    // given: changes that Core Animation blends linearly, as only their scale and translation differ: a scale, a move, a
    // scale and a move, a scale under a turn, and a flip of an axis
    let turn = CATransform3DMakeRotation(.pi / 6, 0, 0, 1)
    let cases: [(name: String, from: CATransform3D, to: CATransform3D)] = [
      ("scale", CATransform3DIdentity, Constants.doubleScale),
      ("move", CATransform3DIdentity, CATransform3DMakeTranslation(30, -20, 0)),
      ("scale and move", CATransform3DMakeTranslation(10, 10, 0), CATransform3DTranslate(Constants.doubleScale, -5, 5, 0)),
      ("scale under a turn", turn, CATransform3DScale(turn, 0.5, 2, 1)),
      ("flip of an axis", CATransform3DIdentity, CATransform3DMakeScale(-1, 1, 1)),
    ]

    for testCase in cases {
      // when: the change about the top left corner animates over a second
      let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
      let layer = timeline.layer
      let size = layer.bounds.size
      layer.updateTransform(testCase.from, anchor: .topLeft, oldSize: size, animationTiming: nil)
      layer.updateTransform(testCase.to, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 1))

      // then: one animation of a timing function changes the transform, and the layer shows the change so far about the
      // corner
      expect(layer.animation(forKey: "transform") is AnchoredTransformBasicAnimation, testCase.name) == true
      for time in [0.25, 0.5, 0.75] {
        timeline.show(at: 100 + time)
        let shown = interpolated(from: testCase.from, to: testCase.to, progress: time)
        try expectShownTransform(of: layer, shown, about: .topLeft, within: 0.01, "\(testCase.name) at \(time)")
      }
    }
  }

  func test_updateTransform_scaleWithADelayedTiming_holdsTheTransformUntilTheDelayPasses() throws {
    // given: a layer at rest
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size

    // when: a scale to twice its size about its top left corner animates over a second, after half a second
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 1, delay: 0.5))

    // then: one animation begins after the delay, and the layer shows no scale until then, then the scale so far
    let animation = try unwrap(layer.animation(forKey: "transform") as? AnchoredTransformBasicAnimation)
    expect(animation.beginTime) == 100.5
    for (time, progress) in [(100.25, 0.0), (101, 0.5), (101.5, 1)] {
      timeline.show(at: time)
      try expectShownTransform(of: layer, interpolated(from: CATransform3DIdentity, to: Constants.doubleScale, progress: progress), about: .topLeft, within: 0.01)
    }
  }

  func test_updateTransform_animatedUpdateDuringTheDelayOfAScale_stacksOnTheScaleToCome() throws {
    // given: a layer scaling to twice its size about its top left corner over a second, after a second, in one animation
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 1, delay: 1))

    // when: half a second in, before the scale begins, an animated update scales it to three times its size instead
    timeline.move(to: 100.5)
    layer.updateTransform(Constants.tripleScale, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 1))

    // then: the layer starts from no scale, which it shows during the delay, and the new scale's way from twice the size
    // follows the scale to come, which still begins after its delay, so the layer lands at three times its size when it ends
    for time in [100.5, 101, 101.5] {
      timeline.show(at: time)
      let shown = stacked([
        (CATransform3DIdentity, Constants.doubleScale, min(max(time - 101, 0), 1)),
        (Constants.doubleScale, Constants.tripleScale, time - 100.5),
      ])
      try expectShownTransform(of: layer, shown, about: .topLeft, within: 0.01, "at \(time)")
    }
    timeline.show(at: 102)
    try expectShownTransform(of: layer, Constants.tripleScale, about: .topLeft, within: 0.01)
  }

  func test_updateTransform_scaleWithASpringWithoutDamping_followsTheSpringPastTenSeconds() throws {
    for isDuringAScale in [false, true] {
      // given: a layer at rest, or a quarter of the way through a scale to three times its size about its top left
      // corner over 2 seconds
      let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
      let layer = timeline.layer
      let size = layer.bounds.size
      if isDuringAScale {
        layer.updateTransform(Constants.tripleScale, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 2))
        timeline.move(to: 100.5)
      }

      // when: a scale about its top left corner animates with a spring without damping, which never finishes
      layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, animationTiming: .spring(dampingRatio: 0, response: 0.5))

      // then: one spring animation scales it from the transform shown, as it doesn't stack on the scale in flight, and the
      // layer shows the scale that the spring gives about the corner, past the 10 seconds that keyframes follow
      let animation = try unwrap(layer.animation(forKey: "transform") as? AnchoredTransformSpringAnimation, "during a scale \(isDuringAScale)")
      let curve = AnimationCurve(animation)
      let start = isDuringAScale ? interpolated(from: CATransform3DIdentity, to: Constants.tripleScale, progress: 0.25) : CATransform3DIdentity
      let updateTime = isDuringAScale ? 100.5 : 100
      for time in [0.1, 0.3, 12.1] {
        timeline.show(at: updateTime + time)
        let shown = interpolated(from: start, to: Constants.doubleScale, progress: curve.progress(forElapsedTime: time))
        try expectShownTransform(of: layer, shown, about: .topLeft, within: 0.01, "during a scale \(isDuringAScale) at \(time)")
      }
    }
  }

  func test_updateTransform_resizeDuringAScale_keepsTheCourse() throws {
    // given: a layer of 40 x 20 scaling to twice its size about its top left corner over 4 seconds, in one animation
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: .linear(duration: 4))
    expect(layer.animation(forKey: "transform") is AnchoredTransformBasicAnimation) == true

    // when: a second in, an animated update grows it to 80 x 40 over a second, keeping the transform
    timeline.move(to: 101)
    layer.animateFrame(to: CGRect(origin: .zero, size: Constants.largeSize), timing: .linear(duration: 1))
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: .linear(duration: 1))

    // then: the scale keeps its course over its 4 seconds, about the corner at the size the layer shows
    for time in [101, 101.5, 102, 103, 105] {
      timeline.show(at: time)
      let progress = min((time - 100) / 4, 1)
      try expectShownTransform(of: layer, interpolated(from: CATransform3DIdentity, to: Constants.doubleScale, progress: progress), about: .topLeft, within: 0.01)
    }
  }

  func test_updateTransform_resizeWithoutATimingDuringAScaleToTheIdentity_followsTheResize() throws {
    // given: a layer of 40 x 20 scaling back from twice its size to no scale about its top left corner over 2 seconds,
    // in one animation, whose transform at the end, the identity, the size doesn't move
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: nil)
    layer.updateTransform(CATransform3DIdentity, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: .linear(duration: 2))
    expect(layer.animation(forKey: "transform") is AnchoredTransformBasicAnimation) == true

    // when: a second in, an update without a timing makes it 80 x 40, keeping the transform
    timeline.move(to: 101)
    layer.retargetFrame(to: CGRect(origin: .zero, size: Constants.largeSize))
    layer.updateTransform(CATransform3DIdentity, anchor: .topLeft, oldSize: Constants.smallSize, animationTiming: nil)

    // then: the scale keeps its course about the corner at the new size
    for time in [101.0, 101.5] {
      timeline.show(at: time)
      try expectShownTransform(of: layer, interpolated(from: Constants.doubleScale, to: CATransform3DIdentity, progress: (time - 100) / 2), about: .topLeft, within: 0.01)
    }
  }

  func test_updateTransform_withoutATimingDuringAScale_glidesToTheNewTransform() throws {
    // given: a layer scaling to twice its size about its top left corner over 10 seconds, in one animation
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 10))

    // when: 2 seconds in, an update without a timing scales it to three times its size instead
    timeline.move(to: 102)
    layer.updateTransform(Constants.tripleScale, anchor: .topLeft, oldSize: size, animationTiming: nil)

    // then: one animation glides from the scale shown to the new one with an ease out, over the 8 seconds the scale had
    // left
    expect(layer.animation(forKey: "transform") is AnchoredTransformBasicAnimation) == true
    let start = interpolated(from: CATransform3DIdentity, to: Constants.doubleScale, progress: 0.2)
    let easeOut = AnimationCurve(timingFunction: CAMediaTimingFunction(name: .easeOut))
    for time in [0.0, 2, 4, 8] {
      timeline.show(at: 102 + time)
      let progress = easeOut.progress(atFraction: time / 8)
      try expectShownTransform(of: layer, interpolated(from: start, to: Constants.tripleScale, progress: progress), about: .topLeft, within: 0.01)
    }
  }

  func test_updateTransform_turnAboutAnotherPointDuringAScale_startsFromTheShownTransform() throws {
    // given: a layer scaling to twice its size about its top left corner over 10 seconds, in one animation, 2 seconds in
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, animationTiming: .linear(duration: 10))
    timeline.show(at: 102)
    let shownScale = interpolated(from: CATransform3DIdentity, to: Constants.doubleScale, progress: 0.2)
    try expectShownTransform(of: layer, shownScale, about: .topLeft, within: 0.01)

    // when: an animated update turns it a quarter turn about its bottom right corner instead, over a second
    layer.updateTransform(Constants.quarterTurn, anchor: .bottomRight, oldSize: size, animationTiming: .linear(duration: 1))

    // then: the layer shows the same at first, then lands at the turn about the new corner
    timeline.show(at: 102)
    try expectShownTransform(of: layer, shownScale, about: .topLeft, within: 0.01)
    timeline.show(at: 103)
    try expectShownTransform(of: layer, Constants.quarterTurn, about: .bottomRight, within: 0.01)
  }

  // MARK: - Point at the Anchor Point

  func test_updateTransform_pointAtTheAnchorPoint_animatesTheTransformItself() throws {
    // given: a layer whose anchor point is at its center
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size

    // when: a quarter turn about its center animates over 2 seconds
    layer.updateTransform(Constants.quarterTurn, anchor: .center, oldSize: size, animationTiming: .linear(duration: 2))

    // then: the turn is a basic animation of the transform, which the size doesn't change, and the layer shows it
    let animation = try unwrap(layer.animation(forKey: "transform") as? CABasicAnimation)
    expect(animation.duration) == 2
    timeline.show(at: 101)
    try expectShownTransform(of: layer, interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: 0.5), about: .center, within: 0.01)

    // when: a second in, an update without a timing scales it instead
    layer.updateTransform(Constants.doubleScale, anchor: .center, oldSize: size, animationTiming: nil)

    // then: the scale glides from the turn shown, over the second the turn had left
    let start = interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: 0.5)
    let easeOut = AnimationCurve(timingFunction: CAMediaTimingFunction(name: .easeOut))
    for time in [0.0, 0.5, 1] {
      timeline.show(at: 101 + time)
      let progress = easeOut.progress(atFraction: time)
      try expectShownTransform(of: layer, interpolated(from: start, to: Constants.doubleScale, progress: progress), about: .center, within: 0.01)
    }
  }

  func test_updateTransform_pointAtTheAnchorPoint_glideFromAChangeThatNeverFinishes_takesTheDefaultDuration() throws {
    // given: a layer whose anchor point is at its center, scaling about its center with a spring without damping
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.doubleScale, anchor: .center, oldSize: size, animationTiming: .spring(dampingRatio: 0, response: 0.5))

    // when: a second in, an update without a timing scales it more
    timeline.move(to: 101)
    layer.updateTransform(Constants.tripleScale, anchor: .center, oldSize: size, animationTiming: nil)

    // then: the glide takes the default duration, as a change that never finishes has no landing to glide to
    let glide = try unwrap(layer.animation(forKey: "transform") as? CABasicAnimation)
    expect(glide.duration) == Animations.defaultAnimationDuration
    expect(glide.timingFunction) == CAMediaTimingFunction(name: .easeOut)
  }

  func test_updateTransform_pointAtTheAnchorPoint_zeroDurationDuringAChange_appliesAtOnce() throws {
    // given: a layer whose anchor point is at its center, turning a quarter turn about its center over 2 seconds
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.quarterTurn, anchor: .center, oldSize: size, animationTiming: .linear(duration: 2))

    // when: a second in, an update with a timing of no duration scales it instead
    timeline.move(to: 101)
    layer.updateTransform(Constants.doubleScale, anchor: .center, oldSize: size, animationTiming: .linear(duration: 0))

    // then: the layer shows the scale at once, and the turn's animation is gone
    expect(layer.animation(forKey: "transform")) == nil
    timeline.show(at: 101)
    try expectShownTransform(of: layer, Constants.doubleScale, about: .center, within: 1e-9)
  }

  func test_updateTransform_pointAtTheAnchorPoint_turnDuringATurn_stacksOnIt() throws {
    // given: a layer whose anchor point is at its center, turning a quarter turn about its center over a second, in one
    // animation
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.quarterTurn, anchor: .center, oldSize: size, animationTiming: .linear(duration: 1))
    expect(layer.animation(forKey: "transform") is AnchoredTransformBasicAnimation) == true

    // when: halfway, an animated update turns it to the half turn over a second
    timeline.move(to: 100.5)
    layer.updateTransform(Constants.halfTurn, anchor: .center, oldSize: size, animationTiming: .linear(duration: 1))

    // then: the first turn goes on along its course, followed by the second's way, until the second lands
    for time in [100.5, 100.75, 101, 101.5] {
      timeline.show(at: time)
      let shown = stacked([
        (CATransform3DIdentity, Constants.quarterTurn, min(time - 100, 1)),
        (Constants.quarterTurn, Constants.halfTurn, time - 100.5),
      ])
      try expectShownTransform(of: layer, shown, about: .center, within: 0.01, "at \(time)")
    }
  }

  func test_updateTransform_withoutATimingDuringABasicAnimation_glidesFromTheShownTransform() throws {
    // given: a layer whose anchor point is at its center, which a basic animation turns a quarter turn over 2 seconds
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.transform = Constants.quarterTurn
    let turn = CABasicAnimation(keyPath: "transform")
    turn.fromValue = NSValue(caTransform3D: CATransform3DIdentity)
    turn.toValue = NSValue(caTransform3D: Constants.quarterTurn)
    turn.beginTime = 100
    turn.duration = 2
    layer.add(turn, forKey: "transform")

    // when: a second in, an update without a timing scales it about its top left corner instead
    timeline.move(to: 101)
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, animationTiming: nil)

    // then: the layer shows the turn about its center at first, then glides to the scale about the corner over the
    // second the turn had left
    let shownTurn = interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: 0.5)
    timeline.show(at: 101)
    try expectShownTransform(of: layer, shownTurn, about: .center, within: 0.01)
    expect(try unwrap(layer.animation(forKey: "transform")).duration).to(beApproximatelyEqual(to: 1, within: 1e-9))
    timeline.show(at: 102)
    try expectShownTransform(of: layer, Constants.doubleScale, about: .topLeft, within: 0.01)
  }

  // MARK: - Without an Old Size

  func test_updateTransform_withoutAnOldSize_withoutAnAnchor_appliesAboutTheCenter() throws {
    // given: a layer whose anchor point is at its top left corner
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: .zero)
    let layer = timeline.layer

    // when: a quarter turn applies without an anchor
    layer.updateTransform(Constants.quarterTurn, animationTiming: nil)

    // then: the layer shows the turn about its center
    timeline.show(at: 100)
    try expectShownTransform(of: layer, Constants.quarterTurn, about: .center, within: 1e-9)
  }

  func test_updateTransform_withoutAnOldSize_resizeAtRest_appliesTheTransformAtTheNewSizeAtOnce() throws {
    // given: a layer of 40 x 20 turned a quarter turn about its top left corner, which remembers its size then
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, animationTiming: nil)

    // when: the layer grows to 80 x 40 at once, and an animated update keeps the transform
    layer.retargetFrame(to: CGRect(origin: .zero, size: Constants.largeSize))
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, animationTiming: .linear(duration: 1))

    // then: the turn applies about the corner at the new size at once, as only the size changed
    expect(layer.animation(forKey: "transform")) == nil
    timeline.show(at: 100)
    try expectShownTransform(of: layer, Constants.quarterTurn, about: .topLeft, within: 0.01)
  }

  func test_updateTransform_withoutAnOldSize_resizeDuringAChangeToATransformThatTheSizeDoesntMove_followsTheResize() throws {
    // given: a layer of 40 x 20 turning back from a quarter turn to no turn about its top left corner over 2 seconds,
    // whose transform at the end, the identity, the size doesn't move
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, animationTiming: nil)
    layer.updateTransform(CATransform3DIdentity, anchor: .topLeft, animationTiming: .linear(duration: 2))

    // when: a second in, an update without a timing makes it 80 x 40, keeping the transform
    timeline.move(to: 101)
    layer.retargetFrame(to: CGRect(origin: .zero, size: Constants.largeSize))
    layer.updateTransform(CATransform3DIdentity, anchor: .topLeft, animationTiming: nil)

    // then: the turn keeps its course about the corner at the new size
    for time in [101.0, 101.5] {
      timeline.show(at: time)
      try expectShownTransform(of: layer, interpolated(from: Constants.quarterTurn, to: CATransform3DIdentity, progress: (time - 100) / 2), about: .topLeft, within: 0.01)
    }
  }

  #if canImport(AppKit)
  func test_updateTransform_withoutAnOldSize_appKitViewInAWindow_keepsTheTransformThroughAppKitsResets() throws {
    // given: a layer-backed view of 40 x 20 in a window, turned a quarter turn about its top left corner
    let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 200, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
    let view = NSView(frame: CGRect(origin: .zero, size: Constants.smallSize))
    view.wantsLayer = true
    try unwrap(window.contentView).addSubview(view)
    let layer = try unwrap(view.layer)
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, animationTiming: nil)
    let turnAtTheOldSize = layer.transform

    // when: the run loop turns, committing the transaction, the first since the view joined the window, and the view
    // grows to 80 x 40
    RunLoop.main.run(until: Date())
    let transformAfterTheFirstCommit = layer.transform
    view.frame = CGRect(origin: .zero, size: Constants.largeSize)

    // then: AppKit's resets leave the turn about the corner at the old size
    expect(CATransform3DEqualToTransform(transformAfterTheFirstCommit, turnAtTheOldSize)) == true
    expect(CATransform3DEqualToTransform(layer.transform, turnAtTheOldSize)) == true

    // when: an update keeps the transform, and the view moves
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, animationTiming: nil)
    view.frame = CGRect(origin: CGPoint(x: 10, y: 10), size: Constants.largeSize)
    RunLoop.main.run(until: Date())

    // then: the turn applies about the corner at the new size, through AppKit's reset on the move
    try expectShownTransform(of: layer, Constants.quarterTurn, about: .topLeft, within: 0.01)

    // when: an update turns it back to no turn, and the view moves again
    layer.updateTransform(CATransform3DIdentity, anchor: .topLeft, animationTiming: nil)
    view.frame = CGRect(origin: CGPoint(x: 20, y: 20), size: Constants.largeSize)

    // then: the view's layer stays at no turn, as the update stopped keeping the turn
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }
  #endif

  // MARK: - Helpers

  /// The distance between where a layer shows a point of it and the point's place in the frame that it shows, which a
  /// transform about the point keeps.
  private func drift(of layer: CALayer, at point: UnitPoint) throws -> CGFloat {
    let presentation = try unwrap(layer.presentation())
    let bounds = presentation.bounds
    let shown = presentation.convert(
      CGPoint(x: bounds.minX + CGFloat(point.x) * bounds.width, y: bounds.minY + CGFloat(point.y) * bounds.height),
      to: presentation.superlayer
    )
    let place = CGPoint(
      x: presentation.position.x + (CGFloat(point.x) - presentation.anchorPoint.x) * bounds.width,
      y: presentation.position.y + (CGFloat(point.y) - presentation.anchorPoint.y) * bounds.height
    )
    return hypot(shown.x - place.x, shown.y - place.y)
  }

  /// The transform a progress of the way from one transform to another, as Core Animation interpolates them.
  private func interpolated(from: CATransform3D, to: CATransform3D, progress: Double) -> CATransform3D {
    AnimationInterpolation.transform(from: from, to: to, progress: progress) ?? to
  }

  /// The angle of the turn that a layer shows, in radians.
  private func shownAngle(of layer: CALayer) throws -> Double {
    let transform = try unwrap(layer.presentation()).transform
    return atan2(Double(transform.m12), Double(transform.m11))
  }

  /// The transform of changes stacked on one another, each a progress of the way from the transform that the one before
  /// it ends at: the first change's transform so far, followed by each later change's way so far, see `TransformChanges`.
  private func stacked(_ changes: [(from: CATransform3D, to: CATransform3D, progress: Double)]) -> CATransform3D {
    var transform = interpolated(from: changes[0].from, to: changes[0].to, progress: changes[0].progress)
    for change in changes.dropFirst() {
      let changeTransform = interpolated(from: change.from, to: change.to, progress: change.progress)
      transform = CATransform3DConcat(CATransform3DConcat(transform, CATransform3DInvert(change.from)), changeTransform)
    }
    return transform
  }

  private func expectTransform(_ transform: CATransform3D, _ expected: CATransform3D, file: StaticString = #filePath, line: UInt = #line) {
    expect(CATransform3DEqualToTransform(transform, expected), file: file, line: line) == true
  }

  // MARK: - Constants

  private enum Constants {

    /// An anchor point at a layer's center.
    static let center = CGPoint(x: 0.5, y: 0.5)

    /// The size that a layer grows from.
    static let smallSize = CGSize(width: 40, height: 20)

    /// The size that a layer grows to.
    static let largeSize = CGSize(width: 80, height: 40)

    /// A turn of 45°.
    static let eighthTurn = CATransform3DMakeRotation(.pi / 4, 0, 0, 1)

    /// A turn of 90°.
    static let quarterTurn = CATransform3DMakeRotation(.pi / 2, 0, 0, 1)

    /// A turn of 180°.
    static let halfTurn = CATransform3DMakeRotation(.pi, 0, 0, 1)

    /// A turn of 270°.
    static let threeQuarterTurn = CATransform3DMakeRotation(.pi * 1.5, 0, 0, 1)

    /// A scale to twice the size.
    static let doubleScale = CATransform3DMakeScale(2, 2, 1)

    /// A scale to three times the size.
    static let tripleScale = CATransform3DMakeScale(3, 3, 1)

    /// A perspective with the eye 500 points away.
    static let perspective: CATransform3D = {
      var perspective = CATransform3DIdentity
      perspective.m34 = -1 / 500
      return perspective
    }()

    /// A turn of 60° about the y axis, seen in perspective.
    static let perspectiveTurn = CATransform3DRotate(perspective, .pi / 3, 0, 1, 0)

    /// A scale of the depth to zero, which doesn't decompose.
    static let flat = CATransform3DMakeScale(1, 1, 0)
  }
}
