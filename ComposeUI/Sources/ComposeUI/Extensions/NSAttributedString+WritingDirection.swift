//
//  NSAttributedString+WritingDirection.swift
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

import Foundation

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

extension NSAttributedString {

  /// Returns the text with each paragraph that has a natural writing direction given the direction of its text.
  ///
  /// TextKit 1 aligns the lines of a paragraph with a natural writing direction by the direction of the user's language,
  /// while TextKit 2 and Core Text take the direction from the paragraph's first character with a strong direction, as
  /// the Unicode Bidirectional Algorithm does. This takes it from the paragraph's first character with a strong
  /// direction, see `strongWritingDirection(of:)`, and leaves a paragraph without one natural.
  ///
  /// - Returns: The text with the resolved writing directions, or the text itself when no paragraph needs one.
  func resolvingNaturalWritingDirections() -> NSAttributedString {
    resolvingNaturalWritingDirections(userWritingDirection: NSParagraphStyle.defaultWritingDirection(forLanguage: nil))
  }

  /// Returns the text with each paragraph that has a natural writing direction given the direction of its text.
  ///
  /// - Parameter userWritingDirection: The direction of the user's language, which TextKit 1 aligns a paragraph with a
  ///   natural writing direction by.
  /// - Returns: The text with the resolved writing directions, or the text itself when no paragraph needs one.
  func resolvingNaturalWritingDirections(userWritingDirection: NSWritingDirection) -> NSAttributedString {
    // the string is read through Core Foundation, since `string` copies the string of a mutable text when it bridges it
    let string: CFString = CFAttributedStringGetString(self as CFAttributedString)
    let length = CFStringGetLength(string)

    var resolvedText: NSMutableAttributedString?
    var paragraphStart = 0
    while paragraphStart < length {
      var paragraphEnd = 0
      CFStringGetParagraphBounds(string, CFRange(location: paragraphStart, length: 0), nil, &paragraphEnd, nil)
      let paragraphRange = NSRange(location: paragraphStart, length: paragraphEnd - paragraphStart)

      // a paragraph in the user's direction is left natural, so that a text in the user's direction isn't copied. the
      // direction is checked before the paragraph style, which most paragraphs then don't need read
      if let direction = Self.firstStrongWritingDirection(in: string, range: paragraphRange), direction != userWritingDirection {
        // TextKit lays out a paragraph with the paragraph style of its first character
        let paragraphStyle = attribute(.paragraphStyle, at: paragraphStart, effectiveRange: nil) as? NSParagraphStyle
        if paragraphStyle?.baseWritingDirection ?? .natural == .natural {
          let resolvedStyle = (paragraphStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
          resolvedStyle.baseWritingDirection = direction

          let text = resolvedText ?? NSMutableAttributedString(attributedString: self)
          text.addAttribute(.paragraphStyle, value: resolvedStyle, range: paragraphRange)
          resolvedText = text
        }
      }

      paragraphStart = paragraphEnd
    }

    return resolvedText ?? self
  }

  /// Returns the direction of the first character with a strong direction in the range, skipping the text in
  /// directional isolates, as rule P2 of the Unicode Bidirectional Algorithm does.
  private static func firstStrongWritingDirection(in string: CFString, range: NSRange) -> NSWritingDirection? {
    let end = range.location + range.length
    var index = range.location
    var isolateDepth = 0
    while index < end {
      var value = UInt32(CFStringGetCharacterAtIndex(string, index))
      index += 1

      if UTF16.isLeadSurrogate(UInt16(value)), index < end {
        let trail = CFStringGetCharacterAtIndex(string, index)
        if UTF16.isTrailSurrogate(trail) {
          value = 0x10000 + ((value - 0xD800) << 10) + (UInt32(trail) - 0xDC00)
          index += 1
        }
      }

      switch value {
      case 0x2066 ... 0x2068: // left-to-right, right-to-left and first strong isolates
        isolateDepth += 1
      case 0x2069: // pop directional isolate
        isolateDepth = max(isolateDepth - 1, 0)
      default:
        if isolateDepth == 0, let direction = strongWritingDirection(of: value) {
          return direction
        }
      }
    }

    return nil
  }

  /// Returns the direction of a character with a strong direction, or `nil` for other characters, such as digits,
  /// most punctuation and combining marks, which don't decide a paragraph's direction.
  ///
  /// The characters with a right-to-left direction are found as of Unicode 18. Of the characters with a left-to-right
  /// direction, this finds the letters, the marks that take space, the numbers made of letters, the private use
  /// characters and the digits that don't act as ASCII digits, and treats the rest, such as Braille and circled letters,
  /// as neutral.
  private static func strongWritingDirection(of value: UInt32) -> NSWritingDirection? {
    switch value {
    case 0x41 ... 0x5A,
         0x61 ... 0x7A: // ASCII letters, checked first as the most common
      return .leftToRight
    case 0 ..< 0x80:
      return nil
    case 0x0590 ... 0x08FF, // Hebrew, Arabic, Syriac, Thaana, NKo, Samaritan and Mandaic
         0xFB1D ... 0xFDFF, // Hebrew and Arabic presentation forms
         0xFE70 ... 0xFEFF, // Arabic presentation forms
         0x10800 ... 0x10FFF, // historic right-to-left scripts
         0x1E800 ... 0x1EFFF: // Mende Kikakui, Adlam and Arabic mathematical letters
      return isRightToLeftInRightToLeftBlocks(value) ? .rightToLeft : nil
    case 0x200E: // left-to-right mark
      return .leftToRight
    case 0x200F: // right-to-left mark, the only right-to-left character outside these blocks
      return .rightToLeft
    case 0x02B9 ... 0x02BA,
         0x02C6 ... 0x02CF,
         0x02EC,
         0x0374,
         0x208F,
         0x2E2F,
         0xA67F,
         0xA717 ... 0xA71F,
         0xA788, // modifier letters
         0xFF10 ... 0xFF19,
         0x1CCF0 ... 0x1CCF9,
         0x1D7CE ... 0x1D7FF,
         0x1FBF0 ... 0x1FBF9, // digits that act as ASCII digits
         0x10140 ... 0x10174: // Greek acrophonic numerals
      // these are neutral, unlike the rest of their categories
      return nil
    default:
      guard let scalar = Unicode.Scalar(value) else {
        return nil
      }

      switch scalar.properties.generalCategory {
      case .uppercaseLetter,
           .lowercaseLetter,
           .titlecaseLetter,
           .modifierLetter,
           .otherLetter,
           .spacingMark,
           .letterNumber,
           .decimalNumber,
           .privateUse:
        return .leftToRight
      default:
        return nil
      }
    }
  }

  /// Returns whether a character of the right-to-left blocks has a right-to-left direction, as all of them have but the
  /// marks, the format characters, the digits and some signs.
  private static func isRightToLeftInRightToLeftBlocks(_ value: UInt32) -> Bool {
    switch value {
    case 0x061C,
         0x070F, // Arabic letter mark, Syriac abbreviation mark
         0x07C0 ... 0x07C9,
         0x1E950 ... 0x1E959: // NKo and Adlam digits
      // these are right-to-left, unlike the rest of their categories
      return true
    case 0x0606 ... 0x0607,
         0x0609 ... 0x060A,
         0x060C,
         0x060E ... 0x060F,
         0x066A ... 0x066C,
         0x06DE,
         0x06E9,
         0x07F6 ... 0x07F9,
         0xFB29,
         0xFBC3 ... 0xFBD2,
         0xFD3E ... 0xFD4F,
         0xFD90 ... 0xFD91,
         0xFDC8 ... 0xFDCF,
         0xFDFD ... 0xFDFF,
         0x1091F,
         0x10B39 ... 0x10B3F,
         0x10D6E,
         0x10E60 ... 0x10E7E,
         0x10ED0 ... 0x10ED8,
         0x1EEF0 ... 0x1EEF1:
      // the neutral signs of these blocks, such as the Arabic comma and the Hebrew plus sign
      return false
    default:
      // the blocks have no surrogates, so each value is a scalar
      switch Unicode.Scalar(value)?.properties.generalCategory {
      case .nonspacingMark?,
           .enclosingMark?,
           .format?,
           .decimalNumber?:
        return false
      default:
        return true
      }
    }
  }
}
