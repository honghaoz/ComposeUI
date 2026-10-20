//
//  ComposeView+InPlaceReuseTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/18/26.
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

/// Tests for the reuse of a view in place, by an item that the render pass that removes the view inserts.
///
/// The rows are 50 points tall in a view of 100 points, so 2 rows show, and a scroll by one row moves one row out and
/// one row in, in one render pass.
class ComposeView_InPlaceReuseTests: XCTestCase {

  // MARK: - Render pass

  func test_scroll_reusesTheViewOfTheRowMovingOutInPlace() throws {
    // given: rows of reusable views in a window, rendered at the top, with a pool that records its use
    let pool = RecordingPool()
    let (window, view) = makeRowsView(pool: pool)
    view.refresh(animated: false)
    let rowZeroView = try rowView(showing: 0, in: view).unwrap()
    let moveCount = rowZeroView.moveCount
    let dequeueCount = pool.dequeueCount

    // when: scrolling by one row, which moves row 0 out and row 2 in
    scroll(view, to: Constants.rowHeight)

    // then: row 2 shows in the view of row 0, which stayed in the window, without going through the pool
    expect(rowView(showing: 2, in: view)) === rowZeroView
    expect(rowZeroView.frame) == CGRect(x: 0, y: 2 * Constants.rowHeight, width: Constants.viewSize.width, height: Constants.rowHeight)
    expect(rowZeroView.moveCount) == moveCount
    expect(pool.enqueued.count) == 0
    expect(pool.dequeueCount) == dequeueCount
    expect(window.contentView().subviews.contains(view)) == true
  }

  func test_scroll_viewWithAnAppReuseIdentifier_leavesAsBefore() throws {
    // given: rows of views with an app's reuse identifier in a window, rendered at the top, with a pool that records its
    // use
    let pool = RecordingPool()
    let (window, view) = makeAppRowsView(pool: pool, inPlace: false)
    view.refresh(animated: false)
    let rowZeroView = try rowView(showing: 0, in: view).unwrap()
    let moveCount = rowZeroView.moveCount

    // when: scrolling by one row, which moves row 0 out and row 2 in
    scroll(view, to: Constants.rowHeight)

    // then: the view of row 0 was removed, and came back from the pool for row 2
    expect(rowView(showing: 2, in: view)) === rowZeroView
    expect(rowZeroView.moveCount) > moveCount
    expect(pool.enqueued.count) == 1
    expect(pool.enqueued.first?.renderable.view) === rowZeroView
    expect(pool.enqueued.first?.key.reuseId) == ReuseId(namespace: .user, id: "row")
    expect(window.contentView().subviews.contains(view)) == true
  }

  func test_scroll_viewThatTheAppReusesInPlace_staysInPlace() throws {
    // given: rows of views that the app reuses in place, in a window, rendered at the top, with a pool that records its
    // use
    let pool = RecordingPool()
    let (window, view) = makeAppRowsView(pool: pool, inPlace: true)
    view.refresh(animated: false)
    let rowZeroView = try rowView(showing: 0, in: view).unwrap()
    let moveCount = rowZeroView.moveCount
    let dequeueCount = pool.dequeueCount

    // when: scrolling by one row, which moves row 0 out and row 2 in
    scroll(view, to: Constants.rowHeight)

    // then: row 2 shows in the view of row 0, which stayed in the window, without going through the pool
    expect(rowView(showing: 2, in: view)) === rowZeroView
    expect(rowZeroView.frame) == CGRect(x: 0, y: 2 * Constants.rowHeight, width: Constants.viewSize.width, height: Constants.rowHeight)
    expect(rowZeroView.moveCount) == moveCount
    expect(pool.enqueued.count) == 0
    expect(pool.dequeueCount) == dequeueCount
    expect(window.contentView().subviews.contains(view)) == true
  }

  func test_scroll_keepsTheViewsInTheItemsOrder() {
    // given: rows of reusable views in a window, rendered at row 2, so that a scroll can move either way
    let (window, view) = makeRowsView(pool: RecordingPool())
    view.refresh(animated: false)
    #if canImport(AppKit)
    // AppKit adds the views' layers to their superviews' layers when it displays, and sorts them in the subview order,
    // so it displays before the moves, to check that each move orders the layers by itself
    window.displayIfNeeded()
    #endif
    scroll(view, to: 2 * Constants.rowHeight)
    expect(rowsInSubviewOrder(of: view)) == [2, 3]
    expect(rowsInSublayerOrder(of: view)) == [2, 3]

    // when: scrolling down by one row, which moves the view of row 2 to the front, for row 4
    scroll(view, to: 3 * Constants.rowHeight)

    // then: the views and their layers are in the rows' order
    expect(rowsInSubviewOrder(of: view)) == [3, 4]
    expect(rowsInSublayerOrder(of: view)) == [3, 4]

    // when: scrolling up by one row, which moves the view of row 4 below the view of row 3, for row 2
    scroll(view, to: 2 * Constants.rowHeight)

    // then: the views and their layers are in the rows' order
    expect(rowsInSubviewOrder(of: view)) == [2, 3]
    expect(rowsInSublayerOrder(of: view)) == [2, 3]
    expect(window.contentView().subviews.contains(view)) == true
  }

