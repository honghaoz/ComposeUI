//
//  ComposeView+LockedScrollViewSettingsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/23/26.
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

import ChouTiTest

@testable import ComposeUI

class ComposeView_LockedScrollViewSettingsTests: XCTestCase {

  func test_automaticallyAdjustsContentInsets_staysOff() {
    // given: a compose view filling a window whose title bar and toolbar overlap it, and a handler that records the
    // assertions
    let window = NSWindow(
      contentRect: CGRect(x: 0, y: 0, width: 400, height: 300),
      styleMask: [.titled, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.toolbar = NSToolbar(identifier: "ComposeViewTests")
    let view = ComposeView()
    window.contentView = view

    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: the automatic adjustment is turned off
    view.automaticallyAdjustsContentInsets = false

    // then: nothing asserts
    expect(assertionMessages) == []

    // when: the automatic adjustment is turned on, and the window lays out
    view.automaticallyAdjustsContentInsets = true
    window.layoutIfNeeded()

    // then: it asserts and stays off, so the content insets leave out the overlap
    expect(assertionMessages) == ["ComposeView doesn't support adjusting the content insets automatically"]
    expect(view.automaticallyAdjustsContentInsets) == false
    expect(view.bounds.height - window.contentLayoutRect.height) > 0
    expect(view.contentInset.top) == 0
  }

  func test_magnification_staysOne() {
    // given: a 100 × 100 compose view, and a handler that records the assertions
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: magnification is disallowed, and the magnification and its range are set to 1
    view.allowsMagnification = false
    view.magnification = 1
    view.setMagnification(1, centeredAt: CGPoint(x: 50, y: 50))
    view.minMagnification = 1
    view.maxMagnification = 1

    // then: nothing asserts
    expect(assertionMessages) == []

    // when: magnification is allowed
    view.allowsMagnification = true

    // then: it asserts and stays disallowed
    expect(assertionMessages) == ["ComposeView doesn't support magnification"]
    expect(view.allowsMagnification) == false

    // when: the magnification range is widened
    view.minMagnification = 0.25
    view.maxMagnification = 4

    // then: each asserts, and the range stays at 1
    expect(assertionMessages) == Array(repeating: "ComposeView doesn't support magnification", count: 3)
    expect(view.minMagnification) == 1
    expect(view.maxMagnification) == 1

    // when: the view is magnified through each of AppKit's magnifying APIs
    view.magnification = 2
    view.setMagnification(2, centeredAt: CGPoint(x: 50, y: 50))
    view.magnify(toFit: CGRect(x: 0, y: 0, width: 400, height: 400))

    // then: each asserts, and the magnification stays 1, so the visible area keeps the view's size
    expect(assertionMessages) == Array(repeating: "ComposeView doesn't support magnification", count: 6)
    expect(view.magnification) == 1
    expect(view.visibleSize) == CGSize(width: 100, height: 100)
  }

  func test_magnification_animator_staysOne() {
    // given: a 100 × 100 compose view in a window, showing fifty 10 pt rows, referenced as an `NSScrollView`, where the
    // animator's magnifying methods don't call the view's overrides
    let window = TestWindow()
    let view = ComposeView {
      VStack {
        for _ in 0 ..< 50 {
          LayerNode().frame(width: .flexible, height: 10)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    let scrollView: NSScrollView = view

    ComposeUI.Assert.setTestAssertionFailureHandler { _, _, _, _ in }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    let magnifyingCalls: [(NSScrollView) -> Void] = [
      { $0.animator().setMagnification(0.25, centeredAt: CGPoint(x: 50, y: 50)) },
      { $0.animator().magnify(toFit: CGRect(x: 0, y: 0, width: 400, height: 400)) },
    ]
    for magnify in magnifyingCalls {
      // when: the view is magnified through the animator, and the animation finishes
      var isFinished = false
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.05
        magnify(scrollView)
      } completionHandler: {
        isFinished = true
      }
      expect(isFinished).toEventually(beTrue())
      view.refresh(animated: false)

      // then: the magnification stays 1, so the clip view keeps the view's size, and the rendered rows are the visible
      // ones at their full width
      expect(view.magnification) == 1
      expect(view.contentView.bounds.size) == CGSize(width: 100, height: 100)
      let visibleBounds = view.contentView.bounds
      let rowFrames = (view.documentView?.layer?.sublayers ?? []).map(\.frame).filter { $0.height == 10 }
      let visibleRows = Int((visibleBounds.minY / 10).rounded(.down)) ..< Int((visibleBounds.maxY / 10).rounded(.up))
      expect(rowFrames.sorted { $0.minY < $1.minY }) == visibleRows.map { CGRect(x: 0, y: CGFloat($0) * 10, width: 100, height: 10) }
    }
  }

  func test_borderType_staysNoBorder() {
    // given: a 100 × 100 compose view, and a handler that records the assertions
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: the view is set to have no border
    view.borderType = .noBorder

    // then: nothing asserts
    expect(assertionMessages) == []

    // when: the view is given each border, and it tiles
    for borderType in [NSBorderType.lineBorder, .bezelBorder, .grooveBorder] {
      view.borderType = borderType
    }
    view.tile()

    // then: each asserts, and the view stays borderless, so the clip view fills it
    expect(assertionMessages) == Array(repeating: "ComposeView doesn't support borders", count: 3)
    expect(view.borderType) == .noBorder
    expect(view.contentView.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
  }

  func test_autohidesScrollers_staysOff() {
    // given: a 100 × 100 compose view, and a handler that records the assertions
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: auto-hiding is turned off
    view.autohidesScrollers = false

    // then: nothing asserts, and it's off
    expect(assertionMessages) == []
    expect(view.autohidesScrollers) == false

    // when: auto-hiding is turned on
    view.autohidesScrollers = true

    // then: it asserts and stays off
    expect(assertionMessages) == ["ComposeView doesn't support auto-hiding scrollers"]
    expect(view.autohidesScrollers) == false
  }

  func test_rulersVisible_staysOff() {
    // given: a 100 × 100 compose view with a vertical ruler, and a handler that records the assertions
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.hasVerticalRuler = true

    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: the rulers are hidden
    view.rulersVisible = false

    // then: nothing asserts, and they're hidden
    expect(assertionMessages) == []
    expect(view.rulersVisible) == false

    // when: the rulers are shown, and the view tiles
    view.rulersVisible = true
    view.tile()

    // then: it asserts, and the rulers stay hidden, so they take no room from the content
    expect(assertionMessages) == ["ComposeView doesn't support rulers"]
    expect(view.rulersVisible) == false
    let insets = view.adjustedContentInset
    expect([insets.top, insets.left, insets.bottom, insets.right]) == [0, 0, 0, 0]
  }

  func test_isFindBarVisible_staysOff() {
    // given: a 100 × 100 compose view with a 30 pt tall find bar view, and a handler that records the assertions
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.findBarView = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 30))

    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: the find bar is hidden
    view.isFindBarVisible = false

    // then: nothing asserts, and it's hidden
    expect(assertionMessages) == []
    expect(view.isFindBarVisible) == false

    // when: the find bar is shown, and the view tiles
    view.isFindBarVisible = true
    view.tile()

    // then: it asserts, and the find bar stays hidden, so it takes no room from the content
    expect(assertionMessages) == ["ComposeView doesn't support the find bar"]
    expect(view.isFindBarVisible) == false
    let insets = view.adjustedContentInset
    expect([insets.top, insets.left, insets.bottom, insets.right]) == [0, 0, 0, 0]
  }
}
#endif
