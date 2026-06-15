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
  enum ZOrderPlan {

    /// The retained items keep their relative order and need no moves. New items at the front of the
    /// z-order are placed correctly by the natural insertion order, e.g. new items revealed by scrolling down.
    /// If `needsNewItemPlacement` is true, some new items are below retained items in the z-order and need to be placed after the update pass.
    case minimal(needsNewItemPlacement: Bool)

    /// Move every renderable to the front in the items order.
    case full

    /// Whether every renderable needs to be moved to the front in the items order.
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

    // `reusingIds` (items present in both the old and new render passes) are the "retained" items here.
    // In z-order terms they stay in the hierarchy and keep their existing positions, so we never move them.
    //
    // The update pass leaves retained renderables where they already are and inserts new renderables at
    // the front (top) of the z-order. This function decides whether that is enough, or a full re-stack
    // is needed.
    //
    // Retained items are never moved in the cheap plan, so their relative order stays locked to `oldIds`.
    // Therefore:
    // - If the retained items appear in a different relative order in `newIds`, the cheap plan cannot
    //   reproduce it, so we re-stack everything -> `.full`.
    // - Otherwise the retained items are already correct. New items were stacked at the front, which is
    //   only correct for items that belong at the front. A new item that should sit *below* a retained
    //   item got placed too high and must be nudged back down afterwards -> `needsNewItemPlacement = true`.
    //
    // To compare the relative order, we walk `newIds` and match each retained id against the next retained
    // id in `oldIds` (skipping ids removed this pass). They must line up one-for-one.

    var oldIndex = 0 // cursor into `oldIds`, advanced in lockstep with the retained ids seen in `newIds`
    let oldCount = oldIds.count
    var seenNewItem = false // whether a new (non-retained) item has been passed in `newIds` so far
    var needsNewItemPlacement = false // whether a new item ended up above a retained item

    for id in newIds {
      if reusingIds.contains(id) {
        // Case A: a retained item. It must match the next retained id in the old order.

        // skip over old ids that were removed this pass (not retained) to reach the next retained id.
        while oldIndex < oldCount, !reusingIds.contains(oldIds[oldIndex]) {
          oldIndex += 1
        }
        guard oldIndex < oldCount, oldIds[oldIndex] == id else {
          // mismatch: the retained items were reordered, which the cheap plan can't reproduce.
          return .full
        }
        oldIndex += 1

        if seenNewItem {
          // this retained item sits above a new item in `newIds`, but the update pass placed new items at
          // the very front, so that new item ended up too high and must be moved back down below this one.
          needsNewItemPlacement = true
        }
      } else {
        // Case B: a brand-new item. Remember it so any retained item that comes after (above) it in
        // `newIds` flags that this new item was placed too high.
        seenNewItem = true
      }
    }

    // the retained items matched their previous relative order, so the cheap plan applies.
    return .minimal(needsNewItemPlacement: needsNewItemPlacement)
  }

  /// Places the new renderables that are not at the front of the z-order to their correct positions.
  ///
  /// The render update pass inserts new renderables at the front of the z-order. For new renderables that
  /// should be below retained renderables, this method moves them below their next sibling of the same kind
  /// (view or layer), walking the items from the front to the back so that each move's anchor is already
  /// placed correctly.
  ///
  /// - Parameters:
  ///   - reusingIds: The ids of the retained renderables.
  ///   - renderableItemIds: The ids of the renderables being rendered, in z-order (back to front).
  ///   - renderableMap: The map of the renderables being rendered, keyed by id.
  func placeNewRenderables(reusingIds: Set<ComposeNodeId>, renderableItemIds: [ComposeNodeId], renderableMap: [ComposeNodeId: Renderable]) {
    let parent: View = contentView()

    // the next sibling of the same kind (already placed correctly), while walking from front to back
    var nextViewSibling: View?
    var nextLayerSibling: CALayer?

    // whether a retained item of the same kind exists above the current position;
    // new items with no retained item above are already placed correctly by the natural insertion order
    var hasRetainedViewAbove = false
    var hasRetainedLayerAbove = false

    #if canImport(AppKit)
    // on AppKit, collect the view moves and fix the subview order with a single `sortSubviews` pass
    var viewMoves: [(view: View, sibling: View)] = []
    #endif

    for id in renderableItemIds.reversed() {
      let isRetained = reusingIds.contains(id)
      switch renderableMap[id]! { // swiftlint:disable:this force_unwrapping
      case .view(let view):
        if isRetained {
          hasRetainedViewAbove = true
        } else if hasRetainedViewAbove, let sibling = nextViewSibling {
          #if canImport(AppKit)
          viewMoves.append((view: view, sibling: sibling))
          #else
          parent.insertSubview(view, belowSubview: sibling)
          #endif
        }
        nextViewSibling = view
      case .layer(let layer):
        if isRetained {
          hasRetainedLayerAbove = true
        } else if hasRetainedLayerAbove, let sibling = nextLayerSibling {
          parent.layer().insertSublayer(layer, below: sibling)
        }
        nextLayerSibling = layer
      }
    }

    #if canImport(AppKit)
    if !viewMoves.isEmpty {
      // fix the subview order with a single sort pass
      var viewOrder: [ObjectIdentifier: Int] = [:]
      viewOrder.reserveCapacity(renderableItemIds.count)
      var index = 0
      for id in renderableItemIds {
        if let view = renderableMap[id]?.view {
          viewOrder[ObjectIdentifier(view)] = index
          index += 1
        }
      }
      parent.sortSubviews(by: viewOrder)

      // fix the moved views' backing layers, which `sortSubviews` does not update.
      // keeping the backing layers in sync with the subview order also keeps AppKit's display-time
      // layer re-sync a no-op, which would otherwise place all backing layers above the layer items.
      let parentLayer = parent.layer()
      for (view, sibling) in viewMoves {
        let viewLayer = view.layer()
        let siblingLayer = sibling.layer()
        guard viewLayer.superlayer === parentLayer, siblingLayer.superlayer === parentLayer else {
          continue // the backing layers are not attached yet, AppKit attaches them at display time
        }
        parentLayer.insertSublayer(viewLayer, below: siblingLayer)
      }
    }
    #endif
  }
}
