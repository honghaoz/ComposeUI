//
//  ScrollDocumentViewTests.swift
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

import ChouTiTest

@testable import ComposeUI

class ScrollDocumentViewTests: XCTestCase {

  // MARK: - First Responder

  func test_acceptsFirstResponder() {
    // given: a 100 × 100 scroll view showing content taller than it
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 300)
    let documentView = scrollView.contentContainerView

    // then: the keys can scroll the scroll view, so its content takes the focus
    expect(documentView is ScrollDocumentView) == true
    expect(documentView.acceptsFirstResponder) == true

    // when: the content fits the scroll view
    scrollView.contentSize = CGSize(width: 100, height: 100)

    // then: the content doesn't take the focus
    expect(documentView.acceptsFirstResponder) == false

    // when: the content is in a plain scroll view of AppKit's, and outside a scroll view
    let plainScrollView = NSScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let plainDocumentView = ScrollDocumentView(frame: CGRect(x: 0, y: 0, width: 100, height: 300))
    plainScrollView.documentView = plainDocumentView
    let looseDocumentView = ScrollDocumentView(frame: CGRect(x: 0, y: 0, width: 100, height: 300))

    // then: no scroll view of ComposeUI's scrolls with the keys, so the content doesn't take the focus
    expect(plainDocumentView.acceptsFirstResponder) == false
    expect(looseDocumentView.acceptsFirstResponder) == false
  }

  func test_keyViewLoop_leavesTheContentOut() throws {
    // given: a window with a scroll view that the keys scroll, above a text field
    let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 200, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    defer {
      window.close()
    }
    let contentView = try unwrap(window.contentView)
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 100, width: 200, height: 200))
    scrollView.contentSize = CGSize(width: 200, height: 1000)
    contentView.addSubview(scrollView)
    let textField = NSTextField(frame: CGRect(x: 0, y: 0, width: 200, height: 24))
    contentView.addSubview(textField)

    // then: the content takes the focus, but not as a key view
    expect(scrollView.contentContainerView.acceptsFirstResponder) == true
    expect(scrollView.contentContainerView.canBecomeKeyView) == false

    // when: the window opens, which focuses the first key view
    window.makeKeyAndOrderFront(nil)

    // then: the text field gets the focus, instead of the scroll view's content above it
    expect(textField.currentEditor()) != nil

    // when: the focus moves to the next key view, as the tab key moves it
    window.selectNextKeyView(nil)

    // then: the text field is the only key view, so it keeps the focus
    expect(textField.currentEditor()) != nil
  }

  // MARK: - Removing a Subview

  func test_focusedSubviewRemoved_focusMovesToTheContent() {
    // given: a scroll view that the keys scroll, in a window, with the focus in a view in its content
    let window = TestWindow()
    let scrollView = makeScrollView(contentSize: CGSize(width: 100, height: 300), in: window.contentView())
    let focusableView = FocusableView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    scrollView.contentContainerView.addSubview(focusableView)
    window.makeFirstResponder(focusableView)

    // when: the view is removed from the content
    focusableView.removeFromSuperview()

    // then: the content keeps the focus, instead of the window
    expect(window.firstResponder) === scrollView.contentContainerView

    // when: the arrow keys are pressed
    window.press(.down)

    // then: the scroll view scrolls
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 40)
  }

  func test_subviewWithTheFocusInsideRemoved_focusMovesToTheContent() {
    // given: a scroll view that the keys scroll, in a window, with the focus in a view inside a container in its content
    let window = TestWindow()
    let scrollView = makeScrollView(contentSize: CGSize(width: 100, height: 300), in: window.contentView())
    let container = NSView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    scrollView.contentContainerView.addSubview(container)
    let focusableView = FocusableView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    container.addSubview(focusableView)
    window.makeFirstResponder(focusableView)

    // when: the container is removed from the content
    container.removeFromSuperview()

    // then: the content keeps the focus
    expect(window.firstResponder) === scrollView.contentContainerView
  }

  func test_focusedSubviewRemoved_scrollViewThatTheKeysCanNotScroll_focusMovesToTheScrollViewAroundIt() {
    // given: a scroll view whose content fits it, nested in a parent scroll view that the keys scroll, in a window, with
    // the focus in a view in the scroll view's content
    let window = TestWindow()
    let parent = makeScrollView(contentSize: CGSize(width: 1000, height: 1000), in: window.contentView())
    let scrollView = makeScrollView(contentSize: CGSize(width: 100, height: 100), in: parent.contentContainerView)
    let focusableView = FocusableView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    scrollView.contentContainerView.addSubview(focusableView)
    window.makeFirstResponder(focusableView)

    // when: the view is removed from the scroll view's content
    focusableView.removeFromSuperview()

    // then: the keys can't scroll the scroll view, so the parent's content takes the focus
    expect(window.firstResponder) === parent.contentContainerView
  }

  func test_focusedSubviewRemoved_noScrollViewThatTheKeysScroll_focusGoesToTheWindow() {
    // given: a scroll view whose content fits it, in a window, with the focus in a view in its content
    let window = TestWindow()
    let scrollView = makeScrollView(contentSize: CGSize(width: 100, height: 100), in: window.contentView())
    let focusableView = FocusableView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    scrollView.contentContainerView.addSubview(focusableView)
    window.makeFirstResponder(focusableView)

    // when: the view is removed from the content
    focusableView.removeFromSuperview()

    // then: no scroll view takes the focus, so the window gets it, as AppKit gives it
    expect(window.firstResponder) === window
  }

  func test_subviewRemoved_focusOutsideIt_staysWhereItIs() {
    // given: a scroll view that the keys scroll, in a window, with two views in its content
    let window = TestWindow()
    let scrollView = makeScrollView(contentSize: CGSize(width: 100, height: 300), in: window.contentView())
    let focusableView = FocusableView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    scrollView.contentContainerView.addSubview(focusableView)
    let otherView = NSView(frame: CGRect(x: 50, y: 0, width: 50, height: 50))
    scrollView.contentContainerView.addSubview(otherView)
    let otherView2 = NSView(frame: CGRect(x: 0, y: 50, width: 50, height: 50))
    scrollView.contentContainerView.addSubview(otherView2)
    let otherView3 = NSView(frame: CGRect(x: 50, y: 50, width: 50, height: 50))
    scrollView.contentContainerView.addSubview(otherView3)

    // when: the focus is in one view, and the other view is removed
    window.makeFirstResponder(focusableView)
    otherView.removeFromSuperview()

    // then: the focused view keeps the focus
    expect(window.firstResponder) === focusableView

    // when: the focus is in the content itself, and a view is removed
    window.makeFirstResponder(scrollView)
    otherView2.removeFromSuperview()

    // then: the content keeps the focus
    expect(window.firstResponder) === scrollView.contentContainerView

    // when: the window has the focus, and a view is removed
    window.makeFirstResponder(nil)
    otherView3.removeFromSuperview()

    // then: the window keeps the focus
    expect(window.firstResponder) === window

    // when: the scroll view leaves the window, and a view is removed from its content
    scrollView.removeFromSuperview()
    focusableView.removeFromSuperview()

    // then: the view leaves without a window to focus in
    expect(focusableView.superview) == nil
  }

  func test_focusedSubviewRestacked_keepsTheFocus() {
    // given: a scroll view that the keys scroll, in a window, with the focus in a view behind another view in its content
    let window = TestWindow()
    let scrollView = makeScrollView(contentSize: CGSize(width: 100, height: 300), in: window.contentView())
    let focusableView = FocusableView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    scrollView.contentContainerView.addSubview(focusableView)
    scrollView.contentContainerView.addSubview(NSView(frame: CGRect(x: 0, y: 0, width: 50, height: 50)))
    window.makeFirstResponder(focusableView)

    // when: the focused view moves to the front, as a render pass restacks the views
    scrollView.contentContainerView.bringSubviewToFront(focusableView)

    // then: the view stays in the content, so it keeps the focus
    expect(scrollView.contentContainerView.subviews.last) === focusableView
    expect(window.firstResponder) === focusableView
  }

  // MARK: - Helpers

  /// Makes a 100 × 100 scroll view that shows content of the size, in a view.
  private func makeScrollView(contentSize: CGSize, in superview: NSView) -> ScrollView {
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = contentSize
    superview.addSubview(scrollView)
    return scrollView
  }
}

/// A view that takes the keyboard focus, and passes clicks and keys up the responder chain.
private final class FocusableView: NSView {

  override var acceptsFirstResponder: Bool {
    true
  }
}
#endif
