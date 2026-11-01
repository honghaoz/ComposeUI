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
/// while a page key that isn't held down glides the content by a page. A glide and a push or a spring go on together
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

  /// The push of a key and the spring that brings the content to rest once the key goes up, `nil` if no key has pushed
  /// the content since it last came to rest.
  ///
  /// While a glide runs, they move the content only along the other axis, and they take the glide's axis over from where
  /// it leaves the content, at rest.
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
    let contentOffset = scrollView.contentOffset
    if contentOffset != lastContentOffset {
      // something else scrolled the scroll view, so the press starts from where the content is, at rest
      stop()
    }

    if let glide, glide.isVertical == direction.isVertical {
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
    let contentOffset = scrollView.contentOffset
    if contentOffset != lastContentOffset {
      // something else scrolled the scroll view, so the glide starts from where the content is, at rest
      stop()
    }

    let isGliding = glide?.isVertical == direction.isVertical
    endGlide(at: contentOffset)

    let unitVector = direction.unitVector
    let destination = scrollView.keyboardScrollRange.restingOffset(
      for: CGPoint(x: contentOffset.x + unitVector.x * distance, y: contentOffset.y + unitVector.y * distance)
    )
    glide = Glide(from: contentOffset, to: destination, isVertical: direction.isVertical, at: time, easesIn: !isGliding)
    lastContentOffset = contentOffset
    startDisplayLink()
  }

  /// Moves the content to where the animation has it at a time, and stops once the content rests, or when something
  /// else scrolls the scroll view or disables its scrolling.
  ///
  /// - Parameter time: The time of the frame that shows the content.
  func step(at time: CFTimeInterval) {
    guard physics != nil || glide != nil, scrollView.contentOffset == lastContentOffset else {
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

    var offset = lastContentOffset
    if var physics {
      physics.advance(to: time, in: range)
      if physics.push != nil, !scrollViewHasFocus {
        physics.endPush(in: range)
        stopObservingKeyWindow()
      }
      offset = physics.position(at: time)
      self.physics = physics
    }

    if var glide {
      // the range can change during the glide, such as when the content shrinks, so a glide whose end leaves the range
      // turns to the new end from where it has the content at this frame, instead of from the last frame, which would
      // show the last frame again and hold the content still while the range changes on each frame
      let destination = range.restingOffset(for: glide.destination)
      if destination != glide.destination {
        glide = Glide(
          from: range.constrained(glide.offset(at: time)),
          to: destination,
          isVertical: glide.isVertical,
          at: time,
          easesIn: false
        )
      }

      let glideOffset: CGPoint
      if glide.hasEnded(at: time) {
        glideOffset = glide.destination
        endGlide(at: glide.destination)
      } else {
        glideOffset = glide.offset(at: time)
        self.glide = glide
      }
      if glide.isVertical {
        offset.y = glideOffset.y
      } else {
        offset.x = glideOffset.x
      }
    }

    if self.glide == nil, physics?.isAtRest(in: range) ?? true {
      scrollView.setContentOffsetExactly(physics?.restingOffset(in: range) ?? offset)
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

  /// A glide of the content to a destination along a timing curve, which moves the content along one axis.
  private struct Glide {

    /// The content offset that the glide starts from.
    let start: CGPoint

    /// The content offset that the glide ends at.
    let destination: CGPoint

    /// The time that the glide starts at.
    let startTime: CFTimeInterval

    /// The timing curve of the glide, with its duration.
    let curve: AnimationCurve

    /// Whether the glide moves the content along the vertical axis, rather than the horizontal one.
    let isVertical: Bool

    /// Makes a glide at 1000 points per second, for up to 200 ms.
    ///
    /// - Parameters:
    ///   - start: The content offset that the glide starts from.
    ///   - destination: The content offset that the glide ends at.
    ///   - isVertical: Whether the glide moves the content along the vertical axis, rather than the horizontal one.
    ///   - startTime: The time that the glide starts at.
    ///   - easesIn: Whether the glide eases in as well as out, which a glide that starts from rest does.
    init(from start: CGPoint, to destination: CGPoint, isVertical: Bool, at startTime: CFTimeInterval, easesIn: Bool) {
      self.start = start
      self.destination = destination
      self.isVertical = isVertical
      self.startTime = startTime
      let length = hypot(destination.x - start.x, destination.y - start.y)
      let duration = min(TimeInterval(length) / Constants.glideSpeed, Constants.maximumGlideDuration)
      curve = AnimationCurve(timingFunction: CAMediaTimingFunction(name: easesIn ? .easeInEaseOut : .easeOut), duration: duration)
    }

    /// Returns whether the glide has ended at a time.
    ///
    /// - Parameter time: The time.
    /// - Returns: Whether the glide has ended.
    func hasEnded(at time: CFTimeInterval) -> Bool {
      time - startTime >= curve.duration
    }

    /// Returns where the glide has the content at a time, between pixels.
    ///
    /// - Parameter time: The time.
    /// - Returns: The content offset.
    func offset(at time: CFTimeInterval) -> CGPoint {
      let progress = CGFloat(curve.progress(forElapsedTime: time - startTime))
      return CGPoint(x: start.x + (destination.x - start.x) * progress, y: start.y + (destination.y - start.y) * progress)
    }
  }

  // MARK: - Constants

  private enum Constants {

    /// The speed of a glide, in points per second.
    static let glideSpeed: TimeInterval = 1000

    /// The longest duration of a glide, in seconds.
    static let maximumGlideDuration: TimeInterval = 0.2
  }
}
#endif
