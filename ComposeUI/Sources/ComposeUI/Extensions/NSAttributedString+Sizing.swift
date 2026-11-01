//
//  NSAttributedString+Sizing.swift
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

import Foundation

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

extension NSAttributedString {

  /// Calculate the bounding size of the attributed string.
  ///
  /// The text size is cached based on the attributed string and the layout parameters. Use `computeBoundingRectSize` to bypass the cache.
  /// The cache is used on the main thread only, where text is measured for layout, so call this method there.
  ///
  /// Related: https://github.com/honghaoz/ChouTiUI/blob/c2cc7b8452d269d6ee55993a977ed4b5fabf15d4/ChouTiUI/Sources/ChouTiUI/Universal/Text/TextSizeProvider.swift#L258
  ///
  /// - Parameters:
  ///   - numberOfLines: The number of lines to calculate the bounding size for. Use 0 for unlimited lines.
  ///   - layoutWidth: The width of the layout.
  ///   - lineBreakMode: The line break mode to use for the layout. Default is `byWordWrapping`.
  /// - Returns: The bounding size of the attributed string.
  func boundingRectSize(numberOfLines: Int, layoutWidth: CGFloat, lineBreakMode: NSLineBreakMode = .byWordWrapping) -> CGSize {
    guard self.length > 0 else {
      return .zero
    }

    // single-line sizing measures the natural, unwrapped line, so its size is independent of `layoutWidth` and `lineBreakMode`
    // see `computeBoundingRectSize` for more details.
    //
    // normalize `layoutWidth` and `lineBreakMode` so the same single-line text resolves to one cache entry regardless of width / mode.
    let keyLayoutWidth = numberOfLines == 1 ? 0 : layoutWidth
    let keyLineBreakMode: NSLineBreakMode = numberOfLines == 1 ? .byWordWrapping : lineBreakMode

    let key = TextSizeCache.Key(attributedString: self, numberOfLines: numberOfLines, layoutWidth: keyLayoutWidth, lineBreakMode: keyLineBreakMode)
    if let size = TextSizeCache.size(for: key) {
      return size
    }

    let size = computeBoundingRectSize(numberOfLines: numberOfLines, layoutWidth: layoutWidth, lineBreakMode: lineBreakMode)

    // a caller can pass an `NSMutableAttributedString` and change it later, which would change a stored key's hash and
    // equality in place, which a dictionary doesn't allow, so the stored key holds an immutable copy, which `copy()`
    // makes only of a mutable text
    let storedText = (copy() as? NSAttributedString) ?? self
    TextSizeCache.insert(size, for: TextSizeCache.Key(attributedString: storedText, numberOfLines: numberOfLines, layoutWidth: keyLayoutWidth, lineBreakMode: keyLineBreakMode))

    return size
  }

