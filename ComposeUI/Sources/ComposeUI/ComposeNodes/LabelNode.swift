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
/// Use `fixedSize(width:height:)` to set the width and height to be fixed or flexible.
public struct LabelNode: ComposeNode, FixedSizableComposeNode {

  private let text: String
  private var font: Font

  private var textColor: ThemedColor
  private var backgroundColor: ThemedColor?
  private var shadow: Themed<NSShadow>?

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

    #if canImport(AppKit)
    font = .systemFont(ofSize: NSFont.systemFontSize)
    textColor = ThemedColor(light: .labelColor, dark: .labelColor)
    #endif

    #if canImport(UIKit)
    #if os(iOS) || os(visionOS)
    font = .systemFont(ofSize: Font.labelFontSize)
    #elseif os(tvOS)
    font = .systemFont(ofSize: 20)
    #endif
    textColor = ThemedColor(light: .label, dark: .label)
    #endif

    backgroundColor = nil
    shadow = nil

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
      if numberOfLines == 1 {
        node = TextNode.singleLineText(
          text,
          font: font,
          foregroundColor: textColor,
          backgroundColor: backgroundColor,
          shadow: shadow,
          textAlignment: textAlignment
        )
      } else {
        node = TextNode.multiLineText(
          text,
          font: font,
          foregroundColor: textColor,
          backgroundColor: backgroundColor,
          shadow: shadow,
          textAlignment: textAlignment,
          numberOfLines: numberOfLines
        )
      }

      node = node?.lineBreakMode(lineBreakMode)
        .selectable(isSelectable)
        .fixedSize(width: isFixedWidth, height: isFixedHeight)

      node?.id = id
    }

    return node!.layout(containerSize: containerSize, context: context) // swiftlint:disable:this force_unwrapping
  }

  public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    guard let node else {
      ComposeUI.assertFailure("layout(containerSize:context:) should be called before calling renderableItems(in:)")
      return []
    }
    return node.renderableItems(in: visibleBounds)
  }

  // MARK: - Public

  /// Set the font of the label.
  ///
  /// - Parameter value: The font to set.
  /// - Returns: A new label node with the updated font.
  public func font(_ value: Font) -> Self {
    guard font != value else {
      return self
    }

    var copy = self
    copy.font = value
    copy.node = nil // invalidate the node so that it will be recreated with the new font
    return copy
  }

  /// Set the text color of the label.
  ///
  /// - Parameter value: The text color to set.
  /// - Returns: A new label node with the updated text color.
  public func textColor(_ value: ThemedColor) -> Self {
    guard textColor != value else {
      return self
    }

    var copy = self
    copy.textColor = value
    copy.node = nil // invalidate the node so that it will be recreated with the new text color
    return copy
  }

  /// Set the text color of the label.
  ///
  /// - Parameter value: The text color to set.
  /// - Returns: A new label node with the updated text color.
  public func textColor(_ value: Color) -> Self {
    textColor(ThemedColor(light: value, dark: value))
  }

  /// Set the background color of the label.
  ///
  /// - Parameter value: The background color to set.
  /// - Returns: A new label node with the updated background color.
  public func backgroundColor(_ value: ThemedColor?) -> Self {
    guard backgroundColor != value else {
      return self
    }

    var copy = self
    copy.backgroundColor = value
    copy.node = nil // invalidate the node so that it will be recreated with the new background color
    return copy
  }

  /// Set the shadow of the label text.

  /// - Parameter value: The shadow to set.
  /// - Returns: A new label node with the updated shadow.
  public func shadow(_ value: Themed<NSShadow>?) -> Self {
    guard shadow != value else {
      return self
    }

    var copy = self
    copy.shadow = value
    copy.node = nil // invalidate the node so that it will be recreated with the new shadow
    return copy
  }

  /// Set the text alignment of the label.
  ///
  /// - Parameter value: The text alignment to set.
  /// - Returns: A new label node with the updated text alignment.
  public func textAlignment(_ value: NSTextAlignment) -> Self {
    guard textAlignment != value else {
      return self
    }

    var copy = self
    copy.textAlignment = value
    copy.node = nil // invalidate the node so that it will be recreated with the new text alignment
    return copy
  }

  /// Set the number of lines of the label.
  ///
  /// Set `numberOfLines` to 0 or 2+ will make the label node have a flexible width and a fixed height.
  ///
  /// - Parameter value: The number of lines to set.
  /// - Returns: A new label node with the updated number of lines.
  public func numberOfLines(_ value: Int) -> Self {
    let value = max(value, 0)
    let isMultiLine = value != 1

    // only want to change fixed size if it's multi-line
    let targetIsFixedWidth: Bool? = isMultiLine ? !isMultiLine : nil
    let targetIsFixedHeight: Bool? = isMultiLine ? isMultiLine : nil

    guard numberOfLines != value || (targetIsFixedWidth != nil && isFixedWidth != targetIsFixedWidth) || (targetIsFixedHeight != nil && isFixedHeight != targetIsFixedHeight) else {
      return self
    }

    var copy = self
    copy.numberOfLines = value

    if isMultiLine {
      copy.isFixedWidth = false
      copy.isFixedHeight = true
    }

    copy.node = nil // invalidate the node so that it will be recreated with the new number of lines

    return copy
  }

  /// Set the line break mode of the label.
  ///
  /// - Parameter value: The line break mode to set.
  /// - Returns: A new label node with the updated line break mode.
  public func lineBreakMode(_ value: NSLineBreakMode) -> Self {
    guard lineBreakMode != value else {
      return self
    }

    var copy = self
    copy.lineBreakMode = value
    copy.node = nil // invalidate the node so that it will be recreated with the new line break mode
    return copy
  }

  /// Set whether the label is selectable.
  ///
  /// - Parameter value: A boolean indicating whether the label is selectable. The default value is `true`.
  /// - Returns: A new label node with the updated selectable state.
  public func selectable(_ value: Bool = true) -> Self {
    guard isSelectable != value else {
      return self
    }

    var copy = self
    copy.isSelectable = value
    copy.node = nil // invalidate the node so that it will be recreated with the new selectable state
    return copy
  }
}
