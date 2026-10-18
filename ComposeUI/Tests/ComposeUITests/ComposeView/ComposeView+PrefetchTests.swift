//
//  ComposeView+PrefetchTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/17/26.
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

class ComposeView_PrefetchTests: XCTestCase {

  // MARK: - Region

  func test_render_prefetchesTheItemsPastTheVisibleBounds() {
    // given: a compose view in a window, 200 by 300 points, showing 100 rows of items that prefetch, 30 points each
    let (window, view, recorder) = makeRowsView()

    // when: the view renders
    view.refresh(animated: false)

    // then: the view prefetches the region one view height past each edge, which has the 10 rows below the visible
    // bounds, since the content starts at the top, at their frames
    let region = CGRect(x: 0, y: -300, width: 200, height: 900)
    expect(view.test.prefetchedBounds) == region
    expect(recorder.prefetches) == (10 ..< 20).map { PrefetchRecorder.Prefetch(row: $0, frame: Self.rowFrame($0), region: region) }
    withExtendedLifetime(window) {}
  }

  func test_scroll_prefetchesOnlyTheItemsThatEnterTheRegion() {
    // given: a rendered compose view in a window, showing rows of items that prefetch, scrolled down by a view height
    let (window, view, recorder) = makeRowsView()
    view.refresh(animated: false)
    scroll(view, to: 300)
    recorder.removeAll()

    // when: scrolling down by a row
    scroll(view, to: 330)

    // then: the region moves by a row, and only the row that entered it is prefetched, instead of also the row that
    // scrolled out of view into it
    expect(view.test.prefetchedBounds) == CGRect(x: 0, y: 30, width: 200, height: 900)
    expect(recorder.rows) == [30]

    // when: scrolling back up by a row
    recorder.removeAll()
    scroll(view, to: 300)

    // then: the row that enters the region at the top is prefetched
    expect(view.test.prefetchedBounds) == CGRect(x: 0, y: 0, width: 200, height: 900)
    expect(recorder.rows) == [0]
    withExtendedLifetime(window) {}
  }

  func test_scroll_pastTheRegion_prefetchesTheWholeRegionButTheVisibleBounds() {
    // given: a rendered compose view in a window, showing rows of items that prefetch
    let (window, view, recorder) = makeRowsView()
    view.refresh(animated: false)
    recorder.removeAll()

    // when: jumping past the region
    scroll(view, to: 1500)

    // then: the rows of the region around the new visible bounds are prefetched, past each of its edges
    expect(view.test.prefetchedBounds) == CGRect(x: 0, y: 1200, width: 200, height: 900)
    expect(recorder.rows) == Array(40 ..< 50) + Array(60 ..< 70)
    withExtendedLifetime(window) {}
  }

  func test_refresh_prefetchesOnlyThePartOfTheRegionThatMoves() {
    // given: a rendered compose view in a window, showing rows of items that prefetch
    let (window, view, recorder) = makeRowsView()
    view.refresh(animated: false)
    recorder.removeAll()

    // when: refreshing
    view.refresh(animated: false)

    // then: the region doesn't move, so no item is prefetched again
    expect(view.test.prefetchedBounds) == CGRect(x: 0, y: -300, width: 200, height: 900)
    expect(recorder.rows) == []
    withExtendedLifetime(window) {}
  }

  func test_scroll_prefetchedFrame_isTheFrameThatTheViewSets() throws {
    // given: a rendered compose view in a window, showing rows of items that prefetch, of a height that isn't in whole
    // pixels
    let recorder = PrefetchRecorder()
    let (window, view) = makeView(size: CGSize(width: 200, height: 300)) {
      VStack {
        for row in 0 ..< 100 {
          PrefetchingNode(row: row, recorder: recorder)
            .frame(width: .flexible, height: 30.3)
        }
      }
    }
    view.refresh(animated: false)
    let prefetch = try recorder.prefetches.last.unwrap()

    // when: scrolling the last prefetched row into view
    scroll(view, to: prefetch.frame.minY)

    // then: the row's layer has the frame that the row was prefetched at
    let layers = view.contentContainerView.layer().sublayers ?? []
    expect(layers.contains { $0.frame == prefetch.frame }) == true
    withExtendedLifetime(window) {}
  }

  // MARK: - Content

  func test_render_contentThatDoesntScroll_doesntPrefetch() {
    // given: a compose view in a window, showing rows of items that prefetch, which fit
    let (window, view, recorder) = makeRowsView(rowCount: 5)

    // when: the view renders
    view.refresh(animated: false)

    // then: the view doesn't prefetch
    expect(view.test.prefetchedBounds) == nil
    expect(recorder.rows) == []
    withExtendedLifetime(window) {}
  }

