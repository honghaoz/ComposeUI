//
//  SwiftUIHostingViewTests.swift
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
import SwiftUI

@testable import ComposeUI

final class SwiftUIHostingViewTests: XCTestCase {

  // MARK: - SwiftUIHostingView

  func test_init_withRootView() {
    // given: a hosting view created with a root view
    let view = SwiftUIHostingView(rootView: SwiftUI.Text("Hello, World!"))

    // then: the bounds start at zero and safe areas are disabled
    expect(view.bounds.size) == .zero

    #if canImport(AppKit)
    if #available(macOS 13.3, *) {
      expect(view.safeAreaRegions) == []
    }
    #endif

    #if canImport(UIKit)
    if #available(iOS 16.4, tvOS 16.4, *) {
      expect(view.test.hostingController.safeAreaRegions) == []
      expect(view.test.hostingController.view.safeAreaInsets) == .zero
    }
    #endif
  }

  func test_layout_appliesBoundsToContent() {
    // given: a hosting view
    let view = SwiftUIHostingView(rootView: SwiftUI.Color.black)

    // when: setting the frame
    view.frame = CGRect(x: 0, y: 0, width: 120, height: 80)

    // then: the bounds are applied to the hosted content
    #if canImport(UIKit)
    view.layoutIfNeeded()
    let hostingControllerView = try? view.subviews.first.unwrap()
    expect(hostingControllerView?.frame) == CGRect(x: 0, y: 0, width: 120, height: 80)
    #endif

    #if canImport(AppKit)
    expect(view.bounds.size) == CGSize(width: 120, height: 80)
    #endif
  }

  // MARK: - MutableSwiftUIHostingView

  func test_mutable_init_emptyContent() {
    // given: a mutable hosting view created without content
    let view = MutableSwiftUIHostingView()

    // then: the content is an empty view
    expect("\(view.content)") == "AnyView(EmptyView())"
  }

  func test_mutable_setContent() {
    // given: a mutable hosting view with empty content
    let view = MutableSwiftUIHostingView()
    expect("\(view.content)".contains("EmptyView")) == true

    // when: setting content
    view.content = AnyView(SwiftUI.Text("Hello, World!"))

    // then: the content is updated
    expect("\(view.content)".contains("Hello, World")) == true

    // when: replacing the content
    view.content = AnyView(SwiftUI.Text("Updated"))

    // then: the new content replaces the old content
    expect("\(view.content)".contains("Updated")) == true
    expect("\(view.content)".contains("Hello, World")) == false
  }

  // MARK: - AppKit specific

  #if canImport(AppKit)

  func test_appKit_isUserInteractionEnabled_defaultTrue() {
    // given: a hosting view
    let view = SwiftUIHostingView(rootView: SwiftUI.Text("Hello, World!"))

    // then: user interaction is enabled by default
    expect(view.isUserInteractionEnabled) == true
  }

  func test_appKit_becomeFirstResponder_whenInteractionDisabled_returnsFalse() {
    // given: a hosting view in a window
    let window = TestWindow()
    let view = SwiftUIHostingView(rootView: SwiftUI.Text("Hello, World!"))
    window.contentView().addSubview(view)

    // when: user interaction is disabled
    view.isUserInteractionEnabled = false

    // then: the view refuses first responder
    expect(view.becomeFirstResponder()) == false
  }

  func test_appKit_becomeFirstResponder_whenInteractionEnabled_delegatesToSuper() {
    // given: a hosting view in a window
    let window = TestWindow()
    let view = SwiftUIHostingView(rootView: SwiftUI.Text("Hello, World!"))
    window.contentView().addSubview(view)

    // when: user interaction is enabled
    view.isUserInteractionEnabled = true

    // then: the result mirrors the underlying NSHostingView's response
    let plainHostingView = NSHostingView(rootView: SwiftUI.Text("Hello, World!"))
    window.contentView().addSubview(plainHostingView)
    expect(view.becomeFirstResponder()) == plainHostingView.becomeFirstResponder()
  }

  #endif

  // MARK: - UIKit specific

  #if canImport(UIKit)

  func test_uiKit_layoutSubviews_resizesHostingControllerView() {
    // given: a hosting view laid out at an initial size
    let view = SwiftUIHostingView(rootView: SwiftUI.Color.black)
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 150)
    view.layoutIfNeeded()

    let hostingControllerView = try? view.subviews.first.unwrap()
    expect(hostingControllerView?.frame) == CGRect(x: 0, y: 0, width: 200, height: 150)

    // when: the bounds change and layout runs
    view.frame = CGRect(x: 0, y: 0, width: 300, height: 250)
    view.layoutIfNeeded()

    // then: the bounds change re-applies the frame to the hosting controller view
    expect(hostingControllerView?.frame) == CGRect(x: 0, y: 0, width: 300, height: 250)
  }

  func test_uiKit_hostingControllerView_hasClearBackground() {
    // given: a hosting view laid out
    let view = SwiftUIHostingView(rootView: SwiftUI.Text("Hello, World!"))
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.layoutIfNeeded()

    // then: the hosting controller view has a clear background
    let hostingControllerView = try? view.subviews.first.unwrap()
    expect(hostingControllerView?.backgroundColor) == .clear
  }

  #endif
}
