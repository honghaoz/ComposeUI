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
import CoreText

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

    if numberOfLines == 1 {
      return singleLineTextBoundingRectSize()
    }

    // === TextKit [BEGIN] ===

    let textStorage = NSTextStorage(attributedString: self)

    let layoutManager = NSLayoutManager()
    textStorage.addLayoutManager(layoutManager)

    let textContainer = NSTextContainer(size: CGSize(width: layoutWidth, height: .greatestFiniteMagnitude))
    textContainer.lineFragmentPadding = 0
    textContainer.maximumNumberOfLines = numberOfLines
    textContainer.lineBreakMode = lineBreakMode

    layoutManager.addTextContainer(textContainer)

    layoutManager.ensureLayout(for: textContainer)
    return layoutManager.usedRect(for: textContainer).size

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

  /// Returns single line text bounding box size in fractional size.
  ///
  /// For multiline text, only the first line size is returned.
  ///
  /// Ported from: https://github.com/honghaoz/ChouTiUI/blob/c2cc7b8452d269d6ee55993a977ed4b5fabf15d4/ChouTiUI/Sources/ChouTiUI/Universal/Text/TextSizeProvider.swift#L312
  ///
  /// - Returns: The bounding box for the text.
  private func singleLineTextBoundingRectSize() -> CGSize {
    let attributedString = self
    guard attributedString.length > 0 else {
      return .zero
    }

    let typesetter = CTTypesetterCreateWithAttributedString(attributedString)

    let count = CTTypesetterSuggestLineBreak(typesetter, 0, .greatestFiniteMagnitude)
    let range = CFRange(location: 0, length: count)
    let line = CTTypesetterCreateLine(typesetter, range)

    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    var leading: CGFloat = 0
    let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
    let height = ascent + descent + leading

    return CGSize(width: width, height: height)
  }

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
/// and the key object of an `NSCache`.
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
  private static var current: [Key: CGSize] = [:]

  /// The sizes of the generation before, which a lookup moves back to `current`.
  private static var previous: [Key: CGSize] = [:]

  /// Whether the cache empties itself when the system is low on memory.
  private static var isHandlingMemoryWarnings = false

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
  }
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
