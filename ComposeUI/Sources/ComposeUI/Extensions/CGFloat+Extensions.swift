//
//  CGFloat+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/6/21.
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
}
