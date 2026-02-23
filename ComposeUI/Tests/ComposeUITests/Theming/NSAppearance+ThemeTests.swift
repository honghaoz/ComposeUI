//
//  NSAppearance+ThemeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/12/24.
//

#if canImport(AppKit)
import AppKit

import ChouTiTest

import ComposeUI

class NSAppearance_ThemeTests: XCTestCase {

    func test_theme() {
        expect(NSAppearance(named: .aqua)?.theme) == .light
        expect(NSAppearance(named: .darkAqua)?.theme) == .dark
        expect(NSAppearance(named: .vibrantDark)?.theme) == .dark
        expect(NSAppearance(named: .vibrantLight)?.theme) == .light
    }
}
#endif
