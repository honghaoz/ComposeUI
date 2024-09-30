//
//  ComposeNode.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit

public protocol ComposeNode: ComposeContent {

  /// The size of the node.
  var size: CGSize { get }

  @discardableResult
  mutating func layout(containerSize: CGSize) -> ComposeNodeSizing

  func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>]
}

// MARK: - ComposeContent

extension ComposeNode {

  public func asNodes() -> [any ComposeNode] {
    [self]
  }
}
