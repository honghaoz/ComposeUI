//
//  ComposeView+ZOrderTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 6/12/26.
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

import CoreGraphics
import Foundation

import ChouTiTest

@testable import ComposeUI

/// Tests that pin the z-order contract of `ComposeView`'s render pass:
///
/// After a render pass, the renderables must render in the renderable items order (back to front), regardless of the
/// renderable's kind (view or layer):
/// - The effective render order of the renderable layers (sibling layers sorted by `zPosition`, with the sublayer list
///   order breaking ties) matches the items order across both kinds.
/// - The content view's subviews, filtered to renderable views, are in the items order restricted to view items, so the
///   hit-testing order matches the visual order among view items.
class ComposeView_ZOrderTests: XCTestCase {

  /// The window hosting the view under test, kept alive so the (AppKit) display pass can attach and re-stack the subviews' backing layers.
  private var hostWindow: TestWindow?

  override func tearDown() {
    hostWindow = nil
    super.tearDown()
  }

  /// Records the latest render pass result via the debug event handler.
  private class RenderRecorder {

    private(set) var renderableItemIds: [String] = []
    private(set) var renderableMap: [String: Renderable] = [:]

    /// Whether at least one render pass had a different set of item ids than the previous one.
    private(set) var sawItemIdsChange: Bool = false

    func attach(to view: ComposeView) {
      view.debug { [weak self] _, event in
        guard let self else {
          return
        }
        if case .renderDidFinish(let ids, _, let renderableMap) = event {
          // map the `ComposeNodeId` keys to their string ids so the tests can keep asserting on readable ids.
          let stringIds = ids.map(\.id)
          if !self.renderableItemIds.isEmpty, stringIds != self.renderableItemIds {
            self.sawItemIdsChange = true
          }
          self.renderableItemIds = stringIds
          self.renderableMap = Dictionary(uniqueKeysWithValues: renderableMap.map { ($0.key.id, $0.value) })
        }
      }
    }
  }

  /// Verifies the renderables render in the latest render pass's item order.
  ///
  /// The pinned contract is:
  /// - All items: the effective render order of the renderable layers, sibling layers sorted by `zPosition`, with the
  ///   sublayer list order breaking ties, which is how Core Animation composites siblings, matches the items order,
  ///   regardless of the renderable's kind (view or layer).
  /// - View items: the content view's subviews, restricted to view items, are in the items order. This keeps the
  ///   hit-testing order in sync with the visual order among view items.
  private func expectHierarchyMatchesItemOrder(_ view: ComposeView,
                                               _ recorder: RenderRecorder,
                                               file: StaticString = #filePath,
                                               line: UInt = #line)
  {
    #if canImport(AppKit)
    // force a display pass so AppKit attaches the subviews' backing layers to the content view's layer and re-stacks
    // them (AppKit re-stacks all backing layers above the standalone sublayers at display time).
    // the effective render order below must survive the re-stack, since it is driven by `zPosition`.
    hostWindow?.displayIfNeeded()
    #endif

    let contentView: View = view.contentView()
    let ids = recorder.renderableItemIds

    // all renderables must be in the hierarchy
    for id in ids {
      guard let renderable = recorder.renderableMap[id] else {
        fail("missing renderable for id: \(id)", file: file, line: line)
        return
      }
      switch renderable {
      case .view(let renderableView):
        expect(renderableView.superview === contentView, "renderable view should be in content view, id: \(id)", file: file, line: line) == true
      case .layer(let renderableLayer):
        expect(renderableLayer.superlayer === contentView.layer(), "renderable layer should be in content view, id: \(id)", file: file, line: line) == true
      }
    }

    // the content view's subviews, filtered to renderable views, must be in the items order restricted to view items
    let expectedViews = ids.compactMap { recorder.renderableMap[$0]?.view }
    let expectedViewIds = Set(expectedViews.map { ObjectIdentifier($0) })
    let actualViews = contentView.subviews.filter { expectedViewIds.contains(ObjectIdentifier($0)) }
    expect(actualViews.map { ObjectIdentifier($0) }, "subviews order should match items order", file: file, line: line) == expectedViews.map { ObjectIdentifier($0) }

    // the effective render order of the renderable layers (view backing layers and layer items together) must
    // match the items order across both kinds
    let expectedLayers = ids.compactMap { recorder.renderableMap[$0]?.layer }
    let expectedLayerIds = Set(expectedLayers.map { ObjectIdentifier($0) })
    let actualLayers = Self.effectiveRenderOrder(of: contentView.layer()).filter { expectedLayerIds.contains(ObjectIdentifier($0)) }
    expect(actualLayers.map { ObjectIdentifier($0) }, "effective layer render order should match items order", file: file, line: line) == expectedLayers.map { ObjectIdentifier($0) }
  }

  /// The effective render order of the layer's sublayers (back to front): Core Animation composites sibling
  /// layers sorted by `zPosition`, with the sublayer list order breaking ties.
  static func effectiveRenderOrder(of layer: CALayer) -> [CALayer] {
    (layer.sublayers ?? [])
      .enumerated()
      .sorted { lhs, rhs in
        if lhs.element.zPosition != rhs.element.zPosition {
          return lhs.element.zPosition < rhs.element.zPosition
        }
        return lhs.offset < rhs.offset
      }
      .map(\.element)
  }

  /// Makes a `ComposeView` hosted in a test window so that view items' backing layers are attached
  /// to the content view's layer, like in a real app.
  private func makeHostedView(@ComposeContentBuilder content: @escaping () -> ComposeContent) -> (ComposeView, TestWindow) {
    let window = TestWindow()
    let view = ComposeView(content: content)
    window.contentView().addSubview(view)
    hostWindow = window
    return (view, window)
  }

  // MARK: - Initial Render

  func test_initialRender_mixedViewAndLayerItems() {
    // given: a hosted view with mixed view and layer items and a render recorder
    let (view, _) = makeHostedView {
      ZStack {
        ColorNode(.red)
        ViewNode()
        ColorNode(.blue)
        ViewNode()
      }
    }
    let recorder = RenderRecorder()
    recorder.attach(to: view)

    // when: the view renders initially
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)

    // then: the hierarchy matches the items order
    expect(recorder.renderableItemIds.count) == 4
    expectHierarchyMatchesItemOrder(view, recorder)
  }

