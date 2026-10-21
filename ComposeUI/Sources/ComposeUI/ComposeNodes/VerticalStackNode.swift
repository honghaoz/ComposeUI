//
//  VerticalStackNode.swift
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

public typealias VStack = VerticalStackNode
public typealias VerticalStack = VerticalStackNode

/// A node that stacks its children vertically.
///
/// The node's width is the maximum width of its children.
/// The node's height is the sum of its children's heights plus the spacing between them.
public struct VerticalStackNode: ComposeNode, ContainerNodeInternal {

  /// The latest layout's pass, container size and sizing, which a layout in the same pass at the same container size
  /// returns instead of laying out the children again.
  ///
  /// Declared first: it ends 7 bytes short of an 8-byte boundary, and the one-byte `alignment` declared after it goes
  /// into those bytes instead of taking an 8-byte slot of its own, which keeps the stack's heap box 16 bytes smaller.
  private var lastLayout: (passId: UInt64, containerSize: CGSize, sizing: ComposeNodeSizing)?

  private let alignment: Layout.HorizontalAlignment
  private let spacing: CGFloat

  /// The children, by value in one buffer.
  private var children: NodeBuffer

  public init(alignment: Layout.HorizontalAlignment = .center,
              spacing: CGFloat = 0,
              @ComposeContentBuilder content: () -> ComposeContent)
  {
    self.alignment = alignment
    self.spacing = spacing
    self.children = NodeList.buffer(of: content())
  }

  /// Creates a stack of the children in a buffer.
  init(alignment: Layout.HorizontalAlignment, spacing: CGFloat, children: NodeBuffer) {
    self.alignment = alignment
    self.spacing = spacing
    self.children = children
  }

  var childNodes: [any ComposeNode] {
    get {
      (0 ..< children.count).map { children.node(at: $0) }
    }
    set {
      children = NodeBuffer.make(newValue)
      lastLayout = nil
    }
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.vStack)

  public private(set) var size: CGSize = .zero

  public var renderableItemsBoundingRect: CGRect {
    layoutCache.itemsBoundingRect
  }

  /// The cached children layout information, used to cull invisible children in `render(visibleBounds:into:)`.
  private var layoutCache = StackLayoutCache()

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    // a stack lays out each flexible child twice, for its sizing and at its proposed size, so without returning a
    // layout made at the same size earlier in the pass, each enclosing stack with a flexible child would double the
    // layouts of the nodes in it
    if let lastLayout, lastLayout.passId == context.passId, lastLayout.containerSize == containerSize {
      return lastLayout.sizing
    }

    // the children change in place as they lay out, so a copy of the stack that shares them gets its own
    NodeBuffer.makeUnique(&children)

    guard children.count > 0 else {
      size = .zero
      layoutCache = StackLayoutCache()
      return ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
    }

    let childCount = children.count

    let totalSpacing = spacing * CGFloat(childCount - 1)

    var widthSizing: ComposeNodeSizing.Sizing = .fixed(0)
    var heightSizing: ComposeNodeSizing.Sizing = .fixed(totalSpacing)

    // the children's sizings and proposed heights are needed only during this layout, so they're in temporary memory
    withUnsafeTemporaryAllocation(of: ComposeNodeSizing.Sizing.self, capacity: childCount) { childHeightSizings in
      // first pass: collect children's sizings
      for nodeIndex in 0 ..< childCount {

        // special treatment for spacer node with nil width to make it fixed with 0 width,
        // so that the spacer nodes don't expand the vertical stack node's width.
        children.withNode(at: nodeIndex, as: SpacerNode.self) { $0.zeroWidthIfSpacerWithoutWidth() }

        let childSizing = children.layout(at: nodeIndex, containerSize: containerSize, context: context)

        heightSizing = heightSizing.combine(with: childSizing.height, axis: .main)
        childHeightSizings.initializeElement(at: nodeIndex, to: childSizing.height)

        widthSizing = widthSizing.combine(with: childSizing.width, axis: .cross)
      }

      withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: childCount) { proposedHeights in
        let remainingHeight = containerSize.height - totalSpacing
        Layout.stackLayout(space: remainingHeight, items: UnsafeBufferPointer(childHeightSizings), into: proposedHeights)
        proposedHeights.round(scaleFactor: context.scaleFactor)

        // second pass: layout children with proposed heights
        for nodeIndex in 0 ..< childCount {
          switch childHeightSizings[nodeIndex] {
          case .flexible,
               .range:
            _ = children.layout(
              at: nodeIndex,
              containerSize: CGSize(width: containerSize.width, height: proposedHeights[nodeIndex]),
              context: context
            )
          case .fixed:
            // skips fixed height nodes as they don't need to be laid out again
            continue
          }
        }
      }

      childHeightSizings.deinitialize()
    }

    var maxWidth: CGFloat = 0
    var totalChildNodesHeight: CGFloat = 0
    for index in 0 ..< childCount {
      let childSize = children.size(at: index)
      maxWidth = max(maxWidth, childSize.width)
      totalChildNodesHeight += childSize.height
    }

    size = CGSize(width: maxWidth, height: totalChildNodesHeight + totalSpacing)

    // cache the children layout information for render(visibleBounds:into:)
    layoutCache.reset(reservingCapacity: childCount)

    var y: CGFloat = 0
    for index in 0 ..< childCount {
      let nodeSize = children.size(at: index)

      let x: CGFloat
      switch alignment {
      case .center:
        x = (size.width - nodeSize.width) / 2
      case .left:
        x = 0
      case .right:
        x = size.width - nodeSize.width
      }

      let childOrigin = CGPoint(x: x, y: y)
      let itemsBoundingRect = children.renderableItemsBoundingRect(at: index)
      layoutCache.appendChild(
        origin: childOrigin,
        itemsBoundingRect: itemsBoundingRect.isNull ? itemsBoundingRect : itemsBoundingRect.translate(childOrigin)
      )

      y += nodeSize.height + spacing
    }

    layoutCache.finish(mainAxis: .vertical)

    let sizing = ComposeNodeSizing(width: widthSizing, height: heightSizing)
    lastLayout = (context.passId, containerSize, sizing)
    return sizing
  }

  public func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
    guard layoutCache.childCount == children.count else {
      ComposeUI.assertFailure("render(visibleBounds:into:) requires layout(containerSize:context:) to be called first")
      return
    }

    let visibleChildRange = layoutCache.visibleChildRange(minPosition: visibleBounds.minY, maxPosition: visibleBounds.maxY)

    // each visible child appends its items to the pass's array, where they're changed in place
    for i in visibleChildRange {
      let childOrigin = layoutCache.child(at: i).origin
      let boundsInChild = visibleBounds.translate(-childOrigin)
      let start = items.count
      children.render(at: i, visibleBounds: boundsInChild, into: &items)
      for index in start ..< items.count {
        items[index].id = id.join(with: items[index].id, suffix: "\(i)")
        items[index].frame = items[index].frame.translate(childOrigin)
      }
    }
  }
}
