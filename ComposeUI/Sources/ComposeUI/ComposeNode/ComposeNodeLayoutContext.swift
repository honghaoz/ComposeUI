//
//  ComposeNodeLayoutContext.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/16/24.
//

import CoreGraphics

/// The context for layout.
public struct ComposeNodeLayoutContext {

  /// The scale factor.
  public let scaleFactor: CGFloat

  /// Creates a `ComposeNodeLayoutContext` with the given scale factor.
  ///
  /// - Parameter scaleFactor: The scale factor.
  public init(scaleFactor: CGFloat) {
    self.scaleFactor = scaleFactor
  }
}
