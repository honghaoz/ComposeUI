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
/// cache when it's laid out, see `updateSlot(_:)`, and looks up its item in the slot when it makes its items, see
/// `item(in:id:frame:build:)`.
///
/// The cache is the content root's, `ComposeView.LayoutCacheNode`, which is its only owner, instead of each node
/// allocating a cache when it's made: a refresh rebuilds every node of the content, including the nodes it never
/// renders. A slot is a number instead of a reference to the cache, so the cached items, whose blocks can keep nodes,
/// never keep the cache alive. A node reaches the cache only while the root lays out the content or collects its items,
/// see `performAsCurrent(_:)`, and a node laid out or making its items at another time, or for another content, doesn't
/// cache its item.
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
  struct Slot: Equatable {

    /// The slot of a node that isn't laid out, which no cache has.
    static let unassigned = Slot(rawValue: 0)

    /// The id of the slot's cache in the high bits, and the slot's index in the cache's items in the low bits.
    fileprivate let rawValue: UInt64

    fileprivate init(rawValue: UInt64) {
      self.rawValue = rawValue
    }

    fileprivate init(cacheId: UInt64, index: Int) {
      self.rawValue = cacheId << Constants.indexBitCount | UInt64(index)
    }

    /// The id of the slot's cache.
    fileprivate var cacheId: UInt64 {
      rawValue >> Constants.indexBitCount
    }

    /// The slot's index in the cache's items.
    fileprivate var index: Int {
      Int(truncatingIfNeeded: rawValue & Constants.maximumIndex)
    }

    /// Whether the slot is in the given cache.
    ///
    /// - Parameter cache: The cache.
    /// - Returns: `true` if the slot is in the cache, otherwise `false`.
    func isIn(_ cache: RenderableItemCache) -> Bool {
      cacheId == cache.id
    }
  }

  /// The cache whose content is being laid out or whose items are being collected, see `performAsCurrent(_:)`.
  ///
  /// It's kept in memory that the cache manages instead of a static variable, every access to which the compiler
  /// checks at run time, and it doesn't retain the cache, which `performAsCurrent(_:)` keeps alive while it's set.
  private static let current: UnsafeMutablePointer<Unmanaged<RenderableItemCache>?> = {
    let pointer = UnsafeMutablePointer<Unmanaged<RenderableItemCache>?>.allocate(capacity: 1)
    pointer.initialize(to: nil)
    return pointer
  }()

  /// The id of the next cache.
  private static var nextId: UInt64 = 1

  /// The cache's id, which the slots in it have, between 1 and `Constants.maximumId`.
  ///
  /// Ids start over after the maximum, so a slot kept from the cache that many caches earlier would match, which a
  /// process doesn't reach.
  private let id: UInt64

  /// The items of the slots, by the slots' indices, `nil` for a slot whose node hasn't built its item.
  ///
  /// It's made for all the slots taken when a node first builds its item, so that a tree that's laid out but never
  /// rendered, such as one that's only measured, doesn't allocate it. The cache manages the memory instead of keeping
  /// an array: an array's subscript setter releases the replaced item within the access to the array, where the item's
  /// deinitializer could reach the cache again, so the compiler would check every access to the array at run time.
  private var items: UnsafeMutablePointer<RenderableItem?>?

  /// The number of items in `items`, including the `nil` items of slots not taken yet.
  ///
  /// It's private, with `itemCountForTesting` for tests, so that the compiler sees every access to it and doesn't check
  /// the accesses at run time.
  private var itemCount = 0

  /// The number of slots taken.
  private var slotCount = 0

  init() {
    id = Self.nextId
    Self.nextId = Self.nextId == Constants.maximumId ? 1 : Self.nextId + 1
  }

  deinit {
    if let items {
      items.deinitialize(count: itemCount)
      items.deallocate()
    }
  }

  /// Returns a new slot in the cache, or `Slot.unassigned` if the cache has no more indices, for a node that builds its
  /// item without caching it.
  func makeSlot() -> Slot {
    guard UInt64(slotCount) <= Constants.maximumIndex else {
      return .unassigned
    }

    let slot = Slot(cacheId: id, index: slotCount)
    slotCount += 1
    return slot
  }

  /// Makes the cache the one that nodes take their slots in and look up their items in while `body` runs.
  ///
  /// The content's root calls this around its calls of the content's `layout(containerSize:context:)` and
  /// `appendRenderableItems(in:to:)`, see `ComposeView.LayoutCacheNode`. It sets the cache back to the one set before,
  /// so that a root's call within another root's finds its own cache.
  ///
  /// - Parameter body: Lays out the content or collects its items.
  /// - Returns: What `body` returns.
  func performAsCurrent<Result>(_ body: () -> Result) -> Result {
    let previous = Self.current.pointee
    Self.current.pointee = Unmanaged.passUnretained(self)
    defer {
      Self.current.pointee = previous
    }
    return withExtendedLifetime(self, body)
  }

  /// Keeps the node's slot if it's in the current cache, otherwise replaces it with a new slot in the current cache.
  ///
  /// A node that caches its item calls this when it's laid out. A node laid out where no cache is current, outside a
  /// content root's layout, keeps its slot.
  ///
  /// - Parameter slot: The node's slot.
  static func updateSlot(_ slot: inout Slot) {
    guard let current = current.pointee else {
      return
    }
    // the cache is used without retaining it, since `performAsCurrent(_:)` keeps it alive
    current._withUnsafeGuaranteedRef { cache in
      if !slot.isIn(cache) {
        slot = cache.makeSlot()
      }
    }
  }

  /// Returns the item cached in the slot for the given `id` and `frame`, building and caching it on a miss.
  ///
  /// A node builds its item without caching it when its slot isn't in the current cache, such as when the node isn't
  /// laid out, it makes its items where no cache is current, or its content was replaced.
  ///
  /// - Parameters:
  ///   - slot: The node's slot.
  ///   - id: The item's id.
  ///   - frame: The item's frame.
  ///   - build: Builds the item, with the given `id` and `frame`, on a miss. It is non-escaping, so it is not
  ///     heap-allocated on a hit.
  /// - Returns: The cached item on a hit, otherwise a freshly built (and now cached) item.
  static func item(in slot: Slot, id: ComposeNodeId, frame: CGRect, build: () -> RenderableItem) -> RenderableItem {
    guard let current = current.pointee else {
      return build()
    }
    // the cache is used without retaining it, since `performAsCurrent(_:)` keeps it alive
    return current._withUnsafeGuaranteedRef { cache in
      cache.item(in: slot, id: id, frame: frame, build: build)
    }
  }

  private func item(in slot: Slot, id: ComposeNodeId, frame: CGRect, build: () -> RenderableItem) -> RenderableItem {
    guard slot.isIn(self) else {
      return build()
    }

    // compare the full configuration (id string and isFixed), not `==`: `==` ignores `isFixed`, but the built item's
    // composition in the parent's `join(with:)` depends on it, so a fixed/non-fixed change for the same string must rebuild.
    let index = slot.index
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
  ///
  /// The first items are made for exactly the slots taken. Slots taken after them, such as by nodes that a custom node
  /// makes in its layout, at least double the items, so that each slot past them doesn't move all the items again.
  private func makeItemsForAllSlots() {
    let newItemCount = max(slotCount, itemCount * 2)
    let newItems = UnsafeMutablePointer<RenderableItem?>.allocate(capacity: newItemCount)
    if let items {
      newItems.moveInitialize(from: items, count: itemCount)
      items.deallocate()
    }
    (newItems + itemCount).initialize(repeating: nil, count: newItemCount - itemCount)
    items = newItems
    itemCount = newItemCount
  }

  #if DEBUG
  /// The number of items in `items`, for tests.
  var itemCountForTesting: Int {
    itemCount
  }

  /// The id of the next cache, for tests.
  static var nextIdForTesting: UInt64 {
    get {
      nextId
    }
    set {
      nextId = newValue
    }
  }

  /// The largest id of a cache, for tests.
  static var maximumIdForTesting: UInt64 {
    Constants.maximumId
  }

  /// The largest index of a slot, for tests.
  static var maximumSlotIndexForTesting: Int {
    Int(Constants.maximumIndex)
  }

  /// Makes the cache's next slot take the given index, for tests.
  ///
  /// - Parameter index: The index of the next slot.
  func setNextSlotIndexForTesting(_ index: Int) {
    slotCount = index
  }

  /// Fails the assertion that a built item has the id and frame it's cached for, since the cache finds the item by them.
  ///
  /// The lookup compares them itself and calls this only when they differ, so that the debug builds that the
  /// benchmarks use don't keep the built item for a call on each miss, which costs about 140 instructions.
  @inline(never)
  private static func assertCacheableFailure() {
    ComposeUI.assertFailure("the built item must have the id and frame it's cached for")
  }
  #endif

  // MARK: - Constants

  private enum Constants {

    /// The number of a slot's low bits that hold its index.
    static let indexBitCount: UInt64 = 24

    /// The largest index of a slot, which also masks a slot's index bits.
    static let maximumIndex: UInt64 = (1 << indexBitCount) - 1

    /// The largest id of a cache, which fits in a slot's high bits.
    static let maximumId: UInt64 = (1 << (64 - indexBitCount)) - 1
  }
}
