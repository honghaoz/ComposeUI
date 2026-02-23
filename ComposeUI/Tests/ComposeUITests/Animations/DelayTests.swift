//
//  DelayTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/21.
//

import Foundation
import QuartzCore
import XCTest

@testable import ComposeUI

class DelayTests: XCTestCase {

    func test_positiveDelay() {
        var isExecuted = false
        let startTime = CACurrentMediaTime()
        var delayTime: CFTimeInterval = 0
        delay(0.01) {
            let endTime = CACurrentMediaTime()
            delayTime = endTime - startTime
            XCTAssertTrue(Thread.isMainThread)
            isExecuted = true
        }
        XCTAssertFalse(isExecuted)
        XCTAssertEventuallyEqual(isExecuted, true, timeout: 0.05)
        XCTAssertEqual(delayTime, 0.01, accuracy: 1e-2)
    }

    func test_negativeDelay() {
        var isExecuted = false
        delay(-0.01) {
            XCTAssertTrue(Thread.isMainThread)
            isExecuted = true
        }
        XCTAssertTrue(isExecuted)
    }

    func test_zeroDelay() {
        var isExecuted = false
        delay(0) {
            XCTAssertTrue(Thread.isMainThread)
            isExecuted = true
        }
        XCTAssertTrue(isExecuted)
    }
}
