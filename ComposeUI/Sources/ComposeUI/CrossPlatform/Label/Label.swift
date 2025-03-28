//
//  Label.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 5/22/22.
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

// From: https://github.com/honghaoz/ChouTiUI/blob/c2cc7b8452d269d6ee55993a977ed4b5fabf15d4/ChouTiUI/Sources/ChouTiUI/AppKit/Text/NSLabel.swift

#if canImport(AppKit)

import AppKit

/// A view that displays one or more lines of informational text.
///
/// - The label renders the text vertically centered to match UILabel's default behavior.
/// - By default, the label is single-line.
/// - In single-line mode, `lineBreakMode` can be set to `.byTruncatingTail`, `.byTruncatingMiddle`, `.byTruncatingHead`, or `.byClipping`.
/// - To support multiline text, set `numberOfLines` to 0 (unlimited) or 2+ and `lineBreakMode` to `.byWordWrapping` or `.byCharWrapping`.
/// - In multiline mode, the label only supports `.byTruncatingTail` truncation mode, with `multilineTruncatesLastVisibleLine` set to `true`.
open class Label: NSTextField {

  override public class var cellClass: AnyClass? {
    get { BaseNSTextFieldCell.self }
    set {}
  }

  private var theCell: BaseNSTextFieldCell? { cell as? BaseNSTextFieldCell }

  /// The vertical alignment of the text. Default to `.center`.
  public var verticalAlignment: TextVerticalAlignment {
    get {
      theCell?.verticalAlignment ?? .center
    }
    set {
      theCell?.verticalAlignment = newValue
    }
  }

  /// The text of the label. Default to `""`.
  ///
  /// Setting `text` to `nil` will set the `text` to `""`.
  public var text: String? {
    get {
      stringValue
    }
    set {
      stringValue = newValue ?? ""
    }
  }

  /// The alignment mode of the text.
  var textAlignment: NSTextAlignment {
    get {
      alignment
    }
    set {
      alignment = newValue
    }
  }

  /// The maximum number of lines for rendering text.
  var numberOfLines: Int {
    get {
      maximumNumberOfLines
    }
    set {
      maximumNumberOfLines = newValue
    }
  }

  /// The attributed text.
  var attributedText: NSAttributedString {
    get {
      attributedStringValue
    }
    set {
      attributedStringValue = newValue
    }
  }

  /// If the label is in multiline mode, this property controls whether the label truncates the text at the end of the last visible line.
  ///
  /// Default to `true`.
  public var multilineTruncatesLastVisibleLine: Bool {
    get {
      theCell?.truncatesLastVisibleLine ?? false
    }
    set {
      theCell?.truncatesLastVisibleLine = newValue
    }
  }

  override public init(frame: NSRect) {
    super.init(frame: frame)
    commonInit()
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    // swiftlint:disable:next fatal_error
    fatalError("init(coder:) is unavailable")
  }

  private func commonInit() {
    layerContentsRedrawPolicy = .onSetNeedsDisplay

    // Add 2 points of horizontal padding on both sides to match UILabel's layout.
    // Note: This compensates for macOS's default inset, possibly caused by the default border.
    theCell?.horizontalPadding = 2

    // Default to single line mode
    maximumNumberOfLines = 1
    cell?.truncatesLastVisibleLine = true

    /// Don't set `usesSingleLineMode` as it can affect the text baseline.
    // usesSingleLineMode = true
    // cell?.usesSingleLineMode = true

    updateCommonSettings()

    refusesFirstResponder = true

    isEditable = false
    setIsSelectable(false)
    isContinuous = false

    drawsBackground = false
    isBezeled = false
    isBordered = false

    backgroundColor = .clear

    ignoreHitTest = true
  }

  /// Set label to single line mode.
  /// - Parameter truncationMode: The text truncation mode. Default to `.tail`.
  public func setToSingleLineMode(truncationMode: TextTruncationMode = .tail) {
    maximumNumberOfLines = 1

    switch truncationMode {
    case .none:
      lineBreakMode = .byClipping
    case .head:
      lineBreakMode = .byTruncatingHead
    case .tail:
      lineBreakMode = .byTruncatingTail
    case .middle:
      lineBreakMode = .byTruncatingMiddle
    }

    multilineTruncatesLastVisibleLine = false
  }

  /// Set label to multiline mode.
  /// - Parameters:
  ///   - numberOfLines: Number of lines, 0 for unlimited. Default to 0.
  ///   - lineWrapMode: The line wrap mode. Default to `.byWord`.
  ///   - truncatesLastVisibleLine: If `true`, the label truncates the text at the end of the last visible line. Default to `true`.
  public func setToMultilineMode(numberOfLines: Int = 0, lineWrapMode: LineWrapMode = .byWord, truncatesLastVisibleLine: Bool = true) {
    maximumNumberOfLines = numberOfLines

    switch lineWrapMode {
    case .byWord:
      lineBreakMode = .byWordWrapping
    case .byChar:
      lineBreakMode = .byCharWrapping
    }

    multilineTruncatesLastVisibleLine = truncatesLastVisibleLine
  }

  // MARK: - Public

  /// Set label's selectable state.
  ///
  /// - Note: Set to `true` for tappable links.
  ///
  /// - Parameter isSelectable: If `true`, the label is selectable.
  open func setIsSelectable(_ isSelectable: Bool) {
    if isSelectable {
      // avoid selecting text changes font
      // https://stackoverflow.com/a/38966031/3164091
      self.isSelectable = true
      allowsEditingTextAttributes = true
    } else {
      self.isSelectable = false
      allowsEditingTextAttributes = false
    }
  }
}

private class BaseNSTextFieldCell: NSTextFieldCell {

  /// The additional horizontal padding to add to the text frame.
  var horizontalPadding: CGFloat = 0

  /// The vertical alignment of the text.
  var verticalAlignment: TextVerticalAlignment = .center

  override func drawingRect(forBounds rect: NSRect) -> NSRect {
    super.drawingRect(forBounds: adjustRect(rect))
  }

  override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
    super.draw(withFrame: adjustRect(cellFrame), in: controlView)
  }

  override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
    super.drawInterior(withFrame: adjustRect(cellFrame), in: controlView)
  }

  override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
    super.edit(withFrame: adjustRect(rect), in: controlView, editor: textObj, delegate: delegate, event: event)
  }

  override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
    super.select(withFrame: adjustRect(rect), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
  }

  private func adjustRect(_ rect: CGRect) -> CGRect {
    let adjustRect = rect.insetBy(dx: -horizontalPadding, dy: 0)
    switch verticalAlignment {
    case .top:
      // by default, NSTextField uses top alignment
      return adjustRect
    case .center:
      return adjustedFrame(toVerticallyCenterText: adjustRect)
    case .bottom:
      assertionFailure("unsupported bottom alignment")
      return adjustRect
    }
  }

  private func adjustedFrame(toVerticallyCenterText rect: NSRect) -> NSRect {
    let titleRect = titleRect(forBounds: rect)
    let cellHeight = cellSize(forBounds: rect).height
    return CGRect(x: titleRect.origin.x, y: (titleRect.height - cellHeight) / 2, width: titleRect.width, height: cellHeight)
  }
}

#endif

#if canImport(UIKit)
import UIKit

public typealias Label = UILabel
#endif
