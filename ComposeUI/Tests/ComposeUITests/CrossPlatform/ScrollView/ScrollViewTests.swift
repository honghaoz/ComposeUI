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

  func test_contentOffset_outsideScrollableRange() {
    // given: a 100 × 200 scroll view showing a 300 × 500 content
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
    scrollView.contentSize = CGSize(width: 300, height: 500)

    // when: setting a content offset past the start of the horizontal range and the end of the vertical range
    scrollView.contentOffset = CGPoint(x: -50, y: 1000)

    // then: AppKit keeps the offset within the scrollable range, and UIKit keeps it as set
    #if canImport(AppKit)
    expect(scrollView.contentOffset) == CGPoint(x: 0, y: 300)
    #endif
    #if canImport(UIKit)
    expect(scrollView.contentOffset) == CGPoint(x: -50, y: 1000)
    #endif
  }

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

    // when: scrolling is disabled and the scroll view gets a scroll wheel event
    scrollView.isScrollEnabled = false
    scrollView.scrollWheel(with: event)

    // then: the event passes to the next responder, and the scroll view doesn't scroll
    expect(container.scrollWheelEventCount) == 1
    expect(scrollView.contentOffset) == .zero

    // when: scrolling is enabled and the scroll view gets the event again
    scrollView.isScrollEnabled = true
    scrollView.scrollWheel(with: event)

    // then: the scroll view handles the event instead of passing it on
    expect(container.scrollWheelEventCount) == 1
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
  #endif

  // MARK: - Helpers

  /// The insets as `[top, left, bottom, right]`, since `NSEdgeInsets` isn't `Equatable`.
  private static func components(of insets: EdgeInsets) -> [CGFloat] {
    [insets.top, insets.left, insets.bottom, insets.right]
  }
}

#if canImport(AppKit)
private final class ScrollWheelRecordingView: NSView {

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
