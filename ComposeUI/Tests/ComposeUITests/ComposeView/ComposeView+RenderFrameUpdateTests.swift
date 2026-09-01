//
//  ComposeView+RenderFrameUpdateTests.swift
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

import QuartzCore

import ChouTiTest

@testable import ComposeUI

/// Tests for the steady-state per-item frame/transform update behavior in the render pass.
///
/// These tests pin down two properties of the reuse path:
/// - Correctness: a reused renderable always ends a render pass with the correct frame and an identity transform.
/// - Efficiency: a reused renderable whose frame is unchanged (the common case while scrolling) is not re-framed.
class ComposeView_RenderFrameUpdateTests: XCTestCase {

  // MARK: - setFrame skipping

  func test_reusedRenderable_keepsCorrectFrame_afterScroll() {
    // given: a content view with a frame-tracking row, rendered
    var trackingView: FrameTrackingView?
    let view = makeContentView(captureView: { trackingView = $0 })
    view.refresh(animated: false)

    guard let tracked = trackingView else {
      fail("tracking view should be created")
      return
    }
    expect(tracked.frame) == CGRect(x: 0, y: 0, width: 100, height: 50)

    // when: scroll a little, the tracking row stays visible and its content-space frame is unchanged
    view.setContentOffset(CGPoint(x: 0, y: 10))
    view.layoutIfNeeded()

    // then: the reused renderable still has the correct frame
    expect(tracked.frame) == CGRect(x: 0, y: 0, width: 100, height: 50)
  }

  func test_reusedRenderable_skipsRedundantFrameUpdate_afterScroll() {
    // given: a content view with a frame-tracking row, rendered, with the counter reset after the initial insert
    var trackingView: FrameTrackingView?
    let view = makeContentView(captureView: { trackingView = $0 })
    view.refresh(animated: false)

    guard let tracked = trackingView else {
      fail("tracking view should be created")
      return
    }

    // reset the counter after the initial insert so we only measure the scroll render pass.
    tracked.resetFrameSetCount()

    // when: scroll a little, the tracking row stays visible and its content-space frame is unchanged
    view.setContentOffset(CGPoint(x: 0, y: 10))
    view.layoutIfNeeded()

    // then: the frame did not change, so the render pass should not have re-applied it
    expect(tracked.frameSetCount) == 0
  }

  func test_reusedRenderable_updatesFrame_afterResize() {
    // given: a content view with a frame-tracking row, rendered, with the counter reset after the initial insert
    var trackingView: FrameTrackingView?
    let view = makeContentView(captureView: { trackingView = $0 })
    view.refresh(animated: false)

    guard let tracked = trackingView else {
      fail("tracking view should be created")
      return
    }
    expect(tracked.frame) == CGRect(x: 0, y: 0, width: 100, height: 50)

    // reset the counter after the initial insert so we only measure the resize render pass.
    tracked.resetFrameSetCount()

    // when: resize the view width, the flexible-width row's frame changes
    view.frame.size = CGSize(width: 200, height: 100)
    view.layoutIfNeeded()

    // then: the row is re-framed to the new width
    expect(tracked.frame) == CGRect(x: 0, y: 0, width: 200, height: 50)
    expect(tracked.frameSetCount > 0) == true
  }

  // MARK: - transform reset

  func test_reusedRenderable_resetsNonIdentityTransform_onReuse() {
    // given: a content view with a captured layer row, rendered, with a leftover transform on the layer
    var capturedLayer: CALayer?
    let view = makeLayerContentView(captureLayer: { capturedLayer = $0 })
    view.refresh(animated: false)

    guard let layer = capturedLayer else {
      fail("layer should be created")
      return
    }

    // simulate a leftover transform (e.g. from an interrupted transition).
    layer.transform = CATransform3DMakeScale(2, 2, 1)
    expect(CATransform3DIsIdentity(layer.transform)) == false

    // when: the layer is reused via scroll
    view.setContentOffset(CGPoint(x: 0, y: 10))
    view.layoutIfNeeded()

    // then: the render pass resets the transform to identity before applying the frame
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  func test_reusedRenderable_keepsIdentityTransform_afterScroll() {
    // given: a content view with a captured layer row, rendered, with an identity transform on the layer
    var capturedLayer: CALayer?
    let view = makeLayerContentView(captureLayer: { capturedLayer = $0 })
    view.refresh(animated: false)

    guard let layer = capturedLayer else {
      fail("layer should be created")
      return
    }
    expect(CATransform3DIsIdentity(layer.transform)) == true

    // when: the layer is reused via scroll
    view.setContentOffset(CGPoint(x: 0, y: 10))
    view.layoutIfNeeded()

    // then: an already-identity transform stays identity
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  // MARK: - Helpers

  /// A content view with a flexible-width tracking-view row at the top of a scrollable stack.
  private func makeContentView(captureView: @escaping (FrameTrackingView) -> Void) -> ComposeView {
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      VStack {
        ViewNode<FrameTrackingView>(make: { context in
          let view = FrameTrackingView(frame: context.initialFrame ?? .zero)
          #if canImport(AppKit)
          view.wantsLayer = true // ComposéUI manipulates the renderable's backing layer
          #endif
          captureView(view)
          return view
        })
        .frame(width: .flexible, height: 50)

        ColorNode(.blue)
          .frame(width: .flexible, height: 450)
      }
    }
    return view
  }

  /// A content view with a flexible-width layer row at the top of a scrollable stack.
  private func makeLayerContentView(captureLayer: @escaping (CALayer) -> Void) -> ComposeView {
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      VStack {
        LayerNode<CALayer>(make: { context in
          let layer = CALayer()
          if let initialFrame = context.initialFrame {
            layer.frame = initialFrame
          }
          captureLayer(layer)
          return layer
        })
        .frame(width: .flexible, height: 50)

        ColorNode(.blue)
          .frame(width: .flexible, height: 450)
      }
    }
    return view
  }
}

// MARK: - FrameTrackingView

/// A view that counts how many times its `frame` is set, used to verify redundant frame updates are skipped.
private final class FrameTrackingView: View {

  private(set) var frameSetCount = 0

  /// Resets the counter. Settable to allow tests to ignore the initial insert frame set.
  func resetFrameSetCount() {
    frameSetCount = 0
  }

  override var frame: CGRect {
    get {
      super.frame
    }
    set {
      frameSetCount += 1
      super.frame = newValue
    }
  }
}
