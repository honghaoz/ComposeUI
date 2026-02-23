//
//  LayoutCacheNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
//

import ChouTiTest

@testable import ComposeUI

class LayoutCacheNodeTests: XCTestCase {

  func test() {
    let state = TestNode.State()
    let node = TestNode(state: state)
    let cachedNode = LayoutCacheNode(node: node)

    expect(cachedNode.id.id) == "test"
    cachedNode.id = .custom("test2")
    expect(cachedNode.id.id) == "test2"

    expect(cachedNode.size) == .zero

    // node with different size
    do {
      var node = LayerNode().frame(width: 100, height: 50)
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
      let cachedNode = LayoutCacheNode(node: node)
      expect(cachedNode.size) == CGSize(width: 100, height: 50)
    }

    _ = cachedNode.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 1))
    expect(state.layoutCount) == 1

    _ = cachedNode.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 1))
    expect(state.layoutCount) == 1

    _ = cachedNode.layout(containerSize: CGSize(width: 200, height: 200), context: ComposeNodeLayoutContext(scaleFactor: 1))
    expect(state.layoutCount) == 2

    expect(state.renderCount) == 0
    _ = cachedNode.renderableItems(in: CGRect(0, 0, 100, 100))
    expect(state.renderCount) == 1
  }
}
