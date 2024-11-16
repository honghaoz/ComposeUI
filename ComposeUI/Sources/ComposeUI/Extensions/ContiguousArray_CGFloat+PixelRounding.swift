//
//  ContiguousArray_CGFloat+PixelRounding.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 5/23/23.
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

extension ContiguousArray where Element == CGFloat {

  /// Rounding an array of sizes to nearest pixel.
  ///
  /// This method is useful to round frames to the nearest displayable pixel value to avoid rendering artifacts.
  ///
  /// - Parameter scaleFactor: The screen scale factor.
  /// - Returns: A corrected sizes which match the pixel boundary.
  func rounded(scaleFactor: CGFloat) -> Self {
    guard !isEmpty else {
      return self
    }

    if count == 1 {
      return self
    }

    let pixelSize: CGFloat = 1 / scaleFactor
    var roundedSizes: ContiguousArray<CGFloat> = []
    roundedSizes.reserveCapacity(count)
    var totalError: CGFloat = 0.0

    for original in self {
      // if accumulative error exceeds pixel size, should apply a correction to the next item
      let correction: CGFloat
      if abs(totalError) >= pixelSize {
        correction = totalError > 0 ? -pixelSize : pixelSize
        totalError += correction
      } else {
        correction = 0
      }

      let rounded = original.round(nearest: pixelSize)
      totalError += (rounded - original)

      roundedSizes.append(rounded + correction)
    }

    if abs(totalError) > 0 {
      roundedSizes[roundedSizes.count - 1] -= totalError
      if roundedSizes[roundedSizes.count - 1] < 0 {
        // the last element can't hold the error correction
        // to avoid return negative sizes, return self
        return self
      }
    }

    return roundedSizes
  }
}