  /// Calculate the bounding size of the attributed string. No cache is used.
  ///
  /// - Parameters:
  ///   - numberOfLines: The number of lines to calculate the bounding size for. Use 0 for unlimited lines.
  ///   - layoutWidth: The width of the layout.
  ///   - lineBreakMode: The line break mode to use for the layout. Default is `byWordWrapping`.
  /// - Returns: The bounding size of the attributed string.
  func computeBoundingRectSize(numberOfLines: Int, layoutWidth: CGFloat, lineBreakMode: NSLineBreakMode = .byWordWrapping) -> CGSize {
    guard self.length > 0 else {
      return .zero
    }

    #if DEBUG
    WorkCounter.count(.textMeasurement)
    #endif

    // === TextKit [BEGIN] ===

    // one line is measured unwrapped, so its size doesn't depend on the layout width or the line break mode, which the
    // cache leaves out of its key
    let layoutWidth = numberOfLines == 1 ? .greatestFiniteMagnitude : layoutWidth
    let lineBreakMode = numberOfLines == 1 ? .byWordWrapping : lineBreakMode

    // a paragraph's writing direction changes how its lines are laid out, so the text is measured with the directions
    // that text views lay it out with
    #if canImport(UIKit)
    let text = resolvingNaturalWritingDirections().recordingOriginalFonts()
    #else
    let text = resolvingNaturalWritingDirections()
    #endif

    return TextMeasuringSystem.size(of: text, numberOfLines: numberOfLines, layoutWidth: layoutWidth, lineBreakMode: lineBreakMode)

    // === TextKit [END] ===

    //    let sanitizedLineBreakMode: NSLineBreakMode
    //    switch lineBreakMode {
    //    case .byClipping,
    //         .byTruncatingTail,
    //         .byTruncatingHead,
    //         .byTruncatingMiddle:
    //      sanitizedLineBreakMode = .byWordWrapping
    //    default:
    //      sanitizedLineBreakMode = lineBreakMode
    //    }
    //
    //    let attributedString = self.adjustingLineBreakMode(sanitizedLineBreakMode)
    //    guard attributedString.length > 0 else {
    //      return .zero
    //    }
    //
    //    if numberOfLines == 1 {
    //      return singleLineTextBoundingRectSize()
    //    }

    // === CTTypesetter [BEGIN] ===
    //
    //    let typesetter = CTTypesetterCreateWithAttributedString(attributedString)
    //    var index = 0
    //    var lineIndex = 0
    //    var maxWidth: CGFloat = 0
    //    var totalHeight: CGFloat = 0
    //
    //    while index < attributedString.length {
    //      let count = CTTypesetterSuggestLineBreak(typesetter, index, Double(layoutWidth))
    //      let range = CFRange(location: index, length: count)
    //      let line = CTTypesetterCreateLine(typesetter, range)
    //
    //      var ascent: CGFloat = 0
    //      var descent: CGFloat = 0
    //      var leading: CGFloat = 0
    //      let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
    //
    //      maxWidth = max(maxWidth, width)
    //      totalHeight += ascent + descent + leading
    //
    //      lineIndex += 1
    //      if lineIndex >= numberOfLines && numberOfLines > 0 {
    //        break
    //      }
    //
    //      index += count
    //    }
    //
    //    return CGSize(width: maxWidth, height: totalHeight)
    //
    // === CTTypesetter [END] ===

    // === CTFramesetter [BEGIN] ===
    //
    //    let framesetter = CTFramesetterCreateWithAttributedString(attributedString as CFAttributedString)
    //    let frameHeight: CGFloat = 1000000000
    //    let path = CGPath(rect: CGRect(x: 0, y: 0, width: layoutWidth, height: frameHeight), transform: nil)
    //
    //    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
    //
    //    guard let lines = CTFrameGetLines(frame) as? [CTLine], lines.count > 0 else {
    //      ComposeUI.assertFailure("failed to get non-empty lines")
    //      return .zero
    //    }
    //
    //    let linesCount = lines.count
    //
    //    let endLineIndex: Int
    //    if numberOfLines <= 0 || numberOfLines >= linesCount {
    //      endLineIndex = linesCount - 1
    //    } else {
    //      endLineIndex = numberOfLines - 1
    //    }
    //
    //    #if canImport(AppKit)
    //    var lineOrigins = [CGPoint](repeating: .zero, count: linesCount)
    //    CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &lineOrigins)
    //    let lineOriginYs = lineOrigins.map { frameHeight - $0.y }
    //
    //    /// the origin is relative to the bottom left corner of the path bounding box.
    //    let endLineOrigin = lineOriginYs[endLineIndex]
    //
    //    let endLine = lines[endLineIndex]
    //    var endLineDescent: CGFloat = 0
    //    var endLineLeading: CGFloat = 0
    //    _ = CTLineGetTypographicBounds(endLine, nil, &endLineDescent, &endLineLeading)
    //    let endLineBottom = endLineOrigin + endLineDescent + endLineLeading
    //
    //    let maxWidth = lines.map { line in CTLineGetTypographicBounds(line, nil, nil, nil) }.max()!
    //    return CGSize(width: maxWidth, height: endLineBottom)
    //    #else
    //    var maxWidth: CGFloat = 0
    //    var totalHeight: CGFloat = 0
    //    for i in 0 ... endLineIndex {
    //      let line = lines[i]
    //      var ascent: CGFloat = 0
    //      var descent: CGFloat = 0
    //      var leading: CGFloat = 0
    //      let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
    //      let lineHeight = ascent + descent + leading
    //
    //      maxWidth = max(maxWidth, width)
    //      totalHeight += lineHeight
    //    }
    //    return CGSize(width: maxWidth, height: totalHeight)
    //    #endif
    //
    // === CTFramesetter [END] ===
  }

