//
//  ComposeNodeIdTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/5/24.
//

import Foundation
import XCTest

@testable import ComposeUI

class ComposeNodeIdTests: XCTestCase {

    func test_standard() {
        let id = ComposeNodeId.standard(.color)
        XCTAssertEqual(id.id, "C")
    }

    func test_custom() {
        let id = ComposeNodeId.custom("test")
        XCTAssertEqual(id.id, "test")

        let parentId = ComposeNodeId.custom("parent")
        do {
            let childId = parentId.join(with: id)
            XCTAssertEqual(childId.id, "parent|test")
        }
        do {
            let childId = parentId.join(with: id, suffix: "suffix")
            XCTAssertEqual(childId.id, "parent|suffix|test")
        }
    }

    func test_custom_fixed() {
        let id = ComposeNodeId.custom("test", isFixed: true)
        XCTAssertEqual(id.id, "test")

        let parentId = ComposeNodeId.custom("parent", isFixed: false)
        do {
            let childId = parentId.join(with: id)
            XCTAssertEqual(childId.id, "test")
        }
        do {
            let childId = parentId.join(with: id, suffix: "suffix")
            XCTAssertEqual(childId.id, "test")
        }
    }
}
