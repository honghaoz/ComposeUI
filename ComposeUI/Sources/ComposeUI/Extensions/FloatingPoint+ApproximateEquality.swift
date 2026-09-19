//
//  FloatingPoint+ApproximateEquality.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/19/26.
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

extension FloatingPoint {

  /// Returns `true` if the value and another value are approximately equal.
  ///
  /// - Parameters:
  ///   - other: The value to compare with.
  ///   - absoluteTolerance: The largest difference that still counts as equal.
  /// - Returns: `true` if the values are equal, or differ by at most the tolerance.
  func isApproximatelyEqual(to other: Self, absoluteTolerance: Self) -> Bool {
    // the equality check keeps equal infinities equal, whose difference is not a number
    self == other || Swift.abs(self - other) <= absoluteTolerance
  }
}
