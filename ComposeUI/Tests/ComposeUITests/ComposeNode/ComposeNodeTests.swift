//
//  ComposeNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/5/24.
//

import XCTest

@testable import ComposeUI

class ComposeNodeTests: XCTestCase {

    func test_ComposeContent() {
        let node = MockComposeNode()
        let nodes = node.asNodes()
        XCTAssertEqual(nodes.count, 1)
        XCTAssertTrue((nodes[0] as? MockComposeNode) === node)
    }

    func test_id() {
        do {
            let node = MockComposeNode().id("test")
            XCTAssertEqual(node.id, .custom("test", isFixed: false))
        }

        do {
            let node = MockComposeNode().fixedId("test")
            XCTAssertEqual(node.id, .custom("test", isFixed: true))
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
