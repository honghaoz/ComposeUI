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
  var childNodes: [any ComposeNode] {
    didSet {
      lastLayout = nil
    }
  }

  public init(alignment: Layout.HorizontalAlignment = .center,
              spacing: CGFloat = 0,
              @ComposeContentBuilder content: () -> ComposeContent)
  {
    self.alignment = alignment
    self.spacing = spacing
    self.childNodes = content().nodes
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.vStack)

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

    var widthSizing: ComposeNodeSizing.Sizing = .fixed(0)
    var heightSizing: ComposeNodeSizing.Sizing = .fixed(totalSpacing)

    // the children's sizings and proposed heights are needed only during this layout, so they're in temporary memory
    withUnsafeTemporaryAllocation(of: ComposeNodeSizing.Sizing.self, capacity: childCount) { childHeightSizings in
      // first pass: collect children's sizings
      for nodeIndex in 0 ..< childCount {

        // special treatment for spacer node with nil width to make it fixed with 0 width,
        // so that the spacer nodes don't expand the vertical stack node's width.
        // the spacer is found by its type, which costs less than casting each child, and changed in place, since storing
        // a new node in the children allocates a box for it
        if type(of: childNodes[nodeIndex]) == SpacerNode.self {
          childNodes[nodeIndex].zeroWidthIfSpacerWithoutWidth()
        }

        let childSizing = childNodes[nodeIndex].layout(containerSize: containerSize, context: context)

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
            _ = childNodes[nodeIndex].layout(
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
    for node in childNodes {
      maxWidth = max(maxWidth, node.size.width)
      totalChildNodesHeight += node.size.height
    }

    size = CGSize(width: maxWidth, height: totalChildNodesHeight + totalSpacing)

    // cache the children layout information for renderableItems(in:)
    layoutCache.reset(reservingCapacity: childCount)

    var y: CGFloat = 0
    for node in childNodes {
      let nodeSize = node.size

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
      let itemsBoundingRect = node.renderableItemsBoundingRect
      layoutCache.appendChild(origin: childOrigin, itemsBoundingRect: itemsBoundingRect.isNull ? itemsBoundingRect : itemsBoundingRect.translate(childOrigin))

      y += nodeSize.height + spacing
    }

    layoutCache.finish(mainAxis: .vertical)

    let sizing = ComposeNodeSizing(width: widthSizing, height: heightSizing)
    lastLayout = (context.passId, containerSize, sizing)
    return sizing
  }

  public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    guard layoutCache.childCount == childNodes.count else {
      ComposeUI.assertFailure("renderableItems(in:) requires layout(containerSize:context:) to be called first")
      return []
    }

    let visibleChildRange = layoutCache.visibleChildRange(minPosition: visibleBounds.minY, maxPosition: visibleBounds.maxY)

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
