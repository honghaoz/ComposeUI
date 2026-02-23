//
//  RunLoopTests.swift
//  ComposéUI
//
//  Created by Honghao on 5/10/25.
//

import XCTest

@testable import ComposeUI

class RunLoopTests: XCTestCase {

    func test_onNextRunLoop() {
        let expectation = expectation(description: "onNextRunLoop")

        var isExecuted = false
        onNextRunLoop {
            isExecuted = true
            expectation.fulfill()
        }

        XCTAssertFalse(isExecuted)
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(isExecuted)
    }
}
