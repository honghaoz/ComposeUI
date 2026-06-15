//
//  BaseTextViewTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 5/25/26.
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
#endif

#if canImport(UIKit)
import UIKit
#endif

import ChouTiTest

import ComposeUI

class BaseTextViewTests: XCTestCase {

  #if canImport(UIKit)
  func test_contentInsetAdjustmentBehavior() {
    let textView = BaseTextView(frame: .zero)
    expect(textView.contentInsetAdjustmentBehavior) == .never
  }
  #endif

  #if canImport(AppKit)
  func test_removeFromSuperview_whenFirstResponder_resignsFirstResponder() {
    let window = TestWindow()
    let container = NSView(frame: window.contentView?.bounds ?? .zero)
    let textView = BaseTextView(frame: container.bounds)

    window.contentView = container
    container.addSubview(textView)

    expect(window.makeFirstResponder(textView)) == true
    expect(window.firstResponder) === textView

    textView.removeFromSuperview()

    expect(window.firstResponder) !== textView
    expect(textView.window == nil) == true
  }
  #endif

  #if canImport(UIKit) && !os(tvOS)
  func test_removeFromSuperview_whenFirstResponder_resignsFirstResponder() {
    let window = TestWindow()
    let viewController = UIViewController()
    let textView = BaseTextView(frame: window.bounds)

    window.rootViewController = viewController
    window.makeKeyAndVisible()
    viewController.view.addSubview(textView)

    textView.isEditable = true
    expect(textView.becomeFirstResponder()) == true
    expect(textView.isFirstResponder) == true

    textView.removeFromSuperview()

    expect(textView.isFirstResponder) == false
    expect(textView.window == nil) == true
  }
  #endif

  // MARK: - resetForReuse

  func test_resetForReuse_clearsSelection() {
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")

    #if canImport(AppKit)
    textView.setSelectedRange(NSRange(location: 0, length: 5))
    #endif
    #if canImport(UIKit)
    textView.selectedRange = NSRange(location: 0, length: 5)
    #endif
    expect(textView.selectedRange.length) == 5

    textView.resetForReuse()

    expect(textView.selectedRange.location) == 0
    expect(textView.selectedRange.length) == 0
  }

  func test_resetForReuse_clearsFirstResponder() {
    #if canImport(AppKit)
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    let window = TestWindow()
    window.contentView = NSView(frame: window.frame)
    window.contentView?.addSubview(textView)
    window.makeFirstResponder(textView)
    expect(window.firstResponder) === textView

    textView.resetForReuse()
    expect(window.firstResponder) !== textView
    #endif

    #if canImport(UIKit) && !os(tvOS)
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    let window = TestWindow()
    window.rootViewController = UIViewController()
    window.rootViewController?.view.addSubview(textView)
    window.makeKeyAndVisible()
    textView.becomeFirstResponder()
    expect(textView.isFirstResponder) == true
    textView.resetForReuse()
    expect(textView.isFirstResponder) == false
    #endif
  }

  func test_resetForReuse_clearsDelegate() {
    #if canImport(AppKit)
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    class TestDelegate: NSObject, NSTextViewDelegate {}
    let delegate = TestDelegate()
    textView.delegate = delegate
    expect(textView.delegate) != nil

    textView.resetForReuse()
    expect(textView.delegate) == nil
    #endif

    #if canImport(UIKit)
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    class TestDelegate: NSObject, UITextViewDelegate {}
    let delegate = TestDelegate()
    textView.delegate = delegate
    expect(textView.delegate) != nil

    textView.resetForReuse()
    expect(textView.delegate) == nil
    #endif
  }

  func test_resetForReuse_clearsAttributedString() {
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.attributedString = NSAttributedString(string: "Hello, world!")
    expect(textView.attributedString.string) == "Hello, world!"

    textView.resetForReuse()
    expect(textView.attributedString.string) == ""
  }

  func test_resetForReuse_clearsNumberOfLines() {
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.numberOfLines = 2
    expect(textView.numberOfLines) == 2

    textView.resetForReuse()
    expect(textView.numberOfLines) == 0
  }

  func test_resetForReuse_clearsLineBreakMode() {
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.lineBreakMode = .byTruncatingTail
    expect(textView.lineBreakMode) == .byTruncatingTail

    textView.resetForReuse()
    expect(textView.lineBreakMode) == .byWordWrapping
  }

  #if canImport(UIKit)
  func test_resetForReuse_clearsContentInsetAdjustmentBehavior() {
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.contentInsetAdjustmentBehavior = .automatic
    expect(textView.contentInsetAdjustmentBehavior) == .automatic

    textView.resetForReuse()
    expect(textView.contentInsetAdjustmentBehavior) == .never
  }
  #endif

