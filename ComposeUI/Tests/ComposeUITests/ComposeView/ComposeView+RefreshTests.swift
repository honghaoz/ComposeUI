//
//  ComposeView+RefreshTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/3/25.
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

class ComposeView_RefreshTests: XCTestCase {

  func test_refresh() {
    var renderCount = 0
    var isAnimated: Bool?
    let view = ComposeView {
      renderCount += 1
      LayerNode()
        .animation(.linear())
        .onUpdate { _, context in
          isAnimated = context.animationTiming != nil
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

    view.refresh()
    expect(renderCount) == 1
    expect(isAnimated) == false // initial render is always not animated
    isAnimated = nil

    view.refresh()
    expect(renderCount) == 2
    expect(isAnimated) == true
    isAnimated = nil

    view.refresh(animated: false)
    expect(renderCount) == 3
    expect(isAnimated) == false
    isAnimated = nil

    view.setNeedsRefresh(animated: true)
    expect(renderCount) == 3
    view.setNeedsRefresh()
    expect(renderCount) == 3
    view.setNeedsRefresh(animated: false)
    expect(renderCount) == 3

    expect(renderCount).toEventually(beEqual(to: 4))
    expect(isAnimated) == false // the refresh animation flag should be the last scheduled refresh
    isAnimated = nil
  }
}
