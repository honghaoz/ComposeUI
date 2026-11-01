//
//  KeyboardScrollPhysicsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/1/26.
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

#if canImport(AppKit)
import CoreGraphics

import ChouTiTest

@testable import ComposeUI

class KeyboardScrollPhysicsTests: XCTestCase {

  // MARK: - Push

  func test_push_speedsUpToTheTopSpeed() {
    // given: content at rest, which a key pushes down with a line's step of 40 points
    var physics = KeyboardScrollPhysics(position: .zero, time: 0)
    physics.startPush(toward: .down, step: 40)

    // when: the key stays down for 0.1 s
    physics.advance(to: 0.1, in: Self.range)

    // then: the content speeds up at 5000 points per second², which reaches the top speed of 25 steps per second in a
    // fifth of a second, over 100 steps of a millisecond
    expect(physics.velocity.y).to(beApproximatelyEqual(to: 500, within: 1e-9))
    expect(physics.position.y).to(beApproximatelyEqual(to: 5000 * 0.001 * 0.001 * 100 * 101 / 2, within: 1e-9))
    expect(physics.velocity.x) == 0
    expect(physics.position.x) == 0

    // when: the key stays down until 0.5 s
    physics.advance(to: 0.5, in: Self.range)

    // then: the content keeps the top speed from 0.2 s, one step's speed past it at most
    expect(physics.velocity.y) >= 1000
    expect(physics.velocity.y) <= 1005
    expect(physics.position.y).to(beApproximatelyEqual(to: 100 + 1000 * 0.3, within: 3))
  }

  func test_push_againstTheMotion_slowsTheContentDownFirst() {
    // given: content that moves up at 10000 points per second, much faster than a line's top speed, after a page key
    // that pushed it up for a fifth of a second
    var physics = KeyboardScrollPhysics(position: CGPoint(x: 0, y: 5000), time: 0)
    physics.startPush(toward: .up, step: 400)
    physics.advance(to: 0.2, in: Self.range)
    physics.endPush(in: Self.range)
    expect(physics.velocity.y) < -1000

    // when: a key pushes the content down for 0.1 s
    let speed = physics.velocity.y
    physics.startPush(toward: .down, step: 40)
    physics.advance(to: 0.3, in: Self.range)

    // then: the push slows the content down by its force, 500 points per second in 0.1 s, since it moves the other way
    expect(physics.velocity.y).to(beApproximatelyEqual(to: speed + 500, within: 1e-6))
  }

  func test_push_eachDirection_movesTheContentAlongIt() {
    // given: content in the middle of a range that scrolls both ways
    let directions: [(KeyboardScrollDirection, CGPoint)] = [
      (.up, CGPoint(x: 0, y: -1)),
      (.down, CGPoint(x: 0, y: 1)),
      (.left, CGPoint(x: -1, y: 0)),
      (.right, CGPoint(x: 1, y: 0)),
    ]
    let range = KeyboardScrollRange(minimum: .zero, maximum: CGPoint(x: 10000, y: 10000), pixelSize: CGSize(width: 0.5, height: 0.5))
    let start = CGPoint(x: 5000, y: 5000)
    for (direction, unitVector) in directions {
      var physics = KeyboardScrollPhysics(position: start, time: 0)

      // when: a key pushes the content toward the direction for 0.1 s, and goes up
      physics.startPush(toward: direction, step: 40)
      physics.advance(to: 0.1, in: range)
      physics.endPush(in: range)

      // then: the content comes to rest along the direction, where the spring takes its speed of 500 points per second,
      // 500/√175 points further
      let travel = 5000 * 0.001 * 0.001 * 100 * 101 / 2 + 500 / CGFloat(175).squareRoot()
      let expected = CGPoint(x: start.x + unitVector.x * travel, y: start.y + unitVector.y * travel).rounded(toPixelSize: range.pixelSize)
      expect(direction.unitVector) == unitVector
      expect(direction.isVertical) == (unitVector.x == 0)
      expect(physics.restingOffset(in: range)) == expected
      settle(&physics, in: range)
      expect(physics.isAtRest(in: range)) == true
    }
  }

  func test_push_holdsTheContentAcrossItsDirection() {
    // given: content stretched 8 points past the left end, which a key pushes down
    var physics = KeyboardScrollPhysics(position: CGPoint(x: -8, y: 0), time: 0)
    physics.startPush(toward: .down, step: 40)

    // when: the key stays down for a second
    physics.advance(to: 1, in: Self.range)

    // then: the spring brings the content back to the left end while the push moves it down
    expect(physics.position.x).to(beApproximatelyEqual(to: 0, within: 0.01))
    expect(physics.position.y) > 500
  }

