//
//  EmptyNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/6/25.
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
