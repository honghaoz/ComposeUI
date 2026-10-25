//
//  ComposeView+CachedLayoutTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
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

import ComposeUI

class ComposeView_CachedLayoutTests: XCTestCase {

  override func setUp() {
    super.setUp()

    // the tests count the layouts that a cached layout saves, so the debug check of kept layouts, which lays out again,
    // is off
    KeptLayoutChecks.isOn = false
  }

  override func tearDown() {
    KeptLayoutChecks.isOn = true

    super.tearDown()
  }

  func test_noLayoutOnScroll() {
    // given: a compose view with a content make counter and a node tracking layout and render counts
    var contentMakeCount = 0
    let state = TestNode.State()

    let view = ComposeView {
      contentMakeCount += 1
      TestNode(state: state)
        .frame(width: 100, height: 300)
    }

    // when: the view lays out initially
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the initial content make, layout and render are performed
    expect(contentMakeCount) == 1 // initial content make
    expect(state.layoutCount) == 1 // initial layout
    expect(state.renderCount) == 1 // initial render

    // when: the view scrolls
    view.contentOffset = CGPoint(x: 0, y: 100)
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: scroll triggers a render but no content make or layout
    expect(contentMakeCount) == 1 // scroll should not trigger content make
    expect(state.layoutCount) == 1 // scroll should not trigger layout
    expect(state.renderCount) == 2 // scroll should trigger render

    // when: the view scrolls again
    view.contentOffset = CGPoint(x: 0, y: 200)
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: scroll triggers a render but no content make or layout
    expect(contentMakeCount) == 1 // scroll should not trigger content make
    expect(state.layoutCount) == 1 // scroll should not trigger layout
    expect(state.renderCount) == 3 // scroll should trigger render

    // when: the view size changes
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: size change renders the reused content, which keeps its layout, since a fixed frame doesn't depend on the
    // view's size
    expect(contentMakeCount) == 1
    expect(state.layoutCount) == 1 // a size change the content doesn't depend on should not trigger layout
    expect(state.renderCount) == 4 // size change should trigger render

    // when: the view size changes to zero
    view.frame = .zero
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: zero size renders without rebuilding content or laying it out again
    expect(contentMakeCount) == 1
    expect(state.layoutCount) == 1 // a size change the content doesn't depend on should not trigger layout
    expect(state.renderCount) == 5 // size change should trigger render

    // when: the view scrolls after the size change
    view.contentOffset = CGPoint(x: 0, y: 110)
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: scroll triggers a render but no content make or layout
    expect(contentMakeCount) == 1 // scroll should not trigger content make
    expect(state.layoutCount) == 1 // scroll should not trigger layout
    expect(state.renderCount) == 6 // scroll should trigger render
  }

