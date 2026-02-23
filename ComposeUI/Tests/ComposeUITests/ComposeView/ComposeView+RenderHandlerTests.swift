//
//  ComposeView+RenderHandlerTests.swift
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

import ChouTiTest

@testable import ComposeUI

class ComposeView_RenderHandlerTests: XCTestCase {

  func test_renderHandlers_contentSizeSmallerThanContainerSize() {
    // given: a compose view with content smaller than the container
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      ColorNode(.red)
        .frame(width: 50, height: 80)
    }

    var callOrder: [String] = []

    var willLayoutContainerSize: CGSize?
    var willLayoutRenderType: ComposeView.RenderType?
    view.onWillLayout { _, context in
      callOrder.append("willLayout")
      willLayoutContainerSize = context.containerSize
      willLayoutRenderType = context.renderType
    }

    var willRenderContentSize: CGSize?
    var willRenderRenderBounds: CGRect?
    var willRenderRenderType: ComposeView.RenderType?
    view.onWillRender { _, context in
      callOrder.append("willRender")
      willRenderContentSize = context.contentSize
      willRenderRenderBounds = context.renderBounds
      willRenderRenderType = context.renderType
    }

    var didRenderContentSize: CGSize?
    var didRenderRenderBounds: CGRect?
    var didRenderRenderType: ComposeView.RenderType?
    view.onDidRender { _, context in
      callOrder.append("didRender")
      didRenderContentSize = context.contentSize
      didRenderRenderBounds = context.renderBounds
      didRenderRenderType = context.renderType
    }

    // when: the view is refreshed
    view.refresh(animated: false)

    // then: all handlers should be called in the correct order
    expect(callOrder) == ["willLayout", "willRender", "didRender"]

    // then: willLayout should receive the container size
    expect(willLayoutContainerSize) == CGSize(width: 100, height: 100)
    expect(willLayoutRenderType) == .refresh(isAnimated: false)

    // then: willRender should receive the content size adjusted to the container size
    expect(willRenderContentSize) == CGSize(width: 100, height: 100)
    expect(willRenderRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(willRenderRenderType) == .refresh(isAnimated: false)

    // then: didRender should receive the same adjusted content size
    expect(didRenderContentSize) == CGSize(width: 100, height: 100)
    expect(didRenderRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(didRenderRenderType) == .refresh(isAnimated: false)

    // when: the view is resized
    callOrder = []
    willLayoutContainerSize = nil
    willLayoutRenderType = nil
    willRenderContentSize = nil
    willRenderRenderBounds = nil
    willRenderRenderType = nil
    didRenderContentSize = nil
    didRenderRenderBounds = nil
    didRenderRenderType = nil

    view.frame.size = CGSize(width: 150, height: 150)
    view.layoutIfNeeded()

    // then: all handlers should be called with bounds change
    expect(callOrder) == ["willLayout", "willRender", "didRender"]

    expect(willLayoutContainerSize) == CGSize(width: 150, height: 150)
    expect(willLayoutRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100))

    // the content (50x80) is still smaller than the new container (150x150), so content size is adjusted
    expect(willRenderContentSize) == CGSize(width: 150, height: 150)
    expect(willRenderRenderBounds) == CGRect(x: 0, y: 0, width: 150, height: 150)
    expect(willRenderRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100))