  #if canImport(UIKit)
  /// The attribute that UIKit text views record a run's font in when they give its characters a substitute font, which
  /// isn't public.
  private static let originalFontKey = NSAttributedString.Key("NSOriginalFont")

  /// The font that TextKit lays out a run without a font in.
  private static let defaultFont: Font? = {
    // TextKit gives the font to such a run when it fixes the text's attributes. it's read from TextKit instead of named,
    // since the default that the font attribute documents, 12 point Helvetica or Helvetica Neue, has differed between
    // systems
    let text = NSMutableAttributedString(string: "a")
    text.fixAttributes(in: NSRange(location: 0, length: text.length))
    return text.attribute(.font, at: 0, effectiveRange: nil) as? Font
  }()

  /// Returns the text with a substitute font given to each character that its font doesn't have, and the font recorded
  /// for each run that gets one, as UIKit text views record it.
  ///
  /// The layout takes a run's line height from its recorded font instead of its substitute font, so a UIKit text view
  /// lays out a line of characters that its font doesn't have, such as Devanagari in the system font, as tall as the
  /// font's lines.
  func recordingOriginalFonts() -> NSAttributedString {
    let fixedText = NSMutableAttributedString(attributedString: self)
    let range = NSRange(location: 0, length: fixedText.length)
    fixedText.fixAttributes(in: range)
    enumerateAttribute(.font, in: range) { value, runRange, _ in
      guard let font = (value as? Font) ?? Self.defaultFont else {
        return
      }
      fixedText.enumerateAttribute(.font, in: runRange) { fixedValue, fixedRange, _ in
        if let fixedFont = fixedValue as? Font, fixedFont != font {
          fixedText.addAttribute(Self.originalFontKey, value: font, range: fixedRange)
        }
      }
    }
    return fixedText
  }
  #endif

  //  /// Adjust the line break mode of the attributed string.
  //  ///
  //  /// The CoreText (`CTFrameGetLines`) returns decreased number of lines (`CTLine`) if the attributed string has
  //  /// paragraph style with the `lineBreakMode` set to truncating mode such as `.byClipping`, `.byTruncatingTail`,
  //  /// `.byTruncatingHead` or `.byTruncatingMiddle`. In this case, each line can have two `CTRun`s.
  //  ///
  //  /// With `byWordWrapping` or `byCharWrapping` line break mode, CoreText can return correct lines with each line have
  //  /// one `CTRun`.
  //  ///
  //  /// This method returns the attributed string as is if no paragraph style with different line break mode is found.
  //  /// Otherwise, it will return a new attributed string with the updated line break mode.
  //  ///
  //  /// - Parameter lineBreakMode: The line break mode to set.
  //  /// - Returns: An attributed string with the updated line break mode.
  //  private func adjustingLineBreakMode(_ lineBreakMode: NSLineBreakMode) -> NSAttributedString {
  //    var needsAdjustment = false
  //    var rangesToUpdate: [(NSRange, NSParagraphStyle)] = []
  //
  //    // first pass: check if any adjustments are needed and collect ranges
  //    enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
  //      if let paragraphStyle = value as? NSParagraphStyle, paragraphStyle.lineBreakMode != lineBreakMode {
  //        needsAdjustment = true
  //        rangesToUpdate.append((range, paragraphStyle))
  //      }
  //    }
  //
  //    // return original if no changes are needed
  //    guard needsAdjustment else {
  //      return self
  //    }
  //
  //    // second pass: apply changes efficiently
  //    let mutableCopy = NSMutableAttributedString(attributedString: self)
  //
  //    for (range, originalStyle) in rangesToUpdate {
  //      guard let newParagraphStyle = originalStyle.mutableCopy() as? NSMutableParagraphStyle else {
  //        continue
  //      }
  //      newParagraphStyle.lineBreakMode = lineBreakMode
  //      mutableCopy.addAttribute(.paragraphStyle, value: newParagraphStyle, range: range)
  //    }
  //
  //    return mutableCopy
  //  }
}

