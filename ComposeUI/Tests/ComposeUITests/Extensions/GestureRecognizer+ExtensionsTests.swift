//
//  GestureRecognizer+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/7/25.
//

import ChouTiTest

@testable import ComposeUI

class GestureRecognizer_ExtensionsTests: XCTestCase {

    func test_cancel() {
        let recognizer = TapGestureRecognizer()
        recognizer.cancel()
    }
}
