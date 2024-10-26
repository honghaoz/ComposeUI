//
//  ComposeContent.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import Foundation

public protocol ComposeContent {

  func asNodes() -> [any ComposeNode]
}

public extension ComposeContent {

  /// Convert the compose content to a vertical stack node.
  /// - Parameter alignment: The alignment of the vertical stack node.
  /// - Returns: The vertical stack node.
  func asVStack(alignment: Layout.HorizontalAlignment) -> any ComposeNode {
    let nodes = asNodes()
    switch nodes.count {
    case 0:
      return SpacerNode()
    case 1:
      return nodes.first! // swiftlint:disable:this force_unwrapping
    default:
      return VerticalStackNode(alignment: alignment, content: { nodes })
    }
  }

  /// Convert the compose content to a layered stack node.
  /// - Parameter alignment: The alignment of the layered stack node.
  /// - Returns: The layered stack node.
  func asZStack(alignment: Layout.Alignment) -> any ComposeNode {
    let nodes = asNodes()
    switch nodes.count {
    case 0:
      return SpacerNode()
    case 1:
      return nodes.first! // swiftlint:disable:this force_unwrapping
    default:
      return LayeredStackNode(alignment: alignment, content: { nodes })
    }
  }
}

extension [ComposeNode]: ComposeContent {

  public func asNodes() -> [any ComposeNode] {
    self
  }
}

