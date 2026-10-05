//
//  ComposeView+RenderWorkTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/4/26.
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

/// Pins the render work of representative updates: the render passes, the nodes asked for renderable items, and the
/// renderables inserted, reused and removed.
///
/// The counts don't depend on the machine's speed or load, so they hold on any machine. A changed count is a changed
/// cost: update the expected count when the change is intended.
///
/// The rows are 50 points tall in a view of 100 points, so 2 rows show, and a scroll by one row moves one row out and
/// one row in.
class ComposeView_RenderWorkTests: XCTestCase {

  func test_scrollStep_rendersOnce_andChangesOnlyTheRowsMovingInAndOut() {
    // given: rows rendered at the top
    let view = makeRowsView {
      ColorNode(.red)
        .frame(width: .flexible, height: Constants.rowHeight)
    }
    view.refresh(animated: false)
    let events = RenderEventCounter(view: view)

    // when: scrolling by one row
    view.contentOffset = CGPoint(x: 0, y: Constants.rowHeight)
    view.layoutIfNeeded()

    // then: one render pass makes the items of the 2 rows that show, inserts the row moving in, removes the row moving
    // out, and updates the row that stays
    expect(events.renderPasses) == 1
    expect(events.renderableItems) == 2
    expect(events.inserts) == 1
    expect(events.removals) == 1
    expect(events.reuses) == 1
  }

  func test_scrollStep_asksOnlyTheVisibleRowsForRenderableItems_regardlessOfTheRowCount() {
    for rowCount in [Constants.rowCount, 10000] {
      // given: rows that count the requests for their renderable items, rendered at the top
      let state = RenderableItemsProbeNode.State()
      let view = makeRowsView(rowCount: rowCount) {
        RenderableItemsProbeNode(state: state, size: CGSize(width: 100, height: Constants.rowHeight))
      }
      view.refresh(animated: false)
      let requestsBeforeScroll = state.renderableItemsCallCount

      // when: scrolling by one row
      view.contentOffset = CGPoint(x: 0, y: Constants.rowHeight)
      view.layoutIfNeeded()

      // then: only the 2 rows that show are asked, however many rows there are
      expect(state.renderableItemsCallCount - requestsBeforeScroll, "\(rowCount) rows") == 2
    }
  }

  func test_refresh_unchangedContent_updatesTheRenderablesInPlace() {
    // given: rows rendered at the top
    let view = makeRowsView {
      ColorNode(.red)
        .frame(width: .flexible, height: Constants.rowHeight)
    }
    view.refresh(animated: false)
    let events = RenderEventCounter(view: view)

    // when: refreshing with the same content
    let counts = WorkCounter.counting {
      view.refresh(animated: false)
    }

    // then: one render pass updates the 2 rows that show in place, inserting, removing and animating nothing
    expect(events.renderPasses) == 1
    expect(events.renderableItems) == 2
    expect(events.reuses) == 2
    expect(events.inserts) == 0
    expect(events.removals) == 0
    expect(counts.animations) == 0
  }

  // MARK: - Helpers

  private enum Constants {

    static let rowCount = 60
    static let rowHeight: CGFloat = 50
    static let viewSize = CGSize(width: 100, height: 100)
  }

  /// A view of rows in a vertical stack, with its own renderable pool.
  private func makeRowsView(rowCount: Int = Constants.rowCount, row: @escaping () -> some ComposeNode) -> ComposeView {
    let view = ComposeView {
      VStack {
        for _ in 0 ..< rowCount {
          row()
        }
      }
    }
    view.renderablePool = RenderablePool() // isolate from the shared pool, so earlier tests don't affect the reuse
    view.frame = CGRect(origin: .zero, size: Constants.viewSize)
    return view
  }
}
