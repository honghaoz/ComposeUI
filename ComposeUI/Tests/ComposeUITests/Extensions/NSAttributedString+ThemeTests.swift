//
//  NSAttributedString+ThemeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
//

import ChouTiTest

@testable import ComposeUI

class NSAttributedString_ThemeTests: XCTestCase {

    func test() {
        let lightShadow = NSShadow()
        lightShadow.shadowColor = Color.black
        lightShadow.shadowOffset = CGSize(width: 1, height: 1)
        let darkShadow = NSShadow()
        darkShadow.shadowColor = Color.white
        darkShadow.shadowOffset = CGSize(width: 1, height: -1)

        let attributedString = NSAttributedString(
            string: "Hello, world!",
            attributes: [
                .themedForegroundColor: ThemedColor(light: .red, dark: .blue),
                .themedBackgroundColor: ThemedColor(light: .green, dark: .yellow),
                .themedShadow: Themed<NSShadow>(light: lightShadow, dark: darkShadow),
            ]
        )

        do {
            let darkAttributedString = attributedString.apply(theme: .dark)
            let attributes = darkAttributedString.attributes(at: 0, effectiveRange: nil)
            expect(attributes[.foregroundColor] as? Color) == Color.blue
            expect(attributes[.backgroundColor] as? Color) == Color.yellow
            expect((attributes[.shadow] as? NSShadow)?.shadowColor as? Color) == Color.white
            #if canImport(AppKit)
            expect((attributes[.shadow] as? NSShadow)?.shadowOffset.height) == -darkShadow.shadowOffset.height
            #else
            expect((attributes[.shadow] as? NSShadow)?.shadowOffset.height) == darkShadow.shadowOffset.height
            #endif

            expect(attributes[.themedForegroundColor] as? ThemedColor) == ThemedColor(light: .red, dark: .blue)
            expect(attributes[.themedBackgroundColor] as? ThemedColor) == ThemedColor(light: .green, dark: .yellow)
            expect(attributes[.themedShadow] as? Themed<NSShadow>) == Themed<NSShadow>(light: lightShadow, dark: darkShadow)
        }

        do {
            let lightAttributedString = attributedString.apply(theme: .light)
            let attributes = lightAttributedString.attributes(at: 0, effectiveRange: nil)
            expect(attributes[.foregroundColor] as? Color) == Color.red
            expect(attributes[.backgroundColor] as? Color) == Color.green
            expect((attributes[.shadow] as? NSShadow)?.shadowColor as? Color) == Color.black
            #if canImport(AppKit)
            expect((attributes[.shadow] as? NSShadow)?.shadowOffset.height) == -lightShadow.shadowOffset.height
            #else
            expect((attributes[.shadow] as? NSShadow)?.shadowOffset.height) == lightShadow.shadowOffset.height
            #endif

            expect(attributes[.themedForegroundColor] as? ThemedColor) == ThemedColor(light: .red, dark: .blue)
            expect(attributes[.themedBackgroundColor] as? ThemedColor) == ThemedColor(light: .green, dark: .yellow)
            expect(attributes[.themedShadow] as? Themed<NSShadow>) == Themed<NSShadow>(light: lightShadow, dark: darkShadow)
        }
    }

    func test_incorrectValue() {
        let value = NSObject()

        var assertionCount = 0
        Assert.setTestAssertionFailureHandler { message, file, line, column in
            switch assertionCount {
            case 0:
                expect(message) == "expected ThemedColor for .themedForegroundColor, got \(value)"
            case 1:
                expect(message) == "expected ThemedColor for .themedBackgroundColor, got \(value)"
            case 2:
                expect(message) == "expected Themed<NSShadow> for .themedShadow, got \(value)"
            default:
                break
            }
            assertionCount += 1
        }

        let attributedString = NSAttributedString(
            string: "Hello, world!",
            attributes: [
                .themedForegroundColor: value,
                .themedBackgroundColor: value,
                .themedShadow: value,
            ]
        )
        _ = attributedString.apply(theme: .dark)
        expect(assertionCount) == 3
    }
}