  func test_removal_withoutAnInsertionOfItsKind_poolsTheViewAtTheEndOfThePass() throws {
    // given: rows of reusable views, rendered at the top, with a pool that records its use, and a render handler that
    // records whether the view of row 1 is in the content view as the pass ends
    let pool = RecordingPool()
    let (window, view) = makeRowsView(pool: pool)
    view.refresh(animated: false)
    let rowOneView = try rowView(showing: 1, in: view).unwrap()
    var isInContentViewAsThePassEnds: Bool?
    view.onDidRender { view, _ in
      isInContentViewAsThePassEnds = rowOneView.superview === view.contentContainerView
    }

    // when: the view shrinks to one row, which moves row 1 out without moving a row in
    view.frame.size.height = Constants.rowHeight
    view.layoutIfNeeded()

    // then: the view of row 1 left the content view before the pass ended, for the pool
    expect(isInContentViewAsThePassEnds) == false
    expect(rowOneView.superview) == nil
    expect(pool.enqueued.count) == 1
    expect(pool.enqueued.first?.renderable.view) === rowOneView
    expect(pool.enqueued.first?.key.reuseId) == Constants.rowReuseId
    expect(window.contentView().subviews.contains(view)) == true
  }

  func test_scroll_callsTheRemovalBlocksWithTheViewInPlace() throws {
    // given: rows of reusable views, rendered at the top, whose removal blocks record whether their view is in the
    // content view
    var isInContentViewOnRemove: [Bool] = []
    var isInContentViewOnReset: [Bool] = []
    weak var weakView: ComposeView?
    let (window, view) = makeRowsView(
      pool: RecordingPool(),
      onRemove: { renderable, context in
        isInContentViewOnRemove.append(renderable.view?.superview === context.contentView.contentContainerView)
      },
      onResetForReuse: { renderable in
        isInContentViewOnReset.append(renderable.view?.superview === weakView?.contentContainerView)
      }
    )
    weakView = view
    view.refresh(animated: false)
    let rowZeroView = try rowView(showing: 0, in: view).unwrap()

    // when: scrolling by one row, which moves row 0 out and row 2 in
    scroll(view, to: Constants.rowHeight)

    // then: the view of row 0 was in the content view for its removal blocks, and then showed row 2
    expect(isInContentViewOnRemove) == [true]
    expect(isInContentViewOnReset) == [true]
    expect(rowView(showing: 2, in: view)) === rowZeroView
    expect(window.contentView().subviews.contains(view)) == true
  }

  func test_removeTransition_finishingDuringThePass_reusesTheViewInPlace() throws {
    // given: a reusable view with a remove transition that finishes as it starts, rendered for item a
    let pool = RecordingPool()
    let transition = RenderableTransition(
      insert: nil,
      remove: RenderableTransition.RemoveTransition { _, _, completion in
        completion()
      }
    )
    var id = "a"
    let (window, view) = makeView(pool: pool) {
      RowNode(row: 0, reuseId: Constants.rowReuseId).id(id).transition(transition)
    }
    view.refresh(animated: false)
    let itemAView = try rowView(showing: 0, in: view).unwrap()
    let moveCount = itemAView.moveCount
    let dequeueCount = pool.dequeueCount

    // when: an animated refresh replaces item a with item b, of the same kind
    id = "b"
    view.refresh(animated: true)

    // then: item b shows in the view of item a, which stayed in place, without going through the pool
    expect(view.contentContainerView.subviews.compactMap { $0 as? RowView }) == [itemAView]
    expect(itemAView.moveCount) == moveCount
    expect(pool.enqueued.count) == 0
    expect(pool.dequeueCount) == dequeueCount
    expect(window.contentView().subviews.contains(view)) == true
  }

