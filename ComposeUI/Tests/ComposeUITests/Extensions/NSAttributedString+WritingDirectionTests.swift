//
//  NSAttributedString+WritingDirectionTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/11/26.
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

class NSAttributedString_WritingDirectionTests: XCTestCase {

  func test_emptyText_returnsTheText() {
    // given: an empty text
    let text = NSAttributedString(string: "")

    // when: resolving its natural writing directions
    let resolvedText = text.resolvingNaturalWritingDirections(userWritingDirection: .leftToRight)

    // then: the text itself is returned
    expect(resolvedText) === text
  }

  func test_textInTheUserDirection_returnsTheText() {
    for (string, userWritingDirection) in [("Hello", .leftToRight), ("مرحبا", .rightToLeft)] as [(String, NSWritingDirection)] {
      for text in [Self.makeText(string), NSMutableAttributedString(attributedString: Self.makeText(string))] as [NSAttributedString] {
        // when: resolving the natural writing direction of a text in the user's direction, immutable or mutable
        let resolvedText = text.resolvingNaturalWritingDirections(userWritingDirection: userWritingDirection)

        // then: the text itself is returned, since TextKit 1 already lays it out in the user's direction
        expect(resolvedText, string) === text
      }
    }
  }

  func test_rightToLeftLetters_setRightToLeft() {
    let strings = [
      "שלום", // Hebrew
      "مرحبا", // Arabic
      "ܫܠܡܐ", // Syriac
      "ދިވެހި", // Thaana
      "ߒߞߏ", // NKo
      "\u{0800}", // Samaritan
      "\u{0840}", // Mandaic
      "\u{FB1D}", // Hebrew presentation form, the first
      "\u{FDFB}", // Arabic presentation form A
      "\u{FE70}", // Arabic presentation form B, the first
      "\u{FEFC}", // Arabic presentation form B, the last
      "\u{10840}", // Imperial Aramaic
      "\u{1E800}", // Mende Kikakui
      "\u{1E900}", // Adlam
      "\u{1EE00}", // Arabic mathematical letter
    ]
    for string in strings {
      // when: resolving the natural writing direction of a text that starts with a right-to-left letter, for a
      // left-to-right user language
      let resolvedText = Self.makeText(string).resolvingNaturalWritingDirections(userWritingDirection: .leftToRight)

      // then: the paragraph is right-to-left
      expect(Self.writingDirections(of: resolvedText), string) == [.rightToLeft]
    }
  }

  func test_leftToRightLetters_setLeftToRight() {
    let strings = [
      "Hello", // ASCII
      "Привет", // Cyrillic
      "Γεια", // Greek
      "你好", // CJK
      "こんにちは", // Hiragana
      "안녕", // Hangul
      "नमस्ते", // Devanagari
      "สวัสดี", // Thai
      "ǅ", // a titlecase letter
      "ʰ", // a modifier letter
      "\u{0587}", // Armenian, below the Hebrew block
      "\u{0904}", // Devanagari, above the Arabic extended blocks
      "\u{FB17}", // Armenian ligature, below the Hebrew presentation forms
      "\u{FF21}", // fullwidth Latin, above the Arabic presentation forms
      "\u{10780}", // Latin extended, below the historic right-to-left scripts
      "\u{11003}", // Brahmi, above the historic right-to-left scripts
      "\u{1E7E0}", // Ethiopic extended, below Mende Kikakui
      "\u{20000}", // CJK extension, above the Arabic mathematical letters
    ]
    for string in strings {
      // when: resolving the natural writing direction of a text that starts with a left-to-right letter, for a
      // right-to-left user language
      let resolvedText = Self.makeText(string).resolvingNaturalWritingDirections(userWritingDirection: .rightToLeft)

      // then: the paragraph is left-to-right
      expect(Self.writingDirections(of: resolvedText), string) == [.leftToRight]
    }
  }

