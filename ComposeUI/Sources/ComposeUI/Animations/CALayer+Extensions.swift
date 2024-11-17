//
//  CALayer+Extensions.swift
//  ComposeUI
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
  func position(from frame: CGRect) -> CGPoint {
    assert(CATransform3DEqualToTransform(transform, CATransform3DIdentity), "only works with identity transform.")
    return CGPoint(
      x: frame.origin.x + anchorPoint.x * frame.width,
      y: frame.origin.y + anchorPoint.y * frame.height
    )
  }
}