  func test_removeTransition_finishingAfterThePass_poolsTheView() throws {
    // given: a reusable view with a remove transition that finishes later, rendered for item a
    let pool = RecordingPool()
    var finishRemoval: (() -> Void)?
    let transition = RenderableTransition(
      insert: nil,
      remove: RenderableTransition.RemoveTransition { _, _, completion in
        finishRemoval = completion
      }
    )
    var id = "a"
    let (window, view) = makeView(pool: pool) {
      RowNode(row: 0, reuseId: Constants.rowReuseId).id(id).transition(transition)
    }
    view.refresh(animated: false)
    let itemAView = try rowView(showing: 0, in: view).unwrap()

    // when: an animated refresh replaces item a with item b, of the same kind
    id = "b"
    view.refresh(animated: true)

    // then: item b shows in a new view, while the view of item a animates out
    let rowViews = view.contentContainerView.subviews.compactMap { $0 as? RowView }
    expect(rowViews.count) == 2
    expect(rowViews.contains(itemAView)) == true
    expect(pool.enqueued.count) == 0

    // when: the removal finishes, after the pass
    finishRemoval?()

    // then: the view of item a left the content view, for the pool
    expect(itemAView.superview) == nil
    expect(pool.enqueued.count) == 1
    expect(pool.enqueued.first?.renderable.view) === itemAView
    expect(window.contentView().subviews.contains(view)) == true
  }

  func test_removeTransition_finishingInTheRenderHandler_poolsTheView() throws {
    // given: a reusable view with a remove transition that finishes later, rendered for item a, and a render handler
    // that finishes the removal, which runs after the pass's insertions
    let pool = RecordingPool()
    var finishRemoval: (() -> Void)?
    let transition = RenderableTransition(
      insert: nil,
      remove: RenderableTransition.RemoveTransition { _, _, completion in
        finishRemoval = completion
      }
    )
    var id = "a"
    let (window, view) = makeView(pool: pool) {
      RowNode(row: 0, reuseId: Constants.rowReuseId).id(id).transition(transition)
    }
    view.refresh(animated: false)
    let itemAView = try rowView(showing: 0, in: view).unwrap()
    view.onDidRender { _, _ in
      finishRemoval?()
      finishRemoval = nil
    }

    // when: an animated refresh replaces item a with item b, of the same kind
    id = "b"
    view.refresh(animated: true)

    // then: the view of item a left the content view, for the pool, since no insertion could take it anymore
    expect(itemAView.superview) == nil
    expect(pool.enqueued.count) == 1
    expect(pool.enqueued.first?.renderable.view) === itemAView
    expect(window.contentView().subviews.contains(view)) == true
  }

  func test_insertTransition_ofAViewReusedInPlace_startsAtTheFinalFrame() throws {
    // given: a reusable view with an insert transition and no remove transition, rendered for item a, where the
    // transition records the view and its frame when it starts
    var starts: [(view: View?, frame: CGRect, context: RenderableTransition.InsertTransition.Context)] = []
    let transition = RenderableTransition(
      insert: RenderableTransition.InsertTransition { renderable, context, completion in
        starts.append((renderable.view, renderable.frame, context))
        completion()
      },
      remove: nil
    )
    var id = "a"
    var top: CGFloat = 0
    let (window, view) = makeView(pool: RecordingPool()) {
      RowNode(row: 0, reuseId: Constants.rowReuseId).id(id).transition(transition).frame(width: 100, height: 50).padding(top: top)
    }
    view.refresh(animated: false)
    let itemAView = try rowView(showing: 0, in: view).unwrap()
    let itemAFrame = itemAView.frame
    let moveCount = itemAView.moveCount
    starts.removeAll()

    // when: an animated refresh replaces item a with item b, of the same kind, 30 points lower
    id = "b"
    top = 30
    view.refresh(animated: true)

    // then: the insert transition started for item b in the view of item a, which stayed in place, already at item b's
    // frame, as a fresh insertion
    expect(starts.count) == 1
    let start = try starts.first.unwrap()
    expect(start.view) === itemAView
    expect(start.frame) == start.context.targetFrame
    expect(start.context.targetFrame) == itemAView.frame
    expect(itemAView.frame) != itemAFrame
    expect(start.context.revivalPosition) == nil
    expect(start.context.revivalTransform == nil) == true
    expect(itemAView.moveCount) == moveCount
    expect(window.contentView().subviews.contains(view)) == true
  }

  #if canImport(AppKit)
  func test_scroll_viewWithTheFirstResponderInside_leavesAsBefore() throws {
    // given: rows of reusable views in a window, rendered at the top, with the first responder in the view of row 0
    let pool = RecordingPool()
    let (window, view) = makeRowsView(pool: pool)
    view.refresh(animated: false)
    let rowZeroView = try rowView(showing: 0, in: view).unwrap()
    expect(window.makeFirstResponder(rowZeroView.focusTarget)) == true
    let moveCount = rowZeroView.moveCount

    // when: scrolling by one row, which moves row 0 out and row 2 in
    scroll(view, to: Constants.rowHeight)

    // then: the view of row 0 was removed, which took the first responder away, and came back from the pool for row 2
    expect(window.firstResponder) === window
    expect(rowView(showing: 2, in: view)) === rowZeroView
    expect(rowZeroView.moveCount) > moveCount
    expect(pool.enqueued.count) == 1
    expect(pool.enqueued.first?.renderable.view) === rowZeroView
  }
  #endif

