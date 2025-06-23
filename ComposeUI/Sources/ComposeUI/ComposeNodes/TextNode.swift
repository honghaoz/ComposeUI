//
//  TextNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/23/25.
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

public typealias Text = TextNode

/// A node that renders text.
///
/// Performance note: Using `fixedSize(width:height:)` will make the text node
/// re-calculate the intrinsic text size on layout, which is expensive. So it is
/// preferred to use flexible size and do the size calculation once on your side.
public struct TextNode: ComposeNode, FixedSizableComposeNode {

  // MARK: - Text storage

  private let attributedString: NSAttributedString

  // MARK: - Text layout

  private var numberOfLines: Int
  private var lineBreakMode: NSLineBreakMode

  private var textContainerInset: CGSize
  private var adjustIntrinsicTextSize: ((_ original: CGSize) -> CGSize)?

  private var isEditable: Bool
  private var isSelectable: Bool

  public var isFixedWidth: Bool
  public var isFixedHeight: Bool

  /// Initialize a text node with attributed text.
  ///
  /// By default, the text is multi-line with flexible size. Use `fixedSize(width:height:)` to set the width and height to be fixed or flexible.
  /// By default, the text is selectable but not editable. Use `editable(_:)` and `selectable(_:)` to change the behavior.
  ///
  /// Note for line break mode:
  /// - For single line text:
  ///   - If the text node's line break mode is `.byWordWrapping`, `.byCharWrapping`, or `.byClipping`, all line break modes in the attributed string's paragraph styles work.
  ///   - If the text node's line break mode is `.byTruncatingHead`, `.byTruncatingTail`, or `.byTruncatingMiddle`, only the line break modes: `.byClipping`, `.byTruncatingHead`, `.byTruncatingTail`, and `.byTruncatingMiddle` in the attributed string's paragraph styles work.
  ///     The line break modes: `.byWordWrapping`, `.byCharWrapping` in the attributed string's paragraph styles are ignored.
  /// - For multiline text:
  ///   - For attributed string's paragraph styles:
  ///     - Use `.byWordWrapping` or `.byCharWrapping`, it will render the text as multiple lines.
  ///     - Don't use `.byClipping`, `.byTruncatingHead`, `.byTruncatingTail`, and `.byTruncatingMiddle` as it makes the text render as a **single line**.
  ///   - Set text node's line break mode to `.byTruncatingHead`, `.byTruncatingTail`, or `.byTruncatingMiddle` so that the last line of the text is truncated with ellipsis.
  ///
  /// - Parameter attributedString: The attributed text to display.
  public init(_ attributedString: NSAttributedString) {
    self.attributedString = attributedString

    numberOfLines = 0
    lineBreakMode = .byWordWrapping

    textContainerInset = .zero
    adjustIntrinsicTextSize = nil

    isEditable = false
    isSelectable = true

    isFixedWidth = false
    isFixedHeight = false
  }

  /// Initialize a text node with simple text.
  ///
  /// Example:
  ///
  /// ```swift
  /// Text(
  ///   "Hello, world!",
  ///   font: .systemFont(ofSize: 18),
  ///   foregroundColor: ThemedColor(light: .black, dark: .white),
  ///   backgroundColor: ThemedColor(light: .red.withAlphaComponent(0.1), dark: .green.withAlphaComponent(0.1)),
  ///   shadow: Themed<NSShadow>(
  ///     light: {
  ///       let shadow = NSShadow()
  ///       shadow.shadowColor = Color.white.withAlphaComponent(0.33)
  ///       shadow.shadowBlurRadius = 0
  ///       shadow.shadowOffset = CGSize(width: 0, height: 1)
  ///       return shadow
  ///     }(),
  ///     dark: {
  ///       let shadow = NSShadow()
  ///       shadow.shadowColor = Color.black.withAlphaComponent(0.5)
  ///       shadow.shadowBlurRadius = 0
  ///       shadow.shadowOffset = CGSize(width: 0, height: -1)
  ///       return shadow
  ///     }()
  ///   ),
  ///   textAlignment: .left,
  ///   lineBreakMode: .byWordWrapping
  /// )
  /// .fixedSize(width: false, height: true)
  /// ```
  ///
  /// - Parameters:
  ///   - string: The string to display.
  ///   - font: The font to use for the text. The default value is `Font.systemFont(ofSize: 17)`.
  ///   - foregroundColor: The themed foreground color to use for the text. Default value is foreground text color.
  ///   - backgroundColor: The themed background color to use for the text. Default value is `nil`.
  ///   - shadow: The themed shadow to use for the text. Default value is `nil`.
  ///   - textAlignment: The text alignment to use for the text. The default value is `.natural`.
  ///   - lineBreakMode: The line break mode to use for the text. The default value is `.byWordWrapping`. This line break mode is used in the attributed string's paragraph style. It is unrelated to the text node's line break mode.
  ///                    For multiline text, use `.byWordWrapping` or `.byCharWrapping` to render the text as multiple lines. Use other line break modes will make the text render as a single line.
  public init(_ string: String,
              font: Font = Font.systemFont(ofSize: 17),
              foregroundColor: ThemedColor = ThemedColor(light: .black, dark: .white),
              backgroundColor: ThemedColor? = nil,
              shadow: Themed<NSShadow>? = nil,
              textAlignment: NSTextAlignment = .natural,
              lineBreakMode: NSLineBreakMode = .byWordWrapping)
  {
    var attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .themedForegroundColor: foregroundColor,
      .paragraphStyle: {
        let style = NSMutableParagraphStyle()
        style.alignment = textAlignment
        style.lineBreakMode = lineBreakMode
        return style
      }(),
    ]

