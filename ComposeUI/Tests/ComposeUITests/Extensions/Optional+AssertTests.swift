//
//  Optional+AssertTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/31/25.
//

import ChouTiTest

@testable import ComposeUI

class Optional_AssertTests: XCTestCase {

    func test_assert() {
        let optional: Int? = 1
        expect(optional.assertNotNil()) == 1
    }
}
