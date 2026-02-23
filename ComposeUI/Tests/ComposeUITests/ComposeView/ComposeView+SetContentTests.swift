//
//  ComposeView+SetContentTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/6/25.
//

import XCTest
import Foundation

import ComposeUI

class ComposeView_SetContentTests: XCTestCase {

    func test_setContent() {
        var renderCount = 0
        var isAnimated: Bool?
        let contentView = ComposeView {
            renderCount += 1
            LayerNode()
                .animation(.linear())
                .onUpdate { _, context in
                    isAnimated = context.animationTiming != nil
                }
        }

        contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

        contentView.refresh()
        XCTAssertEqual(renderCount, 1)
        XCTAssertEqual(isAnimated, false) // initial render is always not animated
        isAnimated = nil

        contentView.setContent {
            renderCount += 1
            LayerNode()
                .animation(.linear())
                .onUpdate { _, context in
                    isAnimated = context.animationTiming != nil
                }
        }

        XCTAssertEventuallyEqual(renderCount, 2)
        XCTAssertEqual(isAnimated, true)
    }
}
