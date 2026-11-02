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

    // then: the offset comes back to the end of the scrollable range
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

  func test_contentInset_keepsAContentOffsetInsideTheNewRange() {
    // given: a 100 × 200 scroll view without automatic inset adjustments, showing 100 × 500 content, scrolled to 30 pt
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    #if canImport(AppKit)
    scrollView.automaticallyAdjustsContentInsets = false
    #endif
    #if canImport(UIKit)
    scrollView.contentInsetAdjustmentBehavior = .never
    #endif
    scrollView.contentSize = CGSize(width: 100, height: 500)
    scrollView.contentOffset = CGPoint(x: 0, y: 30)

    // when: a 50 pt top inset is set
    scrollView.contentInset = EdgeInsets(top: 50, left: 0, bottom: 0, right: 0)

    // then: the inset only adds scroll space above the content, so the offset stays, as on UIKit
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 30)

    // when: the view scrolls to the top of the inset, and the insets grow at the top and the left
    scrollView.contentOffset = CGPoint(x: 0, y: -50)
    scrollView.contentInset = EdgeInsets(top: 80, left: 20, bottom: 0, right: 0)

    // then: the offset stays at the old top of the inset
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: -50)

    // when: the top inset shrinks to where the view is scrolled, and the left inset goes away
    scrollView.contentInset = EdgeInsets(top: 50, left: 0, bottom: 0, right: 0)

    // then: the offset is at the top of the new range, so it stays
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: -50)
  }

  func test_contentInset_clampsAContentOffsetOutsideTheNewRange() {
    // given: a 100 × 200 scroll view without automatic inset adjustments, showing 100 × 500 content, with an 80 pt top
    // inset, scrolled 50 pt into it
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    #if canImport(AppKit)
    scrollView.automaticallyAdjustsContentInsets = false
    #endif
    #if canImport(UIKit)
    scrollView.contentInsetAdjustmentBehavior = .never
    #endif
    scrollView.contentSize = CGSize(width: 100, height: 500)
    scrollView.contentInset = EdgeInsets(top: 80, left: 0, bottom: 0, right: 0)
    scrollView.contentOffset = CGPoint(x: 0, y: -50)

    // when: the inset is removed
    scrollView.contentInset = EdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

    // then: the offset is above the new range, so it moves to the top of the content, as on UIKit
    expect(scrollView.contentOffset) == .zero

    // when: a 30 pt bottom inset is set, the view scrolls to its end, and the inset shrinks to 10 pt
    scrollView.contentInset = EdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
    scrollView.contentOffset = CGPoint(x: 0, y: 330)
    scrollView.contentInset = EdgeInsets(top: 0, left: 0, bottom: 10, right: 0)

    // then: the offset is past the new end, so it moves to the end
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 310)

    // when: a 20 pt left inset is set, the view scrolls to its left edge and to 100 pt, and the left inset is removed
    scrollView.contentInset = EdgeInsets(top: 0, left: 20, bottom: 10, right: 0)
    scrollView.contentOffset = CGPoint(x: -20, y: 100)
    scrollView.contentInset = EdgeInsets(top: 0, left: 0, bottom: 10, right: 0)

    // then: only the horizontal offset is outside the new range, so only it moves
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 100)

    // when: the view is scrolled in code 50 pt above its range, and gets the insets it already has
    scrollView.contentOffset = CGPoint(x: 0, y: -50)
    scrollView.contentInset = EdgeInsets(top: 0, left: 0, bottom: 10, right: 0)

    // then: the insets don't change, so the offset stays outside the range
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: -50)

    // when: the bottom inset changes
    scrollView.contentInset = EdgeInsets(top: 0, left: 0, bottom: 20, right: 0)

    // then: the new insets bring the offset into the range, even though it was outside it before
    expect(scrollView.contentOffset) == .zero
  }

  #if canImport(AppKit)
  func test_contentInset_insetShrinkingByLessThanAPixel_clampsTheOffsetToTheNewEdge() {
    // given: a 100 × 200 scroll view in a window, without automatic inset adjustments, showing 100 × 500 content, with a
    // 10 pt top inset, scrolled to its top
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    scrollView.automaticallyAdjustsContentInsets = false
    scrollView.contentSize = CGSize(width: 100, height: 500)
    window.contentView().addSubview(scrollView)
    scrollView.contentInset = EdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
    scrollView.contentOffset = CGPoint(x: 0, y: -10)

    // when: the top inset shrinks by half a point, at most a pixel
    scrollView.contentInset = EdgeInsets(top: 9.5, left: 0, bottom: 0, right: 0)

    // then: the offset moves to the new top of the range, as on UIKit, even though it was at most a pixel outside it
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: -9.5)
  }

  func test_contentInsets_movesTheContentOffsetByTheChange() {
    // given: a 100 × 200 scroll view without automatic inset adjustments, showing 100 × 500 content, scrolled to 30 pt
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    scrollView.automaticallyAdjustsContentInsets = false
    scrollView.contentSize = CGSize(width: 100, height: 500)
    scrollView.contentOffset = CGPoint(x: 0, y: 30)

    // when: AppKit's `contentInsets` gets a 50 pt top inset
    scrollView.contentInsets = NSEdgeInsets(top: 50, left: 0, bottom: 0, right: 0)

    // then: AppKit moves the offset by the change, keeping the content where it was relative to the insets, unlike
    // `contentInset`
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: -20)
  }

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

  func test_adjustedContentInset_legacyScrollBars_includesTheThicknessOfTheOnesOverTheContent() {
    // given: a 120 × 200 scroll view with legacy scroll bars and a 20 pt top inset, showing content that overflows only
    // vertically, with a vertical scroll bar
    let thickness = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 120, height: 200))
    scrollView.automaticallyAdjustsContentInsets = false
    scrollView.scrollerStyle = .legacy
    scrollView.hasVerticalScroller = true
    scrollView.contentSize = CGSize(width: 100, height: 300)
    scrollView.contentInset = EdgeInsets(top: 20, left: 0, bottom: 0, right: 0)

    // then: the scroll bar takes its width from the visible area, so the insets in effect are the set insets
    expect(scrollView.visibleSize) == CGSize(width: 120 - thickness, height: 200)
    expect(Self.components(of: scrollView.adjustedContentInset)) == [20, 0, 0, 0]

    // when: the content overflows both axes, with both scroll bars
    scrollView.hasHorizontalScroller = true
    scrollView.contentSize = CGSize(width: 300, height: 300)

    // then: both scroll bars show over the full visible area, the insets in effect add their thickness, and the
    // scrollable range ends where AppKit stops scrolling
    expect(scrollView.visibleSize) == CGSize(width: 120, height: 200)
    expect(Self.components(of: scrollView.adjustedContentInset)) == [20, 0, thickness, thickness]
    let clipView = scrollView.contentView
    let end = clipView.constrainBoundsRect(CGRect(origin: CGPoint(x: 1000, y: 1000), size: clipView.bounds.size)).origin
    expect(end) == CGPoint(x: 300 - 120 + thickness, y: 300 - 200 + thickness)
    expect(CGPoint(x: scrollView.maxOffsetX, y: scrollView.maxOffsetY)) == end
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

  func test_scrollGesture_nested_parentMovesTheScrollViewUnderThePointer_staysWithTheParent() throws {
    // given: a scroll view nested in a parent scroll view that scrolls, beside the parent's own content
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)

    // when: a gesture toward the bottom begins over the parent's own content
    try views.parentContent.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: Constants.scrollInterval))
    try views.parentContent.scrollWheel(with: Self.makeScrollEvent(phase: .changed, deltaY: -10, after: Constants.eventInterval))

    // then: the parent handles it
    expect(views.parent.scrollWheelEventCount) == 2
    expect(views.container.scrollWheelEventCount) == 0

    // when: the parent's scrolling moves the scroll view under the pointer, so AppKit sends the rest of the gesture and
    // its glide to the scroll view
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .changed, deltaY: -10, after: Constants.eventInterval))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .ended, after: Constants.eventInterval))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(momentumPhase: .begin, deltaY: -10, after: Constants.eventInterval))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(momentumPhase: .continuous, deltaY: -10, after: Constants.eventInterval))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(momentumPhase: .end, after: Constants.eventInterval))

    // then: the scroll view passes every event to the parent, which handles them, even though the scroll view can
    // scroll toward the bottom
    expect(views.scrollView.canScrollToBottom) == true
    expect(views.parent.scrollWheelEventCount) == 7
    expect(views.container.scrollWheelEventCount) == 0
  }

  func test_scrollGesture_nested_parentMovesTheScrollViewUnderThePointer_scrollsOnlyTheParent() throws {
    // given: a scroll view nested in a parent scroll view that scrolls, beside the parent's own content
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)

    // when: a swipe toward the bottom begins over the parent's own content and continues over the scroll view, turning
    // the run loop after each event, since AppKit applies a swipe as the run loop turns
    try views.parentContent.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: Constants.scrollInterval))
    wait(timeout: 0.02)
    for _ in 0 ..< 3 {
      try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .changed, deltaY: -10, after: Constants.eventInterval))
      wait(timeout: 0.02)
    }

    // then: the parent scrolls toward the bottom, and the scroll view stays
    expect(views.parent.contentOffset.y) > 400
    expect(views.scrollView.contentOffset) == .zero
  }

  func test_scrollGesture_nested_gestureDuringTheParentsGlide_continuesTheParentsScroll() throws {
    // given: a scroll view nested in a parent scroll view that scrolls, and a flick toward the bottom that the parent
    // took over its own content
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    try Self.sendFlick(to: views.parentContent, deltaY: -10)
    expect(views.parent.scrollWheelEventCount) == 6

    // when: a touch ends the glide, and its swipe toward the bottom begins over the scroll view 74 ms after the glide's
    // end, the longest gap a trackpad sent
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: 0.074))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .changed, deltaY: -10, after: Constants.eventInterval))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .ended, after: Constants.eventInterval))

    // then: the swipe continues the parent's scroll, so the parent handles it instead of the scroll view
    expect(views.parent.scrollWheelEventCount) == 9
    expect(views.container.scrollWheelEventCount) == 0

    // when: a swipe toward the top begins over the scroll view 42 ms after the latest swipe's end
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: 10, after: 0.042))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .changed, deltaY: 10, after: Constants.eventInterval))

    // then: a swipe the other way continues the parent's scroll too
    expect(views.parent.scrollWheelEventCount) == 11
    expect(views.container.scrollWheelEventCount) == 0
  }

  func test_scrollGesture_nested_restingFingersDuringTheParentsGlide_goToTheParent() throws {
    // given: a scroll view nested in a parent scroll view that scrolls, and a flick that the parent took
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    try Self.sendFlick(to: views.parentContent, deltaY: -10)

    // when: fingers rest on the trackpad over the scroll view, which ends the glide and starts a gesture 68 ms after the
    // glide's end, and they lift without moving
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .mayBegin, after: 0.068))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .cancelled, after: 1))

    // then: the parent gets both events, as the scroll view that the fingers stopped
    expect(views.parent.scrollWheelEventCount) == 8
    expect(views.container.scrollWheelEventCount) == 0

    // when: another flick that the parent took, then fingers rest during its glide, and move toward the bottom half a
    // second later
    try Self.sendFlick(to: views.parentContent, deltaY: -10)
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .mayBegin, after: 0.068))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: 0.5))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .changed, deltaY: -10, after: Constants.eventInterval))

    // then: the gesture of the resting fingers continues the parent's scroll, however late it moves
    expect(views.parent.scrollWheelEventCount) == 17
    expect(views.container.scrollWheelEventCount) == 0
  }

  func test_scrollGesture_nested_gestureAfterRestingFingersLift_startsAScrollOfItsOwn() throws {
    // AppKit ends the gesture of resting fingers that lift without moving with a `cancelled` event or an `ended` one
    for liftPhase in [CGScrollPhase.cancelled, .ended] {
      // given: a scroll view nested in a parent scroll view that scrolls, a flick that the parent took over its own
      // content, and fingers that rest on the trackpad over the scroll view 68 ms after the glide's end
      let window = TestWindow()
      let views = Self.makeScrollingNestedScrollViews(in: window)
      try Self.sendFlick(to: views.parentContent, deltaY: -10)
      try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .mayBegin, after: 0.068))
      expect(views.parent.scrollWheelEventCount) == 7

      // when: the fingers lift without moving, and a swipe toward the bottom begins over the scroll view 50 ms later
      try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: liftPhase, after: 0.5))
      try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: 0.05))
      try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .changed, deltaY: -10, after: Constants.eventInterval))

      // then: the parent gets the lift, which ends its scroll, so the swipe starts a scroll of its own, which the scroll
      // view takes, since it can scroll toward the bottom
      expect(views.parent.scrollWheelEventCount) == 8
      expect(views.container.scrollWheelEventCount) == 0
    }
  }

  func test_scrollGesture_nested_restingFingersLiftOverAnotherScrollView_endTheParentsScroll() throws {
    // a scroll view whose scrolling is disabled passes the events on before routing them
    for isOtherScrollViewScrollEnabled in [true, false] {
      // given: a scroll view nested in a parent scroll view that scrolls, another scroll view beside the parent, a
      // flick that the parent took over its own content, and fingers that rest on the trackpad over the nested scroll
      // view 68 ms after the glide's end
      let window = TestWindow()
      let views = Self.makeScrollingNestedScrollViews(in: window)
      let otherScrollView = ScrollView(frame: CGRect(x: 200, y: 0, width: 100, height: 100))
      otherScrollView.contentSize = CGSize(width: 100, height: 500)
      otherScrollView.isScrollEnabled = isOtherScrollViewScrollEnabled
      views.container.addSubview(otherScrollView)
      try Self.sendFlick(to: views.parentContent, deltaY: -10)
      try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .mayBegin, after: 0.068))
      expect(views.parent.scrollWheelEventCount) == 7

      // when: the pointer moves over the other scroll view, for example with a mouse, so AppKit sends the fingers' lift
      // there, and a swipe toward the bottom begins over the nested scroll view a second later
      try otherScrollView.scrollWheel(with: Self.makeScrollEvent(phase: .cancelled, after: 0.5))
      try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: Constants.scrollInterval))
      try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .changed, deltaY: -10, after: Constants.eventInterval))

      // then: the other scroll view passes the lift on, which still ends the parent's scroll, so the swipe starts a
      // scroll of its own, which the nested scroll view takes
      expect(views.container.scrollWheelEventCount) == 1
      expect(views.parent.scrollWheelEventCount) == 7
    }
  }

  func test_scrollGesture_nested_gestureAfterTheParentsScroll_startsAScrollOfItsOwn() throws {
    // given: a scroll view nested in a parent scroll view that scrolls, and a swipe that the parent took over its own
    // content
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    try Self.sendScrollGesture(to: views.parentContent, deltaY: -10)
    expect(views.parent.scrollWheelEventCount) == 3

    // when: a swipe toward the bottom begins over the scroll view 99 ms after the latest swipe's end
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: 0.099))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .ended, after: Constants.eventInterval))

    // then: it continues the parent's scroll
    expect(views.parent.scrollWheelEventCount) == 5

    // when: a swipe toward the bottom begins over the scroll view 101 ms after the latest swipe's end
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: 0.101))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .changed, deltaY: -10, after: Constants.eventInterval))

    // then: the parent's scroll is over, so the swipe starts a scroll of its own, which the scroll view takes, since it
    // can scroll toward the bottom
    expect(views.parent.scrollWheelEventCount) == 5
    expect(views.container.scrollWheelEventCount) == 0
  }

  func test_scrollGesture_nested_restingFingersAtRest_goToTheScrollViewUnderThePointer() throws {
    // given: a scroll view at the bottom end of its range, nested in a parent scroll view that scrolls, and a swipe that
    // the parent took over its own content
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    views.scrollView.contentOffset = CGPoint(x: 0, y: 200)
    try Self.sendScrollGesture(to: views.parentContent, deltaY: -10)
    expect(views.parent.scrollWheelEventCount) == 3

    // when: a second later, fingers rest on the trackpad over the scroll view, and lift without moving
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .mayBegin, after: Constants.scrollInterval))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .cancelled, after: 1))

    // then: the scroll view under the pointer gets both events
    expect(views.parent.scrollWheelEventCount) == 3

    // when: fingers rest over the scroll view again, then move toward the bottom
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .mayBegin, after: Constants.scrollInterval))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: 0.5))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .changed, deltaY: -10, after: Constants.eventInterval))

    // then: resting fingers don't choose a scroll view, so the moving gesture does, and goes to the parent, since the
    // scroll view is at the end
    expect(views.parent.scrollWheelEventCount) == 5
    expect(views.container.scrollWheelEventCount) == 0
  }

  func test_scrollGesture_glideOverAnotherScrollView_isNotHandledByIt() throws {
    // given: two scroll views side by side in a container, showing content taller than them
    let window = TestWindow()
    let container = ScrollWheelRecordingView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    window.contentView().addSubview(container)
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 500)
    container.addSubview(scrollView)
    let otherScrollView = ScrollView(frame: CGRect(x: 100, y: 0, width: 100, height: 100))
    otherScrollView.contentSize = CGSize(width: 100, height: 500)
    container.addSubview(otherScrollView)

    // when: a flick toward the bottom begins over the scroll view, and the pointer moves over the other scroll view
    // during the glide
    try scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: Constants.scrollInterval))
    try scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .ended, after: Constants.eventInterval))
    try scrollView.scrollWheel(with: Self.makeScrollEvent(momentumPhase: .begin, deltaY: -10, after: Constants.eventInterval))
    try otherScrollView.scrollWheel(with: Self.makeScrollEvent(momentumPhase: .continuous, deltaY: -10, after: Constants.eventInterval))
    try otherScrollView.scrollWheel(with: Self.makeScrollEvent(momentumPhase: .end, after: Constants.eventInterval))

    // then: the glide belongs to the scroll view, so the other scroll view passes it on instead of handling it
    expect(container.scrollWheelEventCount) == 2

    // when: fingers rest on the trackpad over the other scroll view, then move toward the bottom
    try otherScrollView.scrollWheel(with: Self.makeScrollEvent(phase: .mayBegin, after: Constants.scrollInterval))
    try otherScrollView.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: 0.5))
    try otherScrollView.scrollWheel(with: Self.makeScrollEvent(phase: .changed, deltaY: -10, after: Constants.eventInterval))

    // then: the gesture starts a scroll of its own, which the other scroll view takes
    expect(container.scrollWheelEventCount) == 2
  }

  func test_scrollGesture_nested_latchedScrollViewRemoved_isNotHandledByTheParent() throws {
    // given: a scroll view nested in a parent scroll view that scrolls, and a swipe toward the bottom that the scroll
    // view took
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: Constants.scrollInterval))
    expect(views.parent.scrollWheelEventCount) == 0

    // when: the scroll view is removed during the swipe, so AppKit sends the rest of the swipe to the parent's content
    // under the pointer
    views.scrollView.removeFromSuperview()
    try views.parentContent.scrollWheel(with: Self.makeScrollEvent(phase: .changed, deltaY: -10, after: Constants.eventInterval))
    try views.parentContent.scrollWheel(with: Self.makeScrollEvent(phase: .ended, after: Constants.eventInterval))

    // then: the swipe belongs to the removed scroll view, so the parent passes it on instead of taking it over
    expect(views.parent.scrollWheelEventCount) == 2
    expect(views.container.scrollWheelEventCount) == 2
  }

  func test_scrollGesture_nested_latchedScrollViewDeallocated_isNotHandledByTheParent() throws {
    // given: a parent scroll view that scrolls, and a swipe toward the bottom that a scroll view nested in it took,
    // which only its superview retains
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    weak var latchedScrollView: ScrollView?
    try autoreleasepool {
      let scrollView = ScrollView(frame: CGRect(x: 400, y: 500, width: 100, height: 100))
      scrollView.contentSize = CGSize(width: 300, height: 300)
      views.parent.documentView?.addSubview(scrollView)
      try scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: Constants.scrollInterval))
      latchedScrollView = scrollView
    }
    expect(views.parent.scrollWheelEventCount) == 0

    // when: the scroll view is removed during the swipe and deallocated, so AppKit sends the rest of the swipe to the
    // parent's content under the pointer
    autoreleasepool {
      latchedScrollView?.removeFromSuperview()
    }
    expect(latchedScrollView).to(beNil())
    try views.parentContent.scrollWheel(with: Self.makeScrollEvent(phase: .changed, deltaY: -10, after: Constants.eventInterval))
    try views.parentContent.scrollWheel(with: Self.makeScrollEvent(phase: .ended, after: Constants.eventInterval))

    // then: the swipe still belongs to the deallocated scroll view, so the parent passes it on instead of taking it over
    expect(views.parent.scrollWheelEventCount) == 2
    expect(views.container.scrollWheelEventCount) == 2

    // when: a swipe toward the bottom begins over the parent's content 50 ms later
    try views.parentContent.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: 0.05))

    // then: it starts a scroll of its own, which the parent takes
    expect(views.parent.scrollWheelEventCount) == 3
    expect(views.container.scrollWheelEventCount) == 2
  }

  func test_scrollGesture_nested_parentDisabledDuringItsGlide_isNotHandledByTheScrollView() throws {
    // given: a scroll view nested in a parent scroll view that scrolls, and a swipe toward the bottom that the parent
    // took over its own content
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    try views.parentContent.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: Constants.scrollInterval))
    try views.parentContent.scrollWheel(with: Self.makeScrollEvent(phase: .ended, after: Constants.eventInterval))
    expect(views.parent.scrollWheelEventCount) == 2

    // when: the parent's scrolling is disabled, and its glide lands on the scroll view
    views.parent.isScrollEnabled = false
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(momentumPhase: .begin, deltaY: -10, after: Constants.eventInterval))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(momentumPhase: .end, after: Constants.eventInterval))

    // then: the scroll view doesn't take over the glide, but passes it to the parent, which passes it on
    expect(views.parent.scrollWheelEventCount) == 4
    expect(views.container.scrollWheelEventCount) == 2
  }

  func test_scrollGesture_nested_gestureAfterTheParentIsDisabled_startsAScrollOfItsOwn() throws {
    // given: a scroll view nested in a parent scroll view that scrolls, and a flick that the parent took over its own
    // content
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    try Self.sendFlick(to: views.parentContent, deltaY: -10)
    expect(views.parent.scrollWheelEventCount) == 6

    // when: the parent's scrolling is disabled, and a swipe toward the bottom begins over the scroll view 74 ms after
    // the glide's end
    views.parent.isScrollEnabled = false
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: 0.074))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .changed, deltaY: -10, after: Constants.eventInterval))

    // then: the parent can't continue its scroll, so the swipe starts a scroll of its own, which the scroll view takes
    expect(views.parent.scrollWheelEventCount) == 6
    expect(views.container.scrollWheelEventCount) == 0

    // when: the parent's scrolling is enabled, it takes another flick, fingers rest over the scroll view 68 ms after
    // the glide's end, the parent's scrolling is disabled, and the fingers move toward the bottom half a second later
    views.parent.isScrollEnabled = true
    try Self.sendFlick(to: views.parentContent, deltaY: -10)
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .mayBegin, after: 0.068))
    views.parent.isScrollEnabled = false
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: 0.5))
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .changed, deltaY: -10, after: Constants.eventInterval))

    // then: the gesture of the resting fingers can't continue the parent's scroll either, so the scroll view takes it
    expect(views.parent.scrollWheelEventCount) == 13
    expect(views.container.scrollWheelEventCount) == 0
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

    // then: the offset is outside the range, so the scroll view brings the document back
    expect(scrollView.contentOffset.x) == 0

    // when: the scroll view is scrolled in code 50 pt before the start of its horizontal range, and gets the same mouse
    // wheel event, which now points away from the range
    scrollView.contentOffset = CGPoint(x: -50, y: 0)
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaX: 10))
    wait(timeout: 0.1)

    // then: the scroll view brings the document back from that side too
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

    // then: the offset is outside the range, so the scroll view brings the document back
    expect(scrollView.contentOffset.y) == 0

    // when: the scroll view is scrolled in code 50 pt before the start of its vertical range, and gets the same mouse
    // wheel event, which now points away from the range
    scrollView.contentOffset = CGPoint(x: 0, y: -50)
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaY: 10))
    wait(timeout: 0.1)

    // then: the scroll view brings the document back from that side too
    expect(scrollView.contentOffset.y) == 0
  }

  func test_scrollGesture_sideways_offsetOutsideTheRange_bringsItBack() throws {
    // given: a 100 × 100 scroll view in a window, showing a document as wide as the scroll view and taller, scrolled in
    // code 50 pt past the end of its horizontal range
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 400)
    window.contentView().addSubview(scrollView)
    window.layoutIfNeeded()
    scrollView.contentOffset = CGPoint(x: 50, y: 0)

    // when: a trackpad swipe scrolls toward the left
    try beginTrackpadSwipe(on: scrollView, deltaX: 10)
    try endTrackpadSwipe(on: scrollView)

    // then: the offset is outside the range, so the swipe keeps its delta, and AppKit springs the document back
    expect(scrollView.contentOffset.x).toEventually(beApproximatelyEqual(to: 0, within: 1e-9))

    // when: the scroll view is scrolled in code 50 pt before the start of its horizontal range, and gets the same
    // trackpad swipe, which now points away from the range
    scrollView.contentOffset = CGPoint(x: -50, y: 0)
    try beginTrackpadSwipe(on: scrollView, deltaX: 10)
    try endTrackpadSwipe(on: scrollView)

    // then: AppKit springs the document back from that side too
    expect(scrollView.contentOffset.x).toEventually(beApproximatelyEqual(to: 0, within: 1e-9))
  }

  func test_scrollGesture_vertical_offsetOutsideTheRange_bringsItBack() throws {
    // given: a 100 × 100 scroll view in a window, showing a document as tall as the scroll view and wider, scrolled in
    // code 50 pt past the end of its vertical range
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 400, height: 100)
    window.contentView().addSubview(scrollView)
    window.layoutIfNeeded()
    scrollView.contentOffset = CGPoint(x: 0, y: 50)

    // when: a trackpad swipe scrolls toward the top
    try beginTrackpadSwipe(on: scrollView, deltaY: 10)
    try endTrackpadSwipe(on: scrollView)

    // then: the offset is outside the range, so the swipe keeps its delta, and AppKit springs the document back
    expect(scrollView.contentOffset.y).toEventually(beApproximatelyEqual(to: 0, within: 1e-9))

    // when: the scroll view is scrolled in code 50 pt before the start of its vertical range, and gets the same
    // trackpad swipe, which now points away from the range
    scrollView.contentOffset = CGPoint(x: 0, y: -50)
    try beginTrackpadSwipe(on: scrollView, deltaY: 10)
    try endTrackpadSwipe(on: scrollView)

    // then: AppKit springs the document back from that side too
    expect(scrollView.contentOffset.y).toEventually(beApproximatelyEqual(to: 0, within: 1e-9))
  }

  func test_scrollWheel_nested_atTheEnd_passesToTheParent() throws {
    // given: a scroll view at the bottom end of its range, nested in a parent scroll view that can scroll in every
    // direction
    let window = TestWindow()
    let (parent, scrollView) = Self.makeNestedScrollViews(in: window)
    scrollView.contentOffset = CGPoint(x: 0, y: 200)

    // when: the scroll view gets a mouse wheel event toward the bottom
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaY: -10))

    // then: the scroll view can't scroll toward the bottom, so the event goes to the parent
    expect(parent.scrollWheelEventCount) == 1

    // when: the scroll view gets a mouse wheel event toward the top
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaY: 10))

    // then: the scroll view can scroll toward the top, so it handles the event
    expect(parent.scrollWheelEventCount) == 1
  }

  func test_scrollWheel_nested_atTheEnd_alwaysBounces_passesToTheParent() throws {
    // given: a scroll view that always bounces, at the bottom right end of its range, nested in a parent scroll view
    // that can scroll in every direction
    let window = TestWindow()
    let (parent, scrollView) = Self.makeNestedScrollViews(in: window)
    scrollView.alwaysBounceHorizontal = true
    scrollView.alwaysBounceVertical = true
    scrollView.contentOffset = CGPoint(x: 200, y: 200)

    // when: the scroll view gets mouse wheel events toward the bottom and toward the right
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaY: -10))
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaX: -10))

    // then: a mouse wheel scroll can't bounce, so both events go to the parent
    expect(parent.scrollWheelEventCount) == 2

    // when: trackpad gestures scroll toward the bottom and toward the right
    try Self.sendScrollGesture(to: scrollView, deltaY: -10)
    try Self.sendScrollGesture(to: scrollView, deltaX: -10)

    // then: a trackpad gesture can bounce, so the scroll view handles both
    expect(parent.scrollWheelEventCount) == 2
  }

  func test_scrollWheel_nested_afterAGestureThatWentToTheParent_goesByItsOwnDirection() throws {
    // given: a scroll view at the bottom end of its range, nested in a parent scroll view that can scroll in every
    // direction, and a gesture toward the bottom that went to the parent
    let window = TestWindow()
    let (parent, scrollView) = Self.makeNestedScrollViews(in: window)
    scrollView.contentOffset = CGPoint(x: 0, y: 200)
    try Self.sendScrollGesture(to: scrollView, deltaY: -10)
    expect(parent.scrollWheelEventCount) == 3

    // when: the scroll view gets a mouse wheel event toward the top
    try scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaY: 10))

    // then: the scroll view can scroll toward the top, so it handles the event, instead of sending it where the gesture
    // went
    expect(parent.scrollWheelEventCount) == 3
  }

  func test_scrollWheel_nested_duringTheParentsGesture_goesByItsOwnDirection() throws {
    // given: a scroll view nested in a parent scroll view that scrolls, and a gesture toward the bottom in progress,
    // which the parent took over its own content
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    try views.parentContent.scrollWheel(with: Self.makeScrollEvent(phase: .began, deltaY: -10, after: Constants.scrollInterval))
    expect(views.parent.scrollWheelEventCount) == 1

    // when: the scroll view gets a mouse wheel event toward the bottom during the gesture
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(deltaY: -10, after: Constants.eventInterval))

    // then: the scroll view can scroll toward the bottom, so it handles the event, instead of following the gesture
    expect(views.parent.scrollWheelEventCount) == 1

    // when: the gesture's next event lands on the scroll view
    try views.scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .changed, deltaY: -10, after: Constants.eventInterval))

    // then: the gesture still goes to the parent
    expect(views.parent.scrollWheelEventCount) == 2
    expect(views.container.scrollWheelEventCount) == 0
  }

  func test_scrollWheel_nested_atTheEnd_scrollsTheParent() throws {
    // given: a scroll view at the bottom end of its range, nested in a parent scroll view that scrolls
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    views.scrollView.contentOffset = CGPoint(x: 0, y: 200)

    // when: the scroll view gets a mouse wheel event toward the bottom, and the run loop turns, which is when AppKit
    // applies a scroll
    try views.scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaY: -10))
    wait(timeout: 0.1)

    // then: the parent scrolls by the event's 10 pt, and the scroll view stays at the end
    expect(views.parent.contentOffset.y) == 410
    expect(views.scrollView.contentOffset.y) == 200

    // when: the scroll view gets a mouse wheel event toward the top
    try views.scrollView.scrollWheel(with: Self.makeMouseWheelEvent(deltaY: 10))
    wait(timeout: 0.1)

    // then: the scroll view scrolls by the event's 10 pt, and the parent stays
    expect(views.scrollView.contentOffset.y) == 190
    expect(views.parent.contentOffset.y) == 410
  }
  #endif

  // MARK: - Keyboard

  #if canImport(AppKit)
  func test_canScrollWithKeyboard() {
    // given: a 100 × 100 scroll view showing content as large as it
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 100)

    // then: it has no room to scroll, so the keys can't scroll it, and it doesn't take the focus
    expect(scrollView.canScrollWithKeyboard) == false
    expect(scrollView.acceptsFirstResponder) == false

    // when: the content is taller than the scroll view
    scrollView.contentSize = CGSize(width: 100, height: 300)

    // then: the keys can scroll it, and it takes the focus
    expect(scrollView.canScrollWithKeyboard) == true
    expect(scrollView.acceptsFirstResponder) == true

    // when: the content is wider than the scroll view, and as tall as it
    scrollView.contentSize = CGSize(width: 300, height: 100)

    // then: the keys can scroll it
    expect(scrollView.canScrollWithKeyboard) == true
    expect(scrollView.acceptsFirstResponder) == true

    // when: scrolling is disabled
    scrollView.isScrollEnabled = false

    // then: the keys can't scroll it, and it doesn't take the focus
    expect(scrollView.canScrollWithKeyboard) == false
    expect(scrollView.acceptsFirstResponder) == false
  }

  func test_arrowKeys_scrollByALineTowardTheKey() {
    // given: a 100 × 100 scroll view in a window, showing 300 × 300 content, so it scrolls from 0 to 200 along both axes,
    // with the focus in it
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 300, height: 300)
    window.contentView().addSubview(scrollView)
    window.makeFirstResponder(scrollView)
    expect(window.firstResponder) === scrollView.documentView

    // when: pressing the down arrow
    window.press(.down)

    // then: the content scrolls down by 40 points, as UIKit's keyboard scrolling does
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 40)

    // when: pressing the right arrow
    window.press(.right)

    // then: the content scrolls right by 40 points
    expect(scrollView.contentOffset) == CGPoint(x: 40, y: 40)

    // when: pressing the up arrow
    window.press(.up)

    // then: the content scrolls up by 40 points
    expect(scrollView.contentOffset) == CGPoint(x: 40, y: 0)

    // when: pressing the left arrow
    window.press(.left)

    // then: the content scrolls left by 40 points
    expect(scrollView.contentOffset) == .zero
  }

  func test_arrowKeys_nearTheEnd_stopAtTheEnd() {
    // given: a 100 × 100 scroll view in a window, showing 300 × 300 content, scrolled 10 points short of the bottom right
    // end, with the focus in it
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 300, height: 300)
    window.contentView().addSubview(scrollView)
    window.makeFirstResponder(scrollView)
    scrollView.contentOffset = CGPoint(x: 190, y: 190)

    // when: pressing the down and right arrows
    window.press(.down)
    window.press(.right)

    // then: the content scrolls to the end, not past it
    expect(scrollView.contentOffset) == CGPoint(x: 200, y: 200)
  }

  #if DEBUG
  func test_keyboardScroll_withoutTheAnimation_scrollsAsAppKitDoesAndAddsUpTheKeys() {
    // given: a 100 × 100 scroll view in a window, showing content 1000 tall, with the focus in it, whose keys scroll
    // without the animation, as when the user reduces motion, or before macOS 14
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 1000)
    window.contentView().addSubview(scrollView)
    window.makeFirstResponder(scrollView)
    ScrollView.scrollsWithKeyboardAnimationForTesting = false
    defer {
      ScrollView.scrollsWithKeyboardAnimationForTesting = nil
    }

    // when: the down arrow goes down, which the application dispatches as its current event
    window.keyDown(.down)

    // then: AppKit animates the scroll, unless the user reduces motion, and no animation of ComposeUI moves it
    let reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    if reducesMotion {
      expect(scrollView.contentOffset.y) == 40
    } else {
      expect(scrollView.contentOffset.y) < 40
    }
    if #available(macOS 14.0, *) {
      expect(scrollView.keyboardScrollAnimation) == nil
    }

    // when: the key repeats during AppKit's animation, as it does while it's held down
    window.keyDown(.down, isARepeat: true)

    // then: the repeat scrolls from where the animation goes, so the content scrolls by both presses
    expect(scrollView.contentOffset.y).toEventually(beEqual(to: 80))

    // when: pressing the page down key
    window.press(.pageDown)

    // then: the content scrolls by a page, 80% of the visible height
    expect(scrollView.contentOffset.y).toEventually(beEqual(to: 160))

    // when: pressing the page up key
    window.press(.pageUp)

    // then: the content scrolls back up by a page
    expect(scrollView.contentOffset.y).toEventually(beEqual(to: 80))
  }

  func test_pageKeys_scrollByAPageOfTheVisibleHeight_withAndWithoutTheAnimation() {
    for scrollsWithAnimation in [true, false] {
      // given: a 100 × 100 scroll view in a window, showing content 1000 tall below a 20 point top inset, scrolled to the
      // top of the content, with the focus in it, whose keys scroll with the animation, or without it
      let window = TestWindow()
      let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      scrollView.automaticallyAdjustsContentInsets = false
      scrollView.contentInset = EdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
      scrollView.contentSize = CGSize(width: 100, height: 1000)
      window.contentView().addSubview(scrollView)
      window.makeFirstResponder(scrollView)
      scrollView.contentOffset = .zero
      ScrollView.scrollsWithKeyboardAnimationForTesting = scrollsWithAnimation
      defer {
        ScrollView.scrollsWithKeyboardAnimationForTesting = nil
      }

      // when: pressing the page down key
      window.press(.pageDown)

      // then: the page is 80% of the 80 point height below the inset, more than that height less the 40 point overlap
      expect(scrollView.contentOffset).toEventually(beEqual(to: CGPoint(x: 0, y: 64)))

      // when: the scroll view is 400 points tall below the inset, and the page down key is pressed
      scrollView.frame.size.height = 420
      scrollView.contentOffset = .zero
      window.press(.pageDown)

      // then: the page is the height less the 40 point overlap, more than 80% of the height
      expect(scrollView.contentOffset).toEventually(beEqual(to: CGPoint(x: 0, y: 360)))
    }
  }

  func test_arrowKeysWithOption_scrollByAPageTowardEachDirection_withAndWithoutTheAnimation() {
    for scrollsWithAnimation in [true, false] {
      // given: a 100 × 100 scroll view in a window, in the middle of content 1000 × 1000, with the focus in it, whose
      // keys scroll with the animation, or without it
      let window = TestWindow()
      let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      scrollView.contentSize = CGSize(width: 1000, height: 1000)
      window.contentView().addSubview(scrollView)
      window.makeFirstResponder(scrollView)
      ScrollView.scrollsWithKeyboardAnimationForTesting = scrollsWithAnimation
      defer {
        ScrollView.scrollsWithKeyboardAnimationForTesting = nil
      }

      let pages: [(ScrollingKey, CGPoint)] = [
        (.down, CGPoint(x: 400, y: 480)),
        (.up, CGPoint(x: 400, y: 320)),
        (.right, CGPoint(x: 480, y: 400)),
        (.left, CGPoint(x: 320, y: 400)),
      ]
      for (key, offset) in pages {
        // when: the arrow key goes down and up with Option
        scrollView.contentOffset = CGPoint(x: 400, y: 400)
        window.keyDown(key, modifierFlags: .option)
        window.keyUp(key)
        window.settleKeyboardScrolls()

        // then: the content scrolls toward the key by a page, 80% of the 100 point length, more than the length less
        // the 40 point overlap
        expect(scrollView.contentOffset).toEventually(beEqual(to: offset))
      }
    }
  }

  func test_leftAndRightArrowsWithOption_scrollByAPageOfTheWidthBetweenTheInsets_withAndWithoutTheAnimation() {
    for scrollsWithAnimation in [true, false] {
      // given: a 100 × 100 scroll view in a window, with insets of 20 points on the left and 40 on the right, which
      // leave 40 points of width between them, in the middle of content 1000 wide, with the focus in it, whose keys
      // scroll with the animation, or without it
      let window = TestWindow()
      let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      scrollView.automaticallyAdjustsContentInsets = false
      scrollView.contentInset = EdgeInsets(top: 0, left: 20, bottom: 0, right: 40)
      scrollView.contentSize = CGSize(width: 1000, height: 100)
      window.contentView().addSubview(scrollView)
      window.makeFirstResponder(scrollView)
      ScrollView.scrollsWithKeyboardAnimationForTesting = scrollsWithAnimation
      defer {
        ScrollView.scrollsWithKeyboardAnimationForTesting = nil
      }

      for (key, offset): (ScrollingKey, CGPoint) in [(.right, CGPoint(x: 432, y: 0)), (.left, CGPoint(x: 368, y: 0))] {
        // when: the arrow key goes down and up with Option
        scrollView.contentOffset = CGPoint(x: 400, y: 0)
        window.keyDown(key, modifierFlags: .option)
        window.keyUp(key)
        window.settleKeyboardScrolls()

        // then: the content scrolls toward the key by a page, 80% of the 40 point width between the insets, more than
        // that width less the 40 point overlap
        expect(scrollView.contentOffset).toEventually(beEqual(to: offset))
      }
    }
  }

  func test_arrowKeysWithCommand_scrollToTheEdgeTowardEachDirection_withAndWithoutTheAnimation() {
    for scrollsWithAnimation in [true, false] {
      // given: a 100 × 100 scroll view in a window, in the middle of content 1000 × 1000, with the focus in it, whose
      // keys scroll with the animation, or without it
      let window = TestWindow()
      let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      scrollView.contentSize = CGSize(width: 1000, height: 1000)
      window.contentView().addSubview(scrollView)
      window.makeFirstResponder(scrollView)
      ScrollView.scrollsWithKeyboardAnimationForTesting = scrollsWithAnimation
      defer {
        ScrollView.scrollsWithKeyboardAnimationForTesting = nil
      }

      let edges: [(ScrollingKey, CGPoint)] = [
        (.down, CGPoint(x: 400, y: 900)),
        (.up, CGPoint(x: 400, y: 0)),
        (.right, CGPoint(x: 900, y: 400)),
        (.left, CGPoint(x: 0, y: 400)),
      ]
      for (key, offset) in edges {
        // when: the arrow key goes down and up with Command
        scrollView.contentOffset = CGPoint(x: 400, y: 400)
        window.keyDown(key, modifierFlags: .command)
        window.keyUp(key)
        window.settleKeyboardScrolls()

        // then: the content scrolls to the edge toward the key
        expect(scrollView.contentOffset).toEventually(beEqual(to: offset))
      }
    }
  }

  func test_upAndDownArrowsWithCommand_fromAViewThatInterpretsItsKeys_scrollToTheTopAndTheBottom() {
    for scrollsWithAnimation in [true, false] {
      // given: a 100 × 100 scroll view in a window, in the middle of content 1000 tall, with the focus in a view in its
      // content that interprets its keys, which sends Command-Up and Command-Down as the actions to the beginning and
      // the end of the document, and whose keys scroll with the animation, or without it
      let window = TestWindow()
      let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      scrollView.contentSize = CGSize(width: 100, height: 1000)
      scrollView.contentOffset = CGPoint(x: 0, y: 400)
      window.contentView().addSubview(scrollView)
      let keyInterpretingView = KeyInterpretingView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
      scrollView.documentView?.addSubview(keyInterpretingView)
      window.makeFirstResponder(keyInterpretingView)
      ScrollView.scrollsWithKeyboardAnimationForTesting = scrollsWithAnimation
      defer {
        ScrollView.scrollsWithKeyboardAnimationForTesting = nil
      }

      // when: the down arrow goes down and up with Command
      window.keyDown(.down, modifierFlags: .command)
      window.keyUp(.down)
      window.settleKeyboardScrolls()

      // then: the content scrolls to the bottom
      expect(scrollView.contentOffset).toEventually(beEqual(to: CGPoint(x: 0, y: 900)))

      // when: the up arrow goes down and up with Command
      window.keyDown(.up, modifierFlags: .command)
      window.keyUp(.up)
      window.settleKeyboardScrolls()

      // then: the content scrolls to the top
      expect(scrollView.contentOffset).toEventually(beEqual(to: .zero))
      expect(keyInterpretingView.interpretedKeyCount) == 2
    }
  }
  #endif

  func test_arrowKeys_nested_atTheEnd_goOnToTheParent_whichTakesTheFocus() {
    // given: a scroll view at the bottom end of its range, with the focus in it, nested in a parent scroll view that
    // scrolls
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    views.scrollView.contentOffset = CGPoint(x: 0, y: 200)
    window.makeFirstResponder(views.scrollView)

    // when: pressing the down arrow
    window.press(.down)

    // then: the scroll view can't scroll down, so the press goes on to the parent, which scrolls down by 40 points and
    // takes the focus
    expect(views.scrollView.contentOffset) == CGPoint(x: 0, y: 200)
    expect(views.parent.contentOffset) == CGPoint(x: 400, y: 440)
    expect(window.firstResponder) === views.parent.contentContainerView

    // when: pressing the up arrow
    window.press(.up)

    // then: the parent has the focus, so it scrolls back up, and the scroll view stays
    expect(views.parent.contentOffset) == CGPoint(x: 400, y: 400)
    expect(views.scrollView.contentOffset) == CGPoint(x: 0, y: 200)

    // when: the scroll view takes the focus again, as a click in it gives it, and the up arrow is pressed
    window.makeFirstResponder(views.scrollView)
    window.press(.up)

    // then: the scroll view scrolls up, and the parent stays
    expect(views.scrollView.contentOffset) == CGPoint(x: 0, y: 160)
    expect(views.parent.contentOffset) == CGPoint(x: 400, y: 400)
  }

  func test_arrowKeys_nested_alongAnAxisTheScrollViewDoesNotScroll_scrollTheParent() {
    // given: a scroll view that scrolls only horizontally, with the focus in it, nested in a parent scroll view that
    // scrolls
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    views.scrollView.contentSize = CGSize(width: 300, height: 100)
    window.makeFirstResponder(views.scrollView)

    // when: pressing the down and up arrows
    window.press(.down)
    window.press(.down)
    window.press(.up)

    // then: the parent scrolls vertically, and the scroll view stays
    expect(views.parent.contentOffset) == CGPoint(x: 400, y: 440)
    expect(views.scrollView.contentOffset) == .zero

    // when: pressing the right and left arrows
    window.press(.right)
    window.press(.right)
    window.press(.left)

    // then: the scroll view scrolls horizontally, and the parent stays, without the focus, which stays in the scroll view
    expect(views.scrollView.contentOffset) == CGPoint(x: 40, y: 0)
    expect(views.parent.contentOffset) == CGPoint(x: 400, y: 440)
    expect(window.firstResponder) === views.scrollView.contentContainerView
  }

  func test_arrowKeys_nested_scrollDisabled_scrollTheParent() {
    // given: a scroll view whose scrolling is disabled, with the focus in a view in its content, nested in a parent scroll
    // view that scrolls
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    views.scrollView.contentOffset = CGPoint(x: 100, y: 100)
    views.scrollView.isScrollEnabled = false
    let focusableView = FocusableView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    views.scrollView.documentView?.addSubview(focusableView)
    window.makeFirstResponder(focusableView)

    // when: pressing each arrow
    window.press(.down)
    window.press(.right)
    window.press(.down)
    window.press(.up)
    window.press(.right)
    window.press(.left)

    // then: the scroll view stays, and the parent scrolls toward each key, while the focus stays where it is
    expect(views.scrollView.contentOffset) == CGPoint(x: 100, y: 100)
    expect(views.parent.contentOffset) == CGPoint(x: 440, y: 440)
    expect(window.firstResponder) === focusableView
  }

  func test_pageKeys_scrollByAPage() {
    // given: a 100 × 100 scroll view in a window, showing content 1000 tall, with the focus in it
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 1000)
    window.contentView().addSubview(scrollView)
    window.makeFirstResponder(scrollView)

    // when: pressing the page down key
    window.press(.pageDown)

    // then: the content scrolls down by a page, 80% of the visible height
    expect(scrollView.contentOffset).toEventually(beEqual(to: CGPoint(x: 0, y: 80)))

    // when: pressing the page up key
    window.press(.pageUp)

    // then: the content scrolls back up by a page
    expect(scrollView.contentOffset).toEventually(beEqual(to: .zero))
  }

  func test_pageKeys_nested_atTheEnd_goOnToTheParent_whichTakesTheFocus() {
    // given: a scroll view at the top end of its range, with the focus in it, nested in a parent scroll view that scrolls
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    window.makeFirstResponder(views.scrollView)

    // when: pressing the page up key
    window.press(.pageUp)

    // then: the scroll view can't scroll up, so the press goes on to the parent, which scrolls up by its page, 80% of its
    // height, and takes the focus
    expect(views.parent.contentOffset).toEventually(beEqual(to: CGPoint(x: 400, y: 240)))
    expect(views.scrollView.contentOffset) == .zero
    expect(window.firstResponder) === views.parent.contentContainerView

    // when: the scroll view, at the bottom end of its range, takes the focus again, and the page down key is pressed
    views.scrollView.contentOffset = CGPoint(x: 0, y: 200)
    window.makeFirstResponder(views.scrollView)
    window.press(.pageDown)

    // then: the parent scrolls down by its page, and takes the focus
    expect(views.parent.contentOffset).toEventually(beEqual(to: CGPoint(x: 400, y: 400)))
    expect(views.scrollView.contentOffset) == CGPoint(x: 0, y: 200)
    expect(window.firstResponder) === views.parent.contentContainerView
  }

  func test_pageKeys_nested_scrollDisabled_scrollTheParent() {
    // given: a scroll view whose scrolling is disabled, scrolled to the middle of its range, with the focus in a view in its
    // content, nested in a parent scroll view that scrolls
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    views.scrollView.contentOffset = CGPoint(x: 0, y: 100)
    views.scrollView.isScrollEnabled = false
    let focusableView = FocusableView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    views.scrollView.documentView?.addSubview(focusableView)
    window.makeFirstResponder(focusableView)

    // when: pressing the page down key
    window.press(.pageDown)

    // then: the scroll view stays, and the parent scrolls down by its page, while the focus stays where it is
    expect(views.parent.contentOffset).toEventually(beEqual(to: CGPoint(x: 400, y: 560)))
    expect(views.scrollView.contentOffset) == CGPoint(x: 0, y: 100)
    expect(window.firstResponder) === focusableView

    // when: pressing the page up key
    window.press(.pageUp)

    // then: the parent scrolls back up by its page
    expect(views.parent.contentOffset).toEventually(beEqual(to: CGPoint(x: 400, y: 400)))
    expect(views.scrollView.contentOffset) == CGPoint(x: 0, y: 100)
  }

  func test_pageKeys_fromAViewThatInterpretsItsKeys_scrollByAPage() {
    // given: a 100 × 100 scroll view in a window, showing content 1000 tall, with the focus in a view in its content that
    // interprets its keys, which turns the page keys into the scroll page actions
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 1000)
    window.contentView().addSubview(scrollView)
    let keyInterpretingView = KeyInterpretingView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    scrollView.documentView?.addSubview(keyInterpretingView)
    window.makeFirstResponder(keyInterpretingView)

    // when: pressing the page down key
    window.press(.pageDown)

    // then: the content scrolls down by a page, 80% of the visible height
    expect(scrollView.contentOffset).toEventually(beEqual(to: CGPoint(x: 0, y: 80)))
    expect(keyInterpretingView.interpretedKeyCount) == 1

    // when: pressing the page up key
    window.press(.pageUp)

    // then: the content scrolls back up by a page
    expect(scrollView.contentOffset).toEventually(beEqual(to: .zero))
    expect(keyInterpretingView.interpretedKeyCount) == 2
  }

  func test_pageKeys_fromAViewThatInterpretsItsKeys_nested_scrollTheParentWhenTheScrollViewCanNot() {
    // given: a scroll view at the top end of its range, with the focus in a view in its content that interprets its keys,
    // nested in a parent scroll view that scrolls
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    let keyInterpretingView = KeyInterpretingView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    views.scrollView.documentView?.addSubview(keyInterpretingView)
    window.makeFirstResponder(keyInterpretingView)

    // when: pressing the page up key
    window.press(.pageUp)

    // then: the scroll view can't scroll up, so the press goes on to the parent, which scrolls up by its page
    expect(views.parent.contentOffset).toEventually(beEqual(to: CGPoint(x: 400, y: 240)))
    expect(views.scrollView.contentOffset) == .zero

    // when: the scroll view is at the bottom end of its range, the view that interprets its keys takes the focus again,
    // and the page down key is pressed
    views.scrollView.contentOffset = CGPoint(x: 0, y: 200)
    window.makeFirstResponder(keyInterpretingView)
    window.press(.pageDown)

    // then: the parent scrolls down by its page
    expect(views.parent.contentOffset).toEventually(beEqual(to: CGPoint(x: 400, y: 400)))
    expect(views.scrollView.contentOffset) == CGPoint(x: 0, y: 200)

    // when: the scroll view is in the middle of its range with its scrolling disabled, the view that interprets its keys
    // takes the focus again, and the page keys are pressed
    views.scrollView.contentOffset = CGPoint(x: 0, y: 100)
    views.scrollView.isScrollEnabled = false
    window.makeFirstResponder(keyInterpretingView)
    window.press(.pageDown)

    // then: the scroll view stays, and the parent scrolls down by its page
    expect(views.parent.contentOffset).toEventually(beEqual(to: CGPoint(x: 400, y: 560)))
    expect(views.scrollView.contentOffset) == CGPoint(x: 0, y: 100)

    // when: pressing the page up key
    window.press(.pageUp)

    // then: the parent scrolls back up by its page
    expect(views.parent.contentOffset).toEventually(beEqual(to: CGPoint(x: 400, y: 400)))
    expect(views.scrollView.contentOffset) == CGPoint(x: 0, y: 100)
  }

  func test_pageKeys_fromAViewThatInterpretsItsKeys_inAScrollViewThatCanNotScroll_scrollAnAppKitScrollViewAroundIt() {
    // given: a scroll view whose content fits it, in a plain AppKit scroll view that scrolls, in a window, with the focus
    // in a view in its content that interprets its keys
    let window = TestWindow()
    let outerScrollView = NSScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    outerScrollView.documentView = FlippedView(frame: CGRect(x: 0, y: 0, width: 200, height: 2000))
    window.contentView().addSubview(outerScrollView)
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 100)
    outerScrollView.documentView?.addSubview(scrollView)
    let keyInterpretingView = KeyInterpretingView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    scrollView.documentView?.addSubview(keyInterpretingView)
    window.makeFirstResponder(keyInterpretingView)

    // when: pressing the page down key
    window.press(.pageDown)

    // then: the scroll view passes the key on as the page action, which AppKit's scroll view handles, so it scrolls down
    // by its page, its height less 10 points
    expect(outerScrollView.contentView.bounds.origin).toEventually(beEqual(to: CGPoint(x: 0, y: 190)))
    expect(scrollView.contentOffset) == .zero

    // when: pressing the page up key
    window.press(.pageUp)

    // then: AppKit's scroll view scrolls back up by its page
    expect(outerScrollView.contentView.bounds.origin).toEventually(beEqual(to: .zero))
  }

  func test_keys_withModifiersForOtherUses_passTheirActionsOnWithoutScrolling() {
    // given: a 100 × 100 scroll view in the middle of its range, with the focus in it, in a view that records the key
    // actions that reach it
    let window = TestWindow()
    let recordingView = KeyActionRecordingView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    window.contentView().addSubview(recordingView)
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 1000, height: 1000)
    scrollView.contentOffset = CGPoint(x: 400, y: 400)
    recordingView.addSubview(scrollView)
    window.makeFirstResponder(scrollView)

    // when: each arrow and page key goes down and up with Shift, Control, or more than one modifier, and each page key
    // with Command or Option, which AppKit sends as the key's action
    var presses: [(ScrollingKey, NSEvent.ModifierFlags)] = []
    for modifierFlags: NSEvent.ModifierFlags in [.shift, .control, [.command, .option], [.command, .shift], [.option, .control]] {
      for key: ScrollingKey in [.up, .down, .left, .right, .pageUp, .pageDown] {
        presses.append((key, modifierFlags))
      }
    }
    for modifierFlags: NSEvent.ModifierFlags in [.command, .option] {
      for key: ScrollingKey in [.pageUp, .pageDown] {
        presses.append((key, modifierFlags))
      }
    }
    for (key, modifierFlags) in presses {
      window.keyDown(key, modifierFlags: modifierFlags)
      window.keyUp(key)
    }

    // then: the content stays, and each key's action passes on to the view around the scroll view, without an animation
    // that moves the content
    expect(scrollView.contentOffset) == CGPoint(x: 400, y: 400)
    expect(recordingView.actionCount) == presses.count
    if #available(macOS 14.0, *) {
      expect(scrollView.keyboardScrollAnimation) == nil
    }
  }

  func test_arrowKeyWithCommand_atTheEdge_withNoScrollViewAroundToGoOnTo_passesItsActionOn() {
    // given: a 100 × 100 scroll view at the bottom end of its range, with the focus in it, in a view that records the
    // key actions that reach it
    let window = TestWindow()
    let recordingView = KeyActionRecordingView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    window.contentView().addSubview(recordingView)
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 1000)
    scrollView.contentOffset = CGPoint(x: 0, y: 900)
    recordingView.addSubview(scrollView)
    window.makeFirstResponder(scrollView)

    // when: the down arrow goes down with Command, and repeats while it's held down
    window.keyDown(.down, modifierFlags: .command)
    window.keyDown(.down, isARepeat: true, modifierFlags: .command)
    window.keyUp(.down)

    // then: the content stays at the edge without stretching, and the press and its repeat pass the action on
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 900)
    expect(recordingView.actionCount) == 2
    if #available(macOS 14.0, *) {
      expect(scrollView.keyboardScrollAnimation) == nil
    }
  }

  func test_arrowKeyWithCommand_nested_atTheEdge_goesOnToTheParent_whichTakesTheFocus() {
    // given: a scroll view at the bottom end of its range, with the focus in it, nested in a parent scroll view that
    // scrolls
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    views.scrollView.contentOffset = CGPoint(x: 0, y: 200)
    window.makeFirstResponder(views.scrollView)

    // when: the down arrow goes down and up with Command
    window.keyDown(.down, modifierFlags: .command)
    window.keyUp(.down)
    window.settleKeyboardScrolls()

    // then: the press goes on to the parent, which scrolls to its bottom edge, and takes the focus
    expect(views.parent.contentOffset).toEventually(beEqual(to: CGPoint(x: 400, y: 800)))
    expect(views.scrollView.contentOffset) == CGPoint(x: 0, y: 200)
    expect(window.firstResponder) === views.parent.contentContainerView
  }

  #if DEBUG
  func test_arrowKey_heldDownInANestedScrollView_stretchesItAtItsEnd_andTheNextPressGoesOnToTheParent() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view 40 points from the bottom end of its range, with the focus in it, nested in a parent scroll
    // view that scrolls, whose keys move the content with the animation
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    views.scrollView.contentOffset = CGPoint(x: 0, y: 160)
    window.makeFirstResponder(views.scrollView)
    ScrollView.scrollsWithKeyboardAnimationForTesting = true
    defer {
      ScrollView.scrollsWithKeyboardAnimationForTesting = nil
    }

    // when: the down arrow stays down for half a second, and repeats, as it does after the system's delay
    let startTime: CFTimeInterval = 1000
    window.keyDown(.down, at: startTime)
    let animation = try unwrap(views.scrollView.keyboardScrollAnimation)
    animation.stepFrames(in: views.scrollView, from: startTime, until: startTime + 0.4)
    window.keyDown(.down, at: startTime + 0.4, isARepeat: true)
    animation.stepFrames(in: views.scrollView, from: startTime + 0.4, until: startTime + 0.5)

    // then: the scroll view scrolls to its end and stretches past it, and keeps the focus, while the parent stays
    expect(views.scrollView.contentOffset.y) > 210
    expect(views.parent.contentOffset) == CGPoint(x: 400, y: 400)
    expect(window.firstResponder) === views.scrollView.contentContainerView

    // when: the key goes up, and frames step the animation until it stops
    window.keyUp(.down, at: startTime + 0.5)
    animation.stepFrames(in: views.scrollView, from: startTime + 0.5)

    // then: the scroll view springs back to its end
    expect(views.scrollView.contentOffset) == CGPoint(x: 0, y: 200)

    // when: pressing the down arrow again
    window.press(.down)

    // then: the new press goes on to the parent, which scrolls down by 40 points and takes the focus
    expect(views.parent.contentOffset) == CGPoint(x: 400, y: 440)
    expect(views.scrollView.contentOffset) == CGPoint(x: 0, y: 200)
    expect(window.firstResponder) === views.parent.contentContainerView
  }

  func test_keyInANestedScrollView_whileTheParentHoldsAPress_doesNothing() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view that scrolls only horizontally, with the focus in it, nested in a parent scroll view that
    // scrolls, whose keys move the content with the animation
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    views.scrollView.contentSize = CGSize(width: 300, height: 100)
    window.makeFirstResponder(views.scrollView)
    ScrollView.scrollsWithKeyboardAnimationForTesting = true
    defer {
      ScrollView.scrollsWithKeyboardAnimationForTesting = nil
    }

    // when: the down arrow goes down, which passes through the scroll view to the parent, and the right arrow goes down
    // while it's held, and frames step the parent's animation
    let startTime: CFTimeInterval = 1000
    window.keyDown(.down, at: startTime)
    window.keyDown(.right, at: startTime + 0.05)
    let parentAnimation = try unwrap(views.parent.keyboardScrollAnimation)
    parentAnimation.stepFrames(in: views.parent, from: startTime, until: startTime + 0.1)

    // then: the parent's press keeps the keys, so the right arrow doesn't push the scroll view, and the parent scrolls
    // down
    expect(views.scrollView.keyboardScrollAnimation?.isKeyHeld ?? false) == false
    expect(views.scrollView.contentOffset) == .zero
    expect(views.parent.contentOffset.y) > 400
  }

  func test_arrowKey_atTheEnd_withNoScrollViewAroundToGoOnTo_stretchesTheScrollViewAndSpringsBack() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view at the bottom end of its range, with the focus in it, whose keys move the content
    // with the animation
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 1000)
    scrollView.contentOffset = CGPoint(x: 0, y: 900)
    window.contentView().addSubview(scrollView)
    window.makeFirstResponder(scrollView)
    ScrollView.scrollsWithKeyboardAnimationForTesting = true
    defer {
      ScrollView.scrollsWithKeyboardAnimationForTesting = nil
    }

    // when: the down arrow stays down for a tenth of a second
    let startTime: CFTimeInterval = 1000
    window.keyDown(.down, at: startTime)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.stepFrames(in: scrollView, from: startTime, until: startTime + 0.1)

    // then: the content stretches past the end
    expect(scrollView.contentOffset.y) > 900

    // when: the key goes up, and frames step the animation until it stops
    window.keyUp(.down, at: startTime + 0.1)
    let offsets = animation.stepFrames(in: scrollView, from: startTime + 0.1)

    // then: the content springs back to the end, without passing it into the range
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 900)
    expect(offsets.map(\.y).min()) == 900
  }

  func test_pageKey_atTheEnd_withNoScrollViewAroundToGoOnTo_doesNotStretchTheScrollView() {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view at the bottom end of its range, with the focus in it, whose keys move the content
    // with the animation
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 1000)
    scrollView.contentOffset = CGPoint(x: 0, y: 900)
    window.contentView().addSubview(scrollView)
    window.makeFirstResponder(scrollView)
    ScrollView.scrollsWithKeyboardAnimationForTesting = true
    defer {
      ScrollView.scrollsWithKeyboardAnimationForTesting = nil
    }

    // when: the page down key goes down, and repeats while it's held down
    let startTime: CFTimeInterval = 1000
    window.keyDown(.pageDown, at: startTime)
    window.keyDown(.pageDown, at: startTime + 0.4, isARepeat: true)
    window.keyDown(.pageDown, at: startTime + 0.5, isARepeat: true)
    scrollView.keyboardScrollAnimation?.stepFrames(in: scrollView, from: startTime + 0.5, until: startTime + 0.6)

    // then: the content stays at the end, since a page key doesn't stretch it, and its repeats go on as the press did
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 900)
    expect(scrollView.keyboardScrollAnimation) == nil
  }

  func test_pageKey_heldDownAtTheEnd_inAnAppKitScrollView_pagesTheAppKitScrollViewOnEachRepeat() {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view at the bottom end of its range, with the focus in it, in a plain AppKit scroll view
    // that scrolls, whose keys move the content with the animation
    let window = TestWindow()
    let outerScrollView = NSScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    outerScrollView.documentView = FlippedView(frame: CGRect(x: 0, y: 0, width: 200, height: 2000))
    window.contentView().addSubview(outerScrollView)
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 1000)
    scrollView.contentOffset = CGPoint(x: 0, y: 900)
    outerScrollView.documentView?.addSubview(scrollView)
    window.makeFirstResponder(scrollView)
    ScrollView.scrollsWithKeyboardAnimationForTesting = true
    defer {
      ScrollView.scrollsWithKeyboardAnimationForTesting = nil
    }

    // when: the page down key goes down
    let startTime: CFTimeInterval = 1000
    window.keyDown(.pageDown, at: startTime)

    // then: the scroll view passes the key on as the page action, so AppKit's scroll view scrolls down by its page, its
    // height less 10 points
    expect(outerScrollView.contentView.bounds.origin).toEventually(beEqual(to: CGPoint(x: 0, y: 190)))

    // when: the key repeats while it's held down
    window.keyDown(.pageDown, at: startTime + 0.4, isARepeat: true)
    scrollView.keyboardScrollAnimation?.stepFrames(in: scrollView, from: startTime + 0.4, until: startTime + 0.5)

    // then: the repeat goes on as the press did, so AppKit's scroll view scrolls down by another page, while the scroll
    // view stays at its end instead of stretching
    expect(outerScrollView.contentView.bounds.origin).toEventually(beEqual(to: CGPoint(x: 0, y: 380)))
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 900)
    expect(scrollView.keyboardScrollAnimation) == nil
  }

  func test_pageKey_newPressThatTheScrollViewPassesThrough_endsAPressPassedOnAtTheEnd() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a 100 × 100 scroll view at the bottom end of its range, with the focus in it, whose keys move the content
    // with the animation, which passed on a press of the page down key at the end, and which something else then scrolls
    // up to the middle of its range
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 1000)
    scrollView.contentOffset = CGPoint(x: 0, y: 900)
    window.contentView().addSubview(scrollView)
    window.makeFirstResponder(scrollView)
    ScrollView.scrollsWithKeyboardAnimationForTesting = true
    defer {
      ScrollView.scrollsWithKeyboardAnimationForTesting = nil
    }
    let startTime: CFTimeInterval = 1000
    window.keyDown(.pageDown, at: startTime)
    window.keyUp(.pageDown, at: startTime + 0.1)
    expect(scrollView.keyboardScrollAnimation) == nil
    scrollView.contentOffset = CGPoint(x: 0, y: 500)

    // when: the page down key goes down with Shift, which the scroll view passes through, and repeats once Shift goes
    // up, and frames step the animation for 0.2 s
    window.keyDown(.pageDown, at: startTime + 1, modifierFlags: .shift)
    expect(scrollView.keyboardScrollAnimation) == nil
    window.keyDown(.pageDown, at: startTime + 1.5, isARepeat: true)
    let animation = try unwrap(scrollView.keyboardScrollAnimation)
    animation.stepFrames(in: scrollView, from: startTime + 1.5, until: startTime + 1.7)

    // then: the repeat pushes the content down by pages, since the new press ended the one that the scroll view passed on
    expect(animation.isKeyHeld) == true
    expect(scrollView.contentOffset.y) > 500
  }

  func test_keyUp_throughAScrollViewThatTheKeysPassThrough_endsThePressOfTheParent() throws {
    guard #available(macOS 14.0, *) else {
      return
    }

    // given: a scroll view whose content fits it, with the focus in a view in its content, nested in a parent scroll view
    // that scrolls, whose keys move the content with the animation
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    views.scrollView.contentSize = CGSize(width: 100, height: 100)
    let focusableView = FocusableView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    views.scrollView.documentView?.addSubview(focusableView)
    window.makeFirstResponder(focusableView)
    ScrollView.scrollsWithKeyboardAnimationForTesting = true
    defer {
      ScrollView.scrollsWithKeyboardAnimationForTesting = nil
    }

    // when: the down arrow goes down
    let startTime: CFTimeInterval = 1000
    window.keyDown(.down, at: startTime)

    // then: the key passes through the scroll view to the parent, which holds the press, while the focus stays
    let animation = try unwrap(views.parent.keyboardScrollAnimation)
    expect(animation.isKeyHeld) == true
    expect(window.firstResponder) === focusableView

    // when: the key goes up, which passes up the responder chain through the scroll view
    window.keyUp(.down, at: startTime + 0.05)

    // then: the parent's press ends, and its content comes to rest a step down
    expect(animation.isKeyHeld) == false
    animation.stepFrames(in: views.parent, from: startTime + 0.05)
    expect(views.parent.contentOffset) == CGPoint(x: 400, y: 440)
  }

  func test_arrowKey_withoutTheAnimation_goesOnToTheParentOnANewPressOnly() {
    // given: a scroll view at the bottom end of its range, with the focus in it, nested in a parent scroll view that
    // scrolls, whose keys scroll without the animation
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)
    views.scrollView.contentOffset = CGPoint(x: 0, y: 200)
    window.makeFirstResponder(views.scrollView)
    ScrollView.scrollsWithKeyboardAnimationForTesting = false
    defer {
      ScrollView.scrollsWithKeyboardAnimationForTesting = nil
    }

    // when: the down arrow repeats, as it does while it's held down after the scroll view reached its end
    window.keyDown(.down, isARepeat: true)

    // then: the repeat doesn't go on to the parent, which stays, and the focus stays in the scroll view
    expect(views.parent.contentOffset) == CGPoint(x: 400, y: 400)
    expect(views.scrollView.contentOffset) == CGPoint(x: 0, y: 200)
    expect(window.firstResponder) === views.scrollView.contentContainerView

    // when: pressing the down arrow anew
    window.press(.down)

    // then: the new press goes on to the parent, which scrolls down by 40 points and takes the focus
    expect(views.parent.contentOffset).toEventually(beEqual(to: CGPoint(x: 400, y: 440)))
    expect(window.firstResponder) === views.parent.contentContainerView
  }
  #endif

  func test_click_onTheContent_focusesIt() {
    // given: a scroll view in a window, showing content taller than it, with a view in its content that doesn't take the
    // focus
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 300)
    window.contentView().addSubview(scrollView)
    let view = NSView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    scrollView.documentView?.addSubview(view)
    expect(window.firstResponder) === window

    // when: clicking the view
    let clickedView = window.click(view)

    // then: the click passes up from the view, and focuses the content
    expect(clickedView) === view
    expect(window.firstResponder) === scrollView.documentView

    // when: the focus moves out of the scroll view, and the content is clicked where no view is
    window.makeFirstResponder(nil)
    window.click(at: scrollView.convert(CGPoint(x: 75, y: 75), to: nil))

    // then: the content takes the focus as the clicked view
    expect(window.firstResponder) === scrollView.documentView

    // when: the arrow keys are pressed
    window.press(.down)

    // then: the scroll view scrolls
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 40)
  }

  func test_click_whenTheKeysCanNotScroll_keepsTheFocusWhereItIs() {
    // given: a scroll view in a window, showing content as large as it, with a view in its content, and the focus in a
    // view outside the scroll view
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 100)
    window.contentView().addSubview(scrollView)
    let view = NSView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    scrollView.documentView?.addSubview(view)
    let outsideView = FocusableView(frame: CGRect(x: 200, y: 200, width: 10, height: 10))
    window.contentView().addSubview(outsideView)
    window.makeFirstResponder(outsideView)

    // when: clicking the view
    window.click(view)

    // then: the keys can't scroll the scroll view, so it doesn't take the focus
    expect(window.firstResponder) === outsideView
  }

  func test_click_onAFocusedViewInTheContent_keepsItsFocus() {
    // given: a scroll view in a window, showing content taller than it, with a view that takes the focus and passes
    // clicks up, and another view, in its content
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 300)
    window.contentView().addSubview(scrollView)
    let focusableView = FocusableView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    scrollView.documentView?.addSubview(focusableView)
    let otherView = NSView(frame: CGRect(x: 50, y: 0, width: 50, height: 50))
    scrollView.documentView?.addSubview(otherView)

    // when: clicking the view that takes the focus, which AppKit focuses before the click passes up from it
    window.click(focusableView)

    // then: the view keeps the focus
    expect(window.firstResponder) === focusableView

    // when: clicking the other view
    window.click(otherView)

    // then: the click landed outside the focused view, so the content takes the focus from it
    expect(window.firstResponder) === scrollView.documentView
  }

  func test_click_nested_focusesTheInnermostScrollViewThatTheKeysScroll() {
    // given: a scroll view nested in a parent scroll view that scrolls, beside a view of the parent's own content
    let window = TestWindow()
    let views = Self.makeScrollingNestedScrollViews(in: window)

    // when: clicking the scroll view's content
    window.click(at: views.scrollView.convert(CGPoint(x: 50, y: 50), to: nil))

    // then: the scroll view gets the click first, and keeps the focus as the click passes up to the parent
    expect(window.firstResponder) === views.scrollView.documentView

    // when: clicking the parent's own content
    window.click(views.parentContent)

    // then: the parent's content takes the focus from the scroll view
    expect(window.firstResponder) === views.parent.documentView

    // when: the scroll view's content fits it, and its content is clicked
    views.scrollView.contentSize = CGSize(width: 100, height: 100)
    window.click(at: views.scrollView.convert(CGPoint(x: 50, y: 50), to: nil))

    // then: the keys can't scroll the scroll view, so the parent's content keeps the focus
    expect(window.firstResponder) === views.parent.documentView
  }

  func test_click_outsideAWindow_passesUp() throws {
    // given: a scroll view showing content taller than it, outside a window, inside a view that records the clicks it gets
    let container = MouseDownRecordingView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 100, height: 300)
    container.addSubview(scrollView)
    let event = try unwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))

    // when: the scroll view is clicked
    scrollView.mouseDown(with: event)

    // then: without a window to focus in, the click passes up
    expect(container.mouseDownCount) == 1
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

  /// Makes the nested scroll views of `makeNestedScrollViews(in:)` with a parent scroll view that scrolls, beside a view
  /// of the parent's own content, inside a container.
  private static func makeScrollingNestedScrollViews(in window: TestWindow) -> ScrollingNestedScrollViews {
    let container = ScrollWheelRecordingView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    window.contentView().addSubview(container)

    let parent = ScrollWheelCountingScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    parent.contentSize = CGSize(width: 1000, height: 1000)
    parent.contentOffset = CGPoint(x: 400, y: 400)
    container.addSubview(parent)

    let scrollView = ScrollView(frame: CGRect(x: 400, y: 400, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 300, height: 300)
    parent.documentView?.addSubview(scrollView)

    let parentContent = NSView(frame: CGRect(x: 500, y: 400, width: 100, height: 100))
    parent.documentView?.addSubview(parentContent)
    return ScrollingNestedScrollViews(container: container, parent: parent, scrollView: scrollView, parentContent: parentContent)
  }

  /// The timestamp of the latest synthetic scroll event, in nanoseconds, as `CGEvent` keeps it.
  ///
  /// The helpers give the events increasing timestamps, as AppKit's events have, since a gesture that starts shortly
  /// after a trackpad scroll's latest event continues the scroll.
  private static var latestEventTimestamp: CGEventTimestamp = 0

  /// Makes a scroll wheel event that scrolls by the deltas in pixels, with the phases, the interval after the latest
  /// event. An event without phases is a mouse wheel event.
  private static func makeScrollEvent(
    phase: CGScrollPhase? = nil,
    momentumPhase: CGMomentumScrollPhase? = nil,
    deltaX: Int32 = 0,
    deltaY: Int32 = 0,
    after interval: TimeInterval
  ) throws -> NSEvent {
    let cgEvent = try unwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0))
    if let phase {
      cgEvent.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(phase.rawValue))
    }
    if let momentumPhase {
      cgEvent.setIntegerValueField(.scrollWheelEventMomentumPhase, value: Int64(momentumPhase.rawValue))
    }
    latestEventTimestamp += CGEventTimestamp((interval * 1e9).rounded())
    cgEvent.timestamp = latestEventTimestamp
    return try unwrap(NSEvent(cgEvent: cgEvent))
  }

  /// Sends the events of a trackpad scroll gesture to the view, a second after the latest event: one that begins and
  /// one that changes, both with the deltas, then one that ends.
  private static func sendScrollGesture(to view: NSView, deltaX: Int32 = 0, deltaY: Int32 = 0) throws {
    try view.scrollWheel(with: makeScrollEvent(phase: .began, deltaX: deltaX, deltaY: deltaY, after: Constants.scrollInterval))
    try view.scrollWheel(with: makeScrollEvent(phase: .changed, deltaX: deltaX, deltaY: deltaY, after: Constants.eventInterval))
    try view.scrollWheel(with: makeScrollEvent(phase: .ended, after: Constants.eventInterval))
  }

  /// Sends a trackpad flick to the view, a second after the latest event: a gesture with the vertical delta, then its
  /// glide, which ends with the momentum's end.
  private static func sendFlick(to view: NSView, deltaY: Int32) throws {
    try view.scrollWheel(with: makeScrollEvent(phase: .began, deltaY: deltaY, after: Constants.scrollInterval))
    try view.scrollWheel(with: makeScrollEvent(phase: .changed, deltaY: deltaY, after: Constants.eventInterval))
    try view.scrollWheel(with: makeScrollEvent(phase: .ended, after: Constants.eventInterval))
    try view.scrollWheel(with: makeScrollEvent(momentumPhase: .begin, deltaY: deltaY, after: Constants.eventInterval))
    try view.scrollWheel(with: makeScrollEvent(momentumPhase: .continuous, deltaY: deltaY, after: Constants.eventInterval))
    try view.scrollWheel(with: makeScrollEvent(momentumPhase: .end, after: Constants.eventInterval))
  }

  /// Makes a mouse wheel event, which has no phase, scrolling by the deltas in pixels, a second after the latest event.
  private static func makeMouseWheelEvent(deltaX: Int32 = 0, deltaY: Int32 = 0) throws -> NSEvent {
    try makeScrollEvent(deltaX: deltaX, deltaY: deltaY, after: Constants.scrollInterval)
  }

  /// Sends the start of a trackpad swipe to the scroll view, a second after the latest event: an event that begins and
  /// two that change, all with the deltas, turning the run loop after each, since AppKit applies a swipe as the run loop
  /// turns.
  private func beginTrackpadSwipe(on scrollView: ScrollView, deltaX: Int32 = 0, deltaY: Int32 = 0) throws {
    for phase in [CGScrollPhase.began, .changed, .changed] {
      let interval = phase == .began ? Constants.scrollInterval : Constants.eventInterval
      try scrollView.scrollWheel(with: Self.makeScrollEvent(phase: phase, deltaX: deltaX, deltaY: deltaY, after: interval))
      wait(timeout: 0.02)
    }
  }

  /// Sends the end of a trackpad swipe to the scroll view, and turns the run loop.
  private func endTrackpadSwipe(on scrollView: ScrollView) throws {
    try scrollView.scrollWheel(with: Self.makeScrollEvent(phase: .ended, after: Constants.eventInterval))
    wait(timeout: 0.1)
  }

  // MARK: - Constants

  private enum Constants {

    /// The interval between the events of a trackpad gesture, which a trackpad sends at 120 Hz.
    static let eventInterval: TimeInterval = 1.0 / 120

    /// The interval before a scroll that doesn't continue the latest one.
    static let scrollInterval: TimeInterval = 1
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

/// A scroll view that counts the scroll wheel events that reach it, then handles them as a scroll view does.
private final class ScrollWheelCountingScrollView: ScrollView {

  private(set) var scrollWheelEventCount = 0

  override func scrollWheel(with event: NSEvent) {
    scrollWheelEventCount += 1
    super.scrollWheel(with: event)
  }
}

/// A scroll view nested in a parent scroll view that scrolls, beside a view of the parent's own content, inside a
/// container that records the scroll wheel events the parent passes on.
private struct ScrollingNestedScrollViews {

  let container: ScrollWheelRecordingView
  let parent: ScrollWheelCountingScrollView
  let scrollView: ScrollView
  let parentContent: NSView
}

/// A view that takes the keyboard focus, and passes clicks and keys up the responder chain.
private final class FocusableView: NSView {

  override var acceptsFirstResponder: Bool {
    true
  }
}

/// A view that takes the keyboard focus, and interprets its keys, as a text view does.
private final class KeyInterpretingView: NSView {

  private(set) var interpretedKeyCount = 0

  override var acceptsFirstResponder: Bool {
    true
  }

  override func keyDown(with event: NSEvent) {
    interpretedKeyCount += 1
    interpretKeyEvents([event])
  }
}

/// A view that counts the actions of the arrow and page keys that reach it.
private final class KeyActionRecordingView: NSView {

  private(set) var actionCount = 0

  override func moveUp(_ sender: Any?) {
    actionCount += 1
  }

  override func moveDown(_ sender: Any?) {
    actionCount += 1
  }

  override func moveLeft(_ sender: Any?) {
    actionCount += 1
  }

  override func moveRight(_ sender: Any?) {
    actionCount += 1
  }

  override func pageUp(_ sender: Any?) {
    actionCount += 1
  }

  override func pageDown(_ sender: Any?) {
    actionCount += 1
  }
}

/// A view whose coordinates go down from the top, as a ComposeUI scroll view's content does.
private final class FlippedView: NSView {

  override var isFlipped: Bool {
    true
  }
}

private final class MouseDownRecordingView: NSView {

  private(set) var mouseDownCount = 0

  override func mouseDown(with event: NSEvent) {
    mouseDownCount += 1
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
