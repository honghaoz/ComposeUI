//
//  LayoutCacheNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
//  Copyright © 2024 Honghao Zhang.
//
//  MIT License
//
//  Copyright (c) 2024 Honghao Zhang (github.com/honghaoz)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

/// A wrapper node that caches the layout result of another node.
///
/// This node is useful when you want to cache the layout result of a node so that
/// duplicated layouts are avoided.
///
/// For example, fixed sized `TextNode` is expensive in layout because it
/// needs to calculate the intrinsic text size. If you want to cache the layout
/// result of `TextNode`, you can use `LayoutCacheNode` to wrap it. So that the for
/// the layout with the same container size, the layout result is cached and reused.
public final class LayoutCacheNode: ComposeNode {

  /// The node to cache the layout result of.
  private var node: ComposeNode

  /// The cached layout result of the wrapped node.
  private var cachedLayout: (containerSize: CGSize, sizing: ComposeNodeSizing)?

  public init(node: ComposeNode) {
    self.node = node
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId {
    get { node.id }
    set { node.id = newValue }
  }

  public var size: CGSize {
    node.size
  }

  public func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    if let cachedLayout, cachedLayout.containerSize == containerSize {
      // layout size is the same, reuse the cached layout result
      return cachedLayout.sizing
    } else {
      // layout size is different, layout the wrapped node and cache the result
      let sizing = node.layout(containerSize: containerSize, context: context)
      cachedLayout = (containerSize, sizing)
      return sizing
    }
  }

  public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    node.renderableItems(in: visibleBounds)
  }
}
