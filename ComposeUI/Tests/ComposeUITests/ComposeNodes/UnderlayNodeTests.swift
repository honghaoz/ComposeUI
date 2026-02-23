//
//  UnderlayNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/17/24.
//

import Foundation

import ChouTiTest

@testable import ComposeUI

class UnderlayNodeTests: XCTestCase {

    func test() {
        var content = ColorNode(.red)
            .underlay {
                ColorNode(.blue)
            }
            .background(alignment: .center, content: { ColorNode(.green) })
            .background(ColorNode(.green))

        content.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
        let items = content.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 50))
        guard items.count == 4 else {
            fail("Expected 4 items, got \(items.count)")
            return
        }

        expect(items[0].id.id) == "UL|U|C"
        expect(items[1].id.id) == "UL|UL|U|C"
        expect(items[2].id.id) == "UL|UL|UL|U|C"
        expect(items[3].id.id) == "UL|UL|UL|C"
    }
}
