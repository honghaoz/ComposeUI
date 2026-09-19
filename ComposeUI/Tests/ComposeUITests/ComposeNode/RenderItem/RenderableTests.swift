//
//  RenderableTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/15/25.
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

class RenderableTests: XCTestCase {

  // MARK: - View Case Tests

  func test_view_case_view_property() {
    // given: a view-backed renderable
    let view = BaseView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)

    // then: the view property returns the view
    expect(renderable.view) === view
  }

  func test_view_case_layer_property() {
    // given: a view-backed renderable
    let view = BaseView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)

    // then: the layer property returns the view's layer
    expect(renderable.layer) === view.layer()
  }

  func test_view_case_bounds_property() {
    // given: a view-backed renderable
    let view = BaseView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)

    // then: the bounds match the view's bounds
    expect(renderable.bounds) == CGRect(x: 0, y: 0, width: 100, height: 200)
  }

  func test_view_case_frame_property() {
    // given: a view-backed renderable
    let view = BaseView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)

    // then: the frame matches the view's frame
    expect(renderable.frame) == CGRect(x: 10, y: 20, width: 100, height: 200)
  }

  func test_view_case_setFrame() {
    // given: a view-backed renderable and a new frame
    let view = BaseView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)
    let newFrame = CGRect(x: 30, y: 40, width: 300, height: 400)

    // when: setting the frame
    renderable.setFrame(newFrame)

    // then: the view gets the new frame
    expect(view.frame) == newFrame
  }

  func test_view_case_hasFrame() {
    // given: a view-backed renderable
    let view = BaseView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)

    // then: the renderable has the view's frame, and not a moved or resized one
    expect(renderable.hasFrame(CGRect(x: 10, y: 20, width: 100, height: 200))) == true
    expect(renderable.hasFrame(CGRect(x: 30, y: 40, width: 100, height: 200))) == false
    expect(renderable.hasFrame(CGRect(x: 10, y: 20, width: 300, height: 400))) == false
  }

  #if canImport(AppKit)
  func test_view_case_hasFrame_viewDriftedFromLayer() {
    // given: a view-backed renderable whose backing layer was moved directly, which AppKit doesn't propagate to the view
    let view = BaseView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)
    view.layer().frame = CGRect(x: 30, y: 40, width: 100, height: 200)
    expect(view.frame) == CGRect(x: 10, y: 20, width: 100, height: 200)

    // then: the renderable has neither frame, because its view and its layer disagree
    expect(renderable.hasFrame(CGRect(x: 10, y: 20, width: 100, height: 200))) == false
    expect(renderable.hasFrame(CGRect(x: 30, y: 40, width: 100, height: 200))) == false
  }
  #endif

  func test_view_case_updateFrame_unchanged() {
    // given: a view-backed renderable at a frame
    let view = FrameTrackingView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)
    view.resetFrameSetCount()

    // when: updating to the same frame without animation
    renderable.updateFrame(CGRect(x: 10, y: 20, width: 100, height: 200), animationTiming: nil)

    // then: the frame is not re-applied
    expect(view.frameSetCount) == 0

    // when: updating to the same frame with animation
    renderable.updateFrame(CGRect(x: 10, y: 20, width: 100, height: 200), animationTiming: .easeInEaseOut(duration: 1))

    // then: no frame animation is added and the frame is not re-applied
    expect(view.layer().animationKeys()) == nil
    expect(view.frameSetCount) == 0
    expect(view.frame) == CGRect(x: 10, y: 20, width: 100, height: 200)
  }

  func test_view_case_updateFrame_unchanged_thirdPixelValues() {
    // given: a view-backed renderable at a third-pixel frame (a frame rounded for a 3x display)
    let third: CGFloat = 1 / 3
    let frame = CGRect(x: 10 + third, y: 20, width: 100 + third, height: 30)
    let view = FrameTrackingView(frame: frame)
    let renderable = Renderable.view(view)
    #if canImport(UIKit)
    // a UIKit view's layer is anchored at its center, so the derived frame doesn't round-trip exactly
    expect(view.layer().frame) != frame
    #endif
    view.resetFrameSetCount()

    // when: updating to the same frame without animation
    renderable.updateFrame(frame, animationTiming: nil)

    // then: the frame is recognized as unchanged and not re-applied
    expect(view.frameSetCount) == 0

    // when: updating to the same frame with animation
    renderable.updateFrame(frame, animationTiming: .easeInEaseOut(duration: 1))

    // then: no frame animation is added
    expect(view.layer().animationKeys()) == nil
    expect(view.frameSetCount) == 0
  }

  func test_view_case_updateFrame_changed() {
    // given: a view-backed renderable at a frame
    let view = FrameTrackingView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)
    view.resetFrameSetCount()

    // when: updating to a new frame without animation
    renderable.updateFrame(CGRect(x: 30, y: 40, width: 300, height: 400), animationTiming: nil)

    // then: the frame is applied once, without animation
    expect(view.frame) == CGRect(x: 30, y: 40, width: 300, height: 400)
    expect(view.frameSetCount) == 1
    expect(view.layer().animationKeys()) == nil

    // when: updating to another frame with animation
    renderable.updateFrame(CGRect(x: 50, y: 60, width: 500, height: 600), animationTiming: .easeInEaseOut(duration: 1))

    // then: the frame is animated and the view lands at the new frame
    expect(view.layer().animationKeys()) == ["position", "bounds.size"]
    expect(view.frame) == CGRect(x: 50, y: 60, width: 500, height: 600)
  }

  #if canImport(AppKit)
  func test_view_case_updateFrame_resyncsViewDriftedFromLayer() {
    // given: a view-backed renderable whose backing layer was moved directly to the target frame, leaving the view behind
    let targetFrame = CGRect(x: 30, y: 40, width: 100, height: 200)
    let view = FrameTrackingView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)
    view.layer().frame = targetFrame
    view.resetFrameSetCount()

    // when: updating to the target frame without animation
    renderable.updateFrame(targetFrame, animationTiming: nil)

    // then: the layer already matched but the view didn't, so the frame is applied and the view follows
    expect(view.frameSetCount) == 1
    expect(view.frame) == targetFrame
    expect(view.layer().frame) == targetFrame

    // given: the layer drifts again, this time to be re-synced with animation
    view.layer().frame = CGRect(x: 50, y: 60, width: 100, height: 200)
    view.resetFrameSetCount()

    // when: updating to the layer's frame with animation
    renderable.updateFrame(CGRect(x: 50, y: 60, width: 100, height: 200), animationTiming: .easeInEaseOut(duration: 1))

    // then: the layer already has the frame, so the view is re-synced by setting the frame, without animations
    expect(view.frame) == CGRect(x: 50, y: 60, width: 100, height: 200)
    expect(view.layer().frame) == CGRect(x: 50, y: 60, width: 100, height: 200)
    expect(view.frameSetCount) == 1
    expect(view.layer().animationKeys()) == nil
  }
  #endif

  func test_view_case_addToParent() {
    // given: a parent view and a view-backed renderable
    let parentView = View()
    let childView = View()
    let renderable = Renderable.view(childView)

    // when: adding the renderable to the parent
    renderable.addToParent(parentView)

    // then: the child view is added to the parent
    expect(childView.superview) === parentView
    expect(parentView.subviews.contains(childView)) == true
  }

  func test_view_case_addToParent_alreadyInSameParent() {
    // given: a child view already in the parent, behind another view
    let parentView = View()
    let childView = View()
    parentView.addSubview(childView)

    let renderable = Renderable.view(childView)

    let otherView = View()
    parentView.addSubview(otherView)

    expect(parentView.subviews) == [childView, otherView]

    // when: add the renderable to the parent
    renderable.addToParent(parentView)

    // then: the child view should be brought to the front
    expect(childView.superview) === parentView
    expect(parentView.subviews) == [otherView, childView]
  }

  func test_view_case_addToParent_alreadyAtFront() {
    // given: a child view that is already the front-most subview in the parent
    let parentView = View()
    let otherView = View()
    let childView = View()
    parentView.addSubview(otherView)
    parentView.addSubview(childView)

    let renderable = Renderable.view(childView)

    expect(parentView.subviews) == [otherView, childView]

    // when: adding the renderable to the parent again, should be a no-op
    renderable.addToParent(parentView)

    // then: the subview order is unchanged
    expect(childView.superview) === parentView
    expect(parentView.subviews) == [otherView, childView]
  }

  func test_view_case_addToParent_differentParent() {
    // given: a child view in another parent
    let parentView1 = View()
    let parentView2 = View()
    let childView = View()
    parentView1.addSubview(childView)

    let renderable = Renderable.view(childView)

    // when: adding the renderable to a different parent
    // moving to a different parent should still call addSubview.
    renderable.addToParent(parentView2)

    // then: the child view moves to the new parent
    expect(childView.superview) === parentView2
    expect(parentView1.subviews.contains(childView)) == false
    expect(parentView2.subviews.contains(childView)) == true
  }

  func test_view_case_removeFromParent() {
    // given: a view-backed renderable in a parent view
    let parentView = View()
    let childView = View()
    parentView.addSubview(childView)
    let renderable = Renderable.view(childView)

    // when: removing the renderable from its parent
    renderable.removeFromParent()

    // then: the child view is removed from the parent
    expect(childView.superview) == nil
    expect(parentView.subviews.contains(childView)) == false
  }

  func test_view_case_moveToFront() {
    // given: three subviews with the first at the back
    let parentView = View()
    let firstView = View()
    let secondView = View()
    let thirdView = View()

    parentView.addSubview(firstView)
    parentView.addSubview(secondView)
    parentView.addSubview(thirdView)

    // when: moving the first view's renderable to the front
    let renderable = Renderable.view(firstView)
    renderable.moveToFront()

    // then: the first view is now the last (front-most) subview
    expect(parentView.subviews.last) === firstView
  }

  // MARK: - Layer Case Tests

  func test_layer_case_view_property() {
    // given: a layer-backed renderable
    let layer = CALayer()
    let renderable = Renderable.layer(layer)

    // then: the view property returns nil
    expect(renderable.view) == nil
  }

  func test_layer_case_layer_property() {
    // given: a layer-backed renderable
    let layer = CALayer()
    let renderable = Renderable.layer(layer)

    // then: the layer property returns the layer
    expect(renderable.layer) === layer
  }

  func test_layer_case_bounds_property() {
    // given: a layer-backed renderable
    let layer = CALayer()
    layer.bounds = CGRect(x: 10, y: 20, width: 100, height: 200)
    let renderable = Renderable.layer(layer)

    // then: the bounds match the layer's bounds
    expect(renderable.bounds) == CGRect(x: 10, y: 20, width: 100, height: 200)
  }

  func test_layer_case_frame_property() {
    // given: a layer-backed renderable
    let layer = CALayer()
    layer.frame = CGRect(x: 5, y: 15, width: 150, height: 250)
    let renderable = Renderable.layer(layer)

    // then: the frame matches the layer's frame
    expect(renderable.frame) == CGRect(x: 5, y: 15, width: 150, height: 250)
  }

  func test_layer_case_setFrame() {
    // given: a layer-backed renderable and a new frame
    let layer = CALayer()
    let renderable = Renderable.layer(layer)
    let newFrame = CGRect(x: 30, y: 40, width: 300, height: 400)

    // when: setting the frame
    renderable.setFrame(newFrame)

    // then: the layer gets the new frame
    expect(layer.frame) == newFrame
  }

  func test_layer_case_hasFrame() {
    // given: a layer-backed renderable
    let layer = CALayer()
    layer.frame = CGRect(x: 10, y: 20, width: 100, height: 200)
    let renderable = Renderable.layer(layer)

    // then: the renderable has the layer's frame, and not a moved or resized one
    expect(renderable.hasFrame(CGRect(x: 10, y: 20, width: 100, height: 200))) == true
    expect(renderable.hasFrame(CGRect(x: 30, y: 40, width: 100, height: 200))) == false
    expect(renderable.hasFrame(CGRect(x: 10, y: 20, width: 300, height: 400))) == false
  }

  func test_layer_case_updateFrame_unchanged() {
    // given: a layer-backed renderable at a frame
    let layer = FrameTrackingLayer()
    layer.frame = CGRect(x: 10, y: 20, width: 100, height: 200)
    let renderable = Renderable.layer(layer)
    layer.resetFrameSetCount()

    // when: updating to the same frame without animation
    renderable.updateFrame(CGRect(x: 10, y: 20, width: 100, height: 200), animationTiming: nil)

    // then: the frame is not re-applied
    expect(layer.frameSetCount) == 0

    // when: updating to the same frame with animation
    renderable.updateFrame(CGRect(x: 10, y: 20, width: 100, height: 200), animationTiming: .easeInEaseOut(duration: 1))

    // then: no frame animation is added
    expect(layer.animationKeys()) == nil
    expect(layer.frame) == CGRect(x: 10, y: 20, width: 100, height: 200)
  }

  func test_layer_case_updateFrame_unchanged_thirdPixelValues() {
    // given: a layer-backed renderable at a third-pixel frame (a frame rounded for a 3x display), whose derived frame
    // doesn't round-trip exactly
    let third: CGFloat = 1 / 3
    let frame = CGRect(x: 10 + third, y: 20, width: 100 + third, height: 30)
    let layer = FrameTrackingLayer()
    layer.frame = frame
    expect(layer.frame) != frame
    let renderable = Renderable.layer(layer)
    layer.resetFrameSetCount()

    // when: updating to the same frame without animation
    renderable.updateFrame(frame, animationTiming: nil)

    // then: the frame is recognized as unchanged and not re-applied
    expect(layer.frameSetCount) == 0

    // when: updating to the same frame with animation
    renderable.updateFrame(frame, animationTiming: .easeInEaseOut(duration: 1))

    // then: no frame animation is added
    expect(layer.animationKeys()) == nil
  }

  func test_layer_case_updateFrame_nonIdentityTransform_asserts() {
    // given: a layer-backed renderable at a frame, with a non-identity transform, and a test assertion failure handler
    let layer = FrameTrackingLayer()
    layer.frame = CGRect(x: 10, y: 20, width: 100, height: 200)
    layer.transform = CATransform3DMakeTranslation(20, 0, 0)
    let renderable = Renderable.layer(layer)
    layer.resetFrameSetCount()

    var assertionCount = 0
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message) == "the renderable's transform must be identity when its frame is applied, set a transform in `update` instead of `willInsert` or `willUpdate`"
      assertionCount += 1
    }
    defer { Assert.resetTestAssertionFailureHandler() }

    // when: updating to the same frame
    renderable.updateFrame(CGRect(x: 10, y: 20, width: 100, height: 200), animationTiming: nil)

    // then: the transform is asserted even though the frame is unchanged, and the frame is not re-applied
    expect(assertionCount) == 1
    expect(layer.frameSetCount) == 0
    expect(CATransform3DEqualToTransform(layer.transform, CATransform3DMakeTranslation(20, 0, 0))) == true
  }

  func test_layer_case_updateFrame_changed() {
    // given: a layer-backed renderable at a frame
    let layer = FrameTrackingLayer()
    layer.frame = CGRect(x: 10, y: 20, width: 100, height: 200)
    let renderable = Renderable.layer(layer)
    layer.resetFrameSetCount()

    // when: updating to a new frame without animation
    renderable.updateFrame(CGRect(x: 30, y: 40, width: 300, height: 400), animationTiming: nil)

    // then: the frame is applied once, without animation
    expect(layer.frame) == CGRect(x: 30, y: 40, width: 300, height: 400)
    expect(layer.frameSetCount) == 1
    expect(layer.animationKeys()) == nil

    // when: updating to another frame with animation
    renderable.updateFrame(CGRect(x: 50, y: 60, width: 500, height: 600), animationTiming: .easeInEaseOut(duration: 1))

    // then: the frame is animated and the layer lands at the new frame
    expect(layer.animationKeys()) == ["position", "bounds.size"]
    expect(layer.frame) == CGRect(x: 50, y: 60, width: 500, height: 600)
    expect(layer.frameSetCount) == 1 // animated through position and bounds.size, not through frame
  }

  func test_layer_case_addToParent() {
    // given: a parent view and a layer-backed renderable
    let parentView = BaseView()
    let childLayer = CALayer()
    let renderable = Renderable.layer(childLayer)

    // when: adding the renderable to the parent
    renderable.addToParent(parentView)

    // then: the child layer is added to the parent view's layer
    expect(childLayer.superlayer) === parentView.layer()
    expect(parentView.layer().sublayers?.contains(childLayer)) == true
  }

  func test_layer_case_addToParent_alreadyInSameParent() {
    // given: a child layer already in the parent, behind another layer
    let parentView = BaseView()
    let childLayer = CALayer()
    parentView.layer().addSublayer(childLayer)

    let renderable = Renderable.layer(childLayer)

    let otherLayer = CALayer()
    parentView.layer().addSublayer(otherLayer)

    expect(parentView.layer().sublayers) == [childLayer, otherLayer]

    // when: add the renderable to the parent
    renderable.addToParent(parentView)

    // then: the child layer should be brought to the front
    expect(childLayer.superlayer) === parentView.layer()
    expect(parentView.layer().sublayers) == [otherLayer, childLayer]
  }

  func test_layer_case_addToParent_alreadyAtFront() {
    // given: a child layer that is already the front-most sublayer in the parent
    let parentView = BaseView()
    let otherLayer = CALayer()
    let childLayer = CALayer()
    parentView.layer().addSublayer(otherLayer)
    parentView.layer().addSublayer(childLayer)

    let renderable = Renderable.layer(childLayer)

    expect(parentView.layer().sublayers) == [otherLayer, childLayer]

    // when: adding the renderable to the parent again, should be a no-op
    renderable.addToParent(parentView)

    // then: the sublayer order is unchanged
    expect(childLayer.superlayer) === parentView.layer()
    expect(parentView.layer().sublayers) == [otherLayer, childLayer]
  }

  func test_layer_case_addToParent_differentParent() {
    // given: a child layer in another parent
    let parentView1 = BaseView()
    let parentView2 = BaseView()
    let childLayer = CALayer()
    parentView1.layer().addSublayer(childLayer)

    let renderable = Renderable.layer(childLayer)

    // when: adding the renderable to a different parent
    // moving to a different parent should still call addSublayer.
    renderable.addToParent(parentView2)

    // then: the child layer moves to the new parent
    expect(childLayer.superlayer) === parentView2.layer()
    expect(parentView1.layer().sublayers) == nil
    expect(parentView2.layer().sublayers?.contains(childLayer)) == true
  }

  func test_layer_case_removeFromParent() {
    // given: a layer-backed renderable in a parent view
    let parentView = BaseView()
    let childLayer = CALayer()
    parentView.layer().addSublayer(childLayer)
    let renderable = Renderable.layer(childLayer)

    // when: removing the renderable from its parent
    renderable.removeFromParent()

    // then: the child layer is removed from the parent
    expect(childLayer.superlayer) == nil
    expect(parentView.layer().sublayers) == nil
  }

  func test_layer_case_moveToFront() {
    // given: three sublayers with the first at the back
    let parentView = BaseView()
    let firstLayer = CALayer()
    let secondLayer = CALayer()
    let thirdLayer = CALayer()

    parentView.layer().addSublayer(firstLayer)
    parentView.layer().addSublayer(secondLayer)
    parentView.layer().addSublayer(thirdLayer)

    // when: moving the first layer's renderable to the front
    let renderable = Renderable.layer(firstLayer)
    renderable.moveToFront()

    // then: the first layer is now the last (front-most) sublayer
    expect(parentView.layer().sublayers?.last) === firstLayer
  }
}
