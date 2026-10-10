//
//  RenderableItemCache.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 6/14/26.
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

import CoreGraphics

/// A cache of the `RenderableItem`s that the nodes of one content tree build.
///
/// A node reuses its item across the tree's render passes through the cache, avoiding the per-pass cost of constructing
/// the typed item with its blocks and erasing it (`eraseToRenderableItem()`), which allocate. A node takes a slot in the
/// cache when it's laid out, see `ComposeNodeLayoutContext.updateRenderableItemSlot(_:)`, and looks up its item in the
/// slot when it makes its items, see `item(in:id:frame:build:)`.
///
/// The cache is the content evaluation's, so it lives as long as the tree, and the slots of all the tree's nodes share
/// it, instead of each node allocating a cache when it's made: a refresh rebuilds every node of the content, including
/// the nodes it never renders.
///
/// A slot holds a single item, keyed by the id's full configuration and the frame. While scrolling, both are stable
/// (the node tree and layout are unchanged), so the cached item is returned directly. If the configuration or frame
/// changes, the item is rebuilt. A node copied after it's laid out shares its slot with the copy, so if the two render
/// with different configurations or frames, they overwrite each other and fall back to rebuilding (still correct, but
/// without the caching benefit).
///
/// Like layout and rendering, it must be used on the main thread only.
final class RenderableItemCache {

  /// A node's place in a cache, which the node takes when it's laid out.
  struct Slot {

    /// The cache that the slot is in.
    fileprivate let cache: RenderableItemCache

    /// The slot's index in the cache's items.
    fileprivate let index: Int
  }

  /// The items of the slots, by the slots' indices, `nil` for a slot whose node hasn't built its item.
  ///
  /// It's made for all the slots taken when a node first builds its item, so that a tree that's laid out but never
  /// rendered, such as one that's only measured, doesn't allocate it. The cache manages the memory instead of keeping
  /// an array: an array's subscript setter releases the replaced item within the access to the array, where the item's
  /// deinitializer could reach the cache again, so the compiler would check every access to the array at run time.
  private var items: UnsafeMutablePointer<RenderableItem?>?

  /// The number of items in `items`.
  private var itemCount = 0

  /// The number of slots taken.
  private var slotCount = 0

  deinit {
    if let items {
      items.deinitialize(count: itemCount)
      items.deallocate()
    }
  }

  /// Returns a new slot in the cache.
  func makeSlot() -> Slot {
    let slot = Slot(cache: self, index: slotCount)
    slotCount += 1
    return slot
  }

  /// Replaces the node's slot with a new slot in the cache.
  ///
  /// It's out of line, so that a node's layout, which calls it only for a node new to the cache, keeps only the check
  /// of its slot, see `ComposeNodeLayoutContext.updateRenderableItemSlot(_:)`.
  ///
  /// - Parameter slot: The node's slot.
  @inline(never)
  fileprivate func replace(_ slot: inout Slot?) {
    slot = makeSlot()
  }

  /// Returns the item cached in the slot for the given `id` and `frame`, building and caching it on a miss.
  ///
  /// - Parameters:
  ///   - slot: The node's slot, or `nil` for a node that isn't laid out, which builds its item without caching it.
  ///   - id: The item's id.
  ///   - frame: The item's frame.
  ///   - build: Builds the item, with the given `id` and `frame`, on a miss. It is non-escaping, so it is not
  ///     heap-allocated on a hit.
  /// - Returns: The cached item on a hit, otherwise a freshly built (and now cached) item.
  static func item(in slot: Slot?, id: ComposeNodeId, frame: CGRect, build: () -> RenderableItem) -> RenderableItem {
    guard let slot else {
      return build()
    }
    return slot.cache.item(at: slot.index, id: id, frame: frame, build: build)
  }

  private func item(at index: Int, id: ComposeNodeId, frame: CGRect, build: () -> RenderableItem) -> RenderableItem {
    // compare the full configuration (id string and isFixed), not `==`: `==` ignores `isFixed`, but the built item's
    // composition in the parent's `join(with:)` depends on it, so a fixed/non-fixed change for the same string must rebuild.
    if index < itemCount, let item = items.unsafelyUnwrapped[index], item.id.isSameConfiguration(as: id), item.frame == frame {
      return item
    }

    let item = build()

    #if DEBUG
    if !item.id.isSameConfiguration(as: id) || item.frame != frame {
      Self.assertCacheableFailure()
    }
    #endif

    if index >= itemCount {
      makeItemsForAllSlots()
    }
    items.unsafelyUnwrapped[index] = item
    return item
  }

  /// Makes `items` hold an item for each slot taken, keeping the cached items.
  private func makeItemsForAllSlots() {
    let newItems = UnsafeMutablePointer<RenderableItem?>.allocate(capacity: slotCount)
    if let items {
      newItems.moveInitialize(from: items, count: itemCount)
      items.deallocate()
    }
    (newItems + itemCount).initialize(repeating: nil, count: slotCount - itemCount)
    items = newItems
    itemCount = slotCount
  }

  #if DEBUG
  /// Fails the assertion that a built item has the id and frame it's cached for, since the cache finds the item by them.
  ///
  /// The lookup compares them itself and calls this only when they differ, so that the debug builds that the
  /// benchmarks use don't keep the built item for a call on each miss, which costs about 140 instructions.
  @inline(never)
  private static func assertCacheableFailure() {
    ComposeUI.assertFailure("the built item must have the id and frame it's cached for")
  }
  #endif
}

extension ComposeNodeLayoutContext {

  /// Keeps the node's slot if it's in the item cache of the content that the context lays out, otherwise replaces it
  /// with a new slot in the cache.
  ///
  /// A node that caches its item calls this when it's laid out, see `RenderableItemCache`.
  ///
  /// - Parameter slot: The node's slot.
  func updateRenderableItemSlot(_ slot: inout RenderableItemCache.Slot?) {
    let cache = contentEvaluation.renderableItemCache
    // the slot is checked in place, so that laying out a node again in its content doesn't copy the slot, which retains
    // and releases the cache, and it's replaced out of line, so that the retain and release don't make the node's layout
    // too big to be inlined into its caller's
    switch slot {
    case .some(let currentSlot) where currentSlot.cache === cache:
      return
    case .some,
         .none:
      cache.replace(&slot)
    }
  }
}
