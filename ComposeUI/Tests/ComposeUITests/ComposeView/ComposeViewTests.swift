//
//  ComposeViewTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/13/24.
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

class ComposeViewTests: XCTestCase {

  private var contentView: ComposeView!

  override func setUp() {
    super.setUp()
    contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
  }

  func test_defaultContent() {
    // given: a compose view made without content
    let contentView = ComposeView()
    let nodes = contentView.content.asNodes()

    // then: the default content is a single empty node
    expect(nodes.count) == 1
    expect(nodes[0].id.id) == "E"
    expect(nodes[0].size) == .zero
  }

  func test_centerContent() {
    do {
      // given: content size is smaller than the bounds size
      let view = BaseView()
      contentView.setContent {
        ViewNode(view)
          .flexibleSize()
          .frame(width: 50, height: 80)
      }

      // when: the view is refreshed
      contentView.refresh(animated: false)

      // then: the content is centered in both directions
      expect(contentView.contentSize) == CGSize(width: 100, height: 100)
      expect(view.frame) == CGRect(x: 25, y: 10, width: 50, height: 80)
    }

    do {
      // given: content width is smaller than the bounds width
      let view = BaseView()
      contentView.setContent {
        ViewNode(view)
          .flexibleSize()
          .frame(width: 50, height: 120)
      }

      // when: the view is refreshed
      contentView.refresh(animated: false)

      // then: the content is centered horizontally
      expect(contentView.contentSize) == CGSize(width: 100, height: 120)
      expect(view.frame) == CGRect(x: 25, y: 0, width: 50, height: 120)
    }

    do {
      // given: content height is smaller than the bounds height
      let view = BaseView()
      contentView.setContent {
        ViewNode(view)
          .flexibleSize()
          .frame(width: 120, height: 80)
      }

      // when: the view is refreshed
      contentView.refresh(animated: false)

      // then: the content is centered vertically
      expect(contentView.contentSize) == CGSize(width: 120, height: 100)
      expect(view.frame) == CGRect(x: 0, y: 10, width: 120, height: 80)
    }
  }

  func test_visibleBoundsInsets() {
    // given: a compose view with extended visible bounds and render tracking for offscreen top and bottom views
    var isTopRendered = false
    var isBottomRendered = false

    contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.visibleBoundsInsets = EdgeInsets(top: -1, left: 0, bottom: -1, right: 0)

    contentView.setContent {
      ZStack {
        // top view
        ViewNode()
          .frame(width: 100, height: 100)
          .offset(x: 0, y: -100) // move the view above the normal bounds
          .onInsert { _, _ in
            isTopRendered = true
          }
          .onRemove { _, _ in
            isTopRendered = false
          }

        // bottom view
        ViewNode()
          .frame(width: 100, height: 100)
          .offset(x: 0, y: 100) // move the view below the normal bounds
          .onInsert { _, _ in
            isBottomRendered = true
          }
          .onRemove { _, _ in
            isBottomRendered = false
          }
      }
    }

    // when: the view is refreshed
    contentView.refresh(animated: false)

    // then: both offscreen views are rendered thanks to the extended visible bounds
    expect(contentView.contentSize) == CGSize(width: 100, height: 100)
    expect(isTopRendered) == true
    expect(isBottomRendered) == true
  }

  // MARK: - sizeThatFits

  func test_sizeThatFits() {
    // given: a compose view with a flexible-width, fixed-height node
    let contentView = ComposeView {
      LayerNode()
        .frame(width: .flexible, height: 30)
    }

    // then: the fitting size adopts the proposed width and keeps the fixed height
    expect(contentView.sizeThatFits(CGSize(width: 10, height: 10))) == CGSize(width: 10, height: 30)
    expect(contentView.sizeThatFits(CGSize(width: 50, height: 50))) == CGSize(width: 50, height: 30)
  }

