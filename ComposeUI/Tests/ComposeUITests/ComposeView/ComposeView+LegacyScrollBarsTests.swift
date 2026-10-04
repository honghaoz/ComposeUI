//
//  ComposeView+LegacyScrollBarsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/1/26.
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

import ChouTiTest

@testable import ComposeUI

class ComposeView_LegacyScrollBarsTests: XCTestCase {

  private let thickness = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)

  // MARK: - Layout

  func test_verticalScrollBar_contentLaysOutBesideIt() {
    // given: a 120 × 200 view with legacy scroll bars, showing content as wide as the view and 300 pt tall
    let state = WidthDependentNode.State()
    let view = makeView { WidthDependentNode(state: state, height: { _ in 300 }) }

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the vertical scroll bar shows, and the content lays out beside it, so it doesn't scroll sideways
    expect(view.hasVerticalScroller) == true
    expect(view.hasHorizontalScroller) == false
    expect(view.visibleSize) == CGSize(width: 120 - thickness, height: 200)
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120 - thickness, height: 200)
    expect(view.contentSize) == CGSize(width: 120 - thickness, height: 300)
    expect(view.maxOffsetX) == 0
  }

  func test_horizontalScrollBar_contentLaysOutBesideIt() {
    // given: a 120 × 200 view with legacy scroll bars, showing content 300 pt wide and as tall as the view
    let view = makeView { LayerNode().frame(width: 300, height: .flexible) }

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the horizontal scroll bar shows, and the content lays out above it, so it doesn't scroll vertically
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == false
    expect(view.visibleSize) == CGSize(width: 120, height: 200 - thickness)
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120, height: 200 - thickness)
    expect(view.contentSize) == CGSize(width: 300, height: 200 - thickness)
    expect(view.maxOffsetY) == 0
  }

  func test_bothScrollBars_contentLaysOutBesideThem() {
    // given: a 120 × 200 view with legacy scroll bars, showing content 300 pt wide and tall
    let view = makeView { LayerNode().frame(width: 300, height: 300) }

    // when: the view refreshes
    view.refresh(animated: false)

    // then: both scroll bars show, and the content lays out for the space they leave
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == true
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120 - thickness, height: 200 - thickness)
    expect(view.contentSize) == CGSize(width: 300, height: 300)
  }

  func test_contentFitsTheBoundsButNotBesideTheVerticalScrollBar_showsTheHorizontalScrollBar() {
    // given: a 120 × 200 view with legacy scroll bars, showing content 300 pt tall and 115 pt wide, which fits the view's
    // width but not the width beside a vertical scroll bar
    var containerSizes: [CGSize] = []
    let view = makeView { LayerNode().frame(width: 115, height: 300) }
    view.onWillLayout { _, context in
      containerSizes.append(context.containerSize)
    }

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the vertical scroll bar makes the content overflow sideways, so the horizontal scroll bar shows too, and the
    // content lays out once more for the space both leave
    expect(view.hasVerticalScroller) == true
    expect(view.hasHorizontalScroller) == true
    expect(containerSizes) == [
      CGSize(width: 120, height: 200),
      CGSize(width: 120 - thickness, height: 200),
      CGSize(width: 120 - thickness, height: 200 - thickness),
    ]
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120 - thickness, height: 200 - thickness)
  }

  func test_contentFitsBetweenTheInsetsButNotBesideTheVerticalScrollBar_showsTheHorizontalScrollBar() {
    // given: a 120 × 200 view with legacy scroll bars and a 10 pt right inset, showing content 300 pt tall and 100 pt wide,
    // which fits the 110 pt between the insets, but not the space between them beside a vertical scroll bar
    let view = makeView { LayerNode().frame(width: 100, height: 300) }
    view.contentInset = EdgeInsets(top: 0, left: 0, bottom: 0, right: 10)

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the vertical scroll bar makes the content overflow sideways between the insets, so the horizontal scroll bar
    // shows too, for the overflow
    expect(view.hasVerticalScroller) == true
    expect(view.hasHorizontalScroller) == true
    expect(view.maxOffsetX) == 100 + 10 - (120 - thickness)
  }

  func test_scrollBarsOverTheContent_contentLaysOutBesideThemAndScrollsToTheirEdge() {
    // given: a 120 × 200 view with legacy scroll bars and a 20 pt top inset, showing content 300 pt wide and tall, and
    // records the container sizes the content lays out in
    var containerSizes: [CGSize] = []
    let view = makeView { LayerNode().frame(width: 300, height: 300) }
    view.contentInset = EdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
    view.onWillLayout { _, context in
      containerSizes.append(context.containerSize)
    }

    // when: the view refreshes
    view.refresh(animated: false)

    // then: both scroll bars show over the full visible area, and the content lays out beside them, between the insets.
    // the will-layout handler runs for the view's size, for the visible area beside the scroll bars, and for the full one
    // AppKit renders. the scrollable range ends where AppKit stops scrolling
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == true
    expect(view.visibleSize) == CGSize(width: 120, height: 200)
    expect(containerSizes) == [
      CGSize(width: 120, height: 180),
      CGSize(width: 120 - thickness, height: 180 - thickness),
      CGSize(width: 120 - thickness, height: 180 - thickness),
    ]
    expect(view.maxOffsetX) == 300 - 120 + thickness
    expect(view.maxOffsetY) == 300 - 200 + thickness
    let clipView = view.contentView
    let end = clipView.constrainBoundsRect(CGRect(origin: CGPoint(x: 1000, y: 1000), size: clipView.bounds.size)).origin
    expect(end) == CGPoint(x: view.maxOffsetX, y: view.maxOffsetY)

    // when: the view scrolls to where the content's edges reach the visible area's edges, under the scroll bars
    view.contentOffset = CGPoint(x: 300 - 120, y: 300 - 200)

    // then: the view can still scroll by the scroll bars' thickness along both axes
    expect(view.canScrollToRight) == true
    expect(view.canScrollToBottom) == true

    // when: the view scrolls to the end of the scrollable range
    view.contentOffset = end

    // then: the view can't scroll further along either axis
    expect(view.canScrollToRight) == false
    expect(view.canScrollToBottom) == false
  }

  func test_scrollBarsOverTheContent_contentFittingBetweenTheInsets_hidesThem() {
    // given: a 120 × 200 view with legacy scroll bars and a 20 pt top inset, showing content 300 pt wide and tall, with
    // both scroll bars over it
    var contentSize = CGSize(width: 300, height: 300)
    let view = makeView { LayerNode().frame(width: contentSize.width, height: contentSize.height) }
    view.contentInset = EdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
    view.refresh(animated: false)
    expect(view.adjustedContentInset.right) == thickness

    // when: the content becomes 50 pt wide and 170 pt tall, which fits the 180 pt between the insets, but not that space
    // without the scroll bars' thickness, and the view refreshes
    contentSize = CGSize(width: 50, height: 170)
    view.refresh(animated: false)

    // then: both scroll bars hide, and the view doesn't scroll
    expect(view.hasHorizontalScroller) == false
    expect(view.hasVerticalScroller) == false
    expect(view.isScrollEnabled) == false
  }

  func test_scrollBarsOverTheContent_sizeThatFits_leavesOutTheirThickness() {
    // given: a 120 × 200 view with legacy scroll bars and a 20 pt top inset, showing content 300 pt wide and tall, with
    // both scroll bars over it
    let view = makeView { LayerNode().frame(width: 300, height: 300) }
    view.contentInset = EdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
    view.refresh(animated: false)
    expect(view.adjustedContentInset.right) == thickness

    // then: the size that fits is the content and the set insets, since a view of that size has no scroll bars
    expect(view.sizeThatFits(CGSize(width: 1000, height: 1000))) == CGSize(width: 300, height: 320)
  }

  func test_contentOverflowsTheBoundsButFitsBesideTheScrollBar_keepsTheScrollBar() {
    // given: a 120 × 200 view with legacy scroll bars, showing content as wide as the view and 1.75 times as tall, which
    // overflows the view's height but fits beside a vertical scroll bar
    let state = WidthDependentNode.State()
    var renderCount = 0
    let view = makeView { WidthDependentNode(state: state, height: { $0 * 1.75 }) }
    view.onDidRender { _, _ in
      renderCount += 1
    }

    // when: the view refreshes, and the run loop turns, where a follow-up render pass would run
    view.refresh(animated: false)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))

    // then: the vertical scroll bar shows from the layout for the view's size, and stays though the content fits beside
    // it, with nothing to scroll, so the view renders once
    expect(view.hasVerticalScroller) == true
    expect(state.layoutContainerSizes) == [CGSize(width: 120, height: 200), CGSize(width: 120 - thickness, height: 200)]
    expect(renderCount) == 1
    expect(view.isScrollEnabled) == false
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120 - thickness, height: 200)
  }

  func test_overlayScrollBars_layOutOnce() {
    // given: a 120 × 200 view with overlay scroll bars, showing content as wide as the view and 300 pt tall
    let state = WidthDependentNode.State()
    let view = makeView(scrollerStyle: .overlay) { WidthDependentNode(state: state, height: { _ in 300 }) }

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the vertical scroll bar shows over the content, which lays out once, for the view's size
    expect(view.hasVerticalScroller) == true
    expect(state.layoutContainerSizes) == [CGSize(width: 120, height: 200)]
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120, height: 200)
  }

  func test_smallScrollBars_contentFittingBesideThem_showsOnlyTheVerticalScrollBar() {
    // given: a 120 × 200 view with small legacy scroll bars, showing content 300 pt tall and 105 pt wide, which fits the
    // width beside a small vertical scroll bar, but not the width beside a regular one
    let smallThickness = NSScroller.scrollerWidth(for: .small, scrollerStyle: .legacy)
    expect(120 - smallThickness) >= 105
    expect(120 - thickness) < 105
    let view = makeView { LayerNode().frame(width: 105, height: 300) }
    view.verticalScroller?.controlSize = .small
    view.horizontalScroller?.controlSize = .small

    // when: the view refreshes
    view.refresh(animated: false)

    // then: only the vertical scroll bar shows, and the content renders beside it
    expect(view.hasVerticalScroller) == true
    expect(view.hasHorizontalScroller) == false
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120 - smallThickness, height: 200)
  }

  func test_scrollersOfAThinnerClass_contentFittingBesideThem_showsOnlyTheVerticalScrollBar() {
    // given: a 120 × 200 view with legacy scroll bars, whose scrollers are of a class that makes them 10 pt thick, showing
    // content 300 pt tall and 105 pt wide, which fits the width beside a 10 pt vertical scroll bar, but not the width
    // beside a regular one
    expect(120 - thickness) < 105
    let view = makeView { LayerNode().frame(width: 105, height: 300) }
    view.verticalScroller = ThinScroller()
    view.horizontalScroller = ThinScroller()

    // when: the view refreshes
    view.refresh(animated: false)

    // then: only the vertical scroll bar shows, and the content renders beside it
    expect(view.hasVerticalScroller) == true
    expect(view.hasHorizontalScroller) == false
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120 - ThinScroller.thickness, height: 200)
  }

  func test_removedScrollers_countTheRegularScrollBarsAppKitCreates() {
    // given: a 120 × 200 view with legacy scroll bars, whose scrollers were removed, showing content 300 pt tall and 105 pt
    // wide, which doesn't fit the width beside a regular vertical scroll bar
    var contentSize = CGSize(width: 105, height: 300)
    let view = makeView { LayerNode().frame(width: contentSize.width, height: contentSize.height) }
    view.verticalScroller = nil
    view.horizontalScroller = nil

    // when: the view refreshes
    view.refresh(animated: false)

    // then: AppKit creates a regular vertical scroll bar, the content overflows beside it, and the horizontal scroll bar
    // shows too
    expect(view.verticalScroller?.controlSize) == .regular
    expect(view.hasVerticalScroller) == true
    expect(view.hasHorizontalScroller) == true
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120 - thickness, height: 200 - thickness)

    // when: the scrollers are removed again while both scroll bars show, the content becomes 300 pt wide and 185 pt tall,
    // which doesn't fit the height above a regular horizontal scroll bar, and the view refreshes
    view.verticalScroller = nil
    view.horizontalScroller = nil
    contentSize = CGSize(width: 300, height: 185)
    view.refresh(animated: false)

    // then: AppKit keeps a regular scroll bar's space for the horizontal scroll bar without a scroller, so the vertical
    // scroll bar shows too
    expect(view.horizontalScroller) == nil
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == true
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120 - thickness, height: 200 - thickness)
  }

  // MARK: - Scrolling and Resizing

  func test_scrolling_keepsTheScrollBars() {
    // given: a 120 × 200 view with legacy scroll bars, showing content as wide as the view and 300 pt tall
    let state = WidthDependentNode.State()
    var containerSizes: [CGSize] = []
    let view = makeView { WidthDependentNode(state: state, height: { _ in 300 }) }
    view.onWillLayout { _, context in
      containerSizes.append(context.containerSize)
    }

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the content lays out for the view's size, which decides the scroll bars, then for the render size beside the
    // vertical scroll bar, and the will-layout handler runs before each layout
    let renderSize = CGSize(width: 120 - thickness, height: 200)
    expect(state.layoutContainerSizes) == [CGSize(width: 120, height: 200), renderSize]
    expect(containerSizes) == [CGSize(width: 120, height: 200), renderSize]

    // when: the view scrolls
    view.contentOffset = CGPoint(x: 0, y: 50)
    view.layoutIfNeeded()

    // then: the pass keeps the scroll bars and lays out for the render size, which the cached layout already has, without
    // laying out for the view's size again
    expect(view.test.lastRenderBounds) == CGRect(origin: CGPoint(x: 0, y: 50), size: renderSize)
    expect(state.layoutContainerSizes) == [CGSize(width: 120, height: 200), renderSize]
    expect(containerSizes) == [CGSize(width: 120, height: 200), renderSize, renderSize]
  }

  func test_scrollBarsOverTheContent_scrolling_keepsThem() {
    // given: a 120 × 200 view with legacy scroll bars and a 20 pt top inset, that rendered content 300 pt wide and tall,
    // with both scroll bars over it, and records the container sizes the content lays out in
    var containerSizes: [CGSize] = []
    let view = makeView { LayerNode().frame(width: 300, height: 300) }
    view.contentInset = EdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
    view.refresh(animated: false)
    view.onWillLayout { _, context in
      containerSizes.append(context.containerSize)
    }

    // when: the view scrolls
    view.contentOffset = CGPoint(x: 50, y: 50)
    view.layoutIfNeeded()

    // then: the view keeps the scroll bars, and the content lays out once, beside them
    expect(view.test.lastRenderBounds) == CGRect(x: 50, y: 50, width: 120, height: 200)
    expect(containerSizes) == [CGSize(width: 120 - thickness, height: 180 - thickness)]
  }

  func test_scrollBarsOverTheContent_resizing_reportsTheRenderedViewportLast() {
    // given: a 120 × 200 view with legacy scroll bars and a 20 pt top inset, that rendered content 300 pt wide and tall,
    // with both scroll bars over it, and records the bounds each layout reports
    var layoutBounds: [CGRect] = []
    let view = makeView { LayerNode().frame(width: 300, height: 300) }
    view.contentInset = EdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
    view.refresh(animated: false)
    expect(view.visibleSize) == CGSize(width: 120, height: 200)
    view.onWillLayout { _, context in
      switch context.renderType {
      case .refresh:
        break
      case .boundsChange(_, let bounds):
        layoutBounds.append(bounds)
      }
    }

    // when: the view widens by a point
    view.frame.size = CGSize(width: 121, height: 200)
    view.layoutIfNeeded()

    // then: after the visible area beside the scroll bars, the last layout reports the full one AppKit renders, though
    // the content lays out for the same size in both
    expect(layoutBounds) == [
      CGRect(x: 0, y: -20, width: 121, height: 200),
      CGRect(x: 0, y: -20, width: 121 - thickness, height: 200 - thickness),
      CGRect(x: 0, y: -20, width: 121, height: 200),
    ]
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: -20, width: 121, height: 200)
  }

  func test_scrollBarsOverTheContent_willLayoutHandlerChangingTheInsets_keepsTheInsetsInEffectForThePass() {
    // given: a 120 × 200 view with legacy scroll bars and a 20 pt top inset, that rendered content 300 pt wide and tall,
    // with both scroll bars over it, whose will-layout handler records the container sizes and sets a 30 pt top inset the
    // first time it runs
    var containerSizes: [CGSize] = []
    let view = makeView { LayerNode().frame(width: 300, height: 300) }
    view.contentInset = EdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
    view.refresh(animated: false)
    var didSetInsets = false
    view.onWillLayout { view, context in
      containerSizes.append(context.containerSize)
      guard !didSetInsets else {
        return
      }
      didSetInsets = true
      view.contentInset = EdgeInsets(top: 30, left: 0, bottom: 0, right: 0)
    }

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the pass lays the content out between the insets in effect when it began, beside the scroll bars
    expect(containerSizes.last) == CGSize(width: 120 - thickness, height: 180 - thickness)

    // when: the run loop turns
    containerSizes = []
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))

    // then: the view renders again, between the new insets, beside the scroll bars
    expect(containerSizes.last) == CGSize(width: 120 - thickness, height: 170 - thickness)
  }

  func test_insetsTallerThanTheView_showTheVerticalScrollBarOnlyForContentThatOverflows() {
    // given: a 120 × 100 view with legacy scroll bars and 60 pt top and bottom insets, which AppKit scrolls with a 40 pt
    // bottom inset, leaving no space between them, showing content 50 pt wide and with no height
    var contentHeight: CGFloat = 0
    let view = makeView { LayerNode().frame(width: 50, height: contentHeight) }
    view.frame.size = CGSize(width: 120, height: 100)
    view.contentInset = EdgeInsets(top: 60, left: 0, bottom: 60, right: 0)

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the content fits the space AppKit leaves, so no scroll bar shows, and the view doesn't scroll
    expect(view.hasVerticalScroller) == false
    expect(view.hasHorizontalScroller) == false
    expect(view.isScrollEnabled) == false

    // when: the content becomes 10 pt tall, and the view refreshes
    contentHeight = 10
    view.refresh(animated: false)

    // then: the content overflows that space, so the vertical scroll bar shows, and the view scrolls
    expect(view.hasVerticalScroller) == true
    expect(view.hasHorizontalScroller) == false
    expect(view.isScrollEnabled) == true
  }

  func test_resizing_decidesTheScrollBarsAgain() {
    // given: a 120 × 200 view with legacy scroll bars that rendered content as wide as the view and 300 pt tall beside the
    // vertical scroll bar
    let view = makeView { WidthDependentNode(state: WidthDependentNode.State(), height: { _ in 300 }) }
    view.refresh(animated: false)
    expect(view.hasVerticalScroller) == true

    // when: the view grows taller than the content
    view.frame.size = CGSize(width: 120, height: 400)
    view.layoutIfNeeded()

    // then: the content fits, so the vertical scroll bar hides, and the content lays out for the whole view
    expect(view.hasVerticalScroller) == false
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120, height: 400)
  }

  func test_resizing_noWiderThanTheVerticalScrollBar_keepsTheWholeWidth() {
    // given: a 120 × 200 view with legacy scroll bars that rendered content as wide as the view and 300 pt tall beside the
    // vertical scroll bar, and records the bounds each layout reports
    var layoutBounds: [CGRect] = []
    let view = makeView { LayerNode().frame(width: .flexible, height: 300) }
    view.refresh(animated: false)
    view.onWillLayout { _, context in
      switch context.renderType {
      case .refresh:
        break
      case .boundsChange(_, let bounds):
        layoutBounds.append(bounds)
      }
    }

    // when: the view narrows to 10 pt, less than the vertical scroll bar's thickness
    view.frame.size = CGSize(width: 10, height: 200)
    view.layoutIfNeeded()

    // then: AppKit leaves a view no wider than the scroll bar whole, so the content lays out once, for the whole width,
    // and the horizontal scroll bar stays hidden
    expect(view.hasVerticalScroller) == true
    expect(view.hasHorizontalScroller) == false
    expect(layoutBounds) == [CGRect(x: 0, y: 0, width: 10, height: 200)]
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 10, height: 200)

    // when: the view widens to the scroll bar's thickness
    layoutBounds = []
    view.frame.size = CGSize(width: thickness, height: 200)
    view.layoutIfNeeded()

    // then: the view keeps its whole width
    expect(layoutBounds) == [CGRect(x: 0, y: 0, width: thickness, height: 200)]
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: thickness, height: 200)

    // when: the view widens by a point more
    layoutBounds = []
    view.frame.size = CGSize(width: thickness + 1, height: 200)
    view.layoutIfNeeded()

    // then: the scroll bar takes its thickness, leaving a point for the content
    expect(layoutBounds) == [CGRect(x: 0, y: 0, width: thickness + 1, height: 200), CGRect(x: 0, y: 0, width: 1, height: 200)]
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 1, height: 200)
  }

  func test_resizing_noTallerThanTheHorizontalScrollBar_keepsTheWholeHeight() {
    // given: a 120 × 200 view with legacy scroll bars that rendered content 300 pt wide and as tall as the view above the
    // horizontal scroll bar, and records the bounds each layout reports
    var layoutBounds: [CGRect] = []
    let view = makeView { LayerNode().frame(width: 300, height: .flexible) }
    view.refresh(animated: false)
    view.onWillLayout { _, context in
      switch context.renderType {
      case .refresh:
        break
      case .boundsChange(_, let bounds):
        layoutBounds.append(bounds)
      }
    }

    // when: the view shortens to 10 pt, less than the horizontal scroll bar's thickness
    view.frame.size = CGSize(width: 120, height: 10)
    view.layoutIfNeeded()

    // then: AppKit leaves a view no taller than the scroll bar whole, so the content lays out once, for the whole height,
    // and the vertical scroll bar stays hidden
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == false
    expect(layoutBounds) == [CGRect(x: 0, y: 0, width: 120, height: 10)]
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120, height: 10)

    // when: the view grows to the scroll bar's thickness
    layoutBounds = []
    view.frame.size = CGSize(width: 120, height: thickness)
    view.layoutIfNeeded()

    // then: the view keeps its whole height
    expect(layoutBounds) == [CGRect(x: 0, y: 0, width: 120, height: thickness)]
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120, height: thickness)

    // when: the view grows by a point more
    layoutBounds = []
    view.frame.size = CGSize(width: 120, height: thickness + 1)
    view.layoutIfNeeded()

    // then: the scroll bar takes its thickness, leaving a point for the content
    expect(layoutBounds) == [CGRect(x: 0, y: 0, width: 120, height: thickness + 1), CGRect(x: 0, y: 0, width: 120, height: 1)]
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120, height: 1)
  }

  // MARK: - Scroll Indicator Behavior

  func test_alwaysShownScrollBars_contentLaysOutBesideThemOnce() {
    // given: a 120 × 200 view that always shows legacy scroll bars, showing content as wide as the view and 300 pt tall
    let state = WidthDependentNode.State()
    let view = makeView { WidthDependentNode(state: state, height: { _ in 300 }) }
    view.scrollIndicatorBehavior = .always

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the content lays out once, beside both scroll bars
    expect(state.layoutContainerSizes) == [CGSize(width: 120 - thickness, height: 200 - thickness)]
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120 - thickness, height: 200 - thickness)
  }

  func test_manuallyShownScrollBar_contentLaysOutBesideItOnce() {
    // given: a 120 × 200 view that leaves its legacy scroll bars to the caller, which shows the vertical one, showing
    // content as wide as the view and 300 pt tall
    let state = WidthDependentNode.State()
    let view = makeView { WidthDependentNode(state: state, height: { _ in 300 }) }
    view.scrollIndicatorBehavior = .manual
    view.hasVerticalScroller = true

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the content lays out once, beside the vertical scroll bar
    expect(view.hasHorizontalScroller) == false
    expect(state.layoutContainerSizes) == [CGSize(width: 120 - thickness, height: 200)]
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120 - thickness, height: 200)
  }

  // MARK: - Scroller Style

  func test_scrollerStyleChange_rendersForTheNewVisibleSize() {
    // given: a 120 × 200 view in a window, with legacy scroll bars, that rendered content as wide as the view and 300 pt
    // tall, beside the vertical scroll bar, and the window laid out
    let window = TestWindow()
    let view = makeView { WidthDependentNode(state: WidthDependentNode.State(), height: { _ in 300 }) }
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120 - thickness, height: 200)

    // when: the scroll bars switch to overlay, as when a mouse is disconnected, and the window lays out
    view.scrollerStyle = .overlay
    window.layoutIfNeeded()

    // then: the content lays out for the whole view, which the scroll bars no longer take space from
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120, height: 200)
    expect(view.contentSize) == CGSize(width: 120, height: 300)

    // when: the scroll bars switch back to legacy, and the window lays out
    view.scrollerStyle = .legacy
    window.layoutIfNeeded()

    // then: the content lays out beside the vertical scroll bar again
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120 - thickness, height: 200)
    expect(view.contentSize) == CGSize(width: 120 - thickness, height: 300)
  }

  func test_scrollerStyleChangeToLegacy_decidesTheScrollBarsAgain() {
    // given: a 120 × 200 view in a window, with overlay scroll bars, that rendered content 300 pt tall and 115 pt wide,
    // which fits the view's width but not the width beside a legacy vertical scroll bar, and the window laid out
    let window = TestWindow()
    let view = makeView(scrollerStyle: .overlay) { LayerNode().frame(width: 115, height: 300) }
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    expect(view.hasVerticalScroller) == true
    expect(view.hasHorizontalScroller) == false

    // when: the scroll bars switch to legacy, as when a mouse is connected, and the window lays out
    view.scrollerStyle = .legacy
    window.layoutIfNeeded()

    // then: the vertical scroll bar now takes space, so the content overflows beside it and the horizontal scroll bar
    // shows too
    expect(view.hasHorizontalScroller) == true
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120 - thickness, height: 200 - thickness)
  }

  func test_resizeWithAScrollerStyleChangeThatKeepsTheVisibleSize_decidesTheScrollBarsAgain() {
    // given: a 100 × 100 view in a window, with overlay scroll bars, showing content 110 pt wide and tall, so both scroll
    // bars show, and the window laid out
    let window = TestWindow()
    let view = makeView(scrollerStyle: .overlay) { LayerNode().frame(width: 110, height: 110) }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == true

    // when: the view grows by a legacy scroll bar's width in each direction and switches to legacy scroll bars, which
    // take that space, so the visible size stays 100 × 100, and the window lays out
    view.frame = CGRect(x: 0, y: 0, width: 100 + thickness, height: 100 + thickness)
    view.scrollerStyle = .legacy
    expect(view.visibleSize) == CGSize(width: 100, height: 100)
    window.layoutIfNeeded()

    // then: the view renders for its new size, where the content fits, so both scroll bars hide and the content lays out
    // for the whole view
    expect(view.hasHorizontalScroller) == false
    expect(view.hasVerticalScroller) == false
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 100 + thickness, height: 100 + thickness)
  }

  // MARK: - Re-tiling

  func test_manuallyShowingAScrollBar_rendersBesideIt() {
    // given: a 120 × 200 view in a window that leaves its legacy scroll bars to the caller, and rendered content as wide
    // as the view and 300 pt tall without a scroll bar, and the window laid out
    let window = TestWindow()
    let view = makeView { WidthDependentNode(state: WidthDependentNode.State(), height: { _ in 300 }) }
    view.scrollIndicatorBehavior = .manual
    view.hasVerticalScroller = false
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120, height: 200)

    // when: the caller shows the vertical scroll bar, and the window lays out
    view.hasVerticalScroller = true
    window.layoutIfNeeded()

    // then: the content lays out beside the scroll bar
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120 - thickness, height: 200)
    expect(view.contentSize) == CGSize(width: 120 - thickness, height: 300)
  }

  func test_scrollerStyleChange_withoutScrollBars_doesNotLayOut() {
    // given: a 120 × 200 view in a window, with legacy scroll bars, that rendered content that fits it, without scroll
    // bars, and the window laid out
    let window = TestWindow()
    let view = makeView { LayerNode().frame(width: 100, height: 100) }
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    expect(view.hasVerticalScroller) == false
    expect(view.hasHorizontalScroller) == false
    view.layoutCount = 0

    // when: the scroll bars switch to overlay, and the window lays out
    view.scrollerStyle = .overlay
    window.layoutIfNeeded()

    // then: no scroll bar takes space either way, so the visible size stays, and the view doesn't lay out
    expect(view.visibleSize) == CGSize(width: 120, height: 200)
    expect(view.layoutCount) == 0
  }

  func test_resizing_laysOutOnce() {
    // given: a 120 × 200 view in a window, with legacy scroll bars, that rendered content as wide as the view and 300 pt
    // tall, beside the vertical scroll bar, and the window laid out
    let window = TestWindow()
    let view = makeView { WidthDependentNode(state: WidthDependentNode.State(), height: { _ in 300 }) }
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    view.layoutCount = 0

    // when: the view gets wider, the window lays out, and the run loop turns, where a follow-up layout would run
    view.frame.size = CGSize(width: 150, height: 200)
    window.layoutIfNeeded()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

    // then: the view re-tiles as it resizes and as it lays out, and lays out once, rendering for the new visible size
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 150 - thickness, height: 200)
    expect(view.layoutCount) == 1
  }

  func test_refreshShowingAScrollBar_doesNotLayOutAgain() {
    // given: a 120 × 200 view in a window, with legacy scroll bars, that rendered content as wide as the view and 100 pt
    // tall, without scroll bars, and the window laid out
    var contentHeight: CGFloat = 100
    let window = TestWindow()
    let view = makeView { WidthDependentNode(state: WidthDependentNode.State(), height: { _ in contentHeight }) }
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    expect(view.hasVerticalScroller) == false
    view.layoutCount = 0

    // when: the content gets taller than the view, the view refreshes, and the window lays out
    contentHeight = 300
    view.refresh(animated: false)
    window.layoutIfNeeded()

    // then: the refresh shows the vertical scroll bar and renders beside it, so the scroll bar's re-tile doesn't lay the
    // view out again
    expect(view.hasVerticalScroller) == true
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 120 - thickness, height: 200)
    expect(view.layoutCount) == 0
  }

  func test_refreshKeepingBothScrollBars_doesNotResizeTheClipView() {
    // given: a 120 × 200 view with legacy scroll bars, that rendered content 300 pt tall and 115 pt wide, which fits the
    // view's width but not the width beside a vertical scroll bar, so both scroll bars show, and counts the clip view's
    // resizes
    let view = makeView { LayerNode().frame(width: 115, height: 300) }
    view.refresh(animated: false)
    var clipViewResizeCount = 0
    view.contentView.postsFrameChangedNotifications = true
    let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view.contentView, queue: nil) { _ in
      clipViewResizeCount += 1
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
    }

    // when: the view refreshes again
    view.refresh(animated: false)

    // then: both scroll bars stay, and the clip view doesn't resize
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == true
    expect(clipViewResizeCount) == 0
  }

  // MARK: - Scroll Position

  func test_refreshScrolledToTheBottom_keepsTheScrollPosition() {
    // given: a 120 × 200 view in a window, with legacy scroll bars, showing thirty rows 115 pt wide and 10 pt tall, so
    // it shows the horizontal scroll bar only because the vertical one takes width, scrolled to the bottom. the rows are
    // shorter than the scroll bar, so a position off by the scroll bar's height leaves the last row out.
    let window = TestWindow()
    let view = makeView {
      VStack {
        for _ in 0 ..< 30 {
          LayerNode().frame(width: 115, height: 10)
        }
      }
    }
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    let bottom = CGPoint(x: 0, y: 300 - (200 - thickness))
    view.contentOffset = bottom
    window.layoutIfNeeded()

    // when: the view refreshes with the same content
    view.refresh(animated: false)

    // then: the update hides the horizontal scroll bar on the way and shows it again, and the view stays at the bottom,
    // with the last row rendered and fully visible
    expect(view.hasHorizontalScroller) == true
    expect(view.contentOffset) == bottom
    expect(view.test.lastRenderBounds?.origin) == bottom
    expect(view.test.lastRenderBounds?.maxY) == 300
    expect(renderedFrames(in: view).last) == CGRect(x: 0, y: 290, width: 115, height: 10)
  }

  func test_refreshScrolledToTheRightEnd_keepsTheScrollPosition() {
    // given: a 200 × 120 view in a window, with legacy scroll bars, showing thirty columns 10 pt wide and 115 pt tall,
    // so it shows the vertical scroll bar only because the horizontal one takes height, scrolled to the right end. the
    // columns are narrower than the scroll bar, so a position off by the scroll bar's width leaves the last column out.
    let window = TestWindow()
    let view = makeView {
      HStack {
        for _ in 0 ..< 30 {
          LayerNode().frame(width: 10, height: 115)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 120)
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    let rightEnd = CGPoint(x: 300 - (200 - thickness), y: 0)
    view.contentOffset = rightEnd
    window.layoutIfNeeded()

    // when: the view refreshes with the same content
    view.refresh(animated: false)

    // then: the update hides the vertical scroll bar on the way and shows it again, and the view stays at the right end,
    // with the last column rendered and fully visible
    expect(view.hasVerticalScroller) == true
    expect(view.contentOffset) == rightEnd
    expect(view.test.lastRenderBounds?.origin) == rightEnd
    expect(view.test.lastRenderBounds?.maxX) == 300
    expect(renderedFrames(in: view).last) == CGRect(x: 290, y: 0, width: 10, height: 115)
  }

  func test_refreshWithTheSameContent_keepsAnOffsetOutsideTheScrollableRange() {
    // given: a 120 × 200 view in a window, with legacy scroll bars, showing content 115 pt wide and 300 pt tall, so it
    // shows the horizontal scroll bar only because the vertical one takes width, with the offset 30 pt past the bottom
    let window = TestWindow()
    let view = makeView { LayerNode().frame(width: 115, height: 300) }
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    let pastTheBottom = CGPoint(x: 0, y: 300 - (200 - thickness) + 30)
    view.contentOffset = pastTheBottom
    window.layoutIfNeeded()

    // when: the view refreshes with the same content
    view.refresh(animated: false)

    // then: the update hides the horizontal scroll bar on the way and shows it again, and the offset stays past the
    // bottom, as the view keeps an offset set outside the scrollable range
    expect(view.hasHorizontalScroller) == true
    expect(view.contentOffset) == pastTheBottom
    expect(view.test.lastRenderBounds?.origin) == pastTheBottom

    // when: the offset is set 30 pt above the top, and the view refreshes with the same content
    let aboveTheTop = CGPoint(x: 0, y: -30)
    view.contentOffset = aboveTheTop
    window.layoutIfNeeded()
    view.refresh(animated: false)

    // then: the offset stays above the top
    expect(view.hasHorizontalScroller) == true
    expect(view.contentOffset) == aboveTheTop
    expect(view.test.lastRenderBounds?.origin) == aboveTheTop
  }

  func test_refreshScrolledBetweenPixels_keepsTheScrollPositionExactly() {
    // given: a 120 × 200 view in a window, with legacy scroll bars, showing content 115 pt wide and 300 pt tall, so it
    // shows the horizontal scroll bar only because the vertical one takes width, scrolled to 100.25 pt, between pixels,
    // as AppKit's own scrolling can leave it
    let window = TestWindow()
    let view = makeView { LayerNode().frame(width: 115, height: 300) }
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    let offset = CGPoint(x: 0, y: 100.25)
    view.setContentOffsetExactly(offset)
    window.layoutIfNeeded()

    // when: the view refreshes with the same content
    view.refresh(animated: false)

    // then: the update hides the horizontal scroll bar on the way, which AppKit clamps the offset for, and shows it
    // again, and the view keeps the offset exactly, without rounding it to a pixel
    expect(view.hasHorizontalScroller) == true
    expect(view.contentOffset) == offset
    expect(view.test.lastRenderBounds?.origin) == offset
  }

  func test_hidingTheScrollBarsAtTheBottom_keepsAnOffsetBetweenPixelsAlongTheOtherAxis() {
    // given: a 120 × 200 view in a window, with legacy scroll bars, showing content 300 pt wide and tall, scrolled to the
    // bottom and to 50.25 pt horizontally, between pixels, as AppKit's own scrolling can leave it
    let window = TestWindow()
    let view = makeView { LayerNode().frame(width: 300, height: 300) }
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    view.setContentOffsetExactly(CGPoint(x: 50.25, y: 300 - (200 - thickness)))
    window.layoutIfNeeded()

    // when: the view stops showing scroll indicators, and refreshes
    view.scrollIndicatorBehavior = .never
    view.refresh(animated: false)

    // then: the visible area grew, so the offset clamps to the new bottom, and keeps its horizontal position exactly,
    // without rounding it to a pixel
    expect(view.contentOffset) == CGPoint(x: 50.25, y: 300 - 200)
  }

  func test_refreshWithShorterContent_clampsTheScrollPosition() {
    // given: a 120 × 200 view in a window, with legacy scroll bars, showing content 115 pt wide and 300 pt tall,
    // scrolled to the bottom
    var contentHeight: CGFloat = 300
    let window = TestWindow()
    let view = makeView { LayerNode().frame(width: 115, height: contentHeight) }
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    view.contentOffset = CGPoint(x: 0, y: 300 - (200 - thickness))
    window.layoutIfNeeded()

    // when: the content gets 250 pt tall, and the view refreshes
    contentHeight = 250
    view.refresh(animated: false)

    // then: the bottom moved up, so the offset clamps to the new bottom
    expect(view.contentOffset) == CGPoint(x: 0, y: 250 - (200 - thickness))

    // when: the content gets 190 pt tall, which fits the view, and the view refreshes
    contentHeight = 190
    view.refresh(animated: false)

    // then: both scroll bars hide, and the offset clamps to the top
    expect(view.hasHorizontalScroller) == false
    expect(view.hasVerticalScroller) == false
    expect(view.contentOffset) == .zero
  }

  func test_hidingTheScrollBarsAtTheBottom_clampsTheScrollPosition() {
    // given: a 120 × 200 view in a window, with legacy scroll bars, showing content 300 pt wide and tall, scrolled to the
    // bottom
    let window = TestWindow()
    let view = makeView { LayerNode().frame(width: 300, height: 300) }
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    view.contentOffset = CGPoint(x: 0, y: 300 - (200 - thickness))
    window.layoutIfNeeded()

    // when: the view stops showing scroll indicators, and refreshes
    view.scrollIndicatorBehavior = .never
    view.refresh(animated: false)

    // then: the content size stays, but the visible area grew, so the offset clamps to the new bottom
    expect(view.contentSize) == CGSize(width: 300, height: 300)
    expect(view.contentOffset) == CGPoint(x: 0, y: 300 - 200)
  }

  func test_refreshThatHidesTheHorizontalScrollBar_keepsAnOffsetTheNewContentAllows() {
    // given: a 120 × 200 view in a window, with legacy scroll bars, showing content 115 pt wide and 300 pt tall, scrolled
    // to the bottom
    var contentSize = CGSize(width: 115, height: 300)
    let window = TestWindow()
    let view = makeView { LayerNode().frame(width: contentSize.width, height: contentSize.height) }
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    let offset = CGPoint(x: 0, y: 300 - (200 - thickness))
    view.contentOffset = offset
    window.layoutIfNeeded()

    // when: the content gets 100 pt wide, which fits beside the vertical scroll bar, and 400 pt tall, and the view
    // refreshes
    contentSize = CGSize(width: 100, height: 400)
    view.refresh(animated: false)

    // then: the horizontal scroll bar hides, and the offset stays, since the taller content still allows it
    expect(view.hasHorizontalScroller) == false
    expect(view.contentOffset) == offset
    expect(view.test.lastRenderBounds?.origin) == offset
  }

  func test_refreshThatHidesTheVerticalScrollBar_keepsAnOffsetTheNewContentAllows() {
    // given: a 200 × 120 view in a window, with legacy scroll bars, showing content 300 pt wide and 115 pt tall, scrolled
    // to the right end
    var contentSize = CGSize(width: 300, height: 115)
    let window = TestWindow()
    let view = makeView { LayerNode().frame(width: contentSize.width, height: contentSize.height) }
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 120)
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    let offset = CGPoint(x: 300 - (200 - thickness), y: 0)
    view.contentOffset = offset
    window.layoutIfNeeded()

    // when: the content gets 400 pt wide and 100 pt tall, which fits above the horizontal scroll bar, and the view
    // refreshes
    contentSize = CGSize(width: 400, height: 100)
    view.refresh(animated: false)

    // then: the vertical scroll bar hides, and the offset stays, since the wider content still allows it
    expect(view.hasVerticalScroller) == false
    expect(view.contentOffset) == offset
    expect(view.test.lastRenderBounds?.origin) == offset
  }

  func test_willLayoutHandlerSettingTheOffsetBesideTheScrollBar_keepsItsOffset() {
    // given: a 120 × 200 view in a window, with legacy scroll bars, showing content 115 pt wide and 300 pt tall, scrolled
    // to the bottom, and a will-layout handler that sets the offset on the second layout, beside the vertical scroll bar
    let window = TestWindow()
    let view = makeView { LayerNode().frame(width: 115, height: 300) }
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    view.contentOffset = CGPoint(x: 0, y: 300 - (200 - thickness))
    window.layoutIfNeeded()
    var layoutCount = 0
    view.onWillLayout { view, _ in
      layoutCount += 1
      if layoutCount == 2 {
        view.contentOffset = CGPoint(x: 0, y: 40)
      }
    }

    // when: the view refreshes with the same content
    view.refresh(animated: false)

    // then: the update hides the horizontal scroll bar on the way and shows it again, and the handler's offset stays
    expect(layoutCount) == 3
    expect(view.hasHorizontalScroller) == true
    expect(view.contentOffset) == CGPoint(x: 0, y: 40)
    expect(view.test.lastRenderBounds?.origin) == CGPoint(x: 0, y: 40)
  }

  func test_willLayoutHandlerSettingTheOffsetOnTheFirstLayout_laterLayoutsReportIt() {
    // given: a 120 × 200 view in a window, with legacy scroll bars, showing content 115 pt wide and 300 pt tall, so it
    // shows the horizontal scroll bar only because the vertical one takes width, and a will-layout handler that records
    // the viewports it gets and sets the offset on the first layout
    let window = TestWindow()
    let view = makeView { LayerNode().frame(width: 115, height: 300) }
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    var reportedBounds: [CGRect] = []
    view.onWillLayout { view, context in
      switch context.renderType {
      case .refresh:
        break
      case .boundsChange(_, let bounds):
        reportedBounds.append(bounds)
        if reportedBounds.count == 1 {
          view.contentOffset = CGPoint(x: 0, y: 40)
        }
      }
    }

    // when: the view gets 1 pt wider, so it lays out for its full size, then beside the vertical scroll bar, then beside
    // both scroll bars
    view.frame = CGRect(x: 0, y: 0, width: 121, height: 200)
    window.layoutIfNeeded()

    // then: each layout reports the current offset, so the layouts after the handler's change report its offset, which
    // the pass renders
    expect(reportedBounds) == [
      CGRect(x: 0, y: 0, width: 121, height: 200),
      CGRect(x: 0, y: 40, width: 121 - thickness, height: 200),
      CGRect(x: 0, y: 40, width: 121 - thickness, height: 200 - thickness),
    ]
    expect(view.test.lastRenderBounds?.origin) == CGPoint(x: 0, y: 40)
  }

  func test_willLayoutHandlerChangingTheBehaviorOnTheSecondLayout_assertsAndKeepsIt() {
    // given: a 120 × 200 view with legacy scroll bars, showing content larger than the view, a will-layout handler that
    // switches to never showing the scroll indicators on the second layout, after the scroll bars take space, and a
    // handler that records the assertions
    let view = makeView { LayerNode().frame(width: 300, height: 300) }
    var layoutCount = 0
    view.onWillLayout { view, _ in
      layoutCount += 1
      if layoutCount == 2 {
        view.scrollIndicatorBehavior = .never
      }
    }

    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the change asserts, and the pass keeps the automatic behavior, so both scroll bars show and the content lays
    // out for the space they leave
    expect(assertionMessages) == ["onWillLayout can't change scrollBehavior, scrollIndicatorBehavior or clippingBehavior"]
    expect(view.scrollIndicatorBehavior) == .auto
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == true
    expect(view.test.lastRenderBounds?.size) == CGSize(width: 120 - thickness, height: 200 - thickness)
  }

  func test_willLayoutHandlerShowingAScrollBarForTheContainerSize_assertsAndKeepsIt() {
    // given: a 120 × 200 view in a window, with manual legacy scroll bars, both hidden, showing content 100 pt wide and
    // tall, a will-layout handler that shows the vertical scroll bar when the container is wider than 110 pt, which the
    // scroll bar itself would make it not, and a handler that records the assertions
    let window = TestWindow()
    let view = makeView { LayerNode().frame(width: 100, height: 100) }
    view.scrollIndicatorBehavior = .manual
    view.showsHorizontalScrollIndicator = false
    view.showsVerticalScrollIndicator = false
    window.contentView().addSubview(view)
    var layoutCount = 0
    view.onWillLayout { view, context in
      layoutCount += 1
      view.showsVerticalScrollIndicator = context.containerSize.width > 110
    }

    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: the view refreshes, and the run loop runs twice
    view.refresh(animated: false)
    for _ in 0 ..< 2 {
      var isDrained = false
      RunLoop.main.perform { isDrained = true }
      expect(isDrained).toEventually(beTrue())
    }

    // then: the change of the visible size asserts, and the pass keeps the scroll bar hidden and lays out once, for the
    // whole view, so no follow-up pass shows it
    expect(assertionMessages) == ["onWillLayout can't change the visible size"]
    expect(view.hasVerticalScroller) == false
    expect(layoutCount) == 1
    expect(view.test.lastRenderBounds?.size) == CGSize(width: 120, height: 200)
  }

  func test_willLayoutHandlerSwitchingTheScrollerStyleForTheContainerSize_assertsAndKeepsIt() {
    // given: a 120 × 200 view in a window, with overlay scroll bars, showing content 100 pt wide and 300 pt tall, so it
    // shows the vertical scroll bar, a will-layout handler that switches to legacy scroll bars for the view's full width
    // and back to overlay ones otherwise, and a handler that records the assertions
    let window = TestWindow()
    let view = makeView(scrollerStyle: .overlay) { LayerNode().frame(width: 100, height: 300) }
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    var layoutCount = 0
    view.onWillLayout { view, context in
      layoutCount += 1
      view.scrollerStyle = context.containerSize.width == 120 ? .legacy : .overlay
    }

    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: the view refreshes, and the run loop runs twice
    view.refresh(animated: false)
    for _ in 0 ..< 2 {
      var isDrained = false
      RunLoop.main.perform { isDrained = true }
      expect(isDrained).toEventually(beTrue())
    }

    // then: the change of the visible size asserts, and the pass keeps the overlay scroll bars and lays out once, for the
    // whole view, so no follow-up pass switches the style again
    expect(assertionMessages) == ["onWillLayout can't change the visible size"]
    expect(view.scrollerStyle) == .overlay
    expect(layoutCount) == 1
    expect(view.test.lastRenderBounds?.size) == CGSize(width: 120, height: 200)
  }

  func test_didRenderHandlerResizingWithAScrollerStyleChangeThatKeepsTheVisibleSize_rendersAgain() {
    // given: a 100 × 100 view in a window, with overlay scroll bars, showing content 110 pt wide and tall, so both scroll
    // bars show, the window laid out, and a did-render handler that once grows the view by a legacy scroll bar's width in
    // each direction and switches to legacy scroll bars, which take that space, so the visible size stays 100 × 100
    let window = TestWindow()
    let view = makeView(scrollerStyle: .overlay) { LayerNode().frame(width: 110, height: 110) }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    let grownFrame = CGRect(x: 0, y: 0, width: 100 + thickness, height: 100 + thickness)
    var resizes = true
    view.onDidRender { view, _ in
      guard resizes else {
        return
      }
      resizes = false
      view.frame = grownFrame
      view.scrollerStyle = .legacy
    }

    // when: the view refreshes during the window's layout, which ignores the layout the resize requests, and the run loop
    // runs the pass that follows it
    view.setNeedsRefresh(animated: false)
    window.layoutIfNeeded()
    var isDrained = false
    RunLoop.main.perform { isDrained = true }
    expect(isDrained).toEventually(beTrue())

    // then: the view renders again for its new size, where the content fits, so both scroll bars hide and the content
    // lays out for the whole view
    expect(view.hasHorizontalScroller) == false
    expect(view.hasVerticalScroller) == false
    expect(view.test.lastRenderBounds) == grownFrame
  }

  // MARK: - Helpers

  /// Makes a 120 × 200 view that shows scroll bars of the style for the axes its content overflows.
  private func makeView(scrollerStyle: NSScroller.Style = .legacy, @ComposeContentBuilder content: @escaping () -> ComposeContent) -> LayoutCountingComposeView {
    let view = LayoutCountingComposeView(content: content)
    view.frame = CGRect(x: 0, y: 0, width: 120, height: 200)
    view.scrollIndicatorBehavior = .auto
    view.scrollerStyle = scrollerStyle
    return view
  }

  /// Returns the frames of the view's rendered layers in content coordinates, ordered by position.
  private func renderedFrames(in view: ComposeView) -> [CGRect] {
    let frames = view.contentContainerView.layer?.sublayers?.map(\.frame) ?? []
    return frames.sorted { ($0.minY, $0.minX) < ($1.minY, $1.minX) }
  }
}

/// A node as wide as its container, with a height that the width decides, that records the container sizes it lays out
/// for.
private struct WidthDependentNode: ComposeNode {

  final class State {

    /// The container sizes the node laid out for, in order.
    var layoutContainerSizes: [CGSize] = []
  }

  private let state: State
  private let height: (_ width: CGFloat) -> CGFloat

  init(state: State, height: @escaping (_ width: CGFloat) -> CGFloat) {
    self.state = state
    self.height = height
  }

  var id: ComposeNodeId = .custom("width-dependent", isFixed: false)

  var size: CGSize = .zero

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    state.layoutContainerSizes.append(containerSize)
    size = CGSize(width: containerSize.width, height: height(containerSize.width))
    return ComposeNodeSizing(width: .flexible, height: .fixed(size.height))
  }

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    []
  }
}

/// A scroller that makes legacy scroll bars thinner than regular ones.
private final class ThinScroller: NSScroller {

  /// The thickness of the scroller.
  static let thickness: CGFloat = 10

  override static func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
    thickness
  }
}

/// A view that counts its layouts.
private final class LayoutCountingComposeView: ComposeView {

  /// The number of times the view laid out.
  var layoutCount = 0

  override func layout() {
    layoutCount += 1
    super.layout()
  }
}
#endif
