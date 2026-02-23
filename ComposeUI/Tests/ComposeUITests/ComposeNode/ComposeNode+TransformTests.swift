//
//  ComposeNode+TransformTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 1/28/26.
//

import XCTest

@testable import ComposeUI

class ComposeNode_TransformTests: XCTestCase {

    func test_map_anyComposeNode() throws {
        var node: any ComposeNode = ViewNode()
            .map { node in
                node.background {
                    ColorNode(.red)
                }
            }

        node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
        let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))
        let backgroundItem = try XCTUnwrap(renderableItems.first)

        let contentView = ComposeView()
        let renderable = backgroundItem.make(RenderableMakeContext(initialFrame: .zero, contentView: contentView))
        let updateContext = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
        backgroundItem.update(renderable, updateContext)

        XCTAssertEqual(renderable.layer.backgroundColor, UIColor.red.cgColor)
    }

    func test_map_sameType() throws {
        let baseNode = ViewNode()
        var base = baseNode
        _ = base.layout(containerSize: CGSize(width: 200, height: 50), context: ComposeNodeLayoutContext(scaleFactor: 2))
        let baseSize = base.size

        var updated = baseNode
            .map { node in
                node.interactive(false)
            }
        _ = updated.layout(containerSize: CGSize(width: 200, height: 50), context: ComposeNodeLayoutContext(scaleFactor: 2))
        let renderableItems = updated.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 200, height: 50)))
        let item = try XCTUnwrap(renderableItems.first)

        let contentView = ComposeView()
        let renderable = item.make(RenderableMakeContext(initialFrame: .zero, contentView: contentView))
        let updateContext = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
        item.update(renderable, updateContext)

        let view = try XCTUnwrap(renderable.view)
        XCTAssertFalse(view.isUserInteractionEnabled)
    }
}
