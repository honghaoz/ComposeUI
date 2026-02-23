//
//  CGSize+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/10/20.
//

import CoreGraphics

extension CGSize {

  /// Round the size up to the nearest value that is a multiple of the given scale factor.
  ///
  /// For example, `CGSize(width: 49.9, height: 50.0).roundedUp(scaleFactor: 2.0)` returns `CGSize(width: 50.0, height: 50.0)`.
  ///
  /// - Parameter scaleFactor: The scale factor of the screen.
  /// - Returns: The rounded size.
  func roundedUp(scaleFactor: CGFloat) -> CGSize {
    guard scaleFactor > 0 else {
      return self
    }

    let pixelWidth: CGFloat = 1 / scaleFactor
    let width = width.ceil(nearest: pixelWidth)
    let height = height.ceil(nearest: pixelWidth)
    return CGSize(width: width, height: height)
  }

  static func - (left: CGSize, right: CGSize) -> CGSize {
    CGSize(width: left.width - right.width, height: left.height - right.height)
  }
}