  func test_push_duringTheSpringOfATapOnTheOtherAxis_movesTheContentOnToTheTapsStep() {
    for gap in [0.02, 0.1, 0.2] {
      // given: a tap of a key that pushes the content to the right, whose spring takes it a step to the right
      var physics = KeyboardScrollPhysics(position: .zero, time: 0)
      physics.startPush(toward: .right, step: 40)
      physics.endPush(in: Self.planeRange)
      physics.advance(to: gap, in: Self.planeRange)
      expect(physics.position.x) < 39

      // when: before the content rests, a key pushes it down for 0.3 s
      physics.startPush(toward: .down, step: 40)
      physics.advance(to: gap + 0.3, in: Self.planeRange)

      // then: the spring moves the content on to the tap's step while the key pushes it down
      expect(physics.position.x).to(beApproximatelyEqual(to: 40, within: 0.5))
      expect(physics.position.y) > 100

      // when: the key goes up
      physics.endPush(in: Self.planeRange)
      settle(&physics, in: Self.planeRange)

      // then: the content comes to rest down, and a whole step to the right
      expect(physics.isAtRest(in: Self.planeRange)) == true
      expect(physics.restingOffset(in: Self.planeRange).x) == 40
      expect(physics.restingOffset(in: Self.planeRange).y) > 200
    }
  }

  // MARK: - End of a Push

  func test_endPush_afterATap_bringsTheContentAStepAway() {
    // given: content that a key pushed down for 10 ms, at 50 points per second
    var physics = KeyboardScrollPhysics(position: .zero, time: 0)
    physics.startPush(toward: .down, step: 40)
    physics.advance(to: 0.01, in: Self.range)

    // when: the key goes up, and the motion goes on until the content rests
    physics.endPush(in: Self.range)
    let positions = settle(&physics, in: Self.range)

    // then: the content comes to rest a whole step from where the push started, since its speed carries it under 4
    // points, without swinging past the step
    expect(physics.restingOffset(in: Self.range)) == CGPoint(x: 0, y: 40)
    expect(physics.isAtRest(in: Self.range)) == true
    expect(positions.map(\.y).max()) <= 40.5
  }

  func test_endPush_atSpeed_bringsTheContentWhereTheSpringTakesItsSpeed() {
    // given: content that a key pushed down for 0.1 s, at 500 points per second
    var physics = KeyboardScrollPhysics(position: .zero, time: 0)
    physics.startPush(toward: .down, step: 40)
    physics.advance(to: 0.1, in: Self.range)
    let position = physics.position.y

    // when: the key goes up, and the motion goes on until the content rests
    physics.endPush(in: Self.range)
    let positions = settle(&physics, in: Self.range)

    // then: the content comes to rest where the spring takes its kinetic energy, 1/2 m v² = 1/2 k x², on whole pixels,
    // further than a step, without swinging past it
    let restingY = ((position + 500 / CGFloat(175).squareRoot()) / 0.5).rounded() * 0.5
    expect(restingY) > 40
    expect(physics.restingOffset(in: Self.range)) == CGPoint(x: 0, y: restingY)
    expect(positions.map(\.y).max()) <= restingY + 0.5
  }

  func test_endPush_duringTheSpringOfATapOnTheOtherAxis_leavesTheTapItsStep() {
    for gap in [0.02, 0.1, 0.2] {
      // given: a tap of a key that pushes the content to the right, whose spring takes it a step to the right, and before
      // the content rests, a key that pushes it down for 20 ms
      var physics = KeyboardScrollPhysics(position: .zero, time: 0)
      physics.startPush(toward: .right, step: 40)
      physics.endPush(in: Self.planeRange)
      physics.advance(to: gap, in: Self.planeRange)
      physics.startPush(toward: .down, step: 40)
      physics.advance(to: gap + 0.02, in: Self.planeRange)
      expect(physics.position.x) < 39
      expect(physics.velocity.x) > 10

      // when: the key goes up while the content still moves to the right, and the motion goes on until the content rests
      physics.endPush(in: Self.planeRange)
      settle(&physics, in: Self.planeRange)

      // then: the content comes to rest a whole step to the right, as well as a step down
      expect(physics.isAtRest(in: Self.planeRange)) == true
      expect(physics.restingOffset(in: Self.planeRange)) == CGPoint(x: 40, y: 40)
      expect(physics.position.x).to(beApproximatelyEqual(to: 40, within: 1))
    }
  }

