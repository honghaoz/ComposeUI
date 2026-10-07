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

  /// A flag to indicate whether to use TextKit 2.
  ///
  /// Even though TextKit 2 is available on macOS 12, however, using TextKit 2 on macOS 12 could result in various
  /// issues, such as text not updated on `attributedString` set.
  ///
  /// Bumping up the minimum macOS version to 13 to use TextKit 2.
  ///
  /// References:
  /// - "Meet TextKit 2" (https://developer.apple.com/videos/play/wwdc2021/10061)
  /// - "What's new in TextKit and text views" (https://developer.apple.com/videos/play/wwdc2022/10090/)
  private static let shouldUseTextKit2 = {
    if #available(macOS 13.0, *) {
      return true
    } else {
      return false
    }
  }()

  #if DEBUG
  /// Whether the text views made from now on use TextKit 1, so that tests cover the TextKit 1 paths, which macOS 13 and
  /// later don't take.
  static var usesTextKit1ForTesting = false
  #endif

  /// Whether the text view uses TextKit 2.
  private let usesTextKit2: Bool

  /// Whether a layout is scheduled for the next turn of the run loop.
  private var isLayoutScheduled = false

  /// The text storage that shows the text.
  var shownTextStorage: NSTextStorage? {
    if usesTextKit2, #available(macOS 12.0, *) {
      return textContentStorage?.textStorage
    } else {
      return textStorage
    }
  }

  override open var isFlipped: Bool { true }

  // ⚠️ DON'T OVERRIDE `wantsUpdateLayer` ⚠️
  //
  // Override `wantsUpdateLayer` to return `true` could cause the text view to render nothing on macOS 12.
  //
  // Returning `true` is fine on macOS 15.
  //
  // override open var wantsUpdateLayer: Bool {
  //   if #available(macOS 12.0, *) {
  //     return true
  //   } else {
  //     // TextKit 1 doesn't support layer-based rendering
  //     return false
  //   }
  // }

  /// The attributed string content of the text view.
  ///
  /// Setting a text equal to the shown one can leave the shown text in place, so to change an attribute object, such as
  /// an attachment's image, set a text with a new object instead of changing the object.
  public var attributedString: NSAttributedString = NSAttributedString() {
    didSet {
      let storage = shownTextStorage

      // replacing the text storage's content edits it even with an equal text, which costs allocations and moves the
      // selection to the end, so an equal text is left in place. it's compared with the text storage instead of the old
      // value, since the text storage can hold the user's edits, which a new value replaces as before
      if storage?.isEqual(to: attributedString) != true {
        storage?.setAttributedString(attributedString)
      }

      // an equal text still invalidates the intrinsic size, which is computed from this property, and schedules a
      // layout, which also applies the changes made since the last one, such as a new inset
      invalidateIntrinsicContentSize()
      scheduleLayout()
    }
  }

  /// The number of lines to display. Set to 0 for unlimited lines (default).
  open var numberOfLines: Int = 0 {
    didSet {
      if numberOfLines == 1 {
        textContainer?.maximumNumberOfLines = 1
      } else {
        textContainer?.maximumNumberOfLines = numberOfLines > 0 ? numberOfLines : 0
      }

      invalidateIntrinsicContentSize()
      scheduleLayout()
    }
  }

  /// The line break mode to use for the text view. Default is `byWordWrapping`.
  open var lineBreakMode: NSLineBreakMode = .byWordWrapping {
    didSet {
      textContainer?.lineBreakMode = lineBreakMode

      invalidateIntrinsicContentSize()
      scheduleLayout()
    }
  }

  override public init(frame: CGRect) {
    #if DEBUG
    let usesTextKit2 = BaseTextView.shouldUseTextKit2 && !BaseTextView.usesTextKit1ForTesting
    #else
    let usesTextKit2 = BaseTextView.shouldUseTextKit2
    #endif
    self.usesTextKit2 = usesTextKit2

    if usesTextKit2, #available(macOS 12.0, *) {
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

    updateCommonSettings()

    textContainer?.maximumNumberOfLines = numberOfLines
    textContainer?.lineBreakMode = lineBreakMode

    isEditable = false
    isSelectable = true
    isRichText = false

    drawsBackground = false

    textContainerInset = .zero
    self.textContainer?.lineFragmentPadding = 0

    ensureClipsToBounds()
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  override open var intrinsicContentSize: NSSize {
    attributedString.boundingRectSize(numberOfLines: numberOfLines, layoutWidth: frame.width).roundedUp(scaleFactor: 1)
  }

  override open func layout() {
    super.layout()

    layoutSubviews()
  }

  open func layoutSubviews() {
    let size = bounds.size
    textContainer?.size = CGSize(width: size.width - textContainerInset.width * 2, height: size.height > 0 ? size.height : .greatestFiniteMagnitude)

    invalidateIntrinsicContentSize()
  }

  private func scheduleLayout() {
    // a refresh sets the text, the number of lines and the line break mode in one turn, and each schedules a layout,
    // but one layout after all of them does the same work, so a layout that is already scheduled isn't scheduled again
    guard !isLayoutScheduled else {
      return
    }
    isLayoutScheduled = true

    // schedule a layout on the next runloop to avoid an issue where the underlying `_NSTextViewportElementView`
    // doesn't update immediately when setting text with different lengths
    onNextRunLoop { [weak self] in
      // cleared before the layout, so that a change made during the layout schedules another one
      self?.isLayoutScheduled = false
      self?.setNeedsLayout()
      self?.layoutIfNeeded()
    }
  }

  override open func resignFirstResponder() -> Bool {
    // clear text selection when losing focus
    setSelectedRange(NSRange(location: 0, length: 0))

    return super.resignFirstResponder()
  }

  private func ensureClipsToBounds() {
    // clips the text within the bounds of the text view
    // for attributed text with `.byTruncatingTail` break mode, the text can overflow the bounds of the text view
    clipsToBounds = true

    // TextKit 1 draws the text in the text view itself, without the TextKit 2 subviews below, so their lookups would
    // fail their assertions
    guard usesTextKit2 else {
      return
    }

    if #available(macOS 26.0, *) {
      // macOS 26 (Tahoe) 26.4.1 (25E253)
      // (lldb) po subviews
      // ▿ 3 elements
      //   - 0 : <_NSTextSelectionView: 0x70ee1e080>
      //   - 1 : <_NSTextRenderingSurfacesGroupView: 0x70ee1e580>
      //   - 2 : <_NSTextContentView: 0x70ee1de00>
      if let textContentView = subviews.first(where: { $0.className == "_NSTextContentView" }).assertNotNil(),
         textContentView.clipsToBounds == false
      {
        textContentView.clipsToBounds = true
      }
    } else if #available(macOS 16.0, *) {
      // macOS 26 (Tahoe) beta 2
      // subviews:
      //   - 0 : <_NSTextSelectionView: 0xbc2a2e800>
      //   - 1 : <_NSTextRenderingSurfacesGroupView: 0xbc2a2e580>
      //   - 2 : <_NSTextRenderingSurfacesGroupView: 0xbc2a2e300>
      for subview in subviews where subview.className == "_NSTextRenderingSurfacesGroupView" {
        ComposeUI.assert(subview.clipsToBounds == true)
      }
    } else if #available(macOS 12.0, *) {
      // macOS 15 (Sequoia)
      // subviews:
      //   - 0 : <_NSTextSelectionView: 0x128808a80>
      //   - 1 : <_NSTextContentView: 0x128808650>
      if let textContentView = subviews.first(where: { $0.className == "_NSTextContentView" }).assertNotNil(),
         textContentView.clipsToBounds == false
      {
        textContentView.clipsToBounds = true
      }
    }
  }

  /// Reset the text view so it can be reused as if freshly made.
  open func resetForReuse() {
    let selectedRange = selectedRange
    if selectedRange.location != 0 || selectedRange.length != 0 {
      setSelectedRange(NSRange(location: 0, length: 0))
    }

    if window?.firstResponder === self {
      window?.makeFirstResponder(nil)
    }

    delegate = nil

    attributedString = NSAttributedString()

    if numberOfLines != 0 {
      numberOfLines = 0
    }
    if lineBreakMode != .byWordWrapping {
      lineBreakMode = .byWordWrapping
    }

    isEditable = false
    isSelectable = true
    isRichText = false

    drawsBackground = false

    if textContainerInset != .zero {
      textContainerInset = .zero
    }
    textContainer?.lineFragmentPadding = 0

    ensureClipsToBounds()

    ignoreHitTest = false
    typingAttributes = [:]
  }
}

