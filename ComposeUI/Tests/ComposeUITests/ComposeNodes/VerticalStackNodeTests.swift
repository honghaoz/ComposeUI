//
//  VerticalStackNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/31/25.
//

import XCTest

import ComposeUI

class VerticalStackNodeTests: XCTestCase {

    func test_typealias() {
        _ = VerticalStack {}
        _ = VerticalStackNode {}
    }

    func test_empty() {
        var node = VerticalStack {}

        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

        XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(0), height: .fixed(0)))
        XCTAssertEqual(node.size, .zero)
    }

    func test_flexibleWidth_flexibleHeight() {
        var node = VerticalStack {
            LayerNode()
            LayerNode()
        }

        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

        XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .flexible))
        XCTAssertEqual(node.size, CGSize(width: 50, height: 100))

        let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

        guard items.count == 2 else {
            XCTFail("Expected 2 items")
            return
        }

        XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 50, height: 50))
        XCTAssertEqual(items[1].frame, CGRect(x: 0, y: 50, width: 50, height: 50))
    }

    func test_flexibleWidth_flexibleHeight_spacing() {
        var node = VerticalStack(spacing: 10) {
            LayerNode()
            LayerNode()
        }

        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

        XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .range(min: 10, max: .infinity)))
        XCTAssertEqual(node.size, CGSize(width: 50, height: 100))

        let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

        guard items.count == 2 else {
            XCTFail("Expected 2 items")
            return
        }

        XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 50, height: 45))
        XCTAssertEqual(items[1].frame, CGRect(x: 0, y: 55, width: 50, height: 45))
    }

    func test_flexibleWidth_fixedHeight() {
        var node = VerticalStack {
            LayerNode().frame(width: .flexible, height: 30)
            LayerNode().frame(width: .flexible, height: 20)
        }

        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

        XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .fixed(50)))
        XCTAssertEqual(node.size, CGSize(width: 50, height: 50))

        let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

        guard items.count == 2 else {
            XCTFail("Expected 2 items")
            return
        }

        XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 50, height: 30))
        XCTAssertEqual(items[1].frame, CGRect(x: 0, y: 30, width: 50, height: 20))
    }

    func test_fixedWidth_flexibleHeight() {
        var node = VerticalStack {
            LayerNode().frame(width: 20, height: .flexible)
            LayerNode().frame(width: 30, height: .flexible)
        }

        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

        XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(30), height: .flexible))
        XCTAssertEqual(node.size, CGSize(width: 30, height: 100))

        let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

        guard items.count == 2 else {
            XCTFail("Expected 2 items")
            return
        }

        XCTAssertEqual(items[0].frame, CGRect(x: 5, y: 0, width: 20, height: 50))
        XCTAssertEqual(items[1].frame, CGRect(x: 0, y: 50, width: 30, height: 50))
    }

    func test_fixedWidth_fixedHeight() {
        var node = VerticalStack {
            LayerNode().frame(width: 30, height: 50)
            LayerNode().frame(width: 20, height: 20)
        }

        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

        XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(30), height: .fixed(70)))
        XCTAssertEqual(node.size, CGSize(width: 30, height: 70))

        let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

        guard items.count == 2 else {
            XCTFail("Expected 2 items")
            return
        }

        XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 30, height: 50))
        XCTAssertEqual(items[1].frame, CGRect(x: 5, y: 50, width: 20, height: 20))
    }

    func test_fixedWidth_fixedHeight_spacer() {
        var node = VerticalStack {
            LayerNode().frame(width: 30, height: 50)
            SpacerNode()
            LayerNode().frame(width: 20, height: 20)
        }

        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

        XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(30), height: .range(min: 70, max: .infinity)))
        XCTAssertEqual(node.size, CGSize(width: 30, height: 100))

        let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

        guard items.count == 2 else {
            XCTFail("Expected 2 items")
            return
        }

        XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 30, height: 50))
        XCTAssertEqual(items[1].frame, CGRect(x: 5, y: 80, width: 20, height: 20))
    }

    func test_fixedWidth_fixedHeight_alignment() {
        // left alignment
        do {
            var node = VerticalStack(alignment: .left) {
                LayerNode().frame(width: 30, height: 50)
                LayerNode().frame(width: 20, height: 20)
            }

            let context = ComposeNodeLayoutContext(scaleFactor: 1)
            let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

            XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(30), height: .fixed(70)))
            XCTAssertEqual(node.size, CGSize(width: 30, height: 70))

            let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

            guard items.count == 2 else {
                XCTFail("Expected 2 items")
                return
            }

            XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 30, height: 50))
            XCTAssertEqual(items[1].frame, CGRect(x: 0, y: 50, width: 20, height: 20))
        }

        // right alignment
        do {
            var node = VerticalStack(alignment: .right) {
                LayerNode().frame(width: 30, height: 50)
                LayerNode().frame(width: 20, height: 20)
            }

            let context = ComposeNodeLayoutContext(scaleFactor: 1)
            let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

            XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(30), height: .fixed(70)))
            XCTAssertEqual(node.size, CGSize(width: 30, height: 70))

            let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

            guard items.count == 2 else {
                XCTFail("Expected 2 items")
                return
            }

            XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 30, height: 50))
            XCTAssertEqual(items[1].frame, CGRect(x: 10, y: 50, width: 20, height: 20))
        }
    }

    func test_renderableItems_filtersOffscreenChildren() {
        var node = VerticalStack {
            LayerNode().frame(width: 10, height: 10)
            LayerNode().frame(width: 10, height: 10)
            LayerNode().frame(width: 10, height: 10)
        }

        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        _ = node.layout(containerSize: CGSize(width: 10, height: 30), context: context)

        let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))

        guard items.count == 1 else {
            XCTFail("Expected 1 item")
            return
        }

        XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    func test_renderableItems_includesOffsetChildren() {
        var node = VerticalStack {
            LayerNode().frame(width: 10, height: 10)
            LayerNode().frame(width: 10, height: 10)
                .offset(x: 0, y: -10)
        }

        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        _ = node.layout(containerSize: CGSize(width: 10, height: 20), context: context)

        let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))

        guard items.count == 2 else {
            XCTFail("Expected 2 items")
            return
        }

        XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 10, height: 10))
        XCTAssertEqual(items[1].frame, CGRect(x: 0, y: 0, width: 10, height: 10))
    }
}
