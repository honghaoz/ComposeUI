//
//  NSTextField+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/6/24.
//

#if canImport(AppKit)

import AppKit

import ChouTiTest

import ComposeUI

class NSTextField_ExtensionsTests: XCTestCase {

    func test_numberOfLines() {
        let textField = NSTextField()
        textField.maximumNumberOfLines = 2
        expect(textField.numberOfLines) == 2

        textField.numberOfLines = 3
        expect(textField.numberOfLines) == 3
    }

    func test_attributedText() {
        let textField = NSTextField()
        let attributedText = NSAttributedString(string: "Hello, World!")
        textField.attributedStringValue = attributedText
        expect(textField.attributedText) == attributedText

        textField.attributedText = attributedText
        expect(textField.attributedText) == attributedText
    }

    func test_textAlignment() {
        let textField = NSTextField()
        textField.alignment = .center
        expect(textField.textAlignment) == .center

        textField.textAlignment = .left
        expect(textField.textAlignment) == .left
    }
}

#endif
