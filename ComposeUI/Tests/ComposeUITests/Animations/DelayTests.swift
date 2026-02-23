//
//  DelayTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/21.
//

import Foundation
import QuartzCore

import ChouTiTest

@testable import ComposeUI

class DelayTests: XCTestCase {

    func test_positiveDelay() {
        var isExecuted = false
        let startTime = CACurrentMediaTime()
        var delayTime: CFTimeInterval = 0
        delay(0.01) {
            let endTime = CACurrentMediaTime()
            delayTime = endTime - startTime
            expect(Thread.isMainThread) == true
            isExecuted = true
        }
        expect(isExecuted) == false
        expect(isExecuted).toEventually(beTrue(), timeout: 0.05)
        expect(delayTime).to(beApproximatelyEqual(to: 0.01, within: 1e-2))
    }

    func test_negativeDelay() {
        var isExecuted = false
        delay(-0.01) {
            expect(Thread.isMainThread) == true
            isExecuted = true
        }
        expect(isExecuted) == true
    }

    func test_zeroDelay() {
        var isExecuted = false
        delay(0) {
            expect(Thread.isMainThread) == true
            isExecuted = true
        }
        expect(isExecuted) == true
    }
}
