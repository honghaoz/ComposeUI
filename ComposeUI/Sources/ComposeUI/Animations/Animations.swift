//
//  Animations.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/23/21.
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

import Foundation
import QuartzCore

public enum Animations {

  /// Default animation duration.
  public static let defaultAnimationDuration: TimeInterval = 0.3

  /// Default spring animation damping ratio.
  public static let defaultSpringDampingRatio: CGFloat = 0.9

  /// Default spring animation response.
  public static let defaultSpringResponse: CGFloat = 0.5

  /// The frame rate range that ComposeUI's animations ask Core Animation for.
  ///
  /// Defaults to 80 to 120 Hz, preferring 120 Hz, the range that Apple suggests for high-impact animations. Set it to
  /// `.default` to leave the rate to Core Animation, or to a lower range to save power. A change applies to the
  /// animations made after it. Set it on the main thread, where ComposeUI makes its animations.
  ///
  /// An iPhone app needs `CADisableMinimumFrameDurationOnPhone: YES` in its information property list to go above 60 Hz.
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, *)
  public static var preferredFrameRateRange: CAFrameRateRange {
    get {
      storedPreferredFrameRateRange
    }
    set {
      ComposeUI.assert(Thread.isMain, "preferredFrameRateRange must be set on the main thread")
      storedPreferredFrameRateRange = newValue
    }
  }

  /// The storage of `preferredFrameRateRange`, which the main thread reads and writes.
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, *)
  @exclusivity(unchecked)
  private nonisolated(unsafe) static var storedPreferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
}
