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
    // given: a text view showing a text, and an observer of its text storage's edits
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
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
    expect(editCount) == 0

    // when: setting another text
    textView.attributedString = Self.makeText("Goodbye")

    // then: the text storage is edited to show it
    expect(editCount) == 1
    expect(textStorage.string) == "Goodbye"
  }

  func test_attributedString_equalText_keepsTheSelection() {
    // given: a text view showing a text, with part of it selected
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
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
    expect(textView.selectedRange) == NSRange(location: 0, length: 5)
  }

  func test_attributedString_sameTextAfterAnEdit_replacesTheEdit() throws {
    // given: a text view showing a text, which the user then edited
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = Self.makeText("Hello")
    let textStorage = try Self.textStorage(of: textView).unwrap()
    textStorage.replaceCharacters(in: NSRange(location: 5, length: 0), with: ", world!")
    expect(textStorage.string) == "Hello, world!"

    // when: setting the same text as before the edit
    textView.attributedString = Self.makeText("Hello")

    // then: the text replaces the edit, since an equal text is compared with the text storage, not the old text
    expect(textStorage.string) == "Hello"
  }

  func test_attributedString_equalTextWithSubstituteFonts_leavesTheTextStorageUnedited() throws {
    for string in ["مرحبا بالعالم", "Hello 😀👍🏽", "你好，世界", "नमस्ते दुनिया"] {
      // given: a text view showing a text with characters that its font doesn't have, which the text storage gives
      // substitute fonts, with part of it selected, and an observer of the text storage's edits
      let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
      textView.attributedString = Self.makeText(string)
      #if canImport(AppKit)
      textView.setSelectedRange(NSRange(location: 0, length: 2))
      #endif
      #if canImport(UIKit)
      textView.selectedRange = NSRange(location: 0, length: 2)
      #endif
      let textStorage = try Self.textStorage(of: textView).unwrap()
      var editCount = 0
      let observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: textStorage, queue: nil) { _ in
        editCount += 1
      }
      defer {
        NotificationCenter.default.removeObserver(observer)
      }

      // when: setting an equal text, made anew
      textView.attributedString = Self.makeText(string)

      // then: the text storage isn't edited, and the selection stays
      expect(editCount, string) == 0
      expect(textView.selectedRange, string) == NSRange(location: 0, length: 2)
    }
  }

  func test_attributedString_mutableTextChangedInPlace_showsTheChange() throws {
    // given: a text view showing a model's mutable text
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    let modelText = NSMutableAttributedString(attributedString: Self.makeText("Hello"))
    textView.attributedString = modelText

    // when: the model changes its text in place, and sets the same object again
    modelText.replaceCharacters(in: NSRange(location: 5, length: 0), with: ", world!")
    textView.attributedString = modelText

    // then: the text storage shows the changed text
    let textStorage = try Self.textStorage(of: textView).unwrap()
    expect(textStorage.string) == "Hello, world!"
  }

  func test_attributedString_editedTextWithSubstituteFontsSetBack_leavesTheTextStorage() throws {
    // given: a text view showing a text with characters that its font doesn't have, which the text storage gives
    // substitute fonts, which the user then edited, with part of it selected, and an observer of the text storage's
    // edits
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = Self.makeText("你好")
    let textStorage = try Self.textStorage(of: textView).unwrap()
    textStorage.replaceCharacters(in: NSRange(location: 2, length: 0), with: "世界")
    #if canImport(AppKit)
    textView.setSelectedRange(NSRange(location: 0, length: 2))
    #endif
    #if canImport(UIKit)
    textView.selectedRange = NSRange(location: 0, length: 2)
    #endif
    var editCount = 0
    let observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: textStorage, queue: nil) { _ in
      editCount += 1
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
    }

    // when: the model takes the edit into a text, and sets it
    textView.attributedString = Self.makeText("你好世界")

    // then: the text storage, which already shows the text with the substitute fonts, isn't edited and keeps the
    // selection
    expect(editCount) == 0
    expect(textView.selectedRange) == NSRange(location: 0, length: 2)
  }

  func test_attributedString_equalTextWithSubstituteFonts_doesntAllocate() {
    for string in ["你好，世界", "مرحبا بالعالم"] {
      // given: a text view just set to show a text with characters that its font doesn't have, which the text storage
      // gives substitute fonts, after another text view was set to an equal text, since a first set can also allocate
      // what the runtime makes on first use
      let warmedUpTextView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
      warmedUpTextView.attributedString = Self.makeText(string)
      warmedUpTextView.attributedString = Self.makeText(string)
      let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
      textView.attributedString = Self.makeText(string)
      let equalText = Self.makeText(string)

      // when: counting the allocations of setting an equal text
      let allocations = AllocationCounter.count {
        textView.attributedString = equalText
      }

      // then: the text is compared with the text that the text view was set to, since the text view's own set isn't an
      // edit, instead of with a copy of the text that has the substitute fonts, and a right-to-left text isn't copied
      // to give it its writing direction again
      expect(allocations, string) == 0
    }
  }

  func test_init_laysOutWithTextKit1() {
    // when: making a text view
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))

    // then: it lays out its text with TextKit 1, as ComposeUI measures text. the TextKit 2 layout manager is checked
    // first, since asking a TextKit 2 text view for its TextKit 1 layout manager switches it to TextKit 1
    #if canImport(AppKit)
    if #available(macOS 12.0, *) {
      expect(textView.textLayoutManager) == nil
    }
    expect(textView.layoutManager?.textStorage) === textView.textStorage
    #endif
    #if canImport(UIKit)
    if #available(iOS 16.0, tvOS 16.0, *) {
      expect(textView.textLayoutManager) == nil
    }
    expect(textView.layoutManager.textStorage) === textView.textStorage
    #endif
  }

  func test_layout_indentedText_fitsTheMeasuredSize() throws {
    let indents: [(String, firstLineHeadIndent: CGFloat, headIndent: CGFloat, tailIndent: CGFloat)] = [
      ("first line indent", 30, 0, 0),
      ("head indent", 20, 20, 0),
      ("hanging indent", 0, 20, 0),
      ("tail indent", 0, 0, -20),
      ("tail indent from the leading edge", 0, 0, 140),
      ("all indents", 10, 30, -15),
    ]
    let strings = [
      "A paragraph that wraps across several lines in a narrow text view.",
      "مرحبا بالعالم، هذا نص عربي طويل يلتف عبر عدة أسطر",
    ]
    for (name, firstLineHeadIndent, headIndent, tailIndent) in indents {
      for string in strings {
        for (numberOfLines, lineBreakMode) in [(0, .byWordWrapping), (2, .byTruncatingTail)] as [(Int, NSLineBreakMode)] {
          // given: an indented paragraph in a number of lines with a line break mode, laid out in a text view 160 points
          // wide and measured for that width
          let scenario = "\(name), \(string.prefix(8)), \(numberOfLines) lines"
          let style = NSMutableParagraphStyle()
          style.firstLineHeadIndent = firstLineHeadIndent
          style.headIndent = headIndent
          style.tailIndent = tailIndent
          let text = NSAttributedString(string: string, attributes: [.font: Font.systemFont(ofSize: 13), .paragraphStyle: style])
          let makeTextView = { (size: CGSize) -> BaseTextView in
            let textView = BaseTextView(frame: CGRect(origin: .zero, size: size))
            textView.numberOfLines = numberOfLines
            textView.lineBreakMode = lineBreakMode
            textView.attributedString = text
            return textView
          }
          let proposedLineRects = try Self.lineRects(of: makeTextView(CGSize(width: 160, height: 1000)))
          let measuredSize = text.computeBoundingRectSize(numberOfLines: numberOfLines, layoutWidth: 160, lineBreakMode: lineBreakMode)

          // when: showing the text in a text view of the measured size rounded up to whole points, as `TextNode` sizes it
          let size = measuredSize.roundedUp(scaleFactor: 1)
          let lineRects = try Self.lineRects(of: makeTextView(size))

          // then: the text view lays out the lines that it lays out 160 points wide, wrapped and truncated alike, within
          // its bounds, since the measured width has room for each line's indents
          expect(lineRects.map(\.width), scenario) == proposedLineRects.map(\.width)
          expect(lineRects.allSatisfy { $0.minX >= 0 && $0.maxX <= size.width }, scenario) == true
        }
      }
    }
  }

  func test_attributedString_rightToLeftText_alignsItsLinesToTheRight() throws {
    // given: a text view 160 points wide
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 160, height: 100))

    // when: setting a right-to-left text without a writing direction, which wraps to two lines
    textView.attributedString = Self.makeText("مرحبا بالعالم، هذا نص عربي طويل")

    // then: the wrapped line ends at the right edge, as the text's direction aligns it, instead of starting at the left
    // edge, as TextKit 1 aligns it for a left-to-right user language
    let lineRects = try Self.lineRects(of: textView)
    expect(lineRects.count) == 2
    expect(lineRects[1].maxX).to(beApproximatelyEqual(to: 160, within: 0.5))
    expect(lineRects[1].minX) > 10
  }

  func test_layout_oneLineWithParagraphSettingsAndAttachments_fitsTheMeasuredSize() throws {
    let font = Font.systemFont(ofSize: 13)
    let makeText = { (configure: (NSMutableParagraphStyle) -> Void) -> NSAttributedString in
      let style = NSMutableParagraphStyle()
      configure(style)
      return NSAttributedString(string: "Hello world", attributes: [.font: font, .paragraphStyle: style])
    }
    let attachment = NSTextAttachment()
    attachment.bounds = CGRect(x: 0, y: 0, width: 20, height: 20)
    let attachmentText = NSMutableAttributedString(string: "Hello ", attributes: [.font: font])
    attachmentText.append(NSAttributedString(attachment: attachment))
    let texts: [(String, NSAttributedString)] = [
      ("line height multiple", makeText { $0.lineHeightMultiple = 1.5 }),
      ("minimum line height", makeText { $0.minimumLineHeight = 30 }),
      ("maximum line height", makeText { $0.maximumLineHeight = 10 }),
      ("first line indent", makeText { $0.firstLineHeadIndent = 20 }),
      ("tail indent", makeText { $0.tailIndent = -10 }),
      ("baseline offset", NSAttributedString(string: "Hello world", attributes: [.font: font, .baselineOffset: 5])),
      ("attachment", attachmentText),
      ("no font", NSAttributedString(string: "Hello world")),
    ]
    for (name, text) in texts {
      // given: the text measured in one line, and laid out in a wide one-line text view
      let makeTextView = { (size: CGSize) -> BaseTextView in
        let textView = BaseTextView(frame: CGRect(origin: .zero, size: size))
        textView.numberOfLines = 1
        textView.lineBreakMode = .byTruncatingTail
        textView.attributedString = text
        return textView
      }
      let measuredSize = text.computeBoundingRectSize(numberOfLines: 1, layoutWidth: 160)
      let wideLineRects = try Self.lineRects(of: makeTextView(CGSize(width: 1000, height: 1000)))

      // when: showing the text in a one-line text view of the measured size rounded up to whole points, as `TextNode`
      // sizes it
      let size = measuredSize.roundedUp(scaleFactor: 1)
      let lineRects = try Self.lineRects(of: makeTextView(size))

      // then: the text view lays out the line that it lays out when wide, without truncating it, in the measured height,
      // since the line is measured with the settings and attachments that the text view lays it out with
      expect(lineRects.map(\.width), name) == wideLineRects.map(\.width)
      let usedRect = lineRects.reduce(CGRect.null) { $0.union($1) }
      expect(usedRect.height, name).to(beApproximatelyEqual(to: measuredSize.height, within: 0.01))
    }
  }

  #if canImport(AppKit) || canImport(UIKit) && !os(tvOS)
  func test_attributedString_editable_showsTheTextAsSet() throws {
    // given: an editable text view
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.isEditable = true

    // when: setting a right-to-left text without a writing direction
    textView.attributedString = Self.makeText("مرحبا بالعالم")

    // then: the text storage shows the text without a writing direction, so that it aligns by the same rule as the
    // paragraphs that the user types
    let textStorage = try Self.textStorage(of: textView).unwrap()
    let style = { textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle }
    expect(style()?.baseWritingDirection ?? .natural) == .natural

    // when: the user edits the text, and the text is set again
    textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "x")
    textView.attributedString = Self.makeText("مرحبا بالعالم")

    // then: the text storage shows the text again, still without a writing direction
    expect(textStorage.string) == "مرحبا بالعالم"
    expect(style()?.baseWritingDirection ?? .natural) == .natural
  }

  func test_attributedString_equalTextAfterAnEditableChange_showsTheTextForTheNewSetting() throws {
    let text = Self.makeText("مرحبا بالعالم")
    let resolvedStyle = text.resolvingNaturalWritingDirections().attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
    let resolvedDirection = resolvedStyle?.baseWritingDirection ?? .natural
    for (isEditable, isEdited) in [(false, false), (true, false), (false, true)] {
      // given: a text view, editable or not, showing a right-to-left text without a writing direction, and edited after
      // the text is set or not
      let scenario = "editable: \(isEditable), edited: \(isEdited)"
      let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
      textView.isEditable = isEditable
      textView.attributedString = text
      let textStorage = try Self.textStorage(of: textView).unwrap()
      if isEdited {
        textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "x")
      }
      let direction = { (textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.baseWritingDirection ?? .natural }

      // when: the text view's editable setting changes, and the text view is set to the same text
      textView.isEditable = !isEditable
      textView.attributedString = text

      // then: the text storage shows the text for the new setting, without its direction when editable and in its
      // direction when not
      expect(direction(), scenario) == (isEditable ? resolvedDirection : .natural)

      // when: the setting changes back, and the text view is set to the same text
      textView.isEditable = isEditable
      textView.attributedString = text

      // then: the text storage shows the text for the setting again
      expect(direction(), scenario) == (isEditable ? .natural : resolvedDirection)
    }
  }

  func test_layout_editableRightToLeftText_fitsTheMeasuredSize() throws {
    let text = Self.makeText("مرحبا بالعالم، هذا نص عربي طويل يلتف عبر عدة أسطر!")
    for (numberOfLines, lineBreakMode) in [(0, .byWordWrapping), (2, .byTruncatingTail), (1, .byTruncatingTail)] as [(Int, NSLineBreakMode)] {
      // given: a right-to-left text without a writing direction, measured in its direction for 160 points wide
      let scenario = "\(numberOfLines) lines"
      let measuredSize = text.computeBoundingRectSize(numberOfLines: numberOfLines, layoutWidth: 160, lineBreakMode: lineBreakMode)
      let size = measuredSize.roundedUp(scaleFactor: 1)
      let makeTextView = { (isEditable: Bool) -> BaseTextView in
        let textView = BaseTextView(frame: CGRect(origin: .zero, size: size))
        textView.isEditable = isEditable
        textView.numberOfLines = numberOfLines
        textView.lineBreakMode = lineBreakMode
        textView.attributedString = text
        return textView
      }

      // when: showing the text in an editable text view of the measured size, which shows it without its direction, and
      // in one that isn't editable
      let editableLineRects = try Self.lineRects(of: makeTextView(true))
      let lineRects = try Self.lineRects(of: makeTextView(false))

      // then: the editable text view lays out as many lines, each within the other's, within its bounds and the measured
      // height, since TextKit 1 orders a paragraph without a direction by its text, which leaves its line breaks as they
      // are and changes only its alignment
      expect(editableLineRects.count, scenario) == lineRects.count
      expect(zip(editableLineRects, lineRects).allSatisfy { $0.width <= $1.width }, scenario) == true
      expect(editableLineRects.allSatisfy { $0.minX >= 0 && $0.maxX <= size.width }, scenario) == true
      let usedRect = editableLineRects.reduce(CGRect.null) { $0.union($1) }
      expect(usedRect.height, scenario).to(beApproximatelyEqual(to: measuredSize.height, within: 0.01))
    }
  }
  #endif

  func test_attributedString_rightToLeftText_keepsTheTextAsSet() throws {
    // given: a text view, and a right-to-left text without a writing direction
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    let text = Self.makeText("مرحبا بالعالم")

    // when: setting the text
    textView.attributedString = text

    // then: the text view returns the text as set, and shows it with the text's writing direction
    expect(textView.attributedString) === text
    let textStorage = try Self.textStorage(of: textView).unwrap()
    expect(textStorage.string) == text.string
    let shownStyle = textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
    expect(shownStyle) == text.resolvingNaturalWritingDirections().attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
  }

  #if canImport(AppKit)
  func test_attributedString_equalText_leavesTheIntrinsicSize() {
    // given: a text view showing a text, with its intrinsic size invalidations counted from then
    let textView = CountingTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = Self.makeText("Hello, world!")
    textView.intrinsicSizeInvalidationCount = 0

    // when: setting an equal text, made anew
    textView.attributedString = Self.makeText("Hello, world!")

    // then: the intrinsic size, which is computed from the text, isn't invalidated
    expect(textView.intrinsicSizeInvalidationCount) == 0

    // when: setting another text
    textView.attributedString = Self.makeText("Goodbye")

    // then: the intrinsic size is invalidated
    expect(textView.intrinsicSizeInvalidationCount) == 1
  }

  func test_textContainerInset_fitsTheTextContainerInTheInset() {
    // given: a text view 200 points wide
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))

    // when: setting a horizontal inset
    textView.textContainerInset = CGSize(width: 30, height: 0)

    // then: the text container fits in the inset right away, which the text view itself doesn't do, since it only moves
    // the text container by the inset
    expect(textView.textContainer?.size.width) == 140
  }

  func test_setFrameSize_fitsTheTextContainerInTheBounds() {
    for (height, expectedHeight) in [(50, 50), (0, CGFloat.greatestFiniteMagnitude)] as [(CGFloat, CGFloat)] {
      // given: a text view with a horizontal inset
      let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
      textView.textContainerInset = CGSize(width: 10, height: 0)

      // when: resizing it
      textView.setFrameSize(CGSize(width: 120, height: height))

      // then: the text container fits in the new bounds inside the inset right away, instead of in the layout that the
      // change asks for, which a text view without a window doesn't get, with no height limit for a zero height
      expect(textView.textContainer?.size, "height \(height)") == CGSize(width: 100, height: expectedHeight)
      expect(textView.window) == nil
    }
  }

  func test_attributedString_userEditedTextSetBack_leavesTheTextStorageAndInvalidatesTheIntrinsicSize() throws {
    // given: a text view showing a model's mutable text, which the user then edited, with part of it selected, and an
    // observer of the text storage's edits
    let textView = CountingTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
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
    expect(editCount) == 0
    expect(textView.selectedRange) == NSRange(location: 0, length: 5)
    expect(textView.intrinsicSizeInvalidationCount) == 1
  }

  func test_textAndLayoutSettings_applyWithoutLayingOutTheTextView() throws {
    // given: a text view 160 points wide showing a text
    let textView = CountingTextView(frame: CGRect(x: 0, y: 0, width: 160, height: 200))
    textView.attributedString = Self.makeText("Hello")

    // when: setting a text that wraps, a number of lines and a line break mode, as a refresh does, and running the
    // blocks scheduled on the main run loop
    textView.attributedString = Self.makeText("A paragraph that wraps across several lines in a narrow text view.")
    textView.numberOfLines = 2
    textView.lineBreakMode = .byTruncatingTail
    runScheduledBlocks()

    // then: the text is laid out in 2 lines without a layout of the text view, since TextKit 1 lays out the text again
    // for each of the changes
    expect(textView.layoutCount) == 0
    expect(try Self.lineRects(of: textView).count) == 2
    expect(textView.textContainer?.lineBreakMode) == .byTruncatingTail
  }

  func test_superviewChanges_leaveNoRegistrationForEveryViewsFrameChanges() {
    // given: a text view in a superview without a window, and a view elsewhere
    let textView = FrameChangeCountingTextView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
    let container = NSView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    container.addSubview(textView)
    let otherView = NSView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))

    // when: the other view's frame changes
    var count = textView.everyFrameChangeCount
    otherView.frame.size.width += 1

    // then: the text view is told, since AppKit registered it for the frame changes of every view, with no later call to
    // remove it from without a window
    expect(textView.everyFrameChangeCount - count) == 1

    // when: the text view moves out of its superview without a window, which AppKit registers it again for, and the other
    // view's frame changes
    textView.removeFromSuperview()
    count = textView.everyFrameChangeCount
    otherView.frame.size.width += 1

    // then: the text view isn't told
    expect(textView.everyFrameChangeCount - count) == 0

    // when: the text view moves into the superview and out without needing display, as it moves out when it deallocates,
    // and the other view's frame changes
    container.addSubview(textView)
    textView.removeFromSuperviewWithoutNeedingDisplay()
    count = textView.everyFrameChangeCount
    otherView.frame.size.width += 1

    // then: the text view isn't told
    expect(textView.everyFrameChangeCount - count) == 0

    // when: the text view moves into the superview, the superview moves into a window, and the other view's frame changes
    container.addSubview(textView)
    let window = TestWindow()
    window.contentView = container
    count = textView.everyFrameChangeCount
    otherView.frame.size.width += 1

    // then: the text view isn't told
    expect(textView.everyFrameChangeCount - count) == 0

    // when: the text view moves out of its superview in the window, and the other view's frame changes
    textView.removeFromSuperview()
    count = textView.everyFrameChangeCount
    otherView.frame.size.width += 1

    // then: the text view isn't told
    expect(textView.everyFrameChangeCount - count) == 0
  }

  func test_documentViewOfAScrollView_keepsTheRegistrationForTheClipViewsFrameChanges() {
    // given: a text view as the document view of a scroll view in a window
    let textView = FrameChangeCountingTextView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    let scrollView = NSScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.documentView = textView
    let window = TestWindow()
    window.contentView?.addSubview(scrollView)

    // when: the scroll view resizes its clip view
    let count = textView.clipViewFrameChangeCount
    scrollView.setFrameSize(CGSize(width: 120, height: 100))

    // then: the text view is told of its clip view's frame change, which AppKit registers it for under a clip view
    expect(textView.clipViewFrameChangeCount - count) > 0
  }

  func test_layout_fitsTheMeasuredSize() throws {
    let mixedFonts = NSMutableAttributedString(attributedString: Self.makeText("Regular text, then "))
    mixedFonts.append(NSAttributedString(string: "bold text that wraps", attributes: [.font: Font.boldSystemFont(ofSize: 17)]))
    let characterWrapping = NSMutableAttributedString(attributedString: Self.makeText("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor."))
    let characterWrappingStyle = NSMutableParagraphStyle()
    characterWrappingStyle.lineBreakMode = .byCharWrapping
    characterWrapping.addAttribute(.paragraphStyle, value: characterWrappingStyle, range: NSRange(location: 0, length: characterWrapping.length))
    let texts: [(String, NSAttributedString)] = [
      ("Latin", Self.makeText("A paragraph that wraps across several lines in a narrow text view.")),
      ("Devanagari", Self.makeText("नमस्ते दुनिया, यह एक लंबा वाक्य है जो कई पंक्तियों में आता है")),
      ("Arabic", Self.makeText("مرحبا بالعالم، هذا نص عربي طويل يلتف عبر عدة أسطر")),
      ("CJK", Self.makeText("你好，世界。这是一个很长的句子，用来测试换行。")),
      ("emoji", Self.makeText("Hello 😀👍🏽 world 🎉, with emoji in a line that wraps")),
      ("mixed fonts", mixedFonts),
      ("character wrapping", characterWrapping),
      ("both directions", Self.makeText("A first paragraph\nمرحبا بالعالم، هذا نص عربي\nA third paragraph")),
    ]
    for (name, text) in texts {
      for (numberOfLines, lineBreakMode) in [(0, .byWordWrapping), (2, .byTruncatingTail), (1, .byTruncatingTail)] as [(Int, NSLineBreakMode)] {
        // given: the text measured for 160 points wide, in a number of lines with a line break mode
        let scenario = "\(name), \(numberOfLines) lines"
        let measuredSize = text.computeBoundingRectSize(numberOfLines: numberOfLines, layoutWidth: 160, lineBreakMode: lineBreakMode)

        // when: showing the text in a text view of the measured size rounded up to whole points, as `TextNode` sizes it
        let size = measuredSize.roundedUp(scaleFactor: 1)
        let textView = BaseTextView(frame: CGRect(origin: .zero, size: size))
        textView.numberOfLines = numberOfLines
        textView.lineBreakMode = lineBreakMode
        textView.attributedString = text

        // then: the text view lays out the text in the measured width and height, with each line within its bounds, in
        // one line as in more
        let layoutManager = try textView.layoutManager.unwrap()
        let textContainer = try textView.textContainer.unwrap()
        layoutManager.ensureLayout(for: textContainer)
        let lineRects = try Self.lineRects(of: textView)
        expect(lineRects.map(\.width).max(), scenario) == measuredSize.width
        expect(layoutManager.usedRect(for: textContainer).height, scenario) == measuredSize.height
        expect(lineRects.allSatisfy { $0.minX >= 0 && $0.maxX <= size.width }, scenario) == true
      }
    }
  }

  func test_attributedString_undoAllowed_newText_removesTheUndoActions() throws {
    // given: a text view that allows undo, which the user typed into
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try window.undoManager.unwrap()
    expect(undoManager.canUndo) == true

    // when: showing another text
    textView.attributedString = NSAttributedString(string: "Hi")

    // then: the text is shown, and the undo actions are gone
    expect(textView.string) == "Hi"
    expect(undoManager.canUndo) == false
  }

  func test_attributedString_undoAllowed_newText_keepsTheUndoActionsOfOtherViews() throws {
    // given: a text view that allows undo, which the user typed into, and an undo action of another view in its window
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try window.undoManager.unwrap()
    let otherView = NSView()
    var isOtherActionUndone = false
    undoManager.registerUndo(withTarget: otherView) { _ in
      isOtherActionUndone = true
    }
    RunLoop.main.run(until: Date())

    // when: showing another text
    textView.attributedString = NSAttributedString(string: "Hi")

    // then: the other view's undo action stays
    expect(undoManager.canUndo) == true

    // when: undoing
    undoManager.undo()

    // then: the other view's action is undone, the text stays, and nothing is left to undo
    expect(isOtherActionUndone) == true
    expect(textView.string) == "Hi"
    expect(undoManager.canUndo) == false
  }

  func test_attributedString_undoAllowed_newTextInTheTypingsPass_undoLeavesTheText() throws {
    // given: a text view that allows undo, which the user typed into, in a pass of the run loop that hasn't ended
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more", endsPass: false)
    let undoManager = try window.undoManager.unwrap()

    // when: showing a longer text in the same pass, as an app that refreshes on each edit does, then undoing after the
    // pass ends
    textView.attributedString = NSAttributedString(string: "A completely different and much longer text")
    RunLoop.main.run(until: Date())
    undoManager.undo()

    // then: the text stays, since the typing's undo actions are gone
    expect(textView.string) == "A completely different and much longer text"
  }

  func test_attributedString_undoAllowed_sameCharactersInOtherAttributes_keepsTheUndoActions() throws {
    // given: a text view that allows undo, which the user typed into
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world")
    let undoManager = try window.undoManager.unwrap()

    // when: showing the same characters in another color
    textView.attributedString = NSAttributedString(string: "Hello, world", attributes: [.foregroundColor: NSColor.red])

    // then: the user can still undo the typing
    expect(undoManager.canUndo) == true
    undoManager.undo()
    expect(textView.string) == "Hello"
  }

  func test_attributedString_undoAllowedThenNotEditable_newText_removesTheUndoActions() throws {
    // given: a text view that the user typed into while it allowed undo, which isn't editable anymore
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try window.undoManager.unwrap()
    textView.isEditable = false

    // when: showing another text
    textView.attributedString = NSAttributedString(string: "Hi")

    // then: the undo actions are gone
    expect(undoManager.canUndo) == false
  }

  func test_attributedString_undoAllowedThenNotAllowed_newText_removesTheUndoActions() throws {
    // given: a text view that the user typed into while it allowed undo, which doesn't allow undo anymore
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try window.undoManager.unwrap()
    textView.allowsUndo = false

    // when: showing another text
    textView.attributedString = NSAttributedString(string: "Hi")

    // then: the undo actions are gone
    expect(undoManager.canUndo) == false
  }

  func test_attributedString_undoManagerOfTheDelegateChanged_newText_removesTheUndoActionsFromThePreviousOne() {
    // given: a text view that allows undo, which the user typed into, whose delegate gives another undo manager since
    let delegate = UndoManagerProvidingDelegate()
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more", delegate: delegate)
    let previousUndoManager = delegate.undoManager
    delegate.undoManager = UndoManager()

    // when: showing another text
    textView.attributedString = NSAttributedString(string: "Hi")

    // then: the undo actions are gone from the undo manager that recorded them
    expect(previousUndoManager.canUndo) == false
    withExtendedLifetime(window) {}
  }

  func test_attributedString_undoAllowed_newText_removesTheUndoActionsBeforeTheTextChanges() throws {
    // given: a text view that allows undo, which the user typed into, and an observer of its text storage's edits
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try window.undoManager.unwrap()
    var canUndoDuringTheEdit: Bool?
    let observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: textView.textStorage, queue: nil) { _ in
      canUndoDuringTheEdit = undoManager.canUndo
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
    }

    // when: showing another text
    textView.attributedString = NSAttributedString(string: "Hi")

    // then: the undo actions were gone when the text storage told its observers of the edit
    expect(canUndoDuringTheEdit) == false
  }

  func test_attributedString_undoAllowed_undoRegistrationDisabledTwice_newText_keepsBothDisables() throws {
    // given: a text view that allows undo, which the user typed into, whose undo registration the app disabled twice
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try window.undoManager.unwrap()
    undoManager.disableUndoRegistration()
    undoManager.disableUndoRegistration()

    // when: showing another text
    textView.attributedString = NSAttributedString(string: "Hi")

    // then: the undo actions are gone, and registration stays disabled
    expect(undoManager.canUndo) == false
    expect(undoManager.isUndoRegistrationEnabled) == false

    // when: the app enables registration once
    undoManager.enableUndoRegistration()

    // then: registration stays disabled
    expect(undoManager.isUndoRegistrationEnabled) == false

    // when: the app enables registration again
    undoManager.enableUndoRegistration()

    // then: registration is enabled
    expect(undoManager.isUndoRegistrationEnabled) == true
  }

  func test_attributedString_undoAllowed_newTextInTheAppsUndoGroup_removesTheUndoActions() throws {
    // given: a text view that allows undo, which the user typed into
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try window.undoManager.unwrap()

    // when: the app shows a longer text in an undo group of its own, then undoing after the pass of the run loop ends
    undoManager.beginUndoGrouping()
    textView.attributedString = NSAttributedString(string: "A completely different and much longer text")
    undoManager.endUndoGrouping()
    RunLoop.main.run(until: Date())
    undoManager.undo()

    // then: the text stays, since the typing's undo actions are gone
    expect(textView.string) == "A completely different and much longer text"
  }

  func test_attributedString_undoAllowed_newTextDuringUndo_removesTheUndoActions() throws {
    // given: a text view that allows undo, which the user typed into, and an app's undo action that shows a longer text
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try window.undoManager.unwrap()
    undoManager.registerUndo(withTarget: textView) { textView in
      textView.attributedString = NSAttributedString(string: "A completely different and much longer text")
    }
    RunLoop.main.run(until: Date())

    // when: undoing the app's action, then undoing again in the next pass of the run loop
    undoManager.undo()
    RunLoop.main.run(until: Date())
    undoManager.undo()

    // then: the text stays, since the typing's undo actions are gone
    expect(textView.string) == "A completely different and much longer text"
  }

  func test_undoNotAllowed_userEditNewTextResetAndWindowExit_leaveTheUndoManagerAlone() {
    // given: an editable text view that doesn't allow undo, in a window that counts the reads of its undo manager
    let window = UndoManagerReadCountingWindow()
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 300, height: 60))
    textView.isEditable = true
    window.contentView?.addSubview(textView)
    textView.attributedString = NSAttributedString(string: "Hello")
    window.makeFirstResponder(textView)
    window.undoManagerReadCount = 0

    // when: the user types, then showing another text, resetting the text view for a text node, and removing it from
    // the window
    textView.insertText(", world", replacementRange: NSRange(location: NSNotFound, length: 0))
    textView.attributedString = NSAttributedString(string: "Hi")
    textView.resetForReuse(keepsTextNodeSettings: true)
    textView.removeFromSuperview()

    // then: the text view doesn't read the undo manager, which the window would make for it
    expect(window.undoManagerReadCount) == 0
  }
  #endif

  #if canImport(UIKit)
  func test_init_givenTextKit1Container_leavesAnEqualTextWithSubstituteFontsInPlace() throws {
    // given: a text view of a given TextKit 1 text container, showing a text with characters that its font doesn't have,
    // and an observer of the text storage's edits
    let textStorage = NSTextStorage()
    let layoutManager = NSLayoutManager()
    textStorage.addLayoutManager(layoutManager)
    let textContainer = NSTextContainer(size: CGSize(width: 200, height: 50))
    layoutManager.addTextContainer(textContainer)
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50), textContainer: textContainer)
    textView.attributedString = Self.makeText("你好，世界")
    var editCount = 0
    let observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: textStorage, queue: nil) { _ in
      editCount += 1
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
    }

    // when: setting an equal text, made anew
    textView.attributedString = Self.makeText("你好，世界")

    // then: the text view uses the given text system, whose text storage isn't edited
    expect(textView.textStorage) === textStorage
    expect(editCount) == 0
  }

  func test_init_givenTextKit1ContainerWithText_showsTheFirstTextSet() throws {
    // given: a text view of a given TextKit 1 text container, whose text storage has a text
    let textStorage = NSTextStorage(string: "Existing text")
    let layoutManager = NSLayoutManager()
    textStorage.addLayoutManager(layoutManager)
    let textContainer = NSTextContainer(size: CGSize(width: 200, height: 50))
    layoutManager.addTextContainer(textContainer)
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50), textContainer: textContainer)

    // when: setting an empty text, equal to the text that the text view starts with
    textView.attributedString = NSAttributedString()

    // then: the text storage shows the empty text instead of its own
    expect(textStorage.length) == 0
  }

  func test_init_givenTextKit2Container_showsTheText() throws {
    guard #available(iOS 16.0, tvOS 16.0, *) else {
      throw XCTSkip("text views use TextKit 2 from iOS 16 and tvOS 16")
    }

    // given: a text view of a given TextKit 2 text container
    let textContainer = NSTextContainer(size: CGSize(width: 200, height: 50))
    let textLayoutManager = NSTextLayoutManager()
    textLayoutManager.textContainer = textContainer
    let textContentStorage = NSTextContentStorage()
    textContentStorage.addTextLayoutManager(textLayoutManager)
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50), textContainer: textContainer)

    // when: setting a text
    textView.attributedString = Self.makeText("Hello, world!")

    // then: the text view shows it with the given TextKit 2 text system
    expect(textView.textLayoutManager) === textLayoutManager
    expect(textView.attributedText.string) == "Hello, world!"
  }

  func test_layout_fitsTheMeasuredSize() throws {
    let font = Font.systemFont(ofSize: 13)
    let mixedFonts = NSMutableAttributedString(string: "Regular text, then ", attributes: [.font: font])
    mixedFonts.append(NSAttributedString(string: "नमस्ते bold text", attributes: [.font: Font.boldSystemFont(ofSize: 17)]))
    let texts: [(String, NSAttributedString)] = [
      ("Latin", NSAttributedString(string: "A paragraph that wraps across several lines in a narrow view.", attributes: [.font: font])),
      ("Devanagari", NSAttributedString(string: "नमस्ते दुनिया, यह एक लंबा वाक्य है जो कई पंक्तियों में आता है", attributes: [.font: font])),
      ("Arabic", NSAttributedString(string: "مرحبا بالعالم، هذا نص عربي طويل يلتف عبر عدة أسطر", attributes: [.font: font])),
      ("Thai", NSAttributedString(string: "สวัสดีชาวโลก นี่คือประโยคภาษาไทยที่ยาวมาก", attributes: [.font: font])),
      ("CJK", NSAttributedString(string: "你好，世界。这是一个很长的句子，用来测试换行。", attributes: [.font: font])),
      ("emoji", NSAttributedString(string: "Hello 😀👍🏽 world 🎉, with emoji in a line that wraps", attributes: [.font: font])),
      ("mixed fonts", mixedFonts),
      ("no font", NSAttributedString(string: "नमस्ते दुनिया, यह एक लंबा वाक्य है")),
      ("both directions", NSAttributedString(string: "A first paragraph\nمرحبا بالعالم، هذا نص عربي\nनमस्ते दुनिया", attributes: [.font: font])),
    ]
    for (name, text) in texts {
      for (numberOfLines, lineBreakMode) in [(0, .byWordWrapping), (2, .byTruncatingTail), (1, .byTruncatingTail)] as [(Int, NSLineBreakMode)] {
        // given: the text measured for 160 points wide, in a number of lines with a line break mode
        let scenario = "\(name), \(numberOfLines) lines"
        let measuredSize = text.computeBoundingRectSize(numberOfLines: numberOfLines, layoutWidth: 160, lineBreakMode: lineBreakMode)

        // when: showing the text in a text view of the measured size rounded up to whole points, as `TextNode` sizes it
        let size = measuredSize.roundedUp(scaleFactor: 1)
        let textView = BaseTextView(frame: CGRect(origin: .zero, size: size))
        textView.numberOfLines = numberOfLines
        textView.lineBreakMode = lineBreakMode
        textView.attributedString = text

        // then: the text view lays out the text in the measured height, within its bounds, since the text is measured with
        // the line heights of the fonts that the text view records for the characters it gives substitute fonts, in one
        // line as in more
        let usedSize = Self.usedSize(of: textView)
        expect(usedSize.height, scenario).to(beApproximatelyEqual(to: measuredSize.height, within: 0.01))
        expect(usedSize.width <= size.width, scenario) == true
      }
    }
  }

  /// Returns the size that the text view lays out its text in.
  private static func usedSize(of textView: BaseTextView) -> CGSize {
    // the TextKit 2 layout manager is read first, since asking a TextKit 2 text view for its TextKit 1 layout manager
    // switches it to TextKit 1
    if #available(iOS 16.0, tvOS 16.0, *), let textLayoutManager = textView.textLayoutManager {
      textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)
      return textLayoutManager.usageBoundsForTextContainer.size
    } else {
      textView.layoutManager.ensureLayout(for: textView.textContainer)
      return textView.layoutManager.usedRect(for: textView.textContainer).size
    }
  }
  #endif

  #if canImport(UIKit)
  func test_attributedString_notEditable_emptyText_tellsTheDelegateThatTheSelectionMoved() {
    // given: a text view that isn't editable, showing a text with the selection at its end, and a delegate that counts
    // the selection changes
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")
    expect(textView.selectedRange) == NSRange(location: 13, length: 0)
    let counter = SelectionChangeCounter()
    textView.delegate = counter

    // when: setting an empty text
    textView.attributedString = NSAttributedString()

    // then: the text is gone, and the delegate is told that the selection moved to the start
    expect(textView.textStorage.length) == 0
    expect(textView.selectedRange) == NSRange(location: 0, length: 0)
    expect(counter.count) == 1
  }

  func test_attributedString_notEditable_showsTheTextWithItsFontColorAndAlignment() {
    // given: a selectable text view that isn't editable, showing a text, with a selection of some of it
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 300, height: 50))
    textView.isSelectable = true
    textView.attributedString = NSAttributedString(string: "Hello, world! How are you?")
    textView.selectedRange = NSRange(location: 5, length: 10)

    // when: showing a text with a font, a color and an alignment, which has room for the selection
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let font = UIFont.systemFont(ofSize: 21)
    textView.attributedString = NSAttributedString(string: "Goodbye, everyone! Have a nice day.", attributes: [.font: font, .foregroundColor: UIColor.red, .paragraphStyle: style])

    // then: the text view's font, text color and alignment are the text's, and the selection collapses to the end, as
    // `attributedText` sets them
    expect(textView.font) == font
    expect(textView.textColor) == .red
    expect(textView.textAlignment) == .center
    expect(textView.selectedRange) == NSRange(location: 35, length: 0)
  }

  #if !os(tvOS)
  func test_attributedString_newText_removesTheUndoActions() throws {
    // given: a typed text view, in the pass of the run loop whose undo group holds the typing
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try textView.undoManager.unwrap()

    // when: showing a shorter text in the same pass, as an app that refreshes on each edit does
    textView.attributedString = NSAttributedString(string: "Hi")

    // then: the text is shown, and the undo actions are gone
    expect(textView.textStorage.string) == "Hi"
    expect(undoManager.canUndo) == false

    // when: the user types again
    textView.insertText("!")

    // then: the user can undo the new typing
    expect(undoManager.canUndo) == true
    undoManager.undo()
    expect(textView.textStorage.string) == "Hi"
    withExtendedLifetime(window) {}
  }

  func test_attributedString_editedThenNotEditable_newText_removesTheUndoActions() {
    // given: a text view that the user typed into, which isn't editable anymore
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    textView.isEditable = false

    // when: showing a shorter text
    textView.attributedString = NSAttributedString(string: "Hi")

    // then: the undo actions are gone
    expect(textView.undoManager?.canUndo) == false
    withExtendedLifetime(window) {}
  }

  func test_attributedString_neverEditable_newText_leavesTheUndoActions() throws {
    // given: a text view that has never been editable, with an undo action that the app registered
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 300, height: 60))
    textView.attributedString = NSAttributedString(string: "Hello")
    let undoManager = try textView.undoManager.unwrap()
    let target = NSObject()
    undoManager.beginUndoGrouping()
    undoManager.registerUndo(withTarget: target) { _ in }
    undoManager.endUndoGrouping()
    expect(undoManager.canUndo) == true

    // when: showing another text
    textView.attributedString = NSAttributedString(string: "Hi")

    // then: the app's undo action stays
    expect(undoManager.canUndo) == true
  }

  func test_attributedString_textOfTheUsersEdit_keepsTheUndoActions() {
    // given: an editable text view that the user typed into
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world")

    // when: showing the text that the user's edit made
    textView.attributedString = NSAttributedString(attributedString: textView.textStorage)

    // then: the user can still undo the typing
    expect(textView.undoManager?.canUndo) == true
    textView.undoManager?.undo()
    expect(textView.textStorage.string) == "Hello"
    withExtendedLifetime(window) {}
  }

  func test_attributedString_sameCharactersInOtherAttributes_keepsTheUndoActions() {
    // given: an editable text view that the user typed into
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world")

    // when: showing the same characters in another color
    textView.attributedString = NSAttributedString(string: "Hello, world", attributes: [.foregroundColor: UIColor.red])

    // then: the user can still undo the typing
    expect(textView.undoManager?.canUndo) == true
    textView.undoManager?.undo()
    expect(textView.textStorage.string) == "Hello"
    withExtendedLifetime(window) {}
  }

  func test_attributedString_undoRegistrationDisabledTwice_newText_keepsBothDisables() throws {
    // given: a typed text view whose undo registration the app disabled twice
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try textView.undoManager.unwrap()
    undoManager.disableUndoRegistration()
    undoManager.disableUndoRegistration()

    // when: showing a shorter text
    textView.attributedString = NSAttributedString(string: "Hi")

    // then: the undo actions are gone, and registration stays disabled
    expect(undoManager.canUndo) == false
    expect(undoManager.isUndoRegistrationEnabled) == false

    // when: the app enables registration once
    undoManager.enableUndoRegistration()

    // then: registration stays disabled
    expect(undoManager.isUndoRegistrationEnabled) == false

    // when: the app enables registration again
    undoManager.enableUndoRegistration()

    // then: registration is enabled
    expect(undoManager.isUndoRegistrationEnabled) == true
    withExtendedLifetime(window) {}
  }

  func test_attributedString_newTextDuringUndo_assertsAndLeavesTheUndoActions() throws {
    // given: a typed text view after the typing's pass, an app's undo action that shows a shorter text, and an assertion
    // handler that records the messages
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try textView.undoManager.unwrap()
    RunLoop.main.run(until: Date())
    undoManager.registerUndo(withTarget: textView) { textView in
      textView.attributedString = NSAttributedString(string: "Hi")
    }
    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: undoing the app's action
    undoManager.undo()

    // then: the text view asserts, and leaves the typing's undo actions
    expect(textView.textStorage.string) == "Hi"
    expect(assertionMessages) == [Constants.undoOperationAssertionMessage]
    expect(undoManager.canUndo) == true
    withExtendedLifetime(window) {}
  }

  func test_attributedString_newTextDuringRedo_assertsAndLeavesTheUndoActions() throws {
    // given: a typed text view after the typing's pass, an app's undo action whose redo shows a shorter text, undone in
    // a pass that has ended, and an assertion handler that records the messages
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try textView.undoManager.unwrap()
    RunLoop.main.run(until: Date())
    undoManager.registerUndo(withTarget: textView) { textView in
      textView.undoManager?.registerUndo(withTarget: textView) { textView in
        textView.attributedString = NSAttributedString(string: "Hi")
      }
    }
    RunLoop.main.run(until: Date())
    undoManager.undo()
    RunLoop.main.run(until: Date())
    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: redoing
    undoManager.redo()

    // then: the text view asserts, and leaves the typing's undo actions
    expect(textView.textStorage.string) == "Hi"
    expect(assertionMessages) == [Constants.undoOperationAssertionMessage]
    expect(undoManager.canUndo) == true
    withExtendedLifetime(window) {}
  }

  func test_attributedString_newTextInTheAppsUndoGroup_assertsAndLeavesTheUndoActions() throws {
    // given: a typed text view after the typing's pass, and an assertion handler that records the messages
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try textView.undoManager.unwrap()
    RunLoop.main.run(until: Date())
    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: the app shows a shorter text in an undo group of its own
    undoManager.beginUndoGrouping()
    textView.attributedString = NSAttributedString(string: "Hi")
    undoManager.endUndoGrouping()

    // then: the group ends, and the text view asserts, and leaves the typing's undo actions
    expect(assertionMessages) == [Constants.undoOperationAssertionMessage]
    expect(undoManager.canUndo) == true
    withExtendedLifetime(window) {}
  }

  func test_attributedString_newTextInTheAppsUndoGroup_notGroupingByEvent_assertsAndLeavesTheUndoActions() throws {
    // given: a typed text view after the typing's pass, whose undo manager doesn't group by event, and an assertion
    // handler that records the messages
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try textView.undoManager.unwrap()
    RunLoop.main.run(until: Date())
    undoManager.groupsByEvent = false
    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: the app shows a shorter text in an undo group of its own, the only group open
    undoManager.beginUndoGrouping()
    textView.attributedString = NSAttributedString(string: "Hi")
    undoManager.endUndoGrouping()

    // then: the group ends, and the text view asserts, and leaves the typing's undo actions
    expect(assertionMessages) == [Constants.undoOperationAssertionMessage]
    expect(undoManager.canUndo) == true
    withExtendedLifetime(window) {}
  }

  func test_attributedString_textKit2_newText_removesTheUndoActions() throws {
    guard #available(iOS 15.0, *) else {
      throw XCTSkip("TextKit 2 text containers are available from iOS 15")
    }

    // given: a typed text view with a TextKit 2 text container
    let (textContainer, contentStorage) = Self.makeTextKit2TextContainer()
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more", textContainer: textContainer)

    // when: showing a shorter text
    textView.attributedString = NSAttributedString(string: "Hi")

    // then: the text is shown, and the undo actions are gone
    expect(textView.text) == "Hi"
    expect(textView.undoManager?.canUndo) == false
    withExtendedLifetime((window, contentStorage)) {}
  }

  func test_attributedString_textKit2_textOfTheUsersEdit_keepsTheUndoActions() throws {
    guard #available(iOS 15.0, *) else {
      throw XCTSkip("TextKit 2 text containers are available from iOS 15")
    }

    // given: a typed text view with a TextKit 2 text container
    let (textContainer, contentStorage) = Self.makeTextKit2TextContainer()
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world", textContainer: textContainer)

    // when: showing the text that the user's edit made
    textView.attributedString = NSAttributedString(attributedString: textView.attributedText)

    // then: the user can still undo the typing
    expect(textView.undoManager?.canUndo) == true
    textView.undoManager?.undo()
    expect(textView.text) == "Hello"
    withExtendedLifetime((window, contentStorage)) {}
  }
  #endif
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

  func test_resetForReuse_emptySelectionAtTheEnd_movesItToTheStart() {
    // given: a text view with a text, whose empty selection is at the end, where setting the text leaves it, and a
    // delegate that counts the selection changes
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")
    expect(textView.selectedRange) == NSRange(location: 13, length: 0)
    let counter = SelectionChangeCounter()
    textView.delegate = counter

    // when: reset for reuse
    textView.resetForReuse()

    // then: the reset moves the selection to the start, as in a new text view
    expect(counter.count) == 1
    expect(textView.selectedRange) == NSRange(location: 0, length: 0)
  }

  func test_resetForReuse_keepingTextNodeSettings_emptySelection_isNotMoved() {
    // given: a text view with a text, whose empty selection is at the end, where setting the text leaves it, and a
    // delegate that counts the selection changes
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")
    expect(textView.selectedRange) == NSRange(location: 13, length: 0)
    let counter = SelectionChangeCounter()
    textView.delegate = counter

    // when: resetting it for a reuse by a text node
    textView.resetForReuse(keepsTextNodeSettings: true)

    // then: the reset doesn't move the selection, which the text node's next text moves
    expect(counter.count) == 0
    expect(textView.selectedRange) == NSRange(location: 13, length: 0)
  }

  func test_resetForReuse_keepingTextNodeSettings_selectionOfSomeText_isRemoved() {
    // given: a text view with a text, a selection of some of it, and a delegate that counts the selection changes
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")
    #if canImport(AppKit)
    textView.setSelectedRange(NSRange(location: 0, length: 5))
    #endif
    #if canImport(UIKit)
    textView.selectedRange = NSRange(location: 0, length: 5)
    #endif
    let counter = SelectionChangeCounter()
    textView.delegate = counter

    // when: resetting it for a reuse by a text node
    textView.resetForReuse(keepsTextNodeSettings: true)

    // then: the reset moves the selection to the start, since the text view keeps its text, which a text node can leave
    // in place with the selection
    expect(textView.selectedRange) == NSRange(location: 0, length: 0)
    expect(counter.count) == 1
  }

  #if canImport(AppKit)
  func test_resetForReuse_keepingTextNodeSettings_emptySelectionWithOtherRanges_isRemoved() {
    // given: a text view with a text, an empty first selection and a selection of some text after it, which `selectedRange`
    // doesn't show
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")
    textView.setSelectedRanges([NSValue(range: NSRange(location: 2, length: 0)), NSValue(range: NSRange(location: 7, length: 5))], affinity: .downstream, stillSelecting: false)
    expect(textView.selectedRanges.map(\.rangeValue)) == [NSRange(location: 2, length: 0), NSRange(location: 7, length: 5)]

    // when: resetting it for a reuse by a text node
    textView.resetForReuse(keepsTextNodeSettings: true)

    // then: the selection is gone, since the text view keeps its text, which a text node can leave in place with the
    // selection
    expect(textView.selectedRanges.map(\.rangeValue)) == [NSRange(location: 0, length: 0)]
  }
  #endif

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

  func test_resetForReuse_releasesTheLastThemedText() {
    // given: a text view that keeps the last text a theme was applied to
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    weak var weakText: NSAttributedString?
    autoreleasepool {
      let text = NSAttributedString(string: "Hello, world!")
      weakText = text
      textView.lastThemedText = (text, .light, NSAttributedString(string: "Hello, world!"))
    }
    expect(weakText) != nil

    // when: reset for reuse
    textView.resetForReuse()

    // then: the text is released
    expect(weakText) == nil
  }

  func test_resetForReuse_keepingTextNodeSettings_keepsThem() {
    #if os(tvOS)
    let settings = [false]
    #else
    let settings = [true, false]
    #endif
    for isInteractive in settings {
      // given: a text view with a text, a number of lines, a line break mode, an inset, and the interaction settings of
      // an editable text view or of a text view that isn't interactive, which aren't the defaults
      let scenario = "interactive \(isInteractive)"
      let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
      textView.attributedString = NSAttributedString(string: "Hello, world!")
      textView.numberOfLines = 2
      textView.lineBreakMode = .byTruncatingTail
      #if canImport(AppKit)
      textView.textContainerInset = CGSize(width: 4, height: 2)
      #endif
      #if canImport(UIKit)
      textView.textContainerInset = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
      #endif
      #if !os(tvOS)
      textView.isEditable = isInteractive
      #endif
      textView.isSelectable = isInteractive
      #if canImport(AppKit)
      textView.ignoreHitTest = !isInteractive
      #endif
      #if canImport(UIKit)
      textView.isUserInteractionEnabled = isInteractive
      #endif

      // when: resetting it for a reuse by a text node
      textView.resetForReuse(keepsTextNodeSettings: true)

      // then: the settings that a text node sets on each reuse stay
      #if !os(tvOS)
      expect(textView.isEditable, scenario) == isInteractive
      #endif
      expect(textView.isSelectable, scenario) == isInteractive
      #if canImport(AppKit)
      expect(textView.ignoreHitTest, scenario) == !isInteractive
      expect(textView.textContainerInset, scenario) == CGSize(width: 4, height: 2)
      #endif
      #if canImport(UIKit)
      expect(textView.isUserInteractionEnabled, scenario) == isInteractive
      expect(textView.textContainerInset, scenario) == UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
      #endif
      expect(textView.numberOfLines, scenario) == 2
      expect(textView.lineBreakMode, scenario) == .byTruncatingTail
    }
  }

  func test_resetForReuse_keepingTextNodeSettings_keepsTheTextUntilTheEndOfTheRunLoopTurn() {
    #if os(tvOS)
    let editableStates = [false]
    #else
    let editableStates = [true, false]
    #endif
    for isEditable in editableStates {
      // given: a text view, editable or not, with a text whose attribute holds an object
      let scenario = "editable \(isEditable)"
      let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
      #if !os(tvOS)
      textView.isEditable = isEditable
      #endif
      weak var weakObject: NSObject?
      autoreleasepool {
        let object = NSObject()
        weakObject = object
        textView.attributedString = NSAttributedString(string: "Hello, world!", attributes: [NSAttributedString.Key("io.chouti.composeui.test"): object])
      }

      // when: resetting it for a reuse by a text node
      textView.resetForReuse(keepsTextNodeSettings: true)

      // then: it keeps the text, which a reuse in the same render pass replaces in one edit
      expect(textView.attributedString.string, scenario) == "Hello, world!"
      expect(Self.textStorage(of: textView)?.string, scenario) == "Hello, world!"

      // when: the run loop turn ends
      let turnEnded = expectation(description: "the run loop turn ends")
      onNextRunLoop {
        turnEnded.fulfill()
      }
      wait(for: [turnEnded], timeout: 1)

      // then: the text view removes its text, and on AppKit lets go of the object that the text held, which a UIKit text
      // view keeps until it gets another text
      expect(textView.attributedString.string, scenario) == ""
      expect(Self.textStorage(of: textView)?.length, scenario) == 0
      #if canImport(AppKit)
      expect(weakObject, scenario) == nil
      #endif
    }
  }

  func test_resetForReuse_keepingTextNodeSettings_resetAgainInTheSameTurn_schedulesTheTextViewOnce() {
    // given: a text view reset for a reuse by a text node, which then gets another text, as a text node that reuses it
    // sets
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")
    let countBefore = BaseTextView.scheduledTextRemovalCount
    textView.resetForReuse(keepsTextNodeSettings: true)
    textView.attributedString = NSAttributedString(string: "Another text")

    // when: it's reset again before the run loop turn ends, as when a later refresh in the same turn removes it again
    textView.resetForReuse(keepsTextNodeSettings: true)

    // then: it's scheduled once
    expect(BaseTextView.scheduledTextRemovalCount) == countBefore + 1

    // when: the run loop turn ends
    let turnEnded = expectation(description: "the run loop turn ends")
    onNextRunLoop {
      turnEnded.fulfill()
    }
    wait(for: [turnEnded], timeout: 1)

    // then: it removes its text, since the second reset scheduled the removal again
    expect(textView.attributedString.string) == ""
    expect(Self.textStorage(of: textView)?.length) == 0
    expect(BaseTextView.scheduledTextRemovalCount) == 0
  }

  func test_resetForReuse_keepingTextNodeSettings_resetAgainInALaterTurn_removesTheTextAgain() {
    // given: a text view reset for a reuse by a text node, which removed its text at the end of the run loop turn
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")
    textView.resetForReuse(keepsTextNodeSettings: true)
    let firstTurnEnded = expectation(description: "the first run loop turn ends")
    onNextRunLoop {
      firstTurnEnded.fulfill()
    }
    wait(for: [firstTurnEnded], timeout: 1)
    expect(textView.attributedString.string) == ""

    // when: a text node reuses it, it's reset again, and the next turn ends
    textView.attributedString = NSAttributedString(string: "Another text")
    textView.resetForReuse(keepsTextNodeSettings: true)
    let secondTurnEnded = expectation(description: "the second run loop turn ends")
    onNextRunLoop {
      secondTurnEnded.fulfill()
    }
    wait(for: [secondTurnEnded], timeout: 1)

    // then: it removes the other text too, since the end of the first turn took it off the list
    expect(textView.attributedString.string) == ""
    expect(Self.textStorage(of: textView)?.length) == 0
  }

  func test_resetForReuse_keepingTextNodeSettings_textSetBeforeTheEndOfTheTurn_isKept() {
    // given: a text view with a text, reset for a reuse by a text node
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")
    textView.resetForReuse(keepsTextNodeSettings: true)

    // when: the text view gets another text, as a text node that reuses it sets, and the run loop turn ends
    textView.attributedString = NSAttributedString(string: "Another text")
    let turnEnded = expectation(description: "the run loop turn ends")
    onNextRunLoop {
      turnEnded.fulfill()
    }
    wait(for: [turnEnded], timeout: 1)

    // then: the text view keeps the other text, since it got it before its text was to be removed
    expect(textView.attributedString.string) == "Another text"
    expect(Self.textStorage(of: textView)?.string) == "Another text"
  }

  #if canImport(AppKit)
  func test_resetForReuse_keepingTextNodeSettings_undoAllowed_removesTheUndoActions() throws {
    // given: a text view that allows undo, which the user typed into
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try window.undoManager.unwrap()

    // when: resetting it for a text node in its window
    textView.resetForReuse(keepsTextNodeSettings: true)

    // then: the undo actions are gone
    expect(undoManager.canUndo) == false
  }

  func test_resetForReuse_keepingTextNodeSettings_undoManagerOfTheDelegate_removesTheUndoActions() {
    // given: a text view that allows undo, whose delegate gives it an undo manager, which the user typed into
    let delegate = UndoManagerProvidingDelegate()
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more", delegate: delegate)
    expect(delegate.undoManager.canUndo) == true

    // when: resetting it for a text node, which removes the delegate
    textView.resetForReuse(keepsTextNodeSettings: true)

    // then: the delegate's undo manager no longer has the undo actions
    expect(delegate.undoManager.canUndo) == false
    withExtendedLifetime(window) {}
  }

  func test_resetForReuse_keepingTextNodeSettings_undoAllowed_outsideItsWindow_removesTheUndoActions() throws {
    // given: a text view that allows undo, which the user typed into, removed from its window, as a text node's text view
    // is before its reset
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try window.undoManager.unwrap()
    textView.removeFromSuperview()

    // when: resetting it for a text node
    textView.resetForReuse(keepsTextNodeSettings: true)

    // then: the undo actions are gone
    expect(undoManager.canUndo) == false
  }

  func test_removeFromSuperview_undoAllowed_backInTheWindow_keepsTheUndoActions() throws {
    // given: a text view that allows undo, which the user typed into
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world")
    let undoManager = try window.undoManager.unwrap()
    let contentView = try window.contentView.unwrap()

    // when: removing it from its window
    textView.removeFromSuperview()

    // then: the window keeps the undo actions
    expect(undoManager.canUndo) == true

    // when: adding it back, as a tab view does with the views of its tabs
    contentView.addSubview(textView)

    // then: the user can still undo the typing
    undoManager.undo()
    expect(textView.string) == "Hello"
  }

  func test_moveToAnotherWindow_undoAllowed_sharedUndoManager_keepsTheUndoActions() throws {
    // given: a text view that allows undo, which the user typed into, in a window that shares its undo manager with
    // another one, as a document's windows do
    let windowDelegate = UndoManagerProvidingWindowDelegate()
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world", windowDelegate: windowDelegate)
    let otherWindow = TestWindow()
    otherWindow.delegate = windowDelegate

    // when: moving it to the other window
    otherWindow.contentView?.addSubview(textView)

    // then: the user can still undo the typing there
    let undoManager = try textView.undoManager.unwrap()
    expect(undoManager) === windowDelegate.undoManager
    undoManager.undo()
    expect(textView.string) == "Hello"
    withExtendedLifetime(window) {}
  }

  func test_moveWithinTheWindow_undoAllowed_keepsTheUndoActions() throws {
    // given: a text view that allows undo, which the user typed into, and two containers in its window
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world")
    let undoManager = try window.undoManager.unwrap()
    let contentView = try window.contentView.unwrap()
    let container = NSView(frame: contentView.bounds)
    let otherContainer = NSView(frame: contentView.bounds)
    contentView.addSubview(container)
    contentView.addSubview(otherContainer)

    // when: moving it to another superview in its window
    container.addSubview(textView)

    // then: the window keeps the undo actions
    expect(undoManager.canUndo) == true

    // when: moving its superview to another superview in its window
    otherContainer.addSubview(container)

    // then: the user can still undo the typing
    expect(undoManager.canUndo) == true
    undoManager.undo()
    expect(textView.string) == "Hello"
  }

  func test_userEdit_undoAllowed_inAnotherWindow_removesTheUndoActionsFromTheFirstWindow() throws {
    // given: a text view that allows undo, which the user typed into
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world")
    let undoManager = try window.undoManager.unwrap()
    let otherWindow = TestWindow()

    // when: moving it to another window
    otherWindow.contentView?.addSubview(textView)

    // then: the first window keeps the undo actions
    expect(undoManager.canUndo) == true

    // when: the user types in the other window
    otherWindow.makeFirstResponder(textView)
    textView.insertText(" again", replacementRange: NSRange(location: NSNotFound, length: 0))
    RunLoop.main.run(until: Date())

    // then: the first window's undo actions are gone, and the other window's undo manager records the edit
    expect(undoManager.canUndo) == false
    expect(otherWindow.undoManager?.canUndo) == true
  }

  func test_userEdit_undoManagerOfTheDelegateChanged_removesTheUndoActionsFromThePreviousOne() {
    // given: a text view that allows undo, which the user typed into, whose delegate gives another undo manager since
    let delegate = UndoManagerProvidingDelegate()
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world", delegate: delegate)
    let previousUndoManager = delegate.undoManager
    let undoManager = UndoManager()
    delegate.undoManager = undoManager

    // when: the user types again
    textView.insertText(" again", replacementRange: NSRange(location: NSNotFound, length: 0))
    RunLoop.main.run(until: Date())

    // then: the previous undo manager's actions are gone, and the new one records the edit
    expect(previousUndoManager.canUndo) == false
    expect(undoManager.canUndo) == true
    withExtendedLifetime(window) {}
  }

  func test_userEdit_undoTurnedOff_removesTheUndoActions() throws {
    // given: a text view that the user typed into while it allowed undo, which doesn't allow undo anymore
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world")
    let undoManager = try window.undoManager.unwrap()
    textView.allowsUndo = false

    // when: the user types again, which no undo manager records
    textView.insertText(" again", replacementRange: NSRange(location: NSNotFound, length: 0))

    // then: the undo actions are gone
    expect(undoManager.canUndo) == false
    expect(textView.string) == "Hello, world again"
  }

  func test_userEdit_rejected_keepsTheUndoActions() throws {
    // given: a text view that the user typed into while it allowed undo, which doesn't allow undo anymore, and whose
    // delegate rejects edits
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world")
    let undoManager = try window.undoManager.unwrap()
    textView.allowsUndo = false
    let delegate = EditRejectingDelegate()
    textView.delegate = delegate

    // when: the user types again, which the delegate rejects
    textView.insertText(" again", replacementRange: NSRange(location: NSNotFound, length: 0))

    // then: the text and the undo actions stay
    expect(textView.string) == "Hello, world"
    expect(undoManager.canUndo) == true
  }
  #endif

  #if canImport(UIKit)
  func test_resetForReuse_keepingTextNodeSettings_frameChangeThatResizes_removesTheTextFirst() {
    // given: a text view with a text, reset for a reuse by a text node, and an observer that records the text view's
    // size at each edit of its text storage
    let textView = AttributedTextCountingTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")
    textView.resetForReuse(keepsTextNodeSettings: true)
    textView.attributedTextSetCount = 0
    var sizesAtEdits: [CGSize] = []
    let observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: textView.textStorage, queue: nil) { _ in
      sizesAtEdits.append(textView.frame.size)
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
    }

    // when: a frame change resizes it, as when a text node of another size reuses it
    textView.frame = CGRect(x: 0, y: 20, width: 160, height: 50)

    // then: it removes the text through its text storage before the resize, which would lay the text out again
    expect(sizesAtEdits) == [CGSize(width: 200, height: 50)]
    expect(textView.attributedTextSetCount) == 0
    expect(textView.textStorage.length) == 0
    expect(textView.frame) == CGRect(x: 0, y: 20, width: 160, height: 50)
  }

  func test_resetForReuse_keepingTextNodeSettings_frameChangeThatMoves_keepsTheText() {
    // given: a text view with a text, reset for a reuse by a text node, and an observer of its text storage edits
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")
    textView.resetForReuse(keepsTextNodeSettings: true)
    var editCount = 0
    let observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: textView.textStorage, queue: nil) { _ in
      editCount += 1
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
    }

    // when: a frame change moves it without resizing it, as when a text node of the same size reuses it
    textView.frame = CGRect(x: 0, y: 20, width: 200, height: 50)

    // then: it keeps the text
    expect(editCount) == 0
    expect(textView.textStorage.string) == "Hello, world!"

    // when: it gets another text, as the text node that reuses it sets
    textView.attributedString = NSAttributedString(string: "Another text")

    // then: it replaces the text in one edit
    expect(editCount) == 1
    expect(textView.textStorage.string) == "Another text"
  }

  func test_frameChangeThatResizes_keepsTheText() {
    // given: a text view with a text, which no reset is to remove
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")

    // when: a frame change resizes it
    textView.frame = CGRect(x: 0, y: 0, width: 160, height: 50)

    // then: it keeps the text
    expect(textView.textStorage.string) == "Hello, world!"
  }

  func test_resize_subviewsWithoutAutoresizingMasks_skipsAutoresizing() throws {
    // given: a text view with a text, which doesn't scroll, as a text node's, and has only its own subviews, without
    // autoresizing masks
    let textView = AutoresizingRecordingTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.isScrollEnabled = false
    textView.attributedString = NSAttributedString(string: "Hello, world!")
    expect(textView.subviews.allSatisfy(\.autoresizingMask.isEmpty)) == true
    textView.autoresizesSubviewsValues = []

    // when: a frame change moves it
    textView.frame = CGRect(x: 0, y: 20, width: 200, height: 50)

    // then: autoresizing is left as it is
    expect(textView.autoresizesSubviewsValues) == []

    // when: a frame change resizes it
    textView.frame = CGRect(x: 0, y: 20, width: 240, height: 60)

    // then: the resize skips autoresizing, which leaves a subview without a mask as it is, and turns it back on after,
    // except on tvOS, which autoresizes without the cost of iOS, and the text view lays out its subviews itself
    #if os(tvOS)
    expect(textView.autoresizesSubviewsValues) == []
    #else
    expect(textView.autoresizesSubviewsValues) == [false, true]
    #endif
    expect(textView.autoresizesSubviews) == true
    textView.layoutIfNeeded()
    let textContainerView = try unwrap(Self.textContainerView(of: textView))
    expect(textContainerView.frame) == textView.bounds
  }

  func test_resize_subviewWithAnAutoresizingMask_isAutoresized() {
    // given: a text view with a subview that an app added, whose autoresizing mask keeps its width the text view's
    let textView = AutoresizingRecordingTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    let subview = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 10))
    subview.autoresizingMask = [.flexibleWidth]
    textView.addSubview(subview)
    textView.autoresizesSubviewsValues = []

    // when: a frame change resizes the text view
    textView.frame = CGRect(x: 0, y: 0, width: 240, height: 50)

    // then: the subview is autoresized
    expect(textView.autoresizesSubviewsValues) == []
    expect(subview.frame) == CGRect(x: 0, y: 0, width: 240, height: 10)
  }

  func test_resize_autoresizingTurnedOff_staysOff() {
    // given: a text view whose app turned autoresizing off
    let textView = AutoresizingRecordingTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.autoresizesSubviews = false
    textView.autoresizesSubviewsValues = []

    // when: a frame change resizes it
    textView.frame = CGRect(x: 0, y: 0, width: 240, height: 50)

    // then: autoresizing stays off
    expect(textView.autoresizesSubviewsValues) == []
    expect(textView.autoresizesSubviews) == false
  }

  #if !os(tvOS)
  func test_resize_firstResponderWithASelection_autoresizesItsSubviews() {
    for isEditable in [false, true] {
      // given: a selectable text view, editable or not, the first responder in a key window with a selection, for which
      // UIKit adds the cursor, the selection views and the scroll indicators, which have autoresizing masks
      let scenario = "editable \(isEditable)"
      let window = TestWindow()
      window.rootViewController = UIViewController()
      let textView = AutoresizingRecordingTextView(frame: CGRect(x: 10, y: 10, width: 120, height: 60))
      textView.isEditable = isEditable
      textView.isScrollEnabled = isEditable
      window.rootViewController?.view.addSubview(textView)
      window.makeKeyAndVisible()
      textView.attributedString = NSAttributedString(string: "A paragraph that wraps across several lines in a narrow frame.")
      textView.becomeFirstResponder()
      textView.selectedRange = NSRange(location: 5, length: 20)
      expect(textView.subviews.contains { !$0.autoresizingMask.isEmpty }, scenario) == true
      textView.autoresizesSubviewsValues = []

      // when: a frame change resizes it
      textView.frame = CGRect(x: 10, y: 30, width: 180, height: 80)

      // then: it autoresizes its subviews, as UIKit does
      expect(textView.autoresizesSubviewsValues, scenario) == []
      expect(textView.autoresizesSubviews, scenario) == true
      textView.resignFirstResponder()
    }
  }
  #endif

  func test_resetForReuse_unchangedScrollIndicatorInsets_makesNoScrollIndicators() {
    // given: a text view whose scroll indicator insets are as made, and its subviews
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")
    let subviews = textView.subviews

    // when: resetting it for a reuse by a text node
    textView.resetForReuse(keepsTextNodeSettings: true)

    // then: it has the same subviews, since setting a scroll indicator inset would make scroll indicators, whose
    // autoresizing masks would keep a resize autoresizing the subviews
    expect(textView.subviews) == subviews
  }

  func test_resetForReuse_keepingTextNodeSettings_removesTheTextThroughTheTextStorage() {
    // given: a text view with a text, with the selection at its end, reset for a reuse by a text node
    let textView = AttributedTextCountingTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")
    expect(textView.selectedRange) == NSRange(location: 13, length: 0)
    textView.attributedTextSetCount = 0
    textView.resetForReuse(keepsTextNodeSettings: true)

    // when: the run loop turn ends with the text view still in the pool
    let turnEnded = expectation(description: "the run loop turn ends")
    onNextRunLoop {
      turnEnded.fulfill()
    }
    wait(for: [turnEnded], timeout: 1)

    // then: it removes its text through its text storage instead of through `attributedText`, which takes the selection
    // to the start
    expect(textView.attributedTextSetCount) == 0
    expect(textView.textStorage.length) == 0
    expect(textView.selectedRange) == NSRange(location: 0, length: 0)

    // when: the next text node sets a text with a font, a color and an alignment
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let font = UIFont.systemFont(ofSize: 21)
    textView.attributedString = NSAttributedString(string: "Next", attributes: [.font: font, .foregroundColor: UIColor.red, .paragraphStyle: style])

    // then: it's shown through `attributedText`, which sets the text view's font, text color and alignment from it
    expect(textView.attributedTextSetCount) == 1
    expect(textView.font) == font
    expect(textView.textColor) == .red
    expect(textView.textAlignment) == .center
  }

  func test_resetForReuse_removesTheTextThroughAttributedText() {
    // given: a text view with a text
    let textView = AttributedTextCountingTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")
    textView.attributedTextSetCount = 0

    // when: resetting it for reuse
    textView.resetForReuse()

    // then: it removes its text through `attributedText`, since an app may still observe a text view that it resets
    // itself
    expect(textView.attributedTextSetCount) == 1
    expect(textView.textStorage.length) == 0
  }

  #if !os(tvOS)
  func test_resetForReuse_keepingTextNodeSettings_textThatTheUserEmptied_removesTheUndoActions() {
    // given: a text view whose user typed into its empty text, then deleted the typing
    let (textView, window) = Self.makeTypedTextView(text: "", typed: "abc")
    textView.deleteBackward()
    textView.deleteBackward()
    textView.deleteBackward()
    expect(textView.textStorage.length) == 0
    expect(textView.undoManager?.canUndo) == true

    // when: resetting it for a text node
    textView.resetForReuse(keepsTextNodeSettings: true)

    // then: the undo actions are gone
    expect(textView.undoManager?.canUndo) == false
    withExtendedLifetime(window) {}
  }

  func test_resetForReuse_keepingTextNodeSettings_inTheAppsUndoGroup_assertsAndLeavesTheUndoActions() throws {
    // given: a typed text view in an undo group that the app opened, and an assertion handler that records the messages
    let (textView, window) = Self.makeTypedTextView(text: "Hello", typed: ", world and more")
    let undoManager = try textView.undoManager.unwrap()
    undoManager.beginUndoGrouping()
    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: resetting it for a text node in the group, which the app then ends
    textView.resetForReuse(keepsTextNodeSettings: true)
    undoManager.endUndoGrouping()

    // then: the text view asserts, and leaves the undo actions
    expect(assertionMessages) == [Constants.undoOperationAssertionMessage]
    expect(undoManager.canUndo) == true
    withExtendedLifetime(window) {}
  }

  func test_resetForReuse_neverEditable_leavesTheUndoActions() throws {
    // given: a text view that has never been editable, with an undo action that the app registered
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 300, height: 60))
    textView.attributedString = NSAttributedString(string: "Hello")
    let undoManager = try textView.undoManager.unwrap()
    let target = NSObject()
    undoManager.beginUndoGrouping()
    undoManager.registerUndo(withTarget: target) { _ in }
    undoManager.endUndoGrouping()

    // when: resetting it for a text node
    textView.resetForReuse(keepsTextNodeSettings: true)

    // then: the app's undo action stays
    expect(undoManager.canUndo) == true
  }
  #endif
  #endif

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

  func test_resetForReuse_restoresClipsToBounds() {
    // given: a text view whose clipping an app turned off
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.clipsToBounds = false

    // when: reset for reuse
    textView.resetForReuse()

    // then: it clips again
    expect(textView.clipsToBounds) == true
  }

  #if canImport(UIKit)
  func test_resetForReuse_keepingTextNodeSettings_textContainerViewKeepsClipping() throws {
    guard #available(iOS 16.0, *) else {
      throw XCTSkip("the text view clips its text container view from iOS 16")
    }

    // given: a text view in a window, showing a text
    let window = TestWindow()
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    window.addSubview(textView)
    textView.attributedString = Self.makeText("Hello, world")
    textView.layoutIfNeeded()
    let textContainerView = try Self.textContainerView(of: textView).unwrap()

    // then: the view that UIKit draws the text in clips
    expect(textContainerView.clipsToBounds) == true

    // when: resetting it for a text node, and reusing it for another text
    textView.removeFromSuperview()
    textView.resetForReuse(keepsTextNodeSettings: true)
    window.addSubview(textView)
    textView.attributedString = Self.makeText("Another text")
    textView.layoutIfNeeded()

    // then: UIKit draws the text in the same view, which still clips
    expect(Self.textContainerView(of: textView)) === textContainerView
    expect(textContainerView.clipsToBounds) == true
  }
  #endif

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
    textView.textStorage
  }

  #if canImport(UIKit)
  /// Returns the subview that UIKit draws a text view's text in.
  private static func textContainerView(of textView: UITextView) -> UIView? {
    textView.subviews.first { String(cString: object_getClassName($0)) == "_UITextContainerView" }
  }
  #endif

  #if canImport(UIKit) && !os(tvOS)
  /// Returns an editable text view in a key window that the user typed into, in a pass of the run loop whose undo group
  /// holds the typing, and the window, which the caller keeps until the end of the test.
  ///
  /// - Parameters:
  ///   - text: The text that the text view shows.
  ///   - typed: The text that the user types at the end of the text.
  ///   - textContainer: The text view's text container, `nil` for one of its own.
  private static func makeTypedTextView(text: String, typed: String, textContainer: NSTextContainer? = nil) -> (BaseTextView, UIWindow) {
    let window = TestWindow()
    window.rootViewController = UIViewController()
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 300, height: 60), textContainer: textContainer)
    window.rootViewController?.view.addSubview(textView)
    window.makeKeyAndVisible()
    textView.isEditable = true
    textView.attributedString = NSAttributedString(string: text)
    textView.becomeFirstResponder()
    textView.selectedRange = NSRange(location: textView.textStorage.length, length: 0)
    textView.insertText(typed)
    return (textView, window)
  }

  /// Returns a TextKit 2 text container, and the content storage that keeps its text, which the caller keeps until the
  /// end of the test.
  @available(iOS 15.0, *)
  private static func makeTextKit2TextContainer() -> (NSTextContainer, NSTextContentStorage) {
    let textContainer = NSTextContainer(size: CGSize(width: 300, height: 60))
    let textLayoutManager = NSTextLayoutManager()
    textLayoutManager.textContainer = textContainer
    let contentStorage = NSTextContentStorage()
    contentStorage.addTextLayoutManager(textLayoutManager)
    return (textContainer, contentStorage)
  }
  #endif

  /// Returns the rect that each line that the text view lays out uses.
  private static func lineRects(of textView: BaseTextView) throws -> [CGRect] {
    #if canImport(AppKit)
    let layoutManager = try textView.layoutManager.unwrap()
    let textContainer = try textView.textContainer.unwrap()
    #endif
    #if canImport(UIKit)
    let layoutManager = textView.layoutManager
    let textContainer = textView.textContainer
    #endif
    layoutManager.ensureLayout(for: textContainer)
    var rects: [CGRect] = []
    layoutManager.enumerateLineFragments(forGlyphRange: layoutManager.glyphRange(for: textContainer)) { _, usedRect, _, _, _ in
      rects.append(usedRect)
    }
    return rects
  }

  #if canImport(AppKit)
  /// Returns an editable text view that allows undo in a window, which the user typed into at the end of its text, and the
  /// window, which the caller keeps until the end of the test.
  ///
  /// - Parameters:
  ///   - text: The text that the text view shows.
  ///   - typed: The text that the user types at the end of the text.
  ///   - endsPass: Whether the pass of the run loop whose undo group holds the typing ends.
  ///   - delegate: The text view's delegate, which can give it an undo manager.
  ///   - windowDelegate: The window's delegate, which can give the window an undo manager.
  private static func makeTypedTextView(text: String, typed: String, endsPass: Bool = true, delegate: NSTextViewDelegate? = nil, windowDelegate: NSWindowDelegate? = nil) -> (BaseTextView, NSWindow) {
    let window = TestWindow()
    window.delegate = windowDelegate
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 300, height: 60))
    textView.allowsUndo = true
    textView.isEditable = true
    textView.delegate = delegate
    window.contentView?.addSubview(textView)
    textView.attributedString = NSAttributedString(string: text)
    window.makeFirstResponder(textView)
    textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
    textView.insertText(typed, replacementRange: NSRange(location: NSNotFound, length: 0))
    if endsPass {
      RunLoop.main.run(until: Date())
    }
    return (textView, window)
  }
  #endif

  /// Runs the main run loop until the blocks scheduled on it so far have run.
  private func runScheduledBlocks() {
    var isDrained = false
    RunLoop.main.perform {
      isDrained = true
    }
    expect(isDrained).toEventually(beTrue())
  }

  // MARK: - Constants

  private enum Constants {

    /// The assertion message for a text change during an undo operation of an editable text view's undo manager.
    static let undoOperationAssertionMessage = "an editable text view's text must not change during an undo operation of its undo manager, change it after the operation, such as with `setNeedsRefresh(animated:)`"
  }
}

