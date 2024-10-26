//
//  VerticalStackNode.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit

public typealias VStack = VerticalStackNode
public typealias VerticalStack = VerticalStackNode

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

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize) -> ComposeNodeSizing {
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

      let childSizing = childNodes[nodeIndex].layout(containerSize: containerSize)

      heightSizing = heightSizing.combine(with: childSizing.height, axis: .main)
      childHeightSizings.append(childSizing.height)

      widthSizing = widthSizing.combine(with: childSizing.width, axis: .cross)
    }

    let remainingHeight = containerSize.height - totalSpacing
    let proposedHeights = Layout.stackLayout(space: remainingHeight, children: childHeightSizings)

    // second pass: layout children with proposed heights
    for nodeIndex in 0 ..< childCount {
      switch childHeightSizings[nodeIndex] {
      case .flexible, .range:
        _ = childNodes[nodeIndex].layout(containerSize: CGSize(width: containerSize.width, height: proposedHeights[nodeIndex]))
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

  public func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>] {
    var y: CGFloat = 0
    return childNodes.enumerated().flatMap { i, node in
      defer {
        y += node.size.height + spacing
      }

      let x: CGFloat
      switch alignment {
      case .center:
        x = (size.width - node.size.width) / 2
      case .left:
        x = 0
      case .right:
        x = size.width - node.size.width
      }

      let childOrigin = CGPoint(x: x, y: y)
      let boundsInChild = visibleBounds.translate(-childOrigin)

      let items = node.viewItems(in: boundsInChild)

      return items.map { item in
        item
          .id("\(ComposeNodeId.vStack.rawValue)|\(i)|\(item.id)")
          .frame(item.frame.translate(childOrigin))
      }
    }
  }
}
