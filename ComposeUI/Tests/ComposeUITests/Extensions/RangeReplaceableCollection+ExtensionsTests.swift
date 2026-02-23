//
//  RangeReplaceableCollection+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/3/24.
//

import XCTest

@testable import ComposeUI

class RangeReplaceableCollection_ExtensionsTests: XCTestCase {

    func testSwapRemove() {
        var array = [1, 2, 3, 4, 5]
        let removed = array.swapRemove(at: 2)
        XCTAssertEqual(removed, 3)
        XCTAssertEqual(array, [1, 2, 5, 4])
    }

    // Test correctness
    func testSwapRemoveCorrectness() {
        var array = [1, 2, 3, 4, 5]
        let removed = array.swapRemove(at: 1)

        XCTAssertEqual(removed, 2)
        XCTAssertEqual(array, [1, 5, 3, 4])
    }

    // Test edge cases
    func testSwapRemoveLastElement() {
        var array = [1, 2, 3]
        let removed = array.swapRemove(at: 2)

        XCTAssertEqual(removed, 3)
        XCTAssertEqual(array, [1, 2])
    }
}
