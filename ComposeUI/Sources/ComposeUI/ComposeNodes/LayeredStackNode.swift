//
//  LayeredStackNode.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit

public typealias ZStack = LayeredStackNode
public typealias LayeredStack = LayeredStackNode

public struct LayeredStackNode: ComposeNode {

  private let alignment: Layout.Alignment
  private var childNodes: [any ComposeNode]

  public init(alignment: Layout.Alignment = .center, @ComposeContentBuilder content: () -> ComposeContent) {
    self.alignment = alignment
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

    var maxWidth: CGFloat = 0
    var maxHeight: CGFloat = 0
    var widthSizing: ComposeNodeSizing.Sizing = .fixed(0)
    var heightSizing: ComposeNodeSizing.Sizing = .fixed(0)

    for nodeIndex in 0 ..< childCount {
      let childSizing = childNodes[nodeIndex].layout(containerSize: containerSize)
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
    return ComposeNodeSizing(width: widthSizing, height: heightSizing)
  }

  public func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>] {
    childNodes.enumerated().flatMap { i, node in
      let childFrame = Layout.position(rect: node.size, in: size, alignment: alignment)

      let boundsInChild = visibleBounds.translate(-childFrame.origin)

      let items = node.viewItems(in: boundsInChild)

      return items.map { item in
        item
          .id("\(ComposeNodeId.zStack.rawValue)|\(i)|\(item.id)")
          .frame(item.frame.translate(childFrame.origin))
      }
    }
  }
}
