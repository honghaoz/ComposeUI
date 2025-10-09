//
//  ComposeView+WindowBackingPropertiesDidChangeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/8/25.
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
import AppKit

@testable import ComposeUI

class ComposeView_WindowBackingPropertiesDidChangeTests: XCTestCase {

  func test_windowBackingPropertiesDidChange() {
    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let window = TestWindowWithBackingScaleFactor()

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
    window.contentView?.addSubview(view)

    // initial render when added to window
    expect(renderCount).toEventually(beEqual(to: 1))
    expect(refreshCount) == 1
    expect(isAnimated) == false
    isAnimated = nil
    expect(view.contentScaleFactor) == window.backingScaleFactor

    // change backing scale factor - should trigger refresh
    window.backingScaleFactor = 3.0

    expect(renderCount).toEventually(beEqual(to: 2))
    expect(refreshCount) == 2
    expect(isAnimated) == false
    isAnimated = nil
    expect(view.contentScaleFactor) == 3.0

    // change backing scale factor again - should trigger another refresh
    window.backingScaleFactor = 1.0

    expect(renderCount).toEventually(beEqual(to: 3))
    expect(refreshCount) == 3
    expect(isAnimated) == false
    expect(view.contentScaleFactor) == 1.0
    isAnimated = nil
  }

  func test_windowBackingPropertiesDidChange_viewRemovedFromWindow() {
    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let window = TestWindowWithBackingScaleFactor()

    var renderCount = 0
    var refreshCount = 0
    let view = ComposeView {
      renderCount += 1
      LayerNode()
        .onUpdate { _, _ in
          refreshCount += 1
        }
    }

    view.frame = frame
    window.contentView?.addSubview(view)

    // initial render when added to window
    expect(renderCount).toEventually(beEqual(to: 1))
    expect(refreshCount) == 1

    // remove view from window
    view.removeFromSuperview()

    // change backing scale factor - should not trigger refresh since view is not in window
    window.backingScaleFactor = 3.0

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3)) // flush any pending refreshes
    expect(renderCount) == 1 // no new render
    expect(refreshCount) == 1
  }
}

// MARK: - TestWindowWithBackingScaleFactor

private final class TestWindowWithBackingScaleFactor: NSWindow {

  private var _backingScaleFactor: CGFloat = 2.0
  override var backingScaleFactor: CGFloat {
    get {
      _backingScaleFactor
    }
    set {
      _backingScaleFactor = newValue
      NotificationCenter.default.post(name: NSWindow.didChangeBackingPropertiesNotification, object: self)
    }
  }

  init() {
    super.init(
      contentRect: CGRect(x: 0, y: 0, width: 500, height: 500),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    contentView?.wantsLayer = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }
}

#endif
