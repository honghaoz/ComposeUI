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
  /// value at a fixed delay, it compares what it reads with this prediction for the time it read at.
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
}

/// The scalar of a number value, for `predictedValue(forKeyPath:at:scalar:)`.
func numberScalar(_ value: Any) throws -> CGFloat {
  try CGFloat((value as? NSNumber).unwrap().doubleValue)
}