  #if canImport(UIKit)
  func test_scroll_viewWithTheFirstResponderInside_givesItUpInPlace() throws {
    // given: rows of reusable views in a window, rendered at the top, with the first responder in the view of row 0
    let pool = RecordingPool()
    let (window, view) = makeRowsView(pool: pool)
    view.refresh(animated: false)
    let rowZeroView = try rowView(showing: 0, in: view).unwrap()
    expect(rowZeroView.focusTarget.becomeFirstResponder()) == true
    let moveCount = rowZeroView.moveCount

    // when: scrolling by one row, which moves row 0 out and row 2 in
    scroll(view, to: Constants.rowHeight)

    // then: row 2 shows in the view of row 0, which stayed in the window and gave up the first responder
    expect(rowZeroView.focusTarget.isFirstResponder) == false
    expect(rowView(showing: 2, in: view)) === rowZeroView
    expect(rowZeroView.moveCount) == moveCount
    expect(pool.enqueued.count) == 0
    expect(window.contentView().subviews.contains(view)) == true
  }

  func test_scroll_viewWithATouchInProgress_leavesAsBefore() throws {
    // given: rows of reusable views in a window, rendered at the top, with a control that tracks a touch in the view of
    // row 0
    let pool = RecordingPool()
    let (window, view) = makeRowsView(pool: pool)
    view.refresh(animated: false)
    let rowZeroView = try rowView(showing: 0, in: view).unwrap()
    let control = TrackingControl()
    control.tracks = true
    rowZeroView.addSubview(control)
    let moveCount = rowZeroView.moveCount

    // when: scrolling by one row, which moves row 0 out and row 2 in
    scroll(view, to: Constants.rowHeight)

    // then: the view of row 0 was removed, which cancels the touch, and came back from the pool for row 2
    expect(rowView(showing: 2, in: view)) === rowZeroView
    expect(rowZeroView.moveCount) > moveCount
    expect(pool.enqueued.count) == 1
    expect(pool.enqueued.first?.renderable.view) === rowZeroView
    expect(window.contentView().subviews.contains(view)) == true
  }
  #endif

  // MARK: - InPlaceReuse

  func test_take_returnsTheLastKeptViewOfTheKind() {
    // given: two kept views of one kind and one of another
    let reuse = ComposeView.InPlaceReuse()
    let viewA1 = View()
    let viewA2 = View()
    let viewB = View()
    reuse.keep(.view(viewA1), key: Constants.keyA)
    reuse.keep(.view(viewA2), key: Constants.keyA)
    reuse.keep(.view(viewB), key: Constants.keyB)

    // then: each take returns the last kept view of its kind, until none is left
    expect(reuse.take(Constants.keyB)?.view) === viewB
    expect(reuse.take(Constants.keyB)?.view) == nil
    expect(reuse.take(Constants.keyA)?.view) === viewA2
    expect(reuse.take(Constants.keyA)?.view) === viewA1
    expect(reuse.take(Constants.keyA)?.view) == nil
  }

  func test_take_withoutAKeptViewOfTheKind_returnsNil() {
    // given: no kept view
    let reuse = ComposeView.InPlaceReuse()

    // then: a take returns nil
    expect(reuse.take(Constants.keyA)?.view) == nil

    // when: keeping a view of another kind
    let viewB = View()
    reuse.keep(.view(viewB), key: Constants.keyB)

    // then: a take of the kind returns nil, and the view of the other kind stays
    expect(reuse.take(Constants.keyA)?.view) == nil
    expect(reuse.take(Constants.keyB)?.view) === viewB
  }

