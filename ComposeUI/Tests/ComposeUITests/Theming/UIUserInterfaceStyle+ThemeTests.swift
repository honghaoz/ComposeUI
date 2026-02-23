//
//  UIUserInterfaceStyle+ThemeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/12/24.
//

#if canImport(UIKit)
import UIKit

import ChouTiTest

import ComposeUI

class UIUserInterfaceStyle_ThemeTests: XCTestCase {

    func test_theme() {
        expect(UIUserInterfaceStyle.unspecified.theme) == .light
        expect(UIUserInterfaceStyle.light.theme) == .light
        expect(UIUserInterfaceStyle.dark.theme) == .dark
    }
}
#endif
