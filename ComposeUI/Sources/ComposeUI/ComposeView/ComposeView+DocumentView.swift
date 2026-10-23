//
//  ComposeView+DocumentView.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/22/26.
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

extension ComposeView {

  /// The view that holds a ComposeView's renderables, which tells assistive technologies its children in the items
  /// order.
  ///
  /// AppKit tells a view's children in the subview order, while a render pass leaves a view that passes every click
  /// through anywhere in it, see `ClickThroughView`, so the children come in the items order instead, as the subview
  /// order would have them if the pass kept every view in the items order.
  final class DocumentView: BaseView {

    override func accessibilityChildren() -> [Any]? {
      guard let composeView = enclosingScrollView as? ComposeView else {
        return super.accessibilityChildren()
      }
      return NSAccessibility.unignoredChildren(from: composeView.shownSubviewsInItemsOrder())
    }
  }
}
#endif
