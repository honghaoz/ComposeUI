//
//  EdgeInsets+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
//

import ChouTiTest

@testable import ComposeUI

class EdgeInsets_ExtensionsTests: XCTestCase {

    func test() {
        let insets = EdgeInsets(inset: 10)
        expect(insets.horizontal) == 20
        expect(insets.vertical) == 20
    }
}
