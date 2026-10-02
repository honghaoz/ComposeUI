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

  // MARK: - Scroll Position

  func test_refreshScrolledToTheBottom_keepsTheScrollPosition() {
    // given: a 120 × 200 view in a window, with legacy scroll bars, showing content 115 pt wide and 300 pt tall, so it
    // shows the horizontal scroll bar only because the vertical one takes width, scrolled to the bottom
    let window = TestWindow()
    let view = makeView { LayerNode().frame(width: 115, height: 300) }
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    let bottom = CGPoint(x: 0, y: 300 - (200 - thickness))
    view.contentOffset = bottom
    window.layoutIfNeeded()

    // when: the view refreshes with the same content
    view.refresh(animated: false)

    // then: the update hides the horizontal scroll bar on the way and shows it again, and the view stays at the bottom
    expect(view.hasHorizontalScroller) == true
    expect(view.contentOffset) == bottom
    expect(view.test.lastRenderBounds?.origin) == bottom
  }

  func test_refreshScrolledToTheRightEnd_keepsTheScrollPosition() {
    // given: a 200 × 120 view in a window, with legacy scroll bars, showing content 300 pt wide and 115 pt tall, so it
    // shows the vertical scroll bar only because the horizontal one takes height, scrolled to the right end
    let window = TestWindow()
    let view = makeView { LayerNode().frame(width: 300, height: 115) }
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 120)
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    window.layoutIfNeeded()
    let rightEnd = CGPoint(x: 300 - (200 - thickness), y: 0)
    view.contentOffset = rightEnd
    window.layoutIfNeeded()

    // when: the view refreshes with the same content
    view.refresh(animated: false)

    // then: the update hides the vertical scroll bar on the way and shows it again, and the view stays at the right end
    expect(view.hasVerticalScroller) == true
    expect(view.contentOffset) == rightEnd
    expect(view.test.lastRenderBounds?.origin) == rightEnd
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

  func test_willLayoutHandlerSwitchingToManualBesideTheScrollBars_keepsItsScrollIndicators() {
    // given: a 120 × 200 view with legacy scroll bars, showing content larger than the view, and a will-layout handler
    // that, on the second layout, beside the scroll bars, switches to manual scroll indicators and hides them
    let view = makeView { LayerNode().frame(width: 300, height: 300) }
    var layoutCount = 0
    view.onWillLayout { view, _ in
      layoutCount += 1
      guard layoutCount == 2 else {
        return
      }
      view.scrollIndicatorBehavior = .manual
      view.showsHorizontalScrollIndicator = false
      view.showsVerticalScrollIndicator = false
    }

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the automatic update stops when the handler switches to manual, so the scroll bars stay hidden
    expect(layoutCount) == 3
    expect(view.scrollIndicatorBehavior) == .manual
    expect(view.hasHorizontalScroller) == false
    expect(view.hasVerticalScroller) == false
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
