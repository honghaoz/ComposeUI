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

/// Pins the render work of representative updates: the render passes, the nodes asked for renderable items, the
/// renderables inserted, reused and removed, the text storages edited, and the item ids joined again.
///
/// The counts don't depend on the machine's speed or load, so they hold on any machine. A changed count is a changed
/// cost: update the expected count when the change is intended.
///
/// The rows are 50 points tall in a view of 100 points, so 2 rows show, and a scroll by one row moves one row out and
/// one row in.
class ComposeView_RenderWorkTests: XCTestCase {

  func test_scrollStep_rendersOnce_andChangesOnlyTheRowsMovingInAndOut() {
    // given: rows rendered at the top
    let view = makeRowsView { _ in
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
      let view = makeRowsView(rowCount: rowCount) { _ in
        RenderableItemsProbeNode(state: state, size: CGSize(width: 100, height: Constants.rowHeight))
      }
      view.refresh(animated: false)
      let requestsBeforeScroll = state.renderCallCount

      // when: scrolling by one row
      view.contentOffset = CGPoint(x: 0, y: Constants.rowHeight)
      view.layoutIfNeeded()

      // then: only the 2 rows that show are asked, however many rows there are
      expect(state.renderCallCount - requestsBeforeScroll, "\(rowCount) rows") == 2
    }
  }

  func test_scroll_textRows_makeTextViewsOnlyForTheRowsShownFirst() {
    // given: text rows rendered at the top, with a pool that counts the text views it serves and the ones it can't
    let pool = CountingRenderablePool()
    let view = makeRowsView(pool: pool) { index in
      TextNode("Row \(index)")
        .frame(width: .flexible, height: Constants.rowHeight)
    }
    view.refresh(animated: false)

    for step in 1 ... 10 {
      // when: scrolling by one row
      view.contentOffset = CGPoint(x: 0, y: CGFloat(step) * Constants.rowHeight)
      view.layoutIfNeeded()

      // then: the text views show the texts of the 2 rows in view, from top to bottom
      let shownTexts = view.contentContainerView.subviews
        .compactMap { $0 as? BaseTextView }
        .sorted { $0.frame.minY < $1.frame.minY }
        .map(\.attributedString.string)
      expect(shownTexts) == ["Row \(step)", "Row \(step + 1)"]
    }

    // then: text views are made only for the 2 rows shown first, and each of the 10 rows moving in reuses the text view
    // of the row moving out in place, without the pool
    expect(pool.missCount) == 2
    expect(pool.hitCount) == 0
  }

  #if canImport(AppKit)
  func test_scroll_textRows_leavesTheTextViewsThatStayLaidOut() {
    // given: text rows rendered at the top, with their text views laid out
    let view = makeRowsView { index in
      TextNode("Row \(index)")
        .frame(width: .flexible, height: Constants.rowHeight)
    }
    view.refresh(animated: false)
    view.layoutSubtreeIfNeeded()
    let textViews = view.contentContainerView.subviews.compactMap { $0 as? BaseTextView }
    expect(textViews.count) == 2
    expect(textViews.map(\.needsLayout)) == [false, false]

    // when: scrolling by less than a row, so the 2 rows that show stay in view
    view.contentOffset = CGPoint(x: 0, y: 10)

    // then: their text views don't need a layout, since their texts and sizes are unchanged
    expect(view.contentContainerView.subviews.compactMap { $0 as? BaseTextView }.count) == 3
    expect(textViews.map(\.needsLayout)) == [false, false]
  }
  #endif

