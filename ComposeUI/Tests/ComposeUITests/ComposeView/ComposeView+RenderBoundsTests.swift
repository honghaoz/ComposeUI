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
    view.contentOffset = CGPoint(x: 0, y: 10)
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

    view.contentOffset = CGPoint(x: 0, y: 200)
    view.layoutIfNeeded()
    expect(view.hasHorizontalScroller) == true
    expect(view.contentOffset) == CGPoint(x: 0, y: 200)

    // when: a refresh shortens the rows, so the clip view clamps the offset while the horizontal scroller shows, and
    // fits them horizontally, which hides the scroller and clamps the offset again
    contentSize = CGSize(width: 100, height: 250)
    view.refresh(animated: false)

    // then: the pass renders the rows at the offset the view ends up with
    expect(view.hasHorizontalScroller) == false
    expect(view.contentOffset) == CGPoint(x: 0, y: 150)
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

    view.contentOffset = CGPoint(x: 200, y: 0)
    view.layoutIfNeeded()
    expect(view.hasVerticalScroller) == true
    expect(view.contentOffset) == CGPoint(x: 200, y: 0)

    // when: a refresh narrows the columns, so the clip view clamps the offset while the vertical scroller shows, and
    // fits them vertically, which hides the scroller and clamps the offset again
    contentSize = CGSize(width: 250, height: 100)
    view.refresh(animated: false)

    // then: the pass renders the columns at the offset the view ends up with
    expect(view.hasVerticalScroller) == false
    expect(view.contentOffset) == CGPoint(x: 150, y: 0)
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

    view.contentOffset = CGPoint(x: 0, y: 200)
    view.layoutIfNeeded()
    expect(view.hasHorizontalScroller) == false
    expect(view.contentOffset) == CGPoint(x: 0, y: 200)

    // when: a refresh shortens the rows, so the clip view clamps the offset, and widens them, which shows the
    // horizontal scroller and shrinks the clip view
    contentSize = CGSize(width: 200, height: 250)
    view.refresh(animated: false)

    // then: the pass renders the rows at the offset the view ends up with
    expect(view.hasHorizontalScroller) == true
    expect(view.contentOffset) == CGPoint(x: 0, y: 150)
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
    view.contentOffset = CGPoint(x: 0, y: maxOffsetY)
    view.layoutIfNeeded()

    // then: the view stays at the end, rendered once for the full view size, with the rows that fill the viewport
    expect(view.contentOffset) == CGPoint(x: 0, y: maxOffsetY)
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
    view.contentOffset = CGPoint(x: 10, y: 50)
    view.layoutIfNeeded()

    // then: the view stays where it's scrolled to, rendered once for the full view size
    expect(view.contentOffset) == CGPoint(x: 10, y: 50)
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

    // then: the view renders once, at the new end, for the full view size
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == true
    expect(view.contentOffset) == CGPoint(x: 0, y: view.maxOffsetY)
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

    // then: the scrollers show over the clip view with the insets, and the content lays out for the frame inside the
    // 1 pt border, in the document's magnified coordinates
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == true
    expect(view.contentView.frame.size) == CGSize(width: 120, height: 80)
    expect(view.test.lastRenderBounds?.size) == CGSize(width: 60, height: 40)

    // when: the insets are removed, so the scrollers take space from the clip view, and the view refreshes
    view.contentInsets = NSEdgeInsetsZero
    view.refresh(animated: false)

    // then: the size stays
    let thickness = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    expect(view.contentView.frame.size) == CGSize(width: 120 - thickness, height: 80 - thickness)
    expect(view.test.lastRenderBounds?.size) == CGSize(width: 60, height: 40)
  }

  func test_renderBounds_borderTypes_matchTheClipViewWithoutScrollers() {
    for borderType in [NSBorderType.noBorder, .lineBorder, .bezelBorder, .grooveBorder] {
      // given: a 240 × 180 view with the border and no scrollers
      let view = ComposeView {
        LayerNode().frame(width: 10, height: 10)
      }
      view.frame = CGRect(x: 0, y: 0, width: 240, height: 180)
      view.borderType = borderType

      // when: the view refreshes
      view.refresh(animated: false)

      // then: the content lays out for the area AppKit tiles the clip view in
      expect(view.test.lastRenderBounds?.size) == view.contentView.bounds.size
    }
  }

  func test_renderBounds_grooveBorder_contentOverflowingTheTiledBorderScrolls() {
    // given: a 240 × 180 view with a groove border, which AppKit tiles 2 pt wide on each side, leaving 236 × 176 without
    // scrollers, showing 237 × 177 content that overflows that area, though not the 238 × 178 AppKit calculates for the
    // frame
    let view = ComposeView {
      LayerNode().frame(width: 237, height: 177)
    }
    view.frame = CGRect(x: 0, y: 0, width: 240, height: 180)
    useLegacyScrollers(view)
    view.borderType = .grooveBorder

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the content lays out for the area inside the tiled border, so it scrolls, with both scrollers shown
    expect(view.test.lastRenderBounds?.size) == CGSize(width: 236, height: 176)
    expect(view.isScrollEnabled) == true
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == true

    // when: the scrollers hide
    view.scrollIndicatorBehavior = .never
    view.refresh(animated: false)

    // then: the size stays, and it's the area the view shows
    expect(view.test.lastRenderBounds?.size) == CGSize(width: 236, height: 176)
    expect(view.contentView.bounds.size) == CGSize(width: 236, height: 176)
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

    // then: the content lays out and renders for the scaled viewport, 20 rows 400 pt wide
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 400, height: 200)
    expect(renderedFrames(in: view)) == (0 ..< 20).map { CGRect(x: 0, y: CGFloat($0) * 10, width: 400, height: 10) }
  }

  func test_renderBounds_legacyScrollerMovedInByTheRightContentInset_rendersTheFullWidth() throws {
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

    // then: the rows lay out for the full view width, and only the vertical scroller shows
    let thickness = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    let verticalScroller = try view.verticalScroller.unwrap()
    expect(view.contentView.frame.width) == 240 - thickness
    expect(verticalScroller.frame.maxX) < view.contentView.frame.maxX
    expect(view.hasVerticalScroller) == true
    expect(view.hasHorizontalScroller) == false
    expect(renderedFrames(in: view)) == (0 ..< 18).map { CGRect(x: 0, y: CGFloat($0) * 10, width: 240, height: 10) }

    // when: the rows become 230 pt wide, which fits the view width but not the clip view
    rowWidth = 230
    view.refresh(animated: false)

    // then: the rows fit, centered in the view width, so the horizontal scroller stays hidden
    expect(view.hasHorizontalScroller) == false
    expect(renderedFrames(in: view)) == (0 ..< 18).map { CGRect(x: 5, y: CGFloat($0) * 10, width: 230, height: 10) }
  }

  func test_renderBounds_legacyScrollerMovedInByTheBottomContentInset_rendersTheFullHeight() throws {
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

    // then: the rows center in the full view height, and only the horizontal scroller shows
    let thickness = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    let horizontalScroller = try view.horizontalScroller.unwrap()
    expect(view.contentView.frame.height) == 180 - thickness
    expect(horizontalScroller.frame.maxY) < view.contentView.frame.maxY
    expect(view.hasHorizontalScroller) == true
    expect(view.hasVerticalScroller) == false
    expect(renderedFrames(in: view)) == (0 ..< 5).map { CGRect(x: 0, y: 65 + CGFloat($0) * 10, width: 400, height: 10) }
  }

  func test_renderBounds_fractionalViewSize_roundsDownWithTheClipView() {
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

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the rows lay out for the size AppKit rounds the clip view down to, so the content is no wider than the
    // visible area, and only the vertical scroller shows
    expect(view.visibleSize) == CGSize(width: 99, height: 99)
    expect(view.test.lastRenderBounds?.size) == CGSize(width: 99, height: 99)
    expect(view.contentSize) == CGSize(width: 99, height: 400)
    expect(view.hasVerticalScroller) == true
    expect(view.hasHorizontalScroller) == false
  }

  func test_renderBounds_fractionalViewSize_roundsUpWithTheClipView() {
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

    // then: the content lays out for the size AppKit rounds the clip view up to, which it fits, so the view neither
    // scrolls nor shows scrollers
    expectSize(view.visibleSize, approximatelyEquals: CGSize(width: 100, height: 100))
    expectSize(view.test.lastRenderBounds?.size, approximatelyEquals: CGSize(width: 100, height: 100))
    expect(view.isScrollEnabled) == false
    expect(view.hasVerticalScroller) == false
    expect(view.hasHorizontalScroller) == false
  }

  func test_renderBounds_scaledBoundsWithBorder_matchesTheClipView() {
    for (borderType, boundsLength, contentLength) in [(NSBorderType.lineBorder, CGFloat(150), CGFloat(148)), (.grooveBorder, 300, 296)] {
      // given: a 100 × 100 view in a window, with the border and scaled bounds, showing content as large as the area
      // inside the border before AppKit rounds it to the pixels of the scaled bounds
      let window = TestWindow()
      let view = ComposeView {
        LayerNode().frame(width: contentLength, height: contentLength)
      }
      view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      view.borderType = borderType
      window.contentView().addSubview(view)
      view.setBoundsSize(CGSize(width: boundsLength, height: boundsLength))

      // when: the view refreshes
      view.refresh(animated: false)

      // then: the content lays out for the clip view's size, so the view scrolls exactly when the content doesn't fit it
      let clipSize = view.contentView.frame.size
      expectSize(view.test.lastRenderBounds?.size, approximatelyEquals: clipSize)
      expect(view.isScrollEnabled) == (contentLength > clipSize.width)
    }
  }

  func test_renderBounds_viewSmallerThanItsBorder_laysOutForAnEmptySize() {
    // given: a 3 × 3 view with a groove border, which is 2 pt wide on each side
    let view = ComposeView {
      LayerNode().frame(width: 10, height: 10)
    }
    view.frame = CGRect(x: 0, y: 0, width: 3, height: 3)
    view.borderType = .grooveBorder

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the content lays out for an empty size rather than a negative one
    expect(view.test.lastRenderBounds?.size) == .zero
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

    // then: the view renders once, after the tiling, for the new size at the clamped offset
    expect(view.contentOffset) == CGPoint(x: 0, y: view.maxOffsetY)
    expect(renderBounds) == [CGRect(x: 0, y: view.maxOffsetY, width: 140, height: 140)]
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
