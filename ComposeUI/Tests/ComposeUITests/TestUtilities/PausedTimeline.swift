//
//  PausedTimeline.swift
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

/// A layer on a paused timeline in a window, so that the layer's presentation shows the time that the timeline moves
/// to, and the animations added to the layer begin at the timeline's time.
final class PausedTimeline {

  /// The window that keeps the layers in a committed layer tree.
  let window = TestWindow()

  /// The paused layer that the layer is in.
  let timeline = CALayer()

  /// The layer.
  let layer = CALayer()

  /// Creates a layer of the frame on a timeline paused at 100.
  ///
  /// - Parameters:
  ///   - frame: The layer's frame.
  ///   - anchorPoint: The layer's anchor point.
  init(frame: CGRect, anchorPoint: CGPoint) {
    timeline.speed = 0
    timeline.timeOffset = 100
    window.layer.addSublayer(timeline)
    layer.anchorPoint = anchorPoint
    layer.frame = frame
    timeline.addSublayer(layer)
    CATransaction.flush()
  }

  /// Moves the timeline to a time, the layer's current time.
  ///
  /// - Parameter time: The time.
  func move(to time: TimeInterval) {
    timeline.timeOffset = time
  }

  /// Moves the timeline to a time and commits, so that the layer's presentation shows the time.
  ///
  /// - Parameter time: The time.
  func show(at time: TimeInterval) {
    move(to: time)
    CATransaction.flush()
  }
}