// MARK: - Text Measuring System

/// A TextKit 1 text system that measures texts as text views lay them out.
///
/// On the main thread, where text is measured for layout, one text system measures one text after another, which
/// allocates less than half as much as a new text system for each text. It keeps the last text it measures until the
/// end of the run loop turn, instead of until the next measurement, so that it doesn't keep the objects that a text's
/// attributes hold, such as an attachment's image, after the layout that measures the text.
private final class TextMeasuringSystem {

  /// The text system that measures texts on the main thread, `nil` while it measures one, so that a measurement inside
  /// another, such as one that a custom attachment makes for its bounds, uses a new text system.
  private static var main: TextMeasuringSystem? = TextMeasuringSystem()

  /// Whether the main text system removes its text at the end of the run loop turn.
  private static var isTextRemovalScheduled = false

  private let textStorage = NSTextStorage()
  private let layoutManager = NSLayoutManager()
  private let textContainer = NSTextContainer(size: .zero)

  /// Creates a text system that measures texts.
  init() {
    textStorage.addLayoutManager(layoutManager)
    textContainer.lineFragmentPadding = 0
    layoutManager.addTextContainer(textContainer)
  }

  /// Returns the size that a text lays out in, measured in the main text system on the main thread, and in a new text
  /// system elsewhere.
  ///
  /// - Parameters:
  ///   - text: The text to measure, with the writing directions and the fonts that text views lay it out with.
  ///   - numberOfLines: The number of lines to lay out. Use 0 for unlimited lines.
  ///   - layoutWidth: The width of the layout.
  ///   - lineBreakMode: The line break mode to use for the layout.
  /// - Returns: The size that the text lays out in.
  static func size(of text: NSAttributedString, numberOfLines: Int, layoutWidth: CGFloat, lineBreakMode: NSLineBreakMode) -> CGSize {
    guard Thread.isMain, let system = main else {
      return TextMeasuringSystem().size(of: text, numberOfLines: numberOfLines, layoutWidth: layoutWidth, lineBreakMode: lineBreakMode)
    }

    main = nil
    defer {
      main = system
    }

    if !isTextRemovalScheduled {
      isTextRemovalScheduled = true
      onNextRunLoop {
        system.removeText()
        isTextRemovalScheduled = false
      }
    }

    return system.size(of: text, numberOfLines: numberOfLines, layoutWidth: layoutWidth, lineBreakMode: lineBreakMode)
  }

