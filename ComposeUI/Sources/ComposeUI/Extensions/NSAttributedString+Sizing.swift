//
//  NSAttributedString+Sizing.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/23/25.
//

import Foundation
import CoreText
import UIKit

extension NSAttributedString {

  /// Calculate the bounding size of the attributed string.
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

    if numberOfLines == 1 {
      return singleLineTextBoundingRectSize()
    }

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
  }

  /// Returns single line text bounding box size in fractional size.
  ///
  /// For multiline text, only the first line size is returned.
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
}