  func test_refresh_unchangedContent_updatesTheRenderablesInPlace() {
    // given: rows rendered at the top
    let view = makeRowsView { _ in
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

  func test_refresh_editsOnlyTheTextThatChanged() throws {
    // given: label rows rendered at the top and drawn, with labels that fill their rows, so that a new text keeps a
    // label's size, the first row's text in a variable, and an observer of the edits to the text storages of the 2 rows
    // that show
    var firstRowText = "Row 0"
    let view = makeRowsView { index in
      LabelNode(index == 0 ? firstRowText : "Row \(index)")
        .fixedSize(width: false, height: false)
        .frame(width: .flexible, height: Constants.rowHeight)
    }
    view.refresh(animated: false)
    let labelViews = view.contentContainerView.subviews
      .compactMap { $0 as? TextLabelView }
      .sorted { $0.frame.minY < $1.frame.minY }
    labelViews.forEach { $0.layer().displayIfNeeded() }
    let textStorages = labelViews.map(\.test.textStorage)
    expect(textStorages.count) == 2
    var editsPerRow = [0, 0]
    let observer = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: nil, queue: nil) { notification in
      if let row = textStorages.firstIndex(where: { $0 === notification.object as AnyObject? }) {
        editsPerRow[row] += 1
      }
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
    }

    // when: refreshing with the same content, and drawing
    view.refresh(animated: false)
    labelViews.forEach { $0.layer().displayIfNeeded() }

    // then: the label views of the 2 rows that show keep their text, so their text storages aren't edited
    expect(editsPerRow) == [0, 0]

    // when: changing the first row's text, refreshing, and drawing
    firstRowText = "Changed"
    view.refresh(animated: false)
    labelViews.forEach { $0.layer().displayIfNeeded() }

    // then: only the first row's text storage is edited, to show the new text
    expect(editsPerRow) == [1, 0]
    expect(textStorages.map(\.string)) == ["Changed", "Row 1"]
  }

  func test_refresh_rowsWithIds_haveTheIdsThatTheRefreshBeforeJoined() {
    // given: rows with ids past the 15 bytes that a string stores inline, rendered at the top, and refreshed, after which
    // the view keeps the ids that the stack joins
    let view = makeRowsView { index in
      ColorNode(.red)
        .frame(width: .flexible, height: Constants.rowHeight)
        .id("a row id past the inline limit \(index)")
    }
    view.refresh(animated: false)
    let keptIds = renderedIds(of: view) {
      view.refresh(animated: false)
    }

    // when: refreshing again
    let ids = renderedIds(of: view) {
      view.refresh(animated: false)
    }

    // then: the 2 rows that show have their joined ids, the ones that the view kept, which the refresh didn't make again
    expect(ids.map(\.id)) == ["VS|0|a row id past the inline limit 0|C", "VS|1|a row id past the inline limit 1|C"]
    expect(keptIds.contains { $0.id.storageAddress == nil }) == false
    expect(ids.map(\.id.storageAddress)) == keptIds.map(\.id.storageAddress)
  }

  func test_scroll_rowsWithIds_haveTheIdsThatTheViewKeptForTheRowsThatStay() {
    // given: rows with ids past the inline limit, rendered at the top and refreshed, after which the view keeps the ids
    // that the stack joins
    let view = makeRowsView { index in
      ColorNode(.red)
        .frame(width: .flexible, height: Constants.rowHeight)
        .id("a row id past the inline limit \(index)")
    }
    view.refresh(animated: false)
    let keptIds = renderedIds(of: view) {
      view.refresh(animated: false)
    }

    // when: scrolling by less than a row, so the 2 rows that show stay and a third row shows
    let ids = renderedIds(of: view) {
      view.contentOffset = CGPoint(x: 0, y: 10)
      view.layoutIfNeeded()
    }

    // then: the rows have their joined ids, and the rows that stay have the ones that the view kept
    expect(ids.map(\.id)) == [
      "VS|0|a row id past the inline limit 0|C",
      "VS|1|a row id past the inline limit 1|C",
      "VS|2|a row id past the inline limit 2|C",
    ]
    expect(keptIds.contains { $0.id.storageAddress == nil }) == false
    expect(ids.prefix(2).map(\.id.storageAddress)) == keptIds.map(\.id.storageAddress)
  }

  func test_refresh_rowWithANewId_hasTheJoinedIdOfItsNewId() {
    // given: rows with ids past the inline limit, the first row's id in a variable, rendered at the top and refreshed,
    // after which the view keeps the ids that the stack joins
    var firstRowId = "a row id past the inline limit 0"
    let view = makeRowsView { index in
      ColorNode(.red)
        .frame(width: .flexible, height: Constants.rowHeight)
        .id(index == 0 ? firstRowId : "a row id past the inline limit \(index)")
    }
    view.refresh(animated: false)
    let keptIds = renderedIds(of: view) {
      view.refresh(animated: false)
    }

    // when: changing the first row's id, and refreshing
    firstRowId = "a new row id past the inline limit"
    let ids = renderedIds(of: view) {
      view.refresh(animated: false)
    }

    // then: the first row has the joined id of its new id, and the second row has the id that the view kept
    expect(ids.map(\.id)) == ["VS|0|a new row id past the inline limit|C", "VS|1|a row id past the inline limit 1|C"]
    expect(ids.last?.id.storageAddress) == keptIds.last?.id.storageAddress
  }

  // MARK: - Helpers

  private enum Constants {

    static let rowCount = 60
    static let rowHeight: CGFloat = 50
    static let viewSize = CGSize(width: 100, height: 100)
  }

  /// A view of rows in a vertical stack, with its own renderable pool.
  private func makeRowsView(rowCount: Int = Constants.rowCount, pool: RenderablePoolType = RenderablePool(), row: @escaping (Int) -> some ComposeNode) -> ComposeView {
    let view = ComposeView {
      VStack {
        for index in 0 ..< rowCount {
          row(index)
        }
      }
    }
    view.renderablePool = pool // isolate from the shared pool, so earlier tests don't affect the reuse
    view.frame = CGRect(origin: .zero, size: Constants.viewSize)
    return view
  }

  /// Returns the ids of the items of the view's last render pass while the body runs.
  private func renderedIds(of view: ComposeView, during body: () -> Void) -> [ComposeNodeId] {
    var ids: [ComposeNodeId] = []
    view.debug { _, event in
      switch event {
      case .renderDidFinish(let renderableItemIds, _, _):
        ids = renderableItemIds
      default:
        break
      }
    }
    body()
    return ids
  }
}

/// A renderable pool that counts the renderables it serves, and the requests it can't serve.
private final class CountingRenderablePool: RenderablePoolType {

  private(set) var hitCount = 0
  private(set) var missCount = 0

  private let backing = RenderablePool()

  func enqueue(_ renderable: Renderable, key: ReuseKey) {
    backing.enqueue(renderable, key: key)
  }

  func dequeue(_ key: ReuseKey) -> Renderable? {
    if let renderable = backing.dequeue(key) {
      hitCount += 1
      return renderable
    } else {
      missCount += 1
      return nil
    }
  }
}
