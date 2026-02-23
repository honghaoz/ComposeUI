//
//  RenderItem+ContextTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
//

import XCTest

import ComposeUI

class RenderItem_ContextTests: XCTestCase {

    func test_renderableInsertContext() {
        XCTAssertEqual(RenderableUpdateType.insert.requiresFullUpdate, true)
        XCTAssertEqual(RenderableUpdateType.refresh.requiresFullUpdate, true)
        XCTAssertEqual(RenderableUpdateType.scroll.requiresFullUpdate, false)
        XCTAssertEqual(RenderableUpdateType.boundsChange.requiresFullUpdate, false)
    }
}
