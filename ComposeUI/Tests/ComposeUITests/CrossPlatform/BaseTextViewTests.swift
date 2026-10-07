//
//  BaseTextViewTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 5/25/26.
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

import ChouTiTest

@testable import ComposeUI

class BaseTextViewTests: XCTestCase {

  #if canImport(UIKit)
  func test_contentInsetAdjustmentBehavior() {
    // given: a text view
    let textView = BaseTextView(frame: .zero)

    // then: the content inset adjustment behavior is never
    expect(textView.contentInsetAdjustmentBehavior) == .never
  }
  #endif

  #if canImport(AppKit)
  func test_removeFromSuperview_whenFirstResponder_resignsFirstResponder() {
    // given: a text view that is the first responder in a window
    let window = TestWindow()
    let container = NSView(frame: window.contentView?.bounds ?? .zero)
    let textView = BaseTextView(frame: container.bounds)

    window.contentView = container
    container.addSubview(textView)

    expect(window.makeFirstResponder(textView)) == true
    expect(window.firstResponder) === textView

    // when: the text view is removed from its superview
    textView.removeFromSuperview()

    // then: it resigns first responder and leaves the window
    expect(window.firstResponder) !== textView
    expect(textView.window) == nil
  }
  #endif

  #if canImport(UIKit) && !os(tvOS)
  func test_removeFromSuperview_whenFirstResponder_resignsFirstResponder() {
    // given: an editable text view that is the first responder in a key window
    let window = TestWindow()
    let viewController = UIViewController()
    let textView = BaseTextView(frame: window.bounds)

    window.rootViewController = viewController
    window.makeKeyAndVisible()
    viewController.view.addSubview(textView)

    textView.isEditable = true
    expect(textView.becomeFirstResponder()) == true
    expect(textView.isFirstResponder) == true

    // when: the text view is removed from its superview
    textView.removeFromSuperview()

    // then: it resigns first responder and leaves the window
    expect(textView.isFirstResponder) == false
    expect(textView.window) == nil
  }
  #endif

  // MARK: - Text

