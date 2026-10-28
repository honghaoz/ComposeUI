//
//  CALayer+KeptTransformTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/28/26.
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

import ChouTiTest

@testable import ComposeUI

class CALayer_KeptTransformTests: XCTestCase {

  func test_keepTransform_putsTheTransformBackWhenItBecomesIdentity() {
    // given: a layer that keeps its quarter turn
    let layer = CALayer()
    layer.keepTransform(Constants.quarterTurn)
    layer.transform = Constants.quarterTurn

    // when: the transform becomes identity
    layer.transform = CATransform3DIdentity

    // then: the layer has the quarter turn back
    expect(CATransform3DEqualToTransform(layer.transform, Constants.quarterTurn)) == true
  }

  func test_keepTransform_leavesAnotherTransform() {
    // given: a layer that keeps its quarter turn
    let layer = CALayer()
    layer.keepTransform(Constants.quarterTurn)
    layer.transform = Constants.quarterTurn

    // when: another transform is set
    layer.transform = Constants.doubleScale

    // then: the layer has the other transform, since only identity is put back
    expect(CATransform3DEqualToTransform(layer.transform, Constants.doubleScale)) == true
  }

  func test_keepTransform_again_keepsTheNewTransform() {
    // given: a layer that keeps its quarter turn, then a scale
    let layer = CALayer()
    layer.keepTransform(Constants.quarterTurn)
    layer.transform = Constants.quarterTurn
    layer.keepTransform(Constants.doubleScale)
    layer.transform = Constants.doubleScale

    // when: the transform becomes identity
    layer.transform = CATransform3DIdentity

    // then: the layer has the scale back
    expect(CATransform3DEqualToTransform(layer.transform, Constants.doubleScale)) == true
  }

