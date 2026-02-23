//
//  ComposeView+CachedLayoutTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
//

import XCTest

import ComposeUI

class ComposeView_CachedLayoutTests: XCTestCase {

    func test_noLayoutOnScroll() {
        var contentMakeCount = 0
        let state = TestNode.State()

        let view = ComposeView {
            contentMakeCount += 1
            TestNode(state: state)
                .frame(width: 100, height: 300)
        }

        view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        view.setNeedsLayout()
        view.layoutIfNeeded()

        XCTAssertEqual(contentMakeCount, 1) // initial content make
        XCTAssertEqual(state.layoutCount, 1) // initial layout
        XCTAssertEqual(state.renderCount, 1) // initial render

        view.setContentOffset(CGPoint(x: 0, y: 100), animated: false)
        view.setNeedsLayout()
        view.layoutIfNeeded()

        XCTAssertEqual(contentMakeCount, 1) // scroll should not trigger content make
        XCTAssertEqual(state.layoutCount, 1) // scroll should not trigger layout
        XCTAssertEqual(state.renderCount, 2) // scroll should trigger render

        view.setContentOffset(CGPoint(x: 0, y: 200), animated: false)
        view.setNeedsLayout()
        view.layoutIfNeeded()

        XCTAssertEqual(contentMakeCount, 1) // scroll should not trigger content make
        XCTAssertEqual(state.layoutCount, 1) // scroll should not trigger layout
        XCTAssertEqual(state.renderCount, 3) // scroll should trigger render

        view.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
        view.setNeedsLayout()
        view.layoutIfNeeded()

        XCTAssertEqual(contentMakeCount, 2) // size change should trigger content make
        XCTAssertEqual(state.layoutCount, 2) // size change should trigger layout
        XCTAssertEqual(state.renderCount, 4) // size change should trigger render

        view.frame = .zero
        view.setNeedsLayout()
        view.layoutIfNeeded()

        XCTAssertEqual(contentMakeCount, 3) // size change should trigger content make
        XCTAssertEqual(state.layoutCount, 3) // size change should trigger layout
        XCTAssertEqual(state.renderCount, 5) // size change should trigger render

        view.setContentOffset(CGPoint(x: 0, y: 110), animated: false)
        view.setNeedsLayout()
        view.layoutIfNeeded()

        XCTAssertEqual(contentMakeCount, 3) // scroll should not trigger content make
        XCTAssertEqual(state.layoutCount, 3) // scroll should not trigger layout
        XCTAssertEqual(state.renderCount, 6) // scroll should trigger render
    }
}
