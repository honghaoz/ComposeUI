//
//  RenderItem+ContextTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
//

import ChouTiTest

import ComposeUI

class RenderItem_ContextTests: XCTestCase {

    func test_renderableInsertContext() {
        expect(RenderableUpdateType.insert.requiresFullUpdate) == true
        expect(RenderableUpdateType.refresh.requiresFullUpdate) == true
        expect(RenderableUpdateType.scroll.requiresFullUpdate) == false
        expect(RenderableUpdateType.boundsChange.requiresFullUpdate) == false
    }
}
