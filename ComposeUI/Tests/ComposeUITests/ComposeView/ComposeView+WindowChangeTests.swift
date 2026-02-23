//
//  ComposeView+WindowChangeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/3/25.
//

import XCTest
import Foundation

@testable import ComposeUI

class ComposeView_WindowChangeTests: XCTestCase {

    func test_windowDidChange() throws {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let window = TestWindow()
        window.contentScaleFactor = 1

        var renderCount = 0
        var refreshCount = 0
        var isAnimated: Bool?
        let view = ComposeView {
            renderCount += 1
            LayerNode()
                .animation(.linear())
                .onUpdate { _, context in
                    isAnimated = context.animationTiming != nil
                    refreshCount += 1
                }
        }

        view.frame = frame
        window.addSubview(view)

        XCTAssertEqual(renderCount, 0)
        XCTAssertEqual(refreshCount, 0)
        XCTAssertEventuallyEqual(renderCount, 1)
        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(isAnimated, false)
        isAnimated = nil

        view.removeFromSuperview()
        XCTAssertEqual(renderCount, 1)
        XCTAssertEqual(refreshCount, 1)

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3)) // flush the pending refresh
        XCTAssertEqual(renderCount, 1) // setting window to nil should not trigger a new render
        XCTAssertEqual(refreshCount, 1)

        window.addSubview(view)
        XCTAssertEqual(renderCount, 1)
        XCTAssertEventuallyEqual(renderCount, 2) // adding to the same window again should trigger a new render
        XCTAssertEqual(refreshCount, 2)
        XCTAssertEqual(isAnimated, false)
        isAnimated = nil

        let window2 = TestWindow()
        window.contentScaleFactor = 4
        window2.addSubview(view)
        XCTAssertEqual(renderCount, 2)
        XCTAssertEventuallyEqual(renderCount, 3) // adding to a different window should trigger a new render
        XCTAssertEqual(refreshCount, 3)
        XCTAssertEqual(isAnimated, false)
        isAnimated = nil
    }
}
