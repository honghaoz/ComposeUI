//
//  ComposeView+ContentNode.swift
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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

extension ComposeView {

  /// A wrapper node used in `ComposeView` to cache the layout result of the wrapped node.
  final class ContentNode: ComposeNode {

    /// The wrapped node.
    private var node: any ComposeNode

    /// The cached layout result of the wrapped node.
    private var cachedLayout: (layoutSize: CGSize, sizing: ComposeNodeSizing)?

    init(node: any ComposeNode) {
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

    func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
      if let cachedLayout, cachedLayout.layoutSize == containerSize {
        // layout size is the same, reuse the cached layout result
        return cachedLayout.sizing
      } else {
        // layout size is different, layout the wrapped node and cache the result
        let sizing = node.layout(containerSize: containerSize, context: context)
        cachedLayout = (node.size, sizing)
        return sizing
      }
    }

    func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
      node.renderableItems(in: visibleBounds)
    }
  }
}
