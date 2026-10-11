//
//  RenderableItemCacheTests.swift
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

import ChouTiTest

@testable import ComposeUI

class RenderableItemCacheTests: XCTestCase {

  private func makeItem(id: ComposeNodeId, frame: CGRect) -> RenderableItem {
    RenderableItem(id: id, frame: frame, make: { _ in .view(BaseView(frame: .zero)) }, update: { _, _ in })
  }

  /// Returns the item for the slot while the cache's items are collected, as a node's `renderableItems(in:)` does in a
  /// render pass.
  private func item(in slot: RenderableItemCache.Slot,
                    of cache: RenderableItemCache,
                    id: ComposeNodeId,
                    frame: CGRect,
                    build: () -> RenderableItem) -> RenderableItem
  {
    cache.collectItems {
      RenderableItemCache.item(in: slot, id: id, frame: frame, build: build)
    }
  }

  func test_returnsCachedItem_whenIdAndFrameUnchanged() {
    // given: a slot in a cache and a counting build closure
    let cache = RenderableItemCache()
    let slot = cache.makeSlot()
    let id = ComposeNodeId.custom("x")
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)

    var buildCount = 0
    func build() -> RenderableItem {
      buildCount += 1
      return makeItem(id: id, frame: frame)
    }

    // when: requesting the item twice with the same id and frame
    let first = item(in: slot, of: cache, id: id, frame: frame, build: build)
    let second = item(in: slot, of: cache, id: id, frame: frame, build: build)

