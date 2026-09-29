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
        invokedContentUpdateContext = view.test.contentUpdateContext
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
    expect(view.test.lastRenderBounds) == nil

    // when: the view lays out initially
    view.layoutIfNeeded()

    // then: the view is rendered with the expected bounds
    #if canImport(AppKit)
    // after layout, the bounds() should consider the scrollers
    if #available(macOS 26.0, *) {
      expect(view.bounds()) == CGRect(x: 0, y: 0, width: 103, height: 63)
    } else {
      expect(view.bounds()) == CGRect(x: 0, y: 0, width: 105, height: 65)
    }
    #endif
    #if canImport(UIKit)
    expect(view.bounds()) == CGRect(x: 0, y: 0, width: 120, height: 80)
    #endif

    expect(updateCount) == 1

    // then: expect the contentUpdateContext is set with correct render bounds
    let initialContext = try unwrap(invokedContentUpdateContext)
    var expectedContext = ComposeView.ContentUpdateContext(
      contentNode: initialContext.contentNode,
      contentEvaluation: initialContext.contentEvaluation,
      updateType: .boundsChange,
      previousRenderBounds: nil,
      renderBounds: CGRect(x: 0, y: 0, width: 120, height: 80),
      preparedAnimationDecision: .all
    )
    expect(invokedContentUpdateContext) == expectedContext

    // then: lastRenderBounds does not consider the scrollers
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120, height: 80)

    // reset
    invokedContentUpdateContext = nil

    // when: layout again without changing the bounds
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: should not update as no bounds change
    expect(updateCount) == 1
    expect(invokedContentUpdateContext) == nil
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120, height: 80)

    // when: adjust scroll position and layout again
    view.setContentOffset(CGPoint(x: 0, y: 10))
    view.layoutIfNeeded()

    // then: should update
    expect(updateCount) == 2

    // then: expect the contentUpdateContext is set with correct render bounds
    expectedContext = ComposeView.ContentUpdateContext(
      contentNode: initialContext.contentNode,
      contentEvaluation: initialContext.contentEvaluation,
      updateType: .boundsChange,
      previousRenderBounds: CGRect(x: 0, y: 0, width: 120, height: 80),
      renderBounds: CGRect(x: 0, y: 10, width: 120, height: 80),
      preparedAnimationDecision: .all
    )
    expect(invokedContentUpdateContext) == expectedContext

    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 10, width: 120, height: 80)
  }

  #if canImport(AppKit)
  func test_renderBounds_hidingLegacyScroller_scrolledToBottom() {
    // given: a view with legacy scrollers, scrolled to the bottom of rows that overflow both axes
    var contentSize = CGSize(width: 200, height: 300)
    let view = ComposeView {
      VStack {
        for _ in 0 ..< Int(contentSize.height / 10) {
          LayerNode().frame(width: contentSize.width, height: 10)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    useLegacyScrollers(view)
    view.refresh(animated: false)

    view.setContentOffset(CGPoint(x: 0, y: 200))
    view.layoutIfNeeded()
    expect(view.hasHorizontalScroller) == true
    expect(view.contentOffset()) == CGPoint(x: 0, y: 200)

    // when: a refresh shortens the rows, so the clip view clamps the offset while the horizontal scroller shows, and
    // fits them horizontally, which hides the scroller and clamps the offset again
    contentSize = CGSize(width: 100, height: 250)
    view.refresh(animated: false)

    // then: the pass renders the rows at the offset the view ends up with
    expect(view.hasHorizontalScroller) == false
    expect(view.contentOffset()) == CGPoint(x: 0, y: 150)
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 150, width: 100, height: 100)
    expect(renderedFrames(in: view)) == (15 ..< 25).map { CGRect(x: 0, y: CGFloat($0) * 10, width: 100, height: 10) }
  }

  func test_renderBounds_hidingLegacyScroller_scrolledToRightEdge() {
    // given: a view with legacy scrollers, scrolled to the right edge of columns that overflow both axes
    var contentSize = CGSize(width: 300, height: 200)
    let view = ComposeView {
      HStack {
        for _ in 0 ..< Int(contentSize.width / 10) {
          LayerNode().frame(width: 10, height: contentSize.height)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    useLegacyScrollers(view)
    view.refresh(animated: false)

    view.setContentOffset(CGPoint(x: 200, y: 0))
    view.layoutIfNeeded()
    expect(view.hasVerticalScroller) == true
    expect(view.contentOffset()) == CGPoint(x: 200, y: 0)

    // when: a refresh narrows the columns, so the clip view clamps the offset while the vertical scroller shows, and
    // fits them vertically, which hides the scroller and clamps the offset again
    contentSize = CGSize(width: 250, height: 100)
    view.refresh(animated: false)

    // then: the pass renders the columns at the offset the view ends up with
    expect(view.hasVerticalScroller) == false
    expect(view.contentOffset()) == CGPoint(x: 150, y: 0)
    expect(view.test.lastRenderBounds) == CGRect(x: 150, y: 0, width: 100, height: 100)
    expect(renderedFrames(in: view)) == (15 ..< 25).map { CGRect(x: CGFloat($0) * 10, y: 0, width: 10, height: 100) }
  }

  func test_renderBounds_showingLegacyScroller_scrolledToBottom() {
    // given: a view with legacy scrollers, scrolled to the bottom of rows that overflow only vertically
    var contentSize = CGSize(width: 100, height: 300)
    let view = ComposeView {
      VStack {
        for _ in 0 ..< Int(contentSize.height / 10) {
          LayerNode().frame(width: contentSize.width, height: 10)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    useLegacyScrollers(view)
    view.refresh(animated: false)

    view.setContentOffset(CGPoint(x: 0, y: 200))
    view.layoutIfNeeded()
    expect(view.hasHorizontalScroller) == false
    expect(view.contentOffset()) == CGPoint(x: 0, y: 200)

    // when: a refresh shortens the rows, so the clip view clamps the offset, and widens them, which shows the
    // horizontal scroller and shrinks the clip view
    contentSize = CGSize(width: 200, height: 250)
    view.refresh(animated: false)

    // then: the pass renders the rows at the offset the view ends up with
    expect(view.hasHorizontalScroller) == true
    expect(view.contentOffset()) == CGPoint(x: 0, y: 150)
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 150, width: 100, height: 100)
    expect(renderedFrames(in: view)) == (15 ..< 25).map { CGRect(x: 0, y: CGFloat($0) * 10, width: 200, height: 10) }
  }

  func test_renderBounds_legacyScrollers_scrolledToTheEnd_keepsTheOffset() {
    // given: a view with legacy scrollers, showing rows that overflow both axes
    let view = ComposeView {
      VStack {
        for _ in 0 ..< 30 {
          LayerNode().frame(width: 200, height: 10)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    useLegacyScrollers(view)
    view.refresh(animated: false)
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == true

    var renderBounds: [CGRect] = []
    view.onDidRender { _, context in
      renderBounds.append(context.renderBounds)
    }

    // when: scroll to the end, which the shown scrollers put a scroller thickness further than without them
    let maxOffsetY = view.maxOffsetY
    view.setContentOffset(CGPoint(x: 0, y: maxOffsetY))
    view.layoutIfNeeded()

    // then: the view stays at the end, rendered once for the full view size, with the rows that fill the viewport
    expect(view.contentOffset()) == CGPoint(x: 0, y: maxOffsetY)
    expect(renderBounds) == [CGRect(x: 0, y: maxOffsetY, width: 100, height: 100)]
    expect(renderedFrames(in: view)) == (21 ..< 30).map { CGRect(x: 0, y: CGFloat($0) * 10, width: 200, height: 10) }
  }

  func test_renderBounds_legacyScrollers_scrolledSideways_keepsTheOffset() {
    // given: a view with legacy scrollers, showing rows as wide as the view that overflow only vertically, so the shown
    // vertical scroller leaves a scroller thickness of the rows to scroll to sideways
    let view = ComposeView {
      VStack {
        for _ in 0 ..< 30 {
          LayerNode().frame(width: 100, height: 10)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    useLegacyScrollers(view)
    view.refresh(animated: false)
    expect(view.hasHorizontalScroller) == false
    expect(view.hasVerticalScroller) == true

    var renderBounds: [CGRect] = []
    view.onDidRender { _, context in
      renderBounds.append(context.renderBounds)
    }

    // when: scroll sideways within that thickness
    view.setContentOffset(CGPoint(x: 10, y: 50))
    view.layoutIfNeeded()

    // then: the view stays where it's scrolled to, rendered once for the full view size
    expect(view.contentOffset()) == CGPoint(x: 10, y: 50)
    expect(renderBounds) == [CGRect(x: 10, y: 50, width: 100, height: 100)]
  }

  func test_renderBounds_legacyScrollers_contentShrinksAtTheEnd_rendersOnce() {
    // given: a view with legacy scrollers, scrolled to the bottom of rows that overflow both axes
    var rowCount = 30
    let view = ComposeView {
      VStack {
        for _ in 0 ..< rowCount {
          LayerNode().frame(width: 200, height: 10)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    useLegacyScrollers(view)
    view.refresh(animated: false)
    view.setContentOffset(CGPoint(x: 0, y: 200))
    view.layoutIfNeeded()
    expect(view.contentOffset()) == CGPoint(x: 0, y: 200)

    var renderBounds: [CGRect] = []
    view.onDidRender { _, context in
      renderBounds.append(context.renderBounds)
    }

    // when: a refresh shortens the rows while the scrollers stay shown, so the content size clamps the offset to the
    // new end
    rowCount = 25
    view.refresh(animated: false)

    // then: the view renders once, at the new end, for the full view size
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == true
    expect(view.contentOffset()) == CGPoint(x: 0, y: view.maxOffsetY)
    expect(renderBounds) == [CGRect(x: 0, y: view.maxOffsetY, width: 100, height: 100)]
  }

  func test_renderBounds_legacyScrollers_sizeFollowsTheFrameBorderAndMagnification() {
    // given: a view with a line border, content insets, and a magnification of 2, showing both legacy scrollers
    let view = ComposeView {
      LayerNode().frame(width: 300, height: 300)
    }
    view.frame = CGRect(x: 0, y: 0, width: 122, height: 82)
    useLegacyScrollers(view)
    view.borderType = .lineBorder
    view.contentInsets = NSEdgeInsets(top: 10, left: 5, bottom: 7, right: 3)
    view.allowsMagnification = true
    view.magnification = 2

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the content lays out for the frame inside the 1 pt border, in the document's magnified coordinates,
    // regardless of the scrollers and the insets
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == true
    expect(view.test.lastRenderBounds?.size) == CGSize(width: 60, height: 40)
  }

  /// Makes the view show legacy scrollers for the axes its content overflows, so a shown scroller shrinks the clip view.
  private func useLegacyScrollers(_ view: ComposeView) {
    view.scrollIndicatorBehavior = .auto
    view.scrollerStyle = .legacy
  }

  /// The frames of the rendered layers, ordered from top to bottom, then from left to right.
  private func renderedFrames(in view: ComposeView) -> [CGRect] {
    let frames = view.contentView().layer?.sublayers?.map(\.frame) ?? []
    return frames.sorted { ($0.minY, $0.minX) < ($1.minY, $1.minX) }
  }
  #endif
}
