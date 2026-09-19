//
//  CALayer+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/25/22.
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

import QuartzCore

extension CALayer {

  /// The layer's backed view if it is a backing layer for a view.
  ///
  /// On Mac, for layer-backed views, setting the layer's frame won't affect the backed view's frame.
  /// Use this property to find the backed view if you want to manipulate the view's frame.
  @inlinable
  @inline(__always)
  var backedView: View? {
    delegate as? View
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
    // a layer's `frame` is undefined under a non-identity transform, so a frame read from such a layer is meaningless
    ComposeUI.assert(CATransform3DEqualToTransform(transform, CATransform3DIdentity), "CALayer.position(from:frame:) only works with identity transform.")
    return anchoredPosition(in: frame)
  }

  /// The position the layer has when its bounds fill the frame, based on its `anchorPoint`.
  ///
  /// Unlike `position(from:)`, the frame is a layout-space target, not the layer's own frame, so the transform doesn't
  /// matter: the model `position` is the layout position the transform is applied around.
  private func anchoredPosition(in frame: CGRect) -> CGPoint {
    // `origin + anchorPoint * size` rounds twice and can differ by an ulp from Core Animation's fused result for
    // anchor points other than 0, 0.5, and 1, so a fused multiply-add is used to match it
    CGPoint(
      x: frame.origin.x.addingProduct(anchorPoint.x, frame.width),
      y: frame.origin.y.addingProduct(anchorPoint.y, frame.height)
    )
  }

  /// Whether the layer's model geometry already matches the frame, within `Constants.geometryTolerance`.
  ///
  /// - Parameter frame: The frame to compare with.
  /// - Returns: `true` if the layer's position and size match the frame's.
  func hasFrame(_ frame: CGRect) -> Bool {
    // the model `position` and `bounds.size` are compared instead of `frame`, because `frame` is derived from them and
    // does not round-trip exactly for third-pixel values (frames rounded for a 3x display), which would report an
    // unchanged frame as changed. they are also independent of the transform, so no identity precondition here.
    // the tolerance covers geometry written by other arithmetic than `anchoredPosition(in:)`, for example by AppKit
    // deriving a layer-backed view's geometry from its frame.
    let targetPosition = anchoredPosition(in: frame)
    let tolerance = Constants.geometryTolerance
    return position.x.isApproximatelyEqual(to: targetPosition.x, absoluteTolerance: tolerance)
      && position.y.isApproximatelyEqual(to: targetPosition.y, absoluteTolerance: tolerance)
      && bounds.width.isApproximatelyEqual(to: frame.width, absoluteTolerance: tolerance)
      && bounds.height.isApproximatelyEqual(to: frame.height, absoluteTolerance: tolerance)
  }

  /// Restores the layer's model transform to identity.
  func restoreIdentityTransformIfNeeded() {
    guard !CATransform3DIsIdentity(transform) else {
      return
    }
    disableActions(for: "transform") {
      transform = CATransform3DIdentity
    }
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
