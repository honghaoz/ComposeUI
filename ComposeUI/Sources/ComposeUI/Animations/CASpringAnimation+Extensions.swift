//
//  CASpringAnimation+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/23/24.
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

extension CASpringAnimation {

  /// Get the perceptual duration.
  public func perceptualDuration() -> TimeInterval {
    duration(epsilon: 0.005) ?? {
      if #available(iOS 17.0, tvOS 17.0, macOS 14.0, *) {
        return perceptualDuration
      } else {
        return settlingDuration
      }
    }()
  }

  /// `durationForEpsilon:`
  private static let durationForEpsilonSelector = Selector(String("l}zi|qwvNwzMx{qtwvB".map { Character(UnicodeScalar($0.asciiValue! - 8)) })) // swiftlint:disable:this force_unwrapping

  func duration(epsilon: Double) -> TimeInterval? {
    let selector = Self.durationForEpsilonSelector
    guard self.responds(to: selector) else {
      return nil
    }

    typealias Method = @convention(c) (AnyObject, Selector, Double) -> Double
    let methodIMP = method(for: selector)
    let method: Method = unsafeBitCast(methodIMP, to: Method.self)
    let duration = method(self, selector, epsilon)

    return duration
  }
}
