//
//  UnderlayNode.swift
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

/// A node that renders a node with an underlay node.
///
/// It's usable from inlinable code, so that the modifiers that make it are inlinable, and an app's module knows the
/// type that they return, instead of looking up its conformance to `ComposeNode` at run time.
@usableFromInline
struct UnderlayNode<Node: ComposeNode>: ComposeNode {

  private var node: Node
  private var underlayNode: any ComposeNode
  private let alignment: Layout.Alignment

  @usableFromInline
  init(node: Node,
       underlayNode: any ComposeNode,
       alignment: Layout.Alignment)
  {
    self.node = node
    self.underlayNode = underlayNode
    self.alignment = alignment
  }

  // MARK: - ComposeNode

  @usableFromInline
  var id: ComposeNodeId = .standard(.underlay)

  @usableFromInline
  var size: CGSize { node.size }

  @usableFromInline
  var renderableItemsBoundingRect: CGRect {
    let childRect = node.renderableItemsBoundingRect

    let underlayRect = underlayNode.renderableItemsBoundingRect
    guard !underlayRect.isNull else {
      return childRect
    }

    let underlayFrame = Layout.position(rect: underlayNode.size, in: size, alignment: alignment)
    return childRect.union(underlayRect.translate(underlayFrame.origin))
  }

  @usableFromInline
  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    let sizing = node.layout(containerSize: containerSize, context: context)
    _ = underlayNode.layout(containerSize: node.size, context: context)
    return sizing
  }

  @usableFromInline
  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
    // the underlay's items, and then the child's, are appended to the pass's array, where they're changed in place
    let underlayFrame = Layout.position(rect: underlayNode.size, in: size, alignment: alignment)
    let boundsInUnderlay = visibleBounds.translate(-underlayFrame.origin)
    let start = items.count
    underlayNode.render(visibleBounds: boundsInUnderlay, into: &items)
    for index in start ..< items.count {
      items[index].id = id.join(with: items[index].id, suffix: "U")
      items[index].frame = items[index].frame.translate(underlayFrame.origin)
    }

    let childStart = items.count
    node.render(visibleBounds: visibleBounds, into: &items)
    for index in childStart ..< items.count {
      items[index].id = id.join(with: items[index].id)
    }
  }
}

// MARK: - ComposeNode

public extension ComposeNode {

  /// Add an underlay content to the node.
  ///
  /// - Parameters:
  ///   - alignment: The alignment of the underlay content.
  ///   - content: The content to render beneath the node.
  /// - Returns: A new node with the underlay applied.
  @inlinable
  func underlay(alignment: Layout.Alignment = .center,
                @ComposeContentBuilder content: () -> ComposeContent) -> some ComposeNode
  {
    UnderlayNode(
      node: self,
      underlayNode: content().asZStack(alignment: alignment),
      alignment: alignment
    )
  }

  /// Add a background content to the node.
  ///
  /// - Parameters:
  ///   - alignment: The alignment of the background content.
  ///   - content: The content to render as the background.
  /// - Returns: A new node with the background applied.
  @inlinable
  @inline(__always)
  func background(alignment: Layout.Alignment = .center,
                  @ComposeContentBuilder content: () -> ComposeContent) -> some ComposeNode
  {
    underlay(alignment: alignment, content: content)
  }

  /// Add a background node to the node.
  ///
  /// - Parameters:
  ///   - alignment: The alignment of the background node.
  ///   - content: The content to render as the background.
  /// - Returns: A new node with the background applied.
  @inlinable
  @inline(__always)
  func background(alignment: Layout.Alignment = .center, _ content: ComposeContent) -> some ComposeNode {
    underlay(alignment: alignment, content: { content })
  }
}