  func test_stopKeeping_afterAPassPastTheKeyLimit_removesTheArrays() {
    // given: views kept under one key more than the key limit, in a parent
    let reuse = ComposeView.InPlaceReuse()
    reuse.startKeeping()
    let parent = View()
    for number in 0 ... ComposeView.InPlaceReuse.maxKeyCount {
      let view = View()
      parent.addSubview(view)
      reuse.keep(.view(view), key: Self.appInPlaceKey(number))
    }

    // then: each view stays under its key until the pass ends
    expect(reuse.keyCount) == ComposeView.InPlaceReuse.maxKeyCount + 1

    // when: stopping keeping views
    let pool = RecordingPool()
    reuse.stopKeeping(addingTo: pool)

    // then: the views left their parent for the pool, and the arrays are gone
    expect(parent.subviews.isEmpty) == true
    expect(pool.enqueued.count) == ComposeView.InPlaceReuse.maxKeyCount + 1
    expect(reuse.keyCount) == 0

    // when: keeping and taking a view in a pass within the key limit
    reuse.startKeeping()
    reuse.keep(.view(View()), key: Constants.keyA)
    _ = reuse.take(Constants.keyA)
    reuse.stopKeeping(addingTo: pool)

    // then: its emptied array stays for the next pass
    expect(reuse.keyCount) == 1
  }

  func test_stopKeeping_afterAPassPastTheKeyLimitWhoseViewsWereTaken_removesTheArrays() {
    // given: views kept and taken under one key more than the key limit
    let reuse = ComposeView.InPlaceReuse()
    reuse.startKeeping()
    for number in 0 ... ComposeView.InPlaceReuse.maxKeyCount {
      reuse.keep(.view(View()), key: Self.appInPlaceKey(number))
      _ = reuse.take(Self.appInPlaceKey(number))
    }

    // when: stopping keeping views
    reuse.stopKeeping(addingTo: nil)

    // then: the arrays are gone
    expect(reuse.keyCount) == 0
  }

  func test_stopKeeping_afterAPassAtTheKeyLimit_keepsTheEmptiedArrays() {
    // given: views kept under as many keys as the key limit
    let reuse = ComposeView.InPlaceReuse()
    reuse.startKeeping()
    for number in 0 ..< ComposeView.InPlaceReuse.maxKeyCount {
      reuse.keep(.view(View()), key: Self.appInPlaceKey(number))
    }

    // when: stopping keeping views
    reuse.stopKeeping(addingTo: nil)

    // then: the emptied arrays stay for the next pass
    expect(reuse.keyCount) == ComposeView.InPlaceReuse.maxKeyCount
  }

  func test_stopKeeping_removesTheViewsFromTheirParentForThePool() {
    // given: kept views of two kinds, in a parent
    let reuse = ComposeView.InPlaceReuse()
    reuse.startKeeping()
    let parent = View()
    let viewA = View()
    let viewB = View()
    parent.addSubview(viewA)
    parent.addSubview(viewB)
    reuse.keep(.view(viewA), key: Constants.keyA)
    reuse.keep(.view(viewB), key: Constants.keyB)
    let pool = RecordingPool()
    var poolReadCount = 0
    func readPool() -> RenderablePoolType {
      poolReadCount += 1
      return pool
    }

    // when: stopping keeping views
    reuse.stopKeeping(addingTo: readPool())

    // then: the views left their parent for the pool, read once, under their keys, and none is left to take
    expect(viewA.superview) == nil
    expect(viewB.superview) == nil
    expect(poolReadCount) == 1
    expect(pool.enqueued.count) == 2
    expect(pool.enqueued.first { $0.renderable.view === viewA }?.key) == Constants.keyA
    expect(pool.enqueued.first { $0.renderable.view === viewB }?.key) == Constants.keyB
    expect(reuse.take(Constants.keyA)?.view) == nil
    expect(reuse.take(Constants.keyB)?.view) == nil

    // when: stopping again, with no view kept
    reuse.stopKeeping(addingTo: readPool())

    // then: the pool isn't read again
    expect(poolReadCount) == 1

    // when: keeping a view again
    reuse.keep(.view(viewA), key: Constants.keyA)

    // then: a take returns it
    expect(reuse.take(Constants.keyA)?.view) === viewA
  }

  func test_stopKeeping_withoutAPool_releasesTheViews() {
    // given: a kept view in a parent, which nothing else keeps
    let reuse = ComposeView.InPlaceReuse()
    reuse.startKeeping()
    let parent = View()
    weak var weakView: View?
    autoreleasepool {
      let view = View()
      weakView = view
      parent.addSubview(view)
      reuse.keep(.view(view), key: Constants.keyA)
    }
    expect(weakView) != nil

    // when: stopping keeping views, without a pool
    autoreleasepool {
      reuse.stopKeeping(addingTo: nil)
    }

    // then: the view left its parent, and was released
    expect(parent.subviews.isEmpty) == true
    expect(weakView) == nil
    expect(reuse.take(Constants.keyA)?.view) == nil
  }

