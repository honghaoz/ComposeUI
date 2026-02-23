//
//  ColorNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/2/25.
//

import XCTest

@testable import ComposeUI

class ColorNodeTests: XCTestCase {

    func test_init() throws {
        _ = ColorNode(.red)
    }

    func test_id() throws {
        XCTAssertEqual(ColorNode(.red).id.id, "C")
    }

    func test_size() throws {
        XCTAssertEqual(ColorNode(.red).size, .zero)
    }

    func test_layout() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = ColorNode(.red)
        let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
        XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .flexible))
        XCTAssertEqual(node.size, CGSize(width: 100, height: 100))
    }

    func test_renderableItems() throws {
        let context = ComposeNodeLayoutContext(scaleFactor: 1)
        var node = ColorNode(.red)
        _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

        // when visible bounds intersects with the node's frame
        do {
            let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
            let items = node.renderableItems(in: visibleBounds)
            XCTAssertEqual(items.count, 1)

            let item = items[0]
            XCTAssertEqual(item.id.id, "C")
            XCTAssertEqual(item.frame, CGRect(x: 0, y: 0, width: 100, height: 100))

            // make
            do {
                let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: nil))
                XCTAssertEqual(renderable.layer.frame, CGRect(x: 1, y: 2, width: 3, height: 4))
            }

            XCTAssertNil(item.willInsert)
            XCTAssertNil(item.didInsert)
            XCTAssertNil(item.willUpdate)

            // update
            do {
                // when with light theme
                do {
                    let contentView = ComposeView()
                    let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

                    // without animations
                    do {
                        let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
                        item.update(renderable, context)
                        let layer = renderable.layer
                        XCTAssertEqual(layer.backgroundColor, UIColor.red.cgColor)
                        XCTAssertNil(layer.animation(forKey: "backgroundColor"))
                    }

                    // with animations
                    do {
                        let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: .easeInEaseOut(), contentView: contentView)
                        item.update(renderable, context)
                        let layer = renderable.layer
                        XCTAssertEqual(layer.backgroundColor, UIColor.red.cgColor)

                        let animation = try XCTUnwrap(layer.animation(forKey: "backgroundColor") as? CABasicAnimation)
                        XCTAssertEqual(animation.duration, ComposeAnimations.defaultAnimationDuration)
                        XCTAssertEqual(animation.toValue as? CGColor, UIColor.red.cgColor) // swiftlint:disable:this force_cast
                    }
                }

                // conditional update
                do {
                    let contentView = ComposeView()
                    let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

                    // scroll doesn't trigger update
                    do {
                        let context = RenderableUpdateContext(updateType: .scroll, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
                        item.update(renderable, context)
                        let layer = renderable.layer
                        XCTAssertNil(layer.backgroundColor) // doesn't update
                    }

                    // bounds change doesn't trigger update
                    do {
                        let context = RenderableUpdateContext(updateType: .boundsChange, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
                        item.update(renderable, context)
                        let layer = renderable.layer
                        XCTAssertNil(layer.backgroundColor) // doesn't update
                    }
                }
            }

            XCTAssertNil(item.willRemove)
            XCTAssertNil(item.didRemove)
            XCTAssertNil(item.transition)
            XCTAssertNil(item.animationTiming)
        }

        // when visible bounds does not intersect with the node's frame
        do {
            let visibleBounds = CGRect(x: 0, y: 100, width: 100, height: 100)
            let items = node.renderableItems(in: visibleBounds)
            XCTAssertEqual(items.count, 0)
        }
    }
}
