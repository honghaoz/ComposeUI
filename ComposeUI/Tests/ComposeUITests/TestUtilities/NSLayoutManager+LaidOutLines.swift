//
//  NSLayoutManager+LaidOutLines.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/31/26.
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

extension NSLayoutManager {

  /// Returns the text of each line that the layout manager lays out in a text container, from the first line, as the
  /// line shows it: a truncated line shows "…" in place of the characters that it hides.
  ///
  /// The text must not have characters that TextKit hides for other reasons, such as a zero-width joiner, which would
  /// read as a truncation.
  ///
  /// - Parameter textContainer: The text container.
  /// - Returns: The text of each line, with the line break that ends it.
  func laidOutLines(in textContainer: NSTextContainer) -> [String] {
    guard let text = textStorage?.string as NSString? else {
      return []
    }
    var lines: [String] = []
    enumerateLineFragments(forGlyphRange: glyphRange(for: textContainer)) { _, _, _, lineGlyphRange, _ in
      let lineRange = self.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
      guard let hiddenGlyphRange = self.hiddenGlyphRange(in: lineGlyphRange) else {
        lines.append(text.substring(with: lineRange))
        return
      }
      // TextKit hides the truncated glyphs and draws "…" in the glyph just before them. `truncatedGlyphRange(inLineFragmentForGlyphAt:)`
      // would only find a truncated tail, not a truncated head or middle
      let truncatedGlyphRange = NSRange(location: hiddenGlyphRange.location - 1, length: hiddenGlyphRange.length + 1)
      let truncatedRange = self.characterRange(forGlyphRange: truncatedGlyphRange, actualGlyphRange: nil)
      let head = text.substring(with: NSRange(location: lineRange.location, length: truncatedRange.location - lineRange.location))
      let tail = text.substring(with: NSRange(location: NSMaxRange(truncatedRange), length: NSMaxRange(lineRange) - NSMaxRange(truncatedRange)))
      lines.append(head + "…" + tail)
    }
    return lines
  }

  /// Returns the range of the glyphs that a truncated line hides, `nil` for a line that hides none.
  private func hiddenGlyphRange(in lineGlyphRange: NSRange) -> NSRange? {
    var start = NSNotFound
    var end = NSNotFound
    var glyphIndex = lineGlyphRange.location
    while glyphIndex < NSMaxRange(lineGlyphRange) {
      if propertyForGlyph(at: glyphIndex).contains(.null) {
        if start == NSNotFound {
          start = glyphIndex
        }
        end = glyphIndex
      }
      glyphIndex += 1
    }
    // a hidden glyph at the start of the line has no glyph before it to draw "…" in, so it isn't a truncation
    guard start != NSNotFound, start > lineGlyphRange.location else {
      return nil
    }
    return NSRange(location: start, length: end - start + 1)
  }
}