  func test_render_contentThatScrollsHorizontally_prefetchesAlongTheXAxis() {
    // given: a compose view in a window, 200 by 30 points, showing a row of 100 items that prefetch, 40 points each
    let recorder = PrefetchRecorder()
    let (window, view) = makeView(size: CGSize(width: 200, height: 30)) {
      HStack {
        for column in 0 ..< 100 {
          PrefetchingNode(row: column, recorder: recorder)
            .frame(width: 40, height: .flexible)
        }
      }
    }

    // when: the view renders
    view.refresh(animated: false)

    // then: the view prefetches the region one view width past each edge, which has the 5 items after the visible bounds
    let region = CGRect(x: -200, y: 0, width: 600, height: 30)
    expect(view.test.prefetchedBounds) == region
    expect(recorder.prefetches) == (5 ..< 10).map {
      PrefetchRecorder.Prefetch(row: $0, frame: CGRect(x: CGFloat($0) * 40, y: 0, width: 40, height: 30), region: region)
    }
    withExtendedLifetime(window) {}
  }

  func test_render_centeredContent_prefetchesTheFramesInTheView() {
    // given: a compose view in a window, 200 points wide, showing rows of items that prefetch, 100 points wide, which the
    // view centers
    let recorder = PrefetchRecorder()
    let (window, view) = makeView(size: CGSize(width: 200, height: 300)) {
      VStack {
        for row in 0 ..< 100 {
          PrefetchingNode(row: row, recorder: recorder)
            .frame(width: 100, height: 30)
        }
      }
    }

    // when: the view renders
    view.refresh(animated: false)

    // then: the rows below the visible bounds are prefetched at their frames in the view, which the centering moves
    expect(recorder.prefetches.map(\.frame)) == (10 ..< 20).map { CGRect(x: 50, y: CGFloat($0) * 30, width: 100, height: 30) }
    withExtendedLifetime(window) {}
  }

  func test_render_contentWithoutItemsThatPrefetch_doesntLookAhead() {
    // given: a compose view in a window, showing rows of items that don't prefetch
    let (window, view, _) = makeRowsView(prefetchingRows: 0 ..< 0)

    // when: the view renders, and scrolls
    view.refresh(animated: false)
    scroll(view, to: 300)

    // then: the view doesn't look ahead, since no item would prepare its content
    expect(view.test.prefetchedBounds) == nil
    withExtendedLifetime(window) {}
  }

  func test_scroll_firstItemThatPrefetchesShows_startsLookingAhead() {
    // given: a rendered compose view in a window, showing 20 rows of items that don't prefetch, then rows of items that
    // do, scrolled down by a view height
    let (window, view, recorder) = makeRowsView(prefetchingRows: 20 ..< 100)
    view.refresh(animated: false)
    scroll(view, to: 300)
    expect(view.test.prefetchedBounds) == nil

    // when: scrolling the first row of an item that prefetches into view
    scroll(view, to: 330)

    // then: the view prefetches the whole region but the visible bounds, where the rows of items that prefetch are below
    expect(view.test.prefetchedBounds) == CGRect(x: 0, y: 30, width: 200, height: 900)
    expect(recorder.rows) == Array(21 ..< 31)

    // when: scrolling back up, where no item prefetches
    scroll(view, to: 0)

    // then: the view keeps looking ahead
    expect(view.test.prefetchedBounds) == CGRect(x: 0, y: -300, width: 200, height: 900)
    withExtendedLifetime(window) {}
  }

  // MARK: - Window

  func test_render_outOfAWindow_doesntPrefetch() {
    // given: a compose view out of a window, showing rows of items that prefetch
    let (window, view, recorder) = makeRowsView()
    view.removeFromSuperview()

    // when: the view renders
    view.refresh(animated: false)

    // then: the view doesn't prefetch, since no item shows out of a window
    expect(view.test.prefetchedBounds) == nil
    expect(recorder.rows) == []
    withExtendedLifetime(window) {}
  }

  func test_moveToAnotherWindow_prefetchesTheWholeRegionAgain() {
    // given: a rendered compose view in a window, showing rows of items that prefetch, with a prefetch cache
    let (window, view, recorder) = makeRowsView()
    view.refresh(animated: false)
    _ = view.prefetchCache { NSObject() }
    recorder.removeAll()

    // when: the view moves to another window, and renders
    let otherWindow = TestWindow()
    otherWindow.contentView().addSubview(view)
    view.refresh(animated: false)

    // then: the view releases its prefetch caches, and prefetches the whole region again, since the items prepare their
    // content for the window that shows it
    expect(view.prefetchCache(of: NSObject.self)) == nil
    expect(recorder.rows) == Array(10 ..< 20)
    withExtendedLifetime((window, otherWindow)) {}
  }

