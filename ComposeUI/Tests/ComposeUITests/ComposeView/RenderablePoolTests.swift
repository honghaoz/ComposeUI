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

  func test_enqueueThenDequeue_returnsSameRenderable() {
    let pool = RenderablePool()
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
    let pool = RenderablePool()
    expect(pool.dequeue(layerKey("row"))) == nil
    // a key with no bucket reports a zero count.
    expect(pool.count(for: layerKey("row"))) == 0
  }

  func test_keys_areIsolated() {
    let pool = RenderablePool()
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
    let pool = RenderablePool()
    let layerKey = ReuseKey(reuseId: "row", type: ObjectIdentifier(CALayer.self))
    let viewKey = ReuseKey(reuseId: "row", type: ObjectIdentifier(View.self))

    let layer = CALayer()
    pool.enqueue(.layer(layer), key: layerKey)

    // the view key, despite sharing the reuse id, must not dequeue the layer.
    expect(pool.dequeue(viewKey)) == nil
    expect(pool.dequeue(layerKey)?.layer) === layer
  }

  func test_dequeue_isLIFO() {
    let pool = RenderablePool()
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
    let pool = RenderablePool(maxCountPerKey: 2)
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
    let pool = RenderablePool()
    pool.enqueue(.layer(CALayer()), key: layerKey("a"))
    pool.enqueue(.layer(CALayer()), key: layerKey("b"))
    expect(pool.count) == 2

    pool.removeAll()
    expect(pool.count) == 0
    expect(pool.dequeue(layerKey("a"))) == nil
  }
}
