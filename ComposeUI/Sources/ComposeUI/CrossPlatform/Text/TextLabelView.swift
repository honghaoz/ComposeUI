//
//  TextLabelView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/15/26.
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

/// A view that draws a text that's neither editable nor selectable.
///
/// `TextNode` shows a text that the user can neither edit nor select in this view, instead of in a `BaseTextView`. It
/// lays out the text with TextKit 1, as ComposeUI measures text, and draws it, without a text view's machinery for
/// editing, selection and scrolling.
public final class TextLabelView: BaseView, ScheduledTextRemovable {

  /// The text that the view shows.
  ///
  /// Setting a text equal to the shown one leaves the shown text in place, so to change an attribute object, such as an
  /// attachment's image, set a text with a new object instead of changing the object.
  public internal(set) var attributedString: NSAttributedString {
    get {
      lastText
    }
    set {
      isTextRemovalScheduled = false

      // the text storage gives a substitute font to the characters that their font doesn't have, so a new text is
      // compared with the text that the view was last set to instead of with the text storage
      guard !lastText.isEqual(to: newValue) else {
        return
      }

      // a mutable text can change after it's set, so it's compared later through a copy
      lastText = newValue is NSMutableAttributedString ? NSAttributedString(attributedString: newValue) : newValue

      textStorage.setAttributedString(shownText(of: newValue))
      setNeedsDisplayForText()
    }
  }

  /// The maximum number of lines that the view shows, 0 for no limit.
  public internal(set) var numberOfLines: Int = 0 {
    didSet {
      textContainer.maximumNumberOfLines = max(numberOfLines, 0)
      setNeedsDisplayForText()
    }
  }

  /// The line break mode of the text's last line.
  public internal(set) var lineBreakMode: NSLineBreakMode = .byWordWrapping {
    didSet {
      textContainer.lineBreakMode = lineBreakMode
      setNeedsDisplayForText()
    }
  }

  /// The inset of the text from the view's edges, the width from the left and right edges and the height from the top
  /// and bottom edges.
  public internal(set) var textContainerInset: CGSize = .zero {
    didSet {
      setNeedsDisplayForText()
    }
  }

  /// The text that `TextNode` last applied a theme to, with the theme and the themed text.
  var lastThemedText: (text: NSAttributedString, theme: Theme, themedText: NSAttributedString)?

  /// Whether the view removes its text at the end of the run loop turn, unless it gets another text before.
  var isTextRemovalScheduled = false

  /// Whether the view is in the list of views that remove their text at the end of the run loop turn.
  var isInTextRemovalList = false

  /// The text that the view was last set to show, as it was set.
  private var lastText = NSAttributedString()

  #if canImport(UIKit)
  /// Whether the shown text has a link, which shows in the link color.
  private var hasLink = false
  #endif

  private let textStorage = NSTextStorage()
  private let layoutManager = NSLayoutManager()
  private let textContainer = NSTextContainer(size: .zero)

