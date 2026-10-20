//
//  LabelNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
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

public typealias Label = LabelNode

/// A node that renders a text label.
///
/// By default, the label node is single line, with a fixed size based on the text.
/// If you set `numberOfLines` to multiple lines, the width will be flexible, and the height will be fixed.
///
/// Use `fixedSize(width:height:)` to control whether the node uses its intrinsic
/// content size or adapts to the container size for each dimension.
public struct LabelNode: ComposeNode, IntrinsicSizableComposeNode {

  private let text: String
  private var font: Font

  private var textColor: ThemedColor
  private var textBackgroundColor: ThemedColor?
  private var textShadow: Themed<NSShadow>?

  private var textAlignment: NSTextAlignment
  private var numberOfLines: Int
  private var lineBreakMode: NSLineBreakMode

  private var isSelectable: Bool

  public var isFixedWidth: Bool
  public var isFixedHeight: Bool

  private var node: TextNode?

  /// Initialize a label node with a single line of text.
  ///
  /// - Parameter text: The text to render.
  public init(_ text: String) {
    self.text = text

    font = Defaults.font
    textColor = Defaults.textColor

    // `textBackgroundColor` and `textShadow` start as `nil`, and assigning them again would make the compiler copy
    // the node when the initializer returns

    textAlignment = .center
    numberOfLines = 1
    lineBreakMode = .byTruncatingTail

    isSelectable = false

    isFixedWidth = true
    isFixedHeight = true
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.label)

  public var size: CGSize {
    guard let node else {
      ComposeUI.assertFailure("layout(containerSize:context:) should be called before calling size")
      return .zero
    }
    return node.size
  }

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    if node == nil {
      // the text node is made in place, since one made in a local variable and then stored is copied
      if numberOfLines == 1 {
        node = TextNode.singleLineText(
          text,
          font: font,
          foregroundColor: textColor,
          backgroundColor: textBackgroundColor,
          shadow: textShadow,
          textAlignment: textAlignment,
          lineBreakMode: lineBreakMode,
          isSelectable: isSelectable
        )
      } else {
        node = TextNode.multiLineText(
          text,
          font: font,
          foregroundColor: textColor,
          backgroundColor: textBackgroundColor,
          shadow: textShadow,
          textAlignment: textAlignment,
          numberOfLines: numberOfLines,
          lineBreakMode: lineBreakMode,
          isSelectable: isSelectable
        )
      }
      node!.isFixedWidth = isFixedWidth // swiftlint:disable:this force_unwrapping
      node!.isFixedHeight = isFixedHeight // swiftlint:disable:this force_unwrapping
      node!.id = id // swiftlint:disable:this force_unwrapping
    }

