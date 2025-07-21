//
//  MouseEventView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 7/20/25.
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

/// A view that handles mouse events.
class MouseEventView: NSView {

  enum MouseEvent: Hashable {

    case mouseEntered
    case mouseMoved
    case mouseExited

    case mouseDown
    case mouseDragged
    case mouseUp
  }

  /// Callback when mouse event occurs.
  var handler: ((MouseEventView, MouseEvent) -> Void)?

  init() {
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  override var mouseDownCanMoveWindow: Bool {
    // don't drag window
    false
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    // can click through even when window is inactive.
    return true
  }

  // MARK: - Tracking Area

  private var trackingArea: NSTrackingArea?

  override func updateTrackingAreas() {
    super.updateTrackingAreas()

    setupTrackingArea()
  }

  func setupTrackingArea() {
    // only setup tracking area if the rect is different from the existing tracking area
    guard trackingArea == nil || trackingArea?.rect != bounds else {
      return
    }

    // remove existing tracking area
    if let trackingArea = trackingArea {
      removeTrackingArea(trackingArea)
    }

    // create new tracking area
    let trackingArea = NSTrackingArea(
      rect: bounds,
      options: [.activeAlways, .mouseEnteredAndExited, .enabledDuringMouseDrag],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
    self.trackingArea = trackingArea
  }

  // MARK: - Mouse Tracking

  override func mouseEntered(with event: NSEvent) {
    super.mouseEntered(with: event)
    handler?(self, .mouseEntered)
  }

  override func mouseMoved(with event: NSEvent) {
    super.mouseMoved(with: event)
    handler?(self, .mouseMoved)
  }

  override func mouseExited(with event: NSEvent) {
    super.mouseExited(with: event)
    handler?(self, .mouseExited)
  }

  // MARK: - Mouse Click/Drag

  override func mouseDown(with event: NSEvent) {
    super.mouseDown(with: event)
    handler?(self, .mouseDown)
  }

  override func mouseDragged(with event: NSEvent) {
    super.mouseDragged(with: event)
    handler?(self, .mouseDragged)
  }

  override func mouseUp(with event: NSEvent) {
    super.mouseUp(with: event)
    handler?(self, .mouseUp)
  }
}

#endif
