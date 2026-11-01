//
//  ScrollDocumentView.swift
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

/// The view that holds a scroll view's content, which takes the keyboard focus while the arrow and page keys can scroll
/// the scroll view.
///
/// AppKit gives a scroll view's keyboard focus to its document view, so that the keys reach the scroll view through the
/// document view.
class ScrollDocumentView: BaseView {

  override var acceptsFirstResponder: Bool {
    (enclosingScrollView as? ScrollView)?.canScrollWithKeyboard == true
  }

  override var canBecomeKeyView: Bool {
    // the content takes the focus from a click or from code, but stays out of the key view loop, since AppKit gives the
    // focus to the loop's first view when a window opens, which would take it from the window's first text field
    false
  }

  override func willRemoveSubview(_ subview: NSView) {
    super.willRemoveSubview(subview)

    keepKeyboardFocus(leaving: subview)
  }

  /// Gives the keyboard focus to the content of the nearest scroll view that takes it, when the focus is in a subview
  /// that's about to leave the content.
  ///
  /// AppKit gives the focus to the window when a view with it leaves the window, which leaves the keys without a scroll
  /// view to scroll, such as when a render pass removes a text view that scrolled out of view.
  ///
  /// - Parameter subview: The subview that's about to leave the content.
  private func keepKeyboardFocus(leaving subview: NSView) {
    // a render pass removes views on each scroll, while the content has the focus after a click, so the content is ruled
    // out without walking up the views from it
    guard let window, let firstResponder = window.firstResponder as? NSView, firstResponder !== self, firstResponder.isDescendant(of: subview) else {
      return
    }

    var view: NSView? = self
    while let candidate = view {
      if let documentView = candidate as? ScrollDocumentView, documentView.acceptsFirstResponder {
        window.makeFirstResponder(documentView)
        return
      }
      view = candidate.superview
    }
  }
}
#endif
