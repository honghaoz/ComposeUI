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

// MARK: - AppKit

#if canImport(AppKit)
import AppKit

/// A base text view.
///
/// The text view removes its registrations for `NSView.frameDidChangeNotification` when it moves into a window and
/// when it's removed from its superview, unless its superview is a clip view, so a subclass observes frame changes with
/// another object than itself.
open class BaseTextView: TextView {

  /// The text that the text view shows.
  private let shownText: ShownText

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
  ///
  /// A text view that isn't editable when its text is set shows each paragraph without a writing direction in the
  /// direction of its text, as ComposeUI measures it. An editable text view shows the text as set, so that the text and
  /// the paragraphs that the user types align by the same rule, by the user's language, as in other TextKit 1 text
  /// views.
  public var attributedString: NSAttributedString = NSAttributedString() {
    didSet {
      isTextRemovalScheduled = false
      let isChanged = shownText.show(attributedString, resolvesWritingDirections: !isEditable) { textStorage?.setAttributedString($0) }

      // the intrinsic size is computed from the text, so only a different text invalidates it
      if isChanged {
        invalidateIntrinsicContentSize()
      }
    }
  }

  /// The text that `TextNode` last applied a theme to, with the theme and the themed text.
  var lastThemedText: (text: NSAttributedString, theme: Theme, themedText: NSAttributedString)?

  /// Whether the text view removes its text at the end of the run loop turn, unless it gets another text before.
  fileprivate var isTextRemovalScheduled = false

  /// Whether the text view is in the list of text views that remove their text at the end of the run loop turn, where it
  /// stays until then, also when another text cancels the removal.
  fileprivate var isInTextRemovalList = false

  #if DEBUG
  /// The number of text views in the list of text views that remove their text at the end of the run loop turn, for
  /// tests.
  static var scheduledTextRemovalCount: Int {
    ScheduledTextRemoval.count
  }
  #endif

  /// The number of lines to display. Set to 0 for unlimited lines (default).
  open var numberOfLines: Int = 0 {
    didSet {
      if numberOfLines == 1 {
        textContainer?.maximumNumberOfLines = 1
      } else {
        textContainer?.maximumNumberOfLines = numberOfLines > 0 ? numberOfLines : 0
      }

      invalidateIntrinsicContentSize()
    }
  }

  /// The line break mode to use for the text view. Default is `byWordWrapping`.
  open var lineBreakMode: NSLineBreakMode = .byWordWrapping {
    didSet {
      textContainer?.lineBreakMode = lineBreakMode

      invalidateIntrinsicContentSize()
    }
  }

  override open var textContainerInset: NSSize {
    didSet {
      // the text view moves its text container by the inset without resizing it
      fitTextContainer()
    }
  }

  override public init(frame: CGRect) {
    // the text is laid out with TextKit 1, as ComposeUI measures text, so that it fits the size measured for it.
    // a TextKit 2 text view lays out the part of its text that's visible, so it lays out again whenever the scroll view
    // it's in scrolls, even when its text and size are unchanged
    let textContainer = NSTextContainer(size: frame.size)

    let layoutManager = NSLayoutManager()
    layoutManager.addTextContainer(textContainer)

    let textStorage = NSTextStorage()
    textStorage.addLayoutManager(layoutManager)

    shownText = ShownText(textStorage: textStorage)

    super.init(frame: frame, textContainer: textContainer)

    updateCommonSettings()

    textContainer.maximumNumberOfLines = numberOfLines
    textContainer.lineBreakMode = lineBreakMode

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

  override open func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)

