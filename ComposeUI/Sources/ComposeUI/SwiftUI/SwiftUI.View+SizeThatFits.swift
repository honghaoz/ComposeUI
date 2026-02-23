//
//  SwiftUI.View+SizeThatFits.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/3/21.
//

import SwiftUI
import UIKit

public extension SwiftUI.View {

  /// Get a fitting size based on the proposing size.
  ///
  /// - Parameters:
  ///   - proposingSize: The proposing container size.
  /// - Returns: The fitting size of the view.
  func sizeThatFits(_ proposingSize: CGSize) -> CGSize {
    return UIHostingController(rootView: self).sizeThatFits(in: proposingSize)
  }
}
