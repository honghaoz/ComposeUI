//
//  KeyboardScrollAnimation.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/31/26.
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
import AppKit

/// The animation that moves a scroll view's content for the keyboard on a spring, as UIKit's keyboard scrolling does on
/// iPad.
///
/// Each key moves the target by its distance, from the target of the scroll in flight, and the content follows the target
/// on the spring from where it is and as fast as it moves, so that the presses of a key held down glide into each other.
/// The content comes to rest on whole pixels in the scrollable range.
@available(macOS 14.0, *)
final class KeyboardScrollAnimation: NSObject {

  /// The content offset that the content moves to.
  private(set) var target: CGPoint = .zero

  /// Whether the content is moving.
  var isRunning: Bool {
    displayLink != nil
  }

  /// The scroll view whose content the animation moves.
  ///
  /// The scroll view stops the animation when it goes, so the display link never steps the animation without it.
  private unowned let scrollView: ScrollView

  /// The display link that moves the content on each frame, while the content moves.
  private var displayLink: CADisplayLink?

  /// The time that the current motion to the target starts at.
  private var startTime: CFTimeInterval = 0

  /// The content's distance from the target at the start time, which the spring pulls to zero.
  private var startDisplacement: CGPoint = .zero

  /// The content's velocity at the start time, in points per second.
  private var startVelocity: CGPoint = .zero

  /// The content offset that the animation set last, which tells when something else scrolls the scroll view.
  private var lastContentOffset: CGPoint = .zero

  /// Makes an animation for a scroll view.
  ///
  /// - Parameter scrollView: The scroll view whose content the animation moves.
  init(scrollView: ScrollView) {
    self.scrollView = scrollView
  }

  /// Moves the target by a distance from the target of the scroll in flight, or from the content offset when no scroll is
  /// in flight, and starts moving the content to it.
  ///
  /// - Parameters:
  ///   - distance: The distance to move the target by, in content coordinates.
  ///   - time: The time of the key that scrolls.
  func scroll(by distance: CGPoint, at time: CFTimeInterval) {
    // a scroll in flight goes on from where the content is and as fast as it moves, unless something else scrolled the
    // scroll view since its last frame, which ends it
    let contentOffset = scrollView.contentOffset
    if isRunning, contentOffset == lastContentOffset {
      retarget(to: scrollView.keyboardScrollOffset(for: CGPoint(x: target.x + distance.x, y: target.y + distance.y)), at: time)
    } else {
      target = scrollView.keyboardScrollOffset(for: CGPoint(x: contentOffset.x + distance.x, y: contentOffset.y + distance.y))
      startTime = time
      startDisplacement = CGPoint(x: contentOffset.x - target.x, y: contentOffset.y - target.y)
      startVelocity = .zero
      lastContentOffset = contentOffset
      startDisplayLink()
    }
  }

  /// Moves the content to where the spring has it at a time, and stops once the content rests at the target, or when
  /// something else scrolls the scroll view or disables its scrolling.
  ///
  /// - Parameter time: The time of the frame that shows the content.
  func step(at time: CFTimeInterval) {
    guard scrollView.isScrollEnabled, scrollView.contentOffset == lastContentOffset else {
      stop()
      return
    }

    // the scrollable range can change during the scroll, such as when the content changes size, so the target moves
    // back into it, and the content turns to it from where it is
    let restingTarget = scrollView.keyboardScrollOffset(for: target)
    if restingTarget != target {
      retarget(to: restingTarget, at: time)
    }

    var motion = self.motion(at: time)

    // the content stays in the scrollable range on each frame, as AppKit's own scrolling keeps it, so where the spring
    // would carry it past an end, such as after the range shrinks during the scroll, it stops at the end and loses its
    // speed along that axis, instead of showing what's past the end and turning back from out of view
    let position = CGPoint(x: target.x + motion.displacement.x, y: target.y + motion.displacement.y)
    let positionInRange = scrollView.contentOffsetInScrollableRange(position)
    if positionInRange != position {
      startTime = time
      startDisplacement = CGPoint(x: positionInRange.x - target.x, y: positionInRange.y - target.y)
      startVelocity = CGPoint(
        x: positionInRange.x == position.x ? motion.velocity.x : 0,
        y: positionInRange.y == position.y ? motion.velocity.y : 0
      )
      motion = (startDisplacement, startVelocity)
    }

    let pixelSize = scrollView.pixelSize
    let isAtRest = hypot(motion.velocity.x, motion.velocity.y) < Constants.restingSpeed &&
      abs(motion.displacement.x) < pixelSize.width / 2 &&
      abs(motion.displacement.y) < pixelSize.height / 2
    if isAtRest {
      scrollView.setContentOffsetExactly(target)
      stop()
    } else {
      // the content shows on whole pixels on each frame, as AppKit's own scrolling shows it, so that text stays sharp
      scrollView.setContentOffsetExactly(
        scrollView.keyboardScrollOffset(for: CGPoint(x: target.x + motion.displacement.x, y: target.y + motion.displacement.y))
      )
      lastContentOffset = scrollView.contentOffset
    }
  }

