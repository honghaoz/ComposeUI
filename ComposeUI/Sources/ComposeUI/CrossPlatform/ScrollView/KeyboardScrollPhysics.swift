//
//  KeyboardScrollPhysics.swift
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

/// A direction that a key scrolls the content toward.
enum KeyboardScrollDirection {

  case up
  case down
  case left
  case right

  /// The unit vector of the direction, in content coordinates, where the y axis points down.
  var unitVector: CGPoint {
    switch self {
    case .up:
      return CGPoint(x: 0, y: -1)
    case .down:
      return CGPoint(x: 0, y: 1)
    case .left:
      return CGPoint(x: -1, y: 0)
    case .right:
      return CGPoint(x: 1, y: 0)
    }
  }

  /// Whether the direction is along the vertical axis.
  var isVertical: Bool {
    switch self {
    case .up,
         .down:
      return true
    case .left,
         .right:
      return false
    }
  }
}

/// The scrollable range of a scroll view's content offset, which a keyboard scroll moves the content in.
struct KeyboardScrollRange {

  /// The smallest content offset along each axis.
  let minimum: CGPoint

  /// The largest content offset along each axis, which is at least `minimum`.
  let maximum: CGPoint

  /// The size of a pixel in content coordinates.
  let pixelSize: CGSize

  /// Makes a range.
  ///
  /// - Parameters:
  ///   - minimum: The smallest content offset along each axis.
  ///   - maximum: The largest content offset along each axis. Along an axis where it's below `minimum`, as when the
  ///     content is smaller than the visible size, the range is `minimum` alone.
  ///   - pixelSize: The size of a pixel in content coordinates.
  init(minimum: CGPoint, maximum: CGPoint, pixelSize: CGSize) {
    self.minimum = minimum
    self.maximum = CGPoint(x: max(minimum.x, maximum.x), y: max(minimum.y, maximum.y))
    self.pixelSize = pixelSize
  }

  /// Returns the offset in the range that's nearest to an offset.
  ///
  /// - Parameter offset: The offset.
  /// - Returns: The offset in the range.
  func constrained(_ offset: CGPoint) -> CGPoint {
    CGPoint(x: min(max(offset.x, minimum.x), maximum.x), y: min(max(offset.y, minimum.y), maximum.y))
  }

  /// Returns where a keyboard scroll shows the content at rest for an offset: in the range, on whole pixels.
  ///
  /// An end of the range between pixels rounds to the nearest pixel, which can be up to half a pixel past the end, as
  /// AppKit's own scrolling comes to rest on whole pixels, so that text at the end stays sharp.
  ///
  /// - Parameter offset: The offset.
  /// - Returns: The resting offset.
  func restingOffset(for offset: CGPoint) -> CGPoint {
    constrained(offset).rounded(toPixelSize: pixelSize)
  }
}

/// The motion of the content for the keys.
///
/// A key held down pushes the content toward its direction up to a top speed, and once the key goes up, a spring brings
/// the content to rest as far as its speed carries it, and at least a step from where the push started. At an end of
/// the range, a key held down stretches the content past the end, and the spring pulls it back.
///
/// It advances in steps of a millisecond, instead of a step per frame, so that the motion doesn't depend on the frame
/// rate.
struct KeyboardScrollPhysics {

  /// A key held down, which pushes the content.
  struct Push {

    /// The direction of the push.
    let direction: KeyboardScrollDirection

    /// The force of the push, which brings the content to the top speed in `Constants.timeToMaximumSpeed`.
    let force: CGFloat

    /// The top speed that the push brings the content to, in points per second.
    let maximumSpeed: CGFloat
  }

  /// The content offset that the motion is at, between pixels and possibly past an end of the range.
  private(set) var position: CGPoint

  /// The velocity of the content, in points per second.
  private(set) var velocity: CGPoint

  /// The key held down that pushes the content, `nil` once the key goes up.
  private(set) var push: Push?

  /// The time that the motion is at.
  private(set) var time: CFTimeInterval

  /// The offset a step from where the push started, which the content comes to rest at least as far as.
  private var minimumTravelPosition: CGPoint

  /// The offset that the spring brings the content to, once the key goes up, and across the push while it's down.
  private var restingPosition: CGPoint

  /// Makes a motion of content at rest.
  ///
  /// - Parameters:
  ///   - position: The content offset.
  ///   - time: The time that the motion starts at.
  init(position: CGPoint, time: CFTimeInterval) {
    self.position = position
    self.time = time
    velocity = .zero
    minimumTravelPosition = position
    restingPosition = position
  }

