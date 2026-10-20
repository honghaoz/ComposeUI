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
///
/// It's usable from inlinable code, so that the modifiers that make it are inlinable, and an app's module knows the
/// type that they return, instead of looking up its conformance to `ComposeNode` at run time.
@usableFromInline
struct OverlayNode<Node: ComposeNode>: ComposeNode {

  private var node: Node
  private var overlayNode: any ComposeNode
  private let alignment: Layout.Alignment

  @usableFromInline
  init(node: Node, overlayNode: any ComposeNode, alignment: Layout.Alignment) {
    self.node = node
    self.overlayNode = overlayNode
    self.alignment = alignment
  }

  // MARK: - ComposeNode

  @usableFromInline
  var id: ComposeNodeId = .standard(.overlay)

  @usableFromInline
  var size: CGSize { node.size }

  @usableFromInline
  var renderableItemsBoundingRect: CGRect {
    let childRect = node.renderableItemsBoundingRect

    let overlayRect = overlayNode.renderableItemsBoundingRect
    guard !overlayRect.isNull else {
      return childRect
    }

    let overlayFrame = Layout.position(rect: overlayNode.size, in: size, alignment: alignment)
    return childRect.union(overlayRect.translate(overlayFrame.origin))
  }

  @usableFromInline
  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    let sizing = node.layout(containerSize: containerSize, context: context)
    _ = overlayNode.layout(containerSize: node.size, context: context)
    return sizing
  }

  @usableFromInline
  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
    // the child's items, and then the overlay's, are appended to the pass's array, where they're changed in place
    let start = items.count
    node.render(visibleBounds: visibleBounds, into: &items)
    for index in start ..< items.count {
      items[index].id = id.join(with: items[index].id)
    }

    let overlayFrame = Layout.position(rect: overlayNode.size, in: size, alignment: alignment)
    let boundsInOverlay = visibleBounds.translate(-overlayFrame.origin)
    let overlayStart = items.count
    overlayNode.render(visibleBounds: boundsInOverlay, into: &items)
    for index in overlayStart ..< items.count {
      items[index].id = id.join(with: items[index].id, suffix: "O")
      items[index].frame = items[index].frame.translate(overlayFrame.origin)
    }
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
  @inlinable
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
