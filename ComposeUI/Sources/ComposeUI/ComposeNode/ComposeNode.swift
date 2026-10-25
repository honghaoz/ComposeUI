//
//  ComposeNode.swift
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

/// The basic building block of ComposéUI.
public protocol ComposeNode: ComposeContent {

  /// The id of the node.
  ///
  /// The id must be unique for a node type.
  ///
  /// For your own node type, use `.custom` with a prefix to avoid conflicts.
  /// For example, if you have a `MyCustomNode`, you can use id like `.custom("com.myapp.mycustomnode", isFixed: false)`.
  ///
  /// The id is used to generate unique ids for the renderable items, which is used to diff the renderable items in the
  /// renderable hierarchy.
  var id: ComposeNodeId { get set }

  /// The size of the node.
  var size: CGSize { get }

  /// The bounding rect of all renderable items that the node can provide, in the node's coordinate space.
  ///
  /// Container nodes use this rect to skip querying child nodes that can't provide visible renderable items.
  /// For visible bounds that don't intersect this rect, `render(visibleBounds:into:)` must append nothing.
  ///
  /// The default implementation returns the node's bounds, i.e. `CGRect(origin: .zero, size: size)`.
  /// You only need to provide a custom implementation if the node can provide renderable items outside of the node's
  /// bounds, for example, if the node translates its child node's renderable items.
  ///
  /// Like `size`, this value is only valid after `layout(containerSize:context:)` is called.
  var renderableItemsBoundingRect: CGRect { get }

  /// Compute the node's layout with the given container size and layout context.
  ///
  /// A node can be laid out many times between refreshes, such as while its view resizes. Make the node's child nodes
  /// once and keep them across layouts, instead of making new ones in each layout: each built-in node made in a layout
  /// keeps its render item until the content is refreshed.
  ///
  /// Report the lengths of the container size that the layout reads in the sizing's `dependence`, including when the node
  /// returns a child's sizing, so that `ComposeView` can keep the layout when it lays out the content again at a size
  /// that differs only in the other lengths.
  ///
  /// - Parameters:
  ///   - containerSize: The proposed container size.
  ///   - context: The layout context.
  /// - Returns: The sizing information of the node.
  @discardableResult
  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing

  /// Renders the node by appending its renderable items that are visible in the given bounds to an array.
  ///
  /// A render pass collects the items of all its nodes in one array, which each node appends its items to in place,
  /// instead of making an array of its own. A node with child nodes passes the array on to them, and adjusts the items
  /// that they append, such as their frames.
  ///
  /// When the view or layer type of an item changes under the same id, `ComposeView` replaces its renderable with a new
  /// one of the new type, without the item's transitions. This works for items converted from a `ViewItem` or a
  /// `LayerItem`. A `RenderableItem` made with its own initializer records no view or layer type, so its `make` must
  /// keep returning the same type under the same id.
  ///
  /// - Parameters:
  ///   - visibleBounds: The visible bounds, in the node's coordinate space.
  ///   - items: The array to append the items to. The items already in it belong to other nodes, and must stay as they are.
  func render(visibleBounds: CGRect, into items: inout [RenderableItem])
}

// MARK: - Default Implementations

public extension ComposeNode {

  var renderableItemsBoundingRect: CGRect {
    CGRect(origin: .zero, size: size)
  }
}

// MARK: - Renderable Items

public extension ComposeNode {

  /// Returns the renderable items that are visible in the given bounds, in a new array.
  ///
  /// A node with child nodes gets their items with `render(visibleBounds:into:)` instead, which appends them to its own
  /// array without making one for each child.
  ///
  /// - Parameter visibleBounds: The visible bounds, in the node's coordinate space.
  /// - Returns: The renderable items that are visible in the given bounds.
  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    var items: [RenderableItem] = []
    render(visibleBounds: visibleBounds, into: &items)
    return items
  }
}

// MARK: - ComposeContent

public extension ComposeNode {

  /// Returns the node itself.
  func _nodes() -> [any ComposeNode] {
    [self]
  }
}

// MARK: - Id

public extension ComposeNode {

  /// Set the id of the node.
  consuming func id(_ id: String) -> Self {
    self.id(.custom(id, isFixed: false))
  }

  /// Set a fixed id of the node.
  ///
  /// The renderable items provided by this node should have the fixed id.
  consuming func fixedId(_ id: String) -> Self {
    self.id(.custom(id, isFixed: true))
  }

  private consuming func id(_ id: ComposeNodeId) -> Self {
    guard !self.id.isSameConfiguration(as: id) else {
      return consume self
    }

    self.id = id
    return consume self
  }
}