  /// Starts pushing the content toward a direction, keeping its velocity.
  ///
  /// A push that runs ends with `endPush(in:)` first, which picks where the content comes to rest along it.
  ///
  /// - Parameters:
  ///   - direction: The direction of the key.
  ///   - step: The distance of a press of the key: a line for an arrow key, or a page for a page key.
  mutating func startPush(toward direction: KeyboardScrollDirection, step: CGFloat) {
    ComposeUI.assert(push == nil, "a push must end before another starts")

    let maximumSpeed = step * Constants.maximumSpeedMultiplier
    push = Push(direction: direction, force: maximumSpeed * Constants.mass / Constants.timeToMaximumSpeed, maximumSpeed: maximumSpeed)
    let unitVector = direction.unitVector
    minimumTravelPosition = CGPoint(x: position.x + unitVector.x * step, y: position.y + unitVector.y * step)
  }

  /// Stops pushing the content, and picks where the spring brings it to rest.
  ///
  /// - Parameter range: The scrollable range.
  mutating func endPush(in range: KeyboardScrollRange) {
    guard let push else {
      return
    }

    // along the push, the content comes to rest as far as the spring would take its kinetic energy as elastic energy,
    // 1/2 m v² = 1/2 k x², so that it slows down from the speed it has, and at least a step from where the push started,
    // so that a short tap moves it by a whole step. across the push, it still comes to rest where an earlier key brings
    // it, so that a press on one axis doesn't stop a tap on the other short of its step
    var restingPosition = self.restingPosition
    switch push.direction {
    case .up:
      restingPosition.y = min(position.y + Self.springTravel(forVelocity: velocity.y), minimumTravelPosition.y)
    case .down:
      restingPosition.y = max(position.y + Self.springTravel(forVelocity: velocity.y), minimumTravelPosition.y)
    case .left:
      restingPosition.x = min(position.x + Self.springTravel(forVelocity: velocity.x), minimumTravelPosition.x)
    case .right:
      restingPosition.x = max(position.x + Self.springTravel(forVelocity: velocity.x), minimumTravelPosition.x)
    }

    self.restingPosition = range.constrained(restingPosition)
    self.push = nil
  }

  /// Advances the motion to a time.
  ///
  /// - Parameters:
  ///   - newTime: The time to advance to. An earlier time than the motion's leaves it as it is.
  ///   - range: The scrollable range, which can change between calls, such as when the content changes size.
  mutating func advance(to newTime: CFTimeInterval, in range: KeyboardScrollRange) {
    // a time long after the last one, such as after the display paused, advances the motion by a second at most, which
    // brings it to rest unless a key pushes it, so that a long gap doesn't take long to compute
    if newTime - time > Constants.maximumAdvance {
      time = newTime - Constants.maximumAdvance
    }

    // the steps are counted from the interval instead of adding up their durations, which would drift in floating
    // point and take a step fewer at some times, so that the motion doesn't depend on how the time is split
    let stepCount = Int(((newTime - time) / Constants.timeStep + Constants.stepCountTolerance).rounded(.down))
    guard stepCount > 0 else {
      return
    }

    var stepIndex = 0
    while stepIndex < stepCount {
      advanceOneStep(in: range)
      stepIndex += 1
    }
    time += Double(stepCount) * Constants.timeStep
  }

  /// Returns where the content is at a time after the motion's last step, by its velocity since then.
  ///
  /// The motion advances in whole steps, and a frame between two steps shows the content where it moves on to by the
  /// frame's time, so that it moves by the same distance on each frame at a steady speed, instead of by whole steps.
  ///
  /// - Parameter time: The time, at most a step after the motion's.
  /// - Returns: The content offset at the time.
  func position(at time: CFTimeInterval) -> CGPoint {
    let elapsedTime = CGFloat(max(0, time - self.time))
    return CGPoint(x: position.x + velocity.x * elapsedTime, y: position.y + velocity.y * elapsedTime)
  }

  /// Returns whether the content rests: no key pushes it, and it's still, at its resting offset.
  ///
  /// - Parameter range: The scrollable range.
  /// - Returns: Whether the content rests.
  func isAtRest(in range: KeyboardScrollRange) -> Bool {
    guard push == nil else {
      return false
    }

    // the content comes to rest at the resting offset, not only slow, since a key that goes up while the content is
    // still, such as stretched past an end, leaves it short of where it rests
    let restingOffset = self.restingOffset(in: range)
    let distanceX = position.x - restingOffset.x
    let distanceY = position.y - restingOffset.y
    return velocity.x * velocity.x + velocity.y * velocity.y < Constants.restingSpeed * Constants.restingSpeed &&
      distanceX * distanceX + distanceY * distanceY < Constants.restingDistance * Constants.restingDistance
  }

  /// Returns the offset that the content comes to rest at, on whole pixels in the range.
  ///
  /// - Parameter range: The scrollable range.
  /// - Returns: The resting offset.
  func restingOffset(in range: KeyboardScrollRange) -> CGPoint {
    range.restingOffset(for: restingPosition)
  }

