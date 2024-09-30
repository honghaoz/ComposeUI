//
//  ComposeContentView+ContentNode.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit

extension ComposeContentView {

  /// A wrapper node used in `ComposeContentView` to cache the layout result of the wrapped node.
  final class ContentNode: ComposeNode {

    /// The wrapped node.
    private var node: (any ComposeNode)

    /// The cached layout result of the wrapped node.
    private var cachedLayout: (layoutSize: CGSize, ComposeNodeSizing: ComposeNodeSizing)?

    init(node: any ComposeNode) {
      self.node = node
    }

    // MARK: - ComposeNode

    var size: CGSize {
      node.size
    }

    func layout(containerSize: CGSize) -> ComposeNodeSizing {
      if let cachedLayout, cachedLayout.layoutSize == containerSize {
        // layout size is the same, reuse the cached layout result
        return cachedLayout.ComposeNodeSizing
      } else {
        // layout size is different, layout the wrapped node and cache the result
        let ComposeNodeSizing = node.layout(containerSize: containerSize)
        cachedLayout = (node.size, ComposeNodeSizing)
        return ComposeNodeSizing
      }
    }

    func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>] {
      node.viewItems(in: visibleBounds)
    }
  }
}
