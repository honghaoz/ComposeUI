//
//  NSTextField+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/6/24.
//  Copyright © 2024 Honghao Zhang.
//
//  MIT License
//
//  Copyright (c) 2024 Honghao Zhang (github.com/honghaoz)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#if canImport(AppKit)

import AppKit

import ChouTiTest

import ComposeUI

class NSTextField_ExtensionsTests: XCTestCase {

  func test_numberOfLines() {
    // given: a text field
    let textField = NSTextField()

    // when: maximumNumberOfLines is set
    textField.maximumNumberOfLines = 2

    // then: numberOfLines reflects the value
    expect(textField.numberOfLines) == 2

    // when: numberOfLines is set
    textField.numberOfLines = 3

    // then: numberOfLines is updated
    expect(textField.numberOfLines) == 3
  }

  func test_attributedText() {
    // given: a text field and an attributed string
    let textField = NSTextField()
    let attributedText = NSAttributedString(string: "Hello, World!")

    // when: attributedStringValue is set
    textField.attributedStringValue = attributedText

    // then: attributedText returns the attributed string
    expect(textField.attributedText) == attributedText

    // when: attributedText is set
    textField.attributedText = attributedText

    // then: attributedText returns the attributed string
    expect(textField.attributedText) == attributedText
  }

  func test_textAlignment() {
    // given: a text field
    let textField = NSTextField()

    // when: alignment is set
    textField.alignment = .center

    // then: textAlignment reflects the value
    expect(textField.textAlignment) == .center

    // when: textAlignment is set
    textField.textAlignment = .left

    // then: textAlignment is updated
    expect(textField.textAlignment) == .left
  }
}

#endif
