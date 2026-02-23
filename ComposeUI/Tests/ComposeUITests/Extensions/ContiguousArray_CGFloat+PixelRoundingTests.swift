//
//  ContiguousArray_CGFloat+PixelRoundingTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 5/23/23.
//

import XCTest

@testable import ComposeUI

class ContiguousArray_CGFloat_PixelRoundingTests: XCTestCase {

    func testEmptyArray() {
        let array: ContiguousArray<CGFloat> = []
        XCTAssertEqual(Array(array.rounded(scaleFactor: 2)), [])
    }

    func testArrayWithOneElement() {
        let array: ContiguousArray<CGFloat> = [10.33333]
        XCTAssertEqual(Array(array.rounded(scaleFactor: 2)), [10.33333])
    }

    func testArrayWithMultipleElements() {
        let array: ContiguousArray<CGFloat> = [10.3333333333, 10.333333333, 10.3333333333]
        XCTAssertEqual(Array(array.rounded(scaleFactor: 2)), [10.5, 10.5, 9.999999999600002])
    }

    func testArrayWithMoreElements() {
        let array: ContiguousArray<CGFloat> = [51.6666666667, 51.6666666667, 51.6666666667, 51.6666666667, 51.6666666667, 51.6666666667]
        XCTAssertEqual(Array(array.rounded(scaleFactor: 2)), [51.5, 51.5, 51.5, 52, 51.5, 52.00000000020002])
    }

    func testArrayWithTooSmallPixelWidths() {
        let array: ContiguousArray<CGFloat> = [0.3, 0.3, 0.3]
        XCTAssertEqual(Array(array.rounded(scaleFactor: 2)), [0.3, 0.3, 0.3])
    }

    func testArrayWithTooSmallPixelWidths2() {
        let array: ContiguousArray<CGFloat> = [0.3]
        XCTAssertEqual(Array(array.rounded(scaleFactor: 2)), [0.3])
    }

    func testArrayWithTooSmallPixelWidths3() {
        let array: ContiguousArray<CGFloat> = [0.3, 0.3]
        let roundedArray = array.rounded(scaleFactor: 2)
        XCTAssertEqual(roundedArray[0], 0.5)
        XCTAssertEqual(roundedArray[1], 0.1, accuracy: 1e-12)
    }
}
