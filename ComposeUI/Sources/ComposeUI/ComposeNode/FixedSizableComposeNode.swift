//
//  FixedSizableComposeNode.swift
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

/// A node that supports fixed width and height.
public protocol FixedSizableComposeNode: ComposeNode {

  /// Whether the width is fixed. If `true`, the width of the node uses its intrinsic width.
  var isFixedWidth: Bool { get set }

  /// Whether the height is fixed. If `true`, the height of the node uses its intrinsic height.
  var isFixedHeight: Bool { get set }
}

public extension FixedSizableComposeNode {

  /// Set whether the width and height of the node are fixed.
  ///
  /// - Parameters:
  ///   - width: Whether the width is fixed.
  ///   - height: Whether the height is fixed.
  /// - Returns: A new node with the width and height set.
  func fixed(width: Bool = true, height: Bool = true) -> Self {
    var node = self
    node.isFixedWidth = width
    node.isFixedHeight = height
    return node
  }

  /// Set the node to be flexible.
  ///
  /// - Returns: A new node with the width and height set to flexible.
  func flexible() -> Self {
    var node = self
    node.isFixedWidth = false
    node.isFixedHeight = false
    return node
  }
}