  func test_resize_laysOutAgainOnlyForALengthTheContentDependsOn() {
    // given: a compose view of content as wide as the view and of a fixed height, laid out
    let state = TestNode.State()
    let view = ComposeView {
      TestNode(state: state)
        .frame(width: .flexible, height: 300)
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    #if canImport(AppKit)
    // overlay scroll bars take no space, so the layout doesn't depend on the system's scroll bar setting
    view.scrollerStyle = .overlay
    #endif
    view.layoutIfNeeded()
    expect(state.layoutCount) == 1

    // when: the view's height changes
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
    view.layoutIfNeeded()

    // then: the content keeps its layout, which doesn't depend on the height
    expect(state.layoutCount) == 1

    // when: the view's width changes
    view.frame = CGRect(x: 0, y: 0, width: 150, height: 200)
    view.layoutIfNeeded()

    // then: the content lays out again at the new width
    expect(state.layoutCount) == 2
    expect(view.contentSize) == CGSize(width: 150, height: 300)
  }

  func test_resize_customNodeThatDependsOnTheWidthAlone_keepsItsLayoutOnAHeightChange() {
    // given: a compose view of an app's node as wide as the view and twice as tall, which reports that its layout reads
    // the width alone, laid out
    let state = AspectRatioNode.State()
    let view = ComposeView {
      AspectRatioNode(state: state)
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    #if canImport(AppKit)
    // overlay scroll bars take no space, so the layout doesn't depend on the system's scroll bar setting
    view.scrollerStyle = .overlay
    #endif
    view.layoutIfNeeded()
    expect(state.layoutCount) == 1

    // when: the view's height changes
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
    view.layoutIfNeeded()

    // then: the node keeps its layout
    expect(state.layoutCount) == 1

    // when: the view's width changes
    view.frame = CGRect(x: 0, y: 0, width: 150, height: 200)
    view.layoutIfNeeded()

    // then: the node lays out again at the new width
    expect(state.layoutCount) == 2
    expect(view.contentSize) == CGSize(width: 150, height: 300)
  }

  func test_resize_customContainerThatReportsItsChildsDependence_keepsItsLayoutOnAHeightChange() {
    // given: a compose view of an app's container node, which reports that its layout reads what its child's layout
    // reads, around content as wide as the view and of a fixed height, laid out
    let state = TestNode.State()
    let view = ComposeView {
      InsetNode(inset: 10, child: TestNode(state: state).frame(width: .flexible, height: 300))
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    #if canImport(AppKit)
    // overlay scroll bars take no space, so the layout doesn't depend on the system's scroll bar setting
    view.scrollerStyle = .overlay
    #endif
    view.layoutIfNeeded()
    expect(state.layoutCount) == 1

    // when: the view's height changes
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
    view.layoutIfNeeded()

    // then: the container keeps its layout, which doesn't depend on the height
    expect(state.layoutCount) == 1

    // when: the view's width changes
    view.frame = CGRect(x: 0, y: 0, width: 150, height: 200)
    view.layoutIfNeeded()

    // then: the container lays out its child again at the new width
    expect(state.layoutCount) == 2
    expect(view.contentSize) == CGSize(width: 150, height: 320)
  }

  func test_resize_relayoutsReusedContentAcrossZeroSize() throws {
    // given: content with padding, an overlay, and a size-dependent shadow
    var color = Color.red
    var contentMakeCount = 0
    var layer: CALayer?
    var overlayLayer: CALayer?
    let view = ComposeView {
      contentMakeCount += 1
      ColorNode(color)
        .shadow(color: .black, opacity: 1, radius: 2, offset: .zero, path: { CGPath(rect: $0.layer.bounds, transform: nil) })
        .onUpdate { renderable, _ in
          layer = renderable.layer
        }
        .overlay {
          ColorNode(.blue)
            .frame(width: 10, height: 10)
            .onUpdate { renderable, _ in
              overlayLayer = renderable.layer
            }
        }
        .padding(10)
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 80)
    view.refresh(animated: false)
    let originalLayer = try unwrap(layer)
    color = .green

    // when: the reused tree receives larger, smaller, and zero-size proposals
    for size in [CGSize(width: 200, height: 120), CGSize(width: 60, height: 40), .zero, CGSize(width: 100, height: 80)] {
      view.frame.size = size
      view.setNeedsLayout()
      view.layoutIfNeeded()

      // then: root content remains unchanged while every frame is recomputed
      expect(contentMakeCount) == 1
      if size == .zero {
        expect(layer?.superlayer) == nil
      } else {
        let renderedLayer = try unwrap(layer)
        let expectedFrame = CGRect(x: 10, y: 10, width: size.width - 20, height: size.height - 20)
        expect(renderedLayer.frame) == expectedFrame
        expect(renderedLayer.backgroundColor) == Color.red.cgColor
        expect(renderedLayer.shadowPath?.boundingBoxOfPath) == CGRect(origin: .zero, size: expectedFrame.size)
        expect(overlayLayer?.frame) == CGRect(x: size.width / 2 - 5, y: size.height / 2 - 5, width: 10, height: 10)
        if size.width == 200 || size.width == 60 {
          expect(renderedLayer) === originalLayer
        }
      }
    }

    // when: layout is requested with the same bounds
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the content is still reused without running the builder
    expect(contentMakeCount) == 1
    expect(layer?.backgroundColor) == Color.red.cgColor

    // when: an explicit refresh reevaluates the configuration
    view.refresh(animated: false)

    // then: the new color is applied
    expect(contentMakeCount) == 2
    expect(layer?.backgroundColor) == Color.green.cgColor
  }

  func test_resize_performsPendingRefresh() throws {
    // given: changed content with a pending refresh
    var color = Color.red
    var layer: CALayer?
    var contentMakeCount = 0
    var updateType: RenderableUpdateType?
    let view = ComposeView {
      contentMakeCount += 1
      ColorNode(color)
        .onUpdate { renderable, context in
          layer = renderable.layer
          updateType = context.updateType
        }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let originalLayer = try unwrap(layer)
    color = .blue
    view.setNeedsRefresh(animated: false)

    // when: the view resizes before the pending refresh runs
    view.frame.size = CGSize(width: 200, height: 150)
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: refresh takes precedence and applies both new configuration and frame
    expect(layer) === originalLayer
    expect(layer?.backgroundColor) == Color.blue.cgColor
    expect(layer?.frame) == CGRect(x: 0, y: 0, width: 200, height: 150)
    expect(contentMakeCount) == 2
    expect(updateType) == .refresh

    // when: layout is requested again without further changes
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: no additional content evaluation occurs
    expect(contentMakeCount) == 2
  }
}

/// An app's node as wide as its container and twice as tall, as an image of a fixed aspect ratio is, which reports that
/// its layout reads the container's width alone.
private struct AspectRatioNode: ComposeNode {

  final class State {
    var layoutCount = 0
  }

  private let state: State

  init(state: State) {
    self.state = state
  }

  var id: ComposeNodeId = .custom("AspectRatioNode")

  private(set) var size: CGSize = .zero

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    state.layoutCount += 1
    size = CGSize(width: containerSize.width, height: containerSize.width * 2)
    return ComposeNodeSizing(width: .flexible, height: .fixed(size.height), dependence: .width)
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {}
}

/// An app's container node that insets its child on each side, which reports that its layout reads what its child's
/// layout reads.
private struct InsetNode<Child: ComposeNode>: ComposeNode {

  private let inset: CGFloat

  private var child: Child

  init(inset: CGFloat, child: Child) {
    self.inset = inset
    self.child = child
  }

  var id: ComposeNodeId = .custom("InsetNode")

  private(set) var size: CGSize = .zero

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    let childContainerSize = CGSize(width: containerSize.width - inset * 2, height: containerSize.height - inset * 2)
    let childSizing = child.layout(containerSize: childContainerSize, context: context)
    size = CGSize(width: child.size.width + inset * 2, height: child.size.height + inset * 2)
    return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height), dependence: childSizing.dependence)
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {}
}
