//
//  HorizontalStackNode.swift
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

public typealias HStack = HorizontalStackNode
public typealias HorizontalStack = HorizontalStackNode

/// A node that stacks its children horizontally.
///
/// The node's width is the sum of its children's widths plus the spacing between them.
/// The node's height is the maximum height of its children.
public struct HorizontalStackNode: ComposeNode, ContainerNodeInternal {

  /// The latest layout's pass, container size and sizing, which a layout in the same pass at the same container size
  /// returns instead of laying out the children again.
  ///
  /// Declared first: it ends 7 bytes short of an 8-byte boundary, and the one-byte `alignment` declared after it goes
  /// into those bytes instead of taking an 8-byte slot of its own, which keeps the stack's heap box 16 bytes smaller.
  private var lastLayout: (passId: UInt64, containerSize: CGSize, sizing: ComposeNodeSizing)?

  private let alignment: Layout.VerticalAlignment
  private let spacing: CGFloat
  var childNodes: [any ComposeNode] {
    didSet {
      lastLayout = nil
    }
  }

  public init(alignment: Layout.VerticalAlignment = .center,
              spacing: CGFloat = 0,
              @ComposeContentBuilder content: () -> ComposeContent)
  {
    self.alignment = alignment
    self.spacing = spacing
    self.childNodes = content().nodes
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.hStack)

  public private(set) var size: CGSize = .zero

  public var renderableItemsBoundingRect: CGRect {
    layoutCache.itemsBoundingRect
  }

  /// The cached children layout information, used to cull invisible children in `renderableItems(in:)`.
  private var layoutCache = StackLayoutCache()

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    // a stack lays out each flexible child twice, for its sizing and at its proposed size, so without returning a layout
    // made at the same size earlier in the pass, each enclosing stack with a flexible child would double the layouts of
    // the nodes in it
    if let lastLayout, lastLayout.passId == context.passId, lastLayout.containerSize == containerSize {
      return lastLayout.sizing
    }

    guard !childNodes.isEmpty else {
      size = .zero
      layoutCache = StackLayoutCache()
      return ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
    }

    let childCount = childNodes.count

    let totalSpacing = spacing * CGFloat(childCount - 1)

    var widthSizing: ComposeNodeSizing.Sizing = .fixed(totalSpacing)
    var heightSizing: ComposeNodeSizing.Sizing = .fixed(0)

    // the children's sizings and proposed widths are needed only during this layout, so they're in temporary memory
    withUnsafeTemporaryAllocation(of: ComposeNodeSizing.Sizing.self, capacity: childCount) { childWidthSizings in
      // first pass: collect children's sizings
      for nodeIndex in 0 ..< childCount {

        // special treatment for spacer node with nil height to make it fixed with 0 height,
        // so that the spacer nodes don't expand the horizontal stack node's height.
        // the spacer is found by its type, which costs less than casting each child, and changed in place, since storing
        // a new node in the children allocates a box for it
        if type(of: childNodes[nodeIndex]) == SpacerNode.self {
          childNodes[nodeIndex].zeroHeightIfSpacerWithoutHeight()
        }

        let childSizing = childNodes[nodeIndex].layout(containerSize: containerSize, context: context)

        widthSizing = widthSizing.combine(with: childSizing.width, axis: .main)
        childWidthSizings.initializeElement(at: nodeIndex, to: childSizing.width)

        heightSizing = heightSizing.combine(with: childSizing.height, axis: .cross)
      }

      withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: childCount) { proposedWidths in
        let remainingWidth = containerSize.width - totalSpacing
        Layout.stackLayout(space: remainingWidth, items: UnsafeBufferPointer(childWidthSizings), into: proposedWidths)
        proposedWidths.round(scaleFactor: context.scaleFactor)

        // second pass: layout children with proposed widths
        for nodeIndex in 0 ..< childCount {
          switch childWidthSizings[nodeIndex] {
          case .flexible,
               .range:
            _ = childNodes[nodeIndex].layout(
              containerSize: CGSize(width: proposedWidths[nodeIndex], height: containerSize.height),
              context: context
            )
          case .fixed:
            // skips fixed width nodes as they don't need to be laid out again
            continue
          }
        }
      }

      childWidthSizings.deinitialize()
    }

    var maxHeight: CGFloat = 0
    var totalChildNodesWidth: CGFloat = 0
    for node in childNodes {
      maxHeight = max(maxHeight, node.size.height)
      totalChildNodesWidth += node.size.width
    }

    size = CGSize(width: totalChildNodesWidth + totalSpacing, height: maxHeight)

    // cache the children layout information for renderableItems(in:)
    layoutCache.reset(reservingCapacity: childCount)

    var x: CGFloat = 0
    for node in childNodes {
      let nodeSize = node.size

      let y: CGFloat
      switch alignment {
      case .center:
        y = (size.height - nodeSize.height) / 2
      case .top:
        y = 0
      case .bottom:
        y = size.height - nodeSize.height
      }

      let childOrigin = CGPoint(x: x, y: y)
      let itemsBoundingRect = node.renderableItemsBoundingRect
      layoutCache.appendChild(origin: childOrigin, itemsBoundingRect: itemsBoundingRect.isNull ? itemsBoundingRect : itemsBoundingRect.translate(childOrigin))

      x += nodeSize.width + spacing
    }

    layoutCache.finish(mainAxis: .horizontal)

    let sizing = ComposeNodeSizing(width: widthSizing, height: heightSizing)
    lastLayout = (context.passId, containerSize, sizing)
    return sizing
  }

  public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    guard layoutCache.childCount == childNodes.count else {
      ComposeUI.assertFailure("renderableItems(in:) requires layout(containerSize:context:) to be called first")
      return []
    }

    let visibleChildRange = layoutCache.visibleChildRange(minPosition: visibleBounds.minX, maxPosition: visibleBounds.maxX)

    var mappedChildItems: [RenderableItem] = []
    // typically each visible child provides at least one item, so reserving one slot per visible child
    // avoids the initial growth reallocations without over-allocating for large stacks
    mappedChildItems.reserveCapacity(visibleChildRange.count)

    for i in visibleChildRange {
      let node = childNodes[i]
      let childOrigin = layoutCache.children[i].origin
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