  override public init(frame: CGRect) {
    super.init(frame: frame)

    layoutManager.addTextContainer(textContainer)
    textStorage.addLayoutManager(layoutManager)
    textContainer.lineFragmentPadding = 0

    // a truncated line, such as with `.byTruncatingTail`, can lay out past the bounds
    clipsToBounds = true

    #if canImport(UIKit)
    isOpaque = false
    backgroundColor = nil
    contentMode = .redraw
    isUserInteractionEnabled = false
    isAccessibilityElement = true
    accessibilityTraits = .staticText
    #endif
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  /// Resets the view for a reuse by a text node.
  ///
  /// A text node sets the view's settings and text on each reuse, so the settings are kept, and the view removes its
  /// text at the end of the run loop turn, unless it gets another text before, which replaces the text in one edit,
  /// such as when a scroll reuses the view in the same render pass.
  func resetForReuse() {
    lastThemedText = nil
    ScheduledTextRemoval.schedule(self)
  }

  /// Returns the text that the text storage shows for a text, as a text view that's neither editable nor selectable
  /// shows it.
  ///
  /// TextKit 1 aligns a paragraph without a writing direction by the user's language instead of by its text, so each
  /// paragraph is shown in the direction of its text, as ComposeUI measures it. A UIKit text view shows a link in a
  /// color instead of in TextKit's link style, which adds an underline, so on UIKit, each link shows in the link color,
  /// and the view records whether the text has a link, to show it again when the tint color changes, while an AppKit
  /// text view's link style is TextKit's.
  ///
  /// - Parameter text: The text that the view is set to show.
  /// - Returns: The text that the text storage shows.
  private func shownText(of text: NSAttributedString) -> NSAttributedString {
    let shownText = text.resolvingNaturalWritingDirections()

    #if canImport(AppKit)
    return shownText
    #endif

    #if canImport(UIKit)
    hasLink = shownText.hasLink
    if hasLink {
      return shownText.showingLinks(in: linkColor)
    } else {
      return shownText
    }
    #endif
  }

  #if canImport(UIKit)
  /// The color that a link shows in, as a UIKit text view shows a link by default: the tint color, except on visionOS,
  /// where it's the system link color, whatever the tint color.
  private var linkColor: UIColor {
    #if os(visionOS)
    return .link
    #else
    return tintColor
    #endif
  }
  #endif

  // MARK: - Drawing

  /// Marks the view to draw its text again.
  private func setNeedsDisplayForText() {
    #if canImport(AppKit)
    needsDisplay = true
    #endif

    #if canImport(UIKit)
    setNeedsDisplay()
    #endif
  }

  /// Draws the text, laid out in the bounds inside the inset.
  private func drawText() {
    let containerSize = CGSize(
      width: max(0, bounds.width - textContainerInset.width * 2),
      height: max(0, bounds.height - textContainerInset.height * 2)
    )

    // the container is resized only when its size changes, since a resize lays the text out again
    if textContainer.size != containerSize {
      textContainer.size = containerSize
    }

    // a text container without room still lays out a glyph, which an inset as large as the bounds leaves no room to show
    guard containerSize.width > 0, containerSize.height > 0 else {
      return
    }

    let glyphRange = layoutManager.glyphRange(for: textContainer)
    let origin = CGPoint(x: textContainerInset.width, y: textContainerInset.height)
    layoutManager.drawBackground(forGlyphRange: glyphRange, at: origin)
    layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
  }

  #if canImport(AppKit)

  // `BaseView` updates its layer instead of drawing
  override public var wantsUpdateLayer: Bool { false }

  override public func draw(_ dirtyRect: NSRect) {
    drawText()
  }

  // the view doesn't take clicks, as a text view that's neither editable nor selectable doesn't
  override public func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }

  // MARK: - Accessibility

  override public func isAccessibilityElement() -> Bool {
    true
  }

  override public func accessibilityRole() -> NSAccessibility.Role? {
    .staticText
  }

  override public func accessibilityValue() -> Any? {
    super.accessibilityValue() ?? lastText.string
  }

  #endif

  #if canImport(UIKit)

  override public func draw(_ rect: CGRect) {
    drawText()
  }

  #if !os(visionOS)
  override public func tintColorDidChange() {
    super.tintColorDidChange()

    // a link shows in the tint color, as a text view's link follows its tint color, such as when an alert dims it
    if hasLink {
      textStorage.setAttributedString(shownText(of: lastText))
      setNeedsDisplay()
    }
  }
  #endif

  // MARK: - Accessibility

  override public var accessibilityLabel: String? {
    get {
      super.accessibilityLabel ?? lastText.string
    }
    set {
      super.accessibilityLabel = newValue
    }
  }

  #endif

  // MARK: - ScheduledTextRemovable

  func removeTextForReuse() {
    attributedString = NSAttributedString()
  }

  // MARK: - Testing

  #if DEBUG

  var test: Test { Test(host: self) }

  class Test {

    private let host: TextLabelView

    fileprivate init(host: TextLabelView) {
      ComposeUI.assert(Thread.isRunningXCTest, "Test namespace should only be used in test target.")
      self.host = host
    }

    /// The text storage that the view shows.
    var textStorage: NSTextStorage {
      host.textStorage
    }

    /// The layout manager that lays out the text.
    var layoutManager: NSLayoutManager {
      host.layoutManager
    }

    /// The text container that the text is laid out in.
    var textContainer: NSTextContainer {
      host.textContainer
    }
  }

  #endif
}

// MARK: - Links

#if canImport(UIKit)
private extension NSAttributedString {

  /// Whether the text has a link.
  var hasLink: Bool {
    var location = 0
    while location < length {
      var range = NSRange(location: 0, length: 0)
      if attribute(.link, at: location, effectiveRange: &range) != nil {
        return true
      }
      location = NSMaxRange(range)
    }
    return false
  }

  /// Returns the text with each link in a color, without TextKit's link style, as a UIKit text view shows a link.
  ///
  /// - Parameter color: The color of the links.
  /// - Returns: The text with each link in the color.
  func showingLinks(in color: UIColor) -> NSAttributedString {
    let text = NSMutableAttributedString(attributedString: self)
    enumerateAttribute(.link, in: NSRange(location: 0, length: length)) { value, range, _ in
      guard value != nil else {
        return
      }
      text.removeAttribute(.link, range: range)
      text.addAttribute(.foregroundColor, value: color, range: range)
    }
    return text
  }
}
#endif
