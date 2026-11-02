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

/// The animation that moves a scroll view's content for the keyboard.
///
/// A key pushes the content until it goes up, and a spring then brings the content to rest, see `KeyboardScrollPhysics`,
/// while a page key that isn't held down glides the content by a page, and an arrow key with Command glides it to the
/// edge. A glide and a push or a spring go on together
/// along different axes, so that a key on one axis doesn't stop a key on the other short. The scroll view ends the push
/// when a key goes up or a modifier changes. The animation ends it itself when the window loses the keyboard or the focus
/// leaves the scroll view, since the key going up doesn't reach the scroll view then.
@available(macOS 14.0, *)
final class KeyboardScrollAnimation: NSObject {

  /// Whether a key held down pushes the content, which keeps the scroll view's keys until it goes up.
  var isKeyHeld: Bool {
    physics?.push != nil
  }

  /// Whether the content moves.
  var isRunning: Bool {
    displayLink != nil
  }

  /// The scroll view whose content the animation moves.
  ///
  /// The scroll view stops the animation when it goes, so the display link never steps the animation without it.
  private unowned let scrollView: ScrollView

  /// The display link that moves the content on each frame, while the content moves.
  private var displayLink: CADisplayLink?

  /// The push of a key and the spring that brings the content to rest once the key goes up, `nil` while the content
  /// rests.
  ///
  /// While a glide runs, they move the content only along the other axis, where the spring brings content outside the
  /// range back into it, and they take the glide's axis over from where the glide leaves the content, at rest.
  private var physics: KeyboardScrollPhysics?

  /// The glide of a page key, `nil` while no glide moves the content.
  private var glide: Glide?

  /// The content offset that the animation set last, which tells when something else scrolls the scroll view.
  private var lastContentOffset: CGPoint = .zero

  /// The window whose losing the keyboard ends the push, while a key held down pushes the content.
  private weak var observedWindow: NSWindow?

  /// Makes an animation for a scroll view.
  ///
  /// - Parameter scrollView: The scroll view whose content the animation moves.
  init(scrollView: ScrollView) {
    self.scrollView = scrollView
  }

  /// Starts pushing the content toward a direction, for a key that goes down, until it goes up.
  ///
  /// A press during a push or its spring goes on from where the content is and as fast as it moves. A press along a
  /// glide's axis pushes the content from where the glide has it, at rest, while a glide along the other axis goes on.
  ///
  /// - Parameters:
  ///   - direction: The direction of the key.
  ///   - step: The distance of a press of the key.
  ///   - time: The time of the key.
  func pressKey(toward direction: KeyboardScrollDirection, step: CGFloat, at time: CFTimeInterval) {
    let contentOffset = contentOffsetForNewMotion()

    if glide?.isVertical == direction.isVertical {
      endGlide(at: contentOffset)
    }

    var physics = self.physics ?? KeyboardScrollPhysics(position: contentOffset, time: time)
    physics.advance(to: time, in: scrollView.keyboardScrollRange)
    physics.startPush(toward: direction, step: step)
    self.physics = physics
    lastContentOffset = contentOffset
    observeKeyWindow()
    startDisplayLink()
  }

  /// Ends the push of the key held down, for the key going up, so that the spring brings the content to rest.
  ///
  /// - Parameter time: The time of the key going up.
  func releaseKey(at time: CFTimeInterval) {
    guard var physics, physics.push != nil else {
      return
    }

    let range = scrollView.keyboardScrollRange
    physics.advance(to: time, in: range)
    physics.endPush(in: range)
    self.physics = physics
    stopObservingKeyWindow()
  }