  // MARK: - Scroll

  /// Makes a scrollable view with mixed (layer + view) rows, hosted in a test window.
  ///
  /// Each row has a vertically centered layer item and two stacked view items, so that scrolling reveals
  /// a row's items gradually across multiple frames (partial row reveal). This exercises new items entering
  /// in the middle of the z-order, in addition to new items entering at the edges.
  private func makeScrollableView() -> (ComposeView, TestWindow) {
    makeHostedView {
      VStack {
        for _ in 0 ..< 100 {
          HStack {
            ColorNode(.blue)
              .frame(width: 16, height: 16)
            VStack {
              ViewNode()
                .frame(width: .flexible, height: 25)
              ViewNode()
                .frame(width: .flexible, height: 25)
            }
          }
        }
      }
    }
  }

  func test_scrollDown_zOrderMaintained() {
    // given: a scrollable view with mixed rows and a render recorder, rendered initially
    let (view, _) = makeScrollableView()
    let recorder = RenderRecorder()
    recorder.attach(to: view)

    view.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
    view.refresh(animated: false)
    expectHierarchyMatchesItemOrder(view, recorder)

    // when: scroll down with a step that is a non-multiple of row height for varied row churn
    // then: the hierarchy matches the items order after each step
    var offset: CGFloat = 0
    for _ in 0 ..< 30 {
      offset += 35
      view.setContentOffset(CGPoint(x: 0, y: offset))
      view.layoutIfNeeded()
      expectHierarchyMatchesItemOrder(view, recorder)
    }

    // then: the scroll churned rows
    expect(recorder.sawItemIdsChange) == true // ensure rows actually churned
  }

  func test_scrollUp_zOrderMaintained() {
    // given: a scrollable view with mixed rows and a render recorder, rendered and scrolled to the bottom
    let (view, _) = makeScrollableView()
    let recorder = RenderRecorder()
    recorder.attach(to: view)

    view.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
    view.refresh(animated: false)

    // start scrolled down, then scroll up so that new rows enter at the back of the z-order
    var offset: CGFloat = 1050
    view.setContentOffset(CGPoint(x: 0, y: offset))
    view.layoutIfNeeded()
    expectHierarchyMatchesItemOrder(view, recorder)

    // when: scroll up step by step
    // then: the hierarchy matches the items order after each step
    for _ in 0 ..< 30 {
      offset -= 35
      view.setContentOffset(CGPoint(x: 0, y: offset))
      view.layoutIfNeeded()
      expectHierarchyMatchesItemOrder(view, recorder)
    }

    // then: the scroll churned rows
    expect(recorder.sawItemIdsChange) == true // ensure rows actually churned
  }

  // MARK: - Refresh

