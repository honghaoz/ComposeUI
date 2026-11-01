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
/// while a page key that isn't held down glides the content by a page. The scroll view ends the push when a key goes up
/// or a modifier changes. The animation ends it itself when the window loses the keyboard or the focus leaves the scroll
/// view, since the key going up doesn't reach the scroll view then.
@available(macOS 14.0, *)
final class KeyboardScrollAnimation: NSObject {

  /// Whether a key held down pushes the content, which keeps the scroll view's keys until it goes up.
  var isKeyHeld: Bool {
    switch motion {
    case .push(let physics):
      return physics.push != nil
    case .glide,
         nil:
      return false
    }
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

  /// How the content moves, `nil` while it doesn't.
  private var motion: Motion?

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
  /// A press during a push or its spring goes on from where the content is and as fast as it moves.
  ///
  /// - Parameters:
  ///   - direction: The direction of the key.
  ///   - step: The distance of a press of the key.
  ///   - time: The time of the key.
  func pressKey(toward direction: KeyboardScrollDirection, step: CGFloat, at time: CFTimeInterval) {
    let range = scrollView.keyboardScrollRange
    let contentOffset = scrollView.contentOffset

    var physics: KeyboardScrollPhysics
    switch motion {
    case .push(var currentPhysics) where contentOffset == lastContentOffset:
      currentPhysics.advance(to: time, in: range)
      physics = currentPhysics
    case .push,
         .glide,
         nil:
      physics = KeyboardScrollPhysics(position: contentOffset, time: time)
    }

    physics.startPush(toward: direction, step: step)
    motion = .push(physics)
    lastContentOffset = contentOffset
    observeKeyWindow()
    startDisplayLink()
  }

  /// Ends the push of the key held down, for the key going up, so that the spring brings the content to rest.
  ///
  /// - Parameter time: The time of the key going up.
  func releaseKey(at time: CFTimeInterval) {
    switch motion {
    case .push(var physics) where physics.push != nil:
      let range = scrollView.keyboardScrollRange
      physics.advance(to: time, in: range)
      physics.endPush(in: range)
      motion = .push(physics)
      stopObservingKeyWindow()
    case .push,
         .glide,
         nil:
      break
    }
  }

  /// Glides the content by a distance for a page key: easing in and out at 1000 points per second for up to 200 ms, or
  /// easing out from where the content is during a glide.
  ///
  /// - Parameters:
  ///   - distance: The distance to glide by, in content coordinates.
  ///   - time: The time of the key.
  func glide(by distance: CGPoint, at time: CFTimeInterval) {
    let contentOffset = scrollView.contentOffset
    let isGliding: Bool
    switch motion {
    case .glide where contentOffset == lastContentOffset:
      isGliding = true
    case .glide,
         .push,
         nil:
      isGliding = false
    }

    let destination = scrollView.keyboardScrollRange.restingOffset(
      for: CGPoint(x: contentOffset.x + distance.x, y: contentOffset.y + distance.y)
    )
    motion = .glide(Glide(from: contentOffset, to: destination, at: time, easesIn: !isGliding))
    lastContentOffset = contentOffset
    stopObservingKeyWindow()
    startDisplayLink()
  }

  /// Moves the content to where the animation has it at a time, and stops once the content rests, or when something
  /// else scrolls the scroll view or disables its scrolling.
  ///
  /// - Parameter time: The time of the frame that shows the content.
  func step(at time: CFTimeInterval) {
    guard let motion, scrollView.contentOffset == lastContentOffset else {
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

    switch motion {
    case .push(var physics):
      physics.advance(to: time, in: range)
      if physics.push != nil, !scrollViewHasFocus {
        physics.endPush(in: range)
        stopObservingKeyWindow()
      }

      if physics.isAtRest(in: range) {
        scrollView.setContentOffsetExactly(physics.restingOffset(in: range))
        stop()
      } else {
        // the content shows on whole pixels on each frame, as AppKit's own scrolling shows it, so that text stays sharp,
        // and past an end while it stretches
        scrollView.setContentOffsetExactly(physics.position(at: time).rounded(toPixelSize: range.pixelSize))
        lastContentOffset = scrollView.contentOffset
        self.motion = .push(physics)
      }
    case .glide(var glide):
      // the range can change during the glide, such as when the content shrinks, so a glide whose end leaves the range
      // turns to the new end from where it has the content at this frame, instead of from the last frame, which would
      // show the last frame again and hold the content still while the range changes on each frame
      let destination = range.restingOffset(for: glide.destination)
      if destination != glide.destination {
        glide = Glide(from: range.constrained(glide.offset(at: time)), to: destination, at: time, easesIn: false)
        self.motion = .glide(glide)
      }

      if glide.hasEnded(at: time) {
        scrollView.setContentOffsetExactly(glide.destination)
        stop()
      } else {
        scrollView.setContentOffsetExactly(glide.offset(at: time).rounded(toPixelSize: range.pixelSize))
        lastContentOffset = scrollView.contentOffset
      }
    }
  }

  /// Stops moving the content, which stays where it is.
  func stop() {
    displayLink?.invalidate()
    displayLink = nil
    motion = nil
    stopObservingKeyWindow()
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
    NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey(_:)), name: NSWindow.didResignKeyNotification, object: window)
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

  // MARK: - Motion

  /// How the content moves.
  private enum Motion {

    /// The push of a key, and the spring that brings the content to rest once the key goes up.
    case push(KeyboardScrollPhysics)

    /// The glide of a page key.
    case glide(Glide)
  }

  /// A glide of the content to a destination along a timing curve.
  private struct Glide {

    /// The content offset that the glide starts from.
    let start: CGPoint

    /// The content offset that the glide ends at.
    let destination: CGPoint

    /// The time that the glide starts at.
    let startTime: CFTimeInterval

    /// The timing curve of the glide, with its duration.
    let curve: AnimationCurve

    /// Makes a glide at 1000 points per second, for up to 200 ms.
    ///
    /// - Parameters:
    ///   - start: The content offset that the glide starts from.
    ///   - destination: The content offset that the glide ends at.
    ///   - startTime: The time that the glide starts at.
    ///   - easesIn: Whether the glide eases in as well as out, which a glide that starts from rest does.
    init(from start: CGPoint, to destination: CGPoint, at startTime: CFTimeInterval, easesIn: Bool) {
      self.start = start
      self.destination = destination
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
