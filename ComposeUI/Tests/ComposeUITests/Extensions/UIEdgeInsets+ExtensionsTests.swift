//
//  UIEdgeInsets+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 2/22/26.
//

import XCTest
import UIKit

@testable import ComposeUI

class UIEdgeInsets_ExtensionsTests: XCTestCase {

    func test_horizontal() {
        let insets = UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4)
        XCTAssertEqual(insets.horizontal, 6)
    }

    func test_vertical() {
        let insets = UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4)
        XCTAssertEqual(insets.vertical, 4)
    }

    func test_initInset() {
        let insets = UIEdgeInsets(inset: 8)
        XCTAssertEqual(insets.top, 8)
        XCTAssertEqual(insets.left, 8)
        XCTAssertEqual(insets.bottom, 8)
        XCTAssertEqual(insets.right, 8)
    }
}
