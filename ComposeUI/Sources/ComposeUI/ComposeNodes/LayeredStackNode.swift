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
    self.childNodes = content().nodes
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.zStack)

  public private(set) var size: CGSize = .zero

  public var renderableItemsBoundingRect: CGRect {
    layoutCache.itemsBoundingRect
  }

  /// The cached children layout information, used to cull invisible children in `render(visibleBounds:into:)`.
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

    // cache the children layout information for render(visibleBounds:into:)
    layoutCache.reset(reservingCapacity: childCount)

    for node in childNodes {
      let childOrigin = Layout.position(rect: node.size, in: size, alignment: alignment).origin
      let itemsBoundingRect = node.renderableItemsBoundingRect
      layoutCache.appendChild(origin: childOrigin, itemsBoundingRect: itemsBoundingRect.isNull ? itemsBoundingRect : itemsBoundingRect.translate(childOrigin))
    }

    // no main axis: children in a layered stack overlap each other, so `render(visibleBounds:into:)` checks each
    // child's bounding rect directly instead of binary searching a visible range.
    layoutCache.finish(mainAxis: nil)

    return ComposeNodeSizing(width: widthSizing, height: heightSizing)
  }

  public func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
    let childCount = childNodes.count
    guard layoutCache.childCount == childCount else {
      ComposeUI.assertFailure("render(visibleBounds:into:) requires layout(containerSize:context:) to be called first")
      return
    }

    // each visible child appends its items to the pass's array, where they're changed in place
    for i in 0 ..< childCount {
      // children in a layered stack can overlap each other, so there's no visible range to binary search.
      // instead, skip children whose items bounding rect doesn't intersect the visible bounds.
      let child = layoutCache.child(at: i)
      guard visibleBounds.intersects(child.itemsBoundingRect) else {
        continue
      }

      let boundsInChild = visibleBounds.translate(-child.origin)
      let start = items.count
      childNodes[i].render(visibleBounds: boundsInChild, into: &items)
      for index in start ..< items.count {
        items[index].id = id.join(with: items[index].id, suffix: "\(i)")
        items[index].frame = items[index].frame.translate(child.origin)
      }
    }
  }
}
