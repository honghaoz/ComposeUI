//
//  IntrinsicSizableComposeNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
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
