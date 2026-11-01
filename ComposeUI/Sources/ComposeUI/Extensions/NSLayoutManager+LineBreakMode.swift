//
//  NSLayoutManager+LineBreakMode.swift
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

  /// Lays out the text in a text container with a line break mode, as a label does: `.byCharWrapping` breaks every
  /// line between characters, and the other modes set how the last line ends.
  ///
  /// While the line break mode is `.byCharWrapping`, the layout manager's delegate breaks the lines, so the layout
  /// manager must have no other delegate.
  ///
  /// - Parameters:
  ///   - lineBreakMode: The line break mode.
  ///   - textContainer: The text container, one of the layout manager's.
  func setLineBreakMode(_ lineBreakMode: NSLineBreakMode, in textContainer: NSTextContainer) {
    // TextKit takes a text container's line break mode as the way the last line ends. character wrapping is a way to
    // break every line instead, so for it, the container keeps word wrapping, and the delegate makes the lines break
    // between characters. a container with character wrapping would break the lines between words when the text has
    // no line limit, and with one, lay out the rest of the last line's paragraph past the limit
    let wrapsCharacters = lineBreakMode == .byCharWrapping
    let isDelegateChanged: Bool
    if wrapsCharacters {
      isDelegateChanged = delegate !== CharacterWrappingDelegate.shared
      if isDelegateChanged {
        ComposeUI.assert(delegate == nil, "a layout manager that breaks its lines between characters must have no other delegate")
        delegate = CharacterWrappingDelegate.shared
      }
    } else {
      isDelegateChanged = delegate === CharacterWrappingDelegate.shared
      if isDelegateChanged {
        delegate = nil
      }
    }

    let containerLineBreakMode: NSLineBreakMode = wrapsCharacters ? .byWordWrapping : lineBreakMode
    if textContainer.lineBreakMode != containerLineBreakMode {
      textContainer.lineBreakMode = containerLineBreakMode
    } else if isDelegateChanged {
      // a new delegate doesn't lay out and draw the text again, as a new line break mode of the container does. the
      // display is invalidated first, since it's invalidated only where the text is laid out, and without it, an AppKit
      // text view without background layout would keep its old lines on screen until something lays out the text
      invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textStorage?.length ?? 0))
      textContainerChangedGeometry(textContainer)
    }
  }
}

extension NSLineBreakMode {

  /// The line break mode that a text laid out with this line break mode is measured with: `.byCharWrapping` itself,
  /// and `.byWordWrapping` for the other modes, which break the lines before the last one as word wrapping does.
  var measuringLineBreakMode: NSLineBreakMode {
    self == .byCharWrapping ? .byCharWrapping : .byWordWrapping
  }
}

/// A layout manager delegate that breaks the lines between characters.
private final class CharacterWrappingDelegate: NSObject, NSLayoutManagerDelegate {

  /// The delegate of every layout manager that breaks its lines between characters, as it keeps no state.
  static let shared = CharacterWrappingDelegate()

  func layoutManager(_ layoutManager: NSLayoutManager, shouldBreakLineByWordBeforeCharacterAt charIndex: Int) -> Bool {
    // a line that may not break between words breaks between characters
    false
  }
}
