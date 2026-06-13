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
/// After a render pass, the renderable hierarchy must match the renderable items order (back to front):
/// - The content view's sublayers, filtered to renderable layers, are in the items order.
/// - The content view's subviews, filtered to renderable views, are in the items order restricted to view items.
class ComposeView_ZOrderTests: XCTestCase {

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
          if !self.renderableItemIds.isEmpty, ids != self.renderableItemIds {
            self.sawItemIdsChange = true
          }
          self.renderableItemIds = ids
          self.renderableMap = renderableMap
        }
      }
    }
  }

  /// Verifies the renderable hierarchy (sublayers and subviews) matches the latest render pass's item order.
  ///
  /// The pinned contract is:
  /// - View items: the content view's subviews, restricted to view items, are in the items order.
  ///   This drives both the visual z-order and the hit-testing order of views.
  /// - Layer items: the content view's sublayers, restricted to layer items, are in the items order.
  ///
  /// The interleaving of view backing layers with layer item layers is not guaranteed on either platform:
  /// view items and layer items are z-ordered independently, each within its own kind.
  private func expectHierarchyMatchesItemOrder(_ view: ComposeView,
                                               _ recorder: RenderRecorder,
                                               file: StaticString = #filePath,
                                               line: UInt = #line)
  {
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

    // the content view's sublayers, filtered to layer items, must be in the items order restricted to layer items
    var expectedLayers: [CALayer] = []
    for id in ids {
      if let renderable = recorder.renderableMap[id], case .layer(let layer) = renderable {
        expectedLayers.append(layer)
      }
    }
    let expectedLayerIds = Set(expectedLayers.map { ObjectIdentifier($0) })
    let actualLayers = (contentView.layer().sublayers ?? []).filter { expectedLayerIds.contains(ObjectIdentifier($0)) }
    expect(actualLayers.map { ObjectIdentifier($0) }, "sublayers order should match items order", file: file, line: line) == expectedLayers.map { ObjectIdentifier($0) }
  }

  /// Makes a `ComposeView` hosted in a test window so that view items' backing layers are attached
  /// to the content view's layer, like in a real app.
  private func makeHostedView(@ComposeContentBuilder content: @escaping () -> ComposeContent) -> (ComposeView, TestWindow) {
    let window = TestWindow()
    let view = ComposeView(content: content)
    window.contentView().addSubview(view)
    return (view, window)
  }

  // MARK: - Initial Render

  func test_initialRender_mixedViewAndLayerItems() {
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

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)

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
    let (view, _) = makeScrollableView()
    let recorder = RenderRecorder()
    recorder.attach(to: view)

    view.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
    view.refresh(animated: false)
    expectHierarchyMatchesItemOrder(view, recorder)

    // scroll down with a step that is a non-multiple of row height for varied row churn
    var offset: CGFloat = 0
    for _ in 0 ..< 30 {
      offset += 35
      view.setContentOffset(CGPoint(x: 0, y: offset))
      view.layoutIfNeeded()
      expectHierarchyMatchesItemOrder(view, recorder)
    }

    expect(recorder.sawItemIdsChange) == true // ensure rows actually churned
  }

  func test_scrollUp_zOrderMaintained() {
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

    for _ in 0 ..< 30 {
      offset -= 35
      view.setContentOffset(CGPoint(x: 0, y: offset))
      view.layoutIfNeeded()
      expectHierarchyMatchesItemOrder(view, recorder)
    }

    expect(recorder.sawItemIdsChange) == true // ensure rows actually churned
  }

  // MARK: - Refresh

  func test_refresh_reorderedContent() {
    // use fixed ids so that reordering the content keeps the same item ids
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

    // reverse the order, same ids
    order = ["c", "b", "a"]
    view.refresh(animated: false)
    expect(recorder.renderableItemIds) == ["c", "b", "a"]
    expectHierarchyMatchesItemOrder(view, recorder)

    // move the back item to the front, same ids
    order = ["b", "a", "c"]
    view.refresh(animated: false)
    expect(recorder.renderableItemIds) == ["b", "a", "c"]
    expectHierarchyMatchesItemOrder(view, recorder)
  }

  func test_refresh_insertionsAndRemovals() {
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

    // insert in the middle
    order = ["a", "b", "c"]
    view.refresh(animated: false)
    expect(recorder.renderableItemIds) == ["a", "b", "c"]
    expectHierarchyMatchesItemOrder(view, recorder)

    // insert at the back (z-order bottom) and the front (z-order top)
    order = ["z", "a", "b", "c", "d"]
    view.refresh(animated: false)
    expect(recorder.renderableItemIds) == ["z", "a", "b", "c", "d"]
    expectHierarchyMatchesItemOrder(view, recorder)

    // remove from the middle
    order = ["z", "b", "d"]
    view.refresh(animated: false)
    expect(recorder.renderableItemIds) == ["z", "b", "d"]
    expectHierarchyMatchesItemOrder(view, recorder)

    // remove only, no inserts
    order = ["b"]
    view.refresh(animated: false)
    expect(recorder.renderableItemIds) == ["b"]
    expectHierarchyMatchesItemOrder(view, recorder)
  }

  func test_refresh_readdDuringRemoveTransition() {
    // removing a renderable with a transition keeps it in the hierarchy until the transition completes.
    // re-adding the item during the transition should recover the renderable and restore the correct z-order.
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

    // remove "b" with an in-flight remove transition (animated so that the remove transition runs)
    order = ["a", "c"]
    view.refresh(animated: true)
    expect(recorder.renderableItemIds) == ["a", "c"]
    expectHierarchyMatchesItemOrder(view, recorder)

    // re-add "b" while its remove transition is still running, the renderable should be recovered
    // and placed back between "a" and "c"
    order = ["a", "b", "c"]
    view.refresh(animated: true)
    expect(recorder.renderableItemIds) == ["a", "b", "c"]
    expectHierarchyMatchesItemOrder(view, recorder)
  }
}
