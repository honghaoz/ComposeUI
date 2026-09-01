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
/// renderables deterministic: with pooling, the leaving row is enqueued and immediately reused by the entering row, so no
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
    // given: a rows view with a reuse id, rendered for the initial fill
    let counter = MakeCounter()
    let view = makeRowsView(reuseId: "row", counter: counter, update: nil)
    view.refresh(animated: false)

    let initialMakeCount = counter.madeCount
    expect(initialMakeCount) > 0

    // when: the view scrolls through the whole list
    scrollDown(view)

    // then: every row revealed during the scroll reused a renderable, so no new renderable was created after the
    // initial fill
    expect(counter.madeCount) == initialMakeCount
  }

  func test_noReuseId_doesNotRecycle() {
    // given: a rows view without a reuse id, rendered for the initial fill
    let counter = MakeCounter()
    let view = makeRowsView(reuseId: nil, counter: counter, update: nil)
    view.refresh(animated: false)

    let initialMakeCount = counter.madeCount
    expect(initialMakeCount) > 0

    // when: the view scrolls through the whole list
    scrollDown(view)

    // then: without a reuse identifier, each distinct row creates its own renderable as it is revealed
    expect(counter.madeCount) == Constants.rowCount
    expect(counter.madeCount) > initialMakeCount
  }

  // MARK: - Render identity

  func test_renderIdentity_ignoresIsFixed_reusesAcrossIsFixedChange() {
    // A node id'd "x" (non-fixed) and the same node `fixedId`'d "x" are the SAME render item, because render identity is
    // the id string only. Changing only the "isFixed" must therefore reuse the existing renderable in place rather than
    // remove the old one and create a new one (which is what would happen if `isFixed` were part of the render map keys).

    // given: a view rendering a node id'd "x" (non-fixed), with map-based reuse isolated from the recycle pool
    var madeCount = 0
    let view = ComposeView(frame: CGRect(origin: .zero, size: Constants.viewSize))
    view.renderablePool = nil // isolate map-based reuse from the recycle pool

    view.setContent {
      LayerNode(make: { _ in
        madeCount += 1
        return CALayer()
      })
      .id("x")
    }
    view.refresh(animated: false)
    expect(madeCount) == 1

    // when: the same string id renders again, now fixed
    // the render maps (renderableItemMap/renderableMap) must treat it as the same key.
    view.setContent {
      LayerNode(make: { _ in
        madeCount += 1
        return CALayer()
      })
      .fixedId("x")
    }
    view.refresh(animated: false)

    // then: reused in place: no new renderable was created, and nothing was stranded in the removing map
    expect(madeCount) == 1
    expect(view.test.removingRenderableMap.count) == 0
  }

  func test_renderIdentity_sharedLeafCache_fixedAndNonFixedSameString_notConfused() {
    // Two copies of the same base leaf node share its itemCache (a reference stored in a value-type node). Giving them
    // the same id string but different "isFixed" must not let the fixed copy receive the non-fixed copy's cached item,
    // which would make the parent prefix it ("VS|1|x") instead of treating it as fixed ("x").

    // given: two copies of the same base leaf node with the same id string but different isFixed, and an id recorder
    let base = ColorNode(.red)
    let view = ComposeView(frame: CGRect(origin: .zero, size: Constants.viewSize))
    view.renderablePool = nil

    view.setContent {
      VStack {
        base.id("x") // non-fixed: prefixed by the VStack -> "VS|0|x"
        base.fixedId("x") // fixed: not prefixed -> "x"
      }
    }

    var renderedIds: [String] = []
    view.debug { _, event in
      if case .renderDidFinish(let ids, _, _) = event {
        renderedIds = ids.map(\.id)
      }
    }

    // when: the view renders
    view.refresh(animated: false)

    // then: the fixed copy keeps its unprefixed id
    // with an `==`-based (isFixed-ignoring) cache key it would have rendered as "VS|1|x" by reusing the non-fixed
    // copy's cached item.
    expect(renderedIds.contains("x")) == true
    expect(renderedIds.contains("VS|1|x")) == false
  }

  // MARK: - Default pooling (common nodes)

  func test_colorNode_poolsByDefault_acrossScroll() {
    // given: a recording pool and a list of color rows, rendered for the initial fill
    let pool = RecordingRenderablePool()
    let view = ComposeView(frame: CGRect(origin: .zero, size: Constants.viewSize))
    view.renderablePool = pool
    view.setContent {
      VStack {
        for i in 0 ..< Constants.rowCount {
          // no explicit reuse id: ColorNode pools by default.
          ColorNode(i.isMultiple(of: 2) ? .red : .blue)
            .frame(width: .flexible, height: Constants.rowHeight)
        }
      }
    }
    view.refresh(animated: false)

    // when: the view scrolls through the whole list
    scrollDown(view)

    // then: ColorNode added leaving layers to the pool and reused them for entering rows, all under a bucket with a
    // framework-internal reuse id
    expect(pool.enqueueCount) > 0
    expect(pool.dequeueCount) > 0
    expect(pool.keys.allSatisfy { $0.reuseId.namespace == .framework && $0.reuseId.id == "CALayer" }) == true
  }

  func test_textNode_poolsByDefault_acrossScroll() {
    // given: a recording pool and a list of text rows, rendered for the initial fill
    let pool = RecordingRenderablePool()
    let view = ComposeView(frame: CGRect(origin: .zero, size: Constants.viewSize))
    view.renderablePool = pool
    view.setContent {
      VStack {
        for i in 0 ..< Constants.rowCount {
          // no explicit reuse id: TextNode pools its BaseTextView by default.
          TextNode("Row \(i)")
            .frame(width: .flexible, height: Constants.rowHeight)
        }
      }
    }
    view.refresh(animated: false)

    // when: the view scrolls through the whole list
    scrollDown(view)

    // then: TextNode added leaving views to the pool and reused them for entering rows, all under a framework-internal
    // bucket
    expect(pool.enqueueCount) > 0
    expect(pool.dequeueCount) > 0
    expect(pool.keys.allSatisfy { $0.reuseId.namespace == .framework && $0.reuseId.id == "BaseTextView" }) == true
  }

  func test_textNode_recycledView_resetsTextViewStateFromPreviousUse() throws {
    // given: a recording pool and a rendered text node, with the text view's state mutated by a previous use
    let pool = RecordingRenderablePool()
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.renderablePool = pool

    view.setContent {
      TextNode("First")
        .numberOfLines(2)
        .lineBreakMode(.byTruncatingTail)
        .editable()
        .selectable(false)
        .textContainerInset(horizontal: 10, vertical: 20)
        .frame(width: 100, height: 100)
    }
    view.refresh(animated: false)

    let textView = try firstBaseTextView(in: view).unwrap()
    #if canImport(AppKit)
    textView.string = "User edited text"
    textView.textContainerInset = CGSize(width: 3, height: 4)
    textView.ignoreHitTest = true
    textView.isRichText = true
    textView.drawsBackground = true
    textView.isSelectable = true
    textView.setSelectedRange(NSRange(location: 0, length: 4))
    #endif
    #if canImport(UIKit)
    textView.text = "User edited text"
    textView.textContainerInset = UIEdgeInsets(top: 4, left: 3, bottom: 4, right: 3)
    textView.isUserInteractionEnabled = false
    textView.backgroundColor = .red
    textView.contentInset = UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4)
    textView.horizontalScrollIndicatorInsets = UIEdgeInsets(top: 5, left: 6, bottom: 7, right: 8)
    textView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 5, left: 6, bottom: 7, right: 8)
    textView.setContentOffset(CGPoint(x: 9, y: 10), animated: false)
    textView.isSelectable = true
    textView.selectedRange = NSRange(location: 0, length: 4)
    #endif
    textView.numberOfLines = 3
    textView.lineBreakMode = .byTruncatingMiddle
    #if !os(tvOS)
    textView.isEditable = true
    #endif
    textView.isSelectable = false

    // when: the text node is removed so its view is enqueued to the pool
    view.setContent {
      Empty()
    }
    view.refresh(animated: false)

    // then: the same text view is enqueued with its state reset
    let enqueued = try (pool.lastEnqueuedRenderable?.view as? BaseTextView).unwrap()
    expect(enqueued) === textView
    expect(textView.attributedString.string) == ""
    expect(textView.numberOfLines) == 0
    expect(textView.lineBreakMode) == .byWordWrapping
    #if !os(tvOS)
    expect(textView.isEditable) == false
    #endif
    expect(textView.isSelectable) == true

    #if canImport(AppKit)
    expect(textView.string) == ""
    expect(textView.textContainerInset) == .zero
    expect(textView.ignoreHitTest) == false
    expect(textView.isRichText) == false
    expect(textView.drawsBackground) == false
    expect(textView.selectedRange()) == NSRange(location: 0, length: 0)
    #endif
    #if canImport(UIKit)
    expect(textView.text) == ""
    expect(textView.textContainerInset) == .zero
    expect(textView.isUserInteractionEnabled) == true
    expect(textView.backgroundColor == nil) == true
    expect(textView.contentInset) == .zero
    expect(textView.horizontalScrollIndicatorInsets) == .zero
    expect(textView.verticalScrollIndicatorInsets) == .zero
    expect(textView.contentOffset) == .zero
    expect(textView.selectedRange) == NSRange(location: 0, length: 0)
    #endif

    // when: a new text node reuses the pooled view
    view.setContent {
      TextNode("Second")
        .frame(width: 100, height: 100)
    }
    view.refresh(animated: false)

    // then: the same view is dequeued and configured for the new text
    expect(pool.lastDequeuedRenderable?.view) === textView
    expect(textView.attributedString.string) == "Second"
    expect(textView.numberOfLines) == 0
    expect(textView.lineBreakMode) == .byWordWrapping
  }

  func test_colorNode_recycledLayer_resetsModifierStateFromPreviousUse() {
    // a layer configured by a modifier in one use must not carry that state into a pool

    // given: a recording pool and a rendered color node with a corner radius modifier
    let pool = RecordingRenderablePool()
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.renderablePool = pool

    view.setContent {
      ColorNode(.red).cornerRadius(10).frame(width: 100, height: 100)
    }
    view.refresh(animated: false)

    // when: the node is removed so its layer is enqueued to the pool
    view.setContent {
      Empty()
    }
    view.refresh(animated: false)

    // then: the layer is enqueued with the modified corner radius reset for reuse
    let enqueued = pool.lastEnqueuedRenderable
    expect(enqueued?.layer.cornerRadius) == 0

    // when: a plain color node reuses the pooled layer
    view.setContent {
      ColorNode(.blue).frame(width: 100, height: 100)
    }
    view.refresh(animated: false)

    // then: the plain ColorNode reused the very same enqueued layer and it carries no stale corner radius
    expect(pool.lastDequeuedRenderable?.layer) === enqueued?.layer
    expect(enqueued?.layer.cornerRadius) == 0
  }

  func test_innerShadowNode_poolsByDefault_acrossScroll() {
    // given: a recording pool and a list of inner shadow rows, rendered for the initial fill
    let pool = RecordingRenderablePool()
    let view = ComposeView(frame: CGRect(origin: .zero, size: Constants.viewSize))
    view.renderablePool = pool
    view.setContent {
      VStack {
        for _ in 0 ..< Constants.rowCount {
          // no explicit reuse id: InnerShadowNode pools by default.
          InnerShadowNode(color: .black, opacity: 0.5, radius: 4, offset: .zero, path: { renderable in
            CGPath(rect: CGRect(origin: .zero, size: renderable.frame.size), transform: nil)
          })
          .frame(width: .flexible, height: Constants.rowHeight)
        }
      }
    }
    view.refresh(animated: false)

    // when: the view scrolls through the whole list
    scrollDown(view)

    // then: InnerShadowNode added leaving layers to the pool and reused them for entering rows, all under a
    // framework-internal bucket
    expect(pool.enqueueCount) > 0
    expect(pool.dequeueCount) > 0
    expect(pool.keys.allSatisfy { $0.reuseId.namespace == .framework && $0.reuseId.id == "InnerShadowLayer" }) == true
  }

  func test_dropShadowNode_poolsByDefault_acrossScroll() {
    // given: a recording pool and a list of drop shadow rows, rendered for the initial fill
    let pool = RecordingRenderablePool()
    let view = ComposeView(frame: CGRect(origin: .zero, size: Constants.viewSize))
    view.renderablePool = pool
    view.setContent {
      VStack {
        for _ in 0 ..< Constants.rowCount {
          // no explicit reuse id: DropShadowNode pools by default.
          DropShadowNode(color: .black, opacity: 0.5, radius: 4, offset: .zero, path: { renderable in
            CGPath(rect: CGRect(origin: .zero, size: renderable.frame.size), transform: nil)
          })
          .frame(width: .flexible, height: Constants.rowHeight)
        }
      }
    }
    view.refresh(animated: false)

    // when: the view scrolls through the whole list
    scrollDown(view)

    // then: DropShadowNode added leaving layers to the pool and reused them for entering rows, all under a
    // framework-internal bucket
    // these plain (no cutout) rows never install a mask, so the reset's guard takes its no-op branch on each enqueue.
    expect(pool.enqueueCount) > 0
    expect(pool.dequeueCount) > 0
    expect(pool.keys.allSatisfy { $0.reuseId.namespace == .framework && $0.reuseId.id == "DropShadowLayer" }) == true
  }

  func test_dropShadowNode_recycledLayer_clearsCutoutMaskFromPreviousUse() {
    // a cutout mask installed in one use must not carry into the pool (the layer's `update` only sets the mask when a
    // cutout is provided, so a reuse without a cutout would otherwise leak the stale mask).

    // given: a recording pool and a rendered drop shadow node with a cutout
    let pool = RecordingRenderablePool()
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.renderablePool = pool

    view.setContent {
      DropShadowNode(color: .black, opacity: 0.5, radius: 4, offset: .zero, paths: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: CGPath(rect: rect.insetBy(dx: 10, dy: 10), transform: nil))
      })
      .frame(width: 100, height: 100)
    }
    view.refresh(animated: false)

    // the cutout installed a mask on the rendered layer.
    expect(firstDropShadowLayer(in: view)?.mask) != nil

    // when: the node is removed so its layer is enqueued to the pool
    view.setContent {
      Empty()
    }
    view.refresh(animated: false)

    // then: the layer is enqueued with the cutout mask cleared for reuse
    let enqueued = pool.lastEnqueuedRenderable
    expect(enqueued?.layer.mask) == nil

    // when: a plain (no cutout) drop shadow node reuses the pooled layer
    view.setContent {
      DropShadowNode(color: .black, opacity: 0.5, radius: 4, offset: .zero, path: { renderable in
        CGPath(rect: CGRect(origin: .zero, size: renderable.frame.size), transform: nil)
      })
      .frame(width: 100, height: 100)
    }
    view.refresh(animated: false)

    // then: the plain (no cutout) DropShadowNode reused the very same enqueued layer and it carries no stale mask
    expect(pool.lastDequeuedRenderable?.layer) === enqueued?.layer
    expect(enqueued?.layer.mask) == nil
  }

  // MARK: - In-flight animation cleanup

  func test_colorNode_recycledLayer_scrubsInFlightAnimationFromPreviousUse() throws {
    // a layer added to the pool mid-animation (e.g. an animated color change interrupted by scrolling the row off-screen)
    // must not keep that animation: the render pass only disables implicit actions, so the explicit animation would
    // otherwise survive in the pool and leak into the next, possibly non-animated, reuse.

    // given: a recording pool and a rendered color node with an in-flight animation on its layer
    let pool = RecordingRenderablePool()
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.renderablePool = pool

    view.setContent {
      ColorNode(.red).frame(width: 100, height: 100)
    }
    view.refresh(animated: false)

    // simulate an in-flight animation left on the layer by a prior animated change.
    let layer = try firstColorLayer(in: view).unwrap()
    let animation = CABasicAnimation(keyPath: "backgroundColor")
    animation.duration = 10
    layer.add(animation, forKey: "backgroundColor")
    expect(layer.animationKeys()?.isEmpty) == false

    // when: the node is removed so its layer is enqueued to the pool
    view.setContent {
      Empty()
    }
    view.refresh(animated: false)

    // then: the same layer is enqueued, scrubbed of its in-flight animation, so reuse starts from a clean state
    expect(pool.lastEnqueuedRenderable?.layer) === layer
    expect(layer.animationKeys() ?? []) == []
  }

  func test_innerShadowNode_recycledLayer_scrubsMaskAnimationFromPreviousUse() throws {
    // the inner shadow keeps its mask attached across reuses, so the centralized pooling scrub (which only reaches the
    // layer itself) can't clear an in-flight mask animation; the node's reset must.

    // given: a recording pool and a rendered inner shadow node with an in-flight animation on its mask
    let pool = RecordingRenderablePool()
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.renderablePool = pool

    view.setContent {
      InnerShadowNode(color: .black, opacity: 0.5, radius: 4, offset: .zero, path: { renderable in
        CGPath(rect: CGRect(origin: .zero, size: renderable.frame.size), transform: nil)
      })
      .frame(width: 100, height: 100)
    }
    view.refresh(animated: false)

    // simulate an in-flight animation left on the mask by a prior animated change.
    let mask = try firstInnerShadowLayer(in: view).unwrap().mask.unwrap()
    let animation = CABasicAnimation(keyPath: "path")
    animation.duration = 10
    mask.add(animation, forKey: "path")
    expect(mask.animationKeys()?.isEmpty) == false

    // when: the node is removed so its layer is enqueued to the pool
    view.setContent {
      Empty()
    }
    view.refresh(animated: false)

    // then: the mask stays attached but is scrubbed of its in-flight animation
    expect(pool.lastEnqueuedRenderable?.layer.mask) === mask
    expect(mask.animationKeys() ?? []) == []
  }

  func test_dropShadowNode_recycledLayer_scrubsCutoutMaskAnimationFromPreviousUse() throws {
    // the drop shadow detaches its cutout mask on reset, but the mask layer instance is retained and re-attached on a
    // later cutout update, so its in-flight animation must be cleared before it is detached.

    // given: a recording pool and a rendered drop shadow node with an in-flight animation on its cutout mask
    let pool = RecordingRenderablePool()
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.renderablePool = pool

    view.setContent {
      DropShadowNode(color: .black, opacity: 0.5, radius: 4, offset: .zero, paths: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: CGPath(rect: rect.insetBy(dx: 10, dy: 10), transform: nil))
      })
      .frame(width: 100, height: 100)
    }
    view.refresh(animated: false)

    // simulate an in-flight animation left on the cutout mask by a prior animated change.
    let mask = try firstDropShadowLayer(in: view).unwrap().mask.unwrap()
    let animation = CABasicAnimation(keyPath: "path")
    animation.duration = 10
    mask.add(animation, forKey: "path")
    expect(mask.animationKeys()?.isEmpty) == false

    // when: the node is removed so its layer is enqueued to the pool
    view.setContent {
      Empty()
    }
    view.refresh(animated: false)

    // then: the mask is detached for reuse and its in-flight animation is cleared, so a later cutout reuse won't leak it
    expect(pool.lastEnqueuedRenderable?.layer.mask) == nil
    expect(mask.animationKeys() ?? []) == []
  }

  // MARK: - Pool configuration

  func test_renderablePool_defaultsToSharedPool() {
    // given: a compose view
    let view = ComposeView(frame: CGRect(origin: .zero, size: Constants.viewSize))

    // then: by default a view uses the process-wide shared pool, so reuse is amortized across views
    expect(view.renderablePool === RenderablePool.shared) == true
  }

  func test_renderablePool_disabled_doesNotRecycle() {
    // given: a rows view with a reuse id but pooling disabled, rendered for the initial fill
    let counter = MakeCounter()
    let view = makeRowsView(reuseId: "row", counter: counter, update: nil)
    view.renderablePool = nil // disable pooling despite the rows having a reuse identifier.
    view.refresh(animated: false)

    let initialMakeCount = counter.madeCount
    expect(initialMakeCount) > 0

    // when: the view scrolls through the whole list
    scrollDown(view)

    // then: with pooling disabled, each revealed row creates its own renderable (nothing is enqueued or reused)
    expect(counter.madeCount) == Constants.rowCount
    expect(counter.madeCount) > initialMakeCount
  }

  func test_renderablePool_customPool_isUsedForReuse() {
    // given: a rows view using a custom pool, rendered for the initial fill
    let counter = MakeCounter()
    let pool = MockRenderablePool()
    let view = makeRowsView(reuseId: "row", counter: counter, update: nil)
    view.renderablePool = pool
    view.refresh(animated: false)

    // when: the view scrolls through the whole list
    scrollDown(view)

    // then: the custom pool received enqueued renderables and handed them back for reuse
    expect(pool.enqueueCount) > 0
    expect(pool.dequeueCount) > 0
  }

  // MARK: - Reconfiguration (dirty-state contract)

  func test_reuseId_recycledRenderable_isReconfiguredForNewRow() {
    // given: a rows view with a reuse id, rendered for the initial fill
    let counter = MakeCounter()
    // each row stamps its own index onto the (possibly recycled) view on update.
    let view = makeRowsView(reuseId: "row", counter: counter, update: { rowView, index in
      rowView.configuredValue = index
    })
    view.refresh(animated: false)

    // when: the view scrolls to the bottom of the list
    scrollDown(view)

    // then: the recycled renderables were reconfigured to the current rows (no stale state)
    // at the bottom, the two visible rows are the last two (indices 58 and 59). Their renderables are recycled from
    // earlier rows.
    let configuredValues = visibleRowViews(in: view).map(\.configuredValue).sorted()
    expect(configuredValues) == [Constants.rowCount - 2, Constants.rowCount - 1]
  }

  // MARK: - Type safety

  func test_reuseId_sharedAcrossDifferentTypes_doesNotCrash() {
    // even rows are backed by `RowViewA`, odd rows by `RowViewB`, all sharing the same reuse identifier. The pool key
    // includes the concrete type, so a enqueued `RowViewA` is never handed to a `RowViewB` item (which would crash on the
    // `as!` cast in the update closure). Completing the scroll without crashing exercises that guard.

    // given: a list mixing two row view types under one reuse id, rendered for the initial fill
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

    // when: the view scrolls through the whole list
    scrollDown(view)

    // then: both types were created and recycled within their own type bucket
    expect(counterA.madeCount) > 0
    expect(counterB.madeCount) > 0
    // the visible views at the bottom must be the correct concrete types for their rows (58 -> A, 59 -> B).
    let bottomTypes = visibleRowTypeNames(in: view)
    expect(bottomTypes.contains("RowViewA")) == true
    expect(bottomTypes.contains("RowViewB")) == true
  }

  // MARK: - Modifier semantics

  func test_reuseIdModifier_setsReuseIdAndResolvesKey() {
    // given: a color node with a user reuse id
    let item = firstRenderableItem(of: ColorNode(.red).reuseId("x").frame(width: 100, height: 100))

    // then: the item carries the user reuse id and resolves a reuse key
    expect(item?.reuseId) == ReuseId(namespace: .user, id: "x")
    expect(item?.reuseKey) != nil
  }

  func test_reuseIdModifier_innerWins_whenCoalesced() {
    // given: two adjacent reuse identifiers that coalesce into one modifier node
    let item = firstRenderableItem(of: ColorNode(.red).reuseId("inner").reuseId("outer").frame(width: 100, height: 100))

    // then: the inner one wins
    expect(item?.reuseId) == ReuseId(namespace: .user, id: "inner")
  }

  func test_reuseIdModifier_innerWins_acrossNodeBoundary() {
    // given: an outer reuse identifier applied across a frame boundary
    let item = firstRenderableItem(of: ColorNode(.red).reuseId("inner").frame(width: 100, height: 100).reuseId("outer"))

    // then: the outer identifier must not overwrite the inner one already on the item
    expect(item?.reuseId) == ReuseId(namespace: .user, id: "inner")
  }

  func test_nonPoolingNode_withoutReuseId_resolvesNilKey() {
    // given: a node that does not pool by default (here a `LayerNode`) and is not given a reuse id
    let item = firstRenderableItem(of: LayerNode<CALayer>().frame(width: 100, height: 100))

    // then: the item has no reuse key
    expect(item?.reuseId) == nil
    expect(item?.reuseKey) == nil
  }

  // MARK: - Default pooling (internal reuse id) and isolation

  func test_colorNode_defaultReuseKey_usesFrameworkNamespace() {
    // given: a plain color node
    let item = firstRenderableItem(of: ColorNode(.red).frame(width: 100, height: 100))

    // then: ColorNode opts into pooling by default with a framework-internal reuse id
    expect(item?.reuseId) == ReuseId(namespace: .framework, id: "CALayer")
    expect(item?.reuseKey?.reuseId) == ReuseId(namespace: .framework, id: "CALayer")
  }

  func test_textNode_defaultReuseKey_usesFrameworkNamespace() {
    // given: a plain text node
    let item = firstRenderableItem(of: TextNode("Hello").frame(width: 100, height: 100))

    // then: TextNode opts into pooling by default with a framework-internal reuse id
    expect(item?.reuseId) == ReuseId(namespace: .framework, id: "BaseTextView")
    expect(item?.reuseKey?.reuseId) == ReuseId(namespace: .framework, id: "BaseTextView")
  }

  func test_colorNode_userReuseId_overridesInternalReuseId_andUsesUserNamespace() {
    // given: a color node with an explicit user reuse id
    let item = firstRenderableItem(of: ColorNode(.red).reuseId("custom").frame(width: 100, height: 100))

    // then: the user reuse id replaces the framework-internal identity, so the caller stays in control of pooling
    expect(item?.reuseId) == ReuseId(namespace: .user, id: "custom")
    expect(item?.reuseKey?.reuseId) == ReuseId(namespace: .user, id: "custom")
  }

  func test_innerShadowNode_defaultReuseKey_usesFrameworkNamespace() {
    // given: a plain inner shadow node
    let item = firstRenderableItem(of: InnerShadowNode(color: .black, opacity: 0.5, radius: 4, offset: .zero, path: { _ in
      CGPath(rect: .zero, transform: nil)
    }).frame(width: 100, height: 100))

    // then: InnerShadowNode opts into pooling by default with a framework-internal reuse id
    expect(item?.reuseId) == ReuseId(namespace: .framework, id: "InnerShadowLayer")
    expect(item?.reuseKey?.reuseId) == ReuseId(namespace: .framework, id: "InnerShadowLayer")
  }

  func test_dropShadowNode_defaultReuseKey_usesFrameworkNamespace() {
    // given: a plain drop shadow node
    let item = firstRenderableItem(of: DropShadowNode(color: .black, opacity: 0.5, radius: 4, offset: .zero, path: { _ in
      CGPath(rect: .zero, transform: nil)
    }).frame(width: 100, height: 100))

    // then: DropShadowNode opts into pooling by default with a framework-internal reuse id
    expect(item?.reuseId) == ReuseId(namespace: .framework, id: "DropShadowLayer")
    expect(item?.reuseKey?.reuseId) == ReuseId(namespace: .framework, id: "DropShadowLayer")
  }

  func test_internalReuseId_doesNotOverrideExistingInternalReuseId() {
    // given: an item assigned two internal reuse ids
    let item = LayerItem<CALayer>(id: .custom("l"), frame: .zero, make: { _ in CALayer() }, update: { _, _ in })
      .eraseToRenderableItem()
      .reuseId(ReuseId(namespace: .framework, id: "first"))
      .reuseId(ReuseId(namespace: .framework, id: "second"))

    // then: the first internal reuse id wins, a second assignment is a no-op
    expect(item.reuseId) == ReuseId(namespace: .framework, id: "first")
  }

  func test_publicInit_withReuseId_setsUserIdentity() {
    // given: an item made with the public initializer taking a reuse id
    let item = LayerItem<CALayer>(id: .custom("l"), frame: .zero, make: { _ in CALayer() }, update: { _, _ in }, reuseId: "x")

    // then: the reuse id is treated as a user-provided identifier
    expect(item.reuseId) == ReuseId(namespace: .user, id: "x")
    expect(item.reuseKey?.reuseId) == ReuseId(namespace: .user, id: "x")
  }

  func test_userReuseId_matchingInternalReuseIdString_resolvesDistinctKey() {
    // given: a framework-pooled item and a user item whose reuse id string equals ColorNode's framework-internal one
    let frameworkItem = firstRenderableItem(of: ColorNode(.red).frame(width: 100, height: 100))
    let userItem = firstRenderableItem(of: ColorNode(.red).reuseId("CALayer").frame(width: 100, height: 100))

    // then: the namespaces keep the keys distinct so a user renderable can never share a pool bucket with a
    // framework-internal one
    expect(frameworkItem?.reuseKey?.reuseId.id) == "CALayer"
    expect(userItem?.reuseKey?.reuseId.id) == "CALayer"
    expect(frameworkItem?.reuseKey) != userItem?.reuseKey
  }

  // MARK: - Transition interaction

  func test_reuseId_renderableIsPooledOnlyAfterRemoveTransitionCompletes() {
    // given: a pool-isolated compose view showing a color node with a remove transition and a reuse id
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

    // when: the content is removed with animation
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: while the remove transition is in flight, the renderable is enqueued in the removing map and must not be
    // pooled (it may still be re-inserted)
    expect(contentView.test.removingRenderableMap.count) == 1
    expect(pool.count) == 0

    // when: the remove transition completes
    removalCompletion?()

    // then: the renderable is moved into the pool for reuse
    expect(contentView.test.removingRenderableMap.count) == 0
    expect(pool.count) == 1
  }

  func test_reuseId_transitionResetForReuse_isCalledBeforePooling() {
    // given: a pool-isolated compose view showing a color node with a residue-leaving remove transition
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

    // when: the content is removed with animation
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: while the remove transition is in flight, the residue is present and the renderable is not yet pooled
    expect(removedLayer?.opacity) == 0
    expect(pool.count) == 0

    // when: the remove transition completes
    removalCompletion?()

    // then: the engine asks the transition to reset its residue before pooling, so the enqueued renderable is clean
    // (visible) and a future reuse does not re-insert it invisible
    expect(removedLayer?.opacity) == 1
    expect(pool.count) == 1

    // when: reuse the enqueued renderable for a new row
    contentView.setContent {
      ColorNode(.blue)
        .transition(transition)
        .reuseId("x")
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: false)

    // then: the renderable is dequeued and stays visible (no leftover fade)
    expect(pool.count) == 0
    expect(removedLayer?.opacity) == 1
  }

  func test_reuseId_renderableReinsertedDuringRemoveTransition_isNotPooled() {
    // given: a pool-isolated compose view showing a color node with a never-completing remove transition
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

    // when: the content is removed with animation
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: the renderable parks in the removing map and is not pooled
    expect(contentView.test.removingRenderableMap.count) == 1
    expect(pool.count) == 0

    // when: re-insert the same node
    contentView.setContent {
      ColorNode(.red)
        .transition(transition)
        .reuseId("x")
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: true)

    // then: the in-flight removal is cancelled and the renderable is revived, so it must never be pooled
    expect(contentView.test.removingRenderableMap.count) == 0
    expect(pool.count) == 0
  }

  // MARK: - Reset for reuse

  func test_onResetForReuse_isCalledOnlyForPooledReuse() {
    // given: a list of reuse-tracking rows with an onResetForReuse hook, rendered for the initial fill
    let counter = MakeCounter()
    var resetForReuseCount = 0

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
          .onResetForReuse { renderable in
            (renderable.view as? ReuseTrackingView)?.wasResetForReuse = true
            resetForReuseCount += 1
          }
        }
      }
    }
    view.refresh(animated: false)

    // the initial fill only makes and inserts renderables; nothing is enqueued yet, so the hook never fired.
    expect(resetForReuseCount) == 0
    expect(visibleRowViews(in: view).contains { $0.wasResetForReuse }) == false

    // when: the view scrolls through the whole list
    scrollDown(view)

    // then: the hook fired for each enqueued row, and the visible (recycled) rows are flagged as reset
    // every row that left the viewport during the scroll was enqueued, so the hook fired for each enqueuing. the
    // visible (recycled) rows were themselves enqueued earlier and are therefore flagged as reset.
    expect(resetForReuseCount) > 0
    expect(visibleRowViews(in: view).allSatisfy(\.wasResetForReuse)) == true
  }

  func test_onResetForReuse_coalescedHooks_runInOrder() {
    // given: two adjacent onResetForReuse hooks that coalesce into one combined block
    var calls: [String] = []
    let item = firstRenderableItem(
      of: ViewNode<ReuseTrackingView>(make: { _ in ReuseTrackingView() })
        .onResetForReuse { _ in calls.append("a") }
        .onResetForReuse { _ in calls.append("b") }
        .frame(width: 100, height: 100)
    )

    // when: the item's resetForReuse runs
    item?.resetForReuse?(.view(ReuseTrackingView()))

    // then: both hooks run, outer after inner
    expect(calls) == ["a", "b"]
  }

  func test_onResetForReuse_hooksStackedAcrossNodeBoundary_runInOrder() {
    // given: an inner hook (below a frame boundary) and an outer hook (coalesced with a reuse identifier)
    var calls: [String] = []
    let item = firstRenderableItem(
      of: ViewNode<ReuseTrackingView>(make: { _ in ReuseTrackingView() })
        .onResetForReuse { _ in calls.append("inner") }
        .frame(width: 100, height: 100)
        .onResetForReuse { _ in calls.append("outer") }
        .reuseId("x")
    )

    // when: the item's resetForReuse runs
    item?.resetForReuse?(.view(ReuseTrackingView()))

    // then: both hooks run, inner first
    expect(calls) == ["inner", "outer"]
  }

  func test_renderItem_erasurePreservesResetForReuse() {
    // a typed item's resetForReuse survives type erasure and runs against the concrete renderable.

    // when: a type-erased view item's resetForReuse runs
    var viewCalls = 0
    let viewItem = ViewItem<ReuseTrackingView>(
      id: .custom("v"),
      frame: .zero,
      make: { _ in ReuseTrackingView() },
      update: { _, _ in },
      resetForReuse: { _ in viewCalls += 1 }
    ).eraseToRenderableItem()
    viewItem.resetForReuse?(.view(ReuseTrackingView()))

    // then: the hook runs against the concrete view
    expect(viewCalls) == 1

    // when: a type-erased layer item's resetForReuse runs
    var layerCalls = 0
    let layerItem = LayerItem<CALayer>(
      id: .custom("l"),
      frame: .zero,
      make: { _ in CALayer() },
      update: { _, _ in },
      resetForReuse: { _ in layerCalls += 1 }
    ).eraseToRenderableItem()
    layerItem.resetForReuse?(.layer(CALayer()))

    // then: the hook runs against the concrete layer
    expect(layerCalls) == 1
  }

  func test_colorNode_pooledLayerHasNoColorResidue() {
    // ColorNode pools its layer with a framework-internal reuse id, the enqueued layer must be
    // freshly-made-equivalent, with no stale background color from its previous use.

    // given: a pool-isolated compose view showing a red color node, recording the pooled layer
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let pool = RenderablePool()
    contentView.renderablePool = pool

    var pooledLayer: CALayer?
    contentView.debug { _, event in
      if case .renderDidRemoveRenderable(_, let renderable) = event {
        pooledLayer = renderable.layer
      }
    }

    contentView.setContent {
      ColorNode(.red).frame(width: 100, height: 100)
    }
    contentView.refresh(animated: false)

    // when: the node is removed so its layer is pooled
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: false)

    // then: the pooled layer has no stale background color
    expect(pool.count) == 1
    expect(pooledLayer) != nil
    expect(pooledLayer?.backgroundColor) == nil
  }

  func test_pooledRenderable_zPositionIsReset() {
    // the render pass owns the renderable layer's `zPosition` (assigned per render pass for the cross-kind
    // z-order); a pooled renderable must have it reset so the reused renderable is freshly-made-equivalent.

    // given: a pool-isolated compose view showing stacked color nodes with a z-index, recording the pooled layer
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let pool = RenderablePool()
    contentView.renderablePool = pool

    var pooledLayer: CALayer?
    contentView.debug { _, event in
      if case .renderDidRemoveRenderable(_, let renderable) = event {
        pooledLayer = renderable.layer
      }
    }

    contentView.setContent {
      ZStack {
        ColorNode(.blue).frame(width: 100, height: 100)
        ColorNode(.red).zIndex(3).frame(width: 100, height: 100)
      }
    }
    contentView.refresh(animated: false)

    // when: the nodes are removed so their layers are pooled
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: false)

    // then: the pooled layer's zPosition is reset
    expect(pool.count) == 2
    expect(pooledLayer) != nil
    expect(pooledLayer?.zPosition) == 0
  }

  func test_onResetForReuse_firesForLayerBackedReuse() {
    // a layer-backed node (ColorNode) also receives the hook when its layer is enqueued, exercising the layer erasure path.

    // given: a list of color rows with an onResetForReuse hook, rendered for the initial fill
    var resetForReuseCount = 0
    let view = ComposeView(frame: CGRect(origin: .zero, size: Constants.viewSize))
    view.renderablePool = RenderablePool() // isolate from the shared pool so reuse counts are deterministic.
    view.setContent {
      VStack {
        for i in 0 ..< Constants.rowCount {
          ColorNode(i.isMultiple(of: 2) ? .red : .blue)
            .frame(width: .flexible, height: Constants.rowHeight)
            .reuseId("color")
            .onResetForReuse { _ in resetForReuseCount += 1 }
        }
      }
    }
    view.refresh(animated: false)

    expect(resetForReuseCount) == 0

    // when: the view scrolls through the whole list
    scrollDown(view)

    // then: the hook fired for the enqueued layers
    expect(resetForReuseCount) > 0
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

  private func firstDropShadowLayer(in view: ComposeView) -> DropShadowLayer? {
    contentSublayers(in: view)?.compactMap { $0 as? DropShadowLayer }.first
  }

  private func firstInnerShadowLayer(in view: ComposeView) -> InnerShadowLayer? {
    contentSublayers(in: view)?.compactMap { $0 as? InnerShadowLayer }.first
  }

  /// The plain `CALayer` rendered by a `ColorNode` (matched by exact type so shadow layer subclasses are excluded).
  private func firstColorLayer(in view: ComposeView) -> CALayer? {
    contentSublayers(in: view)?.first { type(of: $0) == CALayer.self }
  }

  private func firstBaseTextView(in view: ComposeView) -> BaseTextView? {
    view.contentView().subviews.compactMap { $0 as? BaseTextView }.first
  }

  private func contentSublayers(in view: ComposeView) -> [CALayer]? {
    #if canImport(AppKit)
    return view.contentView().layer?.sublayers
    #endif
    #if canImport(UIKit)
    return view.contentView().layer.sublayers
    #endif
  }
}

// MARK: - Test views

/// Counts how many renderables a node's `make` closure creates.
private final class MakeCounter {

  var madeCount = 0
}

private final class ReuseTrackingView: View {

  var configuredValue: Int = -1
  var wasResetForReuse = false
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

/// A custom `RenderablePool` that records the keys and renderables it sees, delegating to a real pool, to verify how
/// `ComposeView` parks and reuses renderables.
private final class RecordingRenderablePool: RenderablePoolType {

  private(set) var enqueueCount = 0
  private(set) var dequeueCount = 0
  private(set) var keys: [ReuseKey] = []
  private(set) var lastEnqueuedRenderable: Renderable?
  private(set) var lastDequeuedRenderable: Renderable?

  private let backing = RenderablePool()

  func enqueue(_ renderable: Renderable, key: ReuseKey) {
    enqueueCount += 1
    keys.append(key)
    lastEnqueuedRenderable = renderable
    backing.enqueue(renderable, key: key)
  }

  func dequeue(_ key: ReuseKey) -> Renderable? {
    dequeueCount += 1
    keys.append(key)
    let renderable = backing.dequeue(key)
    lastDequeuedRenderable = renderable
    return renderable
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
