//
//  ComposeView+LayoutCacheNode.swift
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

extension ComposeView {

  /// The root wrapper of a content tree that skips the layout when the layout inputs are unchanged, so that a scroll
  /// pass doesn't lay out the content again.
  ///
  /// This is a reference type, so a `ComposeView` must create one root per content tree and never place it inside the
  /// content: copies of a content tree would share it and overwrite each other's layout.
  final class LayoutCacheNode: ComposeNode {

    /// The node to cache the layout result of.
    private var node: ComposeNode

    /// The cached layout result of the wrapped node, keyed by the layout inputs.
    private var cachedLayout: (containerSize: CGSize, scaleFactor: CGFloat, sizing: ComposeNodeSizing)?

    /// Creates a root wrapper around the content node.
    ///
    /// - Parameter node: The content node.
    init(node: ComposeNode) {
      self.node = node
    }

    // MARK: - ComposeNode

    var id: ComposeNodeId {
      get { node.id }
      set { node.id = newValue }
    }

    var size: CGSize {
      node.size
    }

    var renderableItemsBoundingRect: CGRect {
      node.renderableItemsBoundingRect
    }

    func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
      if let cachedLayout, cachedLayout.containerSize == containerSize, cachedLayout.scaleFactor == context.scaleFactor {
        return cachedLayout.sizing
      } else {
        let sizing = node.layout(containerSize: containerSize, context: context)
        cachedLayout = (containerSize, context.scaleFactor, sizing)
        return sizing
      }
    }

    func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
      node.renderableItems(in: visibleBounds)
    }
  }
}
