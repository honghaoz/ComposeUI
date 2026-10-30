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

@_spi(Private) @testable import ComposeUI

/// Tests for the steady-state per-item frame/transform update behavior in the render pass.
///
/// These tests pin down three properties of the reuse path:
/// - Correctness: a reused renderable always ends a render pass with the correct frame, and with the transform that its
///   node set.
/// - Efficiency: a reused renderable whose frame is unchanged (the common case while scrolling) is neither re-framed
///   nor frame-animated, including at third-pixel frames on 3x displays where the derived frame is imprecise.
/// - Exactness: a reused renderable's update context, and its remove context when it leaves, hand out the frame that
///   the previous pass applied as the old frame, including at third-pixel frames.
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
    view.contentOffset = CGPoint(x: 0, y: 10)
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
    view.contentOffset = CGPoint(x: 0, y: 10)
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
    view.contentOffset = CGPoint(x: 0, y: 10)
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

  func test_reusedRenderable_nonAnimatedResizeDuringAnimatedResize_glidesFromTheShownHeight() throws {
    // given: a hosted content view with a frame-tracking row, animating linearly over 1.5 seconds
    let window = TestWindow()
    var rowHeight: CGFloat = 50
    var trackingView: FrameTrackingView?
    let view = makeContentView(
      spacerHeight: { 10 },
      rowHeight: { rowHeight },
      animationTiming: .linear(duration: 1.5),
      captureView: { trackingView = $0 }
    )
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    let layer = try unwrap(trackingView).layer()
    CATransaction.flush()
    expect(layer.presentation()).toEventuallyNot(beNil())

    // when: an animated refresh grows the row to 150 points high, and the resize is part way
    rowHeight = 150
    view.refresh(animated: true)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

    // when: a non-animated refresh sets the row 100 points high while the resize is in flight. the refresh glides from
    // the clock's time for this turn, which the test reads first, see `AnimationClock`
    func heightScalar(_ value: Any) throws -> CGFloat {
      try (value as? CGSize).unwrap().height
    }
    let refreshTime = layer.currentTime
    let heightAtRefresh = try layer.predictedValue(forKeyPath: "bounds.size", at: refreshTime, scalar: heightScalar)
    expect(heightAtRefresh) > 50
    expect(heightAtRefresh) < 100
    rowHeight = 100
    view.refresh(animated: false)

    // then: the height glides from the height shown at the refresh's time instead of jumping to 100
    expect(try layer.predictedValue(forKeyPath: "bounds.size", at: refreshTime, scalar: heightScalar))
      .to(beApproximatelyEqual(to: heightAtRefresh, within: 1e-6))

    // then: whenever the run loop lets the test look, the shown height is where the animations put it, until it lands on
    // 100 when the resize would have ended
    var landed = false
    for _ in 0 ..< 100 where !landed {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
      let (shown, times) = try layer.readPresentation { $0.bounds.height }
      try layer.expectShown(shown, forKeyPath: "bounds.size", between: times, scalar: heightScalar, within: 0.5)
      landed = abs(shown - 100) < 0.01
    }
    expect(landed) == true
    expect(try unwrap(trackingView).frame) == CGRect(x: 0, y: 10, width: 100, height: 100)
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
    view.contentOffset = CGPoint(x: 0, y: 10)
    view.layoutIfNeeded()

    // then: the animated scroll pass adds no frame animations to the reused row
    expect(tracked.frame) == CGRect(x: 0, y: 10, width: 100, height: 50)
    expect(tracked.layer().animationKeys()) == nil
  }

  // MARK: - transform ownership

  func test_reusedRenderable_keepsATransformSetOnce() {
    // given: a rendered layer row whose `willInsert` rotates it once
    var trackingLayer: FrameTrackingLayer?
    let view = makeLayerContentView(
      willInsert: { renderable, _ in renderable.layer.transform = Constants.rotation },
      captureLayer: { trackingLayer = $0 }
    )
    view.refresh(animated: false)

    guard let tracked = trackingLayer else {
      fail("tracking layer should be created")
      return
    }
    tracked.resetFrameSetCount()

    // when: the row is reused by a scroll and by a refresh, which don't rotate it again
    view.contentOffset = CGPoint(x: 0, y: 10)
    view.layoutIfNeeded()
    view.refresh(animated: false)

    // then: the row keeps the rotation and its layout frame, without frame updates
    expect(CATransform3DEqualToTransform(tracked.transform, Constants.rotation)) == true
    expect(tracked.hasFrame(CGRect(x: 0, y: 0, width: 100, height: 50))) == true
    expect(tracked.frameSetCount) == 0
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
    view.contentOffset = CGPoint(x: 0, y: 10)
    view.layoutIfNeeded()

    // then: an already-identity transform stays identity
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  func test_reusedLayer_appliesAFrameChange_underATransformSetInWillUpdate() {
    // given: a rendered layer row whose `willUpdate` rotates it, below a spacer that a refresh can grow
    var spacerHeight: CGFloat = 0
    var trackingLayer: FrameTrackingLayer?
    let view = makeLayerContentView(
      spacerHeight: { spacerHeight },
      willUpdate: { renderable, _ in renderable.layer.transform = Constants.rotation },
      captureLayer: { trackingLayer = $0 }
    )
    view.refresh(animated: false)

    guard let tracked = trackingLayer else {
      fail("tracking layer should be created")
      return
    }
    tracked.resetFrameSetCount()

    // when: a refresh keeps the row's frame
    view.refresh(animated: false)

    // then: the frame is recognized as unchanged under the rotation, which the row keeps
    expect(tracked.frameSetCount) == 0
    expect(CATransform3DEqualToTransform(tracked.transform, Constants.rotation)) == true

    // when: a refresh moves the row down
    spacerHeight = 20
    view.refresh(animated: false)

    // then: the new frame is set once, as where the position and bounds size place the row, which keeps the rotation
    expect(tracked.frameSetCount) == 1
    expect(tracked.hasFrame(CGRect(x: 0, y: 20, width: 100, height: 50))) == true
    expect(CATransform3DEqualToTransform(tracked.transform, Constants.rotation)) == true
    expect(tracked.animationKeys()) == nil
  }

  func test_reusedView_appliesAFrameChange_underATransformSetInWillUpdate() {
    // given: a rendered view row whose `willUpdate` rotates it, with a height that a refresh can change
    var rowHeight: CGFloat = 50
    var trackingView: FrameTrackingView?
    let view = makeContentView(
      rowHeight: { rowHeight },
      willUpdate: { renderable, _ in renderable.layer.transform = Constants.rotation },
      captureView: { trackingView = $0 }
    )
    view.refresh(animated: false)

    guard let tracked = trackingView else {
      fail("tracking view should be created")
      return
    }
    tracked.resetFrameSetCount()

    // when: a refresh keeps the row's frame
    view.refresh(animated: false)

    // then: the frame is recognized as unchanged under the rotation, which the row keeps
    expect(tracked.frameSetCount) == 0
    expect(CATransform3DEqualToTransform(tracked.layer().transform, Constants.rotation)) == true

    // when: a refresh makes the row taller
    rowHeight = 60
    view.refresh(animated: false)

    // then: the new frame is set once, as where the position and bounds size place the row, which keeps the rotation
    expect(tracked.frameSetCount) == 1
    expect(Renderable.view(tracked).frame) == CGRect(x: 0, y: 0, width: 100, height: 60)
    expect(tracked.layer().hasFrame(CGRect(x: 0, y: 0, width: 100, height: 60))) == true
    expect(CATransform3DEqualToTransform(tracked.layer().transform, Constants.rotation)) == true
    expect(tracked.layer().animationKeys()) == nil
  }

  func test_insertedRenderable_appliesTheFrame_underATransformSetInWillInsert() throws {
    // given: layer and view rows whose `willInsert` rotates them
    var trackingLayer: FrameTrackingLayer?
    var trackingView: FrameTrackingView?
    let layerView = makeLayerContentView(willInsert: { renderable, _ in renderable.layer.transform = Constants.rotation }, captureLayer: { trackingLayer = $0 })
    let viewView = makeContentView(willInsert: { renderable, _ in renderable.layer.transform = Constants.rotation }, captureView: { trackingView = $0 })

    // when: rendering inserts the rows
    layerView.refresh(animated: false)
    viewView.refresh(animated: false)

    // then: each row is where its position and bounds size place it, which keeps the rotation
    let layer = try unwrap(trackingLayer)
    let viewLayer = try unwrap(trackingView).layer()
    expect(layer.hasFrame(CGRect(x: 0, y: 0, width: 100, height: 50))) == true
    expect(CATransform3DEqualToTransform(layer.transform, Constants.rotation)) == true
    expect(viewLayer.hasFrame(CGRect(x: 0, y: 0, width: 100, height: 50))) == true
    expect(CATransform3DEqualToTransform(viewLayer.transform, Constants.rotation)) == true
  }

  func test_reusedRenderable_animatesAFrameChange_underATransform() throws {
    // given: a rendered view row with an animation timing, which its `willInsert` rotates once, below a spacer that a
    // refresh can grow
    var spacerHeight: CGFloat = 0
    var trackingView: FrameTrackingView?
    let view = makeContentView(
      spacerHeight: { spacerHeight },
      animationTiming: Constants.animationTiming,
      willInsert: { renderable, _ in renderable.layer.transform = Constants.rotation },
      captureView: { trackingView = $0 }
    )
    view.refresh(animated: false)
    let layer = try unwrap(trackingView).layer()

    // when: an animated refresh moves the row down
    spacerHeight = 20
    view.refresh(animated: true)

    // then: the row animates to where its new frame places it, and keeps the rotation without animating it
    expect(layer.animation(forKey: "position")) != nil
    expect(layer.animation(forKey: "transform")) == nil
    expect(layer.hasFrame(CGRect(x: 0, y: 20, width: 100, height: 50))) == true
    expect(CATransform3DEqualToTransform(layer.transform, Constants.rotation)) == true
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
    view.contentOffset = CGPoint(x: 0, y: 10)
    view.layoutIfNeeded()
    view.refresh(animated: false)

    // then: the row keeps the transform that `update` sets again on each pass, without assertions or redundant frame
    // updates, and keeps its layout frame
    expect(assertionCount) == 0
    expect(tracked.frameSetCount) == 0
    expect(CATransform3DEqualToTransform(tracked.transform, Constants.translation)) == true
    expect(tracked.hasFrame(CGRect(x: 0, y: 0, width: 100, height: 50))) == true
  }

  func test_reusedRenderable_animatesATransformFromTheTransformItKept() throws {
    // given: a layer row whose `update` animates its rotation to an angle, rendered, which animates the rotation from
    // none
    let angle = CGFloat.pi / 6
    var trackingLayer: FrameTrackingLayer?
    let view = makeLayerContentView(
      update: { renderable, _ in
        renderable.layer.animate(keyPath: "transform.rotation.z", to: angle, timing: .linear(duration: 10))
      },
      captureLayer: { trackingLayer = $0 }
    )
    view.refresh(animated: false)

    let layer = try unwrap(trackingLayer)
    expect(layer.basicAnimations(forKeyPath: "transform.rotation.z").last?.fromValue as? CGFloat) == -angle
    layer.removeAllAnimations()

    // when: a refresh animates the rotation to the same angle again
    view.refresh(animated: false)

    // then: the animation starts from the rotation that the row kept, so the row stays at the angle instead of
    // turning from none again
    let fromValue = try unwrap(layer.basicAnimations(forKeyPath: "transform.rotation.z").last?.fromValue as? CGFloat)
    expect(abs(fromValue)) < 1e-9
  }

  #if canImport(AppKit)
  func test_insertedView_keepsATransformSetOnce_throughTheFirstWindowCommit() throws {
    // given: a view in a window, whose content turns a view once in each of `willInsert`, `update` and `didInsert`,
    // rendered outside a run loop block, as an event handler renders, and a plain view in the window that the test
    // turns directly
    let window = makeWindow()
    var turnedLayers: [CALayer] = []
    let contentView = ComposeView {
      HStack {
        ViewNode<BaseView>()
          .flexibleSize()
          .willInsert { renderable, _ in
            renderable.layer.transform = Constants.rotation
            turnedLayers.append(renderable.layer)
          }
        ViewNode<BaseView>()
          .flexibleSize()
          .onUpdate { renderable, context in
            guard context.updateType == .insert else {
              return
            }
            renderable.layer.transform = Constants.rotation
            turnedLayers.append(renderable.layer)
          }
        ViewNode<BaseView>()
          .flexibleSize()
          .onInsert { renderable, _ in
            renderable.layer.transform = Constants.rotation
            turnedLayers.append(renderable.layer)
          }
      }
    }
    let container = BaseView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
    window.contentView = container
    contentView.frame = container.bounds
    container.addSubview(contentView)
    let plainView = BaseView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    container.addSubview(plainView)
    plainView.layer().transform = Constants.rotation
    contentView.refresh()
    expect(turnedLayers.count) == 3

    // when: the run loop turns, which runs its blocks, then commits, where AppKit resets the transform of a view that
    // joined the window
    RunLoop.main.run(until: Date())

    // then: AppKit reset the plain view's transform, while the content's views keep the transforms that their blocks set
    expect(CATransform3DIsIdentity(plainView.layer().transform)) == true
    for layer in turnedLayers {
      expect(CATransform3DEqualToTransform(layer.transform, Constants.rotation)) == true
    }
  }

  func test_reusedView_droppingATransform_isNotPutBack() throws {
    // given: a view in a window, whose content turns a view while a flag is set, rendered, with the run loop turned
    let window = makeWindow()
    var isTurned = true
    var turnedLayer: CALayer?
    let contentView = ComposeView {
      ViewNode<BaseView>()
        .flexibleSize()
        .onUpdate { renderable, _ in
          renderable.layer.transform = isTurned ? Constants.rotation : CATransform3DIdentity
        }
        .onInsert { renderable, _ in
          turnedLayer = renderable.layer
        }
    }
    window.contentView = contentView
    contentView.refresh()
    RunLoop.main.run(until: Date())
    let layer = try unwrap(turnedLayer)
    expect(CATransform3DEqualToTransform(layer.transform, Constants.rotation)) == true

    // when: the content drops the transform, and the run loop turns
    isTurned = false
    contentView.refresh()
    RunLoop.main.run(until: Date())

    // then: the view has the identity transform, which its layer doesn't replace with the rotation it kept
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  func test_view_renderedOutsideAWindow_keepsATransformSetOnce_afterJoiningOne() throws {
    // given: a view outside a window, whose content turns a view once in `willInsert`, rendered, with the run loop
    // turned
    var turnedLayer: CALayer?
    let contentView = ComposeView {
      ViewNode<BaseView>()
        .flexibleSize()
        .willInsert { renderable, _ in
          renderable.layer.transform = Constants.rotation
          turnedLayer = renderable.layer
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    contentView.refresh()
    RunLoop.main.run(until: Date())
    let layer = try unwrap(turnedLayer)

    // when: the view joins a window, and the run loop turns
    let window = makeWindow()
    window.contentView = contentView
    RunLoop.main.run(until: Date())

    // then: the view keeps the rotation
    expect(CATransform3DEqualToTransform(layer.transform, Constants.rotation)) == true
  }

  func test_insertedView_changingTheTransformInATransitionedDidInsert_keepsTheChange() throws {
    // given: a view in a window, whose content rotates two views when it inserts them, then, in `didInsert`, which runs
    // when their insert transition completes after the render pass, drops the rotation of one and translates the
    // other, rendered with the transitions
    let window = makeWindow()
    let transition = RenderableTransition(
      insert: RenderableTransition.InsertTransition { renderable, context, completion in
        renderable.setFrame(context.targetFrame)
        RunLoop.main.perform(completion)
      },
      remove: nil
    )
    var droppingLayer: CALayer?
    var translatedView: View?
    let rotateOnInsert: (Renderable, RenderableUpdateContext) -> Void = { renderable, context in
      guard context.updateType == .insert else {
        return
      }
      renderable.layer.transform = Constants.rotation
    }
    let contentView = ComposeView {
      HStack {
        ViewNode<BaseView>()
          .flexibleSize()
          .transition(transition)
          .onUpdate(rotateOnInsert)
          .onInsert { renderable, _ in
            renderable.layer.transform = CATransform3DIdentity
            droppingLayer = renderable.layer
          }
        ViewNode<BaseView>()
          .flexibleSize()
          .transition(transition)
          .onUpdate(rotateOnInsert)
          .onInsert { renderable, _ in
            renderable.layer.transform = Constants.translation
            translatedView = renderable.view
          }
      }
    }
    window.contentView = contentView
    contentView.refresh(animated: true)
    expect(droppingLayer).to(beNil())

    // when: the run loop turns, which completes the transitions
    RunLoop.main.run(until: Date())

    // then: the view whose `didInsert` dropped the rotation has the identity transform
    let layer = try unwrap(droppingLayer)
    expect(CATransform3DIsIdentity(layer.transform)) == true

    // when: the translated view moves, which makes AppKit reset its transform
    let view = try unwrap(translatedView)
    view.setFrameOrigin(CGPoint(x: view.frame.origin.x + 10, y: view.frame.origin.y))

    // then: the view has the translation back, instead of the rotation that it had before `didInsert`
    expect(CATransform3DEqualToTransform(view.layer().transform, Constants.translation)) == true
  }

  func test_removedView_droppingTheTransformInWillRemove_isNotPutBack() throws {
    // given: a view whose content rotates a view and drops the rotation in `willRemove`, before the view fades out,
    // rendered
    var turnedLayer: CALayer?
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
    contentView.setContent {
      ViewNode<BaseView>()
        .flexibleSize()
        .transition(.opacity(timing: .linear(duration: 10)))
        .onUpdate { renderable, _ in
          renderable.layer.transform = Constants.rotation
          turnedLayer = renderable.layer
        }
        .willRemove { renderable, _ in
          renderable.layer.transform = CATransform3DIdentity
        }
    }
    contentView.refresh(animated: false)
    let layer = try unwrap(turnedLayer)
    expect(CATransform3DEqualToTransform(layer.transform, Constants.rotation)) == true

    // when: the content removes the view with its transition
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // then: the view fades out with the identity transform, which its layer doesn't replace with the rotation it kept
    expect(contentView.test.removingRenderableMap.count) == 1
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }
  #endif

  // MARK: - old frame

  func test_reusedRenderable_oldFrameIsThePreviousFrame_thirdPixelFrame() throws {
    // given: a 3x content view with a layer row at a third-pixel offset, rendered, whose layer derives a frame that
    // differs from the frame that the render pass applied
    let third: CGFloat = 1 / 3
    var spacerHeight = 10 + third
    var updateContext: RenderableUpdateContext?
    var trackingLayer: FrameTrackingLayer?
    let view = makeLayerContentView(spacerHeight: { spacerHeight }, update: { _, context in updateContext = context }, captureLayer: { trackingLayer = $0 })
    view.contentScaleFactor = 3
    view.refresh(animated: false)

    let tracked = try unwrap(trackingLayer)
    let appliedFrame = try unwrap(updateContext?.newFrame)
    expect(tracked.frame) != appliedFrame

    // when: scroll a little, which keeps the row's frame
    view.contentOffset = CGPoint(x: 0, y: 10)
    view.layoutIfNeeded()

    // then: the old frame is the frame that the previous pass applied, equal to the new frame
    expect(updateContext?.updateType) == .boundsChange
    expect(updateContext?.oldFrame) == appliedFrame
    expect(updateContext?.newFrame) == appliedFrame

    // when: refresh, which keeps the row's frame
    view.refresh(animated: false)

    // then: the old frame is the frame that the previous pass applied, equal to the new frame
    expect(updateContext?.updateType) == .refresh
    expect(updateContext?.oldFrame) == appliedFrame
    expect(updateContext?.newFrame) == appliedFrame

    // when: refresh with the row moved to another third-pixel offset
    spacerHeight = 20 + 2 * third
    view.refresh(animated: false)

    // then: the old frame is the frame that the previous pass applied, and the new frame is the moved frame
    let movedFrame = CGRect(x: 0, y: 20 + 2 * third, width: 100, height: 50).rounded(scaleFactor: 3)
    expect(updateContext?.oldFrame) == appliedFrame
    expect(updateContext?.newFrame) == movedFrame

    // when: scroll a little, which keeps the moved frame
    view.contentOffset = CGPoint(x: 0, y: 20)
    view.layoutIfNeeded()

    // then: the old frame is the moved frame, which the previous pass applied
    expect(updateContext?.oldFrame) == movedFrame
    expect(updateContext?.newFrame) == movedFrame
  }

  func test_reusedRenderable_oldFrameIsThePreviousFrame_afterAnEarlierItemLeaves() throws {
    // given: a 3x content view with a layer row at a third-pixel offset below another row, rendered
    let third: CGFloat = 1 / 3
    var updateContext: RenderableUpdateContext?
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      VStack {
        ColorNode(.red)
          .frame(width: .flexible, height: 50 + third)

        LayerNode()
          .frame(width: .flexible, height: 50)
          .onUpdate { _, context in updateContext = context }

        ColorNode(.blue)
          .frame(width: .flexible, height: 450)
      }
    }
    view.contentScaleFactor = 3
    view.refresh(animated: false)

    let appliedFrame = try unwrap(updateContext?.newFrame)

    // when: scroll past the first row, which leaves the visible bounds, so the layer row is reused at another index
    view.contentOffset = CGPoint(x: 0, y: 60)
    view.layoutIfNeeded()

    // then: the old frame is the frame that the previous pass applied to the layer row, equal to the new frame
    expect(updateContext?.updateType) == .boundsChange
    expect(updateContext?.oldFrame) == appliedFrame
    expect(updateContext?.newFrame) == appliedFrame
  }

  func test_reusedRenderable_oldFrameIsThePreviousFrame_afterScaleChange() throws {
    // given: a 3x content view with a layer row at a third-pixel offset, rendered
    let third: CGFloat = 1 / 3
    var updateContext: RenderableUpdateContext?
    let view = makeLayerContentView(spacerHeight: { 10 + third }, update: { _, context in updateContext = context }, captureLayer: { _ in })
    view.contentScaleFactor = 3
    view.refresh(animated: false)

    let appliedFrame = try unwrap(updateContext?.newFrame)

    // when: the scale changes to 2x, and the view refreshes
    view.contentScaleFactor = 2
    view.refresh(animated: false)

    // then: the old frame is the frame that the previous pass applied at 3x, and the new frame is on the 2x pixel grid
    expect(updateContext?.oldFrame) == appliedFrame
    expect(updateContext?.newFrame) == CGRect(x: 0, y: 10.5, width: 100, height: 50)
  }

  func test_reusedRenderable_oldFrameIsThePreviousFrame_whenAppCodeMovedTheRenderable() throws {
    // given: a content view with a layer row, rendered, whose layer app code then moves 5 points down
    var updateContext: RenderableUpdateContext?
    var trackingLayer: FrameTrackingLayer?
    let view = makeLayerContentView(
      update: { _, context in
        updateContext = context
      },
      captureLayer: { trackingLayer = $0 }
    )
    view.refresh(animated: false)

    let tracked = try unwrap(trackingLayer)
    let appliedFrame = CGRect(x: 0, y: 0, width: 100, height: 50)
    tracked.frame = appliedFrame.offsetBy(dx: 0, dy: 5)

    // when: scroll a little, which keeps the row's frame
    view.contentOffset = CGPoint(x: 0, y: 10)
    view.layoutIfNeeded()

    // then: the old frame is the frame that the previous pass applied, not where app code moved the layer, and the pass
    // moves the layer back to it
    expect(updateContext?.oldFrame) == appliedFrame
    expect(updateContext?.newFrame) == appliedFrame
    expect(tracked.frame) == appliedFrame
  }

  func test_removedRenderable_oldFrameIsThePreviousFrame_thirdPixelFrame() throws {
    // given: a 3x content view with a layer row at a third-pixel offset, rendered, whose layer derives a frame that
    // differs from the frame that the render pass applied
    let third: CGFloat = 1 / 3
    var appliedFrame: CGRect?
    var willRemoveContext: RenderableRemoveContext?
    var didRemoveContext: RenderableRemoveContext?
    var trackingLayer: FrameTrackingLayer?
    let view = makeLayerContentView(
      spacerHeight: { 10 + third },
      update: { _, context in appliedFrame = context.newFrame },
      willRemove: { _, context in willRemoveContext = context },
      didRemove: { _, context in didRemoveContext = context },
      captureLayer: { trackingLayer = $0 }
    )
    view.contentScaleFactor = 3
    view.refresh(animated: false)

    let tracked = try unwrap(trackingLayer)
    let frame = try unwrap(appliedFrame)
    expect(tracked.frame) != frame

    // when: scroll the row out of the visible bounds
    view.contentOffset = CGPoint(x: 0, y: 200)
    view.layoutIfNeeded()

    // then: both remove blocks get the frame that the previous pass applied as the old frame
    expect(willRemoveContext?.oldFrame) == frame
    expect(didRemoveContext?.oldFrame) == frame
  }

  func test_removedRenderable_oldFrameIsThePreviousFrame_afterScaleChange() throws {
    // given: a 3x content view with a layer row at a third-pixel offset, rendered
    let third: CGFloat = 1 / 3
    var appliedFrame: CGRect?
    var removeContext: RenderableRemoveContext?
    let view = makeLayerContentView(
      spacerHeight: { 10 + third },
      update: { _, context in appliedFrame = context.newFrame },
      willRemove: { _, context in removeContext = context },
      captureLayer: { _ in }
    )
    view.contentScaleFactor = 3
    view.refresh(animated: false)

    let frame = try unwrap(appliedFrame)

    // when: the scale changes to 2x, and the row scrolls out of the visible bounds in the same pass
    view.contentScaleFactor = 2
    view.contentOffset = CGPoint(x: 0, y: 200)
    view.layoutIfNeeded()

    // then: the old frame is the frame that the previous pass applied at 3x
    expect(removeContext?.oldFrame) == frame
  }

  // MARK: - frame kept by the updates

  func test_update_changingTheFrame_asserts() throws {
    // given: a content view with a layer row whose `update` moves the layer 5 points down while a flag is set, and a
    // handler that records the assertions
    var movesLayer = true
    var trackingLayer: FrameTrackingLayer?
    let view = makeLayerContentView(
      update: { renderable, context in
        if movesLayer {
          renderable.layer.frame = context.newFrame.offsetBy(dx: 0, dy: 5)
        }
      },
      captureLayer: { trackingLayer = $0 }
    )
    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: the view renders, inserting the row, then refreshes, reusing it
    view.refresh(animated: false)
    view.refresh(animated: false)

    // then: the update asserts on the insertion and on the reuse
    expect(assertionMessages.count) == 2
    expect(assertionMessages.allSatisfy { $0.hasPrefix("an update changed the frame of renderable: ") }) == true

    // when: the update keeps the frame, and the view refreshes
    movesLayer = false
    assertionMessages.removeAll()
    view.refresh(animated: false)

    // then: nothing asserts, and the pass moved the layer back to its frame
    expect(assertionMessages) == []
    expect(try unwrap(trackingLayer).frame) == CGRect(x: 0, y: 0, width: 100, height: 50)
  }

  func test_update_ofAViewThatRefusesItsFrame_doesNotAssert() throws {
    // given: a content view with a row of a view that keeps a 40 x 40 size, laid out at 100 x 50, and a handler that
    // records the assertions
    var refusingView: SizeKeepingView?
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      ViewNode<SizeKeepingView>()
        .frame(width: .flexible, height: 50)
        .onUpdate { renderable, _ in
          refusingView = renderable.view as? SizeKeepingView
        }
    }
    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: the view renders, inserting the row, then refreshes, reusing it
    view.refresh(animated: false)
    view.refresh(animated: false)

    // then: the view kept its size, and nothing asserts, since the updates kept the frame that the view has
    expect(try unwrap(refusingView).frame.size) == SizeKeepingView.size
    expect(assertionMessages) == []
  }

  // MARK: - Helpers

  #if canImport(AppKit)
  /// A window to show a view in.
  private func makeWindow() -> NSWindow {
    NSWindow(contentRect: CGRect(x: 0, y: 0, width: 300, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
  }
  #endif

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
                                    willRemove: @escaping (Renderable, RenderableRemoveContext) -> Void = { _, _ in },
                                    didRemove: @escaping (Renderable, RenderableRemoveContext) -> Void = { _, _ in },
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
        .willRemove(willRemove)
        .onRemove(didRemove)

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

    /// A rotation set on the tracking row in the transform ownership tests, which a frame set through `frame` would
    /// resize as well as move.
    static let rotation = CATransform3DMakeRotation(CGFloat.pi / 6, 0, 0, 1)
  }
}

// MARK: - SizeKeepingView

/// A view that keeps a fixed size whatever frame it's given, as `UISwitch` does.
private final class SizeKeepingView: BaseView {

  /// The size that the view keeps.
  static let size = CGSize(width: 40, height: 40)

  #if canImport(AppKit)
  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(Self.size)
  }
  #else
  override var frame: CGRect {
    get {
      super.frame
    }
    set {
      super.frame = CGRect(origin: newValue.origin, size: Self.size)
    }
  }
  #endif
}