  func test_stopKeeping_withoutKeptViews_leavesThePoolAlone() {
    // given: a view that was kept and taken, in a parent
    let reuse = ComposeView.InPlaceReuse()
    reuse.startKeeping()
    let parent = View()
    let viewA = View()
    parent.addSubview(viewA)
    reuse.keep(.view(viewA), key: Constants.keyA)
    expect(reuse.take(Constants.keyA)?.view) === viewA
    let pool = RecordingPool()
    var poolReadCount = 0
    func readPool() -> RenderablePoolType {
      poolReadCount += 1
      return pool
    }

    // when: stopping keeping views
    reuse.stopKeeping(addingTo: readPool())

    // then: the taken view stays in its parent, and the pool isn't read
    expect(viewA.superview) === parent
    expect(poolReadCount) == 0
    expect(pool.enqueued.count) == 0
  }

  func test_canKeep() {
    // given: views in place
    let reuse = ComposeView.InPlaceReuse()

    // then: before keeping starts, no view can stay
    expect(reuse.canKeep(.view(View()), key: Constants.keyA)) == false

    // when: starting keeping views
    reuse.startKeeping()

    // then: a view whose reuse identifier allows it can stay in place, an app's view too, but a layer can't, and neither
    // can a view whose reuse identifier doesn't allow it
    expect(reuse.canKeep(.view(View()), key: Constants.keyA)) == true
    expect(reuse.canKeep(.view(View()), key: Constants.appInPlaceKey)) == true
    expect(reuse.canKeep(.layer(CALayer()), key: Constants.keyA)) == false
    expect(reuse.canKeep(.view(View()), key: Constants.appKey)) == false

    // when: stopping keeping views
    reuse.stopKeeping(addingTo: nil)

    // then: no view can stay
    expect(reuse.canKeep(.view(View()), key: Constants.keyA)) == false
  }

  #if canImport(AppKit)
  func test_canKeep_viewWithTheFirstResponderInside_returnsFalse() {
    // given: a view in a window, with the first responder in it
    let reuse = ComposeView.InPlaceReuse()
    reuse.startKeeping()
    let window = TestWindow()
    let view = RowView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
    view.addSubview(view.focusTarget)
    let otherView = RowView(frame: CGRect(x: 0, y: 50, width: 100, height: 50))
    otherView.addSubview(otherView.focusTarget)
    window.contentView().addSubview(view)
    window.contentView().addSubview(otherView)
    expect(window.makeFirstResponder(view.focusTarget)) == true

    // then: the view can't stay in place, the other view can, and the first responder stays
    expect(reuse.canKeep(.view(view), key: Constants.keyA)) == false
    expect(reuse.canKeep(.view(otherView), key: Constants.keyA)) == true
    expect(window.firstResponder) === view.focusTarget

    // when: the window is the first responder
    expect(window.makeFirstResponder(nil)) == true

    // then: the view can stay in place
    expect(reuse.canKeep(.view(view), key: Constants.keyA)) == true
  }

  func test_canKeep_viewWithAnEditingTextField_returnsFalse() {
    // given: a view in a window, with a text field in it that the window's field editor edits
    let reuse = ComposeView.InPlaceReuse()
    reuse.startKeeping()
    let window = TestWindow()
    let view = View(frame: CGRect(x: 0, y: 0, width: 300, height: 50))
    let textField = NSTextField(frame: CGRect(x: 10, y: 10, width: 200, height: 22))
    view.addSubview(textField)
    window.contentView().addSubview(view)
    expect(window.makeFirstResponder(textField)) == true
    expect((window.firstResponder as? NSTextView)?.isFieldEditor) == true

    // then: the view can't stay in place, since the field editor is inside the text field
    expect(reuse.canKeep(.view(view), key: Constants.keyA)) == false
  }

  func test_canKeep_mouseButtonPressed_returnsFalse() {
    // given: a mouse button state that a test sets, which counts its reads
    var isMouseButtonPressed = true
    var readCount = 0
    let reuse = ComposeView.InPlaceReuse(isMouseButtonPressed: {
      readCount += 1
      return isMouseButtonPressed
    })

    // when: a pass starts keeping views while a mouse button is pressed
    reuse.startKeeping()

    // then: a layer can't stay without reading the button state, and no view can stay, with the state read once
    expect(reuse.canKeep(.layer(CALayer()), key: Constants.keyA)) == false
    expect(readCount) == 0
    expect(reuse.canKeep(.view(View()), key: Constants.keyA)) == false
    expect(reuse.canKeep(.view(View()), key: Constants.keyA)) == false
    expect(readCount) == 1

    // when: the next pass starts keeping views after the button is released
    isMouseButtonPressed = false
    reuse.stopKeeping(addingTo: nil)
    reuse.startKeeping()

    // then: a view can stay, with the state read again
    expect(reuse.canKeep(.view(View()), key: Constants.keyA)) == true
    expect(readCount) == 2
  }
  #endif

