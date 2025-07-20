//
//  HoverGestureRecognizer.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 7/19/25.
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

/// A gesture recognizer that detects mouse hover events on AppKit.
public class HoverGestureRecognizer: NSGestureRecognizer {

  /// Whether the mouse is currently hovering over the view.
  public private(set) var isHovering: Bool = false

  private var trackingArea: NSTrackingArea?
  private var trackingResponder: HoverTrackingResponder!

  private var viewObservation: NSKeyValueObservation?

  private var boundsObservation: NSKeyValueObservation?
  private var frameObservation: NSKeyValueObservation?

  override public init(target: Any?, action: Selector?) {
    super.init(target: target, action: action)
    trackingResponder = HoverTrackingResponder(gestureRecognizer: self)
    setupViewObservation()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented") // swiftlint:disable:this fatal_error
  }

  private func setupViewObservation() {
    viewObservation = observe(\.view, options: [.old, .new]) { [weak self] _, change in
      guard let self = self else {
        return
      }

      // reset for old view
      self.boundsObservation?.invalidate()
      self.boundsObservation = nil
      self.frameObservation?.invalidate()
      self.frameObservation = nil

      if let oldView = change.oldValue, let oldView {
        if let trackingArea = self.trackingArea {
          oldView.removeTrackingArea(trackingArea)
        }
      }

      // setup for new view
      if let newView = change.newValue, let newView {
        self.setupTrackingArea(for: newView)
        self.setupBoundsObservation(for: newView)
      }
    }
  }

  private func setupBoundsObservation(for view: NSView) {
    boundsObservation?.invalidate()
    frameObservation?.invalidate()

    boundsObservation = view.observe(\.bounds, options: [.new]) { [weak self] view, _ in
      self?.setupTrackingArea(for: view)
    }
    frameObservation = view.observe(\.frame, options: [.new]) { [weak self] view, _ in
      self?.setupTrackingArea(for: view)
    }
  }

  private func setupTrackingArea(for view: NSView) {
    // remove existing tracking area
    if let trackingArea = trackingArea {
      view.removeTrackingArea(trackingArea)
    }

    // create new tracking area
    let trackingArea = NSTrackingArea(
      rect: view.bounds,
      options: [.activeAlways, .mouseEnteredAndExited, .enabledDuringMouseDrag],
      owner: trackingResponder,
      userInfo: nil
    )
    view.addTrackingArea(trackingArea)
    self.trackingArea = trackingArea
  }

  fileprivate func handleMouseEntered(with event: NSEvent) {
    if !isHovering {
      isHovering = true
      state = .began
    }
  }

  fileprivate func handleMouseExited(with event: NSEvent) {
    if isHovering {
      isHovering = false
      state = .ended
    }
  }

  // MARK: - Cleanup

  deinit {
    viewObservation?.invalidate()
    boundsObservation?.invalidate()
    frameObservation?.invalidate()

    if let trackingArea = trackingArea, let view = view {
      view.removeTrackingArea(trackingArea)
    }
    trackingResponder.gestureRecognizer = nil
  }

  // MARK: - Testing

  #if DEBUG

  var test: Test { Test(host: self) }

  class Test {

    private let host: HoverGestureRecognizer

    fileprivate init(host: HoverGestureRecognizer) {
      ComposeUI.assert(Thread.isRunningXCTest, "test namespace should only be used in test target.")
      self.host = host
    }

    func handleMouseEntered(with event: NSEvent) {
      host.handleMouseEntered(with: event)
    }

    func handleMouseExited(with event: NSEvent) {
      host.handleMouseExited(with: event)
    }
  }

  #endif
}

/// A dedicated responder that handles tracking area events for HoverGestureRecognizer
private final class HoverTrackingResponder: NSResponder {

  weak var gestureRecognizer: HoverGestureRecognizer?

  init(gestureRecognizer: HoverGestureRecognizer) {
    self.gestureRecognizer = gestureRecognizer
    super.init()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented") // swiftlint:disable:this fatal_error
  }

  override func mouseEntered(with event: NSEvent) {
    gestureRecognizer?.handleMouseEntered(with: event)
  }

  override func mouseExited(with event: NSEvent) {
    gestureRecognizer?.handleMouseExited(with: event)
  }
}

#endif
