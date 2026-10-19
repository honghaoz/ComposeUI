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

  /// The z-order bookkeeping of a render pass.
  ///
  /// The renderables render in the items order, a later item above an earlier one, whatever their kind, which takes two
  /// orders:
  ///
  /// - The visual order comes from the renderable layers' `zPosition`. The views' backing layers and the layer items'
  ///   layers share the content view's sublayers, but AppKit stacks the backing layers above the other sublayers when it
  ///   displays, so the sublayer order can't keep the two kinds interleaved. A layer's `zPosition` is its item's z-index
  ///   band plus a fraction of its key, which increases in the items order (see `updateZPosition(of:zIndex:index:)`).
  /// - The hit-testing order comes from the subview order, which the pass keeps in the items order among the view items.
  ///   Layer items never hit-test.
  ///
  /// A render pass records each reused item, an item of the previous pass that it keeps, from the loop that walks the
  /// previous items in order (`recordReuse(oldIndex:newIndex:)`), finishes recording, then places each renderable in
  /// the items order.
  ///
  /// A renderable that's being removed with a transition isn't an item of the pass, so its layer keeps the key it last
  /// got, which keeps it in its place while the reused items keep their keys. When the items' keys move to the middle
  /// of their range, the pass moves the removing layers' keys by as much (`moveKeys(ofRemovingRenderables:)`).
  struct ZOrderPass {

    /// The offset of the items' keys from their indices: an item's key is its index plus 1 plus the offset.
    ///
    /// The pass shifts the previous pass's offset by how far the reused item nearest the middle moved, so that the
    /// reused items keep their keys, and their layers their `zPosition`, when they keep their places relative to that
    /// item. A scroll adds and removes items near the ends, so it changes the `zPosition` of no reused item, except one
    /// next to an item that moves in or out of a partly shown row at an end. A change of `zPosition` in a window copies
    /// the layer's properties and makes the commit copy the layer again.
    private(set) var keyOffset = 0

    /// Whether the reused items changed their order, so that every view moves to the front in the items order.
    ///
    /// Moving a view to the front costs time in proportion to its siblings, so the pass moves the views only when the
    /// reused items changed their order, such as in a refresh that reordered the content. Otherwise, the reused views
    /// stay where they are, and each new view goes below the next reused view, see `insert(_:at:into:ids:reusedRenderables:)`.
    private(set) var restacksViews = false

    /// The index of the reused item nearest the middle of the previous items.
    private let oldMiddleIndex: Int

    /// The key offset of the previous render pass, whose keys the layers of the items that this pass removes still have.
    private let previousKeyOffset: Int

    /// How far the index of the reused item nearest the middle of the previous items moved back.
    private var keyShift: Int?

    /// How far the keys moved further than the shift, when they moved to the middle of their range, or 0.
    private var keyMove = 0

    /// The new index of the last reused item recorded, or -1 before the first.
    private var lastReusedNewIndex = -1

    /// Where the search for the next reused view stopped: the index of the item with that view, or the item count when
    /// no reused view comes after. -1 before the first search.
    private var nextReusedViewIndex = -1

    /// The next reused view, the view of the item at `nextReusedViewIndex`, or `nil` when no reused view comes after.
    private var nextReusedView: View?

    /// Creates the bookkeeping of a render pass.
    ///
    /// - Parameters:
    ///   - oldItemCount: The number of items in the previous render pass.
    ///   - previousKeyOffset: The key offset of the previous render pass.
    init(oldItemCount: Int, previousKeyOffset: Int) {
      oldMiddleIndex = oldItemCount / 2
      self.previousKeyOffset = previousKeyOffset
    }

    /// Returns the key that the item at an index of the previous render pass got, which its layer keeps when the item
    /// is removed with a transition.
    ///
    /// - Parameter oldIndex: The item's index in the previous render pass.
    func previousKey(at oldIndex: Int) -> Int {
      oldIndex + 1 + previousKeyOffset
    }

    /// Records a reused item, called in the order of the previous items.
    ///
    /// - Parameters:
    ///   - oldIndex: The item's index in the previous render pass.
    ///   - newIndex: The item's index in this render pass.
    mutating func recordReuse(oldIndex: Int, newIndex: Int) {
      // a scroll moves items in and out near the ends, so the items around the middle move together, while an end can
      // lose or gain an item in the middle of a partly shown row
      if keyShift == nil || oldIndex <= oldMiddleIndex {
        keyShift = oldIndex - newIndex
      }

      // the reused items keep their order when their new indices increase in the order of their old indices
      if newIndex <= lastReusedNewIndex {
        restacksViews = true
      }
      lastReusedNewIndex = newIndex
    }

    /// Finishes recording the reused items.
    ///
    /// - Parameter itemCount: The number of items in this render pass.
    mutating func finishRecording(itemCount: Int) {
      let shift = keyShift ?? 0
      keyOffset = Self.keyOffset(previous: previousKeyOffset, shift: shift, itemCount: itemCount)
      keyMove = keyOffset - (previousKeyOffset + shift)
    }

    /// Returns the key offset of a render pass.
    ///
    /// - Parameters:
    ///   - previous: The key offset of the previous render pass.
    ///   - shift: How far the index of the reused item nearest the middle moved back since the previous render pass,
    ///     or 0 without a reused item.
    ///   - itemCount: The number of items in the render pass.
    /// - Returns: The previous offset shifted, which keeps the reused items' keys, unless the keys, from the offset
    ///   plus 1 to the offset plus the item count, would leave the range from 1 to `Constants.maxKey`. Then the keys
    ///   move to the middle of the range, which leaves room for later items at either end.
    static func keyOffset(previous: Int, shift: Int, itemCount: Int) -> Int {
      let offset = previous + shift
      if offset >= 0, offset <= Constants.maxKey - itemCount {
        return offset
      } else {
        return max(0, (Constants.maxKey - itemCount) / 2)
      }
    }

    /// Updates a renderable layer's `zPosition` to its item's z-index band plus a fraction of its key.
    ///
    /// The render pass owns the renderable layers' `zPosition`: it assigns it on every render pass and resets it when a
    /// renderable goes to the reuse pool. Use `ComposeNode.zIndex(_:)` to control the stacking instead of setting
    /// `zPosition` directly.
    ///
    /// - Parameters:
    ///   - renderable: The renderable to update.
    ///   - zIndex: The item's z-index, if any.
    ///   - index: The item's index in the render pass.
    func updateZPosition(of renderable: Renderable, zIndex: CGFloat?, index: Int) {
      setZPosition(of: renderable, zIndex: zIndex, key: index + 1 + keyOffset)
    }

    /// Moves the keys of the removing renderables' layers, and their `zPosition`, by as much as the pass moved the
    /// items' keys to the middle of their range, so that each layer keeps its place among the items.
    ///
    /// - Parameter removingRenderables: The renderables being removed.
    func moveKeys(ofRemovingRenderables removingRenderables: inout [RemovingRenderableKey: RemovingRenderable]) {
      guard keyMove != 0 else {
        return
      }

      for (key, removingRenderable) in removingRenderables {
        let zPositionKey = Self.key(removingRenderable.zPositionKey, movedBy: keyMove)
        removingRenderables[key]?.zPositionKey = zPositionKey
        setZPosition(of: removingRenderable.renderable, zIndex: removingRenderable.zIndex, key: zPositionKey)
      }
    }

    /// Returns a removing renderable's key moved by an offset.
    ///
    /// A removal that lasts while the keys drift by about half their range leaves its layer's key far from the items'
    /// keys, where a move can take it past an end of the range. The key then stops at that end, which keeps the layer
    /// in its z-index band, instead of moving it into the next band.
    ///
    /// - Parameters:
    ///   - key: The key to move.
    ///   - offset: How far the items' keys moved.
    /// - Returns: The moved key, within the range from 1 to `Constants.maxKey`.
    static func key(_ key: Int, movedBy offset: Int) -> Int {
      min(max(key + offset, 1), Constants.maxKey)
    }

    /// Sets a renderable layer's `zPosition` to a z-index band plus a fraction of a key.
    ///
    /// Both the items and the removing renderables get their `zPosition` here, so that equal keys give equal values: a
    /// removing layer that shares its key with an item then stacks by the sublayer order, as before the keys moved,
    /// instead of by a rounding difference.
    private func setZPosition(of renderable: Renderable, zIndex: CGFloat?, key: Int) {
      let fraction = CGFloat(key) * Constants.zPositionStep
      ComposeUI.assert(fraction < 1, "too many renderable items to maintain the items order within a z-index band")

      let zPosition = (zIndex ?? 0) + fraction
      let layer = renderable.layer
      guard layer.zPosition != zPosition else {
        return
      }

      layer.disableActions(for: "zPosition") {
        layer.zPosition = zPosition
      }
    }

    /// Places a new item's renderable in the content view, in the subview order of the items if it's a view.
    ///
    /// A new view goes below the next reused view in the items order, or to the front when no reused view comes after
    /// it. The reused views keep their order, so each view is in place once it's added, without another move. When
    /// the reused views restack, every view goes to the front in the items order instead.
    ///
    /// - Parameters:
    ///   - renderable: The new item's renderable, which can be in the content view already, as a view that a removal in
    ///     the pass left in place is, see `InPlaceReuse`.
    ///   - index: The item's index in the render pass.
    ///   - parent: The content view.
    ///   - ids: The ids of the render pass's items, in order.
    ///   - reusedRenderables: The reused renderables, by their items' ids.
    mutating func insert(_ renderable: Renderable, at index: Int, into parent: View, ids: [ComposeNodeId], reusedRenderables: [ComposeNodeId: Renderable]) {
      if !restacksViews, let view = renderable.view, let sibling = nextReusedView(after: index, ids: ids, reusedRenderables: reusedRenderables) {
        parent.insertSubview(view, belowSubview: sibling)
      } else {
        renderable.addToParent(parent)
      }
    }

    /// Returns the next reused view after an index in the items order, or `nil` when no reused view comes after it.
    ///
    /// The new views are added in the items order, so the search continues from the view it found for the previous new
    /// view, which looks at each item at most once in a render pass.
    private mutating func nextReusedView(after index: Int, ids: [ComposeNodeId], reusedRenderables: [ComposeNodeId: Renderable]) -> View? {
      if nextReusedViewIndex <= index {
        nextReusedViewIndex = index + 1
        nextReusedView = nil
        while nextReusedViewIndex < ids.count {
          if let view = reusedRenderables[ids[nextReusedViewIndex]]?.view {
            nextReusedView = view
            break
          }
          nextReusedViewIndex += 1
        }
      }
      return nextReusedView
    }

    // MARK: - Constants

    enum Constants {

      /// The `zPosition` step between two adjacent keys.
      static let zPositionStep: CGFloat = 1e-6

      /// The largest key, whose fraction, the key times `zPositionStep`, keeps an item within its z-index band.
      static let maxKey = 999999
    }
  }
}
