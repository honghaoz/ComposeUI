//
//  RenderablePoolTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 6/13/26.
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

import QuartzCore

import ChouTiTest

@testable import ComposeUI

class RenderablePoolTests: XCTestCase {

  private func layerKey(_ id: String) -> ReuseKey {
    ReuseKey(reuseId: id, type: ObjectIdentifier(CALayer.self))
  }

  private func viewKey(_ id: String) -> ReuseKey {
    ReuseKey(reuseId: id, type: ObjectIdentifier(View.self))
  }

  /// Make a pool for the data-structure tests.
  private func makePool(maxCountPerKey: Int = 32, maxKeyCount: Int = 64) -> RenderablePool {
    RenderablePool(maxCountPerKey: maxCountPerKey, maxKeyCount: maxKeyCount)
  }

  func test_enqueueThenDequeue_returnsSameRenderable() {
    let pool = makePool()
    let key = layerKey("row")

    let layer = CALayer()
    pool.enqueue(.layer(layer), key: key)
    expect(pool.count) == 1
    expect(pool.count(for: key)) == 1

    let dequeued = pool.dequeue(key)
    expect(dequeued?.layer) === layer
    expect(pool.count) == 0
    expect(pool.count(for: key)) == 0
  }

  func test_dequeue_whenEmpty_returnsNil() {
    let pool = makePool()
    expect(pool.dequeue(layerKey("row"))) == nil
    // a key with no bucket reports a zero count.
    expect(pool.count(for: layerKey("row"))) == 0
  }

  func test_keys_areIsolated() {
    let pool = makePool()
    let keyA = layerKey("a")
    let keyB = layerKey("b")

    let layerA = CALayer()
    pool.enqueue(.layer(layerA), key: keyA)

    // a different key has nothing to dequeue.
    expect(pool.dequeue(keyB)) == nil
    // the original key still has its renderable.
    expect(pool.dequeue(keyA)?.layer) === layerA
  }

  func test_sameReuseId_differentType_areIsolated() {
    let pool = makePool()
    let layerKey = ReuseKey(reuseId: "row", type: ObjectIdentifier(CALayer.self))
    let viewKey = ReuseKey(reuseId: "row", type: ObjectIdentifier(View.self))

    let layer = CALayer()
    pool.enqueue(.layer(layer), key: layerKey)

    // the view key, despite sharing the reuse id, must not dequeue the layer.
    expect(pool.dequeue(viewKey)) == nil
    expect(pool.dequeue(layerKey)?.layer) === layer
  }

  func test_dequeue_isLIFO() {
    let pool = makePool()
    let key = layerKey("row")

    let first = CALayer()
    let second = CALayer()
    pool.enqueue(.layer(first), key: key)
    pool.enqueue(.layer(second), key: key)

    // most recently parked is handed back first.
    expect(pool.dequeue(key)?.layer) === second
    expect(pool.dequeue(key)?.layer) === first
  }

  func test_enqueue_isBoundedPerKey() {
    let pool = makePool(maxCountPerKey: 2)
    let key = layerKey("row")

    let layers = [CALayer(), CALayer(), CALayer()]
    for layer in layers {
      pool.enqueue(.layer(layer), key: key)
    }

    // the third enqueue is dropped, the pool keeps at most the cap.
    expect(pool.count(for: key)) == 2
    expect(pool.dequeue(key)?.layer) === layers[1] // the dropped one is the last enqueued
    expect(pool.dequeue(key)?.layer) === layers[0]
    expect(pool.dequeue(key)) == nil
  }