  /// Stops moving the content, which stays where it is.
  func stop() {
    displayLink?.invalidate()
    displayLink = nil
  }

  @objc private func step(_ displayLink: CADisplayLink) {
    step(at: displayLink.targetTimestamp)
  }

  private func startDisplayLink() {
    guard displayLink == nil else {
      return
    }

    // the display link follows the screen of the scroll view's window, and steps the content in the event tracking run
    // loop mode too, such as while a menu is open
    let displayLink = scrollView.displayLink(target: self, selector: #selector(step(_:)))
    displayLink.add(to: .main, forMode: .common)
    self.displayLink = displayLink
  }

  /// Moves the target, and starts the motion to it from where the content is at a time, as fast as it moves.
  ///
  /// - Parameters:
  ///   - newTarget: The new target.
  ///   - time: The time to start the motion at.
  private func retarget(to newTarget: CGPoint, at time: CFTimeInterval) {
    let motion = self.motion(at: time)
    let position = CGPoint(x: target.x + motion.displacement.x, y: target.y + motion.displacement.y)
    target = newTarget
    startTime = time
    startDisplacement = CGPoint(x: position.x - newTarget.x, y: position.y - newTarget.y)
    startVelocity = motion.velocity
  }

  /// Returns the content's distance from the target and its velocity at a time, by the spring's motion from the start.
  ///
  /// - Parameter time: The time.
  /// - Returns: The distance from the target, and the velocity, in points per second.
  private func motion(at time: CFTimeInterval) -> (displacement: CGPoint, velocity: CGPoint) {
    // an underdamped spring's displacement u(t) = e^(-βt) (u0 cos(ωt) + (v0 + β u0) / ω sin(ωt)), where β is the decay
    // rate and ω the damped frequency, and its velocity u'(t) = e^(-βt) (v0 cos(ωt) - (β v0 + ω0² u0) / ω sin(ωt))
    let elapsed = max(0, time - startTime)
    let decayRate = Constants.decayRate
    let dampedFrequency = Constants.dampedFrequency
    let decay = exp(-decayRate * elapsed)
    let cosine = cos(dampedFrequency * elapsed)
    let sine = sin(dampedFrequency * elapsed)

    func displacement(_ displacement: CGFloat, _ velocity: CGFloat) -> CGFloat {
      decay * (displacement * cosine + (velocity + decayRate * displacement) / dampedFrequency * sine)
    }

    func velocity(_ displacement: CGFloat, _ velocity: CGFloat) -> CGFloat {
      decay * (velocity * cosine - (decayRate * velocity + Constants.naturalFrequencySquared * displacement) / dampedFrequency * sine)
    }

    return (
      CGPoint(x: displacement(startDisplacement.x, startVelocity.x), y: displacement(startDisplacement.y, startVelocity.y)),
      CGPoint(x: velocity(startDisplacement.x, startVelocity.x), y: velocity(startDisplacement.y, startVelocity.y))
    )
  }

  // MARK: - Constants

  private enum Constants {

    /// The spring that the content moves on, which UIKit's keyboard scrolling moves the content on on iPad.
    ///
    /// It's underdamped, with a damping ratio of about 0.96, so the content comes to rest at the target in about half a
    /// second, without a visible overshoot.
    static let spring = SpringDescriptor(mass: 1, stiffness: 109, damping: 20)

    /// The rate that the spring's motion decays at, per second.
    static let decayRate = spring.damping / (2 * spring.mass)

    /// The square of the spring's natural frequency.
    static let naturalFrequencySquared = spring.stiffness / spring.mass

    /// The frequency of the spring's damped oscillation, in radians per second.
    static let dampedFrequency = (naturalFrequencySquared - decayRate * decayRate).squareRoot()

    /// The speed under which the content can come to rest, in points per second, as UIKit's keyboard scrolling stops.
    static let restingSpeed: CGFloat = 1
  }
}
#endif
