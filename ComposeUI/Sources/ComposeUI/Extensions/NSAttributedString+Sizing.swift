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
  /// Ported from https://github.com/honghaoz/ChouTiUI/blob/c2cc7b8452d269d6ee55993a977ed4b5fabf15d4/ChouTiUI/Sources/ChouTiUI/Universal/Text/TextSizeProvider.swift#L258
  ///
  /// - Parameters:
  ///   - numberOfLines: The number of lines to calculate the bounding size for. Use 0 for unlimited lines.
  ///   - layoutWidth: The width of the layout.
  ///   - lineBreakMode: The line break mode to use for the layout. The line break mode should be either `byWordWrapping` or `byCharWrapping`. Default is `byWordWrapping`.
  /// - Returns: The bounding size of the attributed string.
  func boundingRectSize(numberOfLines: Int, layoutWidth: CGFloat, lineBreakMode: NSLineBreakMode = .byWordWrapping) -> CGSize {
    let sanitizedLineBreakMode: NSLineBreakMode
    switch lineBreakMode {
    case .byClipping,
         .byTruncatingTail,
         .byTruncatingHead,
         .byTruncatingMiddle:
      sanitizedLineBreakMode = .byWordWrapping
    default:
      sanitizedLineBreakMode = lineBreakMode
    }

    let attributedString = self.adjustingLineBreakMode(sanitizedLineBreakMode)
    guard attributedString.length > 0 else {
      return .zero
    }

    if numberOfLines == 1 {
      return singleLineTextBoundingRectSize()
    }

    let framesetter = CTFramesetterCreateWithAttributedString(attributedString as CFAttributedString)
    let frameHeight: CGFloat = 1000000000
    let path = CGPath(rect: CGRect(x: 0, y: 0, width: layoutWidth, height: frameHeight), transform: nil)

    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)

    guard let lines = CTFrameGetLines(frame) as? [CTLine], lines.count > 0 else {
      ComposeUI.assertFailure("failed to get non-empty lines")
      return .zero
    }

    let linesCount = lines.count

    let endLineIndex: Int
    if numberOfLines <= 0 || numberOfLines >= linesCount {
      endLineIndex = linesCount - 1
    } else {
      endLineIndex = numberOfLines - 1
    }

    var lineOrigins = [CGPoint](repeating: .zero, count: linesCount)
    CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &lineOrigins)
    let lineOriginYs = lineOrigins.map { frameHeight - $0.y }

    /// the origin is relative to the bottom left corner of the path bounding box.
    let endLineOrigin = lineOriginYs[endLineIndex]

    let endLine = lines[endLineIndex]
    var endLineDescent: CGFloat = 0
    var endLineLeading: CGFloat = 0
    _ = CTLineGetTypographicBounds(endLine, nil, &endLineDescent, &endLineLeading)
    let endLineBottom = endLineOrigin + endLineDescent + endLineLeading

    // swiftlint:disable:next force_unwrapping
    let maxWidth = lines.map { CTLineGetBoundsWithOptions($0, []).width }.max()!
    return CGSize(width: maxWidth, height: endLineBottom)
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

    let framesetter = CTFramesetterCreateWithAttributedString(attributedString as CFAttributedString)
    let frameWidth: CGFloat = 1e9
    let frameHeight: CGFloat = 1e9
    let path = CGPath(rect: CGRect(x: 0, y: 0, width: frameWidth, height: frameHeight), transform: nil)

    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)

    guard let lines = CTFrameGetLines(frame) as? [CTLine], lines.count > 0 else {
      ComposeUI.assertFailure("failed to get non-empty lines")
      return .zero
    }

    let linesCount = lines.count
    var lineOrigins = [CGPoint](repeating: .zero, count: linesCount)
    CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &lineOrigins)
    let lineOriginY = frameHeight - lineOrigins[0].y

    let line = lines[0] // only take the first line size
    var descent: CGFloat = 0
    var leading: CGFloat = 0
    let width = CTLineGetTypographicBounds(line, nil, &descent, &leading)
    let lineBottom = lineOriginY + descent + leading

    return CGSize(width: width, height: lineBottom)
  }

  /// Adjust the line break mode of the attributed string.
  ///
  /// The CoreText (`CTFrameGetLines`) returns decreased number of lines (`CTLine`) if the attributed string has
  /// paragraph style with the `lineBreakMode` set to truncating mode such as `.byClipping`, `.byTruncatingTail`,
  /// `.byTruncatingHead` or `.byTruncatingMiddle`. In this case, each line can have two `CTRun`s.
  ///
  /// With `byWordWrapping` or `byCharWrapping` line break mode, CoreText can return correct lines with each line have
  /// one `CTRun`.
  ///
  /// This method returns the attributed string as is if no paragraph style with different line break mode is found.
  /// Otherwise, it will return a new attributed string with the updated line break mode.
  ///
  /// - Parameter lineBreakMode: The line break mode to set.
  /// - Returns: An attributed string with the updated line break mode.
  private func adjustingLineBreakMode(_ lineBreakMode: NSLineBreakMode) -> NSAttributedString {
    var needsAdjustment = false
    var rangesToUpdate: [(NSRange, NSParagraphStyle)] = []

    // first pass: check if any adjustments are needed and collect ranges
    enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
      if let paragraphStyle = value as? NSParagraphStyle, paragraphStyle.lineBreakMode != lineBreakMode {
        needsAdjustment = true
        rangesToUpdate.append((range, paragraphStyle))
      }
    }

    // return original if no changes are needed
    guard needsAdjustment else {
      return self
    }

    // second pass: apply changes efficiently
    let mutableCopy = NSMutableAttributedString(attributedString: self)

    for (range, originalStyle) in rangesToUpdate {
      guard let newParagraphStyle = originalStyle.mutableCopy() as? NSMutableParagraphStyle else {
        continue
      }
      newParagraphStyle.lineBreakMode = lineBreakMode
      mutableCopy.addAttribute(.paragraphStyle, value: newParagraphStyle, range: range)
    }

    return mutableCopy
  }
}