  #if canImport(UIKit)
  func test_canKeep_viewWithTheFirstResponderInside_givesItUp() {
    // given: a view in a window, with the first responder in it
    let reuse = ComposeView.InPlaceReuse()
    reuse.startKeeping()
    let window = TestWindow()
    let view = RowView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
    view.addSubview(view.focusTarget)
    window.contentView().addSubview(view)
    expect(view.focusTarget.becomeFirstResponder()) == true

    // then: the view can stay in place, after giving up the first responder
    expect(reuse.canKeep(.view(view), key: Constants.keyA)) == true
    expect(view.focusTarget.isFirstResponder) == false
  }

  func test_canKeep_viewWithATouchInProgress_returnsFalse() {
    // given: a view with a control and a gesture recognizer that track no touch, in a subview
    let reuse = ComposeView.InPlaceReuse()
    reuse.startKeeping()
    let view = View(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
    let subview = View(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    let control = TrackingControl()
    let recognizer = TouchedGestureRecognizer()
    subview.addSubview(control)
    subview.addGestureRecognizer(recognizer)
    view.addSubview(subview)

    // then: the view can stay in place
    expect(reuse.canKeep(.view(view), key: Constants.keyA)) == true

    // when: the control tracks a touch
    control.tracks = true

    // then: the view can't stay in place
    expect(reuse.canKeep(.view(view), key: Constants.keyA)) == false

    // when: the gesture recognizer tracks a touch instead
    control.tracks = false
    recognizer.touchCount = 1

    // then: the view can't stay in place
    expect(reuse.canKeep(.view(view), key: Constants.keyA)) == false
  }

  func test_canKeep_viewWithTheFocus_returnsFalse() {
    // given: a view with a subview that isn't focused
    let reuse = ComposeView.InPlaceReuse()
    reuse.startKeeping()
    let view = View(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
    let subview = FocusedView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    view.addSubview(subview)

    // then: the view can stay in place
    expect(reuse.canKeep(.view(view), key: Constants.keyA)) == true

    // when: the subview is focused
    subview.isFocusedForTesting = true

    // then: the view can't stay in place
    expect(reuse.canKeep(.view(view), key: Constants.keyA)) == false
  }
  #endif

  // MARK: - Helpers

  private enum Constants {

    static let rowCount = 60
    static let rowHeight: CGFloat = 50
    static let viewSize = CGSize(width: 100, height: 100)
    static let keyA = ReuseKey(reuseId: ReuseId(namespace: .framework, id: "a", reusesInPlace: true), type: ObjectIdentifier(View.self))
    static let keyB = ReuseKey(reuseId: ReuseId(namespace: .framework, id: "b", reusesInPlace: true), type: ObjectIdentifier(View.self))
    static let appKey = ReuseKey(reuseId: ReuseId(namespace: .user, id: "a"), type: ObjectIdentifier(View.self))
    static let appInPlaceKey = ReuseKey(reuseId: ReuseId(namespace: .user, id: "a", reusesInPlace: true), type: ObjectIdentifier(View.self))

    /// The reuse identifier of the rows' views, as ComposeUI's own nodes give their views.
    static let rowReuseId = ReuseId(namespace: .framework, id: "row", reusesInPlace: true)
  }

  /// Returns a key that an app's view reused in place has, of a reuse identifier made from a number.
  private static func appInPlaceKey(_ number: Int) -> ReuseKey {
    ReuseKey(reuseId: ReuseId(namespace: .user, id: "\(number)", reusesInPlace: true), type: ObjectIdentifier(View.self))
  }

  /// Returns a view of reusable rows in a window.
  private func makeRowsView(pool: RenderablePoolType,
                            onRemove: @escaping (Renderable, RenderableRemoveContext) -> Void = { _, _ in },
                            onResetForReuse: @escaping (Renderable) -> Void = { _ in }) -> (TestWindow, ComposeView)
  {
    makeView(pool: pool) {
      VStack {
        for row in 0 ..< Constants.rowCount {
          RowNode(row: row, reuseId: Constants.rowReuseId)
            .onRemove(onRemove)
            .onResetForReuse(onResetForReuse)
            .frame(width: .flexible, height: Constants.rowHeight)
        }
      }
    }
  }

  /// Returns a view of rows in a window, whose views the app reuses with `reuseId(_:inPlace:)`.
  private func makeAppRowsView(pool: RenderablePoolType, inPlace: Bool) -> (TestWindow, ComposeView) {
    makeView(pool: pool) {
      VStack {
        for row in 0 ..< Constants.rowCount {
          RowNode(row: row, reuseId: nil)
            .reuseId("row", inPlace: inPlace)
            .frame(width: .flexible, height: Constants.rowHeight)
        }
      }
    }
  }

  /// Returns a compose view in a window, with a pool.
  private func makeView(pool: RenderablePoolType, @ComposeContentBuilder content: @escaping () -> ComposeContent) -> (TestWindow, ComposeView) {
    let window = TestWindow()
    let view = ComposeView(content: content)
    view.renderablePool = pool
    view.frame = CGRect(origin: .zero, size: Constants.viewSize)
    window.contentView().addSubview(view)
    return (window, view)
  }

  /// Scrolls a view vertically, and renders it.
  private func scroll(_ view: ComposeView, to offset: CGFloat) {
    view.contentOffset = CGPoint(x: 0, y: offset)
    view.layoutIfNeeded()
  }

  private func rowViews(in view: ComposeView) -> [RowView] {
    view.contentContainerView.subviews.compactMap { $0 as? RowView }
  }

  private func rowView(showing row: Int, in view: ComposeView) -> RowView? {
    rowViews(in: view).first { $0.row == row }
  }

  private func rowsInSubviewOrder(of view: ComposeView) -> [Int] {
    rowViews(in: view).map(\.row)
  }

  private func rowsInSublayerOrder(of view: ComposeView) -> [Int] {
    let rowViews = rowViews(in: view)
    return (view.contentContainerView.layer().sublayers ?? []).compactMap { sublayer in
      rowViews.first { $0.layer() === sublayer }?.row
    }
  }
}

// MARK: - RowView

/// A row's view, which records the row it shows, and the moves to a superview or a window, which a reuse in place
/// doesn't make.
private final class RowView: View {

  /// The row that the view shows.
  var row = -1

  /// The number of moves to a superview or a window.
  private(set) var moveCount = 0

  /// A subview that can be the first responder.
  let focusTarget = FocusTarget(frame: CGRect(x: 0, y: 0, width: 50, height: 20))

  #if canImport(AppKit)
  override func viewDidMoveToSuperview() {
    super.viewDidMoveToSuperview()
    moveCount += 1
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    moveCount += 1
  }
  #endif

  #if canImport(UIKit)
  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    moveCount += 1
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    moveCount += 1
  }
  #endif
}

// MARK: - RowNode

/// A node of a row's view, with the reuse identifier that its item sets, as ComposeUI's own nodes do, or without one,
/// for an app to set.
private struct RowNode: ComposeNode {

  private let row: Int
  private let reuseId: ReuseId?

  init(row: Int, reuseId: ReuseId?) {
    self.row = row
    self.reuseId = reuseId
  }

  var id: ComposeNodeId = .custom("row")

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
    let item = ViewItem<RowView>(
      id: id,
      frame: frame,
      make: { context in
        let view = RowView(frame: context.initialFrame ?? .zero)
        #if canImport(AppKit)
        view.wantsLayer = true
        #endif
        view.addSubview(view.focusTarget)
        return view
      },
      update: { view, _ in
        view.row = row
      },
      reuseId: reuseId
    )
    items.append(item.eraseToRenderableItem())
  }
}

#if canImport(AppKit)
/// A view that can be the first responder.
private final class FocusTarget: NSView {

