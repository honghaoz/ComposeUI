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
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: nil)
    var transformWrites = 0
    let observation = layer.observe(\.transform) { _, _ in
      transformWrites += 1
    }

    // when: updates keep the transform, without and with a timing
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: nil)
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: .linear(duration: 1))

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
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: nil)

    // then: the layer shows the turn about the corner at once, without an animation
    expect(layer.animationKeys()) == nil
    timeline.show(at: 100)
    try expectShownTransform(of: layer, Constants.quarterTurn, about: .topLeft, within: 1e-9)
  }

  func test_updateTransform_zeroDuration_appliesAtOnce() throws {
    // given: a layer at rest
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size

    // when: a quarter turn about its top left corner applies with a timing of no duration
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: .linear(duration: 0))

    // then: the layer shows the turn at once, without an animation
    expect(layer.animationKeys()) == nil
    timeline.show(at: 100)
    try expectShownTransform(of: layer, Constants.quarterTurn, about: .topLeft, within: 1e-9)
  }

  func test_updateTransform_transformsThatDontInterpolate_applyAtOnce() throws {
    // given: a layer at rest
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size

    // when: a transform that flattens the depth, which doesn't decompose, applies about the top left corner with a timing
    layer.updateTransform(Constants.flat, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: .linear(duration: 1))

    // then: the layer has the transform about the corner at once, without an animation
    expect(layer.animationKeys()) == nil
    expectTransform(layer.transform, CALayer.anchoredTransform(Constants.flat, pivotOffset: SIMD2(-0.5, -0.5), size: size))
  }

  func test_updateTransform_sizeChangedWithoutASizeAnimation_appliesAtOnce() throws {
    // given: a layer turned about its top left corner, resized without an animation
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 40, height: 20), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, newSize: Constants.smallSize, animationTiming: nil)
    layer.retargetFrame(to: CGRect(origin: .zero, size: Constants.largeSize))

    // when: an animated update follows the size
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, newSize: Constants.largeSize, animationTiming: .linear(duration: 1))

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
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: .linear(duration: 1))

    // when: once the turn ended, an update without a timing scales it instead
    timeline.show(at: 102)
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: nil)

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
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: .linear(duration: 1))

    // then: the layer shows the turn so far about the corner, on the keyframes and between them, and the turn once it ends
    for time in [0.25, 0.5, 0.508, 0.75, 1.5] {
      timeline.show(at: 100 + time)
      try expectShownTransform(of: layer, interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: min(time, 1)), about: .topLeft, within: 0.01)
    }

    // then: the keyframes come at 60 per second
    let animation = try unwrap(layer.animation(forKey: "transform") as? AnchoredTransformAnimation)
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
    layer.updateTransform(Constants.perspectiveTurn, anchor: .center, oldSize: size, newSize: size, animationTiming: .linear(duration: 1))

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
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: Constants.smallSize, newSize: Constants.largeSize, animationTiming: .linear(duration: 1))

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
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.largeSize, newSize: Constants.largeSize, animationTiming: .linear(duration: 1))

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
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, newSize: Constants.smallSize, animationTiming: nil)
    layer.animateFrame(to: CGRect(origin: .zero, size: Constants.largeSize), timing: .linear(duration: 2))
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, newSize: Constants.largeSize, animationTiming: .linear(duration: 2))

    // when: a second in, another animated update grows it to 120 x 60 over a second, which stacks on the first resize
    timeline.move(to: 101)
    let largerSize = CGSize(width: 120, height: 60)
    layer.animateFrame(to: CGRect(origin: .zero, size: largerSize), timing: .linear(duration: 1))
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.largeSize, newSize: largerSize, animationTiming: .linear(duration: 1))

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
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, newSize: Constants.smallSize, animationTiming: nil)
    layer.retargetFrame(to: CGRect(origin: .zero, size: Constants.largeSize))
    let resize = CABasicAnimation(keyPath: "bounds.size")
    resize.fromValue = CGSize(width: -40, height: -20)
    resize.toValue = CGSize.zero
    resize.isAdditive = true
    resize.beginTime = 100
    resize.duration = 1
    layer.add(resize, forKey: "resize")

    // when: the transform follows the new size
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, newSize: Constants.largeSize, animationTiming: nil)

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
    layer.updateTransform(Constants.perspectiveTurn, anchor: .center, oldSize: size, newSize: size, animationTiming: nil)

    // when: an animated update grows it to 200 x 100 over a second
    layer.animateFrame(to: CGRect(origin: .zero, size: largeSize), timing: .linear(duration: 1))
    layer.updateTransform(Constants.perspectiveTurn, anchor: .center, oldSize: size, newSize: largeSize, animationTiming: .linear(duration: 1))

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
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: .linear(duration: 1, delay: 0.5))

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
    layer.updateTransform(Constants.eighthTurn, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: timing)

    // then: on each keyframe, the layer shows the turn that the spring gives, past the eighth turn while it overshoots
    let curve = AnimationCurve(CABasicAnimation.makeAnimation(timing))
    let animation = try unwrap(layer.animation(forKey: "transform") as? AnchoredTransformAnimation)
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
    let cases: [(name: String, frame: CGRect, anchorPoint: CGPoint, anchor: UnitPoint, change: (CALayer) -> Void)] = [
      ("fast turn", CGRect(x: 0, y: 0, width: 400, height: 400), .zero, .center, { layer in
        let size = layer.bounds.size
        layer.updateTransform(Constants.halfTurn, anchor: .center, oldSize: size, newSize: size, animationTiming: .easeInEaseOut(duration: 0.3))
      }),
      ("perspective flip", CGRect(x: 0, y: 0, width: 800, height: 400), Constants.center, .left, { layer in
        let size = layer.bounds.size
        layer.updateTransform(flip, anchor: .left, oldSize: size, newSize: size, animationTiming: .easeInEaseOut(duration: 0.25))
      }),
      ("perspective flip back to flat", CGRect(x: 0, y: 0, width: 800, height: 400), Constants.center, .left, { layer in
        let size = layer.bounds.size
        layer.updateTransform(flip, anchor: .left, oldSize: size, newSize: size, animationTiming: nil)
        layer.updateTransform(CATransform3DIdentity, anchor: .left, oldSize: size, newSize: size, animationTiming: .easeInEaseOut(duration: 0.25))
      }),
      ("perspective turn during a resize", CGRect(x: 0, y: 0, width: 100, height: 50), .zero, .center, { layer in
        let size = layer.bounds.size
        let largeSize = CGSize(width: 600, height: 300)
        layer.updateTransform(Constants.perspectiveTurn, anchor: .center, oldSize: size, newSize: size, animationTiming: nil)
        layer.animateFrame(to: CGRect(origin: .zero, size: largeSize), timing: .easeInEaseOut(duration: 0.3))
        layer.updateTransform(Constants.perspectiveTurn, anchor: .center, oldSize: size, newSize: largeSize, animationTiming: .easeInEaseOut(duration: 0.3))
      }),
      ("scale during a resize", CGRect(x: 0, y: 0, width: 100, height: 100), .zero, .center, { layer in
        let size = layer.bounds.size
        let largeSize = CGSize(width: 1000, height: 1000)
        layer.animateFrame(to: CGRect(origin: .zero, size: largeSize), timing: .linear(duration: 0.25))
        layer.updateTransform(CATransform3DMakeScale(4, 4, 1), anchor: .center, oldSize: size, newSize: largeSize, animationTiming: .linear(duration: 0.25))
      }),
    ]

    for testCase in cases {
      // when: the change animates
      let timeline = PausedTimeline(frame: testCase.frame, anchorPoint: testCase.anchorPoint)
      testCase.change(timeline.layer)

      // then: halfway between each two keyframes, where the interpolation moves the point the most, the layer shows the
      // point within a quarter point of its place, give or take the hundredth that Core Animation adds to a large resize
      // by solving the frame animation's timing in single precision
      let animation = try unwrap(timeline.layer.animation(forKey: "transform") as? AnchoredTransformAnimation, testCase.name)
      let intervals = try unwrap(animation.values?.count, testCase.name) - 1
      for index in 0 ..< intervals {
        timeline.show(at: animation.beginTime + animation.duration * (Double(index) + 0.5) / Double(intervals))
        expect(try drift(of: timeline.layer, at: testCase.anchor), "\(testCase.name) at \(index)") <= 0.27
      }
    }
  }

  func test_updateTransform_springWithoutDamping_followsTenSeconds() throws {
    // given: a layer at rest
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size

    // when: a scale about its top left corner animates with a spring without damping, which never finishes
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: .spring(dampingRatio: 0, response: 0.5))

    // then: the keyframes follow the spring for 10 seconds at 60 per second
    let animation = try unwrap(layer.animation(forKey: "transform") as? AnchoredTransformAnimation)
    expect(animation.duration) == 10
    expect(animation.values?.count) == 601
  }

  // MARK: - Changes in Flight

  func test_updateTransform_withATimingDuringAChange_startsFromTheShownTransform() throws {
    // given: a layer turning a quarter turn about its top left corner over 10 seconds
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: .linear(duration: 10))

    // when: 2 seconds in, an animated update scales it instead over a second
    timeline.move(to: 102)
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: .linear(duration: 1))

    // then: the scale starts from the turn shown, without a jump, and lands a second later
    let start = interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: 0.2)
    for time in [0, 0.5, 1] {
      timeline.show(at: 102 + time)
      try expectShownTransform(of: layer, interpolated(from: start, to: Constants.doubleScale, progress: time), about: .topLeft, within: 0.01)
    }
  }

  func test_updateTransform_withoutATimingDuringAChange_glidesToTheNewTransform() throws {
    // given: a layer turning a quarter turn about its top left corner over 10 seconds
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: .linear(duration: 10))

    // when: 2 seconds in, an update without a timing scales it instead
    timeline.move(to: 102)
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: nil)

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
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: .spring(dampingRatio: 0, response: 0.5))

    // when: a second in, an update without a timing scales it more
    timeline.move(to: 101)
    layer.updateTransform(Constants.tripleScale, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: nil)

    // then: the glide lands after the default duration, as a change that never finishes has no landing to glide to
    let animation = try unwrap(layer.animation(forKey: "transform") as? AnchoredTransformAnimation)
    expect(animation.duration).to(beApproximatelyEqual(to: Animations.defaultAnimationDuration, within: 1e-9))
    timeline.show(at: 101 + Animations.defaultAnimationDuration)
    try expectShownTransform(of: layer, Constants.tripleScale, about: .topLeft, within: 0.01)
  }

  func test_updateTransform_resizeDuringAChange_keepsTheCourse() throws {
    // given: a layer of 40 x 20 turning a quarter turn about its top left corner over 4 seconds
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, newSize: Constants.smallSize, animationTiming: .linear(duration: 4))

    // when: a second in, an animated update grows it to 80 x 40 over a second, keeping the transform
    timeline.move(to: 101)
    layer.animateFrame(to: CGRect(origin: .zero, size: Constants.largeSize), timing: .linear(duration: 1))
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, newSize: Constants.largeSize, animationTiming: .linear(duration: 1))

    // then: the turn keeps its course over its 4 seconds, about the corner at the size the layer shows
    for time in [101, 101.5, 102, 103, 105] {
      timeline.show(at: time)
      let progress = min((time - 100) / 4, 1)
      try expectShownTransform(of: layer, interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: progress), about: .topLeft, within: 0.01)
    }
  }

  func test_updateTransform_resizeWithoutATimingDuringAChange_keepsTheCourse() throws {
    // given: a layer of 40 x 20 turning a quarter turn about its top left corner over 4 seconds
    let timeline = PausedTimeline(frame: CGRect(origin: .zero, size: Constants.smallSize), anchorPoint: Constants.center)
    let layer = timeline.layer
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, newSize: Constants.smallSize, animationTiming: .linear(duration: 4))

    // when: a second in, an update without a timing makes it 80 x 40, keeping the transform
    timeline.move(to: 101)
    layer.retargetFrame(to: CGRect(origin: .zero, size: Constants.largeSize))
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, newSize: Constants.largeSize, animationTiming: nil)

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
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, newSize: Constants.smallSize, animationTiming: nil)
    layer.animateFrame(to: CGRect(origin: .zero, size: Constants.largeSize), timing: .linear(duration: 1))

    // when: the update turns it an eighth turn without a timing
    layer.updateTransform(Constants.eighthTurn, anchor: .topLeft, oldSize: Constants.smallSize, newSize: Constants.largeSize, animationTiming: nil)

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
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, newSize: Constants.largeSize, animationTiming: .linear(duration: 1))

    // when: 2 seconds in, after the turn ended, an update without a timing turns it an eighth turn instead
    timeline.move(to: 102)
    layer.updateTransform(Constants.eighthTurn, anchor: .topLeft, oldSize: Constants.largeSize, newSize: Constants.largeSize, animationTiming: nil)

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
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.smallSize, newSize: Constants.largeSize, animationTiming: .linear(duration: 1))

    // when: 2 seconds in, after the turn ended, an animated update turns it an eighth turn instead over a second
    timeline.move(to: 102)
    layer.updateTransform(Constants.eighthTurn, anchor: .topLeft, oldSize: Constants.largeSize, newSize: Constants.largeSize, animationTiming: .linear(duration: 1))

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
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: .linear(duration: 10))
    timeline.show(at: 102)
    let shownTransform = interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: 0.2)
    try expectShownTransform(of: layer, shownTransform, about: .topLeft, within: 0.01)

    // when: an animated update turns it about its bottom right corner instead, over a second
    layer.updateTransform(Constants.quarterTurn, anchor: .bottomRight, oldSize: size, newSize: size, animationTiming: .linear(duration: 1))

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
    layer.updateTransform(Constants.quarterTurn, anchor: .center, oldSize: Constants.smallSize, newSize: Constants.smallSize, animationTiming: nil)
    layer.animateFrame(to: CGRect(origin: .zero, size: Constants.largeSize), timing: .linear(duration: 1))
    timeline.show(at: 100.5)
    try expectShownTransform(of: layer, Constants.quarterTurn, about: .center, within: 0.01)

    // when: an animated update turns it about its top left corner instead, over a second
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: Constants.largeSize, newSize: Constants.largeSize, animationTiming: .linear(duration: 1))

    // then: the layer shows the same at first, at the size it shows rather than the size it grows to, then lands at the
    // turn about the corner
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
    layer.updateTransform(Constants.quarterTurn, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: nil)
    let modelTransform = layer.transform
    for keyPath in ["transform", "bounds.size"] {
      let animation = CAKeyframeAnimation(keyPath: keyPath)
      animation.values = [layer.value(forKeyPath: keyPath) as Any, layer.value(forKeyPath: keyPath) as Any]
      animation.beginTime = layer.currentTime
      animation.duration = 10
      layer.add(animation, forKey: "keyframes \(keyPath)")
    }

    // when: an animated update scales it instead
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: .linear(duration: 1))

    // then: the change starts from the model transform, at the layer's size, as nothing tells what the layer shows
    let animation = try unwrap(layer.animation(forKey: "transform") as? AnchoredTransformAnimation)
    let values = try unwrap(animation.values as? [NSValue])
    try expectTransform(unwrap(values.first).caTransform3DValue, modelTransform)
    try expectTransform(unwrap(values.last).caTransform3DValue, layer.transform)

    // when: an animated update turns it about its bottom right corner instead, during the change
    let keyframeTransform = values[0].caTransform3DValue
    layer.updateTransform(Constants.doubleScale, anchor: .bottomRight, oldSize: size, newSize: size, animationTiming: .linear(duration: 1))

    // then: the change starts from the transform that the scale shows, about the new corner at the layer's size
    let newValues = try unwrap((layer.animation(forKey: "transform") as? AnchoredTransformAnimation)?.values as? [NSValue])
    let firstTransform = try unwrap(newValues.first).caTransform3DValue
    for (value, expected) in zip(
      [firstTransform.m11, firstTransform.m12, firstTransform.m21, firstTransform.m22, firstTransform.m41, firstTransform.m42],
      [keyframeTransform.m11, keyframeTransform.m12, keyframeTransform.m21, keyframeTransform.m22, keyframeTransform.m41, keyframeTransform.m42]
    ) {
      expect(value).to(beApproximatelyEqual(to: expected, within: 1e-9))
    }
  }

  // MARK: - Point at the Anchor Point

  func test_updateTransform_pointAtTheAnchorPoint_animatesTheTransformItself() throws {
    // given: a layer whose anchor point is at its center
    let timeline = PausedTimeline(frame: CGRect(x: 0, y: 0, width: 100, height: 50), anchorPoint: Constants.center)
    let layer = timeline.layer
    let size = layer.bounds.size

    // when: a quarter turn about its center animates over 2 seconds
    layer.updateTransform(Constants.quarterTurn, anchor: .center, oldSize: size, newSize: size, animationTiming: .linear(duration: 2))

    // then: the turn is a basic animation of the transform, which the size doesn't change, and the layer shows it
    let animation = try unwrap(layer.animation(forKey: "transform") as? CABasicAnimation)
    expect(animation.duration) == 2
    timeline.show(at: 101)
    try expectShownTransform(of: layer, interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: 0.5), about: .center, within: 0.01)

    // when: a second in, an update without a timing scales it instead
    layer.updateTransform(Constants.doubleScale, anchor: .center, oldSize: size, newSize: size, animationTiming: nil)

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
    layer.updateTransform(Constants.doubleScale, anchor: .center, oldSize: size, newSize: size, animationTiming: .spring(dampingRatio: 0, response: 0.5))

    // when: a second in, an update without a timing scales it more
    timeline.move(to: 101)
    layer.updateTransform(Constants.tripleScale, anchor: .center, oldSize: size, newSize: size, animationTiming: nil)

    // then: the glide takes the default duration, as a change that never finishes has no landing to glide to
    let glide = try unwrap(layer.animation(forKey: "transform") as? CABasicAnimation)
    expect(glide.duration) == Animations.defaultAnimationDuration
    expect(glide.timingFunction) == CAMediaTimingFunction(name: .easeOut)
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
    layer.updateTransform(Constants.doubleScale, anchor: .topLeft, oldSize: size, newSize: size, animationTiming: nil)

    // then: the layer shows the turn about its center at first, then glides to the scale about the corner over the
    // second the turn had left
    let shownTurn = interpolated(from: CATransform3DIdentity, to: Constants.quarterTurn, progress: 0.5)
    timeline.show(at: 101)
    try expectShownTransform(of: layer, shownTurn, about: .center, within: 0.01)
    expect(try unwrap(layer.animation(forKey: "transform")).duration).to(beApproximatelyEqual(to: 1, within: 1e-9))
    timeline.show(at: 102)
    try expectShownTransform(of: layer, Constants.doubleScale, about: .topLeft, within: 0.01)
  }

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
