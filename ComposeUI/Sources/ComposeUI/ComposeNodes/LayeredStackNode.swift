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

  /// The children, by value in one buffer.
  private var children: NodeBuffer

  public init(alignment: Layout.Alignment = .center, @ComposeContentBuilder content: () -> ComposeContent) {
    self.alignment = alignment
    self.children = NodeList.buffer(of: content())
  }

  /// Creates a stack of the children in a buffer.
  init(alignment: Layout.Alignment, children: NodeBuffer) {
    self.alignment = alignment
    self.children = children
  }

  var childNodes: [any ComposeNode] {
    get {
      children.nodes
    }
    set {
      children = NodeBuffer.make(newValue)
    }
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.zStack)

  public private(set) var size: CGSize = .zero

  public var renderableItemsBounds: CGRect {
    layoutCache.itemsBoundingRect
  }

  /// The cached children layout information, used to cull invisible children in `render(visibleBounds:into:)`.
  private var layoutCache = StackLayoutCache()

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    // the children change in place as they lay out, so a copy of the stack that shares them gets its own
    NodeBuffer.makeUnique(&children)

    guard children.count > 0 else {
      size = .zero
      layoutCache = StackLayoutCache()
      return ComposeNodeSizing(width: .fixed(0), height: .fixed(0), dependence: [])
    }

    let childCount = children.count

    var maxWidth: CGFloat = 0
    var maxHeight: CGFloat = 0
    var widthSizing: ComposeNodeSizing.Sizing = .fixed(0)
    var heightSizing: ComposeNodeSizing.Sizing = .fixed(0)

    // the stack passes the container size on to each child, so its layout depends on what theirs depend on
    var dependence: ComposeNodeSizing.Dependence = []

    for nodeIndex in 0 ..< childCount {
      let childSizing = children.layout(at: nodeIndex, containerSize: containerSize, context: context)
      dependence.formUnion(childSizing.dependence)
      let childSize = children.size(at: nodeIndex)

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

    for index in 0 ..< childCount {
      let childOrigin = Layout.position(rect: children.size(at: index), in: size, alignment: alignment).origin
      let itemsBoundingRect = children.renderableItemsBounds(at: index)
      layoutCache.appendChild(
        origin: childOrigin,
        itemsBoundingRect: itemsBoundingRect.isNullInline ? itemsBoundingRect : itemsBoundingRect.translate(childOrigin)
      )
    }

    // no main axis: children in a layered stack overlap each other, so `render(visibleBounds:into:)` checks each
    // child's bounding rect directly instead of binary searching a visible range.
    layoutCache.finish(mainAxis: nil)

    return ComposeNodeSizing(width: widthSizing, height: heightSizing, dependence: dependence)
  }

  public func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
    let childCount = children.count
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
      children.render(at: i, visibleBounds: boundsInChild, into: &items)
      guard items.count > start else {
        continue
      }

      // the child's items share one suffix, which is made once for the child instead of once for each item
      let suffix = "\(i)"
      for index in start ..< items.count {
        items[index].id = id.join(with: items[index].id, suffix: suffix)
        items[index].frame = items[index].frame.translate(child.origin)
      }
    }
  }
}
