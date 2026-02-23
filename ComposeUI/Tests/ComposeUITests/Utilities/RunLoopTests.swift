//
//  RunLoopTests.swift
//  ComposéUI
//
//  Created by Honghao on 5/10/25.
//

import ChouTiTest

@testable import ComposeUI

class RunLoopTests: XCTestCase {

    func test_onNextRunLoop() {
        let expectation = expectation(description: "onNextRunLoop")

        var isExecuted = false
        onNextRunLoop {
            isExecuted = true
            expectation.fulfill()
        }

        expect(isExecuted) == false
        wait(for: [expectation], timeout: 1)
        expect(isExecuted) == true
    }
}
