//
//  ComposeNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/5/24.
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
