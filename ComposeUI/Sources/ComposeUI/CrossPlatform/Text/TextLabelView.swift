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

      #if canImport(AppKit)
      textDrawsTheSameInALayer = nil
      updateDrawingMode()
      #endif

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
    if drawsInLayer {
      drawingLayer?.setNeedsDisplay()
    }
    #endif

    #if canImport(UIKit)
    setNeedsDisplay()
    #endif
  }

  /// Sizes the text container to the bounds inside the inset, where the text lays out.
  ///
  /// - Returns: Whether the container has room to show the text.
  private func fitTextContainer() -> Bool {
    let containerSize = CGSize(
      width: max(0, bounds.width - textContainerInset.width * 2),
      height: max(0, bounds.height - textContainerInset.height * 2)
    )

    // the container is resized only when its size changes, since a resize lays the text out again
    if textContainer.size != containerSize {
      textContainer.size = containerSize
    }

    // a text container without room still lays out a glyph, which an inset as large as the bounds leaves no room to show
    return containerSize.width > 0 && containerSize.height > 0
  }

  /// Draws the text, laid out in the bounds inside the inset.
  func drawText() {
    guard fitTextContainer() else {
      return
    }

    let glyphRange = layoutManager.glyphRange(for: textContainer)
    let origin = CGPoint(x: textContainerInset.width, y: textContainerInset.height)
    layoutManager.drawBackground(forGlyphRange: glyphRange, at: origin)
    layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
  }

  #if canImport(AppKit)

  // MARK: - Layer Drawing

  /// Whether the drawing layer draws the text, instead of AppKit drawing the view.
  ///
  /// AppKit draws a layer-backed view through a recording of its drawing, which takes more work than a layer that draws
  /// itself, but the two draw the same pixels only for the texts, sizes and systems that the label drawing parity tests
  /// verify, so the label draws in the layer only for those, and leaves anything else to AppKit.
  private var drawsInLayer = false

  /// The layer that draws the text when the label draws in a layer, made the first time it does.
  private var drawingLayer: DrawingLayer?

  /// Whether the text draws the same pixels in the drawing layer as through AppKit, see
  /// `NSAttributedString.drawsTheSameInALayer`, or `nil` before the label checks the text.
  private var textDrawsTheSameInALayer: Bool?

  #if DEBUG
  /// Whether tests force the label to draw in its drawing layer, `true`, or through AppKit, `false`, instead of choosing.
  private var forcedDrawsInLayer: Bool?
  #endif

  override public var wantsUpdateLayer: Bool { drawsInLayer }

  override public func updateLayer() {
    // the drawing layer shows the text, so the view's own layer shows nothing, instead of what AppKit drew before
    if layer?.contents != nil {
      layer?.contents = nil
    }
  }

  override public func draw(_ dirtyRect: NSRect) {
    drawText()
  }

  override public func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)

    drawingLayer?.frame = bounds
    updateDrawingMode()
  }

  override public func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    updateDrawingMode()
  }

  override public func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()

    updateDrawingMode()
  }

  override public func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()

    // AppKit draws the view again, while the drawing layer draws again for the dynamic colors of the new appearance
    if drawsInLayer {
      drawingLayer?.setNeedsDisplay()
    }
  }

  /// Chooses whether the drawing layer or AppKit draws the text, for the text, the size and the window.
  private func updateDrawingMode() {
    // out of a window, the label keeps how it draws, which saves switching for a reused label that leaves its window
    guard let window, let layer else {
      return
    }

    // the text comes last, since checking it reads each of its styles
    let scale = window.backingScaleFactor
    var drawsInLayer = Self.isLayerDrawingVerified && isSizeInWholePixels(scale: scale) && textDrawsTheSame()
    #if DEBUG
    if let forcedDrawsInLayer {
      drawsInLayer = forcedDrawsInLayer
    }
    #endif

    if drawsInLayer {
      let drawingLayer = self.drawingLayer ?? makeDrawingLayer()
      if drawingLayer.superlayer !== layer {
        layer.addSublayer(drawingLayer)
      }
      // AppKit gives the view's own layer the window's scale, while a layer that the view doesn't own keeps its scale
      if drawingLayer.contentsScale != scale {
        drawingLayer.contentsScale = scale
        drawingLayer.setNeedsDisplay()
      }
    }

    guard drawsInLayer != self.drawsInLayer else {
      return
    }

    self.drawsInLayer = drawsInLayer
    if drawsInLayer {
      drawingLayer?.isHidden = false
      drawingLayer?.setNeedsDisplay()
    } else {
      // AppKit draws the text, so the drawing layer hides, and lets its drawing go
      drawingLayer?.isHidden = true
      drawingLayer?.contents = nil
    }

    // AppKit draws the view, or with the drawing layer drawing, clears what it drew
    needsDisplay = true
  }

  /// Returns whether the text draws the same pixels in the drawing layer as through AppKit, checked once for each text.
  private func textDrawsTheSame() -> Bool {
    if let textDrawsTheSameInALayer {
      return textDrawsTheSameInALayer
    }

    // the text storage gives a substitute font to the characters that their font doesn't have, so the drawing is checked
    // on the text that the storage shows
    let drawsTheSame = textStorage.drawsTheSameInALayer
    textDrawsTheSameInALayer = drawsTheSame
    return drawsTheSame
  }

  private func makeDrawingLayer() -> DrawingLayer {
    let drawingLayer = DrawingLayer()
    drawingLayer.labelView = self
    drawingLayer.frame = bounds
    drawingLayer.needsDisplayOnBoundsChange = true
    // in the label's flipped layer, a sublayer's contents are flipped, which flips the space where Core Graphics offsets
    // shadows, and offsets them differently from AppKit, so the drawing layer flips back, and its drawing flips the
    // context instead
    drawingLayer.isGeometryFlipped = true
    self.drawingLayer = drawingLayer
    return drawingLayer
  }

  /// Returns whether the size is in whole pixels at a scale, which a layer draws in the same pixels as AppKit, while a
  /// size between pixels places the drawing differently in each.
  ///
  /// - Parameter scale: The scale of the window's backing store.
  /// - Returns: Whether the width and the height are whole numbers of pixels.
  private func isSizeInWholePixels(scale: CGFloat) -> Bool {
    let width = bounds.width * scale
    let height = bounds.height * scale
    return width == width.rounded() && height == height.rounded()
  }

  override public func hitTest(_ point: NSPoint) -> NSView? {
    // the view doesn't take clicks, as a text view that's neither editable nor selectable doesn't
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

  // An assistive technology reads a static text's characters, lines and attributes through the queries below, as a
  // native label answers them. They describe the text, so an app's own value, which replaces the text, leaves them to
  // `NSView`, instead of describing a string that isn't the value.

  /// The text that the view describes to assistive technologies, or `nil` when an app sets its own value.
  private var describedText: NSAttributedString? {
    super.accessibilityValue() == nil ? lastText : nil
  }

  override public func accessibilityNumberOfCharacters() -> Int {
    guard let text = describedText else {
      return super.accessibilityNumberOfCharacters()
    }
    return text.length
  }

  override public func accessibilityVisibleCharacterRange() -> NSRange {
    guard describedText != nil else {
      return super.accessibilityVisibleCharacterRange()
    }
    guard fitTextContainer() else {
      return NSRange(location: 0, length: 0)
    }
    return layoutManager.characterRange(forGlyphRange: layoutManager.glyphRange(for: textContainer), actualGlyphRange: nil)
  }

  override public func accessibilityString(for range: NSRange) -> String? {
    guard let text = describedText else {
      return super.accessibilityString(for: range)
    }
    guard text.containsRange(range) else {
      return nil
    }
    return (text.string as NSString).substring(with: range)
  }

  override public func accessibilityAttributedString(for range: NSRange) -> NSAttributedString? {
    guard let text = describedText else {
      return super.accessibilityAttributedString(for: range)
    }
    guard text.containsRange(range) else {
      return nil
    }

    // a text field cell converts the text's attributes to the ones that assistive technologies read, such as a font's
    // name and size instead of a font, as a native label's cell does
    let cell = NSTextFieldCell(textCell: "")
    cell.attributedStringValue = text
    return cell.accessibilityAttributedString(for: range)
  }

  override public func accessibilityRTF(for range: NSRange) -> Data? {
    guard let text = describedText else {
      return super.accessibilityRTF(for: range)
    }
    guard text.containsRange(range) else {
      return nil
    }
    return text.rtf(from: range)
  }

  override public func accessibilityRange(for index: Int) -> NSRange {
    guard let text = describedText else {
      return super.accessibilityRange(for: index)
    }
    guard index >= 0, index < text.length else {
      return Constants.notFoundRange
    }
    return (text.string as NSString).rangeOfComposedCharacterSequence(at: index)
  }

  override public func accessibilityStyleRange(for index: Int) -> NSRange {
    guard let text = describedText else {
      return super.accessibilityStyleRange(for: index)
    }
    guard index >= 0, index < text.length else {
      return Constants.notFoundRange
    }
    var range = NSRange(location: 0, length: 0)
    _ = text.attributes(at: index, longestEffectiveRange: &range, in: NSRange(location: 0, length: text.length))
    return range
  }

  override public func accessibilityLine(for index: Int) -> Int {
    guard describedText != nil else {
      return super.accessibilityLine(for: index)
    }
    // an index past the laid-out lines, such as the end of the text, is on the last line
    let lineRanges = lineCharacterRanges()
    return lineRanges.firstIndex(where: { NSLocationInRange(index, $0) }) ?? max(lineRanges.count - 1, 0)
  }

  override public func accessibilityRange(forLine line: Int) -> NSRange {
    guard describedText != nil else {
      return super.accessibilityRange(forLine: line)
    }
    let lineRanges = lineCharacterRanges()
    return lineRanges.indices.contains(line) ? lineRanges[line] : Constants.notFoundRange
  }

  override public func accessibilityFrame(for range: NSRange) -> NSRect {
    guard let text = describedText else {
      return super.accessibilityFrame(for: range)
    }
    guard text.containsRange(range), fitTextContainer() else {
      return .zero
    }
    let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
    let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
    return NSAccessibility.screenRect(fromView: self, rect: rect.offsetBy(dx: textContainerInset.width, dy: textContainerInset.height))
  }

  override public func accessibilityRange(for point: NSPoint) -> NSRange {
    guard let text = describedText else {
      return super.accessibilityRange(for: point)
    }
    guard text.length > 0, let window, fitTextContainer() else {
      return Constants.notFoundRange
    }
    let viewPoint = convert(window.convertPoint(fromScreen: point), from: nil)
    let containerPoint = CGPoint(x: viewPoint.x - textContainerInset.width, y: viewPoint.y - textContainerInset.height)
    let index = layoutManager.characterIndex(for: containerPoint, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
    return (text.string as NSString).rangeOfComposedCharacterSequence(at: min(index, text.length - 1))
  }

  /// Returns the character ranges of the text's laid-out lines, from the first line.
  private func lineCharacterRanges() -> [NSRange] {
    guard fitTextContainer() else {
      return []
    }
    var lineRanges: [NSRange] = []
    layoutManager.enumerateLineFragments(forGlyphRange: layoutManager.glyphRange(for: textContainer)) { _, _, _, glyphRange, _ in
      lineRanges.append(self.layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil))
    }
    return lineRanges
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

  override public var accessibilityAttributedLabel: NSAttributedString? {
    get {
      // an assistive technology reads the attributes of the attributed label, such as a language to speak a part of
      // the text in, so the text labels the view as it is, unless the app sets its own label
      super.accessibilityAttributedLabel ?? lastText
    }
    set {
      super.accessibilityAttributedLabel = newValue
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

    #if canImport(AppKit)
    /// Whether the label draws its text in its drawing layer, instead of through AppKit.
    var drawsInLayer: Bool {
      host.drawsInLayer
    }

    /// The layer that draws the text when the label draws in a layer.
    var drawingLayer: CALayer? {
      host.drawingLayer
    }

    /// Forces the label to draw in its drawing layer, `true`, or through AppKit, `false`, or lets it choose, `nil`.
    var forcedDrawsInLayer: Bool? {
      get {
        host.forcedDrawsInLayer
      }
      set {
        host.forcedDrawsInLayer = newValue
        host.updateDrawingMode()
      }
    }
    #endif
  }

  #endif

  // MARK: - Constants

  #if canImport(AppKit)
  private enum Constants {

    /// The range that a text query returns for an index, a line or a point that the text doesn't have.
    static let notFoundRange = NSRange(location: NSNotFound, length: 0)
  }
  #endif
}

// MARK: - Ranges

#if canImport(AppKit)
private extension NSAttributedString {

  /// Whether a range is within the text, checked without adding its location and length, which can overflow, such as
  /// for a location of `NSNotFound`.
  ///
  /// - Parameter range: The range to check.
  /// - Returns: Whether the range is within the text.
  func containsRange(_ range: NSRange) -> Bool {
    range.location >= 0 && range.length >= 0 && range.location <= length && range.length <= length - range.location
  }
}
#endif

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
