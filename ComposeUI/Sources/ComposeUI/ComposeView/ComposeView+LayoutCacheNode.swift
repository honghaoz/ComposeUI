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
  /// pass doesn't lay out the content again, caches the items of the content's nodes, and makes the view's id join
  /// cache current while it collects them.
  ///
  /// This is a reference type, so a `ComposeView` must create one root per content tree and never place it inside the
  /// content: copies of a content tree would share it and overwrite each other's layout.
  final class LayoutCacheNode: ComposeNode {

    /// The node to cache the layout result of.
    private var node: ComposeNode

    /// The cached layout result of the wrapped node, keyed by the layout inputs.
    private var cachedLayout: (containerSize: CGSize, scaleFactor: CGFloat, sizing: ComposeNodeSizing)?

    /// The cache of the items that the content's nodes build, which the root makes current while it lays out the content
    /// and collects its items.
    ///
    /// The root owns it, instead of the content evaluation, which a nested compose view also keeps: an item cached here
    /// can keep the nested view, which would keep the cache alive through the evaluation.
    private let itemCache = RenderableItemCache()

    /// The cache of the ids that the content's containers join, which the view keeps across its content trees, so that
    /// a refresh finds the ids that the last content joined.
    private let idJoinCache: ComposeNodeId.JoinCache

    /// Creates a root wrapper around the content node.
    ///
    /// - Parameters:
    ///   - node: The content node.
    ///   - idJoinCache: The view's cache of the ids that the content's containers join. A root made outside a view has a
    ///     cache of its own.
    init(node: ComposeNode, idJoinCache: ComposeNodeId.JoinCache = ComposeNodeId.JoinCache()) {
      self.node = node
      self.idJoinCache = idJoinCache
    }

    // MARK: - ComposeNode

    var id: ComposeNodeId {
      get { node.id }
      set { node.id = newValue }
    }

    var size: CGSize {
      node.size
    }

    var renderableItemsBounds: CGRect {
      node.renderableItemsBounds
    }

    func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
      // a resize that changes only a length the content's layout didn't depend on, such as the height of a list of
      // fixed rows, keeps the layout, which a layout at the new size would only repeat
      if let cachedLayout, cachedLayout.sizing.dependence.isSame(cachedLayout.containerSize, as: containerSize), cachedLayout.scaleFactor == context.scaleFactor {
        #if DEBUG && !COMPOSEUI_BENCHMARK
        if cachedLayout.containerSize != containerSize, ComposeNodeSizing.Dependence.checksKeptLayouts {
          return layoutCheckingKeptLayout(cachedLayout, containerSize: containerSize, context: context)
        }
        #endif
        return cachedLayout.sizing
      } else {
        let sizing = itemCache.performAsCurrent {
          node.layout(containerSize: containerSize, context: context)
        }
        cachedLayout = (containerSize, context.scaleFactor, sizing)
        return sizing
      }
    }

    #if DEBUG && !COMPOSEUI_BENCHMARK
    /// Lays out the content again at a container size that differs from the kept layout's only in lengths that the kept
    /// layout didn't read, and asserts that the new layout has the same sizing, size and items bounding rect, which a
    /// node's wrong dependence that changes any of them breaks.
    ///
    /// - Parameters:
    ///   - keptLayout: The cached layout, which the root would keep.
    ///   - containerSize: The container size to lay out the content in.
    ///   - context: The layout context.
    /// - Returns: The new layout's sizing.
    @inline(never)
    private func layoutCheckingKeptLayout(_ keptLayout: (containerSize: CGSize, scaleFactor: CGFloat, sizing: ComposeNodeSizing),
                                          containerSize: CGSize,
                                          context: ComposeNodeLayoutContext) -> ComposeNodeSizing
    {
      let keptSize = node.size
      let keptItemsBoundingRect = node.renderableItemsBounds

      // without a cached layout, the root lays out the content instead of returning the kept layout
      cachedLayout = nil
      let sizing = layout(containerSize: containerSize, context: context)

      ComposeUI.assert(
        sizing == keptLayout.sizing && node.size == keptSize && node.renderableItemsBounds == keptItemsBoundingRect,
        ComposeNodeSizing.Dependence.keptLayoutMismatchMessage(
          keptContainerSize: keptLayout.containerSize,
          keptSize: keptSize,
          containerSize: containerSize,
          size: node.size
        )
      )
      return sizing
    }
    #endif

    func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
      idJoinCache.performAsCurrent {
        itemCache.performAsCurrent {
          node.render(visibleBounds: visibleBounds, into: &items)
        }
      }
    }
  }
}
