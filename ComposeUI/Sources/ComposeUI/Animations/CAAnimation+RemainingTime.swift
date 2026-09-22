//
//  CAAnimation+RemainingTime.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/22/26.
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

  /// The time the animation has left at a moment, in seconds of its layer's time space.
  ///
  /// A delayed animation that hasn't begun counts its remaining delay.
  /// An animation whose `beginTime` is still unset (zero) begins when the transaction commits, so it counts its full duration.
  /// A paused animation (zero speed) counts its duration however long ago it began, as it has no end to measure to.
  ///
  /// `timeOffset`, `repeatCount`, `repeatDuration` and `autoreverses` aren't accounted for.
  ///
  /// - Parameter now: The layer's current time, see `CALayer.currentTime`.
  /// - Returns: The remaining time, or `nil` when the animation has ended.
  func remainingTime(at now: TimeInterval) -> TimeInterval? {
    // a paused animation's time is frozen, so measuring its end from its begin time would count it as ended once its
    // nominal duration had passed
    guard speed > 0 else {
      return duration
    }
    let scaledDuration = duration / TimeInterval(speed)
    let remainingTime = beginTime == 0 ? scaledDuration : beginTime + scaledDuration - now
    return remainingTime > 0 ? remainingTime : nil
  }
}