  func test_paragraphs_resolveSeparately() {
    // given: a text of paragraphs in both directions, separated by each paragraph separator, and a line separator that
    // doesn't end a paragraph
    let text = Self.makeText("Hello\nمرحبا\r\nשלום\u{2029}World\rمرحبا\u{2028}Hello")

    // when: resolving its natural writing directions for a left-to-right user language
    let resolvedText = text.resolvingNaturalWritingDirections(userWritingDirection: .leftToRight)

    // then: each right-to-left paragraph is right-to-left, including its separator, and the others stay natural
    expect(Self.writingDirections(of: resolvedText)) == [.natural, .rightToLeft, .rightToLeft, .natural, .rightToLeft]
    expect(Self.writingDirection(of: resolvedText, at: 11)) == .rightToLeft // the "\r" of "\r\n"
    expect(Self.writingDirection(of: resolvedText, at: 12)) == .rightToLeft // the "\n" of "\r\n"
    expect(Self.writingDirection(of: resolvedText, at: 18)) == .natural // the "W" after the paragraph separator
    expect(resolvedText.string) == text.string
  }

  func test_explicitWritingDirection_isKept() {
    // given: a text of two right-to-left paragraphs, the first one explicitly left-to-right
    let text = NSMutableAttributedString(attributedString: Self.makeText("مرحبا\nمرحبا"))
    let style = NSMutableParagraphStyle()
    style.baseWritingDirection = .leftToRight
    text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: 6))

    // when: resolving its natural writing directions for a left-to-right user language
    let resolvedText = text.resolvingNaturalWritingDirections(userWritingDirection: .leftToRight)

    // then: the first paragraph keeps its direction, and only the second one is resolved
    expect(Self.writingDirections(of: resolvedText)) == [.leftToRight, .rightToLeft]
  }

  func test_resolvedParagraph_keepsItsParagraphStyleAndAttributes() throws {
    // given: a right-to-left text with a paragraph style that has a natural writing direction
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.lineSpacing = 4
    style.lineBreakMode = .byTruncatingTail
    let font = Font.systemFont(ofSize: 17)
    let text = NSAttributedString(string: "مرحبا", attributes: [.font: font, .foregroundColor: Color.red, .paragraphStyle: style])

    // when: resolving its natural writing direction for a left-to-right user language
    let resolvedText = text.resolvingNaturalWritingDirections(userWritingDirection: .leftToRight)

    // then: the paragraph style keeps its other settings, the other attributes stay, and the given text and style are
    // unchanged
    let resolvedStyle = try (resolvedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle).unwrap()
    expect(resolvedStyle.baseWritingDirection) == .rightToLeft
    expect(resolvedStyle.alignment) == .center
    expect(resolvedStyle.lineSpacing) == 4
    expect(resolvedStyle.lineBreakMode) == .byTruncatingTail
    expect(resolvedText.attribute(.font, at: 0, effectiveRange: nil) as? Font) == font
    expect(resolvedText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? Color) == Color.red
    expect(style.baseWritingDirection) == .natural
    expect(text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle) === style
  }

  func test_resolvedParagraph_takesTheParagraphStyleOfItsFirstCharacter() throws {
    // given: a right-to-left paragraph with a different paragraph style in its second half
    let firstStyle = NSMutableParagraphStyle()
    firstStyle.alignment = .center
    let secondStyle = NSMutableParagraphStyle()
    secondStyle.alignment = .left
    let text = NSMutableAttributedString(attributedString: Self.makeText("مرحبا بالعالم"))
    text.addAttribute(.paragraphStyle, value: firstStyle, range: NSRange(location: 0, length: 6))
    text.addAttribute(.paragraphStyle, value: secondStyle, range: NSRange(location: 6, length: 7))

    // when: resolving its natural writing direction for a left-to-right user language
    let resolvedText = text.resolvingNaturalWritingDirections(userWritingDirection: .leftToRight)

    // then: the whole paragraph takes the style of its first character, which TextKit lays it out with
    let lastStyle = try (resolvedText.attribute(.paragraphStyle, at: 12, effectiveRange: nil) as? NSParagraphStyle).unwrap()
    expect(lastStyle.alignment) == .center
    expect(lastStyle.baseWritingDirection) == .rightToLeft
  }

  func test_textWithoutLetters_keepsTheNaturalDirection() {
    for string in ["123 456", "!?", "😀👍", "١٢٣", "   ", "\n\n"] {
      for userWritingDirection in [NSWritingDirection.leftToRight, .rightToLeft] {
        // given: a text without a letter or directional mark
        let text = Self.makeText(string)

        // when: resolving its natural writing directions
        let resolvedText = text.resolvingNaturalWritingDirections(userWritingDirection: userWritingDirection)

        // then: the text itself is returned, so its paragraphs keep the natural direction
        expect(resolvedText, string) === text
      }
    }
  }

  func test_charactersBeforeTheFirstLetter_areSkipped() {
    for (string, userWritingDirection, expectedDirection) in [
      ("123 مرحبا", .leftToRight, .rightToLeft), // digits
      ("(«مرحبا»)", .leftToRight, .rightToLeft), // punctuation
      ("😀 שלום", .leftToRight, .rightToLeft), // an emoji
      ("١٢٣ Hello", .rightToLeft, .leftToRight), // Arabic digits, which are in the Arabic block
      ("\u{0301}مرحبا", .leftToRight, .rightToLeft), // a combining mark
      ("\u{05B0}Hello", .rightToLeft, .leftToRight), // a Hebrew point, which is in the Hebrew block
    ] as [(String, NSWritingDirection, NSWritingDirection)] {
      // when: resolving the natural writing direction of a text with characters before its first letter
      let resolvedText = Self.makeText(string).resolvingNaturalWritingDirections(userWritingDirection: userWritingDirection)

      // then: the paragraph takes the direction of its first letter
      expect(Self.writingDirections(of: resolvedText), string) == [expectedDirection]
    }
  }

  func test_directionalMarks_decideTheDirection() {
    for (string, userWritingDirection, expectedDirection) in [
      ("\u{200F}123", .leftToRight, .rightToLeft), // right-to-left mark
      ("\u{061C}123", .leftToRight, .rightToLeft), // Arabic letter mark
      ("\u{200F}Hello", .leftToRight, .rightToLeft), // a right-to-left mark before a left-to-right letter
      ("\u{200E}مرحبا", .rightToLeft, .leftToRight), // left-to-right mark
    ] as [(String, NSWritingDirection, NSWritingDirection)] {
      // when: resolving the natural writing direction of a text that starts with a directional mark
      let resolvedText = Self.makeText(string).resolvingNaturalWritingDirections(userWritingDirection: userWritingDirection)

      // then: the paragraph takes the direction of the mark
      expect(Self.writingDirections(of: resolvedText), string) == [expectedDirection]
    }
  }

  func test_directionalIsolates_areSkipped() {
    for (string, userWritingDirection, expectedDirection) in [
      ("\u{2067}abc\u{2069} مرحبا", .leftToRight, .rightToLeft), // right-to-left isolate
      ("\u{2066}مرحبا\u{2069}abc", .rightToLeft, .leftToRight), // left-to-right isolate
      ("\u{2068}مرحبا\u{2069}abc", .rightToLeft, .leftToRight), // first strong isolate
      ("\u{2066}\u{2067}abc\u{2069}def\u{2069}مرحبا", .leftToRight, .rightToLeft), // nested isolates
      ("\u{2069}مرحبا", .leftToRight, .rightToLeft), // a pop without an isolate
    ] as [(String, NSWritingDirection, NSWritingDirection)] {
      // when: resolving the natural writing direction of a text that starts with a directional isolate
      let resolvedText = Self.makeText(string).resolvingNaturalWritingDirections(userWritingDirection: userWritingDirection)

      // then: the paragraph takes the direction of its first letter outside the isolates
      expect(Self.writingDirections(of: resolvedText), string) == [expectedDirection]
    }
  }

  func test_unclosedDirectionalIsolate_keepsTheNaturalDirection() {
    // given: a text whose only letters are in an isolate that the paragraph doesn't close
    let text = Self.makeText("\u{2067}مرحبا\nHello")

    // when: resolving its natural writing directions for a left-to-right user language
    let resolvedText = text.resolvingNaturalWritingDirections(userWritingDirection: .leftToRight)

    // then: the text itself is returned, since the isolate ends with its paragraph
    expect(resolvedText) === text
  }

  func test_unpairedSurrogates_areSkipped() {
    for (codeUnits, expectedDirections) in [
      ([0xD83D, 0x0645], [.rightToLeft]), // a lead surrogate before an Arabic letter
      ([0xDE00, 0x0645], [.rightToLeft]), // a trail surrogate before an Arabic letter
      ([0x0031, 0xD83D, 0x000A, 0x0645], [.natural, .rightToLeft]), // a lead surrogate that ends a paragraph
    ] as [([UInt16], [NSWritingDirection])] {
      // given: a text with an unpaired surrogate, made through Core Foundation, since a Swift string replaces an
      // unpaired surrogate
      let string = NSString(characters: codeUnits, length: codeUnits.count)
      let text = CFAttributedStringCreate(nil, string as CFString, nil) as NSAttributedString
      let shownString: CFString = CFAttributedStringGetString(text as CFAttributedString)
      expect((0 ..< codeUnits.count).map { CFStringGetCharacterAtIndex(shownString, $0) }) == codeUnits

      // when: resolving its natural writing directions for a left-to-right user language
      let resolvedText = text.resolvingNaturalWritingDirections(userWritingDirection: .leftToRight)

      // then: the surrogate is skipped
      expect(Self.writingDirections(of: resolvedText), "\(codeUnits)") == expectedDirections
    }
  }

  func test_mutableText_isntChanged() {
    // given: a mutable right-to-left text
    let text = NSMutableAttributedString(attributedString: Self.makeText("مرحبا"))

    // when: resolving its natural writing direction for a left-to-right user language
    let resolvedText = text.resolvingNaturalWritingDirections(userWritingDirection: .leftToRight)

    // then: a new text has the direction, and the given text is unchanged
    expect(resolvedText) !== text
    expect(Self.writingDirections(of: resolvedText)) == [.rightToLeft]
    expect(text.attribute(.paragraphStyle, at: 0, effectiveRange: nil)) == nil
  }

  func test_withoutAUserDirection_usesTheUserLanguageDirection() {
    for string in ["Hello", "مرحبا"] {
      // when: resolving the natural writing direction of a text without giving the user's direction
      let resolvedText = Self.makeText(string).resolvingNaturalWritingDirections()

      // then: the paragraph is resolved as for the direction of the user's language
      let userWritingDirection = NSParagraphStyle.defaultWritingDirection(forLanguage: nil)
      let expectedText = Self.makeText(string).resolvingNaturalWritingDirections(userWritingDirection: userWritingDirection)
      expect(Self.writingDirections(of: resolvedText), string) == Self.writingDirections(of: expectedText)
    }
  }

  // MARK: - Helpers

  private static func makeText(_ string: String) -> NSAttributedString {
    NSAttributedString(string: string, attributes: [.font: Font.systemFont(ofSize: 13)])
  }

  /// Returns the writing direction of each paragraph, from the paragraph style of its first character.
  private static func writingDirections(of text: NSAttributedString) -> [NSWritingDirection] {
    let string = text.string as NSString
    var directions: [NSWritingDirection] = []
    var location = 0
    while location < string.length {
      directions.append(writingDirection(of: text, at: location))
      location = NSMaxRange(string.paragraphRange(for: NSRange(location: location, length: 0)))
    }
    return directions
  }

  /// Returns the writing direction of the paragraph style at a location.
  private static func writingDirection(of text: NSAttributedString, at location: Int) -> NSWritingDirection {
    (text.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle)?.baseWritingDirection ?? .natural
  }
}
