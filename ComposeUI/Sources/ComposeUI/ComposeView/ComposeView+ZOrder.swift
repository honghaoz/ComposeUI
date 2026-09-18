//
//  ComposeView+ZOrder.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 6/12/26.
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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

extension ComposeView {

  /// The z-order maintenance strategy for a render pass.
  ///
  /// The plan maintains the view hierarchy (subview) order for view items, which drives the hit-testing order.
  /// The visual z-order across all renderables (views and layers) is driven by the renderable layers' `zPosition`,
  /// which is assigned per item in the render pass and needs no plan.
  enum ZOrderPlan {

    /// The reused items keep their relative order and need no moves.
    /// New items at the front of the z-order are placed correctly by the natural insertion order, e.g. new items revealed by scrolling down.
    /// If `needsNewItemPlacement` is true, some new items are below reused items in the z-order and need to be placed after the update pass.
    case minimal(needsNewItemPlacement: Bool)

    /// Move every view item to the front in the items order.
    case full

    /// Whether every view item needs to be moved to the front in the items order.
    var needsFullUpdate: Bool {
      switch self {
      case .minimal:
        return false
      case .full:
        return true
      }
    }
  }

  /// Computes the z-order maintenance plan for a render pass.
  ///
  /// - Parameters:
  ///   - oldIds: The renderable item ids of the previous render pass, in z-order (back to front).
  ///   - newIds: The renderable item ids of the current render pass, in z-order (back to front).
  ///   - reusingIds: The ids that are in both `oldIds` and `newIds`.
  /// - Returns: The z-order plan.
  static func makeZOrderPlan(oldIds: [ComposeNodeId], newIds: [ComposeNodeId], reusingIds: Set<ComposeNodeId>) -> ZOrderPlan {
    // when the content is unchanged, no z-order maintenance is needed.
    if newIds == oldIds {
      return .minimal(needsNewItemPlacement: false)
    }

    // `reusingIds` (items present in both the old and new render passes) are the reused items.
    // In z-order terms they stay in the hierarchy and keep their existing positions, so we never move them.
    //
    // The update pass leaves reused renderables where they already are and inserts new renderables at
    // the front (top) of the z-order. This function decides whether that is enough, or a full re-stack
    // is needed.
    //
    // Reused items are never moved in the cheap plan, so their relative order stays locked to `oldIds`.
    // Therefore:
    // - If the reused items appear in a different relative order in `newIds`, the cheap plan cannot
    //   reproduce it, so we re-stack everything -> `.full`.
    // - Otherwise the reused items are already correct. New items were stacked at the front, which is
    //   only correct for items that belong at the front. A new item that should sit *below* a reused
    //   item got placed too high and must be nudged back down afterwards -> `needsNewItemPlacement = true`.
    //
    // To compare the relative order, we walk `newIds` and match each reused id against the next reused
    // id in `oldIds` (skipping ids removed this pass). They must line up one-for-one.

    var oldIndex = 0 // cursor into `oldIds`, advanced in lockstep with the reused ids seen in `newIds`
    let oldCount = oldIds.count
    var seenNewItem = false // whether a new (not reused) item has been passed in `newIds` so far
    var needsNewItemPlacement = false // whether a new item ended up above a reused item

    for id in newIds {
      if reusingIds.contains(id) {
        // Case A: a reused item. It must match the next reused id in the old order.

        // skip over old ids that were removed this pass (not reused) to reach the next reused id.
        while oldIndex < oldCount, !reusingIds.contains(oldIds[oldIndex]) {
          oldIndex += 1
        }
        guard oldIndex < oldCount, oldIds[oldIndex] == id else {
          // mismatch: the reused items were reordered, which the cheap plan can't reproduce.
          return .full
        }
        oldIndex += 1

        if seenNewItem {
          // this reused item sits above a new item in `newIds`, but the update pass placed new items at
          // the very front, so that new item ended up too high and must be moved back down below this one.
          needsNewItemPlacement = true
        }
      } else {
        // Case B: a brand-new item. Remember it so any reused item that comes after (above) it in
        // `newIds` flags that this new item was placed too high.
        seenNewItem = true
      }
    }

    // the reused items matched their previous relative order, so the cheap plan applies.
    return .minimal(needsNewItemPlacement: needsNewItemPlacement)
  }

  /// Places the new view renderables that are not at the front of the subview order to their correct positions.
  ///
  /// The render update pass inserts new renderables at the front. For new view renderables that should be below reused
  /// view renderables, this method moves them below their next view sibling, walking the items from the front to the
  /// back so that each move's anchor is already placed correctly.
  ///
  /// Only view items are placed: the subview order drives the hit-testing order, so it is kept in sync with the items
  /// order. The visual z-order across all renderables (views and layers) is driven by the renderable layers' `zPosition`,
  /// so layer items need no placement.
  ///
  /// - Parameters:
  ///   - reusingIds: The ids of the reused renderables.
  ///   - renderableItemIds: The ids of the renderables being rendered, in z-order (back to front).
  ///   - renderableMap: The map of the renderables being rendered, keyed by id.
  func placeNewRenderables(reusingIds: Set<ComposeNodeId>, renderableItemIds: [ComposeNodeId], renderableMap: [ComposeNodeId: Renderable]) {
    let parent: View = contentView()

    // the next view sibling (already placed correctly), while walking from front to back
    var nextViewSibling: View?

    // whether a reused view item exists above the current position;
    // new items with no reused item above are already placed correctly by the natural insertion order
    var hasReusedViewAbove = false

    for id in renderableItemIds.reversed() {
      guard let view = renderableMap[id]?.view else {
        continue
      }

      if reusingIds.contains(id) {
        hasReusedViewAbove = true
      } else if hasReusedViewAbove, let sibling = nextViewSibling {
        // a positioned insertion for each move, instead of a single sort pass over the subviews, because the subview
        // list can contain views that are not part of this render pass (e.g. views with an in-flight remove transition).
        // a sort pass with a partial order can move those unmanaged views or miss moves when they interleave with the
        // managed views, while a positioned insertion only touches the moved view.
        parent.insertSubview(view, belowSubview: sibling)
      }
      nextViewSibling = view
    }
  }
}
