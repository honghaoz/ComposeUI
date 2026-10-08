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

  func test_key_canonicallyEquivalentTexts_hashDifferently() {
    // given: the keys of a precomposed "é" and an "e" with a combining accent, which `==` keeps apart
    let precomposed = Self.key(text: "caf\u{E9}")
    let decomposed = Self.key(text: "cafe\u{301}")

    // then: their hashes differ too, so many such texts don't all land in one bucket
    expect(precomposed) != decomposed
    expect(precomposed.hashValue) != decomposed.hashValue
  }

  func test_key_bridgedText_hashesLikeTheSameNativeText() throws {
    // given: a text, and the same text bridged from `NSString`, which doesn't store contiguous UTF-8
    let text = "Subtitle for a row with longer text, caf\u{E9}"
    let bridged = try unwrap(NSMutableString(string: text).copy() as? String)
    expect(bridged.utf8.withContiguousStorageIfAvailable { _ in true }) == nil

    // then: their keys are equal and hash the same
    expect(Self.key(text: bridged)) == Self.key(text: text)
    expect(Self.key(text: bridged).hashValue) == Self.key(text: text).hashValue
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

  func test_attributedString_pastTheByteLimit_keepsTheGenerationBefore() {
    // given: the strings of two texts that fill a generation's bytes, and of a third, which starts the next generation
    let half = String(repeating: "a", count: SimpleTextCache.generationByteLimit / 2 - 1)
    let keys = (0 ..< 3).map { Self.key(text: "\(half)\($0)") }
    let strings = keys.map { SimpleTextCache.attributedString(for: $0) }

    // when: looking up the first string, which the full generation holds
    let first = SimpleTextCache.attributedString(for: keys[0])

    // then: it's the same string
    expect(first) === strings[0]

    // when: making one more string, which starts a third generation and drops the full one
    _ = SimpleTextCache.attributedString(for: Self.key(text: "\(half)3"))
    let firstAgain = SimpleTextCache.attributedString(for: keys[0])
    let second = SimpleTextCache.attributedString(for: keys[1])

    // then: the first string, which the lookup moved to the next generation, is kept, and the second string, which the
    // dropped generation held, is made again
    expect(firstAgain) === strings[0]
    expect(second) !== strings[1]
  }

  func test_attributedString_afterTheByteLimit_countsTheNextGenerationsOwnBytes() {
    // given: the strings of three texts that pass a generation's bytes, which starts the next generation
    let half = String(repeating: "a", count: SimpleTextCache.generationByteLimit / 2 - 1)
    for index in 0 ..< 3 {
      _ = SimpleTextCache.attributedString(for: Self.key(text: "\(half)\(index)"))
    }

    // when: making the strings of a few short texts, and looking up the first one again
    let strings = (0 ..< 3).map { SimpleTextCache.attributedString(for: Self.key(text: "short\($0)")) }
    let first = SimpleTextCache.attributedString(for: Self.key(text: "short0"))

    // then: it's the same string, since the next generation counts only its own bytes, so the short texts all fit
    expect(first) === strings[0]
  }

  func test_attributedString_textOfTheByteLimit_isKept() {
    // given: a text of exactly the byte limit
    let key = Self.key(text: String(repeating: "a", count: SimpleTextCache.generationByteLimit))

    // when: looking up its string twice
    let string = SimpleTextCache.attributedString(for: key)
    let again = SimpleTextCache.attributedString(for: key)

    // then: it's the same string, since the text fits in a generation by itself
    expect(again) === string
  }

  func test_attributedString_textOverTheByteLimit_isNotKept() {
    // given: the strings of two texts that fill a generation's bytes, and a text over the byte limit
    let half = String(repeating: "a", count: SimpleTextCache.generationByteLimit / 2 - 1)
    let first = SimpleTextCache.attributedString(for: Self.key(text: "\(half)0"))
    _ = SimpleTextCache.attributedString(for: Self.key(text: "\(half)1"))
    let long = Self.key(text: String(repeating: "b", count: SimpleTextCache.generationByteLimit + 1))

    // when: looking up the long text's string twice, then making the string of a short text, which starts the next
    // generation, and looking up the first string again
    let longString = SimpleTextCache.attributedString(for: long)
    let longAgain = SimpleTextCache.attributedString(for: long)
    _ = SimpleTextCache.attributedString(for: Self.key(text: "short"))
    let firstAgain = SimpleTextCache.attributedString(for: Self.key(text: "\(half)0"))

    // then: the long text's string is made each time, without being kept or starting a generation, so the full
    // generation, with the first string, became the generation before
    expect(longAgain) !== longString
    expect(firstAgain) === first
  }

  func test_attributedString_shadowChangedLater_keepsTheStringOfTheEarlierValues() {
    // given: the string of settings with a shadow, which the caller then changes
    let shadow = Self.makeShadow(height: 1)
    let string = SimpleTextCache.attributedString(for: Self.key(textShadow: Themed(shadow)))
    shadow.shadowOffset = CGSize(width: 0, height: 2)

    // when: looking up the strings of the changed shadow, and of a new shadow with the earlier values
    let changed = SimpleTextCache.attributedString(for: Self.key(textShadow: Themed(shadow)))
    let again = SimpleTextCache.attributedString(for: Self.key(textShadow: Themed(Self.makeShadow(height: 1))))

    // then: the changed shadow makes a string of its own values, and the earlier values still find the first string,
    // whose shadow kept them
    expect(changed) !== string
    expect(Self.shadowOffset(of: changed)) == CGSize(width: 0, height: 2)
    expect(again) === string
    expect(Self.shadowOffset(of: string)) == CGSize(width: 0, height: 1)
  }

  func test_attributedString_shadowChangedAfterMovingBack_keepsTheString() {
    // given: the string of settings with a shadow, which a full generation of other strings moves to the generation
    // before
    let string = SimpleTextCache.attributedString(for: Self.key(textShadow: Themed(Self.makeShadow(height: 1))))
    for index in 0 ..< SimpleTextCache.generationLimit {
      _ = SimpleTextCache.attributedString(for: Self.key(text: "\(index)"))
    }

    // when: looking up the string with a new shadow of the same values, which moves it back, then changing that shadow
    // and looking up the string with another new shadow of the same values
    let shadow = Self.makeShadow(height: 1)
    let movedBack = SimpleTextCache.attributedString(for: Self.key(textShadow: Themed(shadow)))
    shadow.shadowOffset = CGSize(width: 0, height: 2)
    let again = SimpleTextCache.attributedString(for: Self.key(textShadow: Themed(Self.makeShadow(height: 1))))

    // then: both lookups find the string, since moving it back kept the key's own copy of the shadow
    expect(movedBack) === string
    expect(again) === string
  }

  #if canImport(UIKit)
  func test_memoryWarning_removesAllStrings() {
    // given: the string of some settings
    let string = SimpleTextCache.attributedString(for: Self.key())

    // when: the system sends a memory warning, and looking up the string again
    NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    let again = SimpleTextCache.attributedString(for: Self.key())

    // then: the string is made again
    expect(again) !== string
  }
  #endif

  #if canImport(AppKit)
  func test_attributedString_listensToMemoryPressure() throws {
    // when: looking up a string
    _ = SimpleTextCache.attributedString(for: Self.key())

    // then: the cache listens to the system's memory pressure events, whose handler is `removeAll()`. a test can't
    // send a real event, which takes `sudo memory_pressure -S -l warning`
    let source = try unwrap(SimpleTextCache.memoryPressureSource)
    expect(source.isCancelled) == false
  }
  #endif

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

  /// Returns a new shadow of the vertical offset.
  private static func makeShadow(height: CGFloat) -> NSShadow {
    let shadow = NSShadow()
    shadow.shadowOffset = CGSize(width: 0, height: height)
    return shadow
  }

  /// Returns the offset of the string's light shadow.
  private static func shadowOffset(of string: NSAttributedString) -> CGSize? {
    (string.attribute(.themedShadow, at: 0, effectiveRange: nil) as? Themed<NSShadow>)?.light.shadowOffset
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
