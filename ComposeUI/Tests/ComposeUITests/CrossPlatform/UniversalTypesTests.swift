//
//  UniversalTypesTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 5/9/26.
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

final class UniversalTypesTests: XCTestCase {

  // MARK: - AppKit

  #if canImport(AppKit)

  func test_appKit_typealiases() {
    // then: universal typealiases map to the AppKit types
    expect(ComposeUI.Window.self) == NSWindow.self
    expect(ComposeUI.View.self) == NSView.self
    expect(ComposeUI.TextView.self) == NSTextView.self
    expect(ComposeUI.Color.self) == NSColor.self
    expect(ComposeUI.Font.self) == NSFont.self
    expect(ComposeUI.FontDescriptor.self) == NSFontDescriptor.self
    expect(ComposeUI.BezierPath.self) == NSBezierPath.self
    expect(ComposeUI.GestureRecognizer.self) == NSGestureRecognizer.self
    expect(ComposeUI.TapGestureRecognizer.self) == NSClickGestureRecognizer.self
    expect(ComposeUI.PressGestureRecognizer.self) == NSPressGestureRecognizer.self
    expect(ComposeUI.PanGestureRecognizer.self) == NSPanGestureRecognizer.self
  }

  func test_appKit_edgeInsets_isNSEdgeInsets() {
    // given: edge insets with distinct values
    let insets = ComposeUI.EdgeInsets(top: 1, left: 2, bottom: 3, right: 4)

    // then: the components match
    expect(insets.top) == 1
    expect(insets.left) == 2
    expect(insets.bottom) == 3
    expect(insets.right) == 4
    // confirm interop with NSEdgeInsets
    let nsInsets: NSEdgeInsets = insets
    expect(nsInsets.top) == 1
  }

  func test_appKit_gestureRecognizerDelegate_protocolConformance() {
    // given: a delegate conforming to the universal delegate protocol
    final class Delegate: NSObject, ComposeUI.GestureRecognizerDelegate {}
    let delegate: NSGestureRecognizerDelegate = Delegate()

    // then: it can be used as an AppKit gesture recognizer delegate
    expect(delegate).toNot(beNil())
  }

  #endif

  // MARK: - UIKit

  #if canImport(UIKit)

  func test_uiKit_typealiases() {
    // then: universal typealiases map to the UIKit types
    expect(ComposeUI.Window.self) == UIWindow.self
    expect(ComposeUI.View.self) == UIView.self
    expect(ComposeUI.TextView.self) == UITextView.self
    expect(ComposeUI.Color.self) == UIColor.self
    expect(ComposeUI.Font.self) == UIFont.self
    expect(ComposeUI.FontDescriptor.self) == UIFontDescriptor.self
    expect(ComposeUI.BezierPath.self) == UIBezierPath.self
    expect(ComposeUI.GestureRecognizer.self) == UIGestureRecognizer.self
    expect(ComposeUI.TapGestureRecognizer.self) == UITapGestureRecognizer.self
    expect(ComposeUI.PressGestureRecognizer.self) == UILongPressGestureRecognizer.self
    expect(ComposeUI.PanGestureRecognizer.self) == UIPanGestureRecognizer.self
  }

  func test_uiKit_edgeInsets_isUIEdgeInsets() {
    // given: edge insets with distinct values
    let insets = ComposeUI.EdgeInsets(top: 1, left: 2, bottom: 3, right: 4)

    // then: the components match
    expect(insets.top) == 1
    expect(insets.left) == 2
    expect(insets.bottom) == 3
    expect(insets.right) == 4
    // confirm interop with UIEdgeInsets
    let uiInsets: UIEdgeInsets = insets
    expect(uiInsets.top) == 1
  }

  func test_uiKit_gestureRecognizerDelegate_protocolConformance() {
    // given: a delegate conforming to the universal delegate protocol
    final class Delegate: NSObject, ComposeUI.GestureRecognizerDelegate {}
    let delegate: UIGestureRecognizerDelegate = Delegate()

    // then: it can be used as a UIKit gesture recognizer delegate
    expect(delegate).toNot(beNil())
  }

  #endif
}
