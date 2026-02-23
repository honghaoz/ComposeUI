//
//  UIScrollView+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 2/22/26.
//

import UIKit
import XCTest

@testable import ComposeUI

class UIScrollView_ExtensionsTests: XCTestCase {

    func test_offsets() {
        let scrollView = UIScrollView()
        scrollView.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
        scrollView.contentSize = CGSize(width: 300, height: 500)
        scrollView.contentInset = UIEdgeInsets(top: 10, left: 20, bottom: 30, right: 40)
        scrollView.contentInsetAdjustmentBehavior = .never

        XCTAssertEqual(scrollView.minOffsetX, -20)
        XCTAssertEqual(scrollView.maxOffsetX, 240)
        XCTAssertEqual(scrollView.minOffsetY, -10)
        XCTAssertEqual(scrollView.maxOffsetY, 330)
    }

    func test_canScroll() {
        let scrollView = UIScrollView()
        scrollView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        scrollView.contentSize = CGSize(width: 180, height: 220)
        scrollView.contentInset = UIEdgeInsets(top: 8, left: 6, bottom: 4, right: 2)
        scrollView.contentInsetAdjustmentBehavior = .never

        scrollView.contentOffset = CGPoint(x: scrollView.minOffsetX, y: scrollView.minOffsetY)
        XCTAssertFalse(scrollView.canScrollToLeft)
        XCTAssertTrue(scrollView.canScrollToRight)
        XCTAssertFalse(scrollView.canScrollToTop)
        XCTAssertTrue(scrollView.canScrollToBottom)

        scrollView.contentOffset = CGPoint(x: scrollView.maxOffsetX, y: scrollView.maxOffsetY)
        XCTAssertTrue(scrollView.canScrollToLeft)
        XCTAssertFalse(scrollView.canScrollToRight)
        XCTAssertTrue(scrollView.canScrollToTop)
        XCTAssertFalse(scrollView.canScrollToBottom)
    }
}
