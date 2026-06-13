//
//  ComposeView+RenderReuseTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 6/13/26.
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

/// Tests for the renderable recycle pool (`reuseId`).
///
/// The list geometry is chosen so that exactly one row leaves and one row enters per scroll step (rows are 50pt tall in
/// a 100pt viewport with no visible-bounds insets, scrolling by one row height). This makes the number of created
/// renderables deterministic: with pooling, the leaving row is parked and immediately reused by the entering row, so no
/// new renderable is created after the initial fill.
class ComposeView_RenderReuseTests: XCTestCase {

  private enum Constants {
    static let rowCount = 60
    static let rowHeight: CGFloat = 50
    static let viewSize = CGSize(width: 100, height: 100)
    static var contentHeight: CGFloat { CGFloat(rowCount) * rowHeight }
    static var maxOffset: CGFloat { contentHeight - viewSize.height }
  }

  // MARK: - Recycling

  func test_reuseId_recyclesRenderables_acrossScroll() {
    let counter = MakeCounter()
    let view = makeRowsView(reuseId: "row", counter: counter, update: nil)
    view.refresh(animated: false)

    let initialMakeCount = counter.madeCount
    expect(initialMakeCount) > 0

    scrollDown(view)

    // every row revealed during the scroll reused a parked renderable, so no new renderable was created after the
    // initial fill.
    expect(counter.madeCount) == initialMakeCount
  }

  func test_noReuseId_doesNotRecycle() {
    let counter = MakeCounter()
    let view = makeRowsView(reuseId: nil, counter: counter, update: nil)
    view.refresh(animated: false)

    let initialMakeCount = counter.madeCount
    expect(initialMakeCount) > 0

    scrollDown(view)

    // without a reuse identifier, each distinct row creates its own renderable as it is revealed.
    expect(counter.madeCount) == Constants.rowCount
    expect(counter.madeCount) > initialMakeCount
  }

  // MARK: - Pool configuration

  func test_renderablePool_defaultsToSharedPool() {
    let view = ComposeView(frame: CGRect(origin: .zero, size: Constants.viewSize))
    // by default a view uses the process-wide shared pool, so reuse is amortized across views.
    expect(view.renderablePool === RenderablePool.shared) == true
  }

  func test_renderablePool_disabled_doesNotRecycle() {
    let counter = MakeCounter()
    let view = makeRowsView(reuseId: "row", counter: counter, update: nil)
    view.renderablePool = nil // disable pooling despite the rows having a reuse identifier.
    view.refresh(animated: false)

    let initialMakeCount = counter.madeCount
    expect(initialMakeCount) > 0

    scrollDown(view)

    // with pooling disabled, each revealed row creates its own renderable (nothing is parked or reused).
    expect(counter.madeCount) == Constants.rowCount
    expect(counter.madeCount) > initialMakeCount
  }

  func test_renderablePool_customPool_isUsedForReuse() {
    let counter = MakeCounter()
    let pool = MockRenderablePool()
    let view = makeRowsView(reuseId: "row", counter: counter, update: nil)
    view.renderablePool = pool
    view.refresh(animated: false)

    scrollDown(view)

    // the custom pool received parked renderables and handed them back for reuse.
    expect(pool.enqueueCount) > 0
    expect(pool.dequeueCount) > 0
  }

  // MARK: - Reconfiguration (dirty-state contract)

  func test_reuseId_recycledRenderable_isReconfiguredForNewRow() {
    let counter = MakeCounter()
    // each row stamps its own index onto the (possibly recycled) view on update.
    let view = makeRowsView(reuseId: "row", counter: counter, update: { rowView, index in
      rowView.configuredValue = index
    })
    view.refresh(animated: false)

    scrollDown(view)

    // at the bottom, the two visible rows are the last two (indices 58 and 59). Their renderables are recycled from
    // earlier rows, so this asserts the recycled renderables were reconfigured to the current rows (no stale state).
    let configuredValues = visibleRowViews(in: view).map(\.configuredValue).sorted()
    expect(configuredValues) == [Constants.rowCount - 2, Constants.rowCount - 1]
  }

  // MARK: - Type safety

