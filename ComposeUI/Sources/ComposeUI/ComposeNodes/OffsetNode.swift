//
//  OffsetNode.swift
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

/// A node that offsets the child node's
private struct OffsetNode<Node: ComposeNode>: ComposeNode {

  private var node: Node
  private let offset: CGPoint

  fileprivate init(node: Node, offset: CGPoint) {
    self.node = node
    self.offset = offset
  }

  // MARK: - ComposeNode

  var size: CGSize { node.size }

  mutating func layout(containerSize: CGSize) -> ComposeNodeSizing {
    node.layout(containerSize: containerSize)
  }

  func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>] {
    let boundsInChild = visibleBounds.translate(-offset)

    return node.viewItems(in: boundsInChild)
      .map { item in
        item
          .id("\(ComposeNodeId.offset.rawValue)|\(item.id)")
          .frame(item.frame.translate(offset))
      }
  }
}

// MARK: - ComposeNode

public extension ComposeNode {

  /// Apply an offset to the node.
  ///
  /// - Parameter offset: The amount to offset the node by.
  /// - Returns: A new node with the offset applied.
  func offset(_ offset: CGPoint) -> some ComposeNode {
    OffsetNode(node: self, offset: offset)
  }

  /// Apply an offset to the node.
  ///
  /// - Parameters:
  ///   - x: The amount to offset the node by on the x-axis.
  ///   - y: The amount to offset the node by on the y-axis.
  /// - Returns: A new node with the offset applied.
  @inlinable
  @inline(__always)
  func offset(x: CGFloat = 0, y: CGFloat = 0) -> some ComposeNode {
    offset(CGPoint(x: x, y: y))
  }
}