    // the text container is fitted when the size changes, instead of in the layout that the change asks for, which a
    // text view without a window doesn't get
    fitTextContainer()
  }

  override open func layout() {
    super.layout()

    layoutSubviews()
  }

  open func layoutSubviews() {
    fitTextContainer()

    invalidateIntrinsicContentSize()
  }

  /// Fits the text container in the bounds, inside the horizontal inset.
  private func fitTextContainer() {
    let size = bounds.size
    textContainer?.size = CGSize(
      width: size.width - textContainerInset.width * 2,
      height: size.height > 0 ? size.height : .greatestFiniteMagnitude
    )
  }

  override open func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    stopObservingEveryFrameChange()
  }

  override open func removeFromSuperview() {
    super.removeFromSuperview()

    stopObservingEveryFrameChange()
  }

  /// Removes the text view's registration for the frame changes of every view, unless its superview is a clip view.
  private func stopObservingEveryFrameChange() {
    // AppKit registers a text view for the frame changes of every view each time it moves to a superview that isn't a
    // clip view, even while it deallocates, so each frame change in the process calls into each such text view, and a
    // text view that's gone leaves a registration that each later frame change scans. AppKit registers it after
    // `viewDidMoveToSuperview()`, so it's removed in the calls after it, on a move into a window and on each removal
    // from a superview. Under a clip view, AppKit registers the text view for the clip view's frame changes only, which
    // the text view keeps, as the clip view's document view
    guard !(superview is NSClipView) else {
      return
    }
    NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: nil)
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
  }

  /// Reset the text view so it can be reused as if freshly made.
  open func resetForReuse() {
    resetForReuse(keepsTextNodeSettings: false)
  }

  /// Resets the text view so it can be reused as if freshly made, except for what a text node sets on each reuse when
  /// it's kept.
  ///
  /// A text node sets a text view's interaction settings, number of lines, line break mode, inset and text each time it
  /// reuses the text view, so setting them back to their defaults would pay for each change twice, and a change of the
  /// number of lines, the line break mode or the inset with the text in place lays the text out again. So they're kept,
  /// and the text view removes its text at the end of the run loop turn, unless it gets another text before, which
  /// replaces the text in one edit, such as when a scroll reuses it in the same render pass.
  ///
  /// - Parameter keepsTextNodeSettings: Whether to keep the settings and, until the end of the run loop turn, the text,
  ///   for a reuse by a text node.
  func resetForReuse(keepsTextNodeSettings: Bool) {
    // moving the selection makes the text view's text checking read the text around it, which allocates even when the
    // text view isn't editable. a text node sets a text on each reuse, which moves the selection, or leaves an equal text
    // in place, where an insertion point doesn't show, so for a text node, only an insertion point, an empty selection
    // with no other selected ranges after it, is left in place
    let selectedRange = selectedRange
    if selectedRange.length != 0 || (keepsTextNodeSettings ? selectedRanges.count > 1 : selectedRange.location != 0) {
      setSelectedRange(NSRange(location: 0, length: 0))
    }

    if window?.firstResponder === self {
      window?.makeFirstResponder(nil)
    }

    delegate = nil

    if keepsTextNodeSettings {
      ScheduledTextRemoval.schedule(self)
    } else {
      attributedString = NSAttributedString()
      if numberOfLines != 0 {
        numberOfLines = 0
      }
      if lineBreakMode != .byWordWrapping {
        lineBreakMode = .byWordWrapping
      }
      if textContainerInset != .zero {
        textContainerInset = .zero
      }
      isEditable = false
      isSelectable = true
      ignoreHitTest = false
    }
    lastThemedText = nil

    isRichText = false

    drawsBackground = false

    textContainer?.lineFragmentPadding = 0

    ensureClipsToBounds()

    typingAttributes = [:]
  }
}

// MARK: - Scheduled Text Removal

/// The text views that remove their text at the end of the run loop turn, unless they get another text before.
///
/// A text view that a text node resets for reuse keeps its text until then, so that a reuse in the same render pass
/// replaces the text in one edit, while a text view that stays in the pool doesn't keep its text, and the objects that
/// the text's attributes hold, for longer than the turn. The list holds each text view once, so that it stays as long as
/// the number of text views reset in the turn, however many refreshes run in it.
///
/// The list holds its text views strongly: AppKit keeps a text view that its owners let go of alive for longer than a run
/// loop turn, so a weak reference wouldn't let one that the pool has no room for deallocate any sooner.
private enum ScheduledTextRemoval {

  /// The text views that remove their text at the end of the run loop turn.
  private static var textViews: [BaseTextView] = []

  #if DEBUG
  /// The number of text views in the list.
  static var count: Int {
    textViews.count
  }
  #endif

  /// Schedules a text view to remove its text at the end of the run loop turn, unless it gets another text before.
  static func schedule(_ textView: BaseTextView) {
    textView.isTextRemovalScheduled = true

    // a text view that's reused and reset again in the same turn is in the list already
    guard !textView.isInTextRemovalList else {
      return
    }

    if textViews.isEmpty {
      onNextRunLoop {
        removeTexts()
      }
    }
    textView.isInTextRemovalList = true
    textViews.append(textView)
  }

  /// Removes the text of each listed text view that hasn't got another text.
  private static func removeTexts() {
    // a text storage edit can call back into code that resets text views, which then schedule into a new list, so the
    // list is taken first instead of cleared after the loop
    let textViews = textViews
    Self.textViews = []
    for textView in textViews {
      textView.isInTextRemovalList = false
      if textView.isTextRemovalScheduled {
        textView.attributedString = NSAttributedString()
      }
    }
  }
}

#endif

// MARK: - UIKit

