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

  private let alignment: Layout.VerticalAlignment
  private let spacing: CGFloat
  var childNodes: [any ComposeNode]

  public init(alignment: Layout.VerticalAlignment = .center,
              spacing: CGFloat = 0,
              @ComposeContentBuilder content: () -> ComposeContent)
  {
    self.alignment = alignment
    self.spacing = spacing
    self.childNodes = content().asNodes()
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.hStack)

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    guard !childNodes.isEmpty else {
      size = .zero
      return ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
    }

    let childCount = childNodes.count

    let totalSpacing = spacing * CGFloat(childCount - 1)

    var widthSizing: ComposeNodeSizing.Sizing = .fixed(totalSpacing)
    var heightSizing: ComposeNodeSizing.Sizing = .fixed(0)

    var childWidthSizings: [ComposeNodeSizing.Sizing] = []
    childWidthSizings.reserveCapacity(childCount)

    // first pass: collect children's sizings
    for nodeIndex in 0 ..< childCount {

      // special treatment for spacer node with nil height to make it fixed with 0 height,
      // so that the spacer nodes don't expand the horizontal stack node's height.
      if let spacer = childNodes[nodeIndex] as? SpacerNode, spacer.height == nil {
        childNodes[nodeIndex] = spacer.height(0)
      }

      let childSizing = childNodes[nodeIndex].layout(containerSize: containerSize, context: context)

      widthSizing = widthSizing.combine(with: childSizing.width, axis: .main)
      childWidthSizings.append(childSizing.width)

      heightSizing = heightSizing.combine(with: childSizing.height, axis: .cross)
    }

    let remainingWidth = containerSize.width - totalSpacing
    let proposedWidths = Layout.stackLayout(space: remainingWidth, items: childWidthSizings)
      .rounded(scaleFactor: context.scaleFactor)

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

    var maxHeight: CGFloat = 0
    var totalChildNodesWidth: CGFloat = 0
    for node in childNodes {
      maxHeight = max(maxHeight, node.size.height)
      totalChildNodesWidth += node.size.width
    }

    size = CGSize(width: totalChildNodesWidth + totalSpacing, height: maxHeight)
    return ComposeNodeSizing(width: widthSizing, height: heightSizing)
  }

  public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    var mappedChildItems: [RenderableItem] = []
    mappedChildItems.reserveCapacity(childNodes.count * 4) // use 4x capacity as a rough estimate for the number of items

    var x: CGFloat = 0
    for i in 0 ..< childNodes.count {
      let node = childNodes[i]
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
      let boundsInChild = visibleBounds.translate(-childOrigin)

      let childItems = node.renderableItems(in: boundsInChild)
      for var item in childItems {
        item.id = id.join(with: item.id, suffix: "\(i)")
        item.frame = item.frame.translate(childOrigin)
        mappedChildItems.append(item)
      }

      x += nodeSize.width + spacing
    }

    return mappedChildItems
  }
}
