//
//  CALayer+PredictedValue.swift
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

import ChouTiTest

@testable import ComposeUI

extension CALayer {

  /// The value a key path shows at a time according to the layer's animations of it: the model value plus each additive
  /// animation's value, or the last non-additive animation's value.
  ///
  /// A hosted test can't control when the run loop lets it read the presentation layer, so instead of expecting a
  /// value at a fixed delay, it compares what it reads with this prediction for the times around the read, see
  /// `readPresentation(_:)`.
  ///
  /// - Parameters:
  ///   - keyPath: The animated key path.
  ///   - time: The time in the layer's time space, see `currentTime`.
  ///   - scalar: The scalar to compare a value of the key path by, for example a color's blue component.
  /// - Returns: The predicted scalar.
  func predictedValue(forKeyPath keyPath: String, at time: TimeInterval, scalar: (Any) throws -> CGFloat) throws -> CGFloat {
    var predicted = try scalar(value(forKeyPath: keyPath).unwrap())
    for key in animationKeys() ?? [] {
      guard let animation = animation(forKey: key) as? CABasicAnimation, animation.keyPath == keyPath else {
        continue
      }
      let from = try scalar(animation.fromValue.unwrap())
      let to = try scalar(animation.toValue.unwrap())
      // an unset begin time resolves to the next commit, so the animation is evaluated from its start
      let elapsed = animation.beginTime == 0 ? 0 : (time - animation.beginTime) * TimeInterval(animation.speed)
      let animated = from + (to - from) * CGFloat(animation.progress(forElapsedTime: elapsed))
      predicted = animation.isAdditive ? predicted + animated : animated
    }
    return predicted
  }

  /// Reads values from the presentation layer, with the times just before and after the read.
  ///
  /// The main thread can stall for tens of milliseconds between any two reads on a loaded machine, so a time read next
  /// to a presentation read can be far from the time Core Animation evaluated the presentation layer at. The shown
  /// values lie between the predictions for the times before and after the read instead, see
  /// `expectShown(_:forKeyPath:between:scalar:within:file:line:)`. The times are read from `CACurrentMediaTime()`,
  /// since `currentTime` holds one time per run loop turn, see `AnimationClock`.
  ///
  /// - Important: Core Animation evaluates every presentation layer of a transaction at the time of the transaction's
  ///   first presentation read of a layer with animations, until it commits, so the read must be the first such read
  ///   since a run loop turn or a `CATransaction.flush()`.
  ///
  /// - Parameter read: Reads the values from the presentation layer.
  /// - Returns: The values, and the times before and after the read, in the layer's time space.
  func readPresentation<T>(_ read: (Self) throws -> T) throws -> (shown: T, times: ClosedRange<TimeInterval>) {
    let timeBefore = convertTime(CACurrentMediaTime(), from: nil)
    // Core Animation makes a presentation layer of the layer's class, which an extension of `CALayer` sees as `CALayer`
    let shown = try read(presentation().unwrap() as! Self) // swiftlint:disable:this force_cast
    let timeAfter = convertTime(CACurrentMediaTime(), from: nil)
    return (shown, timeBefore ... timeAfter)
  }

  /// Expects a value read with `readPresentation(_:)` to lie between the predictions for the times it was read between,
  /// within a tolerance.
  ///
  /// The key path's animations must move one way between the times, so the predictions for the two times bound the
  /// value.
  ///
  /// - Parameters:
  ///   - shown: The value read from the presentation layer.
  ///   - keyPath: The animated key path.
  ///   - times: The times the value was read between, see `readPresentation(_:)`.
  ///   - scalar: The scalar to compare a value of the key path by, see `predictedValue(forKeyPath:at:scalar:)`.
  ///   - tolerance: How far outside the predictions the value may be.
  func expectShown(_ shown: CGFloat,
                   forKeyPath keyPath: String,
                   between times: ClosedRange<TimeInterval>,
                   scalar: (Any) throws -> CGFloat,
                   within tolerance: CGFloat,
                   file: StaticString = #filePath,
                   line: UInt = #line) throws
  {
    let earlier = try predictedValue(forKeyPath: keyPath, at: times.lowerBound, scalar: scalar)
    let later = try predictedValue(forKeyPath: keyPath, at: times.upperBound, scalar: scalar)
    let description = "\(keyPath), predicted \(earlier) to \(later)"
    expect(shown, description, file: file, line: line) >= min(earlier, later) - tolerance
    expect(shown, description, file: file, line: line) <= max(earlier, later) + tolerance
  }
}