  func test_keepTransform_identity_stopsKeeping() {
    // given: a layer that keeps its quarter turn, then identity
    let layer = CALayer()
    layer.keepTransform(Constants.quarterTurn)
    layer.transform = Constants.quarterTurn
    layer.keepTransform(CATransform3DIdentity)

    // when: the transform becomes identity
    layer.transform = CATransform3DIdentity

    // then: the transform stays identity
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  func test_stopKeepingTransform_stopsKeeping() {
    // given: a layer that kept its quarter turn
    let layer = CALayer()
    layer.keepTransform(Constants.quarterTurn)
    layer.transform = Constants.quarterTurn
    layer.stopKeepingTransform()

    // when: the transform becomes identity
    layer.transform = CATransform3DIdentity

    // then: the transform stays identity
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  func test_stopKeepingTransform_removesTheObservation() {
    // given: a layer that keeps its quarter turn, which observes the layer's transform
    let layer = CALayer()
    layer.keepTransform(Constants.quarterTurn)
    expect(layer.observationInfo) != nil

    // when: the layer stops keeping its transform
    layer.stopKeepingTransform()

    // then: no observation of the layer is left, which would notify the keeper that went
    expect(layer.observationInfo) == nil
  }

  func test_stopKeepingTransform_withoutAKeptTransform_leavesTheTransform() {
    // given: a layer with a quarter turn that it doesn't keep
    let layer = CALayer()
    layer.transform = Constants.quarterTurn

    // when: the layer stops keeping its transform
    layer.stopKeepingTransform()

    // then: the layer has the quarter turn
    expect(CATransform3DEqualToTransform(layer.transform, Constants.quarterTurn)) == true
  }

  func test_restoreIdentityTransformIfNeeded_stopsKeeping() {
    // given: a layer that keeps its quarter turn
    let layer = CALayer()
    layer.keepTransform(Constants.quarterTurn)
    layer.transform = Constants.quarterTurn

    // when: the layer restores the identity transform
    layer.restoreIdentityTransformIfNeeded()

    // then: the transform is identity, which isn't put back
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  func test_keepTransform_doesNotRetainTheLayer() {
    // given: a layer that keeps its quarter turn, released
    weak var weakLayer: CALayer?
    autoreleasepool {
      let layer = CALayer()
      layer.keepTransform(Constants.quarterTurn)
      layer.transform = Constants.quarterTurn
      weakLayer = layer
      // the transaction holds the layers it changes until it commits
      CATransaction.flush()
    }

    // then: the layer is released, since its keeper doesn't keep it
    expect(weakLayer) == nil
  }

  func test_keepTransform_viewInAWindow_keepsTheTransformThroughAppKitsResets() throws {
    // given: two turned views that joined a window, one of which keeps its transform
    let window = NSWindow(contentRect: Constants.windowFrame, styleMask: [.titled], backing: .buffered, defer: false)
    let contentView = try unwrap(window.contentView)
    let keepingView = NSView(frame: Constants.viewFrame)
    let view = NSView(frame: Constants.viewFrame)
    for view in [keepingView, view] {
      view.wantsLayer = true
      contentView.addSubview(view)
      view.layer?.transform = Constants.quarterTurn
    }
    let keepingLayer = try unwrap(keepingView.layer)
    let layer = try unwrap(view.layer)
    keepingLayer.keepTransform(Constants.quarterTurn)

    // when: the transaction commits, the first since the views joined the window
    CATransaction.flush()

    // then: AppKit reset the transform of the view that doesn't keep it, and the other view has its quarter turn
    expect(CATransform3DIsIdentity(layer.transform)) == true
    expect(CATransform3DEqualToTransform(keepingLayer.transform, Constants.quarterTurn)) == true

    // when: both views move and resize
    keepingView.frame = Constants.movedViewFrame
    view.frame = Constants.movedViewFrame

    // then: the view keeps its quarter turn, and its layer has the geometry of the untransformed view's layer
    expect(CATransform3DEqualToTransform(keepingLayer.transform, Constants.quarterTurn)) == true
    expect(keepingLayer.position) == layer.position
    expect(keepingLayer.bounds) == layer.bounds
  }

  func test_pauseKeepingTransform_leavesTheTransformAlone() {
    // given: a layer that keeps its quarter turn, paused
    let layer = CALayer()
    layer.keepTransform(Constants.quarterTurn)
    layer.transform = Constants.quarterTurn
    let mayBeKeeping = layer.pauseKeepingTransform()

    // when: the transform becomes identity
    layer.transform = CATransform3DIdentity

    // then: the transform stays identity, and the pause tells that the layer can be keeping a transform
    expect(CATransform3DIsIdentity(layer.transform)) == true
    expect(mayBeKeeping) == true
  }

  func test_pauseKeepingTransform_identity_tellsThatTheLayerIsNotKeeping() {
    // given: a layer with the identity transform, while another layer keeps a transform
    let keepingLayer = CALayer()
    keepingLayer.keepTransform(Constants.quarterTurn)
    let layer = CALayer()

    // then: the pause tells that the layer isn't keeping a transform
    expect(layer.pauseKeepingTransform()) == false
    withExtendedLifetime(keepingLayer) {}
  }

  func test_resumeKeepingTransform_keepsTheTransformLeft() {
    // given: a layer that keeps its quarter turn, paused while its transform changes to a scale, then resumed
    let layer = CALayer()
    layer.keepTransform(Constants.quarterTurn)
    layer.transform = Constants.quarterTurn
    let mayBeKeeping = layer.pauseKeepingTransform()
    layer.transform = Constants.doubleScale
    layer.resumeKeepingTransform(mayBeKeeping: mayBeKeeping)

    // when: the transform becomes identity
    layer.transform = CATransform3DIdentity

    // then: the layer has the scale back
    expect(CATransform3DEqualToTransform(layer.transform, Constants.doubleScale)) == true
  }

  func test_resumeKeepingTransform_identity_stopsKeeping() {
    // given: a layer that keeps its quarter turn, paused while its transform changes to identity, then resumed
    let layer = CALayer()
    layer.keepTransform(Constants.quarterTurn)
    layer.transform = Constants.quarterTurn
    let mayBeKeeping = layer.pauseKeepingTransform()
    layer.transform = CATransform3DIdentity
    layer.resumeKeepingTransform(mayBeKeeping: mayBeKeeping)

    // when: the transform changes, then becomes identity
    layer.transform = Constants.quarterTurn
    layer.transform = CATransform3DIdentity

    // then: the transform stays identity
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  func test_resumeKeepingTransform_firstTransform_keepsIt() {
    // given: a layer with the identity transform, paused while it gets a quarter turn, then resumed
    let layer = CALayer()
    let mayBeKeeping = layer.pauseKeepingTransform()
    layer.transform = Constants.quarterTurn
    layer.resumeKeepingTransform(mayBeKeeping: mayBeKeeping)

    // when: the transform becomes identity
    layer.transform = CATransform3DIdentity

    // then: the layer has the quarter turn back
    expect(CATransform3DEqualToTransform(layer.transform, Constants.quarterTurn)) == true
  }

  func test_resumeKeepingTransform_identityThroughout_keepsNothing() {
    // given: a layer with the identity transform, paused and resumed without a change
    let layer = CALayer()
    layer.resumeKeepingTransform(mayBeKeeping: layer.pauseKeepingTransform())

    // when: the transform changes, then becomes identity
    layer.transform = Constants.quarterTurn
    layer.transform = CATransform3DIdentity

    // then: the transform stays identity
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  func test_withTransformKeepingPaused_leavesTheIdentityToTheWork() {
    // given: a layer that keeps its quarter turn
    let layer = CALayer()
    layer.keepTransform(Constants.quarterTurn)
    layer.transform = Constants.quarterTurn

    // when: the work sets identity, then puts the quarter turn back
    var isIdentityInTheWork = false
    layer.withTransformKeepingPaused {
      layer.transform = CATransform3DIdentity
      isIdentityInTheWork = CATransform3DIsIdentity(layer.transform)
      layer.transform = Constants.quarterTurn
    }

    // then: the identity stayed in the work
    expect(isIdentityInTheWork) == true

    // when: the transform becomes identity after the work
    layer.transform = CATransform3DIdentity

    // then: the layer has the quarter turn back, since the keeping goes on after the work
    expect(CATransform3DEqualToTransform(layer.transform, Constants.quarterTurn)) == true
  }

  func test_withTransformKeepingPaused_whilePaused_leavesTheKeepingPaused() {
    // given: a layer that keeps its quarter turn, paused
    let layer = CALayer()
    layer.keepTransform(Constants.quarterTurn)
    layer.transform = Constants.quarterTurn
    _ = layer.pauseKeepingTransform()

    // when: work runs with the keeping paused, then the transform becomes identity
    layer.withTransformKeepingPaused {}
    layer.transform = CATransform3DIdentity

    // then: the transform stays identity, since the keeping is still paused
    expect(CATransform3DIsIdentity(layer.transform)) == true
  }

  func test_withTransformKeepingPaused_withoutAKeptTransform_runsTheWork() {
    // given: a layer that keeps no transform, while another layer keeps one
    let keepingLayer = CALayer()
    keepingLayer.keepTransform(Constants.quarterTurn)
    let layer = CALayer()

    // when: the work turns the layer
    layer.withTransformKeepingPaused {
      layer.transform = Constants.quarterTurn
    }

    // then: the layer has the quarter turn
    expect(CATransform3DEqualToTransform(layer.transform, Constants.quarterTurn)) == true
    withExtendedLifetime(keepingLayer) {}
  }

  // MARK: - Constants

  private enum Constants {

    /// A quarter turn, clockwise on screen.
    static let quarterTurn = CATransform3DMakeRotation(CGFloat.pi / 2, 0, 0, 1)

    /// A scale to twice the size.
    static let doubleScale = CATransform3DMakeScale(2, 2, 1)

    static let windowFrame = CGRect(x: 0, y: 0, width: 200, height: 200)
    static let viewFrame = CGRect(x: 10, y: 20, width: 50, height: 40)

    /// A frame at another origin and size, off the pixel grid.
    static let movedViewFrame = CGRect(x: 7.5, y: 3.25, width: 61, height: 33)
  }
}
#endif