#if canImport(AppKit)
/// A text view that counts its layout passes and the invalidations of its intrinsic size.
private final class CountingTextView: BaseTextView {

  var layoutCount = 0
  var intrinsicSizeInvalidationCount = 0

  override func layout() {
    super.layout()
    layoutCount += 1
  }

  override func invalidateIntrinsicContentSize() {
    super.invalidateIntrinsicContentSize()
    intrinsicSizeInvalidationCount += 1
  }
}

/// A text view that counts the view frame changes that AppKit tells it of, through the private methods AppKit registers
/// for them.
private final class FrameChangeCountingTextView: BaseTextView {

  var everyFrameChangeCount = 0
  var clipViewFrameChangeCount = 0

  @objc(_anyViewFrameChangedWithNotification:)
  func countEveryFrameChange(_ notification: NSNotification) {
    everyFrameChangeCount += 1
  }

  @objc(_superviewClipViewFrameChangedWithNotification:)
  func countClipViewFrameChange(_ notification: NSNotification) {
    clipViewFrameChangeCount += 1
  }
}

/// A window that counts the reads of its undo manager, which it makes when it's first read.
private final class UndoManagerReadCountingWindow: NSWindow {

  var undoManagerReadCount = 0

  override var undoManager: UndoManager? {
    undoManagerReadCount += 1
    return super.undoManager
  }
}

