//
//  LayoutCacheNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
//

import XCTest

@testable import ComposeUI

class LayoutCacheNodeTests: XCTestCase {

    func test() {
        let state = TestNode.State()
        let node = TestNode(state: state)
        let cachedNode = LayoutCacheNode(node: node)

        XCTAssertEqual(cachedNode.id.id, "test")
        cachedNode.id = .custom("test2")
        XCTAssertEqual(cachedNode.id.id, "test2")

        XCTAssertEqual(cachedNode.size, .zero)

        // node with different size
        do {
            var node = LayerNode().frame(width: 100, height: 50)
            let context = ComposeNodeLayoutContext(scaleFactor: 1)
            _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
            let cachedNode = LayoutCacheNode(node: node)
            XCTAssertEqual(cachedNode.size, CGSize(width: 100, height: 50))
        }

        _ = cachedNode.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 1))
        XCTAssertEqual(state.layoutCount, 1)

        _ = cachedNode.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 1))
        XCTAssertEqual(state.layoutCount, 1)

        _ = cachedNode.layout(containerSize: CGSize(width: 200, height: 200), context: ComposeNodeLayoutContext(scaleFactor: 1))
        XCTAssertEqual(state.layoutCount, 2)

        XCTAssertEqual(state.renderCount, 0)
        _ = cachedNode.renderableItems(in: CGRect(0, 0, 100, 100))
        XCTAssertEqual(state.renderCount, 1)
    }
}