  func test_endPush_withoutAPush_leavesTheMotion() {
    // given: content at rest that no key pushes
    var physics = KeyboardScrollPhysics(position: CGPoint(x: 0, y: 30), time: 0)

    // when: a push ends
    physics.endPush(in: Self.range)

    // then: the content stays at rest where it is
    expect(physics.isAtRest(in: Self.range)) == true
    expect(physics.restingOffset(in: Self.range)) == CGPoint(x: 0, y: 30)
  }

  // MARK: - Rubber Band

  func test_push_atTheEnd_stretchesPastItAndSpringsBack() {
    // given: content at the bottom end of a range that ends at 100, which a key pushes down
    let range = KeyboardScrollRange(minimum: .zero, maximum: CGPoint(x: 0, y: 100), pixelSize: CGSize(width: 0.5, height: 0.5))
    var physics = KeyboardScrollPhysics(position: CGPoint(x: 0, y: 100), time: 0)
    physics.startPush(toward: .down, step: 40)

    // when: the key stays down for a second
    physics.advance(to: 1, in: range)

    // then: the content stretches past the end until the spring balances the stretching force, 3000/175 points past it
    expect(physics.position.y).to(beApproximatelyEqual(to: 100 + 3000 / 175, within: 0.01))
    expect(physics.isAtRest(in: range)) == false

    // when: the key goes up, and the motion goes on until the content rests
    physics.endPush(in: range)
    let positions = settle(&physics, in: range)

    // then: the spring brings the content back to the end, without swinging past it into the range
    expect(physics.restingOffset(in: range)) == CGPoint(x: 0, y: 100)
    expect(physics.isAtRest(in: range)) == true
    expect(positions.map(\.y).min()) >= 99.5
  }

  func test_push_intoTheEnd_stretchesFurtherFromItsSpeed() {
    // given: content 100 points before the end of the range, which a key pushes down
    let range = KeyboardScrollRange(minimum: .zero, maximum: CGPoint(x: 0, y: 100), pixelSize: CGSize(width: 0.5, height: 0.5))
    var physics = KeyboardScrollPhysics(position: .zero, time: 0)
    physics.startPush(toward: .down, step: 40)

    // when: the key stays down for a second, in frames
    var positions: [CGPoint] = []
    var time: CFTimeInterval = 0
    while time < 1 {
      time += 1.0 / 120
      physics.advance(to: time, in: range)
      positions.append(physics.position)
    }

    // then: the content reaches the end near the top speed, which stretches it further than the push alone, and settles
    // where the spring balances the push
    let maximumY = positions.map(\.y).max() ?? 0
    expect(maximumY) > 100 + 3000 / 175 + 5
    expect(maximumY) < 160
    expect(physics.position.y).to(beApproximatelyEqual(to: 100 + 3000 / 175, within: 0.5))
  }

  // MARK: - Advance

  func test_advance_inFrames_movesTheContentAsInOneCall() {
    // given: two motions of content that a key pushes down
    var physicsInFrames = KeyboardScrollPhysics(position: .zero, time: 0)
    physicsInFrames.startPush(toward: .down, step: 40)
    var physicsInOneCall = physicsInFrames

    // when: one advances in frames of 1/120 s, and the other in one call, to 0.3 s
    var frameTime: CFTimeInterval = 0
    while frameTime < 0.3 {
      frameTime = min(0.3, frameTime + 1.0 / 120)
      physicsInFrames.advance(to: frameTime, in: Self.range)
    }
    physicsInOneCall.advance(to: 0.3, in: Self.range)

    // then: both move the content the same, since the motion advances in steps of a millisecond
    expect(physicsInFrames.position) == physicsInOneCall.position
    expect(physicsInFrames.velocity) == physicsInOneCall.velocity
    expect(physicsInFrames.time).to(beApproximatelyEqual(to: physicsInOneCall.time, within: 1e-9))
  }

  func test_positionAtATime_betweenSteps_movesOnByTheVelocity() {
    // given: content that a key pushed down for 0.1 s, at 500 points per second
    var physics = KeyboardScrollPhysics(position: .zero, time: 0)
    physics.startPush(toward: .down, step: 40)
    physics.advance(to: 0.1, in: Self.range)

    // then: the content moves on by its velocity between the motion's steps, and stays where it is before them
    expect(physics.position(at: 0.1004).y).to(beApproximatelyEqual(to: physics.position.y + 500 * 0.0004, within: 1e-6))
    expect(physics.position(at: 0.09)) == physics.position
  }

