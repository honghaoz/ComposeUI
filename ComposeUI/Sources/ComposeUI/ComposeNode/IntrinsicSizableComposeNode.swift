//
//  IntrinsicSizableComposeNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
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

import Foundation

/// A protocol for compose nodes whose underlying content has an intrinsic size.
///
/// This protocol allows control over the sizing behavior of nodes that have content with inherent dimensions
/// (like text, images). Nodes can either use their intrinsic content size or adapt to the container size.
public protocol IntrinsicSizableComposeNode: ComposeNode {

  /// Whether the width should use the intrinsic content width.
  ///
  /// When `true`, the node uses its content's intrinsic width.
  /// When `false`, the node adapts its width to the container width.
  var isFixedWidth: Bool { get set }

  /// Whether the height should use the intrinsic content height.
  ///
  /// When `true`, the node uses its content's intrinsic height.
  /// When `false`, the node adapts its height to the container height.
  var isFixedHeight: Bool { get set }
}

public extension IntrinsicSizableComposeNode {

  /// Configure the node to use its intrinsic content size for width and/or height.
  ///
  /// - Parameters:
  ///   - width: When `true`, use the content's intrinsic width. When `false`, adapt to container width.
  ///   - height: When `true`, use the content's intrinsic height. When `false`, adapt to container height.
  /// - Returns: A new node with the specified sizing behavior.
  func fixedSize(width: Bool = true, height: Bool = true) -> Self {
    var node = self
    node.isFixedWidth = width
    node.isFixedHeight = height
    return node
  }

  /// Configure the node to adapt to the container size for both width and height.
  ///
  /// This is equivalent to calling `fixedSize(width: false, height: false)`.
  ///
  /// - Returns: A new node with flexible width and height.
  func flexibleSize() -> Self {
    var node = self
    node.isFixedWidth = false
    node.isFixedHeight = false
    return node
  }
}