    // then: the second call is a cache hit, the build closure is not invoked again
    expect(buildCount) == 1
    expect(first.id) == id
    expect(second.id) == id
    expect(second.frame) == frame
  }

  func test_rebuilds_whenIdChanges() {
    // given: a slot populated with an item for one id
    let cache = RenderableItemCache()
    let slot = cache.makeSlot()
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)

    var buildCount = 0

    _ = item(in: slot, of: cache, id: .custom("a"), frame: frame) {
      buildCount += 1
      return makeItem(id: .custom("a"), frame: frame)
    }

    // when: requesting an item with a different id
    let b = item(in: slot, of: cache, id: .custom("b"), frame: frame) {
      buildCount += 1
      return makeItem(id: .custom("b"), frame: frame)
    }

    // then: a different id misses and rebuilds
    expect(buildCount) == 2
    expect(b.id) == .custom("b")
  }

  func test_rebuilds_whenIsFixed_Changes() {
    // given: a slot populated with a non-fixed item for an id string
    let cache = RenderableItemCache()
    let slot = cache.makeSlot()
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)

    var buildCount = 0

    _ = item(in: slot, of: cache, id: .custom("x", isFixed: false), frame: frame) {
      buildCount += 1
      return makeItem(id: .custom("x", isFixed: false), frame: frame)
    }

    // when: requesting the same id string with a different "isFixed"
    let fixed = item(in: slot, of: cache, id: .custom("x", isFixed: true), frame: frame) {
      buildCount += 1
      return makeItem(id: .custom("x", isFixed: true), frame: frame)
    }

    // then: the same id string with a different "isFixed" must rebuild
    // `ComposeNodeId.==` ignores "isFixed", but the built item composes differently in the parent's `join` (a fixed
    // child id is not prefixed), so the cached non-fixed item must not be reused.
    expect(buildCount) == 2
    // the rebuilt item carries the fixed id (a fixed child id is not prefixed by its parent in `join`).
    expect(ComposeNodeId.custom("parent").join(with: fixed.id).id) == "x"
  }

  func test_rebuilds_whenFrameChanges() {
    // given: a slot populated with an item at a small frame
    let cache = RenderableItemCache()
    let slot = cache.makeSlot()
    let id = ComposeNodeId.custom("x")
    let smallFrame = CGRect(x: 0, y: 0, width: 10, height: 10)
    let largeFrame = CGRect(x: 0, y: 0, width: 20, height: 20)

    var buildCount = 0

    _ = item(in: slot, of: cache, id: id, frame: smallFrame) {
      buildCount += 1
      return makeItem(id: id, frame: smallFrame)
    }

    // when: requesting the same id with a larger frame
    let resized = item(in: slot, of: cache, id: id, frame: largeFrame) {
      buildCount += 1
      return makeItem(id: id, frame: largeFrame)
    }

    // then: a different frame misses and rebuilds
    expect(buildCount) == 2
    expect(resized.frame) == largeFrame
  }

  // MARK: - Slots

  func test_makeSlot_returnsANewSlot() {
    // given: a slot in a cache whose item is cached
    let cache = RenderableItemCache()
    let slot = cache.makeSlot()
    let id = ComposeNodeId.custom("x")
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    var buildCount = 0
    func build() -> RenderableItem {
      buildCount += 1
      return makeItem(id: id, frame: frame)
    }
    _ = item(in: slot, of: cache, id: id, frame: frame, build: build)

    // when: making another slot, and requesting its item with the same id and frame
    let newSlot = cache.makeSlot()
    _ = item(in: newSlot, of: cache, id: id, frame: frame, build: build)

    // then: the new slot builds its own item, and the first slot keeps its item
    expect(buildCount) == 2
    _ = item(in: slot, of: cache, id: id, frame: frame, build: build)
    expect(buildCount) == 2
  }

  func test_makeSlot_pastTheLastIndex_returnsTheUnassignedSlot() {
    // given: a cache whose next slot takes the last index
    let cache = RenderableItemCache()
    cache.setNextSlotIndexForTesting(RenderableItemCache.maximumSlotIndexForTesting)

    // when: taking two slots
    let lastSlot = cache.makeSlot()
    let pastSlot = cache.makeSlot()

    // then: the first slot is in the cache, and the second is the unassigned slot, whose node builds its item each time
    expect(lastSlot.isIn(cache)) == true
    expect(pastSlot) == .unassigned
    expect(pastSlot.isIn(cache)) == false
  }

  func test_init_afterTheLargestId_startsTheIdsOver() {
    // given: a slot in a cache with the first id, and the next id set to the largest one
    let nextId = RenderableItemCache.nextIdForTesting
    defer {
      RenderableItemCache.nextIdForTesting = nextId
    }
    RenderableItemCache.nextIdForTesting = 1
    let slot = RenderableItemCache().makeSlot()
    RenderableItemCache.nextIdForTesting = RenderableItemCache.maximumIdForTesting

    // when: making two caches
    let lastCache = RenderableItemCache()
    let wrappedCache = RenderableItemCache()

    // then: the first cache takes the largest id, and the second starts over at the first id, which the slot has
    expect(lastCache.makeSlot().isIn(lastCache)) == true
    expect(slot.isIn(lastCache)) == false
    expect(slot.isIn(wrappedCache)) == true
  }

  func test_item_slotsTakenAfterTheFirstBuild_cacheTheirOwnItems() {
    // given: a slot whose item is cached, which makes the cache's items for the slots taken so far
    let cache = RenderableItemCache()
    let firstSlot = cache.makeSlot()
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    var buildCount = 0
    func build(_ id: String) -> RenderableItem {
      buildCount += 1
      return makeItem(id: .custom(id), frame: frame)
    }
    _ = item(in: firstSlot, of: cache, id: .custom("first"), frame: frame) { build("first") }

    // when: two more slots are taken, and the last one builds its item first
    let secondSlot = cache.makeSlot()
    let thirdSlot = cache.makeSlot()
    _ = item(in: thirdSlot, of: cache, id: .custom("third"), frame: frame) { build("third") }
    _ = item(in: secondSlot, of: cache, id: .custom("second"), frame: frame) { build("second") }

    // then: each slot returns its own cached item
    expect(buildCount) == 3
    let items = [
      item(in: firstSlot, of: cache, id: .custom("first"), frame: frame) { build("first") },
      item(in: secondSlot, of: cache, id: .custom("second"), frame: frame) { build("second") },
      item(in: thirdSlot, of: cache, id: .custom("third"), frame: frame) { build("third") },
    ]
    expect(buildCount) == 3
    expect(items.map(\.id.id)) == ["first", "second", "third"]
  }

  func test_item_slotsTakenAfterTheFirstBuild_growTheItemsGeometrically() {
    // given: a cache with three slots taken
    let cache = RenderableItemCache()
    let id = ComposeNodeId.custom("x")
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    let firstSlot = cache.makeSlot()
    _ = cache.makeSlot()
    _ = cache.makeSlot()

    // when: the first slot builds its item
    _ = item(in: firstSlot, of: cache, id: id, frame: frame) { makeItem(id: id, frame: frame) }

    // then: the cache makes items for exactly the slots taken
    expect(cache.itemCountForTesting) == 3

    // when: slots are taken one at a time, as by nodes that a custom node makes in its layout, and each builds its item
    var itemCounts: [Int] = []
    for _ in 0 ..< 6 {
      _ = item(in: cache.makeSlot(), of: cache, id: id, frame: frame) { makeItem(id: id, frame: frame) }
      itemCounts.append(cache.itemCountForTesting)
    }

    // then: a slot past the items doubles them, instead of growing them to the number of slots, and the first slot's
    // item stays cached
    expect(itemCounts) == [6, 6, 6, 12, 12, 12]
    var rebuilt = false
    _ = item(in: firstSlot, of: cache, id: id, frame: frame) {
      rebuilt = true
      return makeItem(id: id, frame: frame)
    }
    expect(rebuilt) == false
  }

  func test_item_unassignedSlot_buildsEachTime() {
    // given: the unassigned slot, as for a node that isn't laid out
    let cache = RenderableItemCache()
    let id = ComposeNodeId.custom("x")
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    var buildCount = 0

    // when: requesting the item twice
    for _ in 0 ..< 2 {
      _ = item(in: .unassigned, of: cache, id: id, frame: frame) {
        buildCount += 1
        return makeItem(id: id, frame: frame)
      }
    }

    // then: each request builds the item, since there's nowhere to cache it
    expect(buildCount) == 2
  }

  func test_item_outsideACollection_buildsWithoutCaching() {
    // given: a slot whose item is cached while the cache's items are collected
    let cache = RenderableItemCache()
    let slot = cache.makeSlot()
    let id = ComposeNodeId.custom("x")
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    var buildCount = 0
    func build() -> RenderableItem {
      buildCount += 1
      return makeItem(id: id, frame: frame)
    }
    _ = item(in: slot, of: cache, id: id, frame: frame, build: build)

    // when: requesting the item outside a collection, as a node rendered outside a render pass does
    _ = RenderableItemCache.item(in: slot, id: id, frame: frame, build: build)

    // then: the request builds the item, since it can't reach the cache
    expect(buildCount) == 2
  }

  func test_item_slotOfAnotherCache_buildsWithoutCaching() {
    // given: a slot in one cache, and another cache whose items are collected
    let cache = RenderableItemCache()
    let slot = cache.makeSlot()
    let otherCache = RenderableItemCache()
    let id = ComposeNodeId.custom("x")
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    var buildCount = 0
    func build() -> RenderableItem {
      buildCount += 1
      return makeItem(id: id, frame: frame)
    }

    // when: requesting the slot's item twice while the other cache's items are collected, as a node of a replaced
    // content rendered in a new content's pass does
    _ = item(in: slot, of: otherCache, id: id, frame: frame, build: build)
    _ = item(in: slot, of: otherCache, id: id, frame: frame, build: build)

    // then: each request builds the item, and the other cache doesn't make items for it
    expect(buildCount) == 2
    expect(otherCache.itemCountForTesting) == 0
  }

  func test_collectItems_withinAnotherCollection_restoresTheOuterCache() {
    // given: a slot in a cache whose items are collected, and another cache
    let cache = RenderableItemCache()
    let slot = cache.makeSlot()
    let otherCache = RenderableItemCache()
    let id = ComposeNodeId.custom("x")
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    var buildCount = 0
    func build() -> RenderableItem {
      buildCount += 1
      return makeItem(id: id, frame: frame)
    }

    // when: the other cache's items are collected within the cache's collection, which then requests the item twice
    cache.collectItems {
      otherCache.collectItems {}
      _ = RenderableItemCache.item(in: slot, id: id, frame: frame, build: build)
      _ = RenderableItemCache.item(in: slot, id: id, frame: frame, build: build)
    }

    // then: the outer collection finds its own cache again, so the second request is a hit
    expect(buildCount) == 1
  }

  func test_item_builtWithAnotherFrame_asserts() {
    // given: an assertion failure handler that records the messages
    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }
    let cache = RenderableItemCache()
    let slot = cache.makeSlot()
    let id = ComposeNodeId.custom("x")

    // when: a build closure returns an item with a frame other than the requested one
    let builtItem = item(in: slot, of: cache, id: id, frame: CGRect(x: 0, y: 0, width: 10, height: 10)) {
      makeItem(id: id, frame: CGRect(x: 0, y: 0, width: 20, height: 20))
    }

    // then: it asserts, since the item couldn't be found by its request, and the built item is returned
    expect(assertionMessages) == ["the built item must have the id and frame it's cached for"]
    expect(builtItem.frame) == CGRect(x: 0, y: 0, width: 20, height: 20)
  }

  // MARK: - Layout Context

  func test_updateRenderableItemSlot_slotInTheContentsCache_keepsTheSlot() {
    // given: a node's slot taken with a context, whose item is cached
    let evaluation = ContentEvaluation()
    var slot = RenderableItemCache.Slot.unassigned
    ComposeNodeLayoutContext(scaleFactor: 2, contentEvaluation: evaluation).updateRenderableItemSlot(&slot)
    let id = ComposeNodeId.custom("x")
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    var buildCount = 0
    func build() -> RenderableItem {
      buildCount += 1
      return makeItem(id: id, frame: frame)
    }
    _ = item(in: slot, of: evaluation.renderableItemCache, id: id, frame: frame, build: build)

    // when: updating the slot with another context of the same content, as laying out the node again in a new pass does
    ComposeNodeLayoutContext(scaleFactor: 2, contentEvaluation: evaluation).updateRenderableItemSlot(&slot)
    _ = item(in: slot, of: evaluation.renderableItemCache, id: id, frame: frame, build: build)

    // then: the slot is kept, so its cached item is returned
    expect(buildCount) == 1
  }

  func test_updateRenderableItemSlot_slotInAnotherCache_takesASlotInTheContentsCache() {
    // given: a node's slot taken with a context of one content, whose item is cached
    let firstContext = ComposeNodeLayoutContext(scaleFactor: 2)
    var slot = RenderableItemCache.Slot.unassigned
    firstContext.updateRenderableItemSlot(&slot)
    let id = ComposeNodeId.custom("x")
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    var buildCount = 0
    func build() -> RenderableItem {
      buildCount += 1
      return makeItem(id: id, frame: frame)
    }
    _ = item(in: slot, of: firstContext.contentEvaluation.renderableItemCache, id: id, frame: frame, build: build)

    // when: updating the slot with a context of another content, as laying out a copy of the node in it does
    let evaluation = ContentEvaluation()
    ComposeNodeLayoutContext(scaleFactor: 2, contentEvaluation: evaluation).updateRenderableItemSlot(&slot)
    _ = item(in: slot, of: evaluation.renderableItemCache, id: id, frame: frame, build: build)

    // then: the node takes a new slot in the other content's cache, which builds its own item and keeps it
    expect(buildCount) == 2
    ComposeNodeLayoutContext(scaleFactor: 2, contentEvaluation: evaluation).updateRenderableItemSlot(&slot)
    _ = item(in: slot, of: evaluation.renderableItemCache, id: id, frame: frame, build: build)
    expect(buildCount) == 2
  }
}
