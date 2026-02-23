//
//  ContainerNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/21/25.
//

import Foundation

/// A container node that manages a list of child nodes.
public protocol ContainerNode {

  /// Applies a modifier to all children of the node.
  ///
  /// - Parameter modifier: The modifier to apply to the children.
  /// - Returns: A new container node with the modifier applied to its children.
  func mapChildren(_ modifier: (any ComposeNode) -> any ComposeNode) -> Self
}

protocol ContainerNodeInternal: ContainerNode {

  /// The list of child nodes managed by the container node.
  var childNodes: [any ComposeNode] { get set }
}

extension ContainerNodeInternal {

  public func mapChildren(_ modifier: (any ComposeNode) -> any ComposeNode) -> Self {
    var node = self
    node.childNodes = node.childNodes.map { modifier($0) }
    return node
  }
}