  /// Advances the motion by a step, with a semi-implicit Euler step.
  ///
  /// - Parameter range: The scrollable range.
  private mutating func advanceOneStep(in range: KeyboardScrollRange) {
    var force = CGPoint.zero
    var springsAlongX = true
    var springsAlongY = true
    var target = range.restingOffset(for: restingPosition)

    if let push {
      let unitVector = push.direction.unitVector

      // along the push, the spring only pulls the content back into the range
      let pushTarget = range.restingOffset(for: position)
      if push.direction.isVertical {
        target.y = pushTarget.y
      } else {
        target.x = pushTarget.x
      }

      let pushForce: CGFloat
      if canMove(toward: push.direction, in: range) {
        // the spring would drag against the push, so it only acts across it
        if push.direction.isVertical {
          springsAlongY = false
        } else {
          springsAlongX = false
        }
        pushForce = push.force
      } else {
        // at or past the end, the content stretches: a constant force much stronger than a line's push pulls it out, so
        // that a press at the end stretches it visibly, and the spring pulls it back
        pushForce = Constants.rubberBandForce
      }

      // the push stops at the top speed along its direction, instead of at that speed either way, so that content that
      // moves the other way faster, such as after a page key, slows down first
      if velocity.x * unitVector.x + velocity.y * unitVector.y < push.maximumSpeed {
        force = CGPoint(x: unitVector.x * pushForce, y: unitVector.y * pushForce)
      }
    }

    let displacement = CGPoint(x: position.x - target.x, y: position.y - target.y)
    if springsAlongX {
      force.x -= Constants.stiffness * displacement.x + Constants.damping * velocity.x
    }
    if springsAlongY {
      force.y -= Constants.stiffness * displacement.y + Constants.damping * velocity.y
    }

    let timeStep = CGFloat(Constants.timeStep)
    velocity.x += force.x / Constants.mass * timeStep
    velocity.y += force.y / Constants.mass * timeStep
    position.x += velocity.x * timeStep
    position.y += velocity.y * timeStep

    // the spring stops the content at the target, instead of swinging it past
    if springsAlongX, displacement.x * (position.x - target.x) < 0 {
      velocity.x = 0
    }
    if springsAlongY, displacement.y * (position.y - target.y) < 0 {
      velocity.y = 0
    }
  }

  /// Returns how far the spring takes content that moves at a velocity along an axis.
  ///
  /// - Parameter velocity: The velocity along the axis.
  /// - Returns: The distance, signed as the velocity.
  private static func springTravel(forVelocity velocity: CGFloat) -> CGFloat {
    copysign((velocity * velocity * Constants.mass / Constants.stiffness).squareRoot(), velocity)
  }

  /// Returns whether the content can move toward a direction without passing an end of the range.
  ///
  /// - Parameters:
  ///   - direction: The direction.
  ///   - range: The scrollable range.
  /// - Returns: Whether the content can move toward the direction.
  private func canMove(toward direction: KeyboardScrollDirection, in range: KeyboardScrollRange) -> Bool {
    switch direction {
    case .up:
      return position.y > range.minimum.y
    case .down:
      return position.y < range.maximum.y
    case .left:
      return position.x > range.minimum.x
    case .right:
      return position.x < range.maximum.x
    }
  }

  // MARK: - Constants

  private enum Constants {

    /// The mass of the content.
    static let mass: CGFloat = 1

    /// The stiffness of the spring, a damping ratio of about 0.76 with `damping`.
    static let stiffness: CGFloat = 175

    /// The damping of the spring.
    static let damping: CGFloat = 20

    /// The top speed of a push, in steps per second.
    static let maximumSpeedMultiplier: CGFloat = 25

    /// How long a push takes to bring the content from rest to its top speed, in seconds.
    static let timeToMaximumSpeed: CGFloat = 0.2

    /// The force that stretches the content past an end while a key pushes it there, which the spring balances about 17
    /// points past the end.
    static let rubberBandForce: CGFloat = 3000

    /// The duration of a step of the motion, in seconds.
    static let timeStep: CFTimeInterval = 0.001

    /// The fraction of a step short of a whole step that still counts as one, which absorbs the floating-point error of
    /// an interval that's a whole number of steps.
    static let stepCountTolerance: Double = 1e-6

    /// The longest time that a call advances the motion by, in seconds.
    static let maximumAdvance: CFTimeInterval = 1

    /// The speed under which the content can come to rest, in points per second.
    static let restingSpeed: CGFloat = 1

    /// The distance from the resting offset within which the content can come to rest, in points.
    static let restingDistance: CGFloat = 1
  }
}
#endif
