//
//  ComposeView+RenderableTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
//

import XCTest

@testable import ComposeUI

class ComposeView_RenderableTests: XCTestCase {

    func test_lifecycle() {
        let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        var willInsertCount = 0
        var didInsertCount = 0
        var willUpdateCount = 0
        var updateCount = 0
        var willRemoveCount = 0
        var didRemoveCount = 0

        // show view
        contentView.setContent {
            ViewNode(
                willInsert: { view, context in
                    willInsertCount += 1
                },
                didInsert: { view, context in
                    didInsertCount += 1
                },
                willUpdate: { view, context in
                    willUpdateCount += 1
                },
                update: { view, context in
                    updateCount += 1
                },
                willRemove: { view, context in
                    willRemoveCount += 1
                },
                didRemove: { view, context in
                    didRemoveCount += 1
                }
            )
        }
        contentView.refresh(animated: false)

        XCTAssertEqual(willInsertCount, 1)
        XCTAssertEqual(didInsertCount, 1)
        XCTAssertEqual(updateCount, 1)
        XCTAssertEqual(willRemoveCount, 0)
        XCTAssertEqual(didRemoveCount, 0)

        // remove view
        contentView.setContent {
            EmptyNode()
        }

        contentView.refresh(animated: false)

        XCTAssertEqual(willInsertCount, 1)
        XCTAssertEqual(didInsertCount, 1)
        XCTAssertEqual(willUpdateCount, 1)
        XCTAssertEqual(updateCount, 1)
        XCTAssertEqual(willRemoveCount, 1)
        XCTAssertEqual(didRemoveCount, 1)
    }

    func test_updateContext() {
        // test the update context provided to the renderable update block is correct

        // given: a compose view
        var willUpdateContext: RenderableUpdateContext?
        var updateContext: RenderableUpdateContext?
        let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 150))

        view.setContent {
            ViewNode()
                .frame(width: 100, height: 200)
                .willUpdate { renderable, context in
                    willUpdateContext = context
                }
                .onUpdate { renderable, context in
                    updateContext = context
                }
        }

        // when: refresh the view initially
        view.refresh(animated: false)

        // then: expect the update context is correct
        XCTAssertEqual(
            willUpdateContext,
            RenderableUpdateContext(
                updateType: .insert,
                oldFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
                newFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
                animationTiming: nil,
                contentView: view
            )
        )
        XCTAssertEqual(
            updateContext,
            RenderableUpdateContext(
                updateType: .insert,
                oldFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
                newFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
                animationTiming: nil,
                contentView: view
            )
        )

        // when: refresh the view again
        view.refresh(animated: false)

        // then: expect the update context is correct
        XCTAssertEqual(
            willUpdateContext,
            RenderableUpdateContext(
                updateType: .refresh,
                oldFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
                newFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
                animationTiming: nil,
                contentView: view
            )
        )
        XCTAssertEqual(
            updateContext,
            RenderableUpdateContext(
                updateType: .refresh,
                oldFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
                newFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
                animationTiming: nil,
                contentView: view
            )
        )

        // when: scroll the view
        view.setContentOffset(CGPoint(x: 0, y: 10), animated: false)
        view.layoutIfNeeded()

        // then: expect the update context is correct
        XCTAssertEqual(
            willUpdateContext,
            RenderableUpdateContext(
                updateType: .scroll,
                oldFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
                newFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
                animationTiming: nil,
                contentView: view
            )
        )
        XCTAssertEqual(
            updateContext,
            RenderableUpdateContext(
                updateType: .scroll,
                oldFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
                newFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
                animationTiming: nil,
                contentView: view
            )
        )

        // when: resize the view
        view.frame.size = CGSize(width: 200, height: 200)
        view.layoutIfNeeded()

        // then: expect the update context is correct
        XCTAssertEqual(
            willUpdateContext,
            RenderableUpdateContext(
                updateType: .boundsChange,
                oldFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
                newFrame: CGRect(x: 50, y: 0, width: 100, height: 200),
                animationTiming: nil,
                contentView: view
            )
        )
        XCTAssertEqual(
            updateContext,
            RenderableUpdateContext(
                updateType: .boundsChange,
                oldFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
                newFrame: CGRect(x: 50, y: 0, width: 100, height: 200),
                animationTiming: nil,
                contentView: view
            )
        )
    }
}
