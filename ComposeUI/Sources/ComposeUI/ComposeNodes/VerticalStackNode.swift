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
public struct VerticalStackNode: ComposeNode {

  private let alignment: Layout.HorizontalAlignment
  private let spacing: CGFloat
  private var childNodes: [any ComposeNode]

  public init(alignment: Layout.HorizontalAlignment = .center,
              spacing: CGFloat = 0,
              @ComposeContentBuilder content: () -> ComposeContent)
  {
    self.alignment = alignment
    self.spacing = spacing
    self.childNodes = content().asNodes()
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.vStack)

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    guard !childNodes.isEmpty else {
      size = .zero
      return ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
    }

    let childCount = childNodes.count

    let totalSpacing = spacing * CGFloat(childCount - 1)

    var widthSizing: ComposeNodeSizing.Sizing = .fixed(0)
    var heightSizing: ComposeNodeSizing.Sizing = .fixed(totalSpacing)

    var childHeightSizings: [ComposeNodeSizing.Sizing] = []
    childHeightSizings.reserveCapacity(childCount)

    // first pass: collect children's sizings
    for nodeIndex in 0 ..< childCount {

      // special treatment for spacer node with nil width to make it fixed with 0 width,
      // so that the spacer nodes don't expand the vertical stack node's width.
      if let spacer = childNodes[nodeIndex] as? SpacerNode, spacer.width == nil {
        childNodes[nodeIndex] = spacer.width(0)
      }

      let childSizing = childNodes[nodeIndex].layout(containerSize: containerSize, context: context)

      heightSizing = heightSizing.combine(with: childSizing.height, axis: .main)
      childHeightSizings.append(childSizing.height)

      widthSizing = widthSizing.combine(with: childSizing.width, axis: .cross)
    }

    let remainingHeight = containerSize.height - totalSpacing
    let proposedHeights = Layout.stackLayout(space: remainingHeight, items: childHeightSizings)
      .rounded(scaleFactor: context.scaleFactor)

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

    var maxWidth: CGFloat = 0
    var totalChildNodesHeight: CGFloat = 0
    for node in childNodes {
      maxWidth = max(maxWidth, node.size.width)
      totalChildNodesHeight += node.size.height
    }

    size = CGSize(width: maxWidth, height: totalChildNodesHeight + totalSpacing)
    return ComposeNodeSizing(width: widthSizing, height: heightSizing)
  }

  public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    var mappedChildItems: [RenderableItem] = []
    mappedChildItems.reserveCapacity(childNodes.count * 4) // use 4x capacity as a rough estimate for the number of items

    var y: CGFloat = 0
    for i in 0 ..< childNodes.count {
      let node = childNodes[i]
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
      let boundsInChild = visibleBounds.translate(-childOrigin)

      let childItems = node.renderableItems(in: boundsInChild)
      for var item in childItems {
        item.id = id.join(with: item.id, suffix: "\(i)")
        item.frame = item.frame.translate(childOrigin)
        mappedChildItems.append(item)
      }

      y += nodeSize.height + spacing
    }

    return mappedChildItems
  }
}
