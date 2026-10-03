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
    // use legacy scrollers so the scroller thickness affects the visible size.
    view.scrollerStyle = .legacy
    view.hasHorizontalScroller = true
    view.hasVerticalScroller = true
    #endif

    // before layout, the lastRenderBounds is not set
    expect(view.test.lastRenderBounds) == nil

    // when: the view lays out initially
    view.layoutIfNeeded()

    // then: the view is rendered with the expected bounds
    expect(view.contentOffset) == .zero
    #if canImport(AppKit)
    // after layout, the visible size should consider the scrollers
    if #available(macOS 26.0, *) {
      expect(view.visibleSize) == CGSize(width: 103, height: 63)
    } else {
      expect(view.visibleSize) == CGSize(width: 105, height: 65)
    }
    #endif
    #if canImport(UIKit)
    expect(view.visibleSize) == CGSize(width: 120, height: 80)
    #endif

    expect(updateCount) == 1

    // then: expect the contentUpdateContext is set with the view's bounds at the content offset
    let visibleSize = view.visibleSize
    let initialContext = try unwrap(invokedContentUpdateContext)
    var expectedContext = ComposeView.ContentUpdateContext(
      contentNode: initialContext.contentNode,
      contentEvaluation: initialContext.contentEvaluation,
      updateType: .boundsChange,
      previousRenderBounds: nil,
      bounds: CGRect(x: 0, y: 0, width: 120, height: 80),
      preparedAnimationDecision: .all
    )
    expect(invokedContentUpdateContext) == expectedContext

    // then: lastRenderBounds is the visible area, which the scrollers take space from on AppKit
    expect(view.test.lastRenderBounds) == CGRect(origin: .zero, size: visibleSize)

    // reset
    invokedContentUpdateContext = nil

    // when: layout again without changing the bounds
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: should not update as no bounds change
    expect(updateCount) == 1
    expect(invokedContentUpdateContext) == nil
    expect(view.test.lastRenderBounds) == CGRect(origin: .zero, size: visibleSize)

    // when: adjust scroll position and layout again
    view.contentOffset = CGPoint(x: 0, y: 10)
    view.layoutIfNeeded()

    // then: should update
    expect(updateCount) == 2

    // then: expect the contentUpdateContext is set with correct render bounds
    expectedContext = ComposeView.ContentUpdateContext(
      contentNode: initialContext.contentNode,
      contentEvaluation: initialContext.contentEvaluation,
      updateType: .boundsChange,
      previousRenderBounds: CGRect(origin: .zero, size: visibleSize),
      bounds: CGRect(x: 0, y: 10, width: 120, height: 80),
      preparedAnimationDecision: .all
    )
    expect(invokedContentUpdateContext) == expectedContext

    expect(view.test.lastRenderBounds) == CGRect(origin: CGPoint(x: 0, y: 10), size: visibleSize)
  }

  func test_renderBounds_scroll_rendersOnceAtTheNextLayout() {
    // given: a laid out 100 × 100 view showing content taller than it, with a hook counting render passes
    let view = ComposeView {
      LayerNode()
        .frame(width: .flexible, height: 400)
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.layoutIfNeeded()

    var renderCount = 0
    view.debug(eventHandler: { _, event in
      switch event {
      case .renderWillBegin:
        renderCount += 1
      default:
        break
      }
    })

    // when: the view scrolls
    view.contentOffset = CGPoint(x: 0, y: 50)

    // then: it doesn't render until the next layout pass, on every platform
    expect(renderCount) == 0
    expect(view.test.lastRenderBounds?.origin) == .zero

    // when: the view lays out
    view.layoutIfNeeded()

    // then: it renders the scrolled bounds
    expect(renderCount) == 1
    expect(view.test.lastRenderBounds?.origin) == CGPoint(x: 0, y: 50)

    // when: the view scrolls three times
    view.contentOffset = CGPoint(x: 0, y: 100)
    view.contentOffset = CGPoint(x: 0, y: 150)
    view.contentOffset = CGPoint(x: 0, y: 200)

    // then: it still doesn't render
    expect(renderCount) == 1

    // when: the view lays out
    view.layoutIfNeeded()

    // then: it renders once, for the last offset
    expect(renderCount) == 2
    expect(view.test.lastRenderBounds?.origin) == CGPoint(x: 0, y: 200)
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

    view.contentOffset = CGPoint(x: 0, y: 200)
    view.layoutIfNeeded()
    expect(view.hasHorizontalScroller) == true
    expect(view.contentOffset) == CGPoint(x: 0, y: 200)

    // when: a refresh shortens the rows, so the clip view clamps the offset while the horizontal scroller shows, and
    // narrows them to fit beside the vertical scroller, which hides the horizontal scroller and clamps the offset again
    let thickness = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    contentSize = CGSize(width: 100 - thickness, height: 250)
    view.refresh(animated: false)

    // then: the pass renders the rows at the offset the view ends up with, beside the vertical scroller
    expect(view.hasHorizontalScroller) == false
    expect(view.contentOffset) == CGPoint(x: 0, y: 150)
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 150, width: 100 - thickness, height: 100)
    expect(renderedFrames(in: view)) == (15 ..< 25).map { CGRect(x: 0, y: CGFloat($0) * 10, width: 100 - thickness, height: 10) }
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

    view.contentOffset = CGPoint(x: 200, y: 0)
    view.layoutIfNeeded()
    expect(view.hasVerticalScroller) == true
    expect(view.contentOffset) == CGPoint(x: 200, y: 0)

    // when: a refresh narrows the columns, so the clip view clamps the offset while the vertical scroller shows, and
    // shortens them to fit beside the horizontal scroller, which hides the vertical scroller and clamps the offset again
    let thickness = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    contentSize = CGSize(width: 250, height: 100 - thickness)
    view.refresh(animated: false)

    // then: the pass renders the columns at the offset the view ends up with, beside the horizontal scroller
    expect(view.hasVerticalScroller) == false
    expect(view.contentOffset) == CGPoint(x: 150, y: 0)
    expect(view.test.lastRenderBounds) == CGRect(x: 150, y: 0, width: 100, height: 100 - thickness)
    expect(renderedFrames(in: view)) == (15 ..< 25).map { CGRect(x: CGFloat($0) * 10, y: 0, width: 10, height: 100 - thickness) }
  }

  func test_renderBounds_showingLegacyScroller_scrolledToBottom() {
    // given: a view with legacy scrollers, scrolled to the bottom of rows that overflow only vertically, fitting beside
    // the vertical scroller
    let thickness = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    var contentSize = CGSize(width: 100 - thickness, height: 300)
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

    view.contentOffset = CGPoint(x: 0, y: 200)
    view.layoutIfNeeded()
    expect(view.hasHorizontalScroller) == false
    expect(view.contentOffset) == CGPoint(x: 0, y: 200)

    // when: a refresh shortens the rows, so the clip view clamps the offset, and widens them, which shows the
    // horizontal scroller and shrinks the clip view
    contentSize = CGSize(width: 200, height: 250)
    view.refresh(animated: false)

    // then: the pass renders the rows at the offset the view ends up with, the new end beside both scrollers
    expect(view.hasHorizontalScroller) == true
    expect(view.contentOffset) == CGPoint(x: 0, y: 150 + thickness)
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 150 + thickness, width: 100 - thickness, height: 100 - thickness)
    expect(renderedFrames(in: view)) == (16 ..< 25).map { CGRect(x: 0, y: CGFloat($0) * 10, width: 200, height: 10) }
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
    view.contentOffset = CGPoint(x: 0, y: maxOffsetY)
    view.layoutIfNeeded()

    // then: the view stays at the end, rendered once for the visible area beside the scrollers, with the rows that fill
    // the viewport
    let thickness = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    expect(view.contentOffset) == CGPoint(x: 0, y: maxOffsetY)
    expect(renderBounds) == [CGRect(x: 0, y: maxOffsetY, width: 100 - thickness, height: 100 - thickness)]
    expect(renderedFrames(in: view)) == (21 ..< 30).map { CGRect(x: 0, y: CGFloat($0) * 10, width: 200, height: 10) }
  }

  func test_renderBounds_legacyScrollers_scrolledSideways_keepsTheOffset() {
    // given: a view with legacy scrollers, showing rows as wide as the view that overflow vertically. they don't fit
    // beside the vertical scroller, so the horizontal scroller shows too, with a scroller thickness of the rows to scroll
    // to sideways
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
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == true

    var renderBounds: [CGRect] = []
    view.onDidRender { _, context in
      renderBounds.append(context.renderBounds)
    }

    // when: scroll sideways within that thickness
    view.contentOffset = CGPoint(x: 10, y: 50)
    view.layoutIfNeeded()

    // then: the view stays where it's scrolled to, rendered once for the visible area beside the scrollers
    let thickness = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    expect(view.contentOffset) == CGPoint(x: 10, y: 50)
    expect(renderBounds) == [CGRect(x: 10, y: 50, width: 100 - thickness, height: 100 - thickness)]
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
    view.contentOffset = CGPoint(x: 0, y: 200)
    view.layoutIfNeeded()
    expect(view.contentOffset) == CGPoint(x: 0, y: 200)

    var renderBounds: [CGRect] = []
    view.onDidRender { _, context in
      renderBounds.append(context.renderBounds)
    }

    // when: a refresh shortens the rows while the scrollers stay shown, so the content size clamps the offset to the
    // new end
    rowCount = 25
    view.refresh(animated: false)

    // then: the view renders once, at the new end, for the visible area beside the scrollers
    let thickness = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == true
    expect(view.contentOffset) == CGPoint(x: 0, y: view.maxOffsetY)
    expect(renderBounds) == [CGRect(x: 0, y: view.maxOffsetY, width: 100 - thickness, height: 100 - thickness)]
  }

  func test_renderBounds_legacyScrollers_sizeFollowsTheVisibleSize() {
    // given: a 120 × 80 view with content insets, showing both legacy scrollers
    let view = ComposeView {
      LayerNode().frame(width: 300, height: 300)
    }
    view.frame = CGRect(x: 0, y: 0, width: 120, height: 80)
    useLegacyScrollers(view)
    view.contentInsets = NSEdgeInsets(top: 10, left: 5, bottom: 7, right: 3)

    // when: the view refreshes, and lays out, which renders the visible size that AppKit's tiling of the scrollers leaves
    view.refresh(animated: false)
    view.layoutIfNeeded()

    // then: the scrollers show over the clip view with the insets, so the content lays out for the whole frame
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == true
    expect(view.contentView.frame.size) == CGSize(width: 120, height: 80)
    expect(view.test.lastRenderBounds?.size) == CGSize(width: 120, height: 80)

    // when: the insets are removed, so the scrollers take space from the clip view, and the view refreshes
    view.contentInsets = NSEdgeInsetsZero
    view.refresh(animated: false)

    // then: the content lays out for the visible size beside the scrollers
    let thickness = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    expect(view.contentView.frame.size) == CGSize(width: 120 - thickness, height: 80 - thickness)
    expect(view.test.lastRenderBounds?.size) == CGSize(width: 120 - thickness, height: 80 - thickness)
    expect(view.visibleSize) == CGSize(width: 120 - thickness, height: 80 - thickness)
  }

  func test_renderBounds_scaledBounds_rendersTheScaledViewport() {
    // given: a 200 × 100 view with legacy scrollers, showing 10 pt rows as wide as the viewport
    let view = ComposeView {
      VStack {
        for _ in 0 ..< 40 {
          LayerNode().frame(width: .flexible, height: 10)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    useLegacyScrollers(view)
    view.refresh(animated: false)

    // when: the view's bounds scale to 400 × 200, which doubles its viewport
    view.setBoundsSize(CGSize(width: 400, height: 200))
    view.layoutIfNeeded()

    // then: the content lays out and renders for the scaled viewport beside the vertical scroller, 20 rows
    let thickness = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 400 - thickness, height: 200)
    expect(renderedFrames(in: view)) == (0 ..< 20).map { CGRect(x: 0, y: CGFloat($0) * 10, width: 400 - thickness, height: 10) }
  }

  func test_renderBounds_legacyScrollerMovedInByTheRightContentInset_rendersTheVisibleWidth() throws {
    // given: a 240 × 180 view with a 30 pt right content inset and legacy scrollers, showing flexible rows that overflow
    // vertically, so AppKit shrinks the clip view by the vertical scroller and moves the scroller inside it by the inset
    var rowWidth: CGFloat = 0
    let view = ComposeView {
      VStack {
        for _ in 0 ..< 30 {
          if rowWidth > 0 {
            LayerNode().frame(width: rowWidth, height: 10)
          } else {
            LayerNode().frame(width: .flexible, height: 10)
          }
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 240, height: 180)
    view.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 30)
    useLegacyScrollers(view)

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the rows lay out for the visible width beside the vertical scroller, and only the vertical scroller shows
    let thickness = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    let verticalScroller = try view.verticalScroller.unwrap()
    expect(view.contentView.frame.width) == 240 - thickness
    expect(verticalScroller.frame.maxX) < view.contentView.frame.maxX
    expect(view.hasVerticalScroller) == true
    expect(view.hasHorizontalScroller) == false
    expect(renderedFrames(in: view)) == (0 ..< 18).map { CGRect(x: 0, y: CGFloat($0) * 10, width: 240 - thickness, height: 10) }

    // when: the rows become 230 pt wide, which fits the view width but not the visible width beside the vertical scroller
    rowWidth = 230
    view.refresh(animated: false)

    // then: the rows overflow beside the vertical scroller, so the horizontal scroller shows too, and the rows lay out for
    // the visible height above it
    expect(view.hasHorizontalScroller) == true
    expect(renderedFrames(in: view)) == (0 ..< 17).map { CGRect(x: 0, y: CGFloat($0) * 10, width: 230, height: 10) }
  }

  func test_renderBounds_legacyScrollerMovedInByTheBottomContentInset_centersInTheVisibleHeight() throws {
    // given: a 240 × 180 view with a 30 pt bottom content inset and legacy scrollers, showing five 400 pt wide rows that
    // overflow horizontally, so AppKit shrinks the clip view by the horizontal scroller and moves the scroller inside it
    // by the inset
    let view = ComposeView {
      VStack {
        for _ in 0 ..< 5 {
          LayerNode().frame(width: 400, height: 10)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 240, height: 180)
    view.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
    useLegacyScrollers(view)

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the rows center in the visible height above the horizontal scroller, and only the horizontal scroller shows
    let thickness = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    let horizontalScroller = try view.horizontalScroller.unwrap()
    expect(view.contentView.frame.height) == 180 - thickness
    expect(horizontalScroller.frame.maxY) < view.contentView.frame.maxY
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == false
    let top = (180 - thickness - 50) / 2
    let scale = view.contentScaleFactor
    expect(renderedFrames(in: view)) == (0 ..< 5).map { CGRect(x: 0, y: ((top + CGFloat($0) * 10) * scale).rounded() / scale, width: 400, height: 10) }
  }

  func test_renderBounds_fractionalViewSize_clipViewRoundsDown_staysExact() {
    // given: a 99.2 × 99.2 view in a window, with overlay scrollers, showing flexible rows that overflow vertically
    let window = TestWindow()
    let view = ComposeView {
      VStack {
        for _ in 0 ..< 40 {
          LayerNode().frame(width: .flexible, height: 10)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 99.2, height: 99.2)
    view.scrollIndicatorBehavior = .auto
    view.scrollerStyle = .overlay
    window.contentView().addSubview(view)

    // when: the view refreshes, and its scroll elasticity updates
    view.refresh(animated: false)
    view.invalidateScrollElasticity()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    // then: the rows lay out for the exact size, while AppKit rounds the clip view down to whole pixels, at both 1x and
    // 2x
    expect(view.visibleSize) == CGSize(width: 99.2, height: 99.2)
    expect(view.test.lastRenderBounds?.size) == CGSize(width: 99.2, height: 99.2)
    expect(view.contentView.frame.size) == CGSize(width: 99, height: 99)

    // then: the document keeps the exact width, which fits the exact visible size even though it's wider than the clip
    // view, so the maximum horizontal offset is 0, the view doesn't bounce sideways, and only the vertical scroller shows
    expect(view.contentSize) == CGSize(width: 99.2, height: 400)
    expect(view.maxOffsetX) == 0
    expect(view.canScrollToRight) == false
    expect(view.horizontalScrollElasticity) == .none
    expect(view.verticalScrollElasticity) == .allowed
    expect(view.hasVerticalScroller) == true
    expect(view.hasHorizontalScroller) == false
  }

  func test_renderBounds_fractionalViewSize_clipViewRoundsUp_staysExact() {
    // given: a 99.8 × 99.8 view at (0.4, 0.4) in a window, with legacy scrollers, showing 99.7 × 99.7 content
    let window = TestWindow()
    let view = ComposeView {
      LayerNode().frame(width: 99.7, height: 99.7)
    }
    view.frame = CGRect(x: 0.4, y: 0.4, width: 99.8, height: 99.8)
    useLegacyScrollers(view)
    window.contentView().addSubview(view)

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the content lays out for the exact size, which it fits, while AppKit rounds the clip view up to whole pixels,
    // and the document keeps the exact size, so the view neither scrolls nor shows scrollers
    expect(view.visibleSize) == CGSize(width: 99.8, height: 99.8)
    expect(view.test.lastRenderBounds?.size) == CGSize(width: 99.8, height: 99.8)
    expectSize(view.contentView.frame.size, approximatelyEquals: CGSize(width: 100, height: 100))
    expect(view.contentSize) == CGSize(width: 99.8, height: 99.8)
    expect(view.isScrollEnabled) == false
    expect(view.hasVerticalScroller) == false
    expect(view.hasHorizontalScroller) == false
  }

  func test_renderBounds_scaledBounds_fractionalViewSize_fittingContentDoesNotScroll() {
    for (frameLength, contentLength) in [(CGFloat(99.2), CGFloat(148.6)), (99.8, 149.6)] {
      // given: a view in a window with a fractional frame and bounds 1.5 times as large, so AppKit rounds the clip view
      // to whole pixels through the scaling, at both 1x and 2x: down to 148.5 units for a 99.2 pt frame, and up to 150
      // for a 99.8 pt one, showing content that fits the exact bounds, even where it's larger than the rounded clip view
      let window = TestWindow()
      let view = ComposeView {
        LayerNode().frame(width: contentLength, height: contentLength)
      }
      view.frame = CGRect(x: 0, y: 0, width: frameLength, height: frameLength)
      window.contentView().addSubview(view)
      view.setBoundsSize(CGSize(width: frameLength * 1.5, height: frameLength * 1.5))

      // when: the view lays out, which tiles the clip view for the scaled bounds before rendering
      view.layoutIfNeeded()

      // then: the content lays out for the exact bounds, and the document keeps the exact size, so the view doesn't
      // scroll
      let boundsLength = frameLength * 1.5
      expectSize(view.test.lastRenderBounds?.size, approximatelyEquals: CGSize(width: boundsLength, height: boundsLength))
      expectSize(view.contentSize, approximatelyEquals: CGSize(width: boundsLength, height: boundsLength))
      expect(view.isScrollEnabled) == false
      expect(view.maxOffsetX).to(beApproximatelyEqual(to: 0, within: 1e-9))
      expect(view.maxOffsetY).to(beApproximatelyEqual(to: 0, within: 1e-9))
    }
  }

  func test_renderBounds_rotatedView_laysOutForItsOwnSize() {
    // given: a 200 × 100 view nested in another compose view in a window, rotated 30°, showing twenty 10 pt wide columns
    // as tall as the view
    let window = TestWindow()
    let parent = ComposeView {
      LayerNode().frame(width: 10, height: 10)
    }
    parent.frame = CGRect(x: 0, y: 0, width: 500, height: 500)
    window.contentView().addSubview(parent)
    let view = ComposeView {
      HStack {
        for _ in 0 ..< 20 {
          LayerNode().frame(width: 10, height: 100)
        }
      }
    }
    view.frame = CGRect(x: 150, y: 150, width: 200, height: 100)
    parent.contentContainerView.addSubview(view)
    view.frameRotation = 30

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the content lays out for the view's own size, which rotation doesn't change, so all twenty columns render
    // side by side
    expectSize(view.test.lastRenderBounds?.size, approximatelyEquals: CGSize(width: 200, height: 100))
    expect(renderedFrames(in: view)) == (0 ..< 20).map { CGRect(x: CGFloat($0) * 10, y: 0, width: 10, height: 100) }
  }

  func test_renderBounds_rotatedView_contentFittingTheView_doesNotScroll() {
    // given: a 200 × 100 view with legacy scrollers nested in another compose view in a window, rotated 30°, showing
    // content as large as the view, which the rotation's backing conversions make differ from the render bounds by
    // floating-point noise
    let window = TestWindow()
    let parent = ComposeView {
      LayerNode().frame(width: 10, height: 10)
    }
    parent.frame = CGRect(x: 0, y: 0, width: 500, height: 500)
    window.contentView().addSubview(parent)
    let view = ComposeView {
      LayerNode().frame(width: 200, height: 100)
    }
    view.frame = CGRect(x: 150, y: 150, width: 200, height: 100)
    useLegacyScrollers(view)
    parent.contentContainerView.addSubview(view)
    view.frameRotation = 30

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the content fits, so the view neither scrolls nor shows scrollers, and its document is the view's size
    expect(view.isScrollEnabled) == false
    expect(view.hasHorizontalScroller) == false
    expect(view.hasVerticalScroller) == false
    expectSize(view.contentSize, approximatelyEquals: CGSize(width: 200, height: 100))
  }

  func test_renderBounds_legacyScrollers_growingNearTheEnd_rendersOnceForTheNewSize() {
    // given: a view with legacy scrollers, scrolled near the end of rows that overflow both axes
    let view = ComposeView {
      VStack {
        for _ in 0 ..< 40 {
          LayerNode().frame(width: 200, height: 10)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    useLegacyScrollers(view)
    view.refresh(animated: false)
    view.contentOffset = CGPoint(x: 0, y: 290)
    view.layoutIfNeeded()
    expect(view.contentOffset) == CGPoint(x: 0, y: 290)

    var renderBounds: [CGRect] = []
    view.onDidRender { _, context in
      renderBounds.append(context.renderBounds)
    }

    // when: the view grows, so AppKit's tiling clamps the offset to the new end, which posts a bounds change after it
    // places the clip view and before it places the scrollers
    view.frame.size = CGSize(width: 140, height: 140)
    view.layoutIfNeeded()

    // then: the view renders once, after the tiling, for the visible area of the new size at the clamped offset
    let thickness = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    expect(view.contentOffset) == CGPoint(x: 0, y: view.maxOffsetY)
    expect(renderBounds) == [CGRect(x: 0, y: view.maxOffsetY, width: 140 - thickness, height: 140 - thickness)]
  }

  /// Makes the view show legacy scrollers for the axes its content overflows, so a shown scroller shrinks the clip view.
  private func useLegacyScrollers(_ view: ComposeView) {
    view.scrollIndicatorBehavior = .auto
    view.scrollerStyle = .legacy
  }

  /// The frames of the rendered layers, ordered from top to bottom, then from left to right.
  private func renderedFrames(in view: ComposeView) -> [CGRect] {
    let frames = view.contentContainerView.layer?.sublayers?.map(\.frame) ?? []
    return frames.sorted { ($0.minY, $0.minX) < ($1.minY, $1.minX) }
  }

  /// Expects the size to equal the expected size within the floating-point noise that AppKit's coordinate conversions add
  /// at fractional positions and scaled bounds.
  private func expectSize(_ size: CGSize?, approximatelyEquals expected: CGSize, file: StaticString = #filePath, line: UInt = #line) {
    guard let size else {
      fail("expected a size", file: file, line: line)
      return
    }
    expect(size.width, file: file, line: line).to(beApproximatelyEqual(to: expected.width, within: 1e-9))
    expect(size.height, file: file, line: line).to(beApproximatelyEqual(to: expected.height, within: 1e-9))
  }
  #endif
}
