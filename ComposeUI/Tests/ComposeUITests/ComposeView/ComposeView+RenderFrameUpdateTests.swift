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
/// - Efficiency: a reused renderable whose frame is unchanged (the common case while scrolling) is neither re-framed
///   nor frame-animated, including at third-pixel frames on 3x displays where the derived frame is imprecise.
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

  func test_reusedRenderable_skipsRedundantFrameUpdate_afterScroll_thirdPixelFrame() {
    // given: a 3x content view with a frame-tracking layer row at a third-pixel offset, rendered, with the counter
    // reset after the initial insert
    let third: CGFloat = 1 / 3
    var trackingLayer: FrameTrackingLayer?
    let view = makeLayerContentView(spacerHeight: { 10 + third }, captureLayer: { trackingLayer = $0 })
    view.contentScaleFactor = 3
    view.refresh(animated: false)

    guard let tracked = trackingLayer else {
      fail("tracking layer should be created")
      return
    }

    // the applied frame is rounded to the 3x pixel grid, and the layer's derived frame doesn't round-trip it exactly
    let appliedFrame = CGRect(x: 0, y: 10 + third, width: 100, height: 50).rounded(scaleFactor: 3)
    expect(tracked.frame) != appliedFrame
    expect(tracked.hasFrame(appliedFrame)) == true
    tracked.resetFrameSetCount()

    // when: scroll a little, the tracking row stays visible and its content-space frame is unchanged
    view.setContentOffset(CGPoint(x: 0, y: 10))
    view.layoutIfNeeded()

    // then: the frame is recognized as unchanged despite the imprecise derived frame, so it is not re-applied
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
    expect(tracked.frameSetCount) > 0
  }

  // MARK: - frame animation skipping

  func test_reusedRenderable_skipsFrameAnimation_whenFrameUnchanged_onAnimatedRefresh() {
    // given: a content view with an animated frame-tracking row, rendered, with the counter reset after the initial insert
    var trackingView: FrameTrackingView?
    let view = makeContentView(spacerHeight: { 10 }, animationTiming: Constants.animationTiming, captureView: { trackingView = $0 })
    view.refresh(animated: false)

    guard let tracked = trackingView else {
      fail("tracking view should be created")
      return
    }
    expect(tracked.frame) == CGRect(x: 0, y: 10, width: 100, height: 50)
    tracked.resetFrameSetCount()

    // when: an animated refresh keeps the row's frame
    view.refresh(animated: true)

    // then: the frame did not change, so the render pass adds no frame animations and does not re-apply the frame
    expect(tracked.frame) == CGRect(x: 0, y: 10, width: 100, height: 50)
    expect(tracked.layer().animationKeys()) == nil
    expect(tracked.frameSetCount) == 0
  }

  func test_reusedRenderable_animatesFrame_whenFrameMoved_onAnimatedRefresh() {
    // given: a content view with an animated frame-tracking row below a spacer, rendered
    var spacerHeight: CGFloat = 10
    var trackingView: FrameTrackingView?
    let view = makeContentView(spacerHeight: { spacerHeight }, animationTiming: Constants.animationTiming, captureView: { trackingView = $0 })
    view.refresh(animated: false)

    guard let tracked = trackingView else {
      fail("tracking view should be created")
      return
    }
    expect(tracked.frame) == CGRect(x: 0, y: 10, width: 100, height: 50)

    // when: an animated refresh moves the row down by growing the spacer
    spacerHeight = 30
    view.refresh(animated: true)

    // then: the frame changed, so it animates, and the row ends at the new frame
    expect(tracked.frame) == CGRect(x: 0, y: 30, width: 100, height: 50)
    expect(tracked.layer().animationKeys()) == ["position", "bounds.size"]

    // when: another animated refresh keeps the moved frame while the frame animations are in flight
    view.refresh(animated: true)

    // then: no animation piles up on the in-flight ones
    expect(tracked.frame) == CGRect(x: 0, y: 30, width: 100, height: 50)
    expect(tracked.layer().animationKeys()) == ["position", "bounds.size"]
  }

  func test_reusedRenderable_animatesFrame_whenFrameMovedAndResized_onAnimatedRefresh() {
    // given: a content view with an animated frame-tracking row below a spacer, rendered
    var spacerHeight: CGFloat = 10
    var rowHeight: CGFloat = 50
    var trackingView: FrameTrackingView?
    let view = makeContentView(
      spacerHeight: { spacerHeight },
      rowHeight: { rowHeight },
      animationTiming: Constants.animationTiming,
      captureView: { trackingView = $0 }
    )
    view.refresh(animated: false)

    guard let tracked = trackingView else {
      fail("tracking view should be created")
      return
    }
    expect(tracked.frame) == CGRect(x: 0, y: 10, width: 100, height: 50)

    // when: an animated refresh moves the row down and grows it
    spacerHeight = 30
    rowHeight = 80
    view.refresh(animated: true)

    // then: both the position and the size animate, and the row ends at the new frame
    expect(tracked.frame) == CGRect(x: 0, y: 30, width: 100, height: 80)
    expect(tracked.layer().animationKeys()) == ["position", "bounds.size"]
  }

  func test_reusedRenderable_nonAnimatedResize_keepsInFlightMove() throws {
    // given: a hosted content view with a frame-tracking row below a spacer, animating linearly over 1.5 seconds
    let window = TestWindow()
    var spacerHeight: CGFloat = 10
    var rowHeight: CGFloat = 50
    var trackingView: FrameTrackingView?
    let view = makeContentView(
      spacerHeight: { spacerHeight },
      rowHeight: { rowHeight },
      animationTiming: .linear(duration: 1.5),
      captureView: { trackingView = $0 }
    )
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    let layer = try unwrap(trackingView).layer()
    CATransaction.flush()
    expect(layer.presentation()).toEventuallyNot(beNil())

    // when: an animated refresh moves the row down, and the move is part way
    spacerHeight = 60
    view.refresh(animated: true)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

    // then: the shown row is between the two positions
    let shownDuringMove = try unwrap(layer.presentation()).frame
    expect(shownDuringMove.minY) > 12
    expect(shownDuringMove.minY) < 58

    // when: a non-animated refresh grows the row while the move is in flight
    rowHeight = 80
    view.refresh(animated: false)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

    // then: the new height applies at once and the move keeps going, with no animation added for the resize
    let shownAfterResize = try unwrap(layer.presentation()).frame
    expect(shownAfterResize.height).to(beApproximatelyEqual(to: 80, within: 0.5))
    expect(shownAfterResize.minY) > shownDuringMove.minY
    expect(shownAfterResize.minY) < 58
    expect(layer.animationKeys()) == ["position", "bounds.size"]

    // then: the row lands at the new position with the new height when the move would have ended
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
    let shownAtEnd = try unwrap(layer.presentation()).frame
    expect(shownAtEnd.minY).to(beApproximatelyEqual(to: 60, within: 0.5))
    expect(shownAtEnd.height).to(beApproximatelyEqual(to: 80, within: 0.5))
    expect(try unwrap(trackingView).frame) == CGRect(x: 0, y: 60, width: 100, height: 80)
  }

  func test_reusedRenderable_skipsFrameAnimation_whenFrameUnchanged_onAnimatedScroll() {
    // given: a content view animating every render pass, with an animated frame-tracking row, rendered
    var trackingView: FrameTrackingView?
    let view = makeContentView(
      spacerHeight: { 10 },
      animationTiming: Constants.animationTiming,
      captureView: { trackingView = $0 }
    )
    view.animationBehavior = .dynamic { _, _ in true }
    view.refresh(animated: false)

    guard let tracked = trackingView else {
      fail("tracking view should be created")
      return
    }
    expect(tracked.frame) == CGRect(x: 0, y: 10, width: 100, height: 50)

    // when: scrolling a little, the row stays visible and keeps its content-space frame
    view.setContentOffset(CGPoint(x: 0, y: 10))
    view.layoutIfNeeded()

    // then: the animated scroll pass adds no frame animations to the reused row
    expect(tracked.frame) == CGRect(x: 0, y: 10, width: 100, height: 50)
    expect(tracked.layer().animationKeys()) == nil
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

  // MARK: - transform ownership

  func test_reusedLayer_assertsWhenWillUpdateSetsTransform() {
    // given: a rendered layer row whose `willUpdate` starts setting a transform, and a test assertion failure handler
    var appliesTransform = false
    var trackingLayer: FrameTrackingLayer?
    let view = makeLayerContentView(
      willUpdate: { renderable, _ in
        if appliesTransform {
          renderable.layer.transform = Constants.translation
        }
      },
      captureLayer: { trackingLayer = $0 }
    )
    view.refresh(animated: false)

    guard let tracked = trackingLayer else {
      fail("tracking layer should be created")
      return
    }
    tracked.resetFrameSetCount()

    var assertionCount = 0
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == Constants.identityTransformAssertionMessage
      assertionCount += 1
    }
    defer { Assert.resetTestAssertionFailureHandler() }

    // when: a non-animated refresh reuses the row at the same frame, with `willUpdate` setting the transform
    appliesTransform = true
    view.refresh(animated: false)

    // then: the render pass asserts once, and leaves the row alone since its frame is unchanged
    expect(assertionCount) == 1
    expect(tracked.frameSetCount) == 0
    expect(tracked.animationKeys()) == nil
    expect(CATransform3DEqualToTransform(tracked.transform, Constants.translation)) == true
  }

  func test_reusedView_assertsWhenWillUpdateSetsTransform() {
    // given: a rendered view row whose `willUpdate` starts setting a transform, and a test assertion failure handler
    var appliesTransform = false
    var trackingView: FrameTrackingView?
    let view = makeContentView(
      willUpdate: { renderable, _ in
        if appliesTransform {
          renderable.layer.transform = Constants.translation
        }
      },
      captureView: { trackingView = $0 }
    )
    view.refresh(animated: false)

    guard let tracked = trackingView else {
      fail("tracking view should be created")
      return
    }
    tracked.resetFrameSetCount()

    var assertionCount = 0
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == Constants.identityTransformAssertionMessage
      assertionCount += 1
    }
    defer { Assert.resetTestAssertionFailureHandler() }

    // when: a non-animated refresh reuses the row at the same frame, with `willUpdate` setting the transform
    appliesTransform = true
    view.refresh(animated: false)

    // then: the render pass asserts once, and leaves the row alone since its frame is unchanged
    expect(assertionCount) == 1
    expect(tracked.frameSetCount) == 0
    expect(tracked.layer().animationKeys()) == nil
    expect(CATransform3DEqualToTransform(tracked.layer().transform, Constants.translation)) == true
  }

  func test_insertedRenderable_assertsWhenWillInsertSetsTransform() {
    // given: layer and view rows whose `willInsert` sets a transform, and a test assertion failure handler
    let layerView = makeLayerContentView(willInsert: { renderable, _ in renderable.layer.transform = Constants.translation }, captureLayer: { _ in })
    let viewView = makeContentView(willInsert: { renderable, _ in renderable.layer.transform = Constants.translation }, captureView: { _ in })

    var assertionCount = 0
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == Constants.identityTransformAssertionMessage
      assertionCount += 1
    }
    defer { Assert.resetTestAssertionFailureHandler() }

    // when: rendering inserts the rows
    layerView.refresh(animated: false)
    viewView.refresh(animated: false)

    // then: each insertion asserts once before the frame is applied
    expect(assertionCount) == 2
  }

  func test_reusedRenderable_keepsTransformSetInUpdate() {
    // given: a rendered layer row whose `update` sets a transform, and a test assertion failure handler
    var trackingLayer: FrameTrackingLayer?
    let view = makeLayerContentView(
      update: { renderable, _ in renderable.layer.transform = Constants.translation },
      captureLayer: { trackingLayer = $0 }
    )

    var assertionCount = 0
    Assert.setTestAssertionFailureHandler { _, _, _, _ in
      assertionCount += 1
    }
    defer { Assert.resetTestAssertionFailureHandler() }

    view.refresh(animated: false)

    guard let tracked = trackingLayer else {
      fail("tracking layer should be created")
      return
    }
    expect(CATransform3DEqualToTransform(tracked.transform, Constants.translation)) == true
    tracked.resetFrameSetCount()

    // when: the row is reused by a scroll and by a refresh
    view.setContentOffset(CGPoint(x: 0, y: 10))
    view.layoutIfNeeded()
    view.refresh(animated: false)

    // then: the transform is reset for the frame check and re-applied by `update` on each pass, without assertions or
    // redundant frame updates, and the row keeps its layout frame
    expect(assertionCount) == 0
    expect(tracked.frameSetCount) == 0
    expect(CATransform3DEqualToTransform(tracked.transform, Constants.translation)) == true
    expect(tracked.hasFrame(CGRect(x: 0, y: 0, width: 100, height: 50))) == true
  }

  // MARK: - Helpers

  /// A content view with a flexible-width tracking-view row below a spacer in a scrollable stack.
  ///
  /// The heights are read on every refresh, so a refresh can keep, move, or resize the row. The animation timing, if
  /// any, is set on the row so that animated passes animate its frame. The lifecycle blocks are added to the row.
  private func makeContentView(spacerHeight: @escaping () -> CGFloat = { 0 },
                               rowHeight: @escaping () -> CGFloat = { 50 },
                               animationTiming: AnimationTiming? = nil,
                               willInsert: @escaping (Renderable, RenderableInsertContext) -> Void = { _, _ in },
                               willUpdate: @escaping (Renderable, RenderableUpdateContext) -> Void = { _, _ in },
                               update: @escaping (Renderable, RenderableUpdateContext) -> Void = { _, _ in },
                               captureView: @escaping (FrameTrackingView) -> Void) -> ComposeView
  {
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      VStack {
        Spacer(height: spacerHeight())

        let row = ViewNode<FrameTrackingView>(make: { context in
          let view = FrameTrackingView(frame: context.initialFrame ?? .zero)
          captureView(view)
          return view
        })
        .frame(width: .flexible, height: rowHeight())
        .willInsert(willInsert)
        .willUpdate(willUpdate)
        .onUpdate(update)

        if let animationTiming {
          row.animation(animationTiming)
        } else {
          row
        }

        ColorNode(.blue)
          .frame(width: .flexible, height: 450)
      }
    }
    return view
  }

  /// A content view with a flexible-width tracking-layer row below a spacer in a scrollable stack.
  ///
  /// The lifecycle blocks are added to the row.
  private func makeLayerContentView(spacerHeight: @escaping () -> CGFloat = { 0 },
                                    willInsert: @escaping (Renderable, RenderableInsertContext) -> Void = { _, _ in },
                                    willUpdate: @escaping (Renderable, RenderableUpdateContext) -> Void = { _, _ in },
                                    update: @escaping (Renderable, RenderableUpdateContext) -> Void = { _, _ in },
                                    captureLayer: @escaping (FrameTrackingLayer) -> Void) -> ComposeView
  {
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      VStack {
        Spacer(height: spacerHeight())

        LayerNode<FrameTrackingLayer>(make: { context in
          let layer = FrameTrackingLayer()
          if let initialFrame = context.initialFrame {
            layer.frame = initialFrame
          }
          captureLayer(layer)
          return layer
        })
        .frame(width: .flexible, height: 50)
        .willInsert(willInsert)
        .willUpdate(willUpdate)
        .onUpdate(update)

        ColorNode(.blue)
          .frame(width: .flexible, height: 450)
      }
    }
    return view
  }

  // MARK: - Constants

  private enum Constants {

    /// The animation timing set on the tracking row in the animated tests.
    static let animationTiming: AnimationTiming = .easeInEaseOut(duration: 1)

    /// A non-identity transform set on the tracking row in the transform ownership tests.
    static let translation = CATransform3DMakeTranslation(20, 0, 0)

    /// The message of the render pass's identity transform assertion.
    static let identityTransformAssertionMessage = "the renderable's transform must be identity when its frame is applied, set a transform in `update` instead of `willInsert` or `willUpdate`"
  }
}
