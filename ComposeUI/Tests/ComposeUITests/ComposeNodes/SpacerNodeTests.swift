//
//  SpacerNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 7/31/25.
//

import XCTest

import ComposeUI

class SpacerNodeTests: XCTestCase {

    func test_init_default() {
        let spacer = SpacerNode()
        XCTAssertEqual(spacer.size, .zero)
    }

    func test_init_cgSize() {
        var spacer = SpacerNode(CGSize(width: 100, height: 200))

        let containerSize = CGSize(width: 200, height: 200)
        let context = ComposeNodeLayoutContext(scaleFactor: 2)

        let sizing = spacer.layout(containerSize: containerSize, context: context)
        XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(100), height: .fixed(200)))
        XCTAssertEqual(spacer.size, CGSize(width: 100, height: 200))
    }

    func test_init_size() {
        var spacer = SpacerNode(100)

        let containerSize = CGSize(width: 200, height: 200)
        let context = ComposeNodeLayoutContext(scaleFactor: 2)

        let sizing = spacer.layout(containerSize: containerSize, context: context)
        XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(100), height: .fixed(100)))
        XCTAssertEqual(spacer.size, CGSize(width: 100, height: 100))
    }

    func test_init_width_height() {
        // with width
        do {
            var spacer = SpacerNode(width: 100)

            let containerSize = CGSize(width: 200, height: 200)
            let context = ComposeNodeLayoutContext(scaleFactor: 2)

            let sizing = spacer.layout(containerSize: containerSize, context: context)
            XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(100), height: .flexible))
            XCTAssertEqual(spacer.size, CGSize(width: 100, height: 200))
        }

        // with height
        do {
            var spacer = SpacerNode(height: 100)

            let containerSize = CGSize(width: 200, height: 200)
            let context = ComposeNodeLayoutContext(scaleFactor: 2)

            let sizing = spacer.layout(containerSize: containerSize, context: context)
            XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .fixed(100)))
            XCTAssertEqual(spacer.size, CGSize(width: 200, height: 100))
        }

        // with both width and height
        do {
            var spacer = SpacerNode(width: 100, height: 200)

            let containerSize = CGSize(width: 200, height: 200)
            let context = ComposeNodeLayoutContext(scaleFactor: 2)

            let sizing = spacer.layout(containerSize: containerSize, context: context)
            XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(100), height: .fixed(200)))
            XCTAssertEqual(spacer.size, CGSize(width: 100, height: 200))
        }
    }

    func test_renderableItems() {
        var spacer = SpacerNode()

        let containerSize = CGSize(width: 200, height: 200)
        let context = ComposeNodeLayoutContext(scaleFactor: 2)

        let sizing = spacer.layout(containerSize: containerSize, context: context)
        XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .flexible))
        XCTAssertEqual(spacer.size, containerSize)

        let items = spacer.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertTrue(items.isEmpty)
    }

    func test_modifier_width() {
        var spacer = SpacerNode()
        spacer = spacer.width(100)

        let containerSize = CGSize(width: 200, height: 200)
        let context = ComposeNodeLayoutContext(scaleFactor: 2)

        let sizing = spacer.layout(containerSize: containerSize, context: context)
        XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(100), height: .flexible))
        XCTAssertEqual(spacer.size, CGSize(width: 100, height: 200))

        spacer = spacer.width(100)
    }

    func test_modifier_height() {
        var spacer = SpacerNode()
        spacer = spacer.height(100)

        let containerSize = CGSize(width: 200, height: 200)
        let context = ComposeNodeLayoutContext(scaleFactor: 2)

        let sizing = spacer.layout(containerSize: containerSize, context: context)
        XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .fixed(100)))
        XCTAssertEqual(spacer.size, CGSize(width: 200, height: 100))

        spacer = spacer.height(100)
    }
}
