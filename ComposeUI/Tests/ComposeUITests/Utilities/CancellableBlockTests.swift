//
//  CancellableBlockTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/13/24.
//

import XCTest

@testable import ComposeUI

class CancellableBlockTests: XCTestCase {

    func test_notCancelled() {
        var isExecuted: Bool?
        var isCancelled: Bool?

        let block = CancellableBlock {
            isExecuted = true
        } cancel: {
            isCancelled = true
        }

        block.execute()

        XCTAssertEqual(isExecuted, true)
        XCTAssertNil(isCancelled)
    }

    func test_cancelled() {
        var isExecuted: Bool?
        var isCancelled: Bool?

        let block = CancellableBlock {
            isExecuted = true
        } cancel: {
            isCancelled = true
        }

        block.cancel()

        XCTAssertNil(isExecuted)
        XCTAssertEqual(isCancelled, true)

        block.execute()

        XCTAssertNil(isExecuted)
        XCTAssertEqual(isCancelled, true)
    }
}
