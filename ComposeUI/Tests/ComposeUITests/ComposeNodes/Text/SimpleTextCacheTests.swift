//
//  SimpleTextCacheTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/8/26.
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
#endif

#if canImport(UIKit)
import UIKit
#endif

import ChouTiTest

@testable import ComposeUI

class SimpleTextCacheTests: XCTestCase {

  override func setUp() {
    super.setUp()
    SimpleTextCache.removeAll()
  }

  override func tearDown() {
    SimpleTextCache.removeAll()
    super.tearDown()
  }

  func test_attributedString_makesTheTextOfTheSettings() {
    // given: settings with every attribute
    let key = Self.key(textBackgroundColor: ThemedColor(.green), textShadow: Self.shadow)

    // when: looking up the string
    let string = SimpleTextCache.attributedString(for: key)

    // then: it's the string a text node makes of the settings, with a word-wrapping paragraph style
    expect(string.isEqual(to: Self.expectedString(for: key))) == true
    expect((string.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.lineBreakMode) == .byWordWrapping
  }

  func test_attributedString_sameSettings_reusesTheString() {
    // given: the string of some settings
    let string = SimpleTextCache.attributedString(for: Self.key())

    // when: looking up the string of equal settings, made separately
    let again = SimpleTextCache.attributedString(for: Self.key())

    // then: it's the same string
    expect(again) === string
  }

  func test_attributedString_eachSetting_makesItsOwnString() {
    // given: the string of some settings, and settings that each differ from them in one setting
    let base = SimpleTextCache.attributedString(for: Self.key())
    let variants = [
      Self.key(text: "Other"),
      Self.key(font: .systemFont(ofSize: 20)),
      Self.key(textColor: ThemedColor(.blue)),
      Self.key(textBackgroundColor: ThemedColor(.green)),
      Self.key(textShadow: Self.shadow),
      Self.key(textAlignment: .right),
    ]

    for variant in variants {
      // when: looking up the string of the variant
      let string = SimpleTextCache.attributedString(for: variant)

      // then: it's a string of its own, made of its settings
      expect(string) !== base
      expect(string.isEqual(to: Self.expectedString(for: variant))) == true
    }
  }

  func test_attributedString_canonicallyEquivalentText_keepsItsOwnCharacters() {
    // given: a precomposed "é" and an "e" with a combining accent, which Swift's `==` matches
    let precomposed = "caf\u{E9}"
    let decomposed = "cafe\u{301}"
    expect(precomposed == decomposed) == true

    // when: looking up the strings of the two texts
    let precomposedString = SimpleTextCache.attributedString(for: Self.key(text: precomposed))
    let decomposedString = SimpleTextCache.attributedString(for: Self.key(text: decomposed))

    // then: each string has its own text's characters
    expect(Array(precomposedString.string.utf16)) == Array(precomposed.utf16)
    expect(Array(decomposedString.string.utf16)) == Array(decomposed.utf16)
  }

  func test_attributedString_pastTheGenerationLimit_keepsTheGenerationBefore() {
    // given: the strings of a full generation, and of one more text, which starts the next generation
    let keys = (0 ... SimpleTextCache.generationLimit).map { Self.key(text: "\($0)") }
    let strings = keys.map { SimpleTextCache.attributedString(for: $0) }

    // when: looking up the first string, which the full generation holds
    let first = SimpleTextCache.attributedString(for: keys[0])

    // then: it's the same string
    expect(first) === strings[0]

    // when: filling the next generation and starting a third one, which drops the full generation
    for index in 0 ..< SimpleTextCache.generationLimit - 1 {
      _ = SimpleTextCache.attributedString(for: Self.key(text: "next\(index)"))
    }
    let firstAgain = SimpleTextCache.attributedString(for: keys[0])
    let second = SimpleTextCache.attributedString(for: keys[1])

    // then: the first string, which the lookup moved to the next generation, is kept, and the second string, which the
    // dropped generation held, is made again
    expect(firstAgain) === strings[0]
    expect(second) !== strings[1]
    expect(second.isEqual(to: strings[1])) == true
  }

  func test_removeAll_makesTheStringsAgain() {
    // given: the string of some settings
    let string = SimpleTextCache.attributedString(for: Self.key())

    // when: removing all strings, and looking up the string again
    SimpleTextCache.removeAll()
    let again = SimpleTextCache.attributedString(for: Self.key())

    // then: the string is made again, with the same contents
    expect(again) !== string
    expect(again.isEqual(to: string)) == true
  }

  // MARK: - Helpers

  private static let shadow = Themed<NSShadow>({
    let shadow = NSShadow()
    shadow.shadowOffset = CGSize(width: 0, height: 1)
    return shadow
  }())

  private static func key(text: String = "Text",
                          font: Font = .systemFont(ofSize: 12),
                          textColor: ThemedColor = ThemedColor(.red),
                          textBackgroundColor: ThemedColor? = nil,
                          textShadow: Themed<NSShadow>? = nil,
                          textAlignment: NSTextAlignment = .center) -> SimpleTextCache.Key
  {
    SimpleTextCache.Key(
      text: text,
      font: font,
      textColor: textColor,
      textBackgroundColor: textBackgroundColor,
      textShadow: textShadow,
      textAlignment: textAlignment
    )
  }

  /// Returns the string that a text node makes of the settings.
  private static func expectedString(for key: SimpleTextCache.Key) -> NSAttributedString {
    TextNode.attributedString(
      key.text,
      font: key.font,
      foregroundColor: key.textColor,
      backgroundColor: key.textBackgroundColor,
      shadow: key.textShadow,
      textAlignment: key.textAlignment,
      lineBreakMode: .byWordWrapping
    )
  }
}
