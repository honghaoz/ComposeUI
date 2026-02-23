//
//  ComposeView+PreRenderHandlerTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/3/25.
//

import ChouTiTest

@testable import ComposeUI
import ChouTi

class ComposeView_PreRenderHandlerTests: XCTestCase {

  func test_preRenderHandler() {
    // given: a compose view with a content
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      ColorNode(.red)
        .frame(width: 100, height: 200)
    }

    // set up the pre-render handler to track the callback arguments
    var preRenderCallCount = 0
    var callbackContentSize: CGSize?
    var callbackRenderBounds: CGRect?
    var callbackRenderType: ComposeView.RenderType?
    #if DEBUG
    var eventOrder: [String] = []
    var requestedVisibleBounds: CGRect?
    #endif

    view.onPreRender { view, context in
      preRenderCallCount += 1
      callbackContentSize = context.contentSize
      callbackRenderBounds = context.renderBounds
      callbackRenderType = context.renderType
      #if DEBUG
      eventOrder.append("preRender")
      #endif

      view.setContentOffset(CGPoint(x: 0, y: 100))
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

    // then: the pre-render handler should be called with the correct arguments
    expect(preRenderCallCount) == 1
    expect(callbackContentSize) == CGSize(width: 100, height: 200)
    expect(callbackRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(callbackRenderType) == .refresh(isAnimated: false)

    // then: the content offset should be updated
    expect(view.contentOffset().y) == 100

    #if DEBUG
    expect(eventOrder) == ["preRender", "renderItems"]
    expect(requestedVisibleBounds) == CGRect(x: 0, y: 100, width: 100, height: 100)
    #endif

    // when: the view is scrolled
    view.setContentOffset(CGPoint(x: 0, y: 10))
    view.layoutIfNeeded()

    // then: the pre-render handler should be called with the correct arguments
    expect(preRenderCallCount) == 2
    expect(callbackContentSize) == CGSize(width: 100, height: 200)
    expect(callbackRenderBounds) == CGRect(x: 0, y: 10, width: 100, height: 100)
    expect(callbackRenderType) == .scroll(previousBounds: CGRect(x: 0, y: 100, width: 100, height: 100))
    expect(view.contentOffset().y) == 100

    #if DEBUG
    expect(eventOrder) == ["preRender", "renderItems", "preRender", "renderItems"]
    expect(requestedVisibleBounds) == CGRect(x: 0, y: 100, width: 100, height: 100)
    #endif

    expect(view.bounds()) == CGRect(x: 0, y: 100, width: 100, height: 100)

    // when: the view is resized
    view.frame.size = CGSize(width: 150, height: 150)
    expect(view.bounds()) == CGRect(x: 0, y: 50, width: 150, height: 150) // y: 50 (maxOffsetY) = 200 - 150

    view.layoutIfNeeded()

    // then: the pre-render handler should be called with the correct arguments
    expect(preRenderCallCount) == 3
    expect(callbackContentSize) == CGSize(width: 150, height: 200)
    expect(callbackRenderBounds) == CGRect(x: 0, y: 50, width: 150, height: 150)
    expect(callbackRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 100, width: 100, height: 100))
    #if canImport(AppKit)
    expect(view.contentOffset().y) == 50 // AppKit doesn't allow over scroll
    #endif
    #if canImport(UIKit)
    expect(view.contentOffset().y) == 100
    #endif

    #if DEBUG
    expect(eventOrder) == ["preRender", "renderItems", "preRender", "renderItems", "preRender", "renderItems"]
    #if canImport(AppKit)
    expect(requestedVisibleBounds) == CGRect(x: -25, y: 50, width: 150, height: 150) // AppKit doesn't allow over scroll
    #endif
    #if canImport(UIKit)
    expect(requestedVisibleBounds) == CGRect(x: -25, y: 100, width: 150, height: 150)
    #endif
    #endif
  }

  func test_preRenderHandler_boundsSizeChanged() {
    // test that the pre-render handler is called with bounds size changed
    // should expect a follow-up layout to be scheduled

    // given: a compose view with a content
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      ColorNode(.red)
        .frame(width: 100, height: 200)
    }

    // set up the pre-render handler that changes the bounds size
    view.onPreRender { view, _ in
      view.setBounds(CGRect(x: 0, y: 10, width: 150, height: 150))
    }

    // when: the view is refreshed
    view.refresh(animated: false)

    // then: the old bounds should be used for the immediate render
    expect(view.lastRenderBounds) == CGRect(x: 0, y: 10, width: 100, height: 100)

    // then: the follow-up render should use the new bounds eventually
    expect(view.lastRenderBounds).toEventually(beEqual(to: CGRect(x: 0, y: 10, width: 150, height: 150)))
  }
}

private extension ComposeView {

  var lastRenderBounds: CGRect? {
    try? (DynamicLookup(self).property("lastRenderBounds") as? CGRect).unwrap()
  }
}
