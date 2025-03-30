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

  func test_keyWindowDidChange() {
    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let window = TestWindow(contentRect: frame, styleMask: [], backing: .buffered, defer: false)

    var renderCount = 0
    let view = ComposeView {
      renderCount += 1
      Empty()
    }

    view.frame = frame

    view.refresh()
    expect(renderCount) == 1 // initial render

    window.contentView?.addSubview(view)

    window.makeKey()
    expect(renderCount).toEventually(beEqual(to: 2))

    window.resignKey()
    expect(renderCount).toEventually(beEqual(to: 3))

    window.makeKey()
    expect(renderCount).toEventually(beEqual(to: 4))

    view.removeFromSuperview()

    window.resignKey()
    expect(renderCount) == 4

    window.makeKey()
    expect(renderCount) == 4
  }
}

private class TestWindow: NSWindow {

  override var canBecomeMain: Bool { true }
  override var canBecomeKey: Bool { true }

  override func makeKey() {
    super.makeKey()

    NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: self)
  }
}
#endif
