//
//  PaddingNode.swift
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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import CoreGraphics

/// A node that pads the child node.
private struct PaddingNode<Node: ComposeNode>: ComposeNode {

  private var node: Node
  private let insets: EdgeInsets

  fileprivate init(node: Node, insets: EdgeInsets) {
    self.node = node
    self.insets = insets
  }

  // MARK: - ComposeNode

  var id: ComposeNodeId = .standard(.padding)

  private(set) var size: CGSize = .zero

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    let containerSize = CGSize(
      width: max(0, containerSize.width - insets.horizontal),
      height: max(0, containerSize.height - insets.vertical)
    )

    let childSizing = node.layout(containerSize: containerSize, context: context)
    size = CGSize(
      width: max(0, node.size.width + insets.horizontal),
      height: max(0, node.size.height + insets.vertical)
    )

    // padding node wraps a fixed size child node:
    // positive padding -> bigger fixed sizing
    // negative padding -> smaller fixed sizing

    // padding node wraps a flexible child node:
    // positive padding -> bigger flexible sizing
    // negative padding -> flexible sizing

    return ComposeNodeSizing(
      width: childSizing.width.combine(with: .fixed(insets.horizontal), axis: .main),
      height: childSizing.height.combine(with: .fixed(insets.vertical), axis: .main)
    )
  }

  func viewItems(in visibleBounds: CGRect) -> [ViewItem<View>] {
    let childOrigin = CGPoint(x: insets.left, y: insets.top)
    let boundsInChild = visibleBounds.translate(-childOrigin)

    let childItems = node.viewItems(in: boundsInChild)

    var mappedChildItems: [ViewItem<View>] = []
    mappedChildItems.reserveCapacity(childItems.count)

    for var item in childItems {
      item.id = id.makeViewItemId(childViewItemId: item.id)
      item.frame = item.frame.translate(childOrigin)
      mappedChildItems.append(item)
    }

    return mappedChildItems
  }
}

// MARK: - ComposeNode

public extension ComposeNode {

  /// Add padding to the node.
  ///
  /// - Parameter insets: The insets to add.
  /// - Returns: A new node with the padding applied.
  func padding(_ insets: EdgeInsets) -> some ComposeNode {
    PaddingNode(node: self, insets: insets)
  }

  /// Add padding to the node.
  ///
  /// - Parameters:
  ///   - top: The padding to add to the top.
  ///   - left: The padding to add to the left.
  ///   - bottom: The padding to add to the bottom.
  ///   - right: The padding to add to the right.
  /// - Returns: A new node with the padding applied.
  @inlinable
  @inline(__always)
  func padding(top: CGFloat = 0,
               left: CGFloat = 0,
               bottom: CGFloat = 0,
               right: CGFloat = 0) -> some ComposeNode
  {
    padding(EdgeInsets(top: top, left: left, bottom: bottom, right: right))
  }

  /// Add padding to the node.
  ///
  /// - Parameter distance: The padding to add to all edges.
  /// - Returns: A new node with the padding applied.
  @inlinable
  @inline(__always)
  func padding(_ distance: CGFloat) -> some ComposeNode {
    padding(EdgeInsets(top: distance, left: distance, bottom: distance, right: distance))
  }

  /// Add padding to the node.
  ///
  /// - Parameters:
  ///   - horizontal: The amount of padding to add to the left and right.
  ///   - vertical: The amount of padding to add to the top and bottom.
  /// - Returns: A new node with the padding applied.
  @inlinable
  @inline(__always)
  func padding(horizontal: CGFloat = 0, vertical: CGFloat = 0) -> some ComposeNode {
    padding(EdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal))
  }
}
