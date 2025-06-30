//
//  NSAttributedString+Theme.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/27/25.
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

public extension NSAttributedString.Key {

  /// The key for the themed foreground color of the attributed string.
  ///
  /// The value is a `ThemedColor` object.
  ///
  /// - Note: This key is not used by ComposeUI internally.
  static let themedForegroundColor = NSAttributedString.Key("io.chouti.composeui.themedForegroundColor")

  /// The key for the themed background color of the attributed string.
  ///
  /// The value is a `ThemedColor` object.
  ///
  /// - Note: This key is not used by ComposeUI internally.
  static let themedBackgroundColor = NSAttributedString.Key("io.chouti.composeui.themedBackgroundColor")

  /// The key for the themed shadow of the attributed string.
  ///
  /// The value is a `Themed<NSShadow>` object.
  ///
  /// - Note: This key is not used by ComposeUI internally.
  static let themedShadow = NSAttributedString.Key("io.chouti.composeui.themedShadow")
}

extension NSAttributedString {

  /// Applies the theme to the attributed string.
  ///
  /// Note: If the attributed string is already mutable, it will be used directly. Otherwise, a new mutable attributed string will be created.
  ///
  /// - Parameter theme: The theme to apply.
  /// - Returns: The attributed string with the theme applied.
  func apply(theme: Theme) -> NSAttributedString {
    let mutable: NSMutableAttributedString = self as? NSMutableAttributedString ?? NSMutableAttributedString(attributedString: self)
    mutable.enumerateAttribute(.themedForegroundColor, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, stop in
      if let value = value, let color = (value as? ThemedColor).assertNotNil("expected ThemedColor for .themedForegroundColor, got \(value)") {
        mutable.addAttribute(.foregroundColor, value: color.resolve(for: theme), range: range)
      }
    }
    mutable.enumerateAttribute(.themedBackgroundColor, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, stop in
      if let value = value, let color = (value as? ThemedColor).assertNotNil("expected ThemedColor for .themedBackgroundColor, got \(value)") {
        mutable.addAttribute(.backgroundColor, value: color.resolve(for: theme), range: range)
      }
    }
    mutable.enumerateAttribute(.themedShadow, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, stop in
      if let value = value, let shadow = (value as? Themed<NSShadow>).assertNotNil("expected Themed<NSShadow> for .themedShadow, got \(value)") {
        mutable.addAttribute(.shadow, value: shadow.resolve(for: theme), range: range)
      }
    }
    return mutable
  }
}
