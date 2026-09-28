//
//  CAAnimation+BeginTime.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/27/26.
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

extension CAAnimation {

  /// The begin time of an animation added at a time with a delay: the time plus the delay, where a delay of zero or less
  /// is none, as everywhere a delay is read. It is never zero.
  ///
  /// - Parameters:
  ///   - now: The time the animation is added at, in its layer's time space, see `CALayer.currentTime`.
  ///   - delay: The delay, see `AnimationTiming.delay`.
  /// - Returns: The begin time.
  static func beginTime(at now: TimeInterval, delay: TimeInterval = 0) -> TimeInterval {
    let beginTime = now + max(0, delay)
    // Core Animation takes a begin time of zero as unset and replaces it with the time of the commit, which the start of
    // a paused or offset timeline can give, so zero takes the least positive time instead, which shows the same
    return beginTime == 0 ? .leastNormalMagnitude : beginTime
  }
}
