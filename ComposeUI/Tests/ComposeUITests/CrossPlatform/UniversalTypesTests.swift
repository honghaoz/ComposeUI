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
    expect(ObjectIdentifier(ComposeUI.Window.self)) == ObjectIdentifier(NSWindow.self)
    expect(ObjectIdentifier(ComposeUI.View.self)) == ObjectIdentifier(NSView.self)
    expect(ObjectIdentifier(ComposeUI.TextView.self)) == ObjectIdentifier(NSTextView.self)
    expect(ObjectIdentifier(ComposeUI.Color.self)) == ObjectIdentifier(NSColor.self)
    expect(ObjectIdentifier(ComposeUI.Font.self)) == ObjectIdentifier(NSFont.self)
    expect(ObjectIdentifier(ComposeUI.FontDescriptor.self)) == ObjectIdentifier(NSFontDescriptor.self)
    expect(ObjectIdentifier(ComposeUI.BezierPath.self)) == ObjectIdentifier(NSBezierPath.self)
    expect(ObjectIdentifier(ComposeUI.GestureRecognizer.self)) == ObjectIdentifier(NSGestureRecognizer.self)
    expect(ObjectIdentifier(ComposeUI.TapGestureRecognizer.self)) == ObjectIdentifier(NSClickGestureRecognizer.self)
    expect(ObjectIdentifier(ComposeUI.PressGestureRecognizer.self)) == ObjectIdentifier(NSPressGestureRecognizer.self)
    expect(ObjectIdentifier(ComposeUI.PanGestureRecognizer.self)) == ObjectIdentifier(NSPanGestureRecognizer.self)
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
    expect(ObjectIdentifier(ComposeUI.Window.self)) == ObjectIdentifier(UIWindow.self)
    expect(ObjectIdentifier(ComposeUI.View.self)) == ObjectIdentifier(UIView.self)
    expect(ObjectIdentifier(ComposeUI.TextView.self)) == ObjectIdentifier(UITextView.self)
    expect(ObjectIdentifier(ComposeUI.Color.self)) == ObjectIdentifier(UIColor.self)
    expect(ObjectIdentifier(ComposeUI.Font.self)) == ObjectIdentifier(UIFont.self)
    expect(ObjectIdentifier(ComposeUI.FontDescriptor.self)) == ObjectIdentifier(UIFontDescriptor.self)
    expect(ObjectIdentifier(ComposeUI.BezierPath.self)) == ObjectIdentifier(UIBezierPath.self)
    expect(ObjectIdentifier(ComposeUI.GestureRecognizer.self)) == ObjectIdentifier(UIGestureRecognizer.self)
    expect(ObjectIdentifier(ComposeUI.TapGestureRecognizer.self)) == ObjectIdentifier(UITapGestureRecognizer.self)
    expect(ObjectIdentifier(ComposeUI.PressGestureRecognizer.self)) == ObjectIdentifier(UILongPressGestureRecognizer.self)
    expect(ObjectIdentifier(ComposeUI.PanGestureRecognizer.self)) == ObjectIdentifier(UIPanGestureRecognizer.self)
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
