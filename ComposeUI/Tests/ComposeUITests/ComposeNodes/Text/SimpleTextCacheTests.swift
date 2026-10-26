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
    let settings = Self.settings(textBackgroundColor: ThemedColor(.green), textShadow: Self.shadow)

    // when: looking up the string
    let string = SimpleTextCache.entry(for: settings).string

    // then: it's the string a text node makes of the settings, with a word-wrapping paragraph style
    expect(string.isEqual(to: Self.expectedString(for: settings))) == true
    expect((string.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.lineBreakMode) == .byWordWrapping
  }

  func test_attributedString_sameSettings_reusesTheString() {
    // given: the string of some settings, and equal settings made separately, with color and shadow objects of their own
    let settings = Self.equalSettings()
    let string = SimpleTextCache.entry(for: settings).string
    let equalSettings = Self.equalSettings()
    expect(equalSettings.textColor.light) !== settings.textColor.light

    // when: looking up the string of the equal settings
    let again = SimpleTextCache.entry(for: equalSettings).string

    // then: it's the same string
    expect(again) === string
  }

  func test_attributedString_eachSetting_makesItsOwnString() {
    // given: the string of some settings, and settings that each differ from them in one setting
    let base = SimpleTextCache.entry(for: Self.settings()).string
    let variants = [
      Self.settings(text: "Other"),
      Self.settings(font: .systemFont(ofSize: 20)),
      Self.settings(textColor: ThemedColor(.blue)),
      Self.settings(textBackgroundColor: ThemedColor(.green)),
      Self.settings(textShadow: Self.shadow),
      Self.settings(textAlignment: .right),
    ]

    for variant in variants {
      // when: looking up the string of the variant
      let string = SimpleTextCache.entry(for: variant).string

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
    let precomposedString = SimpleTextCache.entry(for: Self.settings(text: precomposed)).string
    let decomposedString = SimpleTextCache.entry(for: Self.settings(text: decomposed)).string

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

  func test_key_textsOfOtherCodeUnits_areNotEqual() throws {
    // given: texts that differ in one character of the same UTF-8 length, native and bridged from `NSString`, which
    // doesn't store contiguous UTF-8
    let text = "Subtitle for a row with longer text, caf\u{E9}"
    let otherText = "Subtitle for a row with longer text, caf\u{E8}"
    let bridged = try unwrap(NSMutableString(string: text).copy() as? String)
    let otherBridged = try unwrap(NSMutableString(string: otherText).copy() as? String)
    expect(otherBridged.utf8.withContiguousStorageIfAvailable { _ in true }) == nil
    let cases: [(name: String, lhs: String, rhs: String)] = [
      ("another length", "Text", "Texts"),
      ("the same length", "Text", "Next"),
      ("a native and a bridged text", text, otherBridged),
      ("bridged texts", bridged, otherBridged),
    ]

    for testCase in cases {
      // then: the keys of the texts aren't equal
      expect(Self.key(text: testCase.lhs), testCase.name) != Self.key(text: testCase.rhs)
    }
  }

  func test_key_otherAlignment_isNotEqual() {
    // then: the keys of two alignments aren't equal
    expect(Self.key(textAlignment: .right)) != Self.key(textAlignment: .center)
  }

  func test_key_emptyTexts_areEqual() {
    // then: the keys of two empty texts are equal and hash the same
    expect(Self.key(text: "")) == Self.key(text: String())
    expect(Self.key(text: "").hashValue) == Self.key(text: String()).hashValue
  }

  func test_attributedString_sameTextOtherSettings_keepsTheStringOfEach() {
    // given: the strings of a text in two fonts, which share a key
    let first = SimpleTextCache.entry(for: Self.settings(font: .systemFont(ofSize: 12))).string
    let second = SimpleTextCache.entry(for: Self.settings(font: .systemFont(ofSize: 20))).string

    // when: looking up both strings again
    let firstAgain = SimpleTextCache.entry(for: Self.settings(font: .systemFont(ofSize: 12))).string
    let secondAgain = SimpleTextCache.entry(for: Self.settings(font: .systemFont(ofSize: 20))).string

    // then: each lookup finds its own string
    expect(second) !== first
    expect(firstAgain) === first
    expect(secondAgain) === second
  }

  func test_attributedString_sameTextInTheGenerationBefore_movesBackEachStringLookedUp() {
    // given: the strings of a text in four fonts, which a full generation of other strings moves to the generation
    // before, where the string made last leads the list of the text's strings
    let fonts = [12, 16, 20, 26].map { Font.systemFont(ofSize: CGFloat($0)) }
    let strings = fonts.map { SimpleTextCache.entry(for: Self.settings(font: $0)).string }
    for index in 0 ..< SimpleTextCache.generationLimit {
      _ = SimpleTextCache.entry(for: Self.settings(text: "\(index)")).string
    }

    // when: looking up the string of the second font, the third in the list, then of the first font, the last in the
    // list, then of the last font, which leads the list, then of the third font
    let second = SimpleTextCache.entry(for: Self.settings(font: fonts[1])).string
    let first = SimpleTextCache.entry(for: Self.settings(font: fonts[0])).string
    let last = SimpleTextCache.entry(for: Self.settings(font: fonts[3])).string
    let third = SimpleTextCache.entry(for: Self.settings(font: fonts[2])).string

    // then: each lookup finds its string, since moving one string back leaves the others in the list
    expect(second) === strings[1]
    expect(first) === strings[0]
    expect(last) === strings[3]
    expect(third) === strings[2]

    // when: filling another generation, which drops the generation before
    for index in 0 ..< SimpleTextCache.generationLimit - fonts.count {
      _ = SimpleTextCache.entry(for: Self.settings(text: "next\(index)")).string
    }

    // then: the strings that moved back are kept
    for (font, string) in zip(fonts, strings) {
      expect(SimpleTextCache.entry(for: Self.settings(font: font)).string) === string
    }
  }

  func test_attributedString_pastTheGenerationLimit_keepsTheGenerationBefore() {
    // given: the strings of a full generation, and of one more text, which starts the next generation
    let allSettings = (0 ... SimpleTextCache.generationLimit).map { Self.settings(text: "\($0)") }
    let strings = allSettings.map { SimpleTextCache.entry(for: $0).string }

    // when: looking up the first string, which the full generation holds
    let first = SimpleTextCache.entry(for: allSettings[0]).string

    // then: it's the same string
    expect(first) === strings[0]

    // when: filling the next generation and starting a third one, which drops the full generation
    for index in 0 ..< SimpleTextCache.generationLimit - 1 {
      _ = SimpleTextCache.entry(for: Self.settings(text: "next\(index)")).string
    }
    let firstAgain = SimpleTextCache.entry(for: allSettings[0]).string
    let second = SimpleTextCache.entry(for: allSettings[1]).string

    // then: the first string, which the lookup moved to the next generation, is kept, and the second string, which the
    // dropped generation held, is made again
    expect(firstAgain) === strings[0]
    expect(second) !== strings[1]
    expect(second.isEqual(to: strings[1])) == true
  }

  func test_attributedString_pastTheByteLimit_keepsTheGenerationBefore() {
    // given: the strings of two texts that fill a generation's bytes, and of a third, which starts the next generation
    let half = String(repeating: "a", count: SimpleTextCache.generationByteLimit / 2 - 1)
    let allSettings = (0 ..< 3).map { Self.settings(text: "\(half)\($0)") }
    let strings = allSettings.map { SimpleTextCache.entry(for: $0).string }

    // when: looking up the first string, which the full generation holds
    let first = SimpleTextCache.entry(for: allSettings[0]).string

    // then: it's the same string
    expect(first) === strings[0]

    // when: making one more string, which starts a third generation and drops the full one
    _ = SimpleTextCache.entry(for: Self.settings(text: "\(half)3")).string
    let firstAgain = SimpleTextCache.entry(for: allSettings[0]).string
    let second = SimpleTextCache.entry(for: allSettings[1]).string

    // then: the first string, which the lookup moved to the next generation, is kept, and the second string, which the
    // dropped generation held, is made again
    expect(firstAgain) === strings[0]
    expect(second) !== strings[1]
  }

  func test_attributedString_afterTheByteLimit_countsTheNextGenerationsOwnBytes() {
    // given: the strings of three texts that pass a generation's bytes, which starts the next generation
    let half = String(repeating: "a", count: SimpleTextCache.generationByteLimit / 2 - 1)
    for index in 0 ..< 3 {
      _ = SimpleTextCache.entry(for: Self.settings(text: "\(half)\(index)")).string
    }

    // when: making the strings of a few short texts, and looking up the first one again
    let strings = (0 ..< 3).map { SimpleTextCache.entry(for: Self.settings(text: "short\($0)")).string }
    let first = SimpleTextCache.entry(for: Self.settings(text: "short0")).string

    // then: it's the same string, since the next generation counts only its own bytes, so the short texts all fit
    expect(first) === strings[0]
  }

  func test_attributedString_textOfTheByteLimit_isKept() {
    // given: a text of exactly the byte limit
    let settings = Self.settings(text: String(repeating: "a", count: SimpleTextCache.generationByteLimit))

    // when: looking up its string twice
    let string = SimpleTextCache.entry(for: settings).string
    let again = SimpleTextCache.entry(for: settings).string

    // then: it's the same string, since the text fits in a generation by itself
    expect(again) === string
  }

  func test_attributedString_textOverTheByteLimit_isNotKept() {
    // given: the strings of two texts that fill a generation's bytes, and a text over the byte limit
    let half = String(repeating: "a", count: SimpleTextCache.generationByteLimit / 2 - 1)
    let first = SimpleTextCache.entry(for: Self.settings(text: "\(half)0")).string
    _ = SimpleTextCache.entry(for: Self.settings(text: "\(half)1")).string
    let long = Self.settings(text: String(repeating: "b", count: SimpleTextCache.generationByteLimit + 1))

    // when: looking up the long text's string twice, then making the string of a short text, which starts the next
    // generation, and looking up the first string again
    let longString = SimpleTextCache.entry(for: long).string
    let longAgain = SimpleTextCache.entry(for: long).string
    _ = SimpleTextCache.entry(for: Self.settings(text: "short")).string
    let firstAgain = SimpleTextCache.entry(for: Self.settings(text: "\(half)0")).string

    // then: the long text's string is made each time, without being kept or starting a generation, so the full
    // generation, with the first string, became the generation before
    expect(longAgain) !== longString
    expect(firstAgain) === first
  }

  func test_attributedString_textOverTheByteLimit_isReleasedAfterItsLookup() {
    // given: the string of a short text
    _ = SimpleTextCache.entry(for: Self.settings(text: "short"))

    // when: looking up the string of a text over the byte limit, right after the short text's, and letting it go
    weak var longString: NSAttributedString?
    autoreleasepool {
      let long = Self.settings(text: String(repeating: "b", count: SimpleTextCache.generationByteLimit + 1))
      longString = SimpleTextCache.entry(for: long).string
    }

    // then: the long text's string is released, since the cache keeps nothing of it, not even a link from the short
    // text's entry
    expect(longString) == nil
  }

  func test_attributedString_shadowChangedLater_keepsTheStringOfTheEarlierValues() {
    // given: the string of settings with a shadow, which the caller then changes
    let shadow = Self.makeShadow(height: 1)
    let string = SimpleTextCache.entry(for: Self.settings(textShadow: Themed(shadow))).string
    shadow.shadowOffset = CGSize(width: 0, height: 2)

    // when: looking up the strings of the changed shadow, and of a new shadow with the earlier values
    let changed = SimpleTextCache.entry(for: Self.settings(textShadow: Themed(shadow))).string
    let again = SimpleTextCache.entry(for: Self.settings(textShadow: Themed(Self.makeShadow(height: 1)))).string

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
    let string = SimpleTextCache.entry(for: Self.settings(textShadow: Themed(Self.makeShadow(height: 1)))).string
    for index in 0 ..< SimpleTextCache.generationLimit {
      _ = SimpleTextCache.entry(for: Self.settings(text: "\(index)")).string
    }

    // when: looking up the string with a new shadow of the same values, which moves it back, then changing that shadow
    // and looking up the string with another new shadow of the same values
    let shadow = Self.makeShadow(height: 1)
    let movedBack = SimpleTextCache.entry(for: Self.settings(textShadow: Themed(shadow))).string
    shadow.shadowOffset = CGSize(width: 0, height: 2)
    let again = SimpleTextCache.entry(for: Self.settings(textShadow: Themed(Self.makeShadow(height: 1)))).string

    // then: both lookups find the string, since moving it back kept the key's own copy of the shadow
    expect(movedBack) === string
    expect(again) === string
  }

  func test_attributedString_sameTextsInTheSameOrder_reusesEachString() {
    // given: the strings of three texts
    let allSettings = ["First", "Second", "Third"].map { Self.settings(text: $0) }
    let strings = allSettings.map { SimpleTextCache.entry(for: $0).string }

    // when: looking up the strings in the same order twice, where each lookup follows the same lookup as the time before
    let secondRound = allSettings.map { SimpleTextCache.entry(for: $0).string }
    let thirdRound = allSettings.map { SimpleTextCache.entry(for: $0).string }

    // then: each lookup finds its string
    for (index, string) in strings.enumerated() {
      expect(secondRound[index]) === string
      expect(thirdRound[index]) === string
    }
  }

  func test_attributedString_afterTheSameLookup_eachOtherSetting_makesItsOwnString() {
    let variants: [(name: String, settings: SimpleTextCache.Settings)] = [
      ("another text of the same length", Self.settings(text: "Next")),
      ("another font", Self.settings(font: .systemFont(ofSize: 20))),
      ("another text color", Self.settings(textColor: ThemedColor(.blue))),
      ("a background color", Self.settings(textBackgroundColor: ThemedColor(.green))),
      ("a shadow", Self.settings(textShadow: Self.shadow)),
      ("another alignment", Self.settings(textAlignment: .right)),
    ]

    for variant in variants {
      // given: the string of some settings, looked up right after the string of another text, which is looked up again
      SimpleTextCache.removeAll()
      let other = Self.settings(text: "Other")
      _ = SimpleTextCache.entry(for: other)
      let base = SimpleTextCache.entry(for: Self.settings()).string
      _ = SimpleTextCache.entry(for: other)

      // when: looking up the string of the variant, right after the other text's string, as the base string was
      let string = SimpleTextCache.entry(for: variant.settings).string

      // then: it's a string of its own, made of its settings
      expect(string, variant.name) !== base
      expect(string.isEqual(to: Self.expectedString(for: variant.settings)), variant.name) == true
    }
  }

  func test_attributedString_sameOrderInTheGenerationBefore_movesBackEachString() {
    // given: the strings of two texts looked up one after the other, which a full generation of other strings moves to
    // the generation before
    let first = Self.settings(text: "First")
    let second = Self.settings(text: "Second")
    _ = SimpleTextCache.entry(for: first)
    let secondString = SimpleTextCache.entry(for: second).string
    for index in 0 ..< SimpleTextCache.generationLimit {
      _ = SimpleTextCache.entry(for: Self.settings(text: "\(index)"))
    }

    // when: looking up both strings again in the same order, then filling another generation, which drops the
    // generation before
    _ = SimpleTextCache.entry(for: first)
    let movedBack = SimpleTextCache.entry(for: second).string
    for index in 0 ..< SimpleTextCache.generationLimit {
      _ = SimpleTextCache.entry(for: Self.settings(text: "next\(index)"))
    }

    // then: the second string is kept, since its lookup moved it back like any lookup, though it followed the first
    // string's lookup as the time before
    expect(movedBack) === secondString
    expect(SimpleTextCache.entry(for: second).string) === secondString
  }

  func test_entry_singleLineSize_keepsTheSizeUntilTheTextSizeCacheIsCleared() {
    // given: a cleared text size cache, and the entry of some settings, with the size of its single line measured
    NSAttributedString.clearTextSizeCache()
    let entry = SimpleTextCache.entry(for: Self.settings())
    let size = entry.singleLineSize { CGSize(width: 10, height: 20) }

    // when: asking for the size again, with a block that measures another size
    let again = entry.singleLineSize { CGSize(width: 30, height: 40) }

    // then: it's the size measured first
    expect(size) == CGSize(width: 10, height: 20)
    expect(again) == size

    // when: clearing the text size cache, and asking for the size again
    NSAttributedString.clearTextSizeCache()
    let afterClearing = entry.singleLineSize { CGSize(width: 30, height: 40) }

    // then: the size is measured again, since a cleared cache measures every text again
    expect(afterClearing) == CGSize(width: 30, height: 40)
  }

  func test_attributedString_droppedGeneration_releasesTheOtherStringsOfAKeptEntrysText() {
    // given: the entries of a text in two fonts, the one made last kept outside the cache, as a text node keeps it, and
    // a weak reference to the other's string
    weak var otherString: NSAttributedString?
    var kept: SimpleTextCache.Entry?
    autoreleasepool {
      otherString = SimpleTextCache.entry(for: Self.settings(font: .systemFont(ofSize: 12))).string
      kept = SimpleTextCache.entry(for: Self.settings(font: .systemFont(ofSize: 20)))
    }
    expect(otherString) != nil

    // when: filling two generations of other strings, which drop the generation that holds both entries
    autoreleasepool {
      for index in 0 ..< 2 * SimpleTextCache.generationLimit {
        _ = SimpleTextCache.entry(for: Self.settings(text: "\(index)"))
      }
    }

    // then: the other string is released, since the kept entry no longer links to its entry, and the kept entry still
    // has its own string
    expect(otherString) == nil
    expect(kept?.string.string) == "Text"
  }

  func test_attributedString_droppedGeneration_releasesTheStringLookedUpAfterAKeptEntry() {
    // given: the entries of two texts looked up one after the other, the first kept outside the cache, as a text node
    // keeps it, and a weak reference to the second's string
    weak var nextString: NSAttributedString?
    var kept: SimpleTextCache.Entry?
    autoreleasepool {
      kept = SimpleTextCache.entry(for: Self.settings(text: "First"))
      nextString = SimpleTextCache.entry(for: Self.settings(text: "Second")).string
    }
    expect(nextString) != nil

    // when: filling two generations of other strings, which drop the generation that holds both entries
    autoreleasepool {
      for index in 0 ..< 2 * SimpleTextCache.generationLimit {
        _ = SimpleTextCache.entry(for: Self.settings(text: "\(index)"))
      }
    }

    // then: the second string is released, since the kept entry no longer links to the entry looked up after it, and
    // the kept entry still has its own string
    expect(nextString) == nil
    expect(kept?.string.string) == "First"
  }

  func test_removeAll_releasesTheOtherStringsOfAKeptEntrysText() {
    // given: the entries of a text in two fonts, the one made last kept outside the cache, as a text node keeps it, and
    // a weak reference to the other's string
    weak var otherString: NSAttributedString?
    var kept: SimpleTextCache.Entry?
    autoreleasepool {
      otherString = SimpleTextCache.entry(for: Self.settings(font: .systemFont(ofSize: 12))).string
      kept = SimpleTextCache.entry(for: Self.settings(font: .systemFont(ofSize: 20)))
    }
    expect(otherString) != nil

    // when: removing all strings
    SimpleTextCache.removeAll()

    // then: the other string is released, since the kept entry no longer links to its entry, and the kept entry still
    // has its own string
    expect(otherString) == nil
    expect(kept?.string.string) == "Text"
  }

  func test_removeAll_releasesTheStringLookedUpAfterAKeptEntry() {
    // given: the entries of two texts looked up one after the other, the first kept outside the cache, as a text node
    // keeps it, and a weak reference to the second's string, which the last lookup returned
    weak var nextString: NSAttributedString?
    var kept: SimpleTextCache.Entry?
    autoreleasepool {
      kept = SimpleTextCache.entry(for: Self.settings(text: "First"))
      nextString = SimpleTextCache.entry(for: Self.settings(text: "Second")).string
    }
    expect(nextString) != nil

    // when: removing all strings
    SimpleTextCache.removeAll()

    // then: the second string is released, since neither the kept entry's link nor the cache's last lookup keeps its
    // entry, and the kept entry still has its own string
    expect(nextString) == nil
    expect(kept?.string.string) == "First"
  }

  func test_memoryWarning_removesAllStrings() {
    // given: the string of some settings
    let string = SimpleTextCache.entry(for: Self.settings()).string

    // when: the system is low on memory, and looking up the string again
    MemoryWarning.handleMemoryWarning()
    let again = SimpleTextCache.entry(for: Self.settings()).string

    // then: the string is made again
    expect(again) !== string
  }

  func test_removeAll_countsTheNextGenerationFromZero() {
    // given: the string of a text, then of a text as long as a generation's bytes, which starts a generation of one
    // string, and all strings removed
    _ = SimpleTextCache.entry(for: Self.settings(text: "short")).string
    _ = SimpleTextCache.entry(for: Self.settings(text: String(repeating: "a", count: SimpleTextCache.generationByteLimit))).string
    SimpleTextCache.removeAll()

    // when: making the string of a text, then the strings of twice as many texts as a generation holds, less one, and
    // looking up the first string again
    let first = SimpleTextCache.entry(for: Self.settings(text: "first")).string
    for index in 0 ..< 2 * SimpleTextCache.generationLimit - 1 {
      _ = SimpleTextCache.entry(for: Self.settings(text: "\(index)")).string
    }
    let again = SimpleTextCache.entry(for: Self.settings(text: "first")).string

    // then: it's the same string, since the generation that holds it counted from zero, so the other strings filled it
    // and a second generation, which holds all but the last one, and the generation before still holds it
    expect(again) === first
  }

  func test_removeAll_makesTheStringsAgain() {
    // given: the string of some settings
    let string = SimpleTextCache.entry(for: Self.settings()).string

    // when: removing all strings, and looking up the string again
    SimpleTextCache.removeAll()
    let again = SimpleTextCache.entry(for: Self.settings()).string

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

  private static func settings(text: String = "Text",
                               font: Font = .systemFont(ofSize: 12),
                               textColor: ThemedColor = ThemedColor(.red),
                               textBackgroundColor: ThemedColor? = nil,
                               textShadow: Themed<NSShadow>? = nil,
                               textAlignment: NSTextAlignment = .center) -> SimpleTextCache.Settings
  {
    SimpleTextCache.Settings(
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
  private static func expectedString(for settings: SimpleTextCache.Settings) -> NSAttributedString {
    TextNode.attributedString(
      settings.text,
      font: settings.font,
      foregroundColor: settings.textColor,
      backgroundColor: settings.textBackgroundColor,
      shadow: settings.textShadow,
      textAlignment: settings.textAlignment,
      lineBreakMode: .byWordWrapping
    )
  }

  /// Returns settings with every attribute, made of new color and shadow objects each time, of components that the
  /// system doesn't keep a shared color of.
  private static func equalSettings() -> SimpleTextCache.Settings {
    settings(
      textColor: ThemedColor(Color(red: 0.25, green: 0.5, blue: 0.75, alpha: 1)),
      textBackgroundColor: ThemedColor(Color(red: 0.75, green: 0.5, blue: 0.25, alpha: 1)),
      textShadow: Themed(makeShadow(height: 1))
    )
  }

  /// Returns the key of a text and an alignment.
  private static func key(text: String = "Text", textAlignment: NSTextAlignment = .center) -> SimpleTextCache.Key {
    SimpleTextCache.Key(text: text, textAlignment: textAlignment)
  }
}
