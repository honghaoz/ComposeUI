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
    view.setContentOffset(CGPoint(x: 0, y: 100))
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: scroll triggers a render but no content make or layout
    expect(contentMakeCount) == 1 // scroll should not trigger content make
    expect(state.layoutCount) == 1 // scroll should not trigger layout
    expect(state.renderCount) == 2 // scroll should trigger render

    // when: the view scrolls again
    view.setContentOffset(CGPoint(x: 0, y: 200))
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

    // then: size change relayouts and renders the retained content
    expect(contentMakeCount) == 1
    expect(state.layoutCount) == 2 // size change should trigger layout
    expect(state.renderCount) == 4 // size change should trigger render

    // when: the view size changes to zero
    view.frame = .zero
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: zero size relayouts and renders without rebuilding content
    expect(contentMakeCount) == 1
    expect(state.layoutCount) == 3 // size change should trigger layout
    expect(state.renderCount) == 5 // size change should trigger render

    // when: the view scrolls after the size change
    view.setContentOffset(CGPoint(x: 0, y: 110))
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: scroll triggers a render but no content make or layout
    expect(contentMakeCount) == 1 // scroll should not trigger content make
    expect(state.layoutCount) == 3 // scroll should not trigger layout
    expect(state.renderCount) == 6 // scroll should trigger render
  }

  func test_resize_relayoutsRetainedContentAcrossZeroSize() throws {
    // given: content with padding, an overlay, and a geometry-dependent shadow
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

    // when: the retained tree receives larger, smaller, and zero-size proposals
    for size in [CGSize(width: 200, height: 120), CGSize(width: 60, height: 40), .zero, CGSize(width: 100, height: 80)] {
      view.frame.size = size
      view.setNeedsLayout()
      view.layoutIfNeeded()

      // then: root content remains unchanged while all layout geometry is recomputed
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

    // then: the builder is still retained
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

    // then: refresh takes precedence and applies both new configuration and geometry
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
