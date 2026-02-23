//
//  ComposeView+WillRenderHandlerTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/3/25.
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

import XCTest
import Foundation

@testable import ComposeUI

class ComposeView_WillRenderHandlerTests: XCTestCase {

  func test_willRenderHandler() {
    // given: a compose view with a content
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      ColorNode(.red)
        .frame(width: 100, height: 200)
    }

    // set up the will-render handler to track the callback arguments
    var willRenderCallCount = 0
    var callbackContentSize: CGSize?
    var callbackRenderBounds: CGRect?
    var callbackRenderType: ComposeView.RenderType?
    #if DEBUG
    var eventOrder: [String] = []
    var requestedVisibleBounds: CGRect?
    #endif

    view.onWillRender { view, context in
      willRenderCallCount += 1
      callbackContentSize = context.contentSize
      callbackRenderBounds = context.renderBounds
      callbackRenderType = context.renderType
      #if DEBUG
      eventOrder.append("willRender")
      #endif

      view.setContentOffset(CGPoint(x: 0, y: 100), animated: false)
    }

    #if DEBUG
    view.debug { _, event in
      if case .renderWillRequestRenderableItems(let visibleBounds) = event {
        requestedVisibleBounds = visibleBounds
        eventOrder.append("renderItems")
      }
    }
    #endif

    // when: the view is refreshed initially
    view.refresh(animated: false)

    // then: the will-render handler should be called with the correct arguments
    XCTAssertEqual(willRenderCallCount, 1)
    XCTAssertEqual(callbackContentSize, CGSize(width: 100, height: 200))
    XCTAssertEqual(callbackRenderBounds, CGRect(x: 0, y: 0, width: 100, height: 100))
    XCTAssertEqual(callbackRenderType, .refresh(isAnimated: false))

    // then: the content offset should be updated
    XCTAssertEqual(view.contentOffset.y, 100)

    #if DEBUG
    XCTAssertEqual(eventOrder, ["willRender", "renderItems"])
    XCTAssertEqual(requestedVisibleBounds, CGRect(x: 0, y: 100, width: 100, height: 100))
    #endif

    // when: the view is scrolled
    view.setContentOffset(CGPoint(x: 0, y: 10), animated: false)
    view.layoutIfNeeded()

    // then: the will-render handler should be called with the correct arguments
    XCTAssertEqual(willRenderCallCount, 2)
    XCTAssertEqual(callbackContentSize, CGSize(width: 100, height: 200))
    XCTAssertEqual(callbackRenderBounds, CGRect(x: 0, y: 10, width: 100, height: 100))
    XCTAssertEqual(callbackRenderType, .scroll(previousBounds: CGRect(x: 0, y: 100, width: 100, height: 100)))
    XCTAssertEqual(view.contentOffset.y, 100)

    #if DEBUG
    XCTAssertEqual(eventOrder, ["willRender", "renderItems", "willRender", "renderItems"])
    XCTAssertEqual(requestedVisibleBounds, CGRect(x: 0, y: 100, width: 100, height: 100))
    #endif

    XCTAssertEqual(view.bounds, CGRect(x: 0, y: 100, width: 100, height: 100))

    // when: the view is resized
    view.frame.size = CGSize(width: 150, height: 150)
    XCTAssertEqual(view.bounds, CGRect(x: 0, y: 50, width: 150, height: 150)) // y: 50 (maxOffsetY) = 200 - 150

    view.layoutIfNeeded()

    // then: the will-render handler should be called with the correct arguments
    XCTAssertEqual(willRenderCallCount, 3)
    XCTAssertEqual(callbackContentSize, CGSize(width: 150, height: 200))
    XCTAssertEqual(callbackRenderBounds, CGRect(x: 0, y: 50, width: 150, height: 150))
    XCTAssertEqual(callbackRenderType, .boundsChange(previousBounds: CGRect(x: 0, y: 100, width: 100, height: 100)))
    XCTAssertEqual(view.contentOffset.y, 100)

    #if DEBUG
    XCTAssertEqual(eventOrder, ["willRender", "renderItems", "willRender", "renderItems", "willRender", "renderItems"])
    XCTAssertEqual(requestedVisibleBounds, CGRect(x: -25, y: 100, width: 150, height: 150))
    #endif
  }

  func test_willRenderHandler_boundsSizeChanged() {
    // test that the will-render handler is called with bounds size changed
    // should expect a follow-up layout to be scheduled

    // given: a compose view with a content
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      ColorNode(.red)
        .frame(width: 100, height: 200)
    }

    // set up the will-render handler that changes the bounds size
    view.onWillRender { view, _ in
      view.bounds = CGRect(x: 0, y: 10, width: 150, height: 150)
    }

    // when: the view is refreshed
    view.refresh(animated: false)

    // then: the old bounds should be used for the immediate render
    XCTAssertEqual(view.test.lastRenderBounds, CGRect(x: 0, y: 10, width: 100, height: 100))

    // then: the follow-up render should use the new bounds eventually
    XCTAssertEventuallyEqual(view.test.lastRenderBounds, CGRect(x: 0, y: 10, width: 150, height: 150))
  }
}
