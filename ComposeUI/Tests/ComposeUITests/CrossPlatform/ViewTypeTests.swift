//
//  ViewTypeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/19/26.
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

import ChouTiTest

@testable import ComposeUI

class ViewTypeTests: XCTestCase {

  #if canImport(AppKit)
  func test_layer_viewWithoutLayer_asserts() {
    // given: a view that isn't layer-backed, with a handler that records the assertions
    let view = BaseView()
    view.wantsLayer = false

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: getting the view's layer
    let layer = view.layer()

    // then: it asserts, and makes the view layer-backed to return its layer
    expect(assertionMessages) == ["\(view) should be layer backed. Please set `wantsLayer == true`."]
    expect(view.wantsLayer) == true
    expect(layer) === view.layer
  }
  #endif
}
