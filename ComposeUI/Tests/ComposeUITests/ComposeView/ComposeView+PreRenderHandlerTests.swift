//
//  ComposeView+PreRenderHandlerTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/3/25.
//

import XCTest
import Foundation

@testable import ComposeUI

class ComposeView_PreRenderHandlerTests: XCTestCase {

    func test_preRenderHandler() {
        // given: a compose view with a content
        let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.setContent {
            ColorNode(.red)
                .frame(width: 100, height: 200)
        }

        // set up the pre-render handler to track the callback arguments
        var preRenderCallCount = 0
        var callbackContentSize: CGSize?
        var callbackRenderBounds: CGRect?
        var callbackRenderType: ComposeView.RenderType?
        #if DEBUG
        var eventOrder: [String] = []
        var requestedVisibleBounds: CGRect?
        #endif

        view.onPreRender { view, context in
            preRenderCallCount += 1
            callbackContentSize = context.contentSize
            callbackRenderBounds = context.renderBounds
            callbackRenderType = context.renderType
            #if DEBUG
            eventOrder.append("preRender")
            #endif

            view.setContentOffset(CGPoint(x: 0, y: 100), animated: false)
        }

        #if DEBUG
        view.debug { _, event in
            if case .renderWillRequestRenderableItems(let visibleBounds) = event {
                requestedVisibleBounds = visibleBounds
                eventOrder.append("renderItems")
            }
        }
        #endif

        // when: the view is refreshed initially
        view.refresh(animated: false)

        // then: the pre-render handler should be called with the correct arguments
        XCTAssertEqual(preRenderCallCount, 1)
        XCTAssertEqual(callbackContentSize, CGSize(width: 100, height: 200))
        XCTAssertEqual(callbackRenderBounds, CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(callbackRenderType, .refresh(isAnimated: false))

        // then: the content offset should be updated
        XCTAssertEqual(view.contentOffset.y, 100)

        #if DEBUG
        XCTAssertEqual(eventOrder, ["preRender", "renderItems"])
        XCTAssertEqual(requestedVisibleBounds, CGRect(x: 0, y: 100, width: 100, height: 100))
        #endif

        // when: the view is scrolled
        view.setContentOffset(CGPoint(x: 0, y: 10), animated: false)
        view.layoutIfNeeded()

        // then: the pre-render handler should be called with the correct arguments
        XCTAssertEqual(preRenderCallCount, 2)
        XCTAssertEqual(callbackContentSize, CGSize(width: 100, height: 200))
        XCTAssertEqual(callbackRenderBounds, CGRect(x: 0, y: 10, width: 100, height: 100))
        XCTAssertEqual(callbackRenderType, .scroll(previousBounds: CGRect(x: 0, y: 100, width: 100, height: 100)))
        XCTAssertEqual(view.contentOffset.y, 100)

        #if DEBUG
        XCTAssertEqual(eventOrder, ["preRender", "renderItems", "preRender", "renderItems"])
        XCTAssertEqual(requestedVisibleBounds, CGRect(x: 0, y: 100, width: 100, height: 100))
        #endif

        XCTAssertEqual(view.bounds, CGRect(x: 0, y: 100, width: 100, height: 100))

        // when: the view is resized
        view.frame.size = CGSize(width: 150, height: 150)
        XCTAssertEqual(view.bounds, CGRect(x: 0, y: 50, width: 150, height: 150)) // y: 50 (maxOffsetY) = 200 - 150

        view.layoutIfNeeded()

        // then: the pre-render handler should be called with the correct arguments
        XCTAssertEqual(preRenderCallCount, 3)
        XCTAssertEqual(callbackContentSize, CGSize(width: 150, height: 200))
        XCTAssertEqual(callbackRenderBounds, CGRect(x: 0, y: 50, width: 150, height: 150))
        XCTAssertEqual(callbackRenderType, .boundsChange(previousBounds: CGRect(x: 0, y: 100, width: 100, height: 100)))
        XCTAssertEqual(view.contentOffset.y, 100)

        #if DEBUG
        XCTAssertEqual(eventOrder, ["preRender", "renderItems", "preRender", "renderItems", "preRender", "renderItems"])
        XCTAssertEqual(requestedVisibleBounds, CGRect(x: -25, y: 100, width: 150, height: 150))
        #endif
    }

    func test_preRenderHandler_boundsSizeChanged() {
        // test that the pre-render handler is called with bounds size changed
        // should expect a follow-up layout to be scheduled

        // given: a compose view with a content
        let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.setContent {
            ColorNode(.red)
                .frame(width: 100, height: 200)
        }

        // set up the pre-render handler that changes the bounds size
        view.onPreRender { view, _ in
            view.bounds = CGRect(x: 0, y: 10, width: 150, height: 150)
        }

        // when: the view is refreshed
        view.refresh(animated: false)

        // then: the old bounds should be used for the immediate render
        XCTAssertEqual(view.test.lastRenderBounds, CGRect(x: 0, y: 10, width: 100, height: 100))

        // then: the follow-up render should use the new bounds eventually
        XCTAssertEventuallyEqual(view.test.lastRenderBounds, CGRect(x: 0, y: 10, width: 150, height: 150))
    }
}