  func test_advance_byMoreThanASecond_advancesByASecond() {
    // given: content that a key pushes down
    var physics = KeyboardScrollPhysics(position: .zero, time: 0)
    physics.startPush(toward: .down, step: 40)
    var physicsForASecond = physics

    // when: the motion advances by 10 seconds at once, as a frame after a long gap does
    physics.advance(to: 10, in: Self.range)
    physicsForASecond.advance(to: 1, in: Self.range)

    // then: the content moves as it does in a second, and the motion's time is the frame's
    expect(physics.position) == physicsForASecond.position
    expect(physics.time).to(beApproximatelyEqual(to: 10, within: 1e-9))
  }

  func test_advance_toAnEarlierTime_leavesTheMotion() {
    // given: content that a key pushed down for 0.1 s
    var physics = KeyboardScrollPhysics(position: .zero, time: 0)
    physics.startPush(toward: .down, step: 40)
    physics.advance(to: 0.1, in: Self.range)
    let position = physics.position

    // when: the motion advances to an earlier time
    physics.advance(to: 0.05, in: Self.range)

    // then: the motion stays as it is
    expect(physics.position) == position
    expect(physics.time).to(beApproximatelyEqual(to: 0.1, within: 1e-9))
  }

  // MARK: - Range

  func test_range_withAMaximumBelowTheMinimum_isTheMinimumAlongThatAxis() {
    // given: a range whose maximum is below its minimum along the y axis, as for content smaller than the view
    let range = KeyboardScrollRange(minimum: CGPoint(x: 0, y: -20), maximum: CGPoint(x: 100, y: -50), pixelSize: CGSize(width: 1, height: 1))

    // then: the range is the minimum alone along that axis
    expect(range.maximum) == CGPoint(x: 100, y: -20)
    expect(range.constrained(CGPoint(x: 150, y: 30))) == CGPoint(x: 100, y: -20)
    expect(range.constrained(CGPoint(x: -10, y: -70))) == CGPoint(x: 0, y: -20)
  }

  func test_range_restingOffset_atAnEndBetweenPixels_restsOnTheNearestPixel() {
    // given: ranges that end a quarter of a pixel past a whole pixel, and a quarter of a pixel before one, at 2x
    let range = KeyboardScrollRange(minimum: .zero, maximum: CGPoint(x: 0, y: 100.125), pixelSize: CGSize(width: 0.5, height: 0.5))
    let otherRange = KeyboardScrollRange(minimum: .zero, maximum: CGPoint(x: 0, y: 100.375), pixelSize: CGSize(width: 0.5, height: 0.5))

    // then: an offset past the end rests on the pixel nearest to the end, which can be just past it, and an offset
    // inside the range on its nearest pixel
    expect(range.restingOffset(for: CGPoint(x: 0, y: 130))) == CGPoint(x: 0, y: 100)
    expect(otherRange.restingOffset(for: CGPoint(x: 0, y: 130))) == CGPoint(x: 0, y: 100.5)
    expect(range.restingOffset(for: CGPoint(x: 0, y: 40.3))) == CGPoint(x: 0, y: 40.5)
  }

  // MARK: - Helpers

  /// A range that scrolls down from 0 to 10000, at 2x.
  private static let range = KeyboardScrollRange(minimum: .zero, maximum: CGPoint(x: 0, y: 10000), pixelSize: CGSize(width: 0.5, height: 0.5))

  /// A range that scrolls both ways from 0 to 10000, at 2x.
  private static let planeRange = KeyboardScrollRange(minimum: .zero, maximum: CGPoint(x: 10000, y: 10000), pixelSize: CGSize(width: 0.5, height: 0.5))

  /// Advances a motion in frames of 1/120 s until the content rests, for up to two seconds.
  ///
  /// - Parameters:
  ///   - physics: The motion.
  ///   - range: The scrollable range.
  /// - Returns: The content offset of each frame.
  @discardableResult
  private func settle(_ physics: inout KeyboardScrollPhysics, in range: KeyboardScrollRange) -> [CGPoint] {
    var positions: [CGPoint] = []
    let endTime = physics.time + 2
    var time = physics.time
    while !physics.isAtRest(in: range), time < endTime {
      time += 1.0 / 120
      physics.advance(to: time, in: range)
      positions.append(physics.position)
    }
    return positions
  }
}
#endif
