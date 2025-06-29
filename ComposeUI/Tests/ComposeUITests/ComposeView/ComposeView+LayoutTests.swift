//
//  ComposeView+LayoutTests.swift
//  ComposéUI
//
//  Created by Honghao on 6/28/25.
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

import ChouTiTest

import ComposeUI

class ComposeView_LayoutTests: XCTestCase {

  func test_layoutBounds() throws {
    let view = ComposeView {
      try LabelNode("Test")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
    }

    #if canImport(AppKit)
    // force the view to have scrollers so that the layout bounds maybe affected
    view.hasHorizontalScroller = true
    view.hasVerticalScroller = true
    #endif

    // given a specified size
    view.frame.size = view.sizeThatFits(
      CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    )

    var layoutBounds: CGRect?
    view.debug { view, event in
      switch event {
      case .renderWillLayout(_, let bounds, _):
        layoutBounds = bounds
      default:
        break
      }
    }

    view.refresh()

    // the layout bounds should be the same as the view's bounds
    expect(layoutBounds) == view.bounds
    expect(view.showsHorizontalScrollIndicator) == false
    expect(view.showsVerticalScrollIndicator) == false
  }
}
