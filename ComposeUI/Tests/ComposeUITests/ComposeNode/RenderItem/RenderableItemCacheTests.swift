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

  func test_returnsCachedItem_whenIdAndFrameUnchanged() {
    // given: a slot in a cache and a counting build closure
    let slot = RenderableItemCache().makeSlot()
    let id = ComposeNodeId.custom("x")
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)

    var buildCount = 0
    func build() -> RenderableItem {
      buildCount += 1
      return makeItem(id: id, frame: frame)
    }

    // when: requesting the item twice with the same id and frame
    let first = RenderableItemCache.item(in: slot, id: id, frame: frame, build: build)
    let second = RenderableItemCache.item(in: slot, id: id, frame: frame, build: build)

    // then: the second call is a cache hit, the build closure is not invoked again
    expect(buildCount) == 1
    expect(first.id) == id
    expect(second.id) == id
    expect(second.frame) == frame
  }

  func test_rebuilds_whenIdChanges() {
    // given: a slot populated with an item for one id
    let slot = RenderableItemCache().makeSlot()
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)

    var buildCount = 0

    _ = RenderableItemCache.item(in: slot, id: .custom("a"), frame: frame) {
      buildCount += 1
      return makeItem(id: .custom("a"), frame: frame)
    }

    // when: requesting an item with a different id
    let b = RenderableItemCache.item(in: slot, id: .custom("b"), frame: frame) {
      buildCount += 1
      return makeItem(id: .custom("b"), frame: frame)
    }

    // then: a different id misses and rebuilds
    expect(buildCount) == 2
    expect(b.id) == .custom("b")
  }

  func test_rebuilds_whenIsFixed_Changes() {
    // given: a slot populated with a non-fixed item for an id string
    let slot = RenderableItemCache().makeSlot()
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)

    var buildCount = 0

    _ = RenderableItemCache.item(in: slot, id: .custom("x", isFixed: false), frame: frame) {
      buildCount += 1
      return makeItem(id: .custom("x", isFixed: false), frame: frame)
    }

    // when: requesting the same id string with a different "isFixed"
    let fixed = RenderableItemCache.item(in: slot, id: .custom("x", isFixed: true), frame: frame) {
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
    let slot = RenderableItemCache().makeSlot()
    let id = ComposeNodeId.custom("x")
    let smallFrame = CGRect(x: 0, y: 0, width: 10, height: 10)
    let largeFrame = CGRect(x: 0, y: 0, width: 20, height: 20)

    var buildCount = 0

    _ = RenderableItemCache.item(in: slot, id: id, frame: smallFrame) {
      buildCount += 1
      return makeItem(id: id, frame: smallFrame)
    }

    // when: requesting the same id with a larger frame
    let resized = RenderableItemCache.item(in: slot, id: id, frame: largeFrame) {
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
    _ = RenderableItemCache.item(in: slot, id: id, frame: frame, build: build)

    // when: making another slot, and requesting its item with the same id and frame
    let newSlot = cache.makeSlot()
    _ = RenderableItemCache.item(in: newSlot, id: id, frame: frame, build: build)

    // then: the new slot builds its own item, and the first slot keeps its item
    expect(buildCount) == 2
    _ = RenderableItemCache.item(in: slot, id: id, frame: frame, build: build)
    expect(buildCount) == 2
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
    _ = RenderableItemCache.item(in: firstSlot, id: .custom("first"), frame: frame) { build("first") }

    // when: two more slots are taken, and the last one builds its item first
    let secondSlot = cache.makeSlot()
    let thirdSlot = cache.makeSlot()
    _ = RenderableItemCache.item(in: thirdSlot, id: .custom("third"), frame: frame) { build("third") }
    _ = RenderableItemCache.item(in: secondSlot, id: .custom("second"), frame: frame) { build("second") }

    // then: each slot returns its own cached item
    expect(buildCount) == 3
    let items = [
      RenderableItemCache.item(in: firstSlot, id: .custom("first"), frame: frame) { build("first") },
      RenderableItemCache.item(in: secondSlot, id: .custom("second"), frame: frame) { build("second") },
      RenderableItemCache.item(in: thirdSlot, id: .custom("third"), frame: frame) { build("third") },
    ]
    expect(buildCount) == 3
    expect(items.map(\.id.id)) == ["first", "second", "third"]
  }

  func test_item_withoutASlot_buildsEachTime() {
    // given: no slot, as for a node that isn't laid out
    let id = ComposeNodeId.custom("x")
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    var buildCount = 0

    // when: requesting the item twice
    for _ in 0 ..< 2 {
      _ = RenderableItemCache.item(in: nil, id: id, frame: frame) {
        buildCount += 1
        return makeItem(id: id, frame: frame)
      }
    }

    // then: each request builds the item, since there's nowhere to cache it
    expect(buildCount) == 2
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
    let slot = RenderableItemCache().makeSlot()
    let id = ComposeNodeId.custom("x")

    // when: a build closure returns an item with a frame other than the requested one
    let item = RenderableItemCache.item(in: slot, id: id, frame: CGRect(x: 0, y: 0, width: 10, height: 10)) {
      makeItem(id: id, frame: CGRect(x: 0, y: 0, width: 20, height: 20))
    }

    // then: it asserts, since the item couldn't be found by its request, and the built item is returned
    expect(assertionMessages) == ["the built item must have the id and frame it's cached for"]
    expect(item.frame) == CGRect(x: 0, y: 0, width: 20, height: 20)
  }

  // MARK: - Layout Context

  func test_updateRenderableItemSlot_slotInTheContentsCache_keepsTheSlot() {
    // given: a node's slot taken with a context, whose item is cached
    let evaluation = ContentEvaluation()
    var slot: RenderableItemCache.Slot?
    ComposeNodeLayoutContext(scaleFactor: 2, contentEvaluation: evaluation).updateRenderableItemSlot(&slot)
    let id = ComposeNodeId.custom("x")
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    var buildCount = 0
    func build() -> RenderableItem {
      buildCount += 1
      return makeItem(id: id, frame: frame)
    }
    _ = RenderableItemCache.item(in: slot, id: id, frame: frame, build: build)

    // when: updating the slot with another context of the same content, as laying out the node again in a new pass does
    ComposeNodeLayoutContext(scaleFactor: 2, contentEvaluation: evaluation).updateRenderableItemSlot(&slot)
    _ = RenderableItemCache.item(in: slot, id: id, frame: frame, build: build)

    // then: the slot is kept, so its cached item is returned
    expect(buildCount) == 1
  }

  func test_updateRenderableItemSlot_slotInAnotherCache_takesASlotInTheContentsCache() {
    // given: a node's slot taken with a context of one content, whose item is cached
    var slot: RenderableItemCache.Slot?
    ComposeNodeLayoutContext(scaleFactor: 2).updateRenderableItemSlot(&slot)
    let id = ComposeNodeId.custom("x")
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    var buildCount = 0
    func build() -> RenderableItem {
      buildCount += 1
      return makeItem(id: id, frame: frame)
    }
    _ = RenderableItemCache.item(in: slot, id: id, frame: frame, build: build)

    // when: updating the slot with a context of another content, as laying out a copy of the node in it does
    let evaluation = ContentEvaluation()
    ComposeNodeLayoutContext(scaleFactor: 2, contentEvaluation: evaluation).updateRenderableItemSlot(&slot)
    _ = RenderableItemCache.item(in: slot, id: id, frame: frame, build: build)

    // then: the node takes a new slot in the other content's cache, which builds its own item and keeps it
    expect(buildCount) == 2
    ComposeNodeLayoutContext(scaleFactor: 2, contentEvaluation: evaluation).updateRenderableItemSlot(&slot)
    _ = RenderableItemCache.item(in: slot, id: id, frame: frame, build: build)
    expect(buildCount) == 2
  }
}
