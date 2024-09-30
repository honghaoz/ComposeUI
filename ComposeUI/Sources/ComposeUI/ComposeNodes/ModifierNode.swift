//
//  BorderNode.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit

extension Compose {
  
  fileprivate struct ModifierNode<Node: ComposeNode>: ComposeNode {

    private var node: Node

    private let modifier: (UIView) -> Void

    init(node: Node, modifier: @escaping (UIView) -> Void) {
      self.node = node
      self.modifier = modifier
    }
    
    // MARK: - ComposeNode
    
    var size: CGSize {
      node.size
    }
    
    mutating func layout(containerSize: CGSize) -> ComposeNodeSizing {
      node.layout(containerSize: containerSize)
    }
    
    func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>] {
      node.viewItems(in: visibleBounds)
        .map { $0.addsUpdate(modifier) }
    }
  }
}

public extension ComposeNode {

  func modify(with modifier: @escaping (UIView) -> Void) -> some ComposeNode {
    Compose.ModifierNode(node: self, modifier: modifier)
  }

  func border(color: UIColor, width: CGFloat) -> some ComposeNode {
    modify { view in
      view.layer.borderColor = color.cgColor
      view.layer.borderWidth = width
    }
  }

  func cornerRadius(_ radius: CGFloat) -> some ComposeNode {
    modify { view in
      view.layer.masksToBounds = true
      view.layer.cornerCurve = .continuous
      view.layer.cornerRadius = radius
    }
  }

  func shadow(color: UIColor, offset: CGSize, radius: CGFloat, opacity: Float) -> some ComposeNode {
    modify { view in
      view.layer.shadowColor = color.cgColor
      view.layer.shadowOffset = offset
      view.layer.shadowRadius = radius
      view.layer.shadowOpacity = opacity
    }
  }

  func backgroundColor(_ color: UIColor) -> some ComposeNode {
    modify { view in
      view.backgroundColor = color
    }
  }

  func alpha(_ alpha: CGFloat) -> some ComposeNode {
    modify { view in
      view.alpha = alpha
    }
  }
}
