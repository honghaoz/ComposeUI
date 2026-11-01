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
///
/// On macOS, it doesn't post frame-change notifications by default.
public final class TextLabelView: View, ScheduledTextRemovable {

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

      #if canImport(AppKit)
      // a text that a worker drew ahead of time shows the image, and goes to the text storage only when the view lays
      // out the text itself, see `updateTextStorageIfNeeded()`
      takeResultForText()
      if readyImage == nil {
        updateTextStorage()
      } else {
        textStorageNeedsText = true
      }
      updateDrawingMode()
      #endif

      #if canImport(UIKit)
      // a UIKit layout manager lays out its text again at each change, so the text goes to the text storage with the
      // view's settings and size when the view lays it out
      textStorageNeedsText = true
      #endif

      setNeedsDisplayForText()
    }
  }

  /// The maximum number of lines that the view shows, 0 for no limit.
  public internal(set) var numberOfLines: Int = 0 {
    didSet {
      setNeedsDisplayForText()
    }
  }

  /// The line break mode of the text: `.byCharWrapping` breaks every line between characters, and the other modes set
  /// how the last line ends.
  public internal(set) var lineBreakMode: NSLineBreakMode = .byWordWrapping {
    didSet {
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

  /// The TextKit objects that lay out and draw the text.
  private let drawer = TextLabelDrawer()

  /// Whether the text storage still needs the text that the view was last set to, which it gets when the view lays out
  /// the text, see `fitTextContainer()`.
  private var textStorageNeedsText = false

  override public init(frame: CGRect) {
    super.init(frame: frame)

    #if canImport(AppKit)
    // the view subclasses `View` instead of `BaseView`, whose `layout()` has AppKit lay out a view each time it resizes,
    // while a label has nothing to lay out, so it takes `BaseView`'s settings itself
    updateCommonSettings()

    // ComposeUI moves and resizes label views as content scrolls, and observes none of their frames, so a label view
    // doesn't post a notification for each change
    postsFrameChangedNotifications = false
    #endif

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

  #if canImport(AppKit)
  override public var isFlipped: Bool { true }
  #endif

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
  /// Each paragraph is shown in the direction of its text, see `TextLabelDrawer.shownText(of:)`. A UIKit text view
  /// shows a link in a color instead of in TextKit's link style, which adds an underline, so on UIKit, each link shows
  /// in the link color, and the view records whether the text has a link, to show it again when the tint color changes,
  /// while an AppKit text view's link style is TextKit's.
  ///
  /// - Parameter text: The text that the view is set to show.
  /// - Returns: The text that the text storage shows.
  private func shownText(of text: NSAttributedString) -> NSAttributedString {
    let shownText = TextLabelDrawer.shownText(of: text)

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

  /// Marks the label to draw its text again: the drawing layer when the label draws in it, or else the view.
  private func setNeedsDisplayForText() {
    #if canImport(AppKit)
    // AppKit would display a marked view only to have `updateLayer()` mark the drawing layer, so a label that draws in
    // its layer marks the layer itself
    if drawsInLayer {
      drawingLayer?.setNeedsDisplay()
    } else {
      needsDisplay = true
    }
    #endif

    #if canImport(UIKit)
    setNeedsDisplay()
    #endif
  }

  /// Gives the text storage the text that the view was last set to.
  private func updateTextStorage() {
    textStorageNeedsText = false
    drawer.textStorage.setAttributedString(shownText(of: lastText))
  }

  /// Gives the text storage the text that the view was last set to, if the storage doesn't have it, before the text is
  /// laid out.
  private func updateTextStorageIfNeeded() {
    if textStorageNeedsText {
      updateTextStorage()
    }
  }

  /// Gives the drawer the text that the view was last set to, if the text storage doesn't have it, with the view's
  /// settings, and sizes the text container to the bounds inside the inset, where the text lays out.
  ///
  /// - Returns: Whether the container has room to show the text.
  @discardableResult
  private func fitTextContainer() -> Bool {
    let text = textStorageNeedsText ? shownText(of: lastText) : nil
    textStorageNeedsText = false
    return drawer.update(text: text, numberOfLines: numberOfLines, lineBreakMode: lineBreakMode, size: bounds.size, inset: textContainerInset)
  }

  /// Draws the text, laid out in the bounds inside the inset.
  func drawText() {
    fitTextContainer()
    drawer.drawText(size: bounds.size, inset: textContainerInset)
  }

  #if canImport(AppKit)

  // MARK: - Layer Drawing

  /// Whether the drawing layer draws the text, instead of AppKit drawing the view.
  ///
  /// AppKit draws a layer-backed view through a recording of its drawing, which takes more work than a layer that draws
  /// itself, but the two draw the same pixels only for the texts, sizes, coordinates and systems that the label drawing
  /// parity tests verify, so the label draws in the layer only for those, and leaves anything else to AppKit.
  ///
  /// The drawing layer stands in for the view's own drawing, so it follows what AppKit does with that drawing: it covers
  /// the bounds at the window's scale, sits below the layer's other sublayers, and draws again whenever AppKit would draw
  /// the view, which AppKit tells through `updateLayer()`. A change of the label's text, settings or size reaches the
  /// drawing layer directly instead, without AppKit displaying the view. It relies on code outside the label leaving the
  /// label's layer alone, as AppKit asks of a layer-backed view, since the layer's sublayers and transforms apply to a
  /// sublayer differently than to the layer's own contents.
  private var drawsInLayer = false

  /// The layer that draws the text when the label draws in a layer, made the first time it does.
  private var drawingLayer: DrawingLayer?

  /// Whether the text draws the same pixels in the drawing layer as through AppKit, see
  /// `NSAttributedString.drawsTheSameInALayer`, or `nil` before the label checks the text.
  private var textDrawsTheSameInALayer: Bool?

  /// The images that the compose view showing the label draws ahead of time for its labels, `nil` when no compose view
  /// shows the label, or its compose view doesn't draw ahead of time.
  weak var imageCache: TextLabelImageCache?

  /// The image that a worker drew ahead of time for the label's text, with the key that it was drawn for, which the
  /// drawing layer shows the next time it displays, instead of drawing the text.
  private var readyImage: (image: CGImage, key: TextLabelImageCache.Key)?

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

    // AppKit calls this instead of `draw(_:)` whenever the view needs drawing, for any reason, so the drawing layer draws
    // again here, whenever AppKit would draw the view
    drawingLayer?.setNeedsDisplay()
  }

  override public func draw(_ dirtyRect: NSRect) {
    drawText()
  }

  override public func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)

    boundsDidChange()
  }

  override public func setBoundsOrigin(_ newOrigin: NSPoint) {
    super.setBoundsOrigin(newOrigin)

    // AppKit tells the label of a moved bounds origin only here and in `translateOrigin(to:)`, unlike a scale or a
    // rotation of its coordinates, which changes its backing properties
    boundsDidChange()
  }

  override public func translateOrigin(to translation: NSPoint) {
    super.translateOrigin(to: translation)

    // translating the origin moves the bounds origin without going through `setBoundsOrigin(_:)`
    boundsDidChange()
  }

  override public func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    updateDrawingMode()
  }

  override public func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()

    // AppKit calls this for a new scale or color space of the window, and for a scale or a rotation of the label's
    // coordinates or an ancestor's
    boundsDidChange()
  }

  /// Moves the drawing layer to the bounds, and chooses again how the label draws, after a change of its bounds.
  private func boundsDidChange() {
    drawingLayer?.frame = bounds
    updateDrawingMode()
  }

  /// Chooses whether the drawing layer or AppKit draws the text, for the text, the size, the coordinates and the window.
  private func updateDrawingMode() {
    // out of a window, the label keeps how it draws, which saves switching for a reused label that leaves its window
    guard let window, let layer else {
      return
    }

    // the text comes last, since checking it reads each of its styles
    let scale = window.backingScaleFactor
    var drawsInLayer = Self.isLayerDrawingVerified && isSizeInWholePixels(scale: scale) && hasUnchangedCoordinates && textDrawsTheSame()
    #if DEBUG
    if let forcedDrawsInLayer {
      drawsInLayer = forcedDrawsInLayer
    }
    #endif

    if drawsInLayer {
      let drawingLayer = self.drawingLayer ?? makeDrawingLayer()
      if drawingLayer.superlayer !== layer {
        // AppKit draws the view into the layer's contents, below its sublayers, so the drawing layer goes below them too
        layer.insertSublayer(drawingLayer, at: 0)
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
    // the drawing layer draws again when its bounds change, so while the label draws in it, a resize doesn't mark the
    // view, which AppKit would display only to have `updateLayer()` mark the layer. AppKit's drawing of the text keeps
    // AppKit's default for a view that draws, which draws the view again during a resize animation
    layerContentsRedrawPolicy = drawsInLayer ? .onSetNeedsDisplay : .duringViewResize
    if drawsInLayer {
      drawingLayer?.isHidden = false
    } else {
      // AppKit draws the text, so the drawing layer hides, and lets its drawing go
      drawingLayer?.isHidden = true
      drawingLayer?.contents = nil
    }

    // AppKit draws the view again, through `draw(_:)`, or through `updateLayer()`, which clears what AppKit drew and
    // draws the drawing layer
    needsDisplay = true
  }

  /// Returns whether the text draws the same pixels in the drawing layer as through AppKit, checked once for each text.
  private func textDrawsTheSame() -> Bool {
    if let textDrawsTheSameInALayer {
      return textDrawsTheSameInALayer
    }

    // the text storage gives a substitute font to the characters that their font doesn't have, so the drawing is checked
    // on the text that the storage shows
    updateTextStorageIfNeeded()
    let drawsTheSame = drawer.textStorage.drawsTheSameInALayer
    textDrawsTheSameInALayer = drawsTheSame
    return drawsTheSame
  }

  // MARK: - Drawing Ahead of Time

  /// Takes the result of a worker's drawing for the label's new text, and keeps its image for the next display.
  ///
  /// A worker checks the text's styles as the label does, so the result also tells whether the text draws the same in
  /// the drawing layer.
  private func takeResultForText() {
    readyImage = nil
    textDrawsTheSameInALayer = nil

    guard let drawn = takeResultDrawnAhead() else {
      return
    }

    switch drawn.result {
    case .image(let image):
      textDrawsTheSameInALayer = true
      if let image {
        readyImage = (image, drawn.key)
      }
    case .drawnByAppKit:
      textDrawsTheSameInALayer = false
    }
  }

  /// Returns the image drawn ahead of time for the label's text, settings, size and window, which the drawing layer
  /// displays instead of drawing the text, and forgets it, `nil` if there's none.
  ///
  /// It's the image that the label took with its text, if it's still for them, or else the one that the image cache
  /// has for them, since AppKit has the label display again for reasons other than a new text, such as when a compose
  /// view reuses the label and moves it to another superview, or after its settings or size change.
  func takeImageToDisplay() -> CGImage? {
    let readyImage = self.readyImage
    self.readyImage = nil

    if let readyImage, readyImage.key == imageKey() {
      return readyImage.image
    } else {
      switch takeResultDrawnAhead()?.result {
      case .image(let image):
        return image
      case .drawnByAppKit,
           .none:
        return nil
      }
    }
  }

  /// Takes the result of a worker's drawing of the label's text, settings, size and window from the image cache, with
  /// the key that it was drawn for, `nil` if the cache has none.
  private func takeResultDrawnAhead() -> (result: TextLabelImageCache.Result, key: TextLabelImageCache.Key)? {
    guard let imageCache, let key = imageKey(), let result = imageCache.takeResult(for: key) else {
      return nil
    }
    return (result, key)
  }

  /// Returns the key of the image of the label's text, with its current settings, size and window, `nil` out of a
  /// window, or in a window without a color space.
  private func imageKey() -> TextLabelImageCache.Key? {
    guard let window, let environment = TextLabelImageCache.Environment.of(window: window, appearance: effectiveAppearance) else {
      return nil
    }
    return TextLabelImageCache.Key(
      text: lastText,
      size: bounds.size,
      numberOfLines: numberOfLines,
      lineBreakMode: lineBreakMode,
      inset: textContainerInset,
      environment: environment
    )
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

  /// Whether the label's coordinates are the window's, only moved to the label's place, which a layer draws in as AppKit
  /// does, while AppKit also draws a moved bounds origin, or a scale or a rotation of the label or of an ancestor, into
  /// the view's drawing.
  private var hasUnchangedCoordinates: Bool {
    bounds.origin == .zero && !isRotatedOrScaledFromBase
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
    return drawer.layoutManager.characterRange(forGlyphRange: drawer.layoutManager.glyphRange(for: drawer.textContainer), actualGlyphRange: nil)
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
    let glyphRange = drawer.layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
    let rect = drawer.layoutManager.boundingRect(forGlyphRange: glyphRange, in: drawer.textContainer)
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
    let index = drawer.layoutManager.characterIndex(for: containerPoint, in: drawer.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
    return (text.string as NSString).rangeOfComposedCharacterSequence(at: min(index, text.length - 1))
  }

  /// Returns the character ranges of the text's laid-out lines, from the first line.
  private func lineCharacterRanges() -> [NSRange] {
    guard fitTextContainer() else {
      return []
    }
    var lineRanges: [NSRange] = []
    let layoutManager = drawer.layoutManager
    layoutManager.enumerateLineFragments(forGlyphRange: layoutManager.glyphRange(for: drawer.textContainer)) { _, _, _, glyphRange, _ in
      lineRanges.append(layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil))
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
      updateTextStorage()
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
    // a view in the reuse pool doesn't lay out its text, so the text storage lets the old text go now
    updateTextStorageIfNeeded()
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
      host.drawer.textStorage
    }

    /// The layout manager that lays out the text.
    var layoutManager: NSLayoutManager {
      host.drawer.layoutManager
    }

    /// The text container that the text is laid out in.
    var textContainer: NSTextContainer {
      host.drawer.textContainer
    }

    /// Whether the text storage still needs the text that the view was last set to.
    var textStorageNeedsText: Bool {
      host.textStorageNeedsText
    }

    #if canImport(AppKit)
    /// The image drawn ahead of time that the drawing layer shows the next time it displays.
    var readyImage: CGImage? {
      host.readyImage?.image
    }

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

// MARK: - ClickThroughView

#if canImport(AppKit)
extension TextLabelView: ClickThroughView {}
#endif

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