  /// Returns the size that a text lays out in, measured in this text system.
  ///
  /// - Parameters:
  ///   - text: The text to measure, with the writing directions and the fonts that text views lay it out with.
  ///   - numberOfLines: The number of lines to lay out. Use 0 for unlimited lines.
  ///   - layoutWidth: The width of the layout.
  ///   - lineBreakMode: The line break mode to use for the layout.
  /// - Returns: The size that the text lays out in.
  func size(of text: NSAttributedString, numberOfLines: Int, layoutWidth: CGFloat, lineBreakMode: NSLineBreakMode) -> CGSize {
    textContainer.size = CGSize(width: layoutWidth, height: .greatestFiniteMagnitude)
    textContainer.maximumNumberOfLines = numberOfLines
    layoutManager.setLineBreakMode(lineBreakMode, in: textContainer)
    textStorage.setAttributedString(text)
    layoutManager.ensureLayout(for: textContainer)

    // the width is the widest line's glyphs and its paragraph's indents, which the line needs to keep its line breaks,
    // instead of the span of the lines, which also has the offsets that alignments give lines in the layout width, such
    // as a right-to-left paragraph's lines at its right edge. the lines are read in a loop instead of with
    // `enumerateLineFragments(forGlyphRange:using:)`, whose block would box each variable that it changes
    let string: CFString = CFAttributedStringGetString(textStorage)
    let glyphEnd = NSMaxRange(layoutManager.glyphRange(for: textContainer))
    var glyphIndex = 0
    var paragraphStart = 0
    var paragraphEnd = 0
    var paragraphStyle = NSParagraphStyle.default
    var width: CGFloat = 0
    while glyphIndex < glyphEnd {
      var lineGlyphRange = NSRange()
      let usedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
      let lineStart = layoutManager.characterIndexForGlyph(at: lineGlyphRange.location)
      if lineStart >= paragraphEnd {
        // the lines come in order, so a paragraph's bounds are found from its first line
        CFStringGetParagraphBounds(string, CFRange(location: lineStart, length: 0), &paragraphStart, &paragraphEnd, nil)
        paragraphStyle = textStorage.attribute(.paragraphStyle, at: paragraphStart, effectiveRange: nil) as? NSParagraphStyle ?? .default
      }
      let headIndent = lineStart == paragraphStart ? paragraphStyle.firstLineHeadIndent : paragraphStyle.headIndent
      // a negative tail indent insets the line from the trailing edge, while a positive one is a distance from the
      // leading edge, which needs no room past the line's glyphs
      let tailInset = max(-paragraphStyle.tailIndent, 0)
      width = max(width, headIndent + usedRect.width + tailInset)
      glyphIndex = NSMaxRange(lineGlyphRange)
    }
    return CGSize(width: width, height: layoutManager.usedRect(for: textContainer).height)
  }

  /// Removes the text system's text, which lets the objects that its attributes hold go.
  private func removeText() {
    textStorage.setAttributedString(NSAttributedString())
  }
}

// MARK: - Text Size Cache

extension NSAttributedString {

  /// Removes all cached text sizes.
  static func clearTextSizeCache() {
    TextSizeCache.removeAll()
  }
}

/// The sizes that `NSAttributedString.boundingRectSize` measures, keyed by the text and the layout settings that a size
/// depends on.
///
/// The cache keeps two generations of sizes, each of up to `generationLimit` sizes, and empties itself when the system
/// is low on memory.
///
/// Text is measured for layout on the main thread, so the cache is only used there, which lets a lookup skip the lock
/// and the key object of an `NSCache`. Its state skips the runtime's exclusivity checks: no access to it calls the
/// framework's code that reaches the cache, so no two accesses overlap, which the compiler can't prove past the calls
/// inside them. An assignment releases what it replaces only after writing the new value, so a deinitializer that it
/// runs sees the new value. A lookup calls the texts' hashing and equality, so a text or an attribute whose hashing or
/// equality measures text would make accesses overlap, which isn't supported.
enum TextSizeCache {

  /// The text and the layout settings that a text's size depends on.
  struct Key: Hashable {

    let attributedString: NSAttributedString
    let numberOfLines: Int
    let layoutWidth: CGFloat
    let lineBreakMode: NSLineBreakMode

    static func == (lhs: Key, rhs: Key) -> Bool {
      // the settings are compared before the text, since they're cheaper, and the text's object before its contents,
      // since a node measures the same text object on each layout
      lhs.numberOfLines == rhs.numberOfLines
        && lhs.layoutWidth == rhs.layoutWidth
        && lhs.lineBreakMode == rhs.lineBreakMode
        && (lhs.attributedString === rhs.attributedString || lhs.attributedString.isEqual(rhs.attributedString))
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(attributedString)
      hasher.combine(numberOfLines)
      hasher.combine(layoutWidth)
      hasher.combine(lineBreakMode.rawValue)
    }
  }

