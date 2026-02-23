//
//  ComposeView+ClippingTests.swift
//  ComposéUI
//
//  Created by Honghao on 5/10/25.
//

import XCTest

import ComposeUI

class ComposeView_ClippingTests: XCTestCase {

    func test_clippingBehavior() {
        // when view is not scrollable
        do {
            let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
            contentView.setContent {
                ColorNode(.red)
                    .frame(width: 50, height: 50)
            }
            contentView.refresh(animated: false)

            // should not clip
            XCTAssertFalse(contentView.clipsToBounds)

            // when set to always clipping
            contentView.clippingBehavior = .always
            contentView.refresh(animated: false)
            XCTAssertTrue(contentView.clipsToBounds)

            // when set to never clipping
            contentView.clippingBehavior = .never
            contentView.refresh(animated: false)
            XCTAssertFalse(contentView.clipsToBounds)
        }

        do {
            let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
            contentView.setContent {
                ColorNode(.red)
                    .frame(width: 100, height: 100)
            }
            contentView.refresh(animated: false)

            // should not clip
            XCTAssertFalse(contentView.clipsToBounds)

            // when set to always clipping
            contentView.clippingBehavior = .always
            contentView.refresh(animated: false)
            XCTAssertTrue(contentView.clipsToBounds)

            // when set to never clipping
            contentView.clippingBehavior = .never
            contentView.refresh(animated: false)
            XCTAssertFalse(contentView.clipsToBounds)
        }

        // when view is scrollable
        do {
            let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
            contentView.setContent {
                ColorNode(.red)
                    .frame(width: 150, height: 50)
            }
            contentView.refresh(animated: false)

            // should clip
            XCTAssertTrue(contentView.clipsToBounds)

            // when set to always clipping
            contentView.clippingBehavior = .always
            contentView.refresh(animated: false)
            XCTAssertTrue(contentView.clipsToBounds)

            // when set to never clipping
            contentView.clippingBehavior = .never
            contentView.refresh(animated: false)
            XCTAssertFalse(contentView.clipsToBounds)
        }
    }
}
