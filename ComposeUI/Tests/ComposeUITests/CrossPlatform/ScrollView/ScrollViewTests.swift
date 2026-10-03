//
//  ScrollViewTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/26.
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

#if canImport(UIKit)
import UIKit
#endif

import ChouTiTest

@testable import ComposeUI

class ScrollViewTests: XCTestCase {

  // MARK: - Content Offset

  func test_contentOffset() {
    // given: a 100 × 200 scroll view showing a 300 × 500 content
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    scrollView.contentSize = CGSize(width: 300, height: 500)

    // when: setting the content offset
    scrollView.contentOffset = CGPoint(x: 10, y: 20)

    // then: the visible area starts at the offset
    expect(scrollView.contentOffset) == CGPoint(x: 10, y: 20)
    #if canImport(AppKit)
    expect(scrollView.contentView.bounds.origin) == CGPoint(x: 10, y: 20)
    #endif
    #if canImport(UIKit)
    expect(scrollView.bounds.origin) == CGPoint(x: 10, y: 20)
    #endif
  }

  #if canImport(AppKit)
  func test_contentOffset_betweenPixels_roundsToTheNearestPixel() {
    // given: a 100 × 200 scroll view in a window, showing a 300 × 500 content
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    scrollView.contentSize = CGSize(width: 300, height: 500)
    window.contentView().addSubview(scrollView)
    let scale = window.backingScaleFactor

    // when: setting a content offset between pixels
    scrollView.contentOffset = CGPoint(x: 10.3, y: 20.3)

    // then: the offset rounds to the nearest pixel, as on UIKit, so the content lands on the window's pixels
    expect(scrollView.contentOffset) == CGPoint(x: (10.3 * scale).rounded() / scale, y: (20.3 * scale).rounded() / scale)
    let contentOrigin = window.convertToBacking(CGRect(origin: scrollView.contentContainerView.convert(CGPoint.zero, to: nil), size: .zero)).origin
    expect(contentOrigin.x) == contentOrigin.x.rounded()
    expect(contentOrigin.y) == contentOrigin.y.rounded()
  }
  #endif

