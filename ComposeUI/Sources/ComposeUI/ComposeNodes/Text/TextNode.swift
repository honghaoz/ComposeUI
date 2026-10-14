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
public struct TextNode: ComposeNode, IntrinsicSizableComposeNode {

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

  /// The node's slot in the item cache of its content, so scroll render passes reuse its item instead of rebuilding it.
  ///
  /// Each fluent config setter clears it on its returned copy, so that the copy takes its own slot when it's laid out,
  /// and a configuration change is never served a stale cached item.
  private var itemSlot = RenderableItemCache.Slot.unassigned

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
  /// Example:
  /// ```swift
  /// TextNode(
  ///   NSAttributedString(
  ///     string: "ComposéUI is a Swift framework for building UI using AppKit and UIKit with declarative syntax.",
  ///     attributes: [
  ///       .font: Font.systemFont(ofSize: 12, weight: .regular),
  ///       .themedForegroundColor: ThemedColor(
  ///         light: Color.black.withAlphaComponent(0.8),
  ///         dark: Color.white.withAlphaComponent(0.8)
  ///       ),
  ///       .themedShadow: Themed<NSShadow>(
  ///         light: {
  ///           let shadow = NSShadow()
  ///           shadow.shadowColor = Color.white.withAlphaComponent(0.5)
  ///           shadow.shadowOffset = CGSize(width: 0, height: 1)
  ///           return shadow
  ///         }(),
  ///         dark: {
  ///           let shadow = NSShadow()
  ///           shadow.shadowColor = Color.black.withAlphaComponent(0.5)
  ///           shadow.shadowOffset = CGSize(width: 0, height: -1)
  ///           return shadow
  ///         }()
  ///       ),
  ///       .paragraphStyle: {
  ///         let style = NSMutableParagraphStyle()
  ///         style.alignment = .left
  ///         style.lineBreakMode = .byWordWrapping
  ///         style.lineSpacing = 2
  ///         return style
  ///       }()
  ///     ]
  ///   )
  /// )
  /// .fixedSize(width: false, height: true)
  /// ```
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
    self.init(
      TextNode.attributedString(
        string,
        font: font,
        foregroundColor: foregroundColor,
        backgroundColor: backgroundColor,
        shadow: shadow,
        textAlignment: textAlignment,
        lineBreakMode: lineBreakMode
      )
    )
  }

  /// Returns the attributed string for simple text, which `init(_:font:foregroundColor:backgroundColor:shadow:textAlignment:lineBreakMode:)` displays.
  static func attributedString(_ string: String,
                               font: Font,
                               foregroundColor: ThemedColor,
                               backgroundColor: ThemedColor?,
                               shadow: Themed<NSShadow>?,
                               textAlignment: NSTextAlignment,
                               lineBreakMode: NSLineBreakMode) -> NSAttributedString
  {
    var attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .paragraphStyle: {
        let style = NSMutableParagraphStyle()
        style.alignment = textAlignment
        style.lineBreakMode = lineBreakMode
        return style
      }(),
    ]

    // a color that's the same in both themes is set as it is, such as a label's default color, which leaves the text
    // nothing to apply a theme to, so that a text view shows the text itself instead of a themed copy
    if foregroundColor.light == foregroundColor.dark {
      attributes[.foregroundColor] = foregroundColor.light
    } else {
      attributes[.themedForegroundColor] = foregroundColor
    }
    if let backgroundColor = backgroundColor {
      if backgroundColor.light == backgroundColor.dark {
        attributes[.backgroundColor] = backgroundColor.light
      } else {
        attributes[.themedBackgroundColor] = backgroundColor
      }
    }
    if let shadow = shadow {
      attributes[.themedShadow] = shadow
    }

    return NSAttributedString(string: string, attributes: attributes)
  }

  /// Initialize a text node with single line text.
  ///
  /// By default, the node uses the text's intrinsic size. Use `fixedSize(width:height:)` to change the sizing behavior.
  ///
  /// - Parameters:
  ///   - string: The string to display.
  ///   - font: The font to use for the text. The default value is `Font.systemFont(ofSize: 17)`.
  ///   - foregroundColor: The themed foreground color to use for the text. Default value is foreground text color.
  ///   - backgroundColor: The themed background color to use for the text. Default value is `nil`.
  ///   - shadow: The themed shadow to use for the text. Default value is `nil`.
  ///   - textAlignment: The text alignment to use for the text. The default value is `.natural`.
  ///   - lineBreakMode: The node's line break mode, which truncates the text. The default value is `.byTruncatingTail`, which truncates the text with tail ellipsis.
  ///   - isSelectable: Whether the text is selectable. The default value is `true`.
  static func singleLineText(_ string: String,
                             font: Font = Font.systemFont(ofSize: 17),
                             foregroundColor: ThemedColor = ThemedColor(light: .black, dark: .white),
                             backgroundColor: ThemedColor? = nil,
                             shadow: Themed<NSShadow>? = nil,
                             textAlignment: NSTextAlignment = .natural,
                             lineBreakMode: NSLineBreakMode = .byTruncatingTail,
                             isSelectable: Bool = true) -> Self
  {
    let key = SimpleTextCache.Key(
      text: string,
      font: font,
      textColor: foregroundColor,
      textBackgroundColor: backgroundColor,
      textShadow: shadow,
      textAlignment: textAlignment
    )
    var node = TextNode(SimpleTextCache.attributedString(for: key))

    node.numberOfLines = 1
    node.lineBreakMode = lineBreakMode

    node.isSelectable = isSelectable

    node.isFixedWidth = true
    node.isFixedHeight = true

    return node
  }

  /// Initialize a text node with multi-line text.
  ///
  /// By default, the node has flexible size. Use `fixedSize(width:height:)` to change the sizing behavior.
  ///
  /// - Parameters:
  ///   - string: The string to display.
  ///   - font: The font to use for the text. The default value is `Font.systemFont(ofSize: 17)`.
  ///   - foregroundColor: The themed foreground color to use for the text. Default value is foreground text color.
  ///   - backgroundColor: The themed background color to use for the text. Default value is `nil`.
  ///   - shadow: The themed shadow to use for the text. Default value is `nil`.
  ///   - textAlignment: The text alignment to use for the text. The default value is `.natural`.
  ///   - numberOfLines: The number of lines to display. The default value is `0`.
  ///   - lineBreakMode: The node's line break mode, which truncates the last line. The default value is `.byTruncatingTail`, which truncates the last line with tail ellipsis.
  ///   - isSelectable: Whether the text is selectable. The default value is `true`.
  static func multiLineText(_ string: String,
                            font: Font = Font.systemFont(ofSize: 17),
                            foregroundColor: ThemedColor = ThemedColor(light: .black, dark: .white),
                            backgroundColor: ThemedColor? = nil,
                            shadow: Themed<NSShadow>? = nil,
                            textAlignment: NSTextAlignment = .natural,
                            numberOfLines: Int = 0,
                            lineBreakMode: NSLineBreakMode = .byTruncatingTail,
                            isSelectable: Bool = true) -> Self
  {
    let key = SimpleTextCache.Key(
      text: string,
      font: font,
      textColor: foregroundColor,
      textBackgroundColor: backgroundColor,
      textShadow: shadow,
      textAlignment: textAlignment
    )
    var node = TextNode(SimpleTextCache.attributedString(for: key))

    node.numberOfLines = numberOfLines
    node.lineBreakMode = lineBreakMode

    node.isSelectable = isSelectable

    return node
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.textView)

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    RenderableItemCache.updateSlot(&itemSlot)

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

    // bind config locally so the cached `update` closure keeps these values, instead of a copy of `self` and everything
    // that it keeps.
    let attributedString = attributedString
    let numberOfLines = numberOfLines
    let lineBreakMode = lineBreakMode
    let textContainerInset = textContainerInset
    let isEditable = isEditable
    let isSelectable = isSelectable

    let item = RenderableItemCache.item(in: itemSlot, id: id, frame: frame) {
      ViewItem<BaseTextView>(
        id: id,
        frame: frame,
        make: { context in
          let textView = BaseTextView(frame: context.initialFrame ?? .zero)
          #if canImport(UIKit)
          // UIKit lays out a text view's own subviews itself, so autoresizing them on each resize only costs work, such
          // as a block copy for each subview on iOS
          textView.autoresizesSubviews = false
          #endif
          return textView
        },
        update: { view, context in
          switch context.updateType {
          case .insert,
               .refresh:
            break
          case .boundsChange:
            return
          }
          TextNode.updateTextView(
            view,
            theme: context.contentView.theme,
            attributedString: attributedString,
            numberOfLines: numberOfLines,
            lineBreakMode: lineBreakMode,
            textContainerInset: textContainerInset,
            isEditable: isEditable,
            isSelectable: isSelectable
          )
        },
        reuseId: Self.reuseId(isEditable: isEditable, isSelectable: isSelectable),
        resetForReuse: { $0.resetForReuse(keepsTextNodeSettings: true) }
      )
      .eraseToRenderableItem()
    }

    return [item]
  }

  // MARK: - Private

  /// Returns the reuse identifier of a text view with the interaction settings.
  ///
  /// A text view is reused only by a node with the same interaction settings, and its reset keeps them, since changing
  /// them costs work, such as hundreds of allocations each time a UIKit text view becomes selectable or not.
  private static func reuseId(isEditable: Bool, isSelectable: Bool) -> ReuseId {
    switch (isEditable, isSelectable) {
    case (false, true):
      return ReuseId(namespace: .framework, id: "BaseTextView")
    case (false, false):
      return ReuseId(namespace: .framework, id: "BaseTextView.unselectable")
    case (true, true):
      return ReuseId(namespace: .framework, id: "BaseTextView.editable")
    case (true, false):
      return ReuseId(namespace: .framework, id: "BaseTextView.editable.unselectable")
    }
  }

  private static func updateTextView(_ textView: BaseTextView,
                                     theme: Theme,
                                     attributedString: NSAttributedString,
                                     numberOfLines: Int,
                                     lineBreakMode: NSLineBreakMode,
                                     textContainerInset: CGSize,
                                     isEditable: Bool,
                                     isSelectable: Bool)
  {
    // a refresh updates each text view with settings that rarely change, and setting some of them costs work even when
    // the value is unchanged, such as about 300 ns each for the inset and `isSelectable` on macOS, so a setting is set
    // only when it differs from the text view's.
    //
    // the interaction settings are set before the text, since whether the text view is editable when its text is set
    // decides whether it shows the text in the directions of its paragraphs.
    //
    // the other settings are set before the text on UIKit, where changing them with a text in place costs about 10 times
    // the allocations of the change on an empty text view, as a new text view is, and a reused one, whose text the reset
    // for reuse removes, and after the text on AppKit, where that order takes about 5% fewer instructions to scroll labels
    #if !os(tvOS)
    if textView.isEditable != isEditable {
      textView.isEditable = isEditable
    }
    #endif

    if textView.isSelectable != isSelectable {
      textView.isSelectable = isSelectable
    }

    let isInteractive = isSelectable || isEditable

    #if canImport(AppKit)
    textView.ignoreHitTest = !isInteractive
    #endif

    #if canImport(UIKit)
    textView.isUserInteractionEnabled = isInteractive

    // a UIKit text view that scrolls lays out its whole text, also past its bounds, and runs a scroll view's bookkeeping
    // on each frame and text change, so a text view that isn't editable doesn't scroll, and stops its text at its bounds,
    // as on AppKit, while an editable one scrolls, so that the user reaches the text typed past its bounds
    if textView.isScrollEnabled != isEditable {
      textView.isScrollEnabled = isEditable
    }
    #endif

    #if canImport(AppKit)
    textView.attributedString = themedText(of: attributedString, theme: theme, in: textView)
    #endif

    if textView.numberOfLines != numberOfLines {
      textView.numberOfLines = numberOfLines
    }
    if textView.lineBreakMode != lineBreakMode {
      textView.lineBreakMode = lineBreakMode
    }

    #if canImport(AppKit)
    if textView.textContainerInset != textContainerInset {
      textView.textContainerInset = textContainerInset
    }
    #endif

    #if canImport(UIKit)
    let insets = UIEdgeInsets(
      top: textContainerInset.height,
      left: textContainerInset.width,
      bottom: textContainerInset.height,
      right: textContainerInset.width
    )
    if textView.textContainerInset != insets {
      textView.textContainerInset = insets
    }

    textView.attributedString = themedText(of: attributedString, theme: theme, in: textView)
    #endif
  }

  /// Returns the text with the theme applied, the text view's last themed text when it's of the same text and theme.
  private static func themedText(of attributedString: NSAttributedString, theme: Theme, in textView: BaseTextView) -> NSAttributedString {
    // a refresh makes the nodes again, but a label's text is the same object while its settings are the same, so the
    // themed text that the text view shows is reused instead of applying the theme to a new copy of the text
    if let last = textView.lastThemedText, last.text === attributedString, last.theme == theme {
      return last.themedText
    }

    // a text with nothing to apply a theme to is shown as it is, instead of as a copy, which the text view would copy again
    // to compare a later text with, since the copy is mutable
    let themedText = attributedString.hasThemedAttributes ? NSMutableAttributedString(attributedString: attributedString).apply(theme: theme) : attributedString
    // a mutable text can change and stay the same object, so it isn't kept, and its theme is applied on each update
    textView.lastThemedText = attributedString is NSMutableAttributedString ? nil : (attributedString, theme, themedText)
    return themedText
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
    copy.itemSlot = .unassigned // config changed: the copy takes its own slot, so it rebuilds
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
    copy.itemSlot = .unassigned // config changed: the copy takes its own slot, so it rebuilds
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
    copy.itemSlot = .unassigned // config changed: the copy takes its own slot, so it rebuilds
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
    copy.itemSlot = .unassigned // config changed: the copy takes its own slot, so it rebuilds
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
    copy.itemSlot = .unassigned // config changed: the copy takes its own slot, so it rebuilds
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
    copy.itemSlot = .unassigned // config changed: the copy takes its own slot, so it rebuilds
    return copy
  }
}
