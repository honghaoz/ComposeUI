//
//  KeyboardScrollAnimation+Frames.swift
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
import AppKit

@testable import ComposeUI

@available(macOS 14.0, *)
extension KeyboardScrollAnimation {

  /// The duration of a frame that the tests step the animation by, at 120 frames per second.
  static let testFrameDuration: TimeInterval = 1.0 / 120

  /// Steps the animation in frames of `testFrameDuration` after a time, until it stops, or until an end time, for up to
  /// two seconds.
  ///
  /// - Parameters:
  ///   - scrollView: The scroll view whose content the animation moves.
  ///   - startTime: The time of the frame before the first one.
  ///   - endTime: The time of the last frame, or `nil` to step until the animation stops.
  /// - Returns: The content offset of each frame.
  @discardableResult
  func stepFrames(in scrollView: ScrollView, from startTime: CFTimeInterval, until endTime: CFTimeInterval? = nil) -> [CGPoint] {
    let frameCount = Int((((endTime ?? startTime + 2) - startTime) / Self.testFrameDuration).rounded())
    var offsets: [CGPoint] = []
    var frame = 1
    while frame <= frameCount, isRunning {
      step(at: startTime + TimeInterval(frame) * Self.testFrameDuration)
      offsets.append(scrollView.contentOffset)
      frame += 1
    }
    return offsets
  }
}
#endif