  func test_refresh_reorderedContent() {
    // given: a hosted view with a render recorder, rendered, using fixed ids so that reordering the content keeps the
    // same item ids
    var order: [String] = ["a", "b", "c"]
    let (view, _) = makeHostedView {
      ZStack {
        for key in order {
          if key == "b" {
            ViewNode().fixedId(key)
          } else {
            ColorNode(.red).fixedId(key)
          }
        }
      }
    }
    let recorder = RenderRecorder()
    recorder.attach(to: view)

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    expect(recorder.renderableItemIds) == ["a", "b", "c"]
    expectHierarchyMatchesItemOrder(view, recorder)

    // when: reverse the order, same ids
    order = ["c", "b", "a"]
    view.refresh(animated: false)

    // then: the hierarchy matches the reversed order
    expect(recorder.renderableItemIds) == ["c", "b", "a"]
    expectHierarchyMatchesItemOrder(view, recorder)

    // when: move the back item to the front, same ids
    order = ["b", "a", "c"]
    view.refresh(animated: false)

    // then: the hierarchy matches the new order
    expect(recorder.renderableItemIds) == ["b", "a", "c"]
    expectHierarchyMatchesItemOrder(view, recorder)
  }

  func test_refresh_insertionsAndRemovals() {
    // given: a hosted view with a render recorder, rendered with two fixed-id items
    var order: [String] = ["a", "c"]
    let (view, _) = makeHostedView {
      ZStack {
        for key in order {
          if key == "b" || key == "d" {
            ViewNode().fixedId(key)
          } else {
            ColorNode(.red).fixedId(key)
          }
        }
      }
    }
    let recorder = RenderRecorder()
    recorder.attach(to: view)

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    expect(recorder.renderableItemIds) == ["a", "c"]
    expectHierarchyMatchesItemOrder(view, recorder)

    // when: insert in the middle
    order = ["a", "b", "c"]
    view.refresh(animated: false)

    // then: the hierarchy matches the items order
    expect(recorder.renderableItemIds) == ["a", "b", "c"]
    expectHierarchyMatchesItemOrder(view, recorder)

    // when: insert at the back (z-order bottom) and the front (z-order top)
    order = ["z", "a", "b", "c", "d"]
    view.refresh(animated: false)

    // then: the hierarchy matches the items order
    expect(recorder.renderableItemIds) == ["z", "a", "b", "c", "d"]
    expectHierarchyMatchesItemOrder(view, recorder)

    // when: remove from the middle
    order = ["z", "b", "d"]
    view.refresh(animated: false)

    // then: the hierarchy matches the items order
    expect(recorder.renderableItemIds) == ["z", "b", "d"]
    expectHierarchyMatchesItemOrder(view, recorder)

    // when: remove only, no inserts
    order = ["b"]
    view.refresh(animated: false)

    // then: the hierarchy matches the items order
    expect(recorder.renderableItemIds) == ["b"]
    expectHierarchyMatchesItemOrder(view, recorder)
  }

  func test_refresh_placementWithInFlightRemovingViews() {
    // views being removed with an in-flight remove transition stay in the hierarchy but are not part of the
    // new render pass. placing new views below retained siblings must stay correct even with these
    // in-transition views interleaved in the subview list.

    // given: a hosted view with a render recorder, rendered with two never-completing removing views interleaved
    let neverCompletingRemove = RenderableTransition(
      insert: nil,
      remove: RenderableTransition.RemoveTransition { _, _, _ in
        // intentionally never completes, keeps the removing views in the hierarchy
      }
    )

    var order: [String] = ["r1", "a", "b", "r2", "c"]
    let (view, _) = makeHostedView {
      ZStack {
        for key in order {
          if key.hasPrefix("r") {
            ViewNode().transition(neverCompletingRemove).fixedId(key)
          } else {
            ViewNode().fixedId(key)
          }
        }
      }
    }
    let recorder = RenderRecorder()
    recorder.attach(to: view)

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    expect(recorder.renderableItemIds) == ["r1", "a", "b", "r2", "c"]
    expectHierarchyMatchesItemOrder(view, recorder)

    // keep the removing views to check their positions after the next render pass
    guard let removingView1 = recorder.renderableMap["r1"]?.view,
          let removingView2 = recorder.renderableMap["r2"]?.view,
          let viewB = recorder.renderableMap["b"]?.view,
          let viewC = recorder.renderableMap["c"]?.view
    else {
      fail("missing renderable views")
      return
    }

    // when: remove the "r" views (their remove transitions keep them in the hierarchy) and insert new views
    // that belong below retained views
    order = ["a", "n1", "b", "n2", "c"]
    view.refresh(animated: true)

    // then: the hierarchy matches the new items order
    expect(recorder.renderableItemIds) == ["a", "n1", "b", "n2", "c"]
    expect(view.test.removingRenderableMap.count) == 2
    expectHierarchyMatchesItemOrder(view, recorder)

    // then: the in-transition removing views keep their z-positions relative to the retained views:
    // "r1" stays at the back, "r2" stays above "b" and below "c"
    let subviews = view.contentView().subviews
    guard let removingIndex1 = subviews.firstIndex(of: removingView1),
          let removingIndex2 = subviews.firstIndex(of: removingView2),
          let indexB = subviews.firstIndex(of: viewB),
          let indexC = subviews.firstIndex(of: viewC)
    else {
      fail("missing subviews")
      return
    }
    expect(removingIndex1) == 0
    expect(removingIndex2) > indexB
    expect(removingIndex2) < indexC
  }