  /// The most sizes that one generation holds.
  static let generationLimit = 4096

  /// The sizes looked up since the generations last rotated.
  @exclusivity(unchecked) private static var current: [Key: CGSize] = [:]

  /// The sizes of the generation before, which a lookup moves back to `current`.
  @exclusivity(unchecked) private static var previous: [Key: CGSize] = [:]

  /// Whether the cache empties itself when the system is low on memory.
  @exclusivity(unchecked) private static var isHandlingMemoryWarnings = false

  /// Returns the size stored for the key, if any.
  ///
  /// - Parameter key: The text and the layout settings.
  /// - Returns: The stored size, or `nil` if there's none.
  static func size(for key: Key) -> CGSize? {
    if let size = current[key] {
      return size
    }
    guard let index = previous.index(forKey: key) else {
      return nil
    }
    // the entry moves with its stored key, which holds an immutable text, instead of the lookup's key
    let entry = previous.remove(at: index)
    insert(entry.value, for: entry.key)
    return entry.value
  }

  /// Stores the size for the key.
  ///
  /// - Parameters:
  ///   - size: The size to store.
  ///   - key: The text, which must be immutable, and the layout settings.
  static func insert(_ size: CGSize, for key: Key) {
    if !isHandlingMemoryWarnings {
      isHandlingMemoryWarnings = true
      MemoryWarning.addHandler(removeAll)
    }

    if current.count >= generationLimit {
      // two generations keep the sizes used since the generation before, where one dictionary emptied when full would
      // drop the sizes that the next layout measures again
      previous = current
      current.removeAll(keepingCapacity: true)
    }
    current[key] = size
  }

  /// Removes all sizes.
  static func removeAll() {
    current = [:]
    previous = [:]
    clearCount += 1
  }

  /// The number of times the cache was emptied, so that a size kept outside the cache is measured again after it.
  @exclusivity(unchecked) private(set) static var clearCount = 0
}

// Notes on CoreText API:
//
// 1. CTFramesetterSuggestFrameSizeWithConstraints:
//    CTFramesetterSuggestFrameSizeWithConstraints is NOT accurate for multiline text.
//    It may return a height that is not enough to contain the text.
// 2. CTFrameGetLineOrigins:
//    CTFrameGetLineOrigins is NOT precise. The baseline origins retutned are snapped to an integral “pixel grid” in user space (points).
//    The intergral points may result in a height that is either too small or too large.
//    Based on my testing, CTFrameGetLineOrigins provides a better origins on macOS than iOS.
// 3. CTLineGetTypographicBounds:
//    CTLineGetTypographicBounds is precise. It returns the exact bounds of the line, with line ascent, descent, and leading.
//
// CTTypesetter vs. CTFramesetter:
// 1. CTTypesetter:
//    CTTypesetter is the lowest-level line-breaking engine.
//    Given an attributed string, it can break text into lines that fit a given width.
//    CTTypesetter is like a “word wrapping” helper, it just tells you where the line breaks should be, not how to position the lines.
//
//    CTTypesetterSuggestLineBreak vs CTTypesetterSuggestClusterBreak:
//    a. CTTypesetterSuggestLineBreak:
//       It breaks the text into lines that fit a given width at "word" level.
//    b. CTTypesetterSuggestClusterBreak:
//       It breaks the text into lines that fit a given width at "character" level.
//
// 2. CTFramesetter:
//    CTFramesetter is a higher-level layout object that sits on top of CTTypesetter.
//    Given an attributed string and a path (CGPath), it lays out the text automatically to fill the shape.
//    CTFramesetter is like a “full layout manager”, you give it the box, it fills it with text according to Core Text’s rules.
//
// References:
// - https://stackoverflow.com/a/3956161/3164091
// - https://chatgpt.com/share/68a0affc-8db0-8009-b0e3-62f5d7860bb2