  func test_removeAll_clearsPool() {
    let pool = makePool()
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))
    expect(pool.count) == 2
    expect(pool.keyCount) == 2

    pool.removeAll()
    expect(pool.count) == 0
    expect(pool.keyCount) == 0
    expect(pool.dequeue(layerKey("a"))) == nil

    // after a clear, the key order is reset so a freshly enqueued key is not immediately evicted.
    pool.enqueue(.layer(CALayer()), key: layerKey("c"))
    expect(pool.dequeue(layerKey("c"))) != nil
  }

  // MARK: - Empty bucket removal

  func test_dequeue_lastRenderable_removesBucket() {
    let pool = makePool()
    let key = layerKey("row")

    pool.enqueue(.layer(CALayer()), key: key)
    expect(pool.keyCount) == 1

    _ = pool.dequeue(key)

    // emptying the bucket must drop the key entirely, otherwise empty buckets accumulate (especially with dynamic ids).
    expect(pool.keyCount) == 0
    expect(pool.count(for: key)) == 0
  }

  func test_dequeue_nonLastRenderable_keepsBucket() {
    let pool = makePool()
    let key = layerKey("row")

    pool.enqueue(.layer(CALayer()), key: key)
    pool.enqueue(.layer(CALayer()), key: key)

    _ = pool.dequeue(key)

    // one renderable remains, so the bucket (and its key) is kept.
    expect(pool.keyCount) == 1
    expect(pool.count(for: key)) == 1
  }

  // MARK: - Key bounding (LRU)

  func test_enqueue_isBoundedByKeyCount() {
    let pool = makePool(maxKeyCount: 2)

    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))
    expect(pool.keyCount) == 2

    // a third distinct key exceeds the cap, evicting the least-recently-used key ("a").
    pool.enqueue(.layer(CALayer()), key: layerKey("c"))
    expect(pool.keyCount) == 2
    expect(pool.dequeue(layerKey("a"))) == nil
    expect(pool.dequeue(layerKey("b"))) != nil
    expect(pool.dequeue(layerKey("c"))) != nil
  }

  func test_enqueue_touchingKey_makesItMostRecentlyUsed() {
    let pool = makePool(maxKeyCount: 2)

    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))

    // touch "a" again so "b" becomes the least-recently-used key.
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))

    // adding "c" now evicts "b" (the least-recently-used), not "a".
    pool.enqueue(.layer(CALayer()), key: layerKey("c"))
    expect(pool.dequeue(layerKey("b"))) == nil
    expect(pool.dequeue(layerKey("a"))) != nil
    expect(pool.dequeue(layerKey("c"))) != nil
  }

  func test_enqueue_fullBucket_stillRefreshesRecency() {
    // a key whose bucket is full must still be treated as recently-used, so its (warm) bucket isn't evicted when a new
    // key arrives while the key is still active.
    let pool = makePool(maxCountPerKey: 1, maxKeyCount: 2)

    // order so far: "a" (older), "b" (newer).
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))

    // enqueue into the now-full "a": the extra renderable is dropped, but "a" becomes most-recently-used.
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    expect(pool.count(for: layerKey("a"))) == 1

    // adding "c" must now evict "b" (the least-recently-used), not the freshly-touched "a".
    pool.enqueue(.layer(CALayer()), key: layerKey("c"))
    expect(pool.dequeue(layerKey("b"))) == nil
    expect(pool.dequeue(layerKey("a"))) != nil
    expect(pool.dequeue(layerKey("c"))) != nil
  }

  func test_dequeue_updatesRecency() {
    let pool = makePool(maxKeyCount: 2)

    // "a" keeps two renderables so a dequeue leaves its bucket non-empty (and able to be touched).
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))

    // dequeuing from "a" marks it most-recently-used, so "b" becomes the least-recently-used key.
    _ = pool.dequeue(layerKey("a"))

    pool.enqueue(.layer(CALayer()), key: layerKey("c"))
    expect(pool.dequeue(layerKey("b"))) == nil
    expect(pool.dequeue(layerKey("a"))) != nil
    expect(pool.dequeue(layerKey("c"))) != nil
  }

  // MARK: - Memory pressure

  func test_handleMemoryPressure_critical_clearsPool() {
    let pool = makePool()
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))
    expect(pool.count) == 3

    pool.test.handleMemoryPressure(.critical)

    // critical pressure drops everything, keys included.
    expect(pool.count) == 0
    expect(pool.keyCount) == 0
  }

  func test_handleMemoryPressure_warning_evictsHalfKeepingWarmest() {
    let pool = makePool()
    let key = layerKey("row")

    let layers = [CALayer(), CALayer(), CALayer(), CALayer()]
    for layer in layers {
      pool.enqueue(.layer(layer), key: key)
    }
    expect(pool.count(for: key)) == 4

    pool.test.handleMemoryPressure(.warning)

    // half are dropped; the warmest (most recently parked) are kept and handed back first (LIFO).
    expect(pool.count(for: key)) == 2
    expect(pool.dequeue(key)?.layer) === layers[3]
    expect(pool.dequeue(key)?.layer) === layers[2]
    expect(pool.dequeue(key)) == nil
  }

  func test_handleMemoryPressure_warning_dropsSingletonBuckets() {
    let pool = makePool()
    pool.enqueue(.layer(CALayer()), key: layerKey("a")) // bucket of 1 -> not halvable -> dropped
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b")) // bucket of 2 -> halved to 1 -> kept

    pool.test.handleMemoryPressure(.warning)

    expect(pool.keyCount) == 1
    expect(pool.count(for: layerKey("a"))) == 0
    expect(pool.count(for: layerKey("b"))) == 1
  }

  func test_init_observesMemoryPressure_andStaysUsable() {
    // the pool always observes memory pressure; verify the setup path runs and the pool stays usable.
    let pool = RenderablePool()
    let key = layerKey("row")
    pool.enqueue(.layer(CALayer()), key: key)
    expect(pool.dequeue(key)) != nil
  }

  // MARK: - Detached renderable

  func test_enqueue_viewWithSuperview_assertion() {
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == "Renderable must be detached from its parent"
      assertionCount += 1
    }
    defer { ComposeUI.Assert.resetTestAssertionFailureHandler() }

    let pool = makePool()
    let key = viewKey("row")
    let parent = BaseView()
    let view = BaseView()
    parent.addSubview(view)

    pool.enqueue(.view(view), key: key)
    expect(assertionCount) == 1
  }

  func test_enqueue_layerWithSuperlayer_assertion() {
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == "Renderable must be detached from its parent"
      assertionCount += 1
    }
    defer { ComposeUI.Assert.resetTestAssertionFailureHandler() }

    let pool = makePool()
    let key = layerKey("row")
    let parent = CALayer()
    let layer = CALayer()
    parent.addSublayer(layer)

    pool.enqueue(.layer(layer), key: key)
    expect(assertionCount) == 1
  }

  // MARK: - Capacity bounds

  func test_init_nonPositiveMaxCountPerKey_assertion() {
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == "maxCountPerKey must be positive"
      assertionCount += 1
    }
    defer { ComposeUI.Assert.resetTestAssertionFailureHandler() }

    let pool = makePool(maxCountPerKey: 0)
    expect(assertionCount) == 1

    // non-positive values are clamped to 1, so only one renderable per key is kept.
    let key = layerKey("row")
    pool.enqueue(.layer(CALayer()), key: key)
    pool.enqueue(.layer(CALayer()), key: key)
    expect(pool.count(for: key)) == 1
  }

  func test_init_nonPositiveMaxKeyCount_assertion() {
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == "maxKeyCount must be positive"
      assertionCount += 1
    }
    defer { ComposeUI.Assert.resetTestAssertionFailureHandler() }

    let pool = makePool(maxKeyCount: -1)
    expect(assertionCount) == 1

    // non-positive values are clamped to 1, so only one key is kept.
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))
    expect(pool.keyCount) == 1
  }

  func test_init_bothNonPositive_assertsTwice() {
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message.hasSuffix("must be positive")) == true
      assertionCount += 1
    }
    defer { ComposeUI.Assert.resetTestAssertionFailureHandler() }

    _ = makePool(maxCountPerKey: 0, maxKeyCount: 0)
    expect(assertionCount) == 2
  }
}
