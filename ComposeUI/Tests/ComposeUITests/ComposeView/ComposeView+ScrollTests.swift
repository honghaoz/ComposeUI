//
//  ComposeView+ScrollTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
//

import ChouTiTest

import ComposeUI

class ComposeView_ScrollTests: XCTestCase {

    func test_scrollBehavior() {
        // when content size is smaller than bounds size
        do {
            let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
            contentView.setContent {
                ColorNode(.red)
                    .frame(width: 50, height: 50)
            }
            contentView.refresh(animated: false)

            // expect the view is not scrollable since the content size is smaller than bounds size
            expect(contentView.isScrollable) == false

            // when set to always scrollable
            contentView.scrollBehavior = .always
            contentView.refresh(animated: false)
            expect(contentView.isScrollable) == true

            // when set to never scrollable
            contentView.scrollBehavior = .never
            contentView.refresh(animated: false)
            expect(contentView.isScrollable) == false
        }

        // when content size is equal to bounds size
        do {
            let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
            contentView.setContent {
                ColorNode(.red)
                    .frame(width: 100, height: 100)
            }
            contentView.refresh(animated: false)

            // expect the view is not scrollable since the content size is equal to bounds size
            expect(contentView.isScrollable) == false

            // when set to always scrollable
            contentView.scrollBehavior = .always
            contentView.refresh(animated: false)
            expect(contentView.isScrollable) == true

            // when set to never scrollable
            contentView.scrollBehavior = .never
            contentView.refresh(animated: false)
            expect(contentView.isScrollable) == false
        }

        // when content size is larger than bounds size
        do {
            let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
            contentView.setContent {
                ColorNode(.red)
                    .frame(width: 150, height: 150)
            }
            contentView.refresh(animated: false)

            // expect the view is scrollable since the content size is larger than bounds size
            expect(contentView.isScrollable) == true

            // when set to never scrollable
            contentView.scrollBehavior = .never
            contentView.refresh(animated: false)
            expect(contentView.isScrollable) == false

            // when set to always scrollable
            contentView.scrollBehavior = .always
            contentView.refresh(animated: false)
            expect(contentView.isScrollable) == true
        }
    }
}
