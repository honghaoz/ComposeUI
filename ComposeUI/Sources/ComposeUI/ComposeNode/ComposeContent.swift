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

  func asVStack(alignment: Layout.HorizontalAlignment) -> any ComposeNode {
    let nodes = asNodes()
    switch nodes.count {
    case 0:
      return Compose.EmptyNode()
    case 1:
      return nodes.first! // swiftlint:disable:this force_unwrapping
    default:
      return Compose.VerticalStackNode(alignment: alignment, content: { nodes })
    }
  }

  func asZStack(alignment: Layout.Alignment) -> any ComposeNode {
    let nodes = asNodes()
    switch nodes.count {
    case 0:
      return Compose.EmptyNode()
    case 1:
      return nodes.first! // swiftlint:disable:this force_unwrapping
    default:
      return Compose.LayeredStackNode(alignment: alignment, content: { nodes })
    }
  }
}

extension [ComposeNode]: ComposeContent {

  public func asNodes() -> [any ComposeNode] {
    self
  }
}