    return node!.layout(containerSize: containerSize, context: context) // swiftlint:disable:this force_unwrapping
  }

  public func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
    guard let node else {
      ComposeUI.assertFailure("layout(containerSize:context:) should be called before calling render(visibleBounds:into:)")
      return
    }
    node.render(visibleBounds: visibleBounds, into: &items)
  }

  // MARK: - Defaults

  /// The font and the text color of a label that the app doesn't set them for, made once instead of for each label,
  /// since making a system font looks it up in the system's font cache with a new key each time.
  enum Defaults {

    #if canImport(AppKit)
    static let font = Font.systemFont(ofSize: NSFont.systemFontSize)

    static let textColor = ThemedColor(light: .labelColor, dark: .labelColor)
    #endif

    #if canImport(UIKit)
    static let textColor = ThemedColor(light: .label, dark: .label)

    /// The system font of a label's size, which is semibold while Bold Text is on.
    static var font: Font {
      fontCache.font(isBoldTextEnabled: UIAccessibility.isBoldTextEnabled) {
        Font.systemFont(ofSize: fontSize)
      }
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
    /// It keeps the font on the main thread, where a refresh makes its labels, and makes it for each lookup on another
    /// thread, instead of taking a lock for each lookup.
    ///
    /// A class, so that the cache can be a static constant: a mutating lookup of a struct in a static variable is
    /// checked for exclusive access at run time, as the access lasts through the call to the block.
    final class FontCache {

      /// The font made last on the main thread, with the Bold Text setting that it was made with.
      private var lastFont: (font: Font, isBoldTextEnabled: Bool)?

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
        // each label
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

  // MARK: - Public

  /// Set the font of the label.
  ///
  /// - Parameter value: The font to set.
  /// - Returns: A new label node with the updated font.
  public consuming func font(_ value: Font) -> Self {
    guard font != value else {
      return consume self
    }

    font = value
    node = nil // invalidate the node so that it will be recreated with the new font
    return consume self
  }

  /// Set the text color of the label.
  ///
  /// - Parameter value: The text color to set.
  /// - Returns: A new label node with the updated text color.
  public consuming func textColor(_ value: ThemedColor) -> Self {
    guard textColor != value else {
      return consume self
    }

    textColor = value
    node = nil // invalidate the node so that it will be recreated with the new text color
    return consume self
  }

  /// Set the text color of the label.
  ///
  /// - Parameter value: The text color to set.
  /// - Returns: A new label node with the updated text color.
  public consuming func textColor(_ value: Color) -> Self {
    textColor(ThemedColor(light: value, dark: value))
  }

  /// Set the background color of the label.
  ///
  /// - Parameter value: The background color to set.
  /// - Returns: A new label node with the updated background color.
  public consuming func textBackgroundColor(_ value: ThemedColor?) -> Self {
    guard textBackgroundColor != value else {
      return consume self
    }

    textBackgroundColor = value
    node = nil // invalidate the node so that it will be recreated with the new background color
    return consume self
  }

  /// Set the shadow of the label text.

  /// - Parameter value: The shadow to set.
  /// - Returns: A new label node with the updated shadow.
  public consuming func textShadow(_ value: Themed<NSShadow>?) -> Self {
    guard textShadow != value else {
      return consume self
    }

    textShadow = value
    node = nil // invalidate the node so that it will be recreated with the new shadow
    return consume self
  }

  /// Set the text alignment of the label.
  ///
  /// - Parameter value: The text alignment to set.
  /// - Returns: A new label node with the updated text alignment.
  public consuming func textAlignment(_ value: NSTextAlignment) -> Self {
    guard textAlignment != value else {
      return consume self
    }

    textAlignment = value
    node = nil // invalidate the node so that it will be recreated with the new text alignment
    return consume self
  }

  /// Set the number of lines of the label.
  ///
  /// Setting `numberOfLines` will change the node's intrinsic size behavior:
  /// - Single line (`numberOfLines = 1`): Uses intrinsic width and height (fits text exactly)
  /// - Multi-line (`numberOfLines = 0` or `2+`): Uses flexible width (fills container) and intrinsic height (fits text)
  ///
  /// - Parameter value: The number of lines to set.
  /// - Returns: A new label node with the updated number of lines.
  public consuming func numberOfLines(_ value: Int) -> Self {
    let value = max(value, 0)
    let isMultiLine = value != 1

    // only want to change fixed size if it's multi-line
    let targetIsFixedWidth: Bool? = isMultiLine ? !isMultiLine : nil
    let targetIsFixedHeight: Bool? = isMultiLine ? isMultiLine : nil

    guard numberOfLines != value || (targetIsFixedWidth != nil && isFixedWidth != targetIsFixedWidth) || (targetIsFixedHeight != nil && isFixedHeight != targetIsFixedHeight) else {
      return consume self
    }

    numberOfLines = value

    if isMultiLine {
      isFixedWidth = false
      isFixedHeight = true
    }

    node = nil // invalidate the node so that it will be recreated with the new number of lines

    return consume self
  }

  /// Set the line break mode of the label.
  ///
  /// - Parameter value: The line break mode to set.
  /// - Returns: A new label node with the updated line break mode.
  public consuming func lineBreakMode(_ value: NSLineBreakMode) -> Self {
    guard lineBreakMode != value else {
      return consume self
    }

    lineBreakMode = value
    node = nil // invalidate the node so that it will be recreated with the new line break mode
    return consume self
  }

  /// Set whether the label is selectable.
  ///
  /// - Parameter value: A boolean indicating whether the label is selectable. The default value is `true`.
  /// - Returns: A new label node with the updated selectable state.
  public consuming func selectable(_ value: Bool = true) -> Self {
    guard isSelectable != value else {
      return consume self
    }

    isSelectable = value
    node = nil // invalidate the node so that it will be recreated with the new selectable state
    return consume self
  }
}
