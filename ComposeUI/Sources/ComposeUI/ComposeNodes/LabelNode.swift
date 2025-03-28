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

public typealias Text = LabelNode

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
  private var textAlignment: NSTextAlignment
  private var numberOfLines: Int
  private var lineBreakMode: NSLineBreakMode

  public var isFixedWidth: Bool
  public var isFixedHeight: Bool

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

    textAlignment = .center
    numberOfLines = 1
    lineBreakMode = .byTruncatingTail

    isFixedWidth = true
    isFixedHeight = true
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.label)

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    switch (isFixedWidth, isFixedHeight) {
    case (true, true):
      updateLabel(sizingLabel, theme: .light)
      let intrinsicSize = sizingLabel.sizeThatFits(containerSize)
      size = intrinsicSize
      return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height))
    case (true, false):
      updateLabel(sizingLabel, theme: .light)
      let intrinsicSize = sizingLabel.sizeThatFits(containerSize)
      size = CGSize(width: intrinsicSize.width, height: containerSize.height)
      return ComposeNodeSizing(width: .fixed(size.width), height: .flexible)
    case (false, true):
      updateLabel(sizingLabel, theme: .light)
      let intrinsicSize = sizingLabel.sizeThatFits(containerSize)
      size = CGSize(width: containerSize.width, height: intrinsicSize.height)
      return ComposeNodeSizing(width: .flexible, height: .fixed(size.height))
    case (false, false):
      size = containerSize
      return ComposeNodeSizing(width: .flexible, height: .flexible)
    }
  }

  public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    let frame = CGRect(origin: .zero, size: size)
    guard visibleBounds.intersects(frame) else {
      return []
    }

    let viewItem = ViewItem<BaseLabel>(
      id: id,
      frame: frame,
      make: { context in
        if let initialFrame = context.initialFrame {
          return BaseLabel(frame: initialFrame)
        } else {
          return BaseLabel()
        }
      },
      update: { view, context in
        guard context.updateType.requiresFullUpdate else {
          return
        }
        updateLabel(view, theme: context.contentView.theme)
      }
    )

    return [viewItem.eraseToRenderableItem()]
  }

  // MARK: - Private

  private func updateLabel(_ label: BaseLabel, theme: Theme) {
    label.isUserInteractionEnabled = false

    label.text = text
    label.font = font
    label.textColor = textColor.resolve(for: theme)
    label.textAlignment = textAlignment
    label.numberOfLines = numberOfLines
    label.lineBreakMode = lineBreakMode

    #if canImport(AppKit)
    // special handling for NSLabel (NSTextField)
    if numberOfLines == 1 {
      let textTruncationMode: TextTruncationMode
      switch lineBreakMode {
      case .byWordWrapping,
           .byCharWrapping:
        textTruncationMode = .tail
      case .byClipping:
        textTruncationMode = .none
      case .byTruncatingHead:
        textTruncationMode = .head
      case .byTruncatingMiddle:
        textTruncationMode = .middle
      case .byTruncatingTail:
        textTruncationMode = .tail
      @unknown default:
        assertionFailure("Unsupported line break mode: \(lineBreakMode)")
        textTruncationMode = .tail
      }
      label.setToSingleLineMode(truncationMode: textTruncationMode)
    } else {
      let lineWrapMode: LineWrapMode
      switch lineBreakMode {
      case .byWordWrapping:
        lineWrapMode = .byWord
      case .byCharWrapping:
        lineWrapMode = .byChar
      case .byClipping,
           .byTruncatingHead,
           .byTruncatingMiddle,
           .byTruncatingTail:
        // if NSLabel (NSTextField) uses multiline, only .byWordWrapping or .byCharWrapping is supported
        // setting the line break mode to other values will make the label become single line
        lineWrapMode = .byWord
      @unknown default:
        assertionFailure("Unsupported line break mode: \(lineBreakMode)")
        lineWrapMode = .byWord
      }
      label.setToMultilineMode(numberOfLines: numberOfLines, lineWrapMode: lineWrapMode, truncatesLastVisibleLine: true)
    }
    #endif
  }

  // MARK: - Public

  /// Set the font of the label node.
  ///
  /// - Parameter value: The font to set.
  /// - Returns: A new label node with the updated font.
  public func font(_ value: Font) -> Self {
    guard font != value else {
      return self
    }

    var copy = self
    copy.font = value
    return copy
  }

  /// Set the text color of the label node.
  ///
  /// - Parameter value: The text color to set.
  /// - Returns: A new label node with the updated text color.
  public func textColor(_ value: ThemedColor) -> Self {
    guard textColor != value else {
      return self
    }

    var copy = self
    copy.textColor = value
    return copy
  }

  /// Set the text color of the label node.
  ///
  /// - Parameter value: The text color to set.
  /// - Returns: A new label node with the updated text color.
  public func textColor(_ value: Color) -> Self {
    textColor(ThemedColor(light: value, dark: value))
  }

  /// Set the text alignment of the label node.
  ///
  /// - Parameter value: The text alignment to set.
  /// - Returns: A new label node with the updated text alignment.
  public func textAlignment(_ value: NSTextAlignment) -> Self {
    guard textAlignment != value else {
      return self
    }

    var copy = self
    copy.textAlignment = value
    return copy
  }

  /// Set the number of lines of the label node.
  ///
  /// Set `numberOfLines` to 0 or 2+ will make the label node have a flexible width and a fixed height.
  ///
  /// - Parameter value: The number of lines to set.
  /// - Returns: A new label node with the updated number of lines.
  public func numberOfLines(_ value: Int) -> Self {
    let value = max(value, 0)
    guard numberOfLines != value else {
      return self
    }

    var copy = self
    copy.numberOfLines = value

    if numberOfLines != 1 {
      copy.isFixedWidth = false
      copy.isFixedHeight = true
    }

    return copy
  }

  /// Set the line break mode of the label node.
  ///
  /// - Parameter value: The line break mode to set.
  /// - Returns: A new label node with the updated line break mode.
  public func lineBreakMode(_ value: NSLineBreakMode) -> Self {
    guard lineBreakMode != value else {
      return self
    }

    var copy = self
    copy.lineBreakMode = value
    return copy
  }
}

/// A label used to calculate label's intrinsic size.
private let sizingLabel = BaseLabel()