    if let backgroundColor = backgroundColor {
      attributes[.themedBackgroundColor] = backgroundColor
    }
    if let shadow = shadow {
      attributes[.themedShadow] = shadow
    }

    self.init(NSAttributedString(string: string, attributes: attributes))
  }

  /// Initialize a text node with single line text.
  ///
  /// By default, the text is truncated with tail ellipsis. Use `lineBreakMode(_:)` to change the truncation behavior.
  ///
  /// By default, the text has fixed size. Use `fixedSize(width:height:)` to change the size behavior.
  ///
  /// - Parameters:
  ///   - string: The string to display.
  ///   - font: The font to use for the text. The default value is `Font.systemFont(ofSize: 17)`.
  ///   - foregroundColor: The themed foreground color to use for the text. Default value is foreground text color.
  ///   - backgroundColor: The themed background color to use for the text. Default value is `nil`.
  ///   - shadow: The themed shadow to use for the text. Default value is `nil`.
  ///   - textAlignment: The text alignment to use for the text. The default value is `.natural`.
  static func singleLineText(_ string: String,
                             font: Font = Font.systemFont(ofSize: 17),
                             foregroundColor: ThemedColor = ThemedColor(light: .black, dark: .white),
                             backgroundColor: ThemedColor? = nil,
                             shadow: Themed<NSShadow>? = nil,
                             textAlignment: NSTextAlignment = .natural) -> Self
  {
    var node = TextNode(string, font: font, foregroundColor: foregroundColor, backgroundColor: backgroundColor, shadow: shadow, textAlignment: textAlignment, lineBreakMode: .byWordWrapping)

    node.numberOfLines = 1
    node.lineBreakMode = .byTruncatingTail

    node.isFixedWidth = true
    node.isFixedHeight = true

    return node
  }

  /// Initialize a text node with multi-line text.
  ///
  /// By default, the text last line is truncated with tail ellipsis. Use `lineBreakMode(_:)` to change the truncation behavior.
  ///
  /// By default, the text has flexible size. Use `fixedSize(width:height:)` to change the size behavior.
  ///
  /// - Parameters:
  ///   - string: The string to display.
  ///   - font: The font to use for the text. The default value is `Font.systemFont(ofSize: 17)`.
  ///   - foregroundColor: The themed foreground color to use for the text. Default value is foreground text color.
  ///   - backgroundColor: The themed background color to use for the text. Default value is `nil`.
  ///   - shadow: The themed shadow to use for the text. Default value is `nil`.
  ///   - textAlignment: The text alignment to use for the text. The default value is `.natural`.
  ///   - numberOfLines: The number of lines to display. The default value is `0`.
  static func multiLineText(_ string: String,
                            font: Font = Font.systemFont(ofSize: 17),
                            foregroundColor: ThemedColor = ThemedColor(light: .black, dark: .white),
                            backgroundColor: ThemedColor? = nil,
                            shadow: Themed<NSShadow>? = nil,
                            textAlignment: NSTextAlignment = .natural,
                            numberOfLines: Int = 0) -> Self
  {
    var node = TextNode(string, font: font, foregroundColor: foregroundColor, backgroundColor: backgroundColor, shadow: shadow, textAlignment: textAlignment, lineBreakMode: .byWordWrapping)

    node.numberOfLines = numberOfLines
    node.lineBreakMode = .byTruncatingTail

    return node
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.textView)

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    switch (isFixedWidth, isFixedHeight) {
    case (true, true):
      size = intrinsicTextSize(for: containerSize)
      return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height))
    case (true, false):
      let intrinsicSize = intrinsicTextSize(for: containerSize)
      size = CGSize(width: intrinsicSize.width, height: containerSize.height)
      return ComposeNodeSizing(width: .fixed(size.width), height: .flexible)
    case (false, true):
      let intrinsicSize = intrinsicTextSize(for: containerSize)
      size = CGSize(width: containerSize.width, height: intrinsicSize.height)
      return ComposeNodeSizing(width: .flexible, height: .fixed(size.height))
    case (false, false):
      size = containerSize
      return ComposeNodeSizing(width: .flexible, height: .flexible)
    }
  }

  private func intrinsicTextSize(for containerSize: CGSize) -> CGSize {
    let rawIntrinsicSize = attributedString.boundingRectSize(numberOfLines: numberOfLines, layoutWidth: containerSize.width - textContainerInset.width * 2)
    let sizeAdjustment = adjustIntrinsicTextSize?(rawIntrinsicSize) ?? .zero
    let intrinsicSize = CGSize(
      width: rawIntrinsicSize.width + sizeAdjustment.width,
      height: rawIntrinsicSize.height + textContainerInset.height * 2 + sizeAdjustment.height
    )
    return intrinsicSize.roundedUp(scaleFactor: 1)
  }

  public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    let frame = CGRect(origin: .zero, size: size)
    guard visibleBounds.intersects(frame) else {
      return []
    }

    let viewItem = ViewItem<BaseTextView>(
      id: id,
      frame: frame,
      make: { BaseTextView(frame: $0.initialFrame ?? .zero) },
      update: { view, context in
        guard context.updateType.requiresFullUpdate else {
          return
        }
        updateTextView(view, theme: context.contentView.theme)
      }
    )

    return [viewItem.eraseToRenderableItem()]
  }

  // MARK: - Private

  private func updateTextView(_ textView: BaseTextView, theme: Theme) {
    let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
    textView.attributedString = mutableAttributedString.apply(theme: theme)

    textView.numberOfLines = numberOfLines
    textView.lineBreakMode = lineBreakMode

    #if canImport(AppKit)
    textView.textContainerInset = textContainerInset
    #endif

    #if canImport(UIKit)
    textView.textContainerInset = UIEdgeInsets(
      top: textContainerInset.height,
      left: textContainerInset.width,
      bottom: textContainerInset.height,
      right: textContainerInset.width
    )
    #endif

    #if !os(tvOS)
    textView.isEditable = isEditable
    #endif
    textView.isSelectable = isSelectable
  }

  // MARK: - Public

  /// Set the number of lines of the text.
  ///
  /// - Parameter value: The number of lines to set.
  /// - Returns: A new text node with the updated number of lines.
  public func numberOfLines(_ value: Int) -> Self {
    let value = max(value, 0)
    guard numberOfLines != value else {
      return self
    }

    var copy = self
    copy.numberOfLines = value
    return copy
  }

  /// Set the line break mode of the text.
  ///
  /// - Parameter value: The line break mode to set.
  /// - Returns: A new text node with the updated line break mode.
  public func lineBreakMode(_ value: NSLineBreakMode) -> Self {
    guard lineBreakMode != value else {
      return self
    }

    var copy = self
    copy.lineBreakMode = value
    return copy
  }

  /// Set whether the text is editable.
  ///
  /// - Parameter value: A boolean indicating whether the text is editable.
  /// - Returns: A new text node with the updated editable state.
  public func editable(_ value: Bool = true) -> Self {
    guard isEditable != value else {
      return self
    }

    var copy = self
    copy.isEditable = value
    return copy
  }

  /// Set whether the text is selectable.
  ///
  /// - Parameter value: A boolean indicating whether the text is selectable.
  /// - Returns: A new text node with the updated selectable state.
  public func selectable(_ value: Bool = true) -> Self {
    guard isSelectable != value else {
      return self
    }

    var copy = self
    copy.isSelectable = value
    return copy
  }

  /// Set the text container inset of the underlying text view.
  ///
  /// The default text container inset is `(0, 0)`.
  ///
  /// - Parameter horizontal: The horizontal inset to set.
  /// - Parameter vertical: The vertical inset to set.
  /// - Returns: A new text node with the updated text container inset.
  public func textContainerInset(horizontal: CGFloat, vertical: CGFloat) -> Self {
    guard textContainerInset != CGSize(width: horizontal, height: vertical) else {
      return self
    }

    var copy = self
    copy.textContainerInset = CGSize(width: horizontal, height: vertical)
    return copy
  }

  /// Apply an additional size adjustment to the intrinsic text size.
  ///
  /// The text node with fixed size uses the intrinsic text size to determine
  /// the size of the text. You can use this method to apply an additional
  /// size adjustment to the intrinsic text size.
  ///
  /// - Parameter adjustment: The adjustment to apply to the intrinsic text size. The block will be called with the original intrinsic text size.
  /// - Returns: A new text node with the updated intrinsic text size adjustment.
  public func intrinsicTextSizeAdjustment(_ adjustment: ((_ original: CGSize) -> CGSize)?) -> Self {
    var copy = self
    copy.adjustIntrinsicTextSize = adjustment
    return copy
  }
}
