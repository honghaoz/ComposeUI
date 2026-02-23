//
//  EmptyNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import CoreGraphics

public typealias Empty = EmptyNode

/// A node that renders nothing.
///
/// The node has a flexible size.
public struct EmptyNode: ComposeNode {

  /// Initialize an empty node.
  public init() {}

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.empty)

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    size = containerSize
    return ComposeNodeSizing(width: .flexible, height: .flexible)
  }

  public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    return []
  }
}
