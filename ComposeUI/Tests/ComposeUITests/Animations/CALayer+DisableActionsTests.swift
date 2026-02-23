//
//  CALayer+DisableActionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/8/25.
//

import XCTest

@testable import ComposeUI

class CALayer_DisableActionsTests: XCTestCase {

    func test_disableActions() throws {
        let frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        let layer = CALayer()
        layer.frame = frame

        let window = TestWindow()
        window.layer.addSublayer(layer)

        // wait for the layer to have a presentation layer
        RunLoop.main.run(until: Date(timeInterval: 0.05, since: Date()))

        // with disableAction
        do {
            layer.disableActions(for: ["position", "bounds"]) {
                layer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
            }
            XCTAssertNil(layer.animationKeys())
        }

        // with partial disableAction
        do {
            layer.disableActions(for: ["position"]) {
                layer.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
            }
            XCTAssertEqual(layer.animationKeys(), ["bounds"])
        }

        // without disableAction
        do {
            layer.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
            XCTAssertEqual(layer.animationKeys(), ["position", "bounds"])
        }
    }
}
