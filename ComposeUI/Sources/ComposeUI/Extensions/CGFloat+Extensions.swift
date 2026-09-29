//
//  CGFloat+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/6/21.
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

import CoreGraphics

extension CGFloat {

  /// Rounds the value to the nearest value based on the given nearest value.
  ///
  /// For example, `1.1.round(nearest: 0.5)` returns `1.0` and `1.4.round(nearest: 0.5)` returns `1.5`.
  ///
  /// - Parameter nearest: The nearest value, usually this is 1 divided by the scale factor of the screen.
  /// - Returns: The rounded value.
  func round(nearest: CGFloat) -> CGFloat {
    let n = 1 / nearest
    let numberToRound = self * n
    return numberToRound.rounded() / n
  }

  /// Rounds up the value to the nearest value based on the given nearest value.
  ///
  /// For example, `1.0.ceil(nearest: 0.5)` returns `1.0` and `1.1.ceil(nearest: 0.5)` returns `1.5`.
  ///
  /// - Parameter nearest: The nearest value, usually this is 1 divided by the scale factor of the screen.
  /// - Returns: The rounded value.
  func ceil(nearest: CGFloat) -> CGFloat {
    let remainder = truncatingRemainder(dividingBy: nearest)
    if abs(remainder) <= 1e-12 {
      return self
    } else {
      return self + (nearest - remainder)
    }
  }

  /// Returns whether the length extends beyond another length by more than `Constants.geometryTolerance`.
  ///
  /// Lengths computed by different arithmetic, such as a content size summed by the layout and a viewport size converted
  /// through backing coordinates, can differ by floating-point noise while describing the same geometry. Use this
  /// instead of `>` to decide whether one length overflows another, so that the noise doesn't count as an overflow.
  ///
  /// - Parameter other: The length to compare with.
  /// - Returns: `true` if the length is greater than `other` by more than the tolerance.
  func extends(beyond other: CGFloat) -> Bool {
    self - other > Constants.geometryTolerance
  }
}
