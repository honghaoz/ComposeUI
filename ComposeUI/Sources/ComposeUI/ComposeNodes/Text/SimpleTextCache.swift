//
//  SimpleTextCache.swift
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

/// The attributed strings of simple text that `TextNode.singleLineText` and `TextNode.multiLineText` make, kept across
/// refreshes and keyed by the settings that make them.
///
/// The cache keeps two generations of strings, each of up to `generationLimit` strings and `generationByteLimit` bytes of
/// text, and empties itself when the system is low on memory.
///
/// Nodes are made and laid out on the main thread, so the cache is only used there.
enum SimpleTextCache {

  /// The settings that make the attributed string of simple text.
  struct Key: Hashable {

    let text: String
    let font: Font
    let textColor: ThemedColor
    let textBackgroundColor: ThemedColor?
    let textShadow: Themed<NSShadow>?
    let textAlignment: NSTextAlignment

    static func == (lhs: Key, rhs: Key) -> Bool {
      // `String ==` matches canonically equivalent text, such as a precomposed "é" and an "e" with a combining accent,
      // while a text node shows its text's exact characters, so the text is compared by its UTF-8 code units instead
      lhs.text.utf8.elementsEqual(rhs.text.utf8)
        && lhs.font == rhs.font
        && lhs.textColor == rhs.textColor
        && lhs.textBackgroundColor == rhs.textBackgroundColor
        && lhs.textShadow == rhs.textShadow
        && lhs.textAlignment == rhs.textAlignment
    }

    func hash(into hasher: inout Hasher) {
      // the text's UTF-8 code units, as `==` compares them, where `String`'s hash is the same for canonically
      // equivalent text that `==` keeps apart, so many such texts would all land in one bucket
      let isHashed: Bool? = text.utf8.withContiguousStorageIfAvailable { codeUnits in
        hasher.combine(bytes: UnsafeRawBufferPointer(codeUnits))
        return true
      }
      if isHashed == nil {
        // a string bridged from `NSString` doesn't store contiguous UTF-8, and its code units hash the same one by one
        for codeUnit in text.utf8 {
          hasher.combine(codeUnit)
        }
      }
      // 0xFF never occurs in UTF-8, so it ends the text unambiguously
      hasher.combine(UInt8(0xFF))
      hasher.combine(font)
      hasher.combine(textColor)
      hasher.combine(textBackgroundColor)
      hasher.combine(textShadow)
      hasher.combine(textAlignment)
    }

    /// Returns the key with copies of its shadows, which no caller can change.
    func copyingShadows() -> Key {
      guard let textShadow else {
        return self
      }
      return Key(
        text: text,
        font: font,
        textColor: textColor,
        textBackgroundColor: textBackgroundColor,
        textShadow: Themed(
          light: textShadow.light.copy() as! NSShadow, // swiftlint:disable:this force_cast
          dark: textShadow.dark.copy() as! NSShadow // swiftlint:disable:this force_cast
        ),
        textAlignment: textAlignment
      )
    }
  }

  /// The most strings that one generation holds.
  static let generationLimit = 4096

  /// The most text, in UTF-8 bytes, that one generation holds.
  static let generationByteLimit = 256 * 1024

  /// The strings looked up since the generations last rotated.
  private static var current: [Key: NSAttributedString] = [:]

  /// The UTF-8 bytes of the text in `current`.
  private static var currentByteCount = 0

  /// The strings of the generation before, which a lookup moves back to `current`.
  private static var previous: [Key: NSAttributedString] = [:]

  /// Whether the cache empties itself when the system is low on memory.
  private static var isHandlingMemoryWarnings = false

  /// Returns the attributed string for the settings, made once and then reused.
  ///
  /// - Parameter key: The settings that make the string.
  /// - Returns: The attributed string.
  static func attributedString(for key: Key) -> NSAttributedString {
    if let string = current[key] {
      return string
    }

    let byteCount = key.text.utf8.count
    if byteCount > generationByteLimit {
      // a text over the byte limit isn't kept, so the limit bounds each generation however long one text is
      return makeString(for: key)
    }

    if !isHandlingMemoryWarnings {
      isHandlingMemoryWarnings = true
      MemoryWarning.addHandler(removeAll)
    }

    let storedKey: Key
    let string: NSAttributedString
    if let index = previous.index(forKey: key) {
      let entry = previous.remove(at: index)
      storedKey = entry.key
      string = entry.value
    } else {
      // the stored key holds copies of the shadows, since `NSShadow` is mutable, and a caller's change to a shadow
      // would otherwise change the key in place, which a dictionary doesn't allow, and the string made of it
      storedKey = key.copyingShadows()
      string = makeString(for: storedKey)
    }

    if current.count >= generationLimit || currentByteCount + byteCount > generationByteLimit {
      // two generations keep the strings used since the generation before, where one dictionary emptied when full
      // would drop the strings that a refresh is about to make again. the byte limit bounds long texts' memory, which
      // the count limit alone doesn't
      previous = current
      current.removeAll(keepingCapacity: true)
      currentByteCount = 0
    }
    current[storedKey] = string
    currentByteCount += byteCount
    return string
  }

  /// Returns a new attributed string made of the settings.
  private static func makeString(for key: Key) -> NSAttributedString {
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

  /// Removes all strings.
  static func removeAll() {
    current = [:]
    currentByteCount = 0
    previous = [:]
  }
}
