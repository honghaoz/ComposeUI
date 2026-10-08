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
  }

  /// The most strings that one generation holds.
  static let generationLimit = 4096

  /// The strings looked up since the generations last rotated.
  private static var current: [Key: NSAttributedString] = [:]

  /// The strings of the generation before, which a lookup moves back to `current`.
  private static var previous: [Key: NSAttributedString] = [:]

  /// Returns the attributed string for the settings, made once and then reused.
  ///
  /// - Parameter key: The settings that make the string.
  /// - Returns: The attributed string.
  static func attributedString(for key: Key) -> NSAttributedString {
    if let string = current[key] {
      return string
    }

    let string = previous.removeValue(forKey: key) ?? TextNode.attributedString(
      key.text,
      font: key.font,
      foregroundColor: key.textColor,
      backgroundColor: key.textBackgroundColor,
      shadow: key.textShadow,
      textAlignment: key.textAlignment,
      lineBreakMode: .byWordWrapping
    )
    if current.count >= generationLimit {
      // two generations keep the strings used since the generation before, where one dictionary emptied when full
      // would drop the strings that a refresh is about to make again
      previous = current
      current.removeAll(keepingCapacity: true)
    }
    current[key] = string
    return string
  }

  /// Removes all strings.
  static func removeAll() {
    current = [:]
    previous = [:]
  }
}
