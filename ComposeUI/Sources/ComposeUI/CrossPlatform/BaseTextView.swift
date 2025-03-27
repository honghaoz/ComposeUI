//
//  BaseTextView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/26/25.
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

/// A base text view.
open class BaseTextView: TextView {

  // TODO: can't select with TextKit 2

  override open var isFlipped: Bool { true }

  /// The attributed string content of the text view.
  public var attributedString: NSAttributedString = NSAttributedString() {
    didSet {
      if #available(macOS 12.0, *) {
        // TextKit 2
        textContentStorage?.attributedString = attributedString
      } else {
        // TextKit 1
        textStorage?.setAttributedString(attributedString)
      }

      invalidateIntrinsicContentSize()
      needsLayout = true
    }
  }

  /// The number of lines to display. Set to 0 for unlimited lines (default).
  ///
  /// The line break mode is set to `byTruncatingTail` for 1 line, and `byWordWrapping` for multiple lines.
  open var numberOfLines: Int = 0 {
    didSet {
      if numberOfLines == 1 {
        textContainer?.maximumNumberOfLines = 1
        textContainer?.lineBreakMode = .byTruncatingTail
      } else {
        textContainer?.maximumNumberOfLines = numberOfLines > 0 ? numberOfLines : 0
        textContainer?.lineBreakMode = .byWordWrapping
      }

      invalidateIntrinsicContentSize()
    }
  }

  override public init(frame: CGRect) {
    if #available(macOS 12.0, *) {
      let textContainer = NSTextContainer(size: frame.size)

      let textLayoutManager = NSTextLayoutManager()
      textLayoutManager.textContainer = textContainer

      let textContentStorage = NSTextContentStorage()
      textContentStorage.addTextLayoutManager(textLayoutManager)

      super.init(frame: frame, textContainer: textContainer)
    } else {
      let textContainer = NSTextContainer(size: frame.size)

      let layoutManager = NSLayoutManager()
      layoutManager.addTextContainer(textContainer)

      let textStorage = NSTextStorage()
      textStorage.addLayoutManager(layoutManager)

      super.init(frame: frame, textContainer: textContainer)
    }

    isEditable = false
    isSelectable = true

    drawsBackground = false

    textContainerInset = .zero
    self.textContainer?.lineFragmentPadding = 0

    updateCommonSettings()
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  override open var intrinsicContentSize: NSSize {
    attributedString.boundingRectSize(numberOfLines: numberOfLines, layoutWidth: frame.width).roundedUp(scaleFactor: 1)
  }

  override open func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)

    textContainer?.size = NSSize(width: newSize.width, height: newSize.height > 0 ? newSize.height : .greatestFiniteMagnitude)
    invalidateIntrinsicContentSize()
  }

  override open func layout() {
    super.layout()

    layoutSubviews()
  }

  open func layoutSubviews() {
    invalidateIntrinsicContentSize()
  }
}

// "What's new in TextKit and text views" (https://developer.apple.com/videos/play/wwdc2022/10090/)
// "Meet TextKit 2" (https://developer.apple.com/videos/play/wwdc2021/10061)
#endif

#if canImport(UIKit)
import UIKit

open class BaseTextView: View {

  // TODO: implement iOS
}
#endif