/// A text view delegate that gives the text view an undo manager of its own.
private final class UndoManagerProvidingDelegate: NSObject, NSTextViewDelegate {

  var undoManager = UndoManager()

  func undoManager(for view: NSTextView) -> UndoManager? {
    undoManager
  }
}

/// A window delegate that gives each of its windows the same undo manager.
private final class UndoManagerProvidingWindowDelegate: NSObject, NSWindowDelegate {

  let undoManager = UndoManager()

  func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
    undoManager
  }
}

/// A text view delegate that rejects every edit.
private final class EditRejectingDelegate: NSObject, NSTextViewDelegate {

  func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
    false
  }
}
#endif

/// A text view delegate that counts the selection changes that the text view tells it of.
private final class SelectionChangeCounter: NSObject {

  var count = 0
}

#if canImport(AppKit)
extension SelectionChangeCounter: NSTextViewDelegate {

  func textViewDidChangeSelection(_ notification: Notification) {
    count += 1
  }
}
#endif

#if canImport(UIKit)
extension SelectionChangeCounter: UITextViewDelegate {

  func textViewDidChangeSelection(_ textView: UITextView) {
    count += 1
  }
}

/// A text view that records the values that `autoresizesSubviews` is set to.
private final class AutoresizingRecordingTextView: BaseTextView {

  var autoresizesSubviewsValues: [Bool] = []

  override var autoresizesSubviews: Bool {
    didSet {
      autoresizesSubviewsValues.append(autoresizesSubviews)
    }
  }
}

/// A text view that counts the texts set through `attributedText`.
private final class AttributedTextCountingTextView: BaseTextView {

  var attributedTextSetCount = 0

  override var attributedText: NSAttributedString! {
    didSet {
      attributedTextSetCount += 1
    }
  }
}
#endif
