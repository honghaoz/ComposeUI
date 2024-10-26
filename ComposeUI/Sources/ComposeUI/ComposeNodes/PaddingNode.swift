//
//  PaddingNode.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit
  
private struct PaddingNode<Node: ComposeNode>: ComposeNode {

  private var node: Node  
  private let insets: UIEdgeInsets

  fileprivate init(node: Node, insets: UIEdgeInsets) {
    self.node = node
    self.insets = insets
  }
  
  // MARK: - ComposeNode
  
  private(set) var size: CGSize = .zero
  
  mutating func layout(containerSize: CGSize) -> ComposeNodeSizing {
    let containerSize = CGSize(
      width: max(0, containerSize.width - insets.horizontal),
      height: max(0, containerSize.height - insets.vertical)
    )
    
    let childSizing = node.layout(containerSize: containerSize)
    size = CGSize(
      width: node.size.width + insets.horizontal,
      height: node.size.height + insets.vertical
    )
    
    return ComposeNodeSizing(
      width: childSizing.width.combine(with: .fixed(insets.horizontal), axis: .main),
      height: childSizing.height.combine(with: .fixed(insets.vertical), axis: .main)
    )
  }
  
  func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>] {
    let childOrigin = CGPoint(x: insets.left, y: insets.top)
    
    let boundsInChild = visibleBounds.translate(-childOrigin)
    
    return node.viewItems(in: boundsInChild)
      .map { item in
        item
          .id("\(ComposeNodeId.padding.rawValue)|\(item.id)")
          .frame(item.frame.translate(childOrigin))
      }
  }
}

// MARK: - ComposeNode

public extension ComposeNode {

  func padding(_ insets: UIEdgeInsets) -> some ComposeNode {
    PaddingNode(node: self, insets: insets)
  }

  func padding(top: CGFloat = 0,
               left: CGFloat = 0,
               bottom: CGFloat = 0,
               right: CGFloat = 0) -> some ComposeNode
  {
    padding(UIEdgeInsets(top: top, left: left, bottom: bottom, right: right))
  }

  func padding(_ length: CGFloat) -> some ComposeNode {
    padding(UIEdgeInsets(top: length, left: length, bottom: length, right: length))
  }

  func padding(horizontal: CGFloat = 0, vertical: CGFloat = 0) -> some ComposeNode {
    padding(UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal))
  }
}
