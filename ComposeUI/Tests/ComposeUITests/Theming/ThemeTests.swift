//
//  ThemeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/29/21.
//

import ChouTiTest

import ComposeUI

class ThemeTests: XCTestCase {

    func test_isLight() {
        do {
            let theme = Theme.light
            expect(theme.isLight) == true
        }

        do {
            let theme = Theme.dark
            expect(theme.isLight) == false
        }
    }

    func test_isDark() {
        do {
            let theme = Theme.light
            expect(theme.isDark) == false
        }

        do {
            let theme = Theme.dark
            expect(theme.isDark) == true
        }
    }
}