  func test_attributedString_equalText_leavesTheTextStorageUnedited() throws {
    for (textKit, textView) in Self.makeTextViews({ BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50)) }) {
      // given: a text view showing a text, and an observer of its text storage's edits
      textView.attributedString = Self.makeText("Hello, world!")
      let textStorage = try Self.textStorage(of: textView).unwrap()
      var editCount = 0
      let observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: textStorage, queue: nil) { _ in
        editCount += 1
      }
      defer {
        NotificationCenter.default.removeObserver(observer)
      }

      // when: setting an equal text, made anew
      textView.attributedString = Self.makeText("Hello, world!")

      // then: the text storage isn't edited
      expect(editCount, textKit) == 0

      // when: setting another text
      textView.attributedString = Self.makeText("Goodbye")

      // then: the text storage is edited to show it
      expect(editCount, textKit) == 1
      expect(textStorage.string, textKit) == "Goodbye"
    }
  }

  func test_attributedString_equalText_keepsTheSelection() {
    for (textKit, textView) in Self.makeTextViews({ BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50)) }) {
      // given: a text view showing a text, with part of it selected
      textView.attributedString = Self.makeText("Hello, world!")
      #if canImport(AppKit)
      textView.setSelectedRange(NSRange(location: 0, length: 5))
      #endif
      #if canImport(UIKit)
      textView.selectedRange = NSRange(location: 0, length: 5)
      #endif

      // when: setting an equal text, made anew, as a refresh of unchanged content does
      textView.attributedString = Self.makeText("Hello, world!")

      // then: the selection stays
      expect(textView.selectedRange, textKit) == NSRange(location: 0, length: 5)
    }
  }

  func test_attributedString_sameTextAfterAnEdit_replacesTheEdit() throws {
    for (textKit, textView) in Self.makeTextViews({ BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50)) }) {
      // given: a text view showing a text, which the user then edited
      textView.attributedString = Self.makeText("Hello")
      let textStorage = try Self.textStorage(of: textView).unwrap()
      textStorage.replaceCharacters(in: NSRange(location: 5, length: 0), with: ", world!")
      expect(textStorage.string, textKit) == "Hello, world!"

      // when: setting the same text as before the edit
      textView.attributedString = Self.makeText("Hello")

      // then: the text replaces the edit, since an equal text is compared with the text storage, not the old text
      expect(textStorage.string, textKit) == "Hello"
    }
  }

  #if canImport(AppKit)
  func test_attributedString_equalText_stillLaysOutTheTextContainer() {
    for (textKit, textView) in Self.makeTextViews({ BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50)) }) {
      // given: a text view showing a text, with the layout it scheduled run, whose horizontal inset then changed
      textView.attributedString = Self.makeText("Hello, world!")
      runScheduledBlocks()
      textView.textContainerInset = CGSize(width: 30, height: 0)

      // when: setting an equal text, and running the blocks it scheduled
      textView.attributedString = Self.makeText("Hello, world!")
      runScheduledBlocks()

      // then: the text view is laid out again, as for a different text, so its text container fits the new inset
      expect(textView.textContainer?.size.width, textKit) == 140
    }
  }

  func test_attributedString_userEditedTextSetBack_leavesTheTextStorageAndInvalidatesTheIntrinsicSize() throws {
    for (textKit, textView) in Self.makeTextViews({ CountingTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50)) }) {
      // given: a text view showing a model's mutable text, which the user then edited, with part of it selected, and an
      // observer of the text storage's edits
      let modelText = NSMutableAttributedString(attributedString: Self.makeText("Hello"))
      textView.attributedString = modelText
      let textStorage = try Self.textStorage(of: textView).unwrap()
      textStorage.replaceCharacters(in: NSRange(location: 5, length: 0), with: ", world!")
      textView.setSelectedRange(NSRange(location: 0, length: 5))
      var editCount = 0
      let observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: textStorage, queue: nil) { _ in
        editCount += 1
      }
      defer {
        NotificationCenter.default.removeObserver(observer)
      }
      textView.intrinsicSizeInvalidationCount = 0

      // when: the model takes the edit into its mutable text, and sets the same object again
      modelText.replaceCharacters(in: NSRange(location: 5, length: 0), with: ", world!")
      textView.attributedString = modelText

      // then: the text storage, which already shows the text, isn't edited and keeps the selection, and the intrinsic
      // size, which is computed from the text, is invalidated
      expect(editCount, textKit) == 0
      expect(textView.selectedRange, textKit) == NSRange(location: 0, length: 5)
      expect(textView.intrinsicSizeInvalidationCount, textKit) == 1
    }
  }

  func test_textAndLayoutSettings_setInOneTurn_layOutTheTextViewOnce() {
    for (textKit, textView) in Self.makeTextViews({ CountingTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50)) }) {
      // given: a text view showing a text, with the layout it scheduled run
      textView.attributedString = Self.makeText("Hello")
      runScheduledBlocks()
      textView.layoutCount = 0

      // when: setting another text, number of lines and line break mode in one turn, as a refresh does, and running the
      // blocks they scheduled
      textView.attributedString = Self.makeText("Hello, world!")
      textView.numberOfLines = 2
      textView.lineBreakMode = .byClipping
      runScheduledBlocks()

      // then: the text view is laid out once, after all of the changes
      expect(textView.layoutCount, textKit) == 1
    }
  }

  func test_changeDuringTheScheduledLayout_schedulesAnotherLayout() {
    for (textKit, textView) in Self.makeTextViews({ CountingTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50)) }) {
      // given: a text view whose first scheduled layout sets the number of lines, as a subclass can
      textView.onLayout = { [weak textView] in
        textView?.onLayout = nil
        textView?.numberOfLines = 3
      }

      // when: setting a text, and running the blocks it scheduled, then the blocks its layout scheduled
      textView.attributedString = Self.makeText("Hello")
      runScheduledBlocks()
      runScheduledBlocks()

      // then: the change made during the layout gets a layout of its own
      expect(textView.layoutCount, textKit) == 2
      expect(textView.textContainer?.maximumNumberOfLines, textKit) == 3
    }
  }
  #endif

  // MARK: - resetForReuse

  func test_resetForReuse_clearsSelection() {
    // given: a text view with text and a selection
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")

    #if canImport(AppKit)
    textView.setSelectedRange(NSRange(location: 0, length: 5))
    #endif
    #if canImport(UIKit)
    textView.selectedRange = NSRange(location: 0, length: 5)
    #endif
    expect(textView.selectedRange.length) == 5

    // when: reset for reuse
    textView.resetForReuse()

    // then: the selection is cleared
    expect(textView.selectedRange.location) == 0
    expect(textView.selectedRange.length) == 0
  }

  func test_resetForReuse_clearsFirstResponder() {
    #if canImport(AppKit)
    // given: a text view that is the first responder in a window
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    let window = TestWindow()
    window.contentView = NSView(frame: window.frame)
    window.contentView?.addSubview(textView)
    window.makeFirstResponder(textView)
    expect(window.firstResponder) === textView

    // when: reset for reuse
    textView.resetForReuse()

    // then: the text view is no longer the first responder
    expect(window.firstResponder) !== textView
    #endif

    #if canImport(UIKit) && !os(tvOS)
    // given: a text view that is the first responder in a key window
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    let window = TestWindow()
    window.rootViewController = UIViewController()
    window.rootViewController?.view.addSubview(textView)
    window.makeKeyAndVisible()
    textView.becomeFirstResponder()
    expect(textView.isFirstResponder) == true

    // when: reset for reuse
    textView.resetForReuse()

    // then: the text view is no longer the first responder
    expect(textView.isFirstResponder) == false
    #endif
  }

  func test_resetForReuse_clearsDelegate() {
    #if canImport(AppKit)
    // given: a text view with a delegate
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    class TestDelegate: NSObject, NSTextViewDelegate {}
    let delegate = TestDelegate()
    textView.delegate = delegate
    expect(textView.delegate) != nil

    // when: reset for reuse
    textView.resetForReuse()

    // then: the delegate is cleared
    expect(textView.delegate) == nil
    #endif

    #if canImport(UIKit)
    // given: a text view with a delegate
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    class TestDelegate: NSObject, UITextViewDelegate {}
    let delegate = TestDelegate()
    textView.delegate = delegate
    expect(textView.delegate) != nil

    // when: reset for reuse
    textView.resetForReuse()

    // then: the delegate is cleared
    expect(textView.delegate) == nil
    #endif
  }

  func test_resetForReuse_clearsAttributedString() {
    // given: a text view with an attributed string
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")
    expect(textView.attributedString.string) == "Hello, world!"

    // when: reset for reuse
    textView.resetForReuse()

    // then: the attributed string is cleared
    expect(textView.attributedString.string) == ""
  }

  func test_resetForReuse_clearsNumberOfLines() {
    // given: a text view with a number of lines set
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.numberOfLines = 2
    expect(textView.numberOfLines) == 2

    // when: reset for reuse
    textView.resetForReuse()

    // then: the number of lines is reset to 0
    expect(textView.numberOfLines) == 0
  }

  func test_resetForReuse_clearsLineBreakMode() {
    // given: a text view with a custom line break mode
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.lineBreakMode = .byTruncatingTail
    expect(textView.lineBreakMode) == .byTruncatingTail

    // when: reset for reuse
    textView.resetForReuse()

    // then: the line break mode is reset to word wrapping
    expect(textView.lineBreakMode) == .byWordWrapping
  }

  #if canImport(UIKit)
  func test_resetForReuse_clearsContentInsetAdjustmentBehavior() {
    // given: a text view with automatic content inset adjustment
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.contentInsetAdjustmentBehavior = .automatic
    expect(textView.contentInsetAdjustmentBehavior) == .automatic

    // when: reset for reuse
    textView.resetForReuse()

    // then: the content inset adjustment behavior is reset to never
    expect(textView.contentInsetAdjustmentBehavior) == .never
  }
  #endif

  #if canImport(AppKit) || canImport(UIKit) && !os(tvOS)
  func test_resetForReuse_clearsIsEditable() {
    // given: an editable text view
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.isEditable = true
    expect(textView.isEditable) == true

    // when: reset for reuse
    textView.resetForReuse()

    // then: the text view is no longer editable
    expect(textView.isEditable) == false
  }
  #endif

  func test_resetForReuse_clearsIsSelectable() {
    // given: a text view that is not selectable
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.isSelectable = false
    expect(textView.isSelectable) == false

    // when: reset for reuse
    textView.resetForReuse()

    // then: the text view is selectable again
    expect(textView.isSelectable) == true
  }

  #if canImport(AppKit)
  func test_resetForReuse_clearsIsRichText() {
    // given: a text view with rich text enabled
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.isRichText = true
    expect(textView.isRichText) == true

    // when: reset for reuse
    textView.resetForReuse()

    // then: rich text is disabled
    expect(textView.isRichText) == false
  }
  #endif

  #if canImport(UIKit)
  func test_resetForReuse_clearsIsUserInteractionEnabled() {
    // given: a text view with user interaction disabled
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.isUserInteractionEnabled = false
    expect(textView.isUserInteractionEnabled) == false

    // when: reset for reuse
    textView.resetForReuse()

    // then: user interaction is enabled again
    expect(textView.isUserInteractionEnabled) == true
  }
  #endif

  func test_resetForReuse_clearsBackground() {
    #if canImport(AppKit)
    // given: a text view that draws its background
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.drawsBackground = true
    expect(textView.drawsBackground) == true

    // when: reset for reuse
    textView.resetForReuse()

    // then: the background drawing is disabled
    expect(textView.drawsBackground) == false
    #endif

    #if canImport(UIKit)
    // given: a text view with a background color
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.backgroundColor = .red
    expect(textView.backgroundColor) == .red

    // when: reset for reuse
    textView.resetForReuse()

    // then: the background color is cleared
    expect(textView.backgroundColor) == nil
    #endif
  }

  func test_resetForReuse_clearsTextContainerInset() {
    #if canImport(AppKit)
    // given: a text view with a text container inset
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.textContainerInset = CGSize(width: 10, height: 10)
    expect(textView.textContainerInset) == CGSize(width: 10, height: 10)

    // when: reset for reuse
    textView.resetForReuse()

    // then: the text container inset is reset to zero
    expect(textView.textContainerInset) == .zero
    #endif

    #if canImport(UIKit)
    // given: a text view with a text container inset
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.textContainerInset = EdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    expect(textView.textContainerInset) == EdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

    // when: reset for reuse
    textView.resetForReuse()

    // then: the text container inset is reset to zero
    expect(textView.textContainerInset) == .zero
    #endif
  }

  func test_resetForReuse_clearsTextContainerLineFragmentPadding() {
    #if canImport(AppKit)
    // given: a text view with a line fragment padding
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.textContainer?.lineFragmentPadding = 10
    expect(textView.textContainer?.lineFragmentPadding) == 10

    // when: reset for reuse
    textView.resetForReuse()

    // then: the line fragment padding is reset to zero
    expect(textView.textContainer?.lineFragmentPadding) == 0
    #endif

    #if canImport(UIKit)
    // given: a text view with a line fragment padding
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.textContainer.lineFragmentPadding = 10
    expect(textView.textContainer.lineFragmentPadding) == 10

    // when: reset for reuse
    textView.resetForReuse()

    // then: the line fragment padding is reset to zero
    expect(textView.textContainer.lineFragmentPadding) == 0
    #endif
  }

  func test_resetForReuse_clearsClipsToBounds() {
    // given: a text view with clips to bounds enabled
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.clipsToBounds = true
    expect(textView.clipsToBounds) == true

    // when: reset for reuse
    textView.resetForReuse()

    // then: clips to bounds stays enabled
    expect(textView.clipsToBounds) == true
  }

  #if canImport(AppKit)
  func test_resetForReuse_clearsIgnoreHitTest() {
    // given: a text view that ignores hit testing
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.ignoreHitTest = true
    expect(textView.ignoreHitTest) == true

    // when: reset for reuse
    textView.resetForReuse()

    // then: hit testing is no longer ignored
    expect(textView.ignoreHitTest) == false
  }
  #endif

  #if canImport(UIKit)
  func test_resetForReuse_clearsContentOffset() {
    // given: a text view with a content offset
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.contentOffset = CGPoint(x: 0, y: 20)
    expect(textView.contentOffset) == CGPoint(x: 0, y: 20)

    // when: reset for reuse
    textView.resetForReuse()

    // then: the content offset is reset to zero
    expect(textView.contentOffset) == .zero
  }

  func test_resetForReuse_clearsScrollIndicatorInsets() {
    // given: a text view with scroll indicator insets
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.horizontalScrollIndicatorInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    textView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    expect(textView.horizontalScrollIndicatorInsets) == UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    expect(textView.verticalScrollIndicatorInsets) == UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

    // when: reset for reuse
    textView.resetForReuse()

    // then: the scroll indicator insets are reset to zero
    expect(textView.horizontalScrollIndicatorInsets) == .zero
    expect(textView.verticalScrollIndicatorInsets) == .zero
  }

  func test_resetForReuse_resetsScrollOffset() {
    // given: a text view scrolled to an offset
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.contentOffset = CGPoint(x: 0, y: 20)
    expect(textView.contentOffset) == CGPoint(x: 0, y: 20)

    // when: reset for reuse
    textView.resetForReuse()

    // then: the scroll offset is reset to zero
    expect(textView.contentOffset) == .zero
  }
  #endif

  func test_resetForReuse_clearsTypingAttributes() {
    // given: a text view with typing attributes
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.typingAttributes = [NSAttributedString.Key.font: Font.systemFont(ofSize: 12)]

    // when: reset for reuse
    textView.resetForReuse()

    // then: the typing attributes are cleared
    expect(textView.typingAttributes.isEmpty) == true
  }

  // MARK: - Helpers

  /// Returns a text with a font and a color, as a label's text has.
  ///
  /// The text has a color since tvOS's text view adds the label color to a text without one, and then replaces it when
  /// it's set again, which `BaseTextView` leaves to it.
  private static func makeText(_ string: String) -> NSAttributedString {
    NSAttributedString(string: string, attributes: [.font: Font.systemFont(ofSize: 13), .foregroundColor: Color.red])
  }

  /// Returns the text storage that shows the text view's text.
  private static func textStorage(of textView: BaseTextView) -> NSTextStorage? {
    #if canImport(AppKit)
    return textView.shownTextStorage
    #else
    return textView.textStorage
    #endif
  }

  /// Returns a text view of each TextKit the platform's text views use, TextKit 2 and TextKit 1 on macOS, with the
  /// TextKit's name.
  private static func makeTextViews<T: BaseTextView>(_ make: () -> T) -> [(String, T)] {
    #if canImport(AppKit)
    BaseTextView.usesTextKit1ForTesting = true
    let textKit1TextView = make()
    BaseTextView.usesTextKit1ForTesting = false
    // text views use TextKit 2 from macOS 13
    guard #available(macOS 13.0, *) else {
      return [("TextKit 1", textKit1TextView)]
    }
    let textKit2TextView = make()
    // if the flag stopped taking effect, the TextKit 1 runs would silently test TextKit 2 again
    expect(textKit2TextView.textLayoutManager) != nil
    expect(textKit1TextView.textLayoutManager) == nil
    return [("TextKit 2", textKit2TextView), ("TextKit 1", textKit1TextView)]
    #else
    return [("TextKit", make())]
    #endif
  }

  /// Runs the main run loop until the blocks scheduled on it so far have run, such as a text view's scheduled layout.
  private func runScheduledBlocks() {
    var isDrained = false
    RunLoop.main.perform {
      isDrained = true
    }
    expect(isDrained).toEventually(beTrue())
  }
}

#if canImport(AppKit)
/// A text view that counts its layout passes and the invalidations of its intrinsic size.
private final class CountingTextView: BaseTextView {

  var layoutCount = 0
  var intrinsicSizeInvalidationCount = 0

  /// Called at the end of each layout pass.
  var onLayout: (() -> Void)?

  override func layout() {
    super.layout()
    layoutCount += 1
    onLayout?()
  }

  override func invalidateIntrinsicContentSize() {
    super.invalidateIntrinsicContentSize()
    intrinsicSizeInvalidationCount += 1
  }
}
#endif
