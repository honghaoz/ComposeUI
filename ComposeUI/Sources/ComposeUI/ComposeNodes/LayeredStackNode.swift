//
//  LayeredStackNode.swift
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

public typealias ZStack = LayeredStackNode
public typealias LayeredStack = LayeredStackNode

/// A node that stacks its children in z-axis.
///
/// The node's size is the maximum size of its children.
public struct LayeredStackNode: ComposeNode, ContainerNodeInternal {

  private let alignment: Layout.Alignment
  var childNodes: [any ComposeNode]

  public init(alignment: Layout.Alignment = .center, @ComposeContentBuilder content: () -> ComposeContent) {
    self.alignment = alignment
    self.childNodes = content().asNodes()
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.zStack)

  public private(set) var size: CGSize = .zero

  public var renderableItemsBoundingRect: CGRect {
    layoutCache.itemsBoundingRect
  }

  /// The cached children layout information, used to cull invisible children in `renderableItems(in:)`.
  private var layoutCache = StackLayoutCache()

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    guard !childNodes.isEmpty else {
      size = .zero
      layoutCache = StackLayoutCache()
      return ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
    }

    let childCount = childNodes.count

    var maxWidth: CGFloat = 0
    var maxHeight: CGFloat = 0
    var widthSizing: ComposeNodeSizing.Sizing = .fixed(0)
    var heightSizing: ComposeNodeSizing.Sizing = .fixed(0)

    for nodeIndex in 0 ..< childCount {
      let childSizing = childNodes[nodeIndex].layout(containerSize: containerSize, context: context)
      let childSize = childNodes[nodeIndex].size

      if childSize.width > maxWidth {
        maxWidth = childSize.width
      }
      if childSize.height > maxHeight {
        maxHeight = childSize.height
      }

      widthSizing = widthSizing.combine(with: childSizing.width, axis: .cross)
      heightSizing = heightSizing.combine(with: childSizing.height, axis: .cross)
    }

    size = CGSize(width: maxWidth, height: maxHeight)

    // cache the children layout information for renderableItems(in:)
    var childOrigins = ContiguousArray<CGPoint>()
    childOrigins.reserveCapacity(childCount)
    var childItemsBoundingRects = ContiguousArray<CGRect>()
    childItemsBoundingRects.reserveCapacity(childCount)

    for node in childNodes {
      let childOrigin = Layout.position(rect: node.size, in: size, alignment: alignment).origin
      childOrigins.append(childOrigin)

      let itemsBoundingRect = node.renderableItemsBoundingRect
      childItemsBoundingRects.append(itemsBoundingRect.isNull ? itemsBoundingRect : itemsBoundingRect.translate(childOrigin))
    }

    // no main axis: children in a layered stack overlap each other, so `renderableItems(in:)` checks each child's
    // bounding rect directly instead of binary searching a visible range.
    layoutCache.update(childOrigins: childOrigins, childItemsBoundingRects: childItemsBoundingRects, mainAxis: nil)

    return ComposeNodeSizing(width: widthSizing, height: heightSizing)
  }

  public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    let childCount = childNodes.count
    guard layoutCache.childCount == childCount else {
      ComposeUI.assertFailure("renderableItems(in:) requires layout(containerSize:context:) to be called first")
      return []
    }

    var mappedChildItems: [RenderableItem] = []
    // children in a layered stack overlap each other, so typically all children are visible,
    // each providing at least one item
    mappedChildItems.reserveCapacity(childCount)

    for i in 0 ..< childCount {
      // children in a layered stack can overlap each other, so there's no visible range to binary search.
      // instead, skip children whose items bounding rect doesn't intersect the visible bounds.
      guard visibleBounds.intersects(layoutCache.childItemsBoundingRects[i]) else {
        continue
      }

      let node = childNodes[i]
      let childOrigin = layoutCache.childOrigins[i]
      let boundsInChild = visibleBounds.translate(-childOrigin)

      let childItems = node.renderableItems(in: boundsInChild)

      for var item in childItems {
        item.id = id.join(with: item.id, suffix: "\(i)")
        item.frame = item.frame.translate(childOrigin)
        mappedChildItems.append(item)
      }
    }

    return mappedChildItems
  }
}
