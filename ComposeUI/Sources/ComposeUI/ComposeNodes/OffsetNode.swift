//
//  OffsetNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import CoreGraphics

/// A node that offsets the child node's
private struct OffsetNode<Node: ComposeNode>: ComposeNode {

  private var node: Node
  private let offset: CGPoint

  fileprivate init(node: Node, offset: CGPoint) {
    self.node = node
    self.offset = offset
  }

  // MARK: - ComposeNode

  var id: ComposeNodeId = .standard(.offset)

  var size: CGSize { node.size }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    node.layout(containerSize: containerSize, context: context)
  }

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    let boundsInChild = visibleBounds.translate(-offset)

    let childItems = node.renderableItems(in: boundsInChild)

    var mappedChildItems: [RenderableItem] = []
    mappedChildItems.reserveCapacity(childItems.count)

    for var item in childItems {
      item.id = id.join(with: item.id)
      item.frame = item.frame.translate(offset)
      mappedChildItems.append(item)
    }

    return mappedChildItems
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