  /// Glides the content toward a direction for a page key: easing in and out at 1000 points per second for up to 200 ms,
  /// or easing out from where the content is during a glide along the same axis, while a push or a spring goes on along
  /// the other axis.
  ///
  /// - Parameters:
  ///   - direction: The direction of the key.
  ///   - distance: The distance to glide by.
  ///   - time: The time of the key.
  func glide(toward direction: KeyboardScrollDirection, by distance: CGFloat, at time: CFTimeInterval) {
    let contentOffset = contentOffsetForNewMotion()
    let isVertical = direction.isVertical
    let isGliding = glide?.isVertical == isVertical
    let unitVector = direction.unitVector
    let destination = scrollView.keyboardScrollRange.restingOffset(
      for: CGPoint(x: contentOffset.x + unitVector.x * distance, y: contentOffset.y + unitVector.y * distance)
    )
    let glide = Glide(
      alongVerticalAxis: isVertical,
      from: contentOffset.coordinate(alongVerticalAxis: isVertical),
      to: destination.coordinate(alongVerticalAxis: isVertical),
      at: time,
      easesIn: !isGliding
    )
    start(glide, from: contentOffset, at: time)
  }

  /// Glides the content to the edge of the scrollable range toward a direction, for an arrow key with Command: along a
  /// spring that comes to rest without passing the edge, which starts at speed and slows down into the edge, for up to
  /// 1.6 s, while a push or a spring goes on along the other axis.
  ///
  /// - Parameters:
  ///   - direction: The direction of the key.
  ///   - time: The time of the key.
  func glideToEdge(toward direction: KeyboardScrollDirection, at time: CFTimeInterval) {
    let contentOffset = contentOffsetForNewMotion()
    start(Glide(toEdgeToward: direction, from: contentOffset, in: scrollView.keyboardScrollRange, at: time), from: contentOffset, at: time)
  }

  /// Moves the content to where the animation has it at a time, and stops once the content rests, or when something
  /// else scrolls the scroll view or disables its scrolling.
  ///
  /// - Parameter time: The time of the frame that shows the content.
  func step(at time: CFTimeInterval) {
    guard var physics, scrollView.contentOffset == lastContentOffset else {
      stop()
      return
    }

    let range = scrollView.keyboardScrollRange
    guard scrollView.isScrollEnabled else {
      // content that's stretched past an end doesn't stay stretched once scrolling is disabled
      scrollView.setContentOffsetExactly(range.restingOffset(for: lastContentOffset))
      stop()
      return
    }

    physics.advance(to: time, in: range)
    if physics.push != nil, !scrollViewHasFocus {
      physics.endPush(in: range)
      stopObservingKeyWindow()
    }
    var offset = physics.position(at: time)

    if var glide {
      // the range can change during the glide, such as when the content changes size, so a glide whose destination
      // leaves the range, or whose edge moves, turns to where it now ends from where it has the content at this frame,
      // instead of from the last frame, which would show the last frame again and hold the content still while the range
      // changes on each frame
      let isVertical = glide.isVertical
      let destination = glide.destination(in: range, from: offset)
      if destination != glide.destination {
        let start = range.constrained(offset.with(glide.offset(at: time), alongVerticalAxis: isVertical))
        glide = glide.turned(to: destination, from: start.coordinate(alongVerticalAxis: isVertical), at: time)
      }

      if glide.hasEnded(at: time) {
        offset = offset.with(glide.destination, alongVerticalAxis: isVertical)
        physics.rest(at: offset, alongVerticalAxis: isVertical)
        self.glide = nil
      } else {
        offset = offset.with(glide.offset(at: time), alongVerticalAxis: isVertical)
        self.glide = glide
      }
    }
    self.physics = physics

    if self.glide == nil, physics.isAtRest(in: range) {
      scrollView.setContentOffsetExactly(physics.restingOffset(in: range))
      stop()
    } else {
      // the content shows on whole pixels on each frame, as AppKit's own scrolling shows it, so that text stays sharp,
      // and past an end while it stretches
      scrollView.setContentOffsetExactly(offset.rounded(toPixelSize: range.pixelSize))
      lastContentOffset = scrollView.contentOffset
    }
  }

  /// Stops moving the content, which stays where it is.
  func stop() {
    displayLink?.invalidate()
    displayLink = nil
    physics = nil
    glide = nil
    stopObservingKeyWindow()
  }

