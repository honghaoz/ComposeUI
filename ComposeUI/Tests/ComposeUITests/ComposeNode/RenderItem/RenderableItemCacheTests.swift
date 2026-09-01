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
    // given: a cache and a counting build closure
    let cache = RenderableItemCache()
    let id = ComposeNodeId.custom("x")
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)

    var buildCount = 0
    func build() -> RenderableItem {
      buildCount += 1
      return makeItem(id: id, frame: frame)
    }

    // when: requesting the item twice with the same id and frame
    let first = cache.item(id: id, frame: frame, build: build)
    let second = cache.item(id: id, frame: frame, build: build)

    // then: the second call is a cache hit, the build closure is not invoked again
    expect(buildCount) == 1
    expect(first.id) == id
    expect(second.id) == id
    expect(second.frame) == frame
  }

  func test_rebuilds_whenIdChanges() {
    // given: a cache populated with an item for one id
    let cache = RenderableItemCache()
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)

    var buildCount = 0

    _ = cache.item(id: .custom("a"), frame: frame) {
      buildCount += 1
      return makeItem(id: .custom("a"), frame: frame)
    }

    // when: requesting an item with a different id
    let b = cache.item(id: .custom("b"), frame: frame) {
      buildCount += 1
      return makeItem(id: .custom("b"), frame: frame)
    }

    // then: a different id misses and rebuilds
    expect(buildCount) == 2
    expect(b.id) == .custom("b")
  }

  func test_rebuilds_whenIsFixed_Changes() {
    // given: a cache populated with a non-fixed item for an id string
    let cache = RenderableItemCache()
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)

    var buildCount = 0

    _ = cache.item(id: .custom("x", isFixed: false), frame: frame) {
      buildCount += 1
      return makeItem(id: .custom("x", isFixed: false), frame: frame)
    }

    // when: requesting the same id string with a different "isFixed"
    let fixed = cache.item(id: .custom("x", isFixed: true), frame: frame) {
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
    // given: a cache populated with an item at a small frame
    let cache = RenderableItemCache()
    let id = ComposeNodeId.custom("x")
    let smallFrame = CGRect(x: 0, y: 0, width: 10, height: 10)
    let largeFrame = CGRect(x: 0, y: 0, width: 20, height: 20)

    var buildCount = 0

    _ = cache.item(id: id, frame: smallFrame) {
      buildCount += 1
      return makeItem(id: id, frame: smallFrame)
    }

    // when: requesting the same id with a larger frame
    let resized = cache.item(id: id, frame: largeFrame) {
      buildCount += 1
      return makeItem(id: id, frame: largeFrame)
    }

    // then: a different frame misses and rebuilds
    expect(buildCount) == 2
    expect(resized.frame) == largeFrame
  }
}
