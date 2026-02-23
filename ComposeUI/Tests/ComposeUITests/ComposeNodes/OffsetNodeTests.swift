//
//  OffsetNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/13/25.
//

import ChouTiTest

import ChouTi
@testable import ComposeUI

class OffsetNodeTests: XCTestCase {

    func test_id() throws {
        let node = LayerNode().offset(x: 10, y: 20)
        expect(node.id.id) == "O"
    }

    func test_size() throws {
        // node without a size
        do {
            let node = LayerNode()
            expect(node.size) == .zero
            expect(node.offset(x: 10, y: 20).size) == .zero
        }

        // node with a size
        do {
            var node = LayerNode().frame(width: 20, height: 30)

            let context = ComposeNodeLayoutContext(scaleFactor: 1)
            _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

            expect(node.size) == CGSize(width: 20, height: 30)
            expect(node.offset(x: 10, y: 20).size) == CGSize(width: 20, height: 30)
        }
    }

    func test_layout() throws {
        let state = TestNode.State()
        let node = TestNode(state: state)

        var offsetNode = node.offset(x: 10, y: 20)

        expect(state.layoutCount) == 0

        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        _ = offsetNode.layout(containerSize: CGSize(width: 100, height: 100), context: context)

        expect(state.layoutCount) == 1
    }

    func test_renderableItems() throws {
        var node = LayerNode()
            .frame(width: 20, height: 30)
            .offset(x: 10, y: 20)

        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

        // when visible bounds contains the node
        do {
            let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 100)
            let items = node.renderableItems(in: visibleBounds)

            expect(items.count) == 1
            expect(items[0].frame) == CGRect(x: 10, y: 20, width: 20, height: 30)
            expect(items[0].id.id) == "O|F|L"
        }

        // when visible bounds does not contain the node
        do {
            let visibleBounds = CGRect(x: 0, y: 0, width: 10, height: 10)
            let items = node.renderableItems(in: visibleBounds)

            expect(items.count) == 0
        }
    }
}