    expect(didRenderContentSize) == CGSize(width: 150, height: 150)
    expect(didRenderRenderBounds) == CGRect(x: 0, y: 0, width: 150, height: 150)
    expect(didRenderRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100))
  }

  func test_renderHandlers_contentSizeLargerThanContainerSize() {
    // given: a compose view with content larger than the container
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      ColorNode(.red)
        .frame(width: 100, height: 200)
    }

    var callOrder: [String] = []

    var willLayoutContainerSize: CGSize?
    var willLayoutRenderType: ComposeView.RenderType?
    view.onWillLayout { _, context in
      callOrder.append("willLayout")
      willLayoutContainerSize = context.containerSize
      willLayoutRenderType = context.renderType
    }

    var willRenderContentSize: CGSize?
    var willRenderRenderBounds: CGRect?
    var willRenderRenderType: ComposeView.RenderType?
    view.onWillRender { _, context in
      callOrder.append("willRender")
      willRenderContentSize = context.contentSize
      willRenderRenderBounds = context.renderBounds
      willRenderRenderType = context.renderType
    }

    var didRenderContentSize: CGSize?
    var didRenderRenderBounds: CGRect?
    var didRenderRenderType: ComposeView.RenderType?
    view.onDidRender { _, context in
      callOrder.append("didRender")
      didRenderContentSize = context.contentSize
      didRenderRenderBounds = context.renderBounds
      didRenderRenderType = context.renderType
    }

    // when: the view is refreshed
    view.refresh(animated: false)

    // then: all handlers should be called in the correct order
    expect(callOrder) == ["willLayout", "willRender", "didRender"]

    // then: willLayout should receive the container size
    expect(willLayoutContainerSize) == CGSize(width: 100, height: 100)
    expect(willLayoutRenderType) == .refresh(isAnimated: false)

    // then: willRender should receive the actual content size (not adjusted)
    expect(willRenderContentSize) == CGSize(width: 100, height: 200)
    expect(willRenderRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(willRenderRenderType) == .refresh(isAnimated: false)

    // then: didRender should receive the same content size
    expect(didRenderContentSize) == CGSize(width: 100, height: 200)
    expect(didRenderRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(didRenderRenderType) == .refresh(isAnimated: false)

    // when: the view is scrolled
    callOrder = []
    willLayoutContainerSize = nil
    willLayoutRenderType = nil
    willRenderContentSize = nil
    willRenderRenderBounds = nil
    willRenderRenderType = nil
    didRenderContentSize = nil
    didRenderRenderBounds = nil
    didRenderRenderType = nil

    view.setContentOffset(CGPoint(x: 0, y: 50))
    view.layoutIfNeeded()

    // then: all handlers should be called with scroll render type
    expect(callOrder) == ["willLayout", "willRender", "didRender"]

    expect(willLayoutContainerSize) == CGSize(width: 100, height: 100)
    expect(willLayoutRenderType) == .scroll(previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100))

    expect(willRenderContentSize) == CGSize(width: 100, height: 200)
    expect(willRenderRenderBounds) == CGRect(x: 0, y: 50, width: 100, height: 100)
    expect(willRenderRenderType) == .scroll(previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100))

    expect(didRenderContentSize) == CGSize(width: 100, height: 200)
    expect(didRenderRenderBounds) == CGRect(x: 0, y: 50, width: 100, height: 100)
    expect(didRenderRenderType) == .scroll(previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100))

    // when: the view is resized
    callOrder = []
    willLayoutContainerSize = nil
    willLayoutRenderType = nil
    willRenderContentSize = nil
    willRenderRenderBounds = nil
    willRenderRenderType = nil
    didRenderContentSize = nil
    didRenderRenderBounds = nil
    didRenderRenderType = nil

    view.frame.size = CGSize(width: 150, height: 150)
    view.layoutIfNeeded()

    // then: all handlers should be called with bounds change render type
    expect(callOrder) == ["willLayout", "willRender", "didRender"]

    expect(willLayoutContainerSize) == CGSize(width: 150, height: 150)
    expect(willLayoutRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 50, width: 100, height: 100))

    // the content width (100) is now smaller than the container width (150), so content size width is adjusted
    expect(willRenderContentSize) == CGSize(width: 150, height: 200)
    expect(willRenderRenderBounds) == CGRect(x: 0, y: 50, width: 150, height: 150)
    expect(willRenderRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 50, width: 100, height: 100))

    expect(didRenderContentSize) == CGSize(width: 150, height: 200)
    expect(didRenderRenderBounds) == CGRect(x: 0, y: 50, width: 150, height: 150)
    expect(didRenderRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 50, width: 100, height: 100))
  }

  func test_willRenderHandler() {
    // given: a compose view with a content
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      ColorNode(.red)
        .frame(width: 100, height: 200)
    }

    // set up the will-render handler to track the callback arguments
    var eventOrder: [String] = []

    var willRenderCallCount = 0
    var willRenderContentSize: CGSize?
    var willRenderRenderBounds: CGRect?
    var willRenderRenderType: ComposeView.RenderType?

    view.onWillRender { view, context in
      eventOrder.append("willRender")

      willRenderCallCount += 1
      willRenderContentSize = context.contentSize
      willRenderRenderBounds = context.renderBounds
      willRenderRenderType = context.renderType

      // when: adjust the content offset to be at the bottom
      view.setContentOffset(CGPoint(x: 0, y: 100))
    }

    var requestedVisibleBounds: CGRect?
    view.debug { _, event in
      if case .renderWillRequestRenderableItems(let visibleBounds) = event {
        requestedVisibleBounds = visibleBounds
        eventOrder.append("renderItems")
      }
    }

    // when: the view is refreshed initially
    view.refresh(animated: false)

    // then: the will-render handler should be called with the correct arguments
    expect(willRenderCallCount) == 1
    expect(willRenderContentSize) == CGSize(width: 100, height: 200)
    expect(willRenderRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(willRenderRenderType) == .refresh(isAnimated: false)

    // then: the content offset should be updated
    expect(view.contentOffset().y) == 100

    expect(eventOrder) == ["willRender", "renderItems"]
    expect(requestedVisibleBounds) == CGRect(x: 0, y: 100, width: 100, height: 100)

    // when: the view is scrolled
    view.setContentOffset(CGPoint(x: 0, y: 10))
    view.layoutIfNeeded()

    // then: the will-render handler should be called with the correct arguments
    expect(willRenderCallCount) == 2
    expect(willRenderContentSize) == CGSize(width: 100, height: 200)
    expect(willRenderRenderBounds) == CGRect(x: 0, y: 10, width: 100, height: 100)
    expect(willRenderRenderType) == .scroll(previousBounds: CGRect(x: 0, y: 100, width: 100, height: 100))
    expect(view.contentOffset().y) == 100

    expect(eventOrder) == ["willRender", "renderItems", "willRender", "renderItems"]
    expect(requestedVisibleBounds) == CGRect(x: 0, y: 100, width: 100, height: 100)

    expect(view.bounds()) == CGRect(x: 0, y: 100, width: 100, height: 100)

    // when: the view is resized
    view.frame.size = CGSize(width: 150, height: 150)
    expect(view.bounds()) == CGRect(x: 0, y: 50, width: 150, height: 150) // y: 50 (maxOffsetY) = 200 - 150

    view.layoutIfNeeded()

    // then: the will-render handler should be called with the correct arguments
    expect(willRenderCallCount) == 3
    expect(willRenderContentSize) == CGSize(width: 150, height: 200)
    expect(willRenderRenderBounds) == CGRect(x: 0, y: 50, width: 150, height: 150)
    expect(willRenderRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 100, width: 100, height: 100))
    #if canImport(AppKit)
    expect(view.contentOffset().y) == 50 // AppKit doesn't allow over scroll
    #endif
    #if canImport(UIKit)
    expect(view.contentOffset().y) == 100
    #endif

    expect(eventOrder) == [
      "willRender", "renderItems", "willRender", "renderItems", "willRender", "renderItems",
    ]
    #if canImport(AppKit)
    expect(requestedVisibleBounds) == CGRect(x: -25, y: 50, width: 150, height: 150) // AppKit doesn't allow over scroll
    #endif
    #if canImport(UIKit)
    expect(requestedVisibleBounds) == CGRect(x: -25, y: 100, width: 150, height: 150)
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
      view.setBounds(CGRect(x: 0, y: 10, width: 150, height: 150))
    }

    // when: the view is refreshed
    view.refresh(animated: false)

    // then: the old bounds should be used for the immediate render
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 10, width: 100, height: 100)

    // then: the follow-up render should use the new bounds eventually
    expect(view.test.lastRenderBounds).toEventually(
      beEqual(to: CGRect(x: 0, y: 10, width: 150, height: 150))
    )
  }
}