  /// Ends the glide, which leaves the content at rest along its axis at an offset, where the push and the spring take the
  /// axis over.
  ///
  /// - Parameter offset: The content offset.
  private func endGlide(at offset: CGPoint) {
    guard let glide else {
      return
    }

    physics?.rest(at: offset, alongVerticalAxis: glide.isVertical)
    self.glide = nil
  }

  /// Starts a glide in place of the glide that runs, which leaves the content where it is along its axis.
  ///
  /// - Parameters:
  ///   - glide: The glide, which starts from where the content is.
  ///   - contentOffset: The content offset.
  ///   - time: The time that the glide starts at.
  private func start(_ glide: Glide, from contentOffset: CGPoint, at time: CFTimeInterval) {
    endGlide(at: contentOffset)
    self.glide = glide
    // the spring holds the content along the other axis, and brings it back into the range when something else left it
    // outside, as it does content stretched past an end
    physics = physics ?? KeyboardScrollPhysics(position: contentOffset, time: time)
    lastContentOffset = contentOffset
    startDisplayLink()
  }

  /// Returns the content offset that a new press or glide starts from, which stops the motions first when something
  /// else scrolled the scroll view, so that the new one starts from where the content is, at rest.
  private func contentOffsetForNewMotion() -> CGPoint {
    let contentOffset = scrollView.contentOffset
    if contentOffset != lastContentOffset {
      stop()
    }
    return contentOffset
  }

