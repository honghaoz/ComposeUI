//
//  UIEdgeInsets+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit

extension UIEdgeInsets {

  /// The horizontal insets.
  var horizontal: CGFloat { left + right }

  /// The vertical insets.
  var vertical: CGFloat { top + bottom }

  /// Creates an edge insets with the same inset for all sides.
  ///
  /// - Parameter inset: The inset for all sides.
  init(inset: CGFloat) {
    self.init(top: inset, left: inset, bottom: inset, right: inset)
  }
}
