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

  private func layerKey(_ id: String, namespace: ReuseId.Namespace = .user) -> ReuseKey {
    ReuseKey(reuseId: ReuseId(namespace: namespace, id: id), type: ObjectIdentifier(CALayer.self))
  }

  private func viewKey(_ id: String, namespace: ReuseId.Namespace = .user) -> ReuseKey {
    ReuseKey(reuseId: ReuseId(namespace: namespace, id: id), type: ObjectIdentifier(View.self))
  }

  /// Make a pool for the data-structure tests.
  private func makePool(maxCountPerKey: Int = 32, maxKeyCount: Int = 64) -> RenderablePool {
    RenderablePool(maxCountPerKey: maxCountPerKey, maxKeyCount: maxKeyCount)
  }

  func test_enqueueThenDequeue_returnsSameRenderable() {
    // given: an empty pool and a layer key
    let pool = makePool()
    let key = layerKey("row")

    // when: a layer is enqueued
    let layer = CALayer()
    pool.enqueue(.layer(layer), key: key)

    // then: the pool counts reflect the enqueued layer
    expect(pool.count) == 1
    expect(pool.count(for: key)) == 1

    // when: the key is dequeued
    let dequeued = pool.dequeue(key)

    // then: the same layer is handed back and the pool is empty
    expect(dequeued?.layer) === layer
    expect(pool.count) == 0
    expect(pool.count(for: key)) == 0
  }

  func test_dequeue_whenEmpty_returnsNil() {
    // given: an empty pool
    let pool = makePool()

    // then: dequeuing returns nil
    expect(pool.dequeue(layerKey("row"))) == nil
    // a key with no bucket reports a zero count.
    expect(pool.count(for: layerKey("row"))) == 0
  }

  func test_keys_areIsolated() {
    // given: a pool with a layer enqueued under key "a"
    let pool = makePool()
    let keyA = layerKey("a")
    let keyB = layerKey("b")

    let layerA = CALayer()
    pool.enqueue(.layer(layerA), key: keyA)

    // then: keys are isolated
    // a different key has nothing to dequeue.
    expect(pool.dequeue(keyB)) == nil
    // the original key still has its renderable.
    expect(pool.dequeue(keyA)?.layer) === layerA
  }

  func test_sameReuseId_differentType_areIsolated() {
    // given: a pool with a layer enqueued under a layer-typed key that shares its reuse id with a view-typed key
    let pool = makePool()
    let layerKey = ReuseKey(reuseId: ReuseId(namespace: .user, id: "row"), type: ObjectIdentifier(CALayer.self))
    let viewKey = ReuseKey(reuseId: ReuseId(namespace: .user, id: "row"), type: ObjectIdentifier(View.self))

    let layer = CALayer()
    pool.enqueue(.layer(layer), key: layerKey)

    // then: the view key, despite sharing the reuse id, must not dequeue the layer
    expect(pool.dequeue(viewKey)) == nil
    expect(pool.dequeue(layerKey)?.layer) === layer
  }

  func test_sameReuseId_differentNamespace_areIsolated() {
    // given: a pool with a layer enqueued under a framework-namespaced key
    let pool = makePool()
    // same reuse id string and same concrete type, but different namespaces (framework vs user).
    let frameworkKey = layerKey("ColorNode", namespace: .framework)
    let userKey = layerKey("ColorNode", namespace: .user)

    let frameworkLayer = CALayer()
    pool.enqueue(.layer(frameworkLayer), key: frameworkKey)

    // then: namespaces keep the keys isolated
    // a user key must not dequeue a framework-enqueued renderable, so a caller can never accidentally pull (or share) a
    // framework-internal renderable, even when the reuse id and type match.
    expect(pool.dequeue(userKey)) == nil
    expect(pool.dequeue(frameworkKey)?.layer) === frameworkLayer
  }

  func test_dequeue_isLIFO() {
    // given: a pool with two layers enqueued under the same key
    let pool = makePool()
    let key = layerKey("row")

    let first = CALayer()
    let second = CALayer()
    pool.enqueue(.layer(first), key: key)
    pool.enqueue(.layer(second), key: key)

    // then: the most recently enqueued is handed back first
    expect(pool.dequeue(key)?.layer) === second
    expect(pool.dequeue(key)?.layer) === first
  }

  func test_enqueue_isBoundedPerKey() {
    // given: a pool with a per-key cap of 2
    let pool = makePool(maxCountPerKey: 2)
    let key = layerKey("row")

    // when: three layers are enqueued under the same key
    let layers = [CALayer(), CALayer(), CALayer()]
    for layer in layers {
      pool.enqueue(.layer(layer), key: key)
    }

    // then: the third enqueue is dropped, the pool keeps at most the cap
    expect(pool.count(for: key)) == 2
    expect(pool.dequeue(key)?.layer) === layers[1] // the dropped one is the last enqueued
    expect(pool.dequeue(key)?.layer) === layers[0]
    expect(pool.dequeue(key)) == nil
  }

  func test_removeAll_clearsPool() {
    // given: a pool with layers enqueued under two keys
    let pool = makePool()
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))
    expect(pool.count) == 2
    expect(pool.keyCount) == 2

    // when: the pool is cleared
    pool.removeAll()

    // then: the pool is empty
    expect(pool.count) == 0
    expect(pool.keyCount) == 0
    expect(pool.dequeue(layerKey("a"))) == nil

    // when: a new key is enqueued after the clear
    pool.enqueue(.layer(CALayer()), key: layerKey("c"))

    // then: the key order is reset so the freshly enqueued key is not immediately evicted
    expect(pool.dequeue(layerKey("c"))) != nil
  }

  // MARK: - Empty bucket removal

  func test_dequeue_lastRenderable_removesBucket() {
    // given: a pool with a single layer enqueued
    let pool = makePool()
    let key = layerKey("row")

    pool.enqueue(.layer(CALayer()), key: key)
    expect(pool.keyCount) == 1

    // when: the last renderable is dequeued
    _ = pool.dequeue(key)

    // then: emptying the bucket must drop the key entirely, otherwise empty buckets accumulate (especially with
    // dynamic ids)
    expect(pool.keyCount) == 0
    expect(pool.count(for: key)) == 0
  }

  func test_dequeue_nonLastRenderable_keepsBucket() {
    // given: a pool with two layers enqueued under one key
    let pool = makePool()
    let key = layerKey("row")

    pool.enqueue(.layer(CALayer()), key: key)
    pool.enqueue(.layer(CALayer()), key: key)

    // when: one renderable is dequeued
    _ = pool.dequeue(key)

    // then: one renderable remains, so the bucket (and its key) is kept
    expect(pool.keyCount) == 1
    expect(pool.count(for: key)) == 1
  }

  // MARK: - Key bounding (LRU)

  func test_enqueue_isBoundedByKeyCount() {
    // given: a pool with a key cap of 2, filled with two keys
    let pool = makePool(maxKeyCount: 2)

    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))
    expect(pool.keyCount) == 2

    // when: a third distinct key exceeds the cap
    pool.enqueue(.layer(CALayer()), key: layerKey("c"))

    // then: the least-recently-used key ("a") is evicted
    expect(pool.keyCount) == 2
    expect(pool.dequeue(layerKey("a"))) == nil
    expect(pool.dequeue(layerKey("b"))) != nil
    expect(pool.dequeue(layerKey("c"))) != nil
  }

  func test_enqueue_touchingKey_makesItMostRecentlyUsed() {
    // given: a pool with a key cap of 2, filled with keys "a" and "b"
    let pool = makePool(maxKeyCount: 2)

    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))

    // when: "a" is touched again and a new key "c" is added
    // touch "a" again so "b" becomes the least-recently-used key.
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))

    // adding "c" now evicts "b" (the least-recently-used), not "a".
    pool.enqueue(.layer(CALayer()), key: layerKey("c"))

    // then: "b" is evicted while "a" and "c" remain
    expect(pool.dequeue(layerKey("b"))) == nil
    expect(pool.dequeue(layerKey("a"))) != nil
    expect(pool.dequeue(layerKey("c"))) != nil
  }

  func test_enqueue_fullBucket_stillRefreshesRecency() {
    // a key whose bucket is full must still be treated as recently-used, so its (warm) bucket isn't evicted when a new
    // key arrives while the key is still active.

    // given: a pool with a per-key cap of 1 and a key cap of 2, filled with two keys
    let pool = makePool(maxCountPerKey: 1, maxKeyCount: 2)

    // order so far: "a" (older), "b" (newer).
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))

    // when: enqueue into the now-full "a"
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))

    // then: the extra renderable is dropped, but "a" becomes most-recently-used
    expect(pool.count(for: layerKey("a"))) == 1

    // when: "c" is added
    pool.enqueue(.layer(CALayer()), key: layerKey("c"))

    // then: adding "c" evicts "b" (the least-recently-used), not the freshly-touched "a"
    expect(pool.dequeue(layerKey("b"))) == nil
    expect(pool.dequeue(layerKey("a"))) != nil
    expect(pool.dequeue(layerKey("c"))) != nil
  }

  func test_dequeue_updatesRecency() {
    // given: a pool at its key cap of 2
    let pool = makePool(maxKeyCount: 2)

    // "a" keeps two renderables so a dequeue leaves its bucket non-empty (and able to be touched).
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))

    // when: a renderable is dequeued from "a" and a new key "c" is added
    // dequeuing from "a" marks it most-recently-used, so "b" becomes the least-recently-used key.
    _ = pool.dequeue(layerKey("a"))

    pool.enqueue(.layer(CALayer()), key: layerKey("c"))

    // then: "b" is evicted while "a" and "c" remain
    expect(pool.dequeue(layerKey("b"))) == nil
    expect(pool.dequeue(layerKey("a"))) != nil
    expect(pool.dequeue(layerKey("c"))) != nil
  }

  // MARK: - Memory pressure

  func test_handleMemoryPressure_critical_clearsPool() {
    // given: a pool with renderables under two keys
    let pool = makePool()
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))
    expect(pool.count) == 3

    // when: critical memory pressure is handled
    pool.test.handleMemoryPressure(.critical)

    // then: critical pressure drops everything, keys included
    expect(pool.count) == 0
    expect(pool.keyCount) == 0
  }

  func test_handleMemoryPressure_warning_evictsHalfKeepingWarmest() {
    // given: a pool with four layers enqueued under one key
    let pool = makePool()
    let key = layerKey("row")

    let layers = [CALayer(), CALayer(), CALayer(), CALayer()]
    for layer in layers {
      pool.enqueue(.layer(layer), key: key)
    }
    expect(pool.count(for: key)) == 4

    // when: warning memory pressure is handled
    pool.test.handleMemoryPressure(.warning)

    // then: half are dropped, the warmest (most recently enqueued) are kept and handed back first (LIFO)
    expect(pool.count(for: key)) == 2
    expect(pool.dequeue(key)?.layer) === layers[3]
    expect(pool.dequeue(key)?.layer) === layers[2]
    expect(pool.dequeue(key)) == nil
  }

  func test_handleMemoryPressure_warning_dropsSingletonBuckets() {
    // given: a pool with a singleton bucket and a bucket of two
    let pool = makePool()
    pool.enqueue(.layer(CALayer()), key: layerKey("a")) // bucket of 1 -> not halvable -> dropped
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b")) // bucket of 2 -> halved to 1 -> kept

    // when: warning memory pressure is handled
    pool.test.handleMemoryPressure(.warning)

    // then: the singleton bucket is dropped and the halved bucket is kept
    expect(pool.keyCount) == 1
    expect(pool.count(for: layerKey("a"))) == 0
    expect(pool.count(for: layerKey("b"))) == 1
  }

  func test_init_observesMemoryPressure_andStaysUsable() {
    // given: a pool made with the public initializer (the pool always observes memory pressure)
    let pool = RenderablePool()
    let key = layerKey("row")

    // when: a layer is enqueued
    pool.enqueue(.layer(CALayer()), key: key)

    // then: the setup path runs and the pool stays usable
    expect(pool.dequeue(key)) != nil
  }

  // MARK: - Detached renderable

  func test_enqueue_viewWithSuperview_assertion() {
    // given: a test assertion handler expecting the detach assertion, and a view attached to a parent
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

    // when: the attached view is enqueued
    pool.enqueue(.view(view), key: key)

    // then: the assertion fires once
    expect(assertionCount) == 1
  }

  func test_enqueue_layerWithSuperlayer_assertion() {
    // given: a test assertion handler expecting the detach assertion, and a layer attached to a parent
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

    // when: the attached layer is enqueued
    pool.enqueue(.layer(layer), key: key)

    // then: the assertion fires once
    expect(assertionCount) == 1
  }

  // MARK: - Capacity bounds

  func test_init_nonPositiveMaxCountPerKey_assertion() {
    // given: a test assertion handler expecting the positive-cap assertion
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == "maxCountPerKey must be positive"
      assertionCount += 1
    }
    defer { ComposeUI.Assert.resetTestAssertionFailureHandler() }

    // when: a pool is made with a non-positive per-key cap
    let pool = makePool(maxCountPerKey: 0)

    // then: the assertion fires once
    expect(assertionCount) == 1

    // when: two renderables are enqueued under one key
    let key = layerKey("row")
    pool.enqueue(.layer(CALayer()), key: key)
    pool.enqueue(.layer(CALayer()), key: key)

    // then: non-positive values are clamped to 1, so only one renderable per key is kept
    expect(pool.count(for: key)) == 1
  }

  func test_init_nonPositiveMaxKeyCount_assertion() {
    // given: a test assertion handler expecting the positive-cap assertion
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == "maxKeyCount must be positive"
      assertionCount += 1
    }
    defer { ComposeUI.Assert.resetTestAssertionFailureHandler() }

    // when: a pool is made with a non-positive key cap
    let pool = makePool(maxKeyCount: -1)

    // then: the assertion fires once
    expect(assertionCount) == 1

    // when: two distinct keys are enqueued
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))

    // then: non-positive values are clamped to 1, so only one key is kept
    expect(pool.keyCount) == 1
  }

  func test_init_bothNonPositive_assertsTwice() {
    // given: a test assertion handler expecting the positive-cap assertions
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message.hasSuffix("must be positive")) == true
      assertionCount += 1
    }
    defer { ComposeUI.Assert.resetTestAssertionFailureHandler() }

    // when: a pool is made with both caps non-positive
    _ = makePool(maxCountPerKey: 0, maxKeyCount: 0)

    // then: the assertion fires twice
    expect(assertionCount) == 2
  }
}