#endif

#if canImport(UIKit)
import UIKit

open class BaseTextView: UITextView {

  /// The attributed string content of the text view.
  ///
  /// Setting a text equal to the shown one can leave the shown text in place, so to change an attribute object, such as
  /// an attachment's image, set a text with a new object instead of changing the object.
  public var attributedString: NSAttributedString = NSAttributedString() {
    didSet {
      // UITextView leaves an equal text in place itself, so there's no check here. tvOS adds the label color to a text
      // without a color, so it replaces such a text when it's set again, which isn't worked around, since that would
      // copy tvOS's rule
      attributedText = attributedString
    }
  }

  /// The number of lines to display. Set to 0 for unlimited lines (default).
  open var numberOfLines: Int = 0 {
    didSet {
      if numberOfLines == 1 {
        textContainer.maximumNumberOfLines = 1
      } else {
        textContainer.maximumNumberOfLines = numberOfLines > 0 ? numberOfLines : 0
      }
    }
  }

  /// The line break mode to use for the text view. Default is `byWordWrapping`.
  open var lineBreakMode: NSLineBreakMode = .byWordWrapping {
    didSet {
      textContainer.lineBreakMode = lineBreakMode
    }
  }

  override public init(frame: CGRect, textContainer: NSTextContainer?) {
    super.init(frame: frame, textContainer: textContainer)

    self.textContainer.maximumNumberOfLines = numberOfLines
    self.textContainer.lineBreakMode = lineBreakMode

    contentInsetAdjustmentBehavior = .never

    #if !os(tvOS)
    isEditable = false
    #endif
    isSelectable = true

    backgroundColor = nil

    textContainerInset = .zero
    self.textContainer.lineFragmentPadding = 0

    ensureClipsToBounds()
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  private func ensureClipsToBounds() {
    clipsToBounds = true
    if #available(iOS 16.0, *) {
      subviews.first(where: { String(cString: object_getClassName($0)) == "_UITextContainerView" }).assertNotNil()?.clipsToBounds = true
    }
  }

  /// Reset the text view so it can be reused as if freshly made.
  open func resetForReuse() {
    let selectedRange = selectedRange
    if selectedRange.location != 0 || selectedRange.length != 0 {
      self.selectedRange = NSRange(location: 0, length: 0)
    }

    if isFirstResponder {
      resignFirstResponder()
    }

    delegate = nil

    attributedString = NSAttributedString()
    if numberOfLines != 0 {
      numberOfLines = 0
    }
    if lineBreakMode != .byWordWrapping {
      lineBreakMode = .byWordWrapping
    }

    contentInsetAdjustmentBehavior = .never

    #if !os(tvOS)
    isEditable = false
    #endif
    isSelectable = true
    isUserInteractionEnabled = true

    backgroundColor = nil

    if textContainerInset != .zero {
      textContainerInset = .zero
    }
    if textContainer.lineFragmentPadding != 0 {
      textContainer.lineFragmentPadding = 0
    }

    ensureClipsToBounds()

    contentInset = .zero
    horizontalScrollIndicatorInsets = .zero
    verticalScrollIndicatorInsets = .zero
    setContentOffset(.zero, animated: false)

    typingAttributes = [:]
  }
}
#endif