#if canImport(UIKit)
import UIKit

open class BaseTextView: UITextView {

  /// The text that the text view shows, `nil` for a given TextKit 2 text container, with which the text view leaves an
  /// equal text in place itself.
  private let shownText: ShownText?

  /// The attributed string content of the text view.
  ///
  /// Setting a text equal to the shown one can leave the shown text in place, so to change an attribute object, such as
  /// an attachment's image, set a text with a new object instead of changing the object.
  ///
  /// A text view that isn't editable when its text is set shows each paragraph without a writing direction in the
  /// direction of its text, as ComposeUI measures it. An editable text view shows the text as set, so that the text and
  /// the paragraphs that the user types align by the same rule, by the user's language, as in other TextKit 1 text
  /// views.
  public var attributedString: NSAttributedString = NSAttributedString() {
    didSet {
      if let shownText {
        #if os(tvOS)
        // a tvOS text view isn't editable
        let resolvesWritingDirections = true
        #else
        let resolvesWritingDirections = !isEditable
        #endif
        _ = shownText.show(
          attributedString,
          resolvesWritingDirections: resolvesWritingDirections,
          setText: { text in
            if isRemovingTextForReuse {
              textStorage.setAttributedString(text)
            } else {
              attributedText = text
            }
          }
        )
      } else {
        attributedText = attributedString
      }
    }
  }

  /// The text that `TextNode` last applied a theme to, with the theme and the themed text.
  var lastThemedText: (text: NSAttributedString, theme: Theme, themedText: NSAttributedString)?

