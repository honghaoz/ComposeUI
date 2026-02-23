//
//  OverlayNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/13/25.
//

import Foundation

import XCTest

@testable import ComposeUI

class OverlayNodeTests: XCTestCase {

    func test() {
        var content = ColorNode(.red)
            .overlay {
                ColorNode(.blue)
            }
            .background(alignment: .center, content: { ColorNode(.green) })
            .background(ColorNode(.green))

        content.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
        let items = content.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 50))
        guard items.count == 4 else {
            XCTFail("Expected 4 items, got \(items.count)")
            return
        }

        XCTAssertEqual(items[0].id.id, "UL|U|C")
        XCTAssertEqual(items[1].id.id, "UL|UL|U|C")
        XCTAssertEqual(items[2].id.id, "UL|UL|OV|C")
        XCTAssertEqual(items[3].id.id, "UL|UL|OV|O|C")
    }
}