  func test_sizeThatFits_doesNotReplaceRetainedContent() throws {
    // given: rendered content whose next configuration has a different color and height
    var color = Color.red
    var height: CGFloat = 300
    var layer: CALayer?
    var contentMakeCount = 0
    let view = ComposeView {
      contentMakeCount += 1
      LayoutCacheNode(node: ColorNode(color)
        .frame(width: .flexible, height: height)
        .onUpdate { renderable, _ in layer = renderable.layer })
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let originalLayer = try unwrap(layer)
    color = .blue
    height = 400

    // when: fresh content is measured with a different proposal
    let measuredSize = view.sizeThatFits(CGSize(width: 200, height: 80))

    // then: measurement observes fresh configuration without installing it
    expect(measuredSize) == CGSize(width: 200, height: 400)
    expect(contentMakeCount) == 2
    expect(view.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(layer?.frame) == CGRect(x: 0, y: 0, width: 100, height: 300)
    expect(layer?.backgroundColor) == Color.red.cgColor

    // when: the displayed content scrolls and resizes after measurement
    view.setContentOffset(CGPoint(x: 0, y: 20))
    view.layoutIfNeeded()
    view.frame.size.width = 150
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the retained tree still uses its original configuration and fresh geometry
    expect(contentMakeCount) == 2
    expect(layer) === originalLayer
    expect(layer?.frame) == CGRect(x: 0, y: 0, width: 150, height: 300)
    expect(layer?.backgroundColor) == Color.red.cgColor

    // when: fresh content is measured while an explicit refresh is pending
    view.setNeedsRefresh(animated: false)
    expect(view.sizeThatFits(CGSize(width: 250, height: 50))) == CGSize(width: 250, height: 400)

    // then: measurement does not perform the pending refresh
    expect(contentMakeCount) == 3
    expect(layer?.backgroundColor) == Color.red.cgColor
    expect(layer?.frame) == CGRect(x: 0, y: 0, width: 150, height: 300)

    // when: layout fulfills the pending refresh
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the fresh configuration is now committed to the same renderable
    expect(contentMakeCount) == 4
    expect(layer) === originalLayer
    expect(layer?.backgroundColor) == Color.blue.cgColor
    expect(layer?.frame) == CGRect(x: 0, y: 0, width: 150, height: 400)
  }

  func test_sizeThatFits_measuresNewBuilderBeforeScheduledRefresh() throws {
    // given: an existing red renderable and a replacement builder waiting to be displayed
    var layer: CALayer?
    let view = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: 30)
        .onUpdate { renderable, _ in
          layer = renderable.layer
        }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let originalLayer = try unwrap(layer)
    view.setContent {
      ColorNode(.blue)
        .frame(width: .flexible, height: 80)
        .onUpdate { renderable, _ in
          layer = renderable.layer
        }
    }

    // when: measuring the replacement before its scheduled refresh
    let measuredSize = view.sizeThatFits(CGSize(width: 200, height: 200))

    // then: measurement uses the new builder without replacing the displayed content
    expect(measuredSize) == CGSize(width: 200, height: 80)
    expect(layer) === originalLayer
    expect(layer?.backgroundColor) == Color.red.cgColor
    expect(layer?.bounds.size) == CGSize(width: 100, height: 30)
    expect(view.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: layout performs the pending refresh
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the same renderable receives the replacement configuration and geometry
    expect(layer) === originalLayer
    expect(layer?.backgroundColor) == Color.blue.cgColor
    expect(layer?.bounds.size) == CGSize(width: 100, height: 80)
  }

  func test_sizeThatFits_usesProposedSizeForIntrinsicLayout() throws {
    // given: a view whose intrinsic height follows its proposed width
    var renderedView: BaseView?
    let view = ComposeView {
      ViewNode<BaseView>(intrinsicSize: { CGSize(width: $0.width, height: $0.width / 2) })
        .fixedSize(width: false, height: true)
        .onUpdate { renderable, _ in renderedView = renderable.view as? BaseView }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let originalView = try unwrap(renderedView)

    // when: measuring proposals different from the host bounds
    let wideSize = view.sizeThatFits(CGSize(width: 200, height: 300))
    let narrowSize = view.sizeThatFits(CGSize(width: 40, height: 300))

    // then: intrinsic layout uses each proposal without changing the mounted view
    expect(wideSize) == CGSize(width: 200, height: 100)
    expect(narrowSize) == CGSize(width: 40, height: 20)
    expect(originalView.bounds.size) == CGSize(width: 100, height: 50)

    // when: the mounted content resizes
    view.frame.size.width = 160
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the retained view adapts to its own new proposal
    expect(renderedView) === originalView
    expect(originalView.bounds.size) == CGSize(width: 160, height: 80)
  }

  func test_sizeThatFits_preservesFreshCacheInNestedContent() throws {
    // given: a nested compose view whose cached content is created separately for each builder evaluation
    var nestedView: ComposeView?
    var layer: CALayer?
    let view = ComposeView {
      ComposeViewNode {
        LayoutCacheNode(node: ColorNode(.red)
          .frame(width: .flexible, height: 300)
          .onUpdate { renderable, _ in layer = renderable.layer })
      }
      .fixedSize(width: false, height: true)
      .onUpdate { renderable, _ in nestedView = renderable.view as? ComposeView }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let nested = try unwrap(nestedView)
    nested.setNeedsLayout()
    nested.layoutIfNeeded()
    let originalLayer = try unwrap(layer)

    // when: fresh content is measured and the mounted content is resized
    expect(view.sizeThatFits(CGSize(width: 250, height: 150))) == CGSize(width: 250, height: 300)
    view.frame.size.width = 180
    view.setNeedsLayout()
    view.layoutIfNeeded()
    nested.setNeedsLayout()
    nested.layoutIfNeeded()

    // then: the original nested cache renders the mounted proposal rather than the measurement proposal
    expect(nestedView) === nested
    expect(layer) === originalLayer
    expect(nested.bounds().size) == CGSize(width: 180, height: 300)
    expect(layer?.frame) == CGRect(x: 0, y: 0, width: 180, height: 300)
    expect(layer?.backgroundColor) == Color.red.cgColor

    // when: the outer view scrolls without another layout proposal
    view.setContentOffset(CGPoint(x: 0, y: 20))
    view.layoutIfNeeded()

    // then: the nested geometry remains consistent
    expect(layer?.frame) == CGRect(x: 0, y: 0, width: 180, height: 300)
    expect(nested.frame) == CGRect(x: 0, y: 0, width: 180, height: 300)
  }

  // MARK: -

  func test_contentInsetAdjustmentBehavior() {
    // then: automatic content inset adjustment is disabled
    #if canImport(AppKit)
    expect(contentView.automaticallyAdjustsContentInsets) == false
    #endif
    #if canImport(UIKit)
    expect(contentView.contentInsetAdjustmentBehavior) == .never
    #endif
  }
}
