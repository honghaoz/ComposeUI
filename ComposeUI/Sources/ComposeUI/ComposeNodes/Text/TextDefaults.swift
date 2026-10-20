//
//  TextDefaults.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/20/26.
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

/// The font and the text color of the text in labels and text nodes that the app doesn't set them for, made once
/// instead of for each node, since making a system font looks it up in the system's font cache with a new key each time.
@usableFromInline
enum TextDefaults {

  #if canImport(AppKit)
  /// The system font of a label's size.
  @usableFromInline
  static let font = Font.systemFont(ofSize: NSFont.systemFontSize)

  /// The label color.
  @usableFromInline
  static let textColor = ThemedColor(light: .labelColor, dark: .labelColor)

  /// Returns the system font of a label's size.
  ///
  /// - Parameter context: The layout context of the node.
  /// - Returns: The font.
  static func font(in context: ComposeNodeLayoutContext) -> Font {
    font
  }
  #endif

  #if canImport(UIKit)
  /// The system font of a label's size, which is semibold while Bold Text is on, for a node made outside of layout,
  /// which reads the Bold Text setting itself.
  @usableFromInline
  static var font: Font {
    fontCache.font(isBoldTextEnabled: readIsBoldTextEnabled(), make: makeFont)
  }

  /// The label color.
  @usableFromInline
  static let textColor = ThemedColor(light: .label, dark: .label)

  /// Returns the system font of a label's size, which is semibold while Bold Text is on.
  ///
  /// - Parameter context: The layout context of the node, whose layout pass reads the Bold Text setting once for the
  ///   nodes laid out in it.
  /// - Returns: The font.
  static func font(in context: ComposeNodeLayoutContext) -> Font {
    fontCache.font(inPass: context.passId, isBoldTextEnabled: readIsBoldTextEnabled(), make: makeFont)
  }

  /// Returns the system font of a label's size.
  private static func makeFont() -> Font {
    Font.systemFont(ofSize: fontSize)
  }

  /// Returns whether Bold Text is on.
  private static func readIsBoldTextEnabled() -> Bool {
    #if DEBUG
    WorkCounter.count(.boldTextSettingRead)
    #endif
    return UIAccessibility.isBoldTextEnabled
  }

  #if os(tvOS)
  /// The size of a label's system font.
  private static let fontSize: CGFloat = 20
  #else
  /// The size of a label's system font.
  private static let fontSize = Font.labelFontSize
  #endif

  /// The default font made last on the main thread.
  private static let fontCache = FontCache()

  /// A font kept with the Bold Text setting that it was made with, since the system font follows the setting.
  ///
  /// It keeps the font on the main thread, where nodes are laid out and usually made, and makes it for each lookup on
  /// another thread, instead of taking a lock for each lookup.
  ///
  /// A class, so that the cache can be a static constant: a mutating lookup of a struct in a static variable is
  /// checked for exclusive access at run time, as the access lasts through the call to the block.
  final class FontCache {

    /// The font made last on the main thread, with the Bold Text setting that it was made with.
    private var lastFont: (font: Font, isBoldTextEnabled: Bool)?

    /// The layout pass that read the Bold Text setting last.
    private var lastPassId: UInt64?

    /// Returns the font for a layout pass, which reads the Bold Text setting once for the nodes laid out in it, made
    /// with a block when the setting differs from the one that the last font was made with, and for each lookup off
    /// the main thread.
    ///
    /// - Parameters:
    ///   - passId: The layout pass of the lookup.
    ///   - isBoldTextEnabled: Whether Bold Text is on, read only on the main thread, once for each pass.
    ///   - make: The block that makes the font.
    /// - Returns: The font.
    func font(inPass passId: UInt64, isBoldTextEnabled: @autoclosure () -> Bool, make: () -> Font) -> Font {
      guard pthread_main_np() != 0 else {
        return make()
      }
      if passId == lastPassId, let lastFont {
        return lastFont.font
      } else {
        lastPassId = passId
        return font(isBoldTextEnabled: isBoldTextEnabled(), make: make)
      }
    }

    /// Returns the font for a Bold Text setting, made with a block when the setting differs from the one that the last
    /// font was made with, and for each lookup off the main thread.
    ///
    /// - Parameters:
    ///   - isBoldTextEnabled: Whether Bold Text is on, read only on the main thread, since UIKit isolates the setting
    ///     to the main actor.
    ///   - make: The block that makes the font.
    /// - Returns: The font.
    func font(isBoldTextEnabled: @autoclosure () -> Bool, make: () -> Font) -> Font {
      // `pthread_main_np()` instead of `Thread.isMainThread`, which sends an Objective-C message, since this runs for
      // each node
      guard pthread_main_np() != 0 else {
        return make()
      }
      let isBoldTextEnabled = isBoldTextEnabled()
      if let lastFont, lastFont.isBoldTextEnabled == isBoldTextEnabled {
        return lastFont.font
      } else {
        let font = make()
        lastFont = (font, isBoldTextEnabled)
        return font
      }
    }
  }
  #endif
}
