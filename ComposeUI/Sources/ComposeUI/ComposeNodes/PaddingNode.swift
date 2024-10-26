//
//  PaddingNode.swift
//  ComposeUI
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

import UIKit

/// A node that pads the child node.
private struct PaddingNode<Node: ComposeNode>: ComposeNode {

  private var node: Node
  private let insets: UIEdgeInsets

  fileprivate init(node: Node, insets: UIEdgeInsets) {
    self.node = node
    self.insets = insets
  }

  // MARK: - ComposeNode

  private(set) var size: CGSize = .zero

  mutating func layout(containerSize: CGSize) -> ComposeNodeSizing {
    let containerSize = CGSize(
      width: max(0, containerSize.width - insets.horizontal),
      height: max(0, containerSize.height - insets.vertical)
    )

    let childSizing = node.layout(containerSize: containerSize)
    size = CGSize(
      width: node.size.width + insets.horizontal,
      height: node.size.height + insets.vertical
    )

    return ComposeNodeSizing(
      width: childSizing.width.combine(with: .fixed(insets.horizontal), axis: .main),
      height: childSizing.height.combine(with: .fixed(insets.vertical), axis: .main)
    )
  }

  func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>] {
    let childOrigin = CGPoint(x: insets.left, y: insets.top)

    let boundsInChild = visibleBounds.translate(-childOrigin)

    return node.viewItems(in: boundsInChild)
      .map { item in
        item
          .id("\(ComposeNodeId.padding.rawValue)|\(item.id)")
          .frame(item.frame.translate(childOrigin))
      }
  }
}

// MARK: - ComposeNode

public extension ComposeNode {

  /// Add padding to the node.
  ///
  /// - Parameter insets: The insets to add.
  /// - Returns: A new node with the padding applied.
  func padding(_ insets: UIEdgeInsets) -> some ComposeNode {
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
  func padding(top: CGFloat = 0,
               left: CGFloat = 0,
               bottom: CGFloat = 0,
               right: CGFloat = 0) -> some ComposeNode
  {
    padding(UIEdgeInsets(top: top, left: left, bottom: bottom, right: right))
  }

  /// Add padding to the node.
  ///
  /// - Parameter amount: The amount of padding to add to all edges.
  /// - Returns: A new node with the padding applied.
  func padding(_ amount: CGFloat) -> some ComposeNode {
    padding(UIEdgeInsets(top: amount, left: amount, bottom: amount, right: amount))
  }

  /// Add padding to the node.
  ///
  /// - Parameters:
  ///   - horizontal: The amount of padding to add to the left and right.
  ///   - vertical: The amount of padding to add to the top and bottom.
  /// - Returns: A new node with the padding applied.
  func padding(horizontal: CGFloat = 0, vertical: CGFloat = 0) -> some ComposeNode {
    padding(UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal))
  }
}