  #if canImport(AppKit) || canImport(UIKit) && !os(tvOS)
  func test_resetForReuse_clearsIsEditable() {
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.isEditable = true
    expect(textView.isEditable) == true

    textView.resetForReuse()
    expect(textView.isEditable) == false
  }
  #endif

  func test_resetForReuse_clearsIsSelectable() {
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.isSelectable = false
    expect(textView.isSelectable) == false

    textView.resetForReuse()
    expect(textView.isSelectable) == true
  }

  #if canImport(AppKit)
  func test_resetForReuse_clearsIsRichText() {
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.isRichText = true
    expect(textView.isRichText) == true

    textView.resetForReuse()
    expect(textView.isRichText) == false
  }
  #endif

  #if canImport(UIKit)
  func test_resetForReuse_clearsIsUserInteractionEnabled() {
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.isUserInteractionEnabled = false
    expect(textView.isUserInteractionEnabled) == false

    textView.resetForReuse()
    expect(textView.isUserInteractionEnabled) == true
  }
  #endif

  func test_resetForReuse_clearsBackground() {
    #if canImport(AppKit)
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.drawsBackground = true
    expect(textView.drawsBackground) == true

    textView.resetForReuse()
    expect(textView.drawsBackground) == false
    #endif

    #if canImport(UIKit)
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.backgroundColor = .red
    expect(textView.backgroundColor) == .red

    textView.resetForReuse()
    expect(textView.backgroundColor) == nil
    #endif
  }

  func test_resetForReuse_clearsTextContainerInset() {
    #if canImport(AppKit)
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.textContainerInset = CGSize(width: 10, height: 10)
    expect(textView.textContainerInset) == CGSize(width: 10, height: 10)

    textView.resetForReuse()
    expect(textView.textContainerInset) == .zero
    #endif

    #if canImport(UIKit)
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.textContainerInset = EdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    expect(textView.textContainerInset) == EdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

    textView.resetForReuse()
    expect(textView.textContainerInset) == .zero
    #endif
  }

  func test_resetForReuse_clearsTextContainerLineFragmentPadding() {
    #if canImport(AppKit)
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.textContainer?.lineFragmentPadding = 10
    expect(textView.textContainer?.lineFragmentPadding) == 10

    textView.resetForReuse()
    expect(textView.textContainer?.lineFragmentPadding) == 0
    #endif

    #if canImport(UIKit)
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.textContainer.lineFragmentPadding = 10
    expect(textView.textContainer.lineFragmentPadding) == 10

    textView.resetForReuse()
    expect(textView.textContainer.lineFragmentPadding) == 0
    #endif
  }

  func test_resetForReuse_clearsClipsToBounds() {
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.clipsToBounds = true
    expect(textView.clipsToBounds) == true

    textView.resetForReuse()
    expect(textView.clipsToBounds) == true
  }

  #if canImport(AppKit)
  func test_resetForReuse_clearsIgnoreHitTest() {
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.ignoreHitTest = true
    expect(textView.ignoreHitTest) == true

    textView.resetForReuse()
    expect(textView.ignoreHitTest) == false
  }
  #endif

  #if canImport(UIKit)
  func test_resetForReuse_clearsContentOffset() {
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.contentOffset = CGPoint(x: 0, y: 20)
    expect(textView.contentOffset) == CGPoint(x: 0, y: 20)

    textView.resetForReuse()
    expect(textView.contentOffset) == .zero
  }

  func test_resetForReuse_clearsScrollIndicatorInsets() {
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.horizontalScrollIndicatorInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    textView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    expect(textView.horizontalScrollIndicatorInsets) == UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    expect(textView.verticalScrollIndicatorInsets) == UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

    textView.resetForReuse()
    expect(textView.horizontalScrollIndicatorInsets) == .zero
    expect(textView.verticalScrollIndicatorInsets) == .zero
  }

  func test_resetForReuse_resetsScrollOffset() {
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.contentOffset = CGPoint(x: 0, y: 20)
    expect(textView.contentOffset) == CGPoint(x: 0, y: 20)

    textView.resetForReuse()

    expect(textView.contentOffset) == .zero
  }
  #endif

  func test_resetForReuse_clearsTypingAttributes() {
    let textView = BaseTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    textView.typingAttributes = [NSAttributedString.Key.font: Font.systemFont(ofSize: 12)]

    textView.resetForReuse()
    expect(textView.typingAttributes.isEmpty) == true
  }
}
