//
//  ContiguousArray_CGFloat+PixelRounding.swift
//  ComposéUI
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
    var sizes = self
    sizes.withUnsafeMutableBufferPointer { buffer in
      buffer.round(scaleFactor: scaleFactor)
    }
    return sizes
  }
}

extension UnsafeMutableBufferPointer where Element == CGFloat {

  /// Rounds the sizes in the buffer to the nearest pixel, in place, as `ContiguousArray<CGFloat>.rounded(scaleFactor:)`
  /// does.
  ///
  /// - Parameter scaleFactor: The screen scale factor.
  func round(scaleFactor: CGFloat) {
    guard count > 1 else {
      return
    }

    let pixelSize: CGFloat = 1 / scaleFactor

    // the last size absorbs the error the rounding accumulates, unless that makes it negative, in which case the sizes
    // stay as they are. that's known only after the last size, so a first pass finds it without writing, which would
    // lose the sizes to keep
    var totalError: CGFloat = 0.0
    var lastRoundedSize: CGFloat = 0
    for original in self {
      let correction = Self.correction(applyingTo: &totalError, pixelSize: pixelSize)
      let rounded = original.round(nearest: pixelSize)
      totalError += (rounded - original)
      lastRoundedSize = rounded + correction
    }

    if abs(totalError) > 0, lastRoundedSize - totalError < 0 {
      // the last element can't hold the error correction, so to avoid negative sizes, the sizes stay as they are
      return
    }

    // second pass: the same rounding, written in place
    totalError = 0.0
    for index in indices {
      let original = self[index]
      let correction = Self.correction(applyingTo: &totalError, pixelSize: pixelSize)
      let rounded = original.round(nearest: pixelSize)
      totalError += (rounded - original)
      self[index] = rounded + correction
    }

    if abs(totalError) > 0 {
      self[count - 1] -= totalError
    }
  }

  /// Returns the correction to apply to the next size, a pixel against the accumulated error once it reaches a pixel,
  /// and applies it to the accumulated error.
  private static func correction(applyingTo totalError: inout CGFloat, pixelSize: CGFloat) -> CGFloat {
    // if accumulative error exceeds pixel size, should apply a correction to the next item
    guard abs(totalError) >= pixelSize else {
      return 0
    }

    let correction: CGFloat = totalError > 0 ? -pixelSize : pixelSize
    totalError += correction
    return correction
  }
}
