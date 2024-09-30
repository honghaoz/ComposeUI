//
//  OverlayNode.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit

extension Compose {
  
  fileprivate struct OverlayNode<Node: ComposeNode>: ComposeNode {
    
    private var node: Node
    private var overlayNode: any ComposeNode
    private let alignment: Layout.Alignment
    
    init(node: Node,
         overlayNode: any ComposeNode,
         alignment: Layout.Alignment)
    {
      self.node = node
      self.overlayNode = overlayNode
      self.alignment = alignment
    }
    
    // MARK: - ComposeNode
    
    var size: CGSize { node.size }

    mutating func layout(containerSize: CGSize) -> ComposeNodeSizing {
      let sizing = node.layout(containerSize: containerSize)
      _ = overlayNode.layout(containerSize: node.size)
      return sizing
    }
    
    func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>] {
      let childItems = node.viewItems(in: visibleBounds).map { item in
        item.id("\(ComposeNodeId.overlay.rawValue)|\(item.id)")
      }
      
      let overlayViewFrame = Layout.position(rect: overlayNode.size, in: size, alignment: alignment)
      let boundsInOverlay = visibleBounds.translate(-overlayViewFrame.origin)
      let overlayViewItems = overlayNode.viewItems(in: boundsInOverlay).map { item in
        item
          .id("\(ComposeNodeId.overlay.rawValue)|O|\(item.id)")
          .frame(item.frame.translate(overlayViewFrame.origin))
      }
      
      return childItems + overlayViewItems
    }
  }
}

public extension ComposeNode {

  func overlay(alignment: Layout.Alignment = .center,
               @ComposeContentBuilder content: () -> ComposeContent) -> some ComposeNode
  {
    Compose.OverlayNode(
      node: self,
      overlayNode: content().asZStack(alignment: alignment),
      alignment: alignment
    )
  }
}
