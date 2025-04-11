//
//  ComposeNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/5/24.
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

class ComposeNodeTests: XCTestCase {

  func test_ComposeContent() {
    let node = MockComposeNode()
    let nodes = node.asNodes()
    expect(nodes.count) == 1
    expect((nodes[0] as? MockComposeNode)) === node
  }

  func test_id() {
    do {
      let node = MockComposeNode().id("test")
      expect(node.id) == .custom("test", isFixed: false)
    }

    do {
      let node = MockComposeNode().fixedId("test")
      expect(node.id) == .custom("test", isFixed: true)
    }
  }
}

private class MockComposeNode: ComposeNode {

  var id: ComposeNodeId = .custom("test", isFixed: false)
  var size: CGSize = .zero

  func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    ComposeNodeSizing(width: .fixed(100), height: .fixed(100))
  }

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    []
  }
}
