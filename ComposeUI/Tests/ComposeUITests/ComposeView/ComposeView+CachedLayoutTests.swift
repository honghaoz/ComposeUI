//
//  ComposeView+CachedLayoutTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
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

class ComposeView_CachedLayoutTests: XCTestCase {

  func test_noLayoutOnScroll() {
    let state = TestNode.State()

    let view = ComposeView {
      TestNode(state: state)
        .frame(width: 100, height: 300)
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.setNeedsLayout()
    view.layoutIfNeeded()

    expect(state.layoutCount) == 1 // initial layout
    expect(state.renderCount) == 1 // initial render

    view.setContentOffset(CGPoint(x: 0, y: 100))
    view.setNeedsLayout()
    view.layoutIfNeeded()

    expect(state.layoutCount) == 1 // scroll should not trigger layout
    expect(state.renderCount) == 2 // scroll should trigger render

    view.setContentOffset(CGPoint(x: 0, y: 200))
    view.setNeedsLayout()
    view.layoutIfNeeded()

    expect(state.layoutCount) == 1 // scroll should not trigger layout
    expect(state.renderCount) == 3 // scroll should trigger render

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
    view.setNeedsLayout()
    view.layoutIfNeeded()

    expect(state.layoutCount) == 2 // size change should trigger layout
    expect(state.renderCount) == 4 // size change should trigger render
  }
}