  func test_moveOutOfTheWindow_releasesThePrefetchCaches() {
    // given: a rendered compose view in a window, showing rows of items that prefetch, with a prefetch cache
    let (window, view, _) = makeRowsView()
    view.refresh(animated: false)
    _ = view.prefetchCache { NSObject() }

    // when: the view moves out of the window
    view.removeFromSuperview()

    // then: the view releases its prefetch caches, and prefetches again when it's in a window
    expect(view.prefetchCache(of: NSObject.self)) == nil
    expect(view.test.prefetchedBounds) == nil
    withExtendedLifetime(window) {}
  }

  // MARK: - Prefetch Caches

  func test_prefetchCache_makesTheCacheOfATypeOnce() {
    // given: a compose view without prefetch caches
    let view = ComposeView()
    expect(view.prefetchCache(of: NSObject.self)) == nil

    // when: asking for a cache of a type twice
    let cache = view.prefetchCache { NSObject() }
    let secondCache = view.prefetchCache { () -> NSObject in
      fail("the cache is made once")
      return NSObject()
    }

    // then: the view keeps the cache that it made the first time
    expect(secondCache) === cache
    expect(view.prefetchCache(of: NSObject.self)) === cache
    expect(view.prefetchCache(of: NSString.self)) == nil
  }

  // MARK: - Helpers

  /// Returns the frame of a row in the rows view.
  private static func rowFrame(_ row: Int) -> CGRect {
    CGRect(x: 0, y: CGFloat(row) * 30, width: 200, height: 30)
  }

  /// Returns a compose view in a window, 200 by 300 points, showing rows, 30 points each, of items that prefetch or
  /// don't.
  ///
  /// - Parameters:
  ///   - rowCount: The number of rows.
  ///   - prefetchingRows: The rows of items that prefetch, all rows by default.
  /// - Returns: The window, the view, and the recorder of the items' prefetches.
  private func makeRowsView(rowCount: Int = 100, prefetchingRows: Range<Int>? = nil) -> (TestWindow, ComposeView, PrefetchRecorder) {
    let recorder = PrefetchRecorder()
    let makeRow: (Int) -> any ComposeNode = { row in
      if prefetchingRows?.contains(row) ?? true {
        return PrefetchingNode(row: row, recorder: recorder)
          .frame(width: .flexible, height: 30)
      } else {
        return ColorNode(.red)
          .frame(width: .flexible, height: 30)
      }
    }
    let (window, view) = makeView(size: CGSize(width: 200, height: 300)) {
      VStack {
        for row in 0 ..< rowCount {
          makeRow(row)
        }
      }
    }
    return (window, view, recorder)
  }

  /// Returns a compose view in a window, with its own renderable pool.
  private func makeView(size: CGSize, @ComposeContentBuilder content: @escaping () -> ComposeContent) -> (TestWindow, ComposeView) {
    let window = TestWindow()
    let view = ComposeView(content: content)
    view.renderablePool = RenderablePool()
    view.frame = CGRect(origin: .zero, size: size)
    window.contentView().addSubview(view)
    return (window, view)
  }

  /// Scrolls a view vertically, and renders it.
  private func scroll(_ view: ComposeView, to offset: CGFloat) {
    view.contentOffset = CGPoint(x: 0, y: offset)
    view.layoutIfNeeded()
  }
}

// MARK: - PrefetchingNode

/// A node that fills its container, whose item records where it's prefetched.
private struct PrefetchingNode: ComposeNode {

  private let row: Int
  private let recorder: PrefetchRecorder

  init(row: Int, recorder: PrefetchRecorder) {
    self.row = row
    self.recorder = recorder
  }

  var id: ComposeNodeId = .custom("prefetching")

  private(set) var size: CGSize = .zero

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    size = containerSize
    return ComposeNodeSizing(width: .flexible, height: .flexible)
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
    let frame = CGRect(origin: .zero, size: size)
    guard visibleBounds.intersects(frame) else {
      return
    }

    let row = row
    let recorder = recorder
    let item = LayerItem<CALayer>(
      id: id,
      frame: frame,
      make: { _ in CALayer() },
      prefetch: { context in
        recorder.record(PrefetchRecorder.Prefetch(row: row, frame: context.frame, region: context.region))
      },
      update: { _, _ in }
    )
    items.append(item.eraseToRenderableItem())
  }
}

// MARK: - PrefetchRecorder

/// The prefetches of the items of rows, in order.
private final class PrefetchRecorder {

  struct Prefetch: Equatable {

    /// The row of the item.
    let row: Int

    /// The frame that the item was prefetched at.
    let frame: CGRect

    /// The region that the item was prefetched in.
    let region: CGRect
  }

  private(set) var prefetches: [Prefetch] = []

  /// The rows of the prefetched items, in order.
  var rows: [Int] {
    prefetches.map(\.row)
  }

  func record(_ prefetch: Prefetch) {
    prefetches.append(prefetch)
  }

  func removeAll() {
    prefetches.removeAll()
  }
}
