//
//  Optional+AssertTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/31/25.
//

import XCTest

@testable import ComposeUI

class Optional_AssertTests: XCTestCase {

    func test_assert() {
        let optional: Int? = 1
        XCTAssertEqual(optional.assertNotNil(), 1)
    }
}