  /// Whether the keyboard focus is in the scroll view, where the key going up reaches it.
  private var scrollViewHasFocus: Bool {
    guard let firstResponder = scrollView.window?.firstResponder as? NSView else {
      return false
    }
    return firstResponder.isDescendant(of: scrollView)
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

  // MARK: - Key Window

  /// Observes the scroll view's window losing the keyboard, while a key held down pushes the content.
  private func observeKeyWindow() {
    guard observedWindow == nil, let window = scrollView.window else {
      return
    }

    observedWindow = window
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidResignKey(_:)),
      name: NSWindow.didResignKeyNotification,
      object: window
    )
  }

  private func stopObservingKeyWindow() {
    guard let observedWindow else {
      return
    }

    NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: observedWindow)
    self.observedWindow = nil
  }

  @objc private func windowDidResignKey(_ notification: Notification) {
    // the key going up goes to another window or app once the window loses the keyboard
    releaseKey(at: AnimationClock.now)
  }

  // MARK: - Glide

  /// A glide of the content to a destination over time, along one axis.
  private struct Glide {

    /// Whether the glide moves the content along the vertical axis, rather than the horizontal one.
    let isVertical: Bool

    /// The content offset along the glide's axis that the glide starts from.
    let start: CGFloat

    /// The content offset along the glide's axis that the glide ends at.
    let destination: CGFloat

    /// The time that the glide starts at.
    let startTime: CFTimeInterval

    /// How the glide moves the content over time.
    private let timing: Timing

    /// How a glide moves the content over time.
    private enum Timing {

      /// Along a timing curve, with its duration.
      case curve(AnimationCurve)

      /// Along the spring of a glide to the edge toward a direction, which ends once the content is within a distance of
      /// the edge.
      case edgeSpring(direction: KeyboardScrollDirection, endingDistance: CGFloat)
    }

    /// Makes a glide at 1000 points per second, for up to 200 ms.
    ///
    /// - Parameters:
    ///   - isVertical: Whether the glide moves the content along the vertical axis, rather than the horizontal one.
    ///   - start: The content offset along the axis that the glide starts from.
    ///   - destination: The content offset along the axis that the glide ends at.
    ///   - startTime: The time that the glide starts at.
    ///   - easesIn: Whether the glide eases in as well as out, which a glide that starts from rest does.
    init(alongVerticalAxis isVertical: Bool, from start: CGFloat, to destination: CGFloat, at startTime: CFTimeInterval, easesIn: Bool) {
      let length = abs(destination - start)
      let duration = min(TimeInterval(length) / Constants.glideSpeed, Constants.maximumGlideDuration)
      let timingFunction = CAMediaTimingFunction(name: easesIn ? .easeInEaseOut : .easeOut)
      let timing = Timing.curve(AnimationCurve(timingFunction: timingFunction, duration: duration))
      self.init(alongVerticalAxis: isVertical, from: start, to: destination, at: startTime, timing: timing)
    }

    /// Makes a glide to the edge of a range toward a direction, along a spring, which ends once the content is within a
    /// quarter of a pixel of the edge.
    ///
    /// - Parameters:
    ///   - direction: The direction of the edge.
    ///   - offset: The content offset that the glide starts from.
    ///   - range: The scrollable range.
    ///   - startTime: The time that the glide starts at.
    init(toEdgeToward direction: KeyboardScrollDirection, from offset: CGPoint, in range: KeyboardScrollRange, at startTime: CFTimeInterval) {
      let isVertical = direction.isVertical
      let pixelLength = isVertical ? range.pixelSize.height : range.pixelSize.width
      let timing = Timing.edgeSpring(direction: direction, endingDistance: pixelLength * Constants.edgeSpringEndingPixelFraction)
      self.init(
        alongVerticalAxis: isVertical,
        from: offset.coordinate(alongVerticalAxis: isVertical),
        to: Self.edge(toward: direction, in: range, from: offset),
        at: startTime,
        timing: timing
      )
    }

    private init(alongVerticalAxis isVertical: Bool, from start: CGFloat, to destination: CGFloat, at startTime: CFTimeInterval, timing: Timing) {
      self.isVertical = isVertical
      self.start = start
      self.destination = destination
      self.startTime = startTime
      self.timing = timing
    }

    /// Returns whether the glide has ended at a time.
    ///
    /// - Parameter time: The time.
    /// - Returns: Whether the glide has ended.
    func hasEnded(at time: CFTimeInterval) -> Bool {
      let elapsedTime = time - startTime
      switch timing {
      case .curve(let curve):
        return elapsedTime >= curve.duration
      case .edgeSpring(_, let endingDistance):
        // the spring takes long to settle its last fraction of a pixel, which doesn't show, so the glide ends once the
        // content is closer to the edge than that
        return elapsedTime >= Constants.edgeSpringDuration || abs(destination - offset(at: time)) < endingDistance
      }
    }

    /// Returns where the glide has the content along its axis at a time, between pixels.
    ///
    /// - Parameter time: The time.
    /// - Returns: The content offset along the glide's axis.
    func offset(at time: CFTimeInterval) -> CGFloat {
      let elapsedTime = time - startTime
      let progress: Double
      switch timing {
      case .curve(let curve):
        progress = curve.progress(forElapsedTime: elapsedTime)
      case .edgeSpring:
        progress = Self.edgeSpringProgress(forElapsedTime: elapsedTime)
      }
      return start + (destination - start) * CGFloat(progress)
    }

    /// Returns where the glide ends along its axis in a range: its destination brought into the range, or the range's
    /// edge for a glide to an edge, which goes on to the edge as the range changes.
    ///
    /// - Parameters:
    ///   - range: The scrollable range.
    ///   - offset: The content offset, which the glide's destination replaces along its axis.
    /// - Returns: The content offset along the glide's axis that the glide ends at.
    func destination(in range: KeyboardScrollRange, from offset: CGPoint) -> CGFloat {
      switch timing {
      case .curve:
        return range.restingOffset(for: offset.with(destination, alongVerticalAxis: isVertical)).coordinate(alongVerticalAxis: isVertical)
      case .edgeSpring(let direction, _):
        return Self.edge(toward: direction, in: range, from: offset)
      }
    }

    /// Returns a glide of the same kind that turns to another destination from an offset at a time, such as when the
    /// scrollable range leaves the glide's destination.
    ///
    /// - Parameters:
    ///   - destination: The content offset along the glide's axis to turn to.
    ///   - start: The content offset along the glide's axis that the new glide starts from.
    ///   - time: The time that the new glide starts at.
    /// - Returns: The glide to the new destination.
    func turned(to destination: CGFloat, from start: CGFloat, at time: CFTimeInterval) -> Glide {
      switch timing {
      case .curve:
        return Glide(alongVerticalAxis: isVertical, from: start, to: destination, at: time, easesIn: false)
      case .edgeSpring:
        return Glide(alongVerticalAxis: isVertical, from: start, to: destination, at: time, timing: timing)
      }
    }

    /// Returns the content offset along an axis at the edge of a range toward a direction, on whole pixels.
    ///
    /// - Parameters:
    ///   - direction: The direction of the edge.
    ///   - range: The scrollable range.
    ///   - offset: The content offset, which the edge replaces along the direction's axis.
    /// - Returns: The content offset along the direction's axis at the edge.
    private static func edge(toward direction: KeyboardScrollDirection, in range: KeyboardScrollRange, from offset: CGPoint) -> CGFloat {
      var edge = offset
      switch direction {
      case .up:
        edge.y = range.minimum.y
      case .down:
        edge.y = range.maximum.y
      case .left:
        edge.x = range.minimum.x
      case .right:
        edge.x = range.maximum.x
      }
      return range.restingOffset(for: edge).coordinate(alongVerticalAxis: direction.isVertical)
    }

    /// Returns the progress of the spring of a glide to an edge after an elapsed time.
    ///
    /// The spring is critically damped, so that it comes to rest without passing the edge, and the time warps along a
    /// curve that makes the spring start at speed instead of easing in, so that the glide starts as soon as the key goes
    /// down and slows down into the edge.
    ///
    /// - Parameter elapsedTime: The time since the glide started, in seconds.
    /// - Returns: The progress, from 0 at the start to 1 at the edge.
    private static func edgeSpringProgress(forElapsedTime elapsedTime: TimeInterval) -> Double {
      let warpedTime = Constants.edgeSpringTimeWarp.progress(forElapsedTime: elapsedTime) * Constants.edgeSpringDuration
      let angularFrequency = 2 * Double.pi / Constants.edgeSpringResponse
      return 1 - exp(-angularFrequency * warpedTime) * (1 + angularFrequency * warpedTime)
    }
  }

  // MARK: - Constants

  private enum Constants {

    /// The speed of a glide, in points per second.
    static let glideSpeed: TimeInterval = 1000

    /// The longest duration of a glide, in seconds.
    static let maximumGlideDuration: TimeInterval = 0.2

    /// The response of the spring of a glide to an edge: the period of its oscillation without damping, in seconds.
    static let edgeSpringResponse: Double = 0.6

    /// The longest duration of a glide to an edge, which its spring takes to settle, in seconds.
    static let edgeSpringDuration: TimeInterval = 1.6

    /// The curve that warps the time of the spring of a glide to an edge, which makes the spring start at speed.
    static let edgeSpringTimeWarp = AnimationCurve(timingFunction: CAMediaTimingFunction(controlPoints: 0, 0.2, 1, 1), duration: edgeSpringDuration)

    /// The fraction of a pixel from the edge within which a glide to an edge ends.
    static let edgeSpringEndingPixelFraction: CGFloat = 0.25
  }
}

private extension CGPoint {

  /// Returns the coordinate of the point along an axis.
  ///
  /// - Parameter isVertical: Whether the axis is the vertical one, rather than the horizontal one.
  /// - Returns: The coordinate.
  func coordinate(alongVerticalAxis isVertical: Bool) -> CGFloat {
    isVertical ? y : x
  }

  /// Returns the point with its coordinate along an axis replaced.
  ///
  /// - Parameters:
  ///   - coordinate: The coordinate along the axis.
  ///   - isVertical: Whether the axis is the vertical one, rather than the horizontal one.
  /// - Returns: The point with the coordinate.
  func with(_ coordinate: CGFloat, alongVerticalAxis isVertical: Bool) -> CGPoint {
    isVertical ? CGPoint(x: x, y: coordinate) : CGPoint(x: coordinate, y: y)
  }
}
#endif