  func test_reuseId_sharedAcrossDifferentTypes_doesNotCrash() {
    // even rows are backed by `RowViewA`, odd rows by `RowViewB`, all sharing the same reuse identifier. The pool key
    // includes the concrete type, so a parked `RowViewA` is never handed to a `RowViewB` item (which would crash on the
    // `as!` cast in the update closure). Completing the scroll without crashing exercises that guard.
    let counterA = MakeCounter()
    let counterB = MakeCounter()

    let view = ComposeView(frame: CGRect(origin: .zero, size: Constants.viewSize))
    view.renderablePool = RenderablePool() // isolate from the shared pool so reuse counts are deterministic.
    view.setContent {
      VStack {
        for i in 0 ..< Constants.rowCount {
          if i.isMultiple(of: 2) {
            ViewNode<RowViewA>(make: { context in
              counterA.madeCount += 1
              return RowViewA(frame: context.initialFrame ?? .zero).layerBacked()
            })
            .frame(width: .flexible, height: Constants.rowHeight)
            .reuseId("row")
          } else {
            ViewNode<RowViewB>(make: { context in
              counterB.madeCount += 1
              return RowViewB(frame: context.initialFrame ?? .zero).layerBacked()
            })
            .frame(width: .flexible, height: Constants.rowHeight)
            .reuseId("row")
          }
        }
      }
    }
    view.refresh(animated: false)

    scrollDown(view)

    // both types were created and recycled within their own type bucket.
    expect(counterA.madeCount) > 0
    expect(counterB.madeCount) > 0
    // the visible views at the bottom must be the correct concrete types for their rows (58 -> A, 59 -> B).
    let bottomTypes = visibleRowTypeNames(in: view)
    expect(bottomTypes.contains("RowViewA")) == true
    expect(bottomTypes.contains("RowViewB")) == true
  }

  // MARK: - Modifier semantics

  func test_reuseIdModifier_setsReuseIdAndResolvesKey() {
    let item = firstRenderableItem(of: ColorNode(.red).reuseId("x").frame(width: 100, height: 100))
    expect(item?.reuseId) == "x"
    expect(item?.reuseKey) != nil
  }

  func test_reuseIdModifier_innerWins_whenCoalesced() {
    // two adjacent reuse identifiers coalesce into one modifier node; the inner one wins.
    let item = firstRenderableItem(of: ColorNode(.red).reuseId("inner").reuseId("outer").frame(width: 100, height: 100))
    expect(item?.reuseId) == "inner"
  }

  func test_reuseIdModifier_innerWins_acrossNodeBoundary() {
    // an outer reuse identifier applied across a frame boundary must not overwrite the inner one already on the item.
    let item = firstRenderableItem(of: ColorNode(.red).reuseId("inner").frame(width: 100, height: 100).reuseId("outer"))
    expect(item?.reuseId) == "inner"
  }

  func test_noReuseIdModifier_resolvesNilKey() {
    let item = firstRenderableItem(of: ColorNode(.red).frame(width: 100, height: 100))
    expect(item?.reuseId) == nil
    expect(item?.reuseKey) == nil
  }

  // MARK: - Transition interaction

  func test_reuseId_renderableIsPooledOnlyAfterRemoveTransitionCompletes() {
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let pool = RenderablePool()
    contentView.renderablePool = pool

    var removalCompletion: (() -> Void)?
    let transition = RenderableTransition(
      insert: RenderableTransition.InsertTransition { renderable, context, completion in
        renderable.setFrame(context.targetFrame)
        completion()
      },
      remove: RenderableTransition.RemoveTransition { _, _, completion in
        removalCompletion = completion
      }
    )

    contentView.setContent {
      ColorNode(.red)
        .transition(transition)
        .reuseId("x")
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: false)

    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // while the remove transition is in flight, the renderable is parked in the removing map and must not be pooled
    // (it may still be re-inserted).
    expect(contentView.test.removingRenderableMap.count) == 1
    expect(pool.count) == 0

    removalCompletion?()

    // once the remove transition completes, the renderable is moved into the pool for reuse.
    expect(contentView.test.removingRenderableMap.count) == 0
    expect(pool.count) == 1
  }

  func test_reuseId_transitionResetForReuse_isCalledBeforePooling() {
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let pool = RenderablePool()
    contentView.renderablePool = pool

    var removalCompletion: (() -> Void)?
    var removedLayer: CALayer?
    // a transition that leaves presentation residue (a faded-out opacity) as its final act, and supplies a
    // `resetForReuse` to undo it. The engine must invoke `resetForReuse` before pooling, without knowing what it does.
    let transition = RenderableTransition(
      insert: RenderableTransition.InsertTransition { renderable, context, completion in
        renderable.setFrame(context.targetFrame)
        completion()
      },
      remove: RenderableTransition.RemoveTransition(
        animate: { renderable, _, completion in
          renderable.layer.opacity = 0
          removedLayer = renderable.layer
          removalCompletion = completion
        },
        resetForReuse: { renderable in
          renderable.layer.opacity = 1
        }
      )
    )

    contentView.setContent {
      ColorNode(.red)
        .transition(transition)
        .reuseId("x")
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: false)

    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // while the remove transition is in flight, the residue is present and the renderable is not yet pooled.
    expect(removedLayer?.opacity) == 0
    expect(pool.count) == 0

    removalCompletion?()

    // once the transition completes, the engine asks the transition to reset its residue before pooling, so the parked
    // renderable is clean (visible) and a future reuse does not re-insert it invisible.
    expect(removedLayer?.opacity) == 1
    expect(pool.count) == 1

    // reuse the parked renderable for a new row; it stays visible (no leftover fade).
    contentView.setContent {
      ColorNode(.blue)
        .transition(transition)
        .reuseId("x")
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: false)

    expect(pool.count) == 0
    expect(removedLayer?.opacity) == 1
  }

