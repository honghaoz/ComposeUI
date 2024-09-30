//
//  UnderlayNode.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit

extension Compose {
  
  fileprivate struct UnderlayNode<Node: ComposeNode>: ComposeNode {

    private var node: Node
    private var underlayNode: any ComposeNode
    private let alignment: Layout.Alignment
    
    init(node: Node,
         underlayNode: any ComposeNode,
         alignment: Layout.Alignment)
    {
      self.node = node
      self.underlayNode = underlayNode
      self.alignment = alignment
    }
    
    // MARK: - ComposeNode
    
    var size: CGSize { node.size }

    mutating func layout(containerSize: CGSize) -> ComposeNodeSizing {
      let sizing = node.layout(containerSize: containerSize)
      _ = underlayNode.layout(containerSize: node.size)
      return sizing
    }
    
    func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>] {
      let childItems = node.viewItems(in: visibleBounds).map { item in
        item.id("\(ComposeNodeId.underlay.rawValue)|\(item.id)")
      }
      
      let underlayViewFrame = Layout.position(rect: underlayNode.size, in: size, alignment: alignment)
      let boundsInUnderlay = visibleBounds.translate(-underlayViewFrame.origin)
      let underlayViewItems = underlayNode.viewItems(in: boundsInUnderlay).map { item in
        item
          .id("\(ComposeNodeId.underlay.rawValue)|U|\(item.id)")
          .frame(item.frame.translate(underlayViewFrame.origin))
      }
      
      return underlayViewItems + childItems
    }
  }
}

public extension ComposeNode {

  func underlay(alignment: Layout.Alignment = .center,
               @ComposeContentBuilder content: () -> ComposeContent) -> some ComposeNode
  {
    Compose.UnderlayNode(
      node: self,
      underlayNode: content().asZStack(alignment: alignment),
      alignment: alignment
    )
  }
}