  override var acceptsFirstResponder: Bool { true }
}
#endif

#if canImport(UIKit)
/// A view that can be the first responder.
private typealias FocusTarget = UITextField

/// A control whose tracking of a touch a test sets.
private final class TrackingControl: UIControl {

  /// Whether the control tracks a touch.
  var tracks = false

  override var isTracking: Bool {
    tracks
  }
}

/// A gesture recognizer whose number of touches a test sets.
private final class TouchedGestureRecognizer: UIGestureRecognizer {

  /// The number of touches that the recognizer tracks.
  var touchCount = 0

  override var numberOfTouches: Int {
    touchCount
  }
}

/// A view whose focus a test sets.
private final class FocusedView: UIView {

  /// Whether the view is focused.
  var isFocusedForTesting = false

  override var isFocused: Bool {
    isFocusedForTesting
  }
}
#endif

// MARK: - RecordingPool

/// A pool that records the renderables it gets and the requests it serves, and serves them from a renderable pool.
private final class RecordingPool: RenderablePoolType {

  private(set) var enqueued: [(renderable: Renderable, key: ReuseKey)] = []
  private(set) var dequeueCount = 0

  private let backing = RenderablePool()

  func enqueue(_ renderable: Renderable, key: ReuseKey) {
    enqueued.append((renderable, key))
    backing.enqueue(renderable, key: key)
  }

  func dequeue(_ key: ReuseKey) -> Renderable? {
    dequeueCount += 1
    return backing.dequeue(key)
  }
}
