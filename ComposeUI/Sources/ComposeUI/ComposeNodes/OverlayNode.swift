//
//  OverlayNode.swift
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

import CoreGraphics

/// A node that overlays a node with another node.
private struct OverlayNode<Node: ComposeNode>: ComposeNode {

  private var node: Node
  private var overlayNode: any ComposeNode
  private let alignment: Layout.Alignment

  fileprivate init(node: Node, overlayNode: any ComposeNode, alignment: Layout.Alignment) {
    self.node = node
    self.overlayNode = overlayNode
    self.alignment = alignment
  }

  // MARK: - ComposeNode

  var id: ComposeNodeId = .standard(.overlay)

  var size: CGSize { node.size }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    let sizing = node.layout(containerSize: containerSize, context: context)
    _ = overlayNode.layout(containerSize: node.size, context: context)
    return sizing
  }

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    // for the child node
    let childItems = node.renderableItems(in: visibleBounds)

    var mappedChildItems: [RenderableItem] = []
    mappedChildItems.reserveCapacity(childItems.count)

    for var item in childItems {
      item.id = id.join(with: item.id)
      mappedChildItems.append(item)
    }

    // for the overlay node
    let overlayFrame = Layout.position(rect: overlayNode.size, in: size, alignment: alignment)
    let boundsInOverlay = visibleBounds.translate(-overlayFrame.origin)
    let overlayItems = overlayNode.renderableItems(in: boundsInOverlay)

    var mappedOverlayItems: [RenderableItem] = []
    mappedOverlayItems.reserveCapacity(overlayItems.count)

    for var item in overlayItems {
      item.id = id.join(with: item.id, suffix: "O")
      item.frame = item.frame.translate(overlayFrame.origin)
      mappedOverlayItems.append(item)
    }

    return mappedChildItems + mappedOverlayItems
  }
}

// MARK: - ComposeNode

public extension ComposeNode {

  /// Add an overlay content to the node.
  ///
  /// - Parameters:
  ///   - alignment: The alignment of the overlay content.
  ///   - content: The content to overlay.
  /// - Returns: A new node with the overlay applied.
  func overlay(alignment: Layout.Alignment = .center,
               @ComposeContentBuilder content: () -> ComposeContent) -> some ComposeNode
  {
    OverlayNode(
      node: self,
      overlayNode: content().asZStack(alignment: alignment),
      alignment: alignment
    )
  }
}