  func test_contentOffset_outsideScrollableRange() {
    // given: a 100 × 200 scroll view showing a 300 × 500 content
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    scrollView.contentSize = CGSize(width: 300, height: 500)

    // when: setting a content offset past the start of the horizontal range and the end of the vertical range
    scrollView.contentOffset = CGPoint(x: -50, y: 1000)

    // then: the offset stays as set
    expect(scrollView.contentOffset) == CGPoint(x: -50, y: 1000)

    // when: the scroll view resizes
    scrollView.frame.size = CGSize(width: 100, height: 210)

    // then: the offset comes back into the scrollable range
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 290)
  }

  #if canImport(AppKit)
  func test_contentOffset_outsideScrollableRange_scrollWheel() throws {
    // given: a 100 × 200 scroll view in a window, showing content 500 tall, so it scrolls 300
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    scrollView.contentSize = CGSize(width: 100, height: 500)
    window.contentView().addSubview(scrollView)
    let cgEvent = try unwrap(CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: -1, wheel2: 0, wheel3: 0))
    let event = try unwrap(NSEvent(cgEvent: cgEvent))

    // when: the offset is past the end, and the run loop turns
    scrollView.contentOffset = CGPoint(x: 0, y: 1000)
    wait(timeout: 0.05)

    // then: the offset stays as set
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 1000)

    // when: the scroll view gets a one-line mouse wheel scroll
    scrollView.scrollWheel(with: event)

    // then: the offset comes back to the end of the scrollable range, once AppKit applies the scroll on the run loop
    expect(scrollView.contentOffset).toEventually(beEqual(to: CGPoint(x: 0, y: 300)))

    // when: the offset is before the start, and the scroll view gets the scroll again
    scrollView.contentOffset = CGPoint(x: 0, y: -100)
    scrollView.scrollWheel(with: event)

    // then: the offset comes back to the start of the scrollable range
    expect(scrollView.contentOffset).toEventually(beEqual(to: .zero))
  }

  func test_contentOffset_movesTheScroller() {
    // given: a 100 × 200 scroll view with a vertical scroller, showing content 500 tall, so it scrolls 300
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    scrollView.contentSize = CGSize(width: 100, height: 500)
    scrollView.hasVerticalScroller = true

    // when: scrolling halfway
    scrollView.contentOffset = CGPoint(x: 0, y: 150)

    // then: the scroller's knob is halfway along its track
    expect(scrollView.verticalScroller?.doubleValue) == 0.5
  }
  #endif

  // MARK: - Content Size

  func test_contentSize() {
    // given: a 100 × 200 scroll view
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))

    // when: setting the content size
    scrollView.contentSize = CGSize(width: 300, height: 500)

    // then: the content has the size
    expect(scrollView.contentSize) == CGSize(width: 300, height: 500)
    #if canImport(AppKit)
    expect(scrollView.documentView?.frame) == CGRect(x: 0, y: 0, width: 300, height: 500)
    #endif
  }

  // MARK: - Content Inset

  func test_contentInset() {
    // given: a scroll view without automatic inset adjustments
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    #if canImport(AppKit)
    scrollView.automaticallyAdjustsContentInsets = false
    #endif
    #if canImport(UIKit)
    scrollView.contentInsetAdjustmentBehavior = .never
    #endif

    // when: setting the content inset
    scrollView.contentInset = EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)

    // then: the content inset and the adjusted content inset are the set insets
    expect(Self.components(of: scrollView.contentInset)) == [10, 20, 30, 40]
    expect(Self.components(of: scrollView.adjustedContentInset)) == [10, 20, 30, 40]
    #if canImport(AppKit)
    expect(Self.components(of: scrollView.contentInsets)) == [10, 20, 30, 40]
    #endif
  }

  #if canImport(AppKit)
  func test_adjustedContentInset_automaticAdjustment() {
    // given: a scroll view with automatic inset adjustments, filling a window whose title bar and toolbar overlap it
    let window = NSWindow(
      contentRect: CGRect(x: 0, y: 0, width: 400, height: 300),
      styleMask: [.titled, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.toolbar = NSToolbar(identifier: "ScrollViewTests")
    let scrollView = ScrollView(frame: .zero)
    scrollView.automaticallyAdjustsContentInsets = true

    // when: the scroll view is placed in the window and the window lays out
    window.contentView = scrollView
    window.layoutIfNeeded()

    // then: AppKit applies the adjustment to `contentInsets`, so both the content inset and the adjusted content inset
    // include the overlap
    let overlap = scrollView.bounds.height - window.contentLayoutRect.height
    expect(overlap) > 0
    expect(scrollView.adjustedContentInset.top) == overlap
    expect(scrollView.contentInset.top) == overlap
  }
  #endif

  // MARK: - Visible Size

  func test_visibleSize() {
    // given: a 100 × 200 scroll view showing a 300 × 500 content
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    scrollView.contentSize = CGSize(width: 300, height: 500)

    // when: scrolling
    scrollView.contentOffset = CGPoint(x: 10, y: 20)

    // then: the visible area has the scroll view's size
    expect(scrollView.visibleSize) == CGSize(width: 100, height: 200)
  }

  #if canImport(AppKit)
  func test_visibleSize_legacyScroller() {
    // given: a 100 × 200 scroll view showing content taller than it, with a legacy vertical scroller
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    scrollView.contentSize = CGSize(width: 100, height: 500)
    scrollView.scrollerStyle = .legacy
    scrollView.hasVerticalScroller = true

    // when: the scroll view tiles
    scrollView.tile()

    // then: the scroller takes its width from the visible area
    let scrollerWidth = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    expect(scrollerWidth) > 0
    expect(scrollView.visibleSize) == CGSize(width: 100 - scrollerWidth, height: 200)
  }

  func test_visibleSize_magnification() {
    // given: a 100 × 200 scroll view showing a 300 × 500 content
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    scrollView.contentSize = CGSize(width: 300, height: 500)
    scrollView.allowsMagnification = true

    // when: magnifying the content 2×
    scrollView.magnification = 2

    // then: the visible area covers half as much content along each axis
    expect(scrollView.visibleSize) == CGSize(width: 50, height: 100)
  }

  func test_visibleSize_fractionalSize_isExact() {
    // given: a 99.2 × 99.2 scroll view showing a 300 × 500 content, whose clip view AppKit rounds to whole pixels
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 99.2, height: 99.2))
    scrollView.contentSize = CGSize(width: 300, height: 500)

    // then: the visible size is exact, and so is the scroll range, as on UIKit, while AppKit rounds the clip view
    expect(scrollView.contentView.bounds.size) == CGSize(width: 99, height: 99)
    expect(scrollView.visibleSize) == CGSize(width: 99.2, height: 99.2)
    expect(scrollView.maxOffsetX) == 300 - 99.2
    expect(scrollView.maxOffsetY) == 500 - 99.2

    // when: a legacy vertical scroller shows, and the scroll view tiles
    scrollView.scrollerStyle = .legacy
    scrollView.hasVerticalScroller = true
    scrollView.tile()

    // then: the visible size is the exact width beside the scroller
    let scrollerWidth = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    expect(scrollView.visibleSize) == CGSize(width: 99.2 - scrollerWidth, height: 99.2)
  }

  func test_visibleSize_replacedClipView_isTheClipViewSize() {
    // given: a 99.2 × 99.2 scroll view
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 99.2, height: 99.2))

    // when: the clip view is replaced with a plain one, and the scroll view tiles
    scrollView.contentView = NSClipView()
    scrollView.tile()

    // then: the visible size is the new clip view's size, which AppKit rounds to whole pixels
    expect(scrollView.visibleSize) == CGSize(width: 99, height: 99)
    expect(scrollView.visibleSize) == scrollView.contentView.bounds.size
  }

  func test_visibleSize_clipBoundsScaledDifferentlyAlongEachAxis_followsTheClipView() {
    // given: a 99.2 × 99.2 scroll view, whose clip view AppKit rounds to 99 pt
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 99.2, height: 99.2))

    // when: the clip view's bounds scale by 2 along x and by a half along y, which the magnification can't express
    scrollView.contentView.scaleUnitSquare(to: NSSize(width: 2, height: 0.5))

    // then: the visible size scales the exact size by the clip view's scale along each axis
    expect(scrollView.visibleSize) == CGSize(width: 49.6, height: 198.4)
  }

  func test_visibleSize_zeroSize_isZero() {
    // given: a 100 × 100 scroll view
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    // when: the scroll view shrinks to zero, and tiles
    scrollView.frame.size = .zero
    scrollView.tile()

    // then: the visible size is zero, instead of dividing by the clip view's zero size
    expect(scrollView.contentView.frame.size) == .zero
    expect(scrollView.visibleSize) == .zero
  }
  #endif

  #if canImport(UIKit)
  func test_visibleSize_isBoundsSize() {
    // given: a 100 × 200 scroll view showing a 300 × 500 content
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    scrollView.contentSize = CGSize(width: 300, height: 500)

    // when: insetting the content
    scrollView.contentInset = UIEdgeInsets(top: 10, left: 20, bottom: 30, right: 40)

    // then: the visible size is still the bounds size
    expect(scrollView.visibleSize) == CGSize(width: 100, height: 200)

    // when: zooming the content 2×
    let zoomingView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
    scrollView.addSubview(zoomingView)
    let delegate = ZoomingDelegate(zoomingView: zoomingView)
    withExtendedLifetime(delegate) {
      scrollView.delegate = delegate
      scrollView.maximumZoomScale = 4
      scrollView.zoomScale = 2

      // then: the zoom takes effect, and the visible size is still the bounds size
      expect(scrollView.zoomScale) == 2
      expect(scrollView.visibleSize) == CGSize(width: 100, height: 200)
    }
  }
  #endif

  // MARK: - Content Container View

  func test_contentContainerView() {
    // given: a scroll view
    let scrollView = ScrollView()

    // then: the content container is the document view on AppKit, and the scroll view itself on UIKit
    #if canImport(AppKit)
    expect(scrollView.documentView) === scrollView.contentContainerView
    #endif
    #if canImport(UIKit)
    expect(scrollView.contentContainerView) === scrollView
    #endif
  }

  // MARK: - Scroll Enabled

  #if canImport(AppKit)
  func test_isScrollEnabled_scrollWheel() throws {
    // given: a scroll view showing content taller than it, inside a view that records the scroll wheel events it gets
    let window = TestWindow()
    let container = ScrollWheelRecordingView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    window.contentView().addSubview(container)
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    scrollView.contentSize = CGSize(width: 100, height: 500)
    container.addSubview(scrollView)
    let cgEvent = try unwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: -30, wheel2: 0, wheel3: 0))
    let event = try unwrap(NSEvent(cgEvent: cgEvent))

    // when: scrolling is disabled, the scroll view gets a scroll wheel event, and the run loop turns, which is when
    // AppKit applies a scroll
    scrollView.isScrollEnabled = false
    scrollView.scrollWheel(with: event)
    wait(timeout: 0.1)

    // then: the event passes to the next responder, and the scroll view doesn't scroll
    expect(container.scrollWheelEventCount) == 1
    expect(scrollView.contentOffset) == .zero

    // when: scrolling is enabled and the scroll view gets the event again
    scrollView.isScrollEnabled = true
    scrollView.scrollWheel(with: event)

    // then: the scroll view scrolls instead of passing the event on
    expect(container.scrollWheelEventCount) == 1
    expect(scrollView.contentOffset).toEventuallyNot(beEqual(to: .zero))
  }
  #endif

  // MARK: - Scroll Routing

  #if canImport(AppKit)
  func test_scrollGesture_nested_outsideScrollableRange_comesBackIntoRange() throws {
    // given: a scroll view that scrolls from 0 to 200 along both axes, nested in a parent scroll view that can scroll in
    // every direction
    let window = TestWindow()
    let (parent, scrollView) = Self.makeNestedScrollViews(in: window)

    // when: the offset is past the bottom end, and a gesture scrolls further toward the bottom
    scrollView.contentOffset = CGPoint(x: 0, y: 300)
    try Self.sendScrollGesture(to: scrollView, deltaY: -10)

    // then: the scroll view handles the gesture instead of the parent, and AppKit brings the offset back to the end
    expect(parent.scrollWheelEventCount) == 0
    expect(scrollView.contentOffset).toEventually(beEqual(to: CGPoint(x: 0, y: 200)))

    // when: the offset is before the top end, and a gesture scrolls further toward the top
    scrollView.contentOffset = CGPoint(x: 0, y: -100)
    try Self.sendScrollGesture(to: scrollView, deltaY: 10)

    // then: the scroll view handles the gesture, and AppKit brings the offset back to the start
    expect(parent.scrollWheelEventCount) == 0
    expect(scrollView.contentOffset).toEventually(beEqual(to: .zero))

    // when: the offset is past the right end, and a gesture scrolls further toward the right
    scrollView.contentOffset = CGPoint(x: 300, y: 0)
    try Self.sendScrollGesture(to: scrollView, deltaX: -10)

    // then: the scroll view handles the gesture, and AppKit brings the offset back to the end
    expect(parent.scrollWheelEventCount) == 0
    expect(scrollView.contentOffset).toEventually(beEqual(to: CGPoint(x: 200, y: 0)))

    // when: the offset is before the left end, and a gesture scrolls further toward the left
    scrollView.contentOffset = CGPoint(x: -100, y: 0)
    try Self.sendScrollGesture(to: scrollView, deltaX: 10)

    // then: the scroll view handles the gesture, and AppKit brings the offset back to the start
    expect(parent.scrollWheelEventCount) == 0
    expect(scrollView.contentOffset).toEventually(beEqual(to: .zero))
  }

  func test_scrollGesture_nested_atTheEnd_passesToTheParent() throws {
    // given: a scroll view at the bottom end of its range, nested in a parent scroll view that can scroll in every
    // direction
    let window = TestWindow()
    let (parent, scrollView) = Self.makeNestedScrollViews(in: window)
    scrollView.contentOffset = CGPoint(x: 0, y: 200)

    // when: a gesture scrolls toward the bottom
    try Self.sendScrollGesture(to: scrollView, deltaY: -10)

    // then: the parent gets every event of the gesture, and the scroll view stays at the end
    expect(parent.scrollWheelEventCount) == 3
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 200)

    // when: a gesture scrolls toward the top, which the scroll view can scroll to
    try Self.sendScrollGesture(to: scrollView, deltaY: 10)

    // then: the scroll view handles the gesture instead of the parent
    expect(parent.scrollWheelEventCount) == 3
  }

  func test_scrollGesture_nested_withinAPixelOfAnEnd_passesToTheParent() throws {
    for restingDistance in [CGFloat(0.3), -0.3] {
      // given: a 99.2 × 99.2 scroll view nested in a parent scroll view that can scroll in every direction. AppKit aligns
      // where scrolling comes to rest to the window's pixels, so it rests a fraction of a pixel past or short of an end.
      let window = TestWindow()
      let (parent, scrollView) = Self.makeNestedScrollViews(in: window)
      scrollView.frame.size = CGSize(width: 99.2, height: 99.2)

      // when: the offset rests within a pixel of the bottom end, at any display scale, and a gesture scrolls toward the
      // bottom
      scrollView.setContentOffsetExactly(CGPoint(x: 0, y: scrollView.maxOffsetY + restingDistance))
      try Self.sendScrollGesture(to: scrollView, deltaY: -10)

      // then: the scroll view counts as at the end, and passes the gesture to the parent
      expect(parent.scrollWheelEventCount) == 3

      // when: the offset rests within a pixel of the top end, and a gesture scrolls toward the top
      scrollView.setContentOffsetExactly(CGPoint(x: 0, y: scrollView.minOffsetY - restingDistance))
      try Self.sendScrollGesture(to: scrollView, deltaY: 10)

      // then: the scroll view passes the gesture to the parent
      expect(parent.scrollWheelEventCount) == 6

      // when: the offset rests within a pixel of the right end, and a gesture scrolls toward the right
      scrollView.setContentOffsetExactly(CGPoint(x: scrollView.maxOffsetX + restingDistance, y: 0))
      try Self.sendScrollGesture(to: scrollView, deltaX: -10)

      // then: the scroll view passes the gesture to the parent
      expect(parent.scrollWheelEventCount) == 9

      // when: the offset rests within a pixel of the left end, and a gesture scrolls toward the left
      scrollView.setContentOffsetExactly(CGPoint(x: scrollView.minOffsetX - restingDistance, y: 0))
      try Self.sendScrollGesture(to: scrollView, deltaX: 10)

      // then: the scroll view passes the gesture to the parent
      expect(parent.scrollWheelEventCount) == 12
    }
  }

  func test_scrollGesture_nested_nonUniformlyScaledBounds_usesEachAxisPixel() throws {
    // given: a scroll view showing 300 × 1000 content, with its bounds scaled 4 times along x and a quarter along y, so
    // that a pixel covers at most 0.25 points of content along x and at least 2 along y, at 1x or 2x, nested in a parent
    // scroll view that can scroll in every direction
    let window = TestWindow()
    let (parent, scrollView) = Self.makeNestedScrollViews(in: window)
    scrollView.contentSize = CGSize(width: 300, height: 1000)
    scrollView.scaleUnitSquare(to: NSSize(width: 4, height: 0.25))
    scrollView.tile()

    // when: the offset rests 1.5 points past the bottom end, within a pixel along y, and a gesture scrolls toward the
    // bottom
    scrollView.setContentOffsetExactly(CGPoint(x: 0, y: scrollView.maxOffsetY + 1.5))
    try Self.sendScrollGesture(to: scrollView, deltaY: -10)

    // then: the offset counts as inside the scrollable range, so the scroll view passes the gesture to the parent
    expect(parent.scrollWheelEventCount) == 3

    // when: the offset rests 0.3 points past the right end, more than a pixel along x, and a gesture scrolls toward the
    // right
    scrollView.setContentOffsetExactly(CGPoint(x: scrollView.maxOffsetX + 0.3, y: 0))
    try Self.sendScrollGesture(to: scrollView, deltaX: -10)

    // then: the offset counts as outside the scrollable range, so the scroll view handles the gesture instead of the
    // parent
    expect(parent.scrollWheelEventCount) == 3
  }

  func test_scrollGesture_nested_contentSmallerThanTheScrollView_passesToTheParent() throws {
    // given: a scroll view showing content smaller than it, nested in a parent scroll view that can scroll in every
    // direction
    let window = TestWindow()
    let (parent, scrollView) = Self.makeNestedScrollViews(in: window)
    scrollView.contentSize = CGSize(width: 50, height: 50)

    // when: a gesture scrolls toward the bottom
    try Self.sendScrollGesture(to: scrollView, deltaY: -10)

    // then: the maximum offset is below the minimum, and the offset at the minimum is within the scrollable range, so
    // the parent gets the gesture
    expect(scrollView.maxOffsetY) < scrollView.minOffsetY
    expect(scrollView.contentOffset) == .zero
    expect(parent.scrollWheelEventCount) == 3
  }
  #endif

  // MARK: - Scroll Elasticity

  #if canImport(AppKit)
  func test_scrollElasticity() {
    // given: a 100 × 100 scroll view whose document is half a point larger than it in both axes
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100.5, height: 100.5)

    // when: the scroll elasticity updates
    scrollView.invalidateScrollElasticity()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    // then: the document overflows, so the scroll view bounces in both axes
    expect(scrollView.horizontalScrollElasticity) == .allowed
    expect(scrollView.verticalScrollElasticity) == .allowed

    // when: the document shrinks to the scroll view's size
    scrollView.contentSize = CGSize(width: 100, height: 100)
    scrollView.invalidateScrollElasticity()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    // then: the document fits, so the scroll view doesn't bounce
    expect(scrollView.horizontalScrollElasticity) == .none
    expect(scrollView.verticalScrollElasticity) == .none

    // when: the scroll view always bounces
    scrollView.alwaysBounceHorizontal = true
    scrollView.alwaysBounceVertical = true
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    // then: the scroll view bounces in both axes even though the document fits
    expect(scrollView.horizontalScrollElasticity) == .allowed
    expect(scrollView.verticalScrollElasticity) == .allowed
  }

  func test_scrollElasticity_documentLargerByFloatingPointNoise() {
    // given: a 100 × 100 scroll view whose document is larger than it by floating-point noise in both axes
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: CGFloat(100).nextUp, height: CGFloat(100).nextUp)

    // when: the scroll elasticity updates
    scrollView.invalidateScrollElasticity()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    // then: the document fits, so the scroll view doesn't bounce
    expect(scrollView.horizontalScrollElasticity) == .none
    expect(scrollView.verticalScrollElasticity) == .none
  }

  func test_scrollElasticity_fractionalSize_documentAsLargeAsTheView() {
    // given: a 99.2 × 99.2 scroll view, whose clip view AppKit rounds down to 99 pt, showing a document as large as the
    // scroll view
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 99.2, height: 99.2))
    scrollView.contentSize = CGSize(width: 99.2, height: 99.2)

    // when: the scroll elasticity updates
    scrollView.invalidateScrollElasticity()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    // then: the document fits the exact visible size, so the scroll view doesn't bounce, even though the document is
    // larger than the clip view
    expect(scrollView.contentView.bounds.size) == CGSize(width: 99, height: 99)
    expect(scrollView.horizontalScrollElasticity) == .none
    expect(scrollView.verticalScrollElasticity) == .none
  }

  func test_scrollElasticity_contentInsets_bouncesAlongAnAxisTheInsetsMakeRoomAlong() {
    // given: a 100 × 100 scroll view showing a document as large as it, with 20 pt content insets on the left and right
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.automaticallyAdjustsContentInsets = false
    scrollView.contentInset = EdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
    scrollView.contentSize = CGSize(width: 100, height: 100)

    // when: the scroll elasticity updates
    scrollView.invalidateScrollElasticity()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    // then: the insets make room to scroll horizontally, so the scroll view bounces horizontally, while the document
    // fits vertically, so it doesn't bounce vertically
    expect(scrollView.horizontalScrollElasticity) == .allowed
    expect(scrollView.verticalScrollElasticity) == .none
  }
  #endif

  // MARK: - Scroll Wheel

  #if canImport(AppKit)
  func test_scrollWheel_sideways_documentAsWideAsTheView_doesNotMoveIt() throws {
    // given: a 99.2 × 99.2 scroll view in a window, a tenth of a point off the window's pixels, showing a document as
    // wide as the scroll view and taller. AppKit moves the clip view onto whole pixels and rounds its width down, so the
    // document is a fraction of a point wider than the clip view, and AppKit rests the document at the offset the
    // rounding moved the clip view.
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0.1, y: 0, width: 99.2, height: 99.2))
    scrollView.contentSize = CGSize(width: 99.2, height: 400)
    window.contentView().addSubview(scrollView)
    window.layoutIfNeeded()
    let restingOffsetX = scrollView.contentView.frame.minX
    expect(restingOffsetX) != 0
    expect(scrollView.contentView.bounds.width) < 99.2

    // when: the scroll view gets a mouse wheel event toward the right, and the run loop turns, which is when AppKit
    // applies a scroll
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaX: -10))
    wait(timeout: 0.1)

    // then: the document fits the exact visible width, so it stays where it rests
    expect(scrollView.contentOffset.x) == restingOffsetX

    // when: the scroll view gets a mouse wheel event toward the left
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaX: 10))
    wait(timeout: 0.1)

    // then: the document stays where it rests
    expect(scrollView.contentOffset.x) == restingOffsetX

    // when: the scroll view gets a trackpad swipe toward the right
    try beginTrackpadSwipe(on: scrollView, deltaX: -10)
    try endTrackpadSwipe(on: scrollView)

    // then: the document stays where it rests
    expect(scrollView.contentOffset.x) == restingOffsetX

    // when: the scroll view always bounces horizontally, and gets a mouse wheel event toward the right
    scrollView.alwaysBounceHorizontal = true
    wait(timeout: 0.01)
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaX: -10))
    wait(timeout: 0.1)

    // then: a mouse wheel event can't spring back, so the document still stays where it rests
    expect(scrollView.contentOffset.x) == restingOffsetX

    // when: the scroll view gets a trackpad swipe toward the right, still in progress
    try beginTrackpadSwipe(on: scrollView, deltaX: -10)

    // then: a trackpad swipe keeps its delta along an axis that bounces, so the document stretches past where it rests
    expect(scrollView.contentOffset.x) > restingOffsetX
  }

  func test_scrollWheel_vertical_documentAsTallAsTheView_doesNotMoveIt() throws {
    // given: a 99.2 × 99.2 scroll view in a window, showing a document as tall as the scroll view and wider. AppKit moves
    // the clip view onto whole pixels, a fraction below the scroll view's top, rounds its height down, and rests the
    // document at the offset the rounding moved the clip view.
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 99.2, height: 99.2))
    scrollView.contentSize = CGSize(width: 400, height: 99.2)
    window.contentView().addSubview(scrollView)
    window.layoutIfNeeded()
    let restingOffsetY = scrollView.contentView.frame.minY
    expect(restingOffsetY) != 0

    // when: the scroll view gets a mouse wheel event toward the top, and the run loop turns
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaY: 10))
    wait(timeout: 0.1)

    // then: the document fits the exact visible height, so it stays where it rests
    expect(scrollView.contentOffset.y) == restingOffsetY

    // when: the scroll view gets a mouse wheel event toward the bottom
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaY: -10))
    wait(timeout: 0.1)

    // then: the document stays where it rests
    expect(scrollView.contentOffset.y) == restingOffsetY

    // when: the scroll view gets a trackpad swipe toward the top
    try beginTrackpadSwipe(on: scrollView, deltaY: 10)
    try endTrackpadSwipe(on: scrollView)

    // then: the document stays where it rests
    expect(scrollView.contentOffset.y) == restingOffsetY
  }

  func test_scrollWheel_sideways_contentInsets_scrollsThroughTheInsets() throws {
    // given: a 100 × 100 scroll view in a window, on the window's pixels, showing a document as wide as the scroll view
    // and taller, with 20 pt content insets on the left and right, scrolled to the start of the left inset
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.automaticallyAdjustsContentInsets = false
    scrollView.contentInset = EdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
    scrollView.contentSize = CGSize(width: 100, height: 400)
    window.contentView().addSubview(scrollView)
    window.layoutIfNeeded()
    scrollView.contentOffset = CGPoint(x: -20, y: 0)

    // when: the scroll view gets a mouse wheel event toward the right, and the run loop turns
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaX: -10))
    wait(timeout: 0.1)

    // then: the insets make room to scroll even though the document fits, so the document moves by the event's 10 pt
    expect(scrollView.contentOffset.x) == -10

    // when: the scroll view gets a long trackpad swipe toward the right, still in progress
    try beginTrackpadSwipe(on: scrollView, deltaX: -30)

    // then: the axis has room to scroll, so it bounces, and the document stretches past the end of the right inset
    expect(scrollView.contentOffset.x) > 20

    // when: the swipe ends
    try endTrackpadSwipe(on: scrollView)

    // then: the document springs back to the end of the right inset
    expect(scrollView.contentOffset.x).toEventually(beApproximatelyEqual(to: 20, within: 1e-9))
  }

  func test_scrollWheel_vertical_contentInsets_scrollsThroughTheInsets() throws {
    // given: a 100 × 100 scroll view in a window, on the window's pixels, showing a document as tall as the scroll view
    // and wider, with 20 pt content insets on the top and bottom, scrolled to the start of the top inset
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.automaticallyAdjustsContentInsets = false
    scrollView.contentInset = EdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
    scrollView.contentSize = CGSize(width: 400, height: 100)
    window.contentView().addSubview(scrollView)
    window.layoutIfNeeded()
    scrollView.contentOffset = CGPoint(x: 0, y: -20)

    // when: the scroll view gets a mouse wheel event toward the bottom, and the run loop turns
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaY: -10))
    wait(timeout: 0.1)

    // then: the insets make room to scroll even though the document fits, so the document moves by the event's 10 pt
    expect(scrollView.contentOffset.y) == -10

    // when: the scroll view gets a long trackpad swipe toward the bottom, still in progress
    try beginTrackpadSwipe(on: scrollView, deltaY: -30)

    // then: the axis has room to scroll, so it bounces, and the document stretches past the end of the bottom inset
    expect(scrollView.contentOffset.y) > 20

    // when: the swipe ends
    try endTrackpadSwipe(on: scrollView)

    // then: the document springs back to the end of the bottom inset
    expect(scrollView.contentOffset.y).toEventually(beApproximatelyEqual(to: 20, within: 1e-9))
  }

  func test_scrollWheel_sideways_offsetOutsideTheRange_bringsItBack() throws {
    // given: a 100 × 100 scroll view in a window, showing a document as wide as the scroll view and taller, scrolled in
    // code 50 pt past the end of its horizontal range
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 400)
    window.contentView().addSubview(scrollView)
    window.layoutIfNeeded()
    scrollView.contentOffset = CGPoint(x: 50, y: 0)

    // when: the scroll view gets a mouse wheel event toward the left, and the run loop turns
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaX: 10))
    wait(timeout: 0.1)

    // then: the offset is outside the range, so the event keeps its delta, and AppKit brings the document back
    expect(scrollView.contentOffset.x) == 0

    // when: the scroll view is scrolled in code 50 pt before the start of its horizontal range, and gets the same mouse
    // wheel event, which now points away from the range
    scrollView.contentOffset = CGPoint(x: -50, y: 0)
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaX: 10))
    wait(timeout: 0.1)

    // then: AppKit brings the document back from that side too
    expect(scrollView.contentOffset.x) == 0
  }

  func test_scrollWheel_vertical_offsetOutsideTheRange_bringsItBack() throws {
    // given: a 100 × 100 scroll view in a window, showing a document as tall as the scroll view and wider, scrolled in
    // code 50 pt past the end of its vertical range
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 400, height: 100)
    window.contentView().addSubview(scrollView)
    window.layoutIfNeeded()
    scrollView.contentOffset = CGPoint(x: 0, y: 50)

    // when: the scroll view gets a mouse wheel event toward the top, and the run loop turns
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaY: 10))
    wait(timeout: 0.1)

    // then: the offset is outside the range, so the event keeps its delta, and AppKit brings the document back
    expect(scrollView.contentOffset.y) == 0

    // when: the scroll view is scrolled in code 50 pt before the start of its vertical range, and gets the same mouse
    // wheel event, which now points away from the range
    scrollView.contentOffset = CGPoint(x: 0, y: -50)
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaY: 10))
    wait(timeout: 0.1)

    // then: AppKit brings the document back from that side too
    expect(scrollView.contentOffset.y) == 0
  }
  #endif

  // MARK: - Helpers

  /// The insets as `[top, left, bottom, right]`, since `NSEdgeInsets` isn't `Equatable`.
  private static func components(of insets: EdgeInsets) -> [CGFloat] {
    [insets.top, insets.left, insets.bottom, insets.right]
  }

  #if canImport(AppKit)
  /// Makes a 100 × 100 scroll view showing 300 × 300 content, so it scrolls from 0 to 200 along both axes, nested in
  /// a 200 × 200 parent scroll view scrolled to the middle of its 1000 × 1000 content.
  private static func makeNestedScrollViews(in window: TestWindow) -> (parent: ScrollWheelRecordingScrollView, scrollView: ScrollView) {
    let parent = ScrollWheelRecordingScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    parent.contentSize = CGSize(width: 1000, height: 1000)
    parent.contentOffset = CGPoint(x: 400, y: 400)
    window.contentView().addSubview(parent)

    let scrollView = ScrollView(frame: CGRect(x: 400, y: 400, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 300, height: 300)
    parent.documentView?.addSubview(scrollView)
    return (parent, scrollView)
  }

  /// Sends the events of a trackpad scroll gesture to the scroll view: one that begins and one that changes, both with
  /// the deltas, then one that ends.
  private static func sendScrollGesture(to scrollView: ScrollView, deltaX: Int32 = 0, deltaY: Int32 = 0) throws {
    for phase in [CGScrollPhase.began, .changed, .ended] {
      let isEnded = phase == .ended
      let cgEvent = try unwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: isEnded ? 0 : deltaY, wheel2: isEnded ? 0 : deltaX, wheel3: 0))
      cgEvent.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(phase.rawValue))
      try scrollView.scrollWheel(with: unwrap(NSEvent(cgEvent: cgEvent)))
    }
  }

  /// Makes a mouse wheel event, which has no phase, scrolling by the deltas in pixels.
  private static func makeMouseWheelEvent(deltaX: Int32 = 0, deltaY: Int32 = 0) throws -> NSEvent {
    let cgEvent = try unwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0))
    return try unwrap(NSEvent(cgEvent: cgEvent))
  }

  /// Sends the start of a trackpad swipe to the scroll view: an event that begins and two that change, all with the
  /// deltas, turning the run loop after each, since AppKit applies a swipe as the run loop turns.
  private func beginTrackpadSwipe(on scrollView: ScrollView, deltaX: Int32 = 0, deltaY: Int32 = 0) throws {
    for phase in [CGScrollPhase.began, .changed, .changed] {
      let cgEvent = try unwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0))
      cgEvent.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(phase.rawValue))
      try scrollView.scrollWheel(with: unwrap(NSEvent(cgEvent: cgEvent)))
      wait(timeout: 0.02)
    }
  }

  /// Sends the end of a trackpad swipe to the scroll view, and turns the run loop.
  private func endTrackpadSwipe(on scrollView: ScrollView) throws {
    let cgEvent = try unwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: 0, wheel3: 0))
    cgEvent.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(CGScrollPhase.ended.rawValue))
    try scrollView.scrollWheel(with: unwrap(NSEvent(cgEvent: cgEvent)))
    wait(timeout: 0.1)
  }
  #endif
}

#if canImport(AppKit)
private final class ScrollWheelRecordingView: NSView {

  private(set) var scrollWheelEventCount = 0

  override func scrollWheel(with event: NSEvent) {
    scrollWheelEventCount += 1
  }
}

private final class ScrollWheelRecordingScrollView: ScrollView {

  private(set) var scrollWheelEventCount = 0

  override func scrollWheel(with event: NSEvent) {
    scrollWheelEventCount += 1
  }
}
#endif

#if canImport(UIKit)
private final class ZoomingDelegate: NSObject, UIScrollViewDelegate {

  private let zoomingView: UIView

  init(zoomingView: UIView) {
    self.zoomingView = zoomingView
  }

  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    zoomingView
  }
}
#endif
