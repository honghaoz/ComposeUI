//
//  EmptyNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/6/25.
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

class EmptyNodeTests: XCTestCase {

  func test_init() throws {
    _ = Empty()
    _ = EmptyNode()
  }

  func test_id() throws {
    let node = EmptyNode()
    expect(node.id.id) == "E"
  }

  func test_size() throws {
    let node = EmptyNode()
    expect(node.size) == .zero
  }

  func test_layout() throws {
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = EmptyNode()
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
    expect(node.size) == CGSize(width: 100, height: 100)
  }

  func test_renderableItems() throws {
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = EmptyNode()
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when visible bounds intersects with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)
      expect(items.count) == 0
    }

    // when visible bounds does not intersect with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 100, width: 100, height: 100)
      let items = node.renderableItems(in: visibleBounds)
      expect(items.count) == 0
    }
  }
}
