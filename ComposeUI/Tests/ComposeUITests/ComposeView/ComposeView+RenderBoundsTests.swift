//
//  ComposeView+RenderBoundsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/3/25.
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
import ChouTi

class ComposeView_RenderBoundsTests: XCTestCase {

  /// Test the render bounds used in rendering is correct.
  ///
  /// It mainly verifies the bounds used in rendering is correct on AppKit because the scrollers can affect the bounds.
  func test_renderBounds() throws {
    // given: a compose view with hooks to track the content update context and the update count
    var updateCount = 0
    let view = ComposeView {
      LayerNode()
        .frame(width: 200, height: 200)
        .onUpdate { _, _ in
          updateCount += 1
        }
    }

    var invokedContentUpdateContext: ComposeView.ContentUpdateContext?
    view.debug(eventHandler: { view, event in
      switch event {
      case .renderWillBegin:
        invokedContentUpdateContext = view.contentUpdateContext
      default:
        break
      }
    })

    view.frame = CGRect(x: 0, y: 0, width: 120, height: 80)

    #if canImport(AppKit)
    view.scrollIndicatorBehavior = .auto
    // use legacy scrollers so the scroller thickness affects bounds().
    view.scrollerStyle = .legacy
    view.hasHorizontalScroller = true
    view.hasVerticalScroller = true
    #endif

    // before layout, the lastRenderBounds is not set
    expect(view.lastRenderBounds) == .zero

    view.layoutIfNeeded()

    #if canImport(AppKit)
    // after layout, the bounds() should consider the scrollers
    expect(view.bounds()) == CGRect(x: 0, y: 0, width: 105, height: 65)
    #endif
    #if canImport(UIKit)
    expect(view.bounds()) == CGRect(x: 0, y: 0, width: 120, height: 80)
    #endif

    expect(updateCount) == 1

    // expect the contentUpdateContext is set with correct render bounds
    var expectedContext = ComposeView.ContentUpdateContext(
      updateType: .boundsChange(previousRenderBounds: .zero),
      renderBounds: CGRect(x: 0, y: 0, width: 120, height: 80)
    )
    expectedContext.isRendering = true
    expect(invokedContentUpdateContext) == expectedContext

    // expect the lastRenderBounds should NOT consider the scrollers
    expect(view.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120, height: 80)

    // reset
    invokedContentUpdateContext = nil

    // layout again without changing the bounds
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // should not update as no bounds change
    expect(updateCount) == 1
    expect(invokedContentUpdateContext) == nil
    expect(view.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120, height: 80)

    // adjust scroll position and layout again
    view.setContentOffset(CGPoint(x: 0, y: 10))
    view.layoutIfNeeded()

    // should update
    expect(updateCount) == 2

    // expect the contentUpdateContext is set with correct render bounds
    expectedContext = ComposeView.ContentUpdateContext(
      updateType: .boundsChange(previousRenderBounds: CGRect(x: 0, y: 0, width: 120, height: 80)),
      renderBounds: CGRect(x: 0, y: 10, width: 120, height: 80)
    )
    expectedContext.isRendering = true
    expect(invokedContentUpdateContext) == expectedContext

    expect(view.lastRenderBounds) == CGRect(x: 0, y: 10, width: 120, height: 80)
  }
}

private extension ComposeView {

  var contentUpdateContext: ContentUpdateContext? {
    try? (DynamicLookup(self).property("contentUpdateContext") as? ContentUpdateContext).unwrap()
  }

  var lastRenderBounds: CGRect? {
    try? (DynamicLookup(self).property("lastRenderBounds") as? CGRect).unwrap()
  }
}