  func test_reuseId_renderableReinsertedDuringRemoveTransition_isNotPooled() {
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let pool = RenderablePool()
    contentView.renderablePool = pool

    let transition = RenderableTransition(
      insert: RenderableTransition.InsertTransition { renderable, context, completion in
        renderable.setFrame(context.targetFrame)
        completion()
      },
      remove: RenderableTransition.RemoveTransition { _, _, _ in
        // intentionally never completes; the removal is cancelled by re-inserting below.
      }
    )

    contentView.setContent {
      ColorNode(.red)
        .transition(transition)
        .reuseId("x")
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: false)

    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)
    expect(contentView.test.removingRenderableMap.count) == 1
    expect(pool.count) == 0

    // re-insert the same node: the in-flight removal is cancelled and the renderable is revived, so it must never be
    // pooled.
    contentView.setContent {
      ColorNode(.red)
        .transition(transition)
        .reuseId("x")
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: true)

    expect(contentView.test.removingRenderableMap.count) == 0
    expect(pool.count) == 0
  }

  // MARK: - Prepare for reuse

  func test_onPrepareForReuse_isCalledOnlyForPooledReuse() {
    let counter = MakeCounter()
    var prepareForReuseCount = 0

    let view = ComposeView(frame: CGRect(origin: .zero, size: Constants.viewSize))
    view.renderablePool = RenderablePool() // isolate from the shared pool so reuse counts are deterministic.
    view.setContent {
      VStack {
        for _ in 0 ..< Constants.rowCount {
          ViewNode<ReuseTrackingView>(
            make: { context in
              counter.madeCount += 1
              return ReuseTrackingView(frame: context.initialFrame ?? .zero).layerBacked()
            },
            update: { _, _ in }
          )
          .frame(width: .flexible, height: Constants.rowHeight)
          .reuseId("row")
          .onPrepareForReuse { renderable in
            (renderable.view as? ReuseTrackingView)?.wasPreparedForReuse = true
            prepareForReuseCount += 1
          }
        }
      }
    }
    view.refresh(animated: false)

    // the initial fill creates renderables via `make`; none come from the pool yet, so the hook never fired.
    expect(prepareForReuseCount) == 0
    expect(visibleRowViews(in: view).contains { $0.wasPreparedForReuse }) == false

    scrollDown(view)

    // every row revealed during the scroll reused a parked renderable, so the hook fired for each reuse and the visible
    // (recycled) rows are flagged as prepared.
    expect(prepareForReuseCount) > 0
    expect(visibleRowViews(in: view).allSatisfy(\.wasPreparedForReuse)) == true
  }

  func test_onPrepareForReuse_coalescedHooks_runInOrder() {
    // two adjacent hooks coalesce into one combined block; both run, outer after inner.
    var calls: [String] = []
    let item = firstRenderableItem(
      of: ViewNode<ReuseTrackingView>(make: { _ in ReuseTrackingView() })
        .onPrepareForReuse { _ in calls.append("a") }
        .onPrepareForReuse { _ in calls.append("b") }
        .frame(width: 100, height: 100)
    )

    item?.prepareForReuse?(.view(ReuseTrackingView()))

    expect(calls) == ["a", "b"]
  }

  func test_onPrepareForReuse_hooksStackedAcrossNodeBoundary_runInOrder() {
    // an inner hook (below a frame boundary) and an outer hook (coalesced with a reuse identifier) both run, inner first.
    var calls: [String] = []
    let item = firstRenderableItem(
      of: ViewNode<ReuseTrackingView>(make: { _ in ReuseTrackingView() })
        .onPrepareForReuse { _ in calls.append("inner") }
        .frame(width: 100, height: 100)
        .onPrepareForReuse { _ in calls.append("outer") }
        .reuseId("x")
    )

    item?.prepareForReuse?(.view(ReuseTrackingView()))

    expect(calls) == ["inner", "outer"]
  }

  func test_renderItem_erasurePreservesPrepareForReuse() {
    // a typed item's prepareForReuse survives type erasure and runs against the concrete renderable.
    var viewCalls = 0
    let viewItem = ViewItem<ReuseTrackingView>(
      id: .custom("v"),
      frame: .zero,
      make: { _ in ReuseTrackingView() },
      update: { _, _ in },
      prepareForReuse: { _ in viewCalls += 1 }
    ).eraseToRenderableItem()
    viewItem.prepareForReuse?(.view(ReuseTrackingView()))
    expect(viewCalls) == 1

    var layerCalls = 0
    let layerItem = LayerItem<CALayer>(
      id: .custom("l"),
      frame: .zero,
      make: { _ in CALayer() },
      update: { _, _ in },
      prepareForReuse: { _ in layerCalls += 1 }
    ).eraseToRenderableItem()
    layerItem.prepareForReuse?(.layer(CALayer()))
    expect(layerCalls) == 1
  }

  func test_onPrepareForReuse_firesForLayerBackedReuse() {
    // a layer-backed node (ColorNode) also receives the hook on reuse, exercising the layer erasure path.
    var prepareForReuseCount = 0
    let view = ComposeView(frame: CGRect(origin: .zero, size: Constants.viewSize))
    view.renderablePool = RenderablePool() // isolate from the shared pool so reuse counts are deterministic.
    view.setContent {
      VStack {
        for i in 0 ..< Constants.rowCount {
          ColorNode(i.isMultiple(of: 2) ? .red : .blue)
            .frame(width: .flexible, height: Constants.rowHeight)
            .reuseId("color")
            .onPrepareForReuse { _ in prepareForReuseCount += 1 }
        }
      }
    }
    view.refresh(animated: false)

    expect(prepareForReuseCount) == 0

    scrollDown(view)

    expect(prepareForReuseCount) > 0
  }

  // MARK: - Helpers

  private func makeRowsView(reuseId: String?,
                            counter: MakeCounter,
                            update: ((ReuseTrackingView, Int) -> Void)?) -> ComposeView
  {
    let view = ComposeView(frame: CGRect(origin: .zero, size: Constants.viewSize))
    view.renderablePool = RenderablePool() // isolate from the shared pool so reuse counts are deterministic.
    view.setContent {
      VStack {
        for i in 0 ..< Constants.rowCount {
          let node = ViewNode<ReuseTrackingView>(
            make: { context in
              counter.madeCount += 1
              return ReuseTrackingView(frame: context.initialFrame ?? .zero).layerBacked()
            },
            update: { rowView, _ in
              update?(rowView, i)
            }
          )
          .frame(width: .flexible, height: Constants.rowHeight)

          if let reuseId {
            node.reuseId(reuseId)
          } else {
            node
          }
        }
      }
    }
    return view
  }

  private func scrollDown(_ view: ComposeView) {
    var offset: CGFloat = 0
    while offset <= Constants.maxOffset {
      view.setContentOffset(CGPoint(x: 0, y: offset))
      view.layoutIfNeeded()
      offset += Constants.rowHeight
    }
  }

  private func visibleRowViews(in view: ComposeView) -> [ReuseTrackingView] {
    view.contentView().subviews.compactMap { $0 as? ReuseTrackingView }
  }

  private func visibleRowTypeNames(in view: ComposeView) -> Set<String> {
    Set(view.contentView().subviews.map { String(describing: type(of: $0)) })
  }

  private func firstRenderableItem(of node: some ComposeNode) -> RenderableItem? {
    var node = node
    let size = Constants.viewSize
    _ = node.layout(containerSize: size, context: ComposeNodeLayoutContext(scaleFactor: 2))
    return node.renderableItems(in: CGRect(origin: .zero, size: size)).first
  }
}

// MARK: - Test views

/// Counts how many renderables a node's `make` closure creates.
private final class MakeCounter {

  var madeCount = 0
}

private final class ReuseTrackingView: View {

  var configuredValue: Int = -1
  var wasPreparedForReuse = false
}

private final class RowViewA: View {}

private final class RowViewB: View {}

/// A custom `RenderablePool` that counts calls and delegates to a real pool, to verify `ComposeView` uses the configured pool.
private final class MockRenderablePool: RenderablePoolType {

  private(set) var enqueueCount = 0
  private(set) var dequeueCount = 0

  private let backing = RenderablePool()

  func enqueue(_ renderable: Renderable, key: ReuseKey) {
    enqueueCount += 1
    backing.enqueue(renderable, key: key)
  }

  func dequeue(_ key: ReuseKey) -> Renderable? {
    dequeueCount += 1
    return backing.dequeue(key)
  }
}

private extension View {

  /// Enables layer backing on AppKit (ComposéUI manipulates the renderable's backing layer).
  func layerBacked() -> Self {
    #if canImport(AppKit)
    wantsLayer = true
    #endif
    return self
  }
}
