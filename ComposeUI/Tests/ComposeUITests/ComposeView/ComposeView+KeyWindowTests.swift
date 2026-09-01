//
//  ComposeView+KeyWindowTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/30/25.
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
import ChouTiTest

import ComposeUI

class ComposeView_KeyWindowTests: XCTestCase {

  func test_keyWindowDidChange() throws {
    // given: a test window and a compose view with render, refresh and animation tracking, rendered
    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let window = TestWindow()

    var renderCount = 0
    var refreshCount = 0
    var isAnimated: Bool?
    let view = ComposeView {
      renderCount += 1
      LayerNode()
        .animation(.linear())
        .onUpdate { _, context in
          isAnimated = context.animationTiming != nil
          refreshCount += 1
        }
    }

    view.frame = frame

    view.refresh()
    expect(renderCount) == 1 // initial render
    expect(refreshCount) == 1
    expect(isAnimated) == false
    isAnimated = nil

    // when: the view is added to the window and the window becomes key
    window.contentView?.addSubview(view)

    window.makeKey()

    // then: a non-animated refresh is performed
    expect(renderCount).toEventually(beEqual(to: 2))
    expect(refreshCount) == 2
    expect(isAnimated) == false
    isAnimated = nil

    // when: the window resigns key
    window.resignKey()

    // then: another non-animated refresh is performed
    expect(renderCount).toEventually(beEqual(to: 3))
    expect(refreshCount) == 3
    expect(isAnimated) == false
    isAnimated = nil

    // when: the window becomes key again
    window.makeKey()

    // then: another non-animated refresh is performed
    expect(renderCount).toEventually(beEqual(to: 4))
    expect(refreshCount) == 4
    expect(isAnimated) == false
    isAnimated = nil

    // when: the view is removed from the window and the window resigns key
    view.removeFromSuperview()

    window.resignKey()

    // then: no refresh is performed
    expect(renderCount) == 4
    expect(refreshCount) == 4
    expect(isAnimated) == nil
    isAnimated = nil

    // when: the window becomes key again
    window.makeKey()

    // then: no refresh is performed
    expect(renderCount) == 4
    expect(refreshCount) == 4
    expect(isAnimated) == nil
    isAnimated = nil
  }
}

#endif
