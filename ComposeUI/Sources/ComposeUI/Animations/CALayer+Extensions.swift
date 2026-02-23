//
//  CALayer+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/25/22.
//

import UIKit
import QuartzCore

extension CALayer {

  /// The layer's backed view if it is a backing layer for a view.
  ///
  /// On Mac, for layer-backed views, setting the layer's frame won't affect the backed view's frame.
  /// Use this property to find the backed view if you want to manipulate the view's frame.
  @inlinable
  @inline(__always)
  var backedView: UIView? {
    delegate as? UIView
  }

  /// Get the layer's `position` from its `frame`, based on its `anchorPoint`.
  ///
  /// - Precondition: The layer's transform must be identity.
  ///
  /// - Parameters:
  ///   - frame: The layer's frame.
  /// - Returns: The layer's position.
  @_spi(Private)
  public func position(from frame: CGRect) -> CGPoint {
    assert(CATransform3DEqualToTransform(transform, CATransform3DIdentity), "CALayer.position(from:frame:) only works with identity transform.")
    return CGPoint(
      x: frame.origin.x + anchorPoint.x * frame.width,
      y: frame.origin.y + anchorPoint.y * frame.height
    )
  }

  /// Moves the sublayer to the front.
  ///
  /// - Parameter sublayer: The sublayer to move to the front.
  func bringSublayerToFront(_ sublayer: CALayer) {
    guard sublayer.superlayer === self else {
      return
    }

    insertSublayer(sublayer, at: UInt32(sublayers?.count ?? 0))
  }
}
