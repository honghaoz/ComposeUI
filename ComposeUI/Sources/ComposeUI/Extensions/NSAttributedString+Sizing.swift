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

extension NSAttributedString {

  /// Calculate the bounding size of the attributed string.
  ///
  /// Ported from https://github.com/honghaoz/ChouTiUI/blob/c2cc7b8452d269d6ee55993a977ed4b5fabf15d4/ChouTiUI/Sources/ChouTiUI/Universal/Text/TextSizeProvider.swift#L258
  ///
  /// - Parameters:
  ///   - numberOfLines: The number of lines to calculate the bounding size for. Use 0 for unlimited lines.
  ///   - layoutWidth: The width of the layout. For single line text, the smaller of the layout width and the text's intrinsic size is returned.
  /// - Returns: The bounding size of the attributed string.
  func boundingRectSize(numberOfLines: Int, layoutWidth: CGFloat) -> CGSize {
    let attributedString = self
    guard attributedString.length > 0 else {
      return .zero
    }

    if numberOfLines == 1 {
      return singleLineTextBoundingRectSize(layoutWidth: layoutWidth)
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
  /// - Parameters:
  ///   - layoutWidth: The proposing layout width. This width determines the final size's width if it is smaller than the text's intrinsic size.
  /// - Returns: The bounding box for the text.
  private func singleLineTextBoundingRectSize(layoutWidth: CGFloat = .greatestFiniteMagnitude) -> CGSize {
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

    return CGSize(width: min(width, layoutWidth), height: lineBottom)
  }
}
