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

  /// The font that the app sets, or `nil` for the default font, which the label takes when it lays out.
  private var font: Font?

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

    textColor = TextDefaults.textColor

    // `font`, `textBackgroundColor` and `textShadow` start as `nil`, and assigning them again would make the compiler
    // copy the node when the initializer returns

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
    // the size is kept apart from the text node, since reading the optional node copies the whole node to check that
    // it's there, which a stack would do for each read of a child's size, so only the debug builds other than the
    // benchmarks' check the node
    #if DEBUG && !COMPOSEUI_BENCHMARK
    if node == nil {
      ComposeUI.assertFailure("layout(containerSize:context:) should be called before calling size")
    }
    #endif
    return layoutSize
  }

  /// The label's size from its latest layout.
  private var layoutSize: CGSize = .zero

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    if node == nil {
      // the default font is taken here, with the layout pass's one read of the Bold Text setting, instead of in the
      // initializer, where each label would read the setting
      let font = font ?? TextDefaults.font(in: context)

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

    let sizing = node!.layout(containerSize: containerSize, context: context) // swiftlint:disable:this force_unwrapping
    layoutSize = node!.size // swiftlint:disable:this force_unwrapping
    return sizing
  }

  public func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
    guard let node else {
      ComposeUI.assertFailure("layout(containerSize:context:) should be called before calling render(visibleBounds:into:)")
      return
    }
    node.render(visibleBounds: visibleBounds, into: &items)
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
  /// `.byCharWrapping` breaks every line between characters, and the other modes set how the last line ends.
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
