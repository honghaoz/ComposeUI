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

  /// Get the layer's `position` for a frame, based on its `anchorPoint`.
  ///
  /// The frame is where the position and bounds size place the layer before its transform applies, so the transform
  /// doesn't matter.
  ///
  /// - Parameters:
  ///   - frame: The frame for the layer.
  /// - Returns: The layer's position.
  @_spi(Private)
  public func position(from frame: CGRect) -> CGPoint {
    anchoredPosition(in: frame)
  }

  /// The position the layer has when its bounds fill the frame, based on its `anchorPoint`.
  private func anchoredPosition(in frame: CGRect) -> CGPoint {
    // `origin + anchorPoint * size` rounds twice and can differ by an ulp from Core Animation's fused result for
    // anchor points other than 0, 0.5, and 1, so a fused multiply-add is used to match it
    let anchorPoint = self.anchorPoint
    return CGPoint(
      x: frame.origin.x.addingProduct(anchorPoint.x, frame.width),
      y: frame.origin.y.addingProduct(anchorPoint.y, frame.height)
    )
  }

  /// The frame where the layer's position and bounds size place it, before its transform applies.
  ///
  /// It's the frame that a layout gives the layer, which `frame` is too, but only under an identity transform.
  var untransformedFrame: CGRect {
    let size = bounds.size
    let position = self.position
    let anchorPoint = self.anchorPoint
    return CGRect(
      x: position.x.addingProduct(-anchorPoint.x, size.width),
      y: position.y.addingProduct(-anchorPoint.y, size.height),
      width: size.width,
      height: size.height
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
    // each read is an Objective-C call, so each property is read once, and the size goes first, so that a frame of
    // another size takes one read.
    let tolerance = Constants.geometryTolerance
    let size = bounds.size
    guard size.width.isApproximatelyEqual(to: frame.width, absoluteTolerance: tolerance),
          size.height.isApproximatelyEqual(to: frame.height, absoluteTolerance: tolerance)
    else {
      return false
    }

    let targetPosition = anchoredPosition(in: frame)
    let position = self.position
    return position.x.isApproximatelyEqual(to: targetPosition.x, absoluteTolerance: tolerance)
      && position.y.isApproximatelyEqual(to: targetPosition.y, absoluteTolerance: tolerance)
  }

  /// Restores the layer's model transform to identity, forgets the size that `updateTransform(_:anchor:animationTiming:)`
  /// remembers, and on AppKit, stops keeping the transform, see `keepTransform(_:)`.
  func restoreIdentityTransformIfNeeded() {
    guard !CATransform3DIsIdentity(transform) else {
      return
    }
    #if canImport(AppKit)
    // the transform's owner drops the transform, which a kept transform would put back
    stopKeepingTransform()
    #endif
    // what `updateTransform(_:anchor:animationTiming:)` remembers would make its next call assert on this identity
    forgetTransformSize()
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

    // `addSublayer` moves a sublayer that's in the layer already to the end, as `insertSublayer(_:at:)` at the sublayer
    // count does, without reading `sublayers` for the count, which copies the array
    addSublayer(sublayer)
  }
}