  // MARK: - Z-Index

  func test_zIndex_bandsAcrossKinds() {
    // items with an explicit z-index render in bands: a higher band renders above a lower band regardless of the items
    // order. Within a band, items render in the items order. bands apply across kinds (views and layers).

    // given: a hosted view with items in bands -1, 0 and 1 across kinds, and a render recorder
    let (view, _) = makeHostedView {
      ZStack {
        ViewNode().zIndex(1).fixedId("v-top") // band 1: renders above everything
        ColorNode(.red).fixedId("l-mid1") // band 0
        ViewNode().fixedId("v-mid") // band 0
        ColorNode(.blue).zIndex(-1).fixedId("l-back") // band -1: renders below everything
        ColorNode(.green).fixedId("l-mid2") // band 0
      }
    }
    let recorder = RenderRecorder()
    recorder.attach(to: view)

    // when: the view renders
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)

    #if canImport(AppKit)
    hostWindow?.displayIfNeeded()
    #endif

    // then: the effective render order (back to front) is band -1, then band 0 in the items order, then band 1
    let expectedIds = ["l-back", "l-mid1", "v-mid", "l-mid2", "v-top"]
    let expectedLayers = expectedIds.compactMap { recorder.renderableMap[$0]?.layer }
    expect(expectedLayers.count) == 5
    let renderableLayerIds = Set(expectedLayers.map { ObjectIdentifier($0) })
    let actualLayers = Self.effectiveRenderOrder(of: view.contentView().layer()).filter { renderableLayerIds.contains(ObjectIdentifier($0)) }
    expect(actualLayers.map { ObjectIdentifier($0) }) == expectedLayers.map { ObjectIdentifier($0) }
  }

  func test_removingRenderable_keepsZPosition() {
    // a renderable with an in-flight remove transition is not part of the new render pass, so its `zPosition` is not
    // reassigned: it holds its last assigned value and stays visually in place during the removal.

    // given: a hosted view with a render recorder, rendered with a removing-capable item between two others
    let neverCompletingRemove = RenderableTransition(
      insert: nil,
      remove: RenderableTransition.RemoveTransition { _, _, _ in
        // intentionally never completes, keeps the removing renderable in the hierarchy
      }
    )

    var showsRemoving = true
    let (view, _) = makeHostedView {
      ZStack {
        ColorNode(.red).fixedId("a")
        if showsRemoving {
          ColorNode(.blue).transition(neverCompletingRemove).fixedId("removing")
        }
        ColorNode(.green).fixedId("b")
      }
    }
    let recorder = RenderRecorder()
    recorder.attach(to: view)

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)

    guard let removingLayer = recorder.renderableMap["removing"]?.layer else {
      fail("missing removing renderable")
      return
    }
    let zPositionBeforeRemoval = removingLayer.zPosition
    expect(zPositionBeforeRemoval) == 2 * view.test.zPositionStep // band 0, item index 1

    // when: the item is removed with an in-flight remove transition
    showsRemoving = false
    view.refresh(animated: true)

    // then: the removing renderable holds its last assigned zPosition
    expect(view.test.removingRenderableMap.count) == 1
    expect(removingLayer.zPosition) == zPositionBeforeRemoval
  }

  func test_refresh_readdDuringRemoveTransition() {
    // removing a renderable with a transition keeps it in the hierarchy until the transition completes.
    // re-adding the item during the transition should recover the renderable and restore the correct z-order.

    // given: a hosted view with a render recorder, rendered with three items with opacity transitions
    var order: [String] = ["a", "b", "c"]
    let (view, _) = makeHostedView {
      ZStack {
        for key in order {
          ColorNode(.red)
            .transition(.opacity(timing: .easeInEaseOut(duration: 1)))
            .fixedId(key)
        }
      }
    }
    let recorder = RenderRecorder()
    recorder.attach(to: view)

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    expect(recorder.renderableItemIds) == ["a", "b", "c"]
    expectHierarchyMatchesItemOrder(view, recorder)

    // when: remove "b" with an in-flight remove transition (animated so that the remove transition runs)
    order = ["a", "c"]
    view.refresh(animated: true)

    // then: the hierarchy matches the items order
    expect(recorder.renderableItemIds) == ["a", "c"]
    expectHierarchyMatchesItemOrder(view, recorder)

    // when: re-add "b" while its remove transition is still running
    order = ["a", "b", "c"]
    view.refresh(animated: true)

    // then: the renderable is recovered and placed back between "a" and "c"
    expect(recorder.renderableItemIds) == ["a", "b", "c"]
    expectHierarchyMatchesItemOrder(view, recorder)
  }
}