  /// Whether the text view is removing its text for a reuse by a text node.
  private var isRemovingTextForReuse = false

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
    if let textContainer {
      shownText = textContainer.layoutManager?.textStorage.map { ShownText(textStorage: $0) }
      super.init(frame: frame, textContainer: textContainer)
    } else {
      // the text is laid out with TextKit 1, as ComposeUI measures text, so that it fits the size measured for it, which
      // also lays out new text with far fewer allocations than TextKit 2, which the text view uses when it makes its own
      // text system
      let textContainer = NSTextContainer(size: frame.size)

      let layoutManager = NSLayoutManager()
      layoutManager.addTextContainer(textContainer)

      // the text view doesn't keep the text storage of a given text container, so the shown text keeps it
      let textStorage = NSTextStorage()
      textStorage.addLayoutManager(layoutManager)

      shownText = ShownText(textStorage: textStorage)
      super.init(frame: frame, textContainer: textContainer)
    }

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
    resetForReuse(keepsTextNodeSettings: false)
  }

  /// Resets the text view so it can be reused as if freshly made, except for the settings that a text node sets on each
  /// reuse when they're kept.
  ///
  /// A text node sets a text view's interaction settings, number of lines, line break mode and inset each time it reuses
  /// the text view, so setting them back to their defaults would pay for each change twice. The text is removed at once,
  /// unlike on AppKit, since replacing a UIKit text view's text costs more than removing it and setting the new one, and
  /// a reuse moves and resizes the text view before it sets the new text, which costs more with a text in place.
  ///
  /// - Parameter keepsTextNodeSettings: Whether to keep the settings, for a reuse by a text node.
  func resetForReuse(keepsTextNodeSettings: Bool) {
    // removing the text below takes the selection to the start, so a text node's reset doesn't also move it there first,
    // which allocates
    let selectedRange = selectedRange
    if !keepsTextNodeSettings, selectedRange.location != 0 || selectedRange.length != 0 {
      self.selectedRange = NSRange(location: 0, length: 0)
    }

    if isFirstResponder {
      resignFirstResponder()
    }

    delegate = nil

    // removing a text through the text storage leaves the text view as `attributedText` does, in a little over half of
    // the allocations, but tells no one that the selection moved to the start, which `attributedText` tells the
    // delegate, the input delegate and key-value observers. so only a text node's reset removes it this way, since the
    // text view has no delegate and isn't the first responder by now, and goes to the pool, where nothing else observes
    // it, while an app may still observe a text view that it resets itself
    isRemovingTextForReuse = keepsTextNodeSettings
    attributedString = NSAttributedString()
    isRemovingTextForReuse = false
    lastThemedText = nil

    if !keepsTextNodeSettings {
      if numberOfLines != 0 {
        numberOfLines = 0
      }
      if lineBreakMode != .byWordWrapping {
        lineBreakMode = .byWordWrapping
      }
      if textContainerInset != .zero {
        textContainerInset = .zero
      }
      #if !os(tvOS)
      isEditable = false
      #endif
      isSelectable = true
      isUserInteractionEnabled = true
    }

    contentInsetAdjustmentBehavior = .never

    backgroundColor = nil

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

// MARK: - Shown Text

/// The text that a TextKit 1 text view shows, which leaves an equal text in place.
///
/// Replacing a text storage's content edits it even with an equal text, which costs allocations and moves the selection
/// to the end. The text storage gives a substitute font to the characters that their font doesn't have, so it differs
/// from an equal text, which is compared with the text that the text view was last set to instead.
final class ShownText: NSObject {

  /// The text storage that shows the text.
  private let textStorage: NSTextStorage

  /// The text that the text view was last set to show, as it was set.
  private var lastText = NSAttributedString()

  /// Whether the text storage was edited since its text was last set, such as by the user.
  private var isTextStorageEdited: Bool

  /// Whether the text storage's text is being set.
  private var isSettingText = false

  /// Whether the text storage shows the last text with the writing directions of its paragraphs.
  private var showsWritingDirections = true

  /// Creates the shown text of a text storage.
  ///
  /// - Parameter textStorage: The text storage that shows the text.
  init(textStorage: NSTextStorage) {
    self.textStorage = textStorage

    // a given text storage can come with text that the text view wasn't set to show, so the first text is compared with
    // the text storage, as after an edit
    isTextStorageEdited = textStorage.length > 0

    super.init()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didProcessTextStorageEditing(_:)),
      name: NSTextStorage.didProcessEditingNotification,
      object: textStorage
    )
  }

  /// Shows a text, unless the text storage shows an equal one.
  ///
  /// - Parameters:
  ///   - text: The text to show.
  ///   - resolvesWritingDirections: Whether to show the text with the writing directions of its paragraphs, since
  ///     TextKit 1 aligns a paragraph without one by the user's language instead of by its text, see
  ///     `resolvingNaturalWritingDirections()`.
  ///   - setText: Sets the text storage's text to the given text.
  /// - Returns: Whether the text differs from the text that the text view was last set to show.
  func show(_ text: NSAttributedString, resolvesWritingDirections: Bool, setText: (NSAttributedString) -> Void) -> Bool {
    if isTextStorageEdited {
      // the text storage holds an edit, such as the user's, which a text replaces unless it's equal to the edited text,
      // so the text is compared with the text storage, with the substitute fonts that the text storage gives it
      let shownText = resolvesWritingDirections ? text.resolvingNaturalWritingDirections() : text
      if !textStorage.isEqual(to: Self.textWithSubstituteFonts(of: shownText)) {
        set(shownText, with: setText)
      }
      lastText = Self.immutableText(of: text)
      isTextStorageEdited = false
      showsWritingDirections = resolvesWritingDirections
      return true
    } else if !lastText.isEqual(to: text) {
      // comparing the text as it was set also leaves the writing directions to resolve only for a new text
      set(resolvesWritingDirections ? text.resolvingNaturalWritingDirections() : text, with: setText)
      lastText = Self.immutableText(of: text)
      showsWritingDirections = resolvesWritingDirections
      return true
    } else if resolvesWritingDirections != showsWritingDirections {
      // an equal text is shown again when its writing directions change, such as after the text view becomes editable,
      // which leaves the text's size as it was
      set(resolvesWritingDirections ? text.resolvingNaturalWritingDirections() : text, with: setText)
      showsWritingDirections = resolvesWritingDirections
      return false
    } else {
      return false
    }
  }

  /// Sets the text storage's text, which isn't an edit to compare a new text with.
  private func set(_ text: NSAttributedString, with setText: (NSAttributedString) -> Void) {
    isSettingText = true
    setText(text)
    isSettingText = false
  }

  @objc private func didProcessTextStorageEditing(_ notification: NSNotification) {
    if !isSettingText {
      isTextStorageEdited = true
    }
  }

  /// Returns the text with the substitute fonts that a text view's text storage gives it.
  private static func textWithSubstituteFonts(of text: NSAttributedString) -> NSAttributedString {
    #if canImport(AppKit)
    let fixedText = NSMutableAttributedString(attributedString: text)
    fixedText.fixAttributes(in: NSRange(location: 0, length: fixedText.length))
    return fixedText
    #else
    // a UIKit text view's text storage also records the font of each run that it gives a substitute font
    return text.recordingOriginalFonts()
    #endif
  }

  /// Returns an immutable copy of a text, or the text itself when it's immutable.
  private static func immutableText(of text: NSAttributedString) -> NSAttributedString {
    // a mutable text can change after it's set, so it's compared later through a copy
    text is NSMutableAttributedString ? NSAttributedString(attributedString: text) : text
  }
}
