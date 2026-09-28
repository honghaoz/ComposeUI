//
//  CALayer+KeyPathValueTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/27/26.
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

import QuartzCore

import ChouTiTest

@_spi(Private) @testable import ComposeUI

class CALayer_KeyPathValueTests: XCTestCase {

  func test_setKeyPathValue_position() throws {
    // given: a test window with a container view
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    #if os(macOS)
    // given: a layer-backed view with a centered anchor point
    do {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = view.layer()
      layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
      layer.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      view.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      expect(layer.position) == CGPoint(x: 150, y: 225)

      // when: setting the position key path value
      layer.setKeyPathValue("position", CGPoint(x: 180, y: 250)) // x: 30, y: 25

      // then: the layer frame moves and the view frame follows
      expect(layer.frame) == CGRect(x: 130, y: 225, width: 100, height: 50)
      expect(view.frame) == layer.frame
    }

    // given: a layer-hosted view with a centered anchor point
    do {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = CALayer()
      view.layer = layer
      layer.delegate = view as? CALayerDelegate
      layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
      layer.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      view.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      expect(layer.position) == CGPoint(x: 150, y: 225)

      // when: setting the position key path value
      layer.setKeyPathValue("position", CGPoint(x: 180, y: 250)) // x: 30, y: 25

      // then: the layer frame moves and the view frame follows
      expect(layer.frame) == CGRect(x: 130, y: 225, width: 100, height: 50)
      expect(view.frame) == layer.frame
    }
    #endif

    #if canImport(UIKit)
    // given: a view in the container view
    let view = UIView(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    containerView.addSubview(view)
    let layer = view.layer

    // when: setting the position key path value
    layer.setKeyPathValue("position", CGPoint(x: 10, y: 20))

    // then: the layer position is updated
    expect(layer.position) == CGPoint(x: 10, y: 20)
    #endif
  }

  func test_setKeyPathValue_bounds_size() throws {
    // given: a test window with a container view
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    #if os(macOS)
    // given: a layer-backed view
    do {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = view.layer()
      layer.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      view.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      expect(layer.bounds.size) == CGSize(width: 100, height: 50)

      // when: setting the bounds.size key path value
      layer.setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))

      // then: the layer bounds and frame are updated and the view follows
      expect(layer.bounds.size) == CGSize(width: 150, height: 80)
      expect(view.bounds.size) == layer.bounds.size
      expect(layer.frame) == CGRect(x: 100, y: 200, width: 150, height: 80)
      expect(view.frame) == layer.frame
    }

    // given: a layer-hosted view
    do {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = CALayer()
      view.layer = layer
      layer.delegate = view as? CALayerDelegate
      layer.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      view.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      expect(layer.bounds.size) == CGSize(width: 100, height: 50)

      // when: setting the bounds.size key path value
      layer.setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))

      // then: the layer bounds and frame are updated and the view follows
      expect(layer.bounds.size) == CGSize(width: 150, height: 80)
      expect(view.bounds.size) == layer.bounds.size
      expect(layer.frame) == CGRect(x: 100, y: 200, width: 150, height: 80)
      expect(view.frame) == layer.frame
    }
    #endif

    #if canImport(UIKit)
    // given: a view in the container view
    let view = UIView(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    expect(layer.bounds.size) == CGSize(width: 100, height: 50)

    // when: setting the bounds.size key path value
    layer.setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))

    // then: the layer bounds and frame are updated and the view follows
    expect(layer.bounds.size) == CGSize(width: 150, height: 80)
    expect(view.bounds.size) == layer.bounds.size
    expect(view.frame) == CGRect(x: 75, y: 185, width: 150, height: 80)
    expect(view.frame) == layer.frame
    #endif
  }

  func test_setKeyPathValue_anchorPoint() throws {
    // given: a test window with a container view
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    // given: a plain layer, testing layer's behavior by changing anchor point
    do {
      let layer = CALayer()
      layer.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      expect(layer.anchorPoint) == CGPoint(x: 0.5, y: 0.5)

      // when: setting the anchorPoint key path value
      layer.setKeyPathValue("anchorPoint", CGPoint(x: 0, y: 0))

      // then: the frame moves to keep the anchor point position in parent the same
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0) // a plain layer takes the new anchor point directly
      expect(layer.frame) == CGRect(x: 225, y: 175, width: 50, height: 50)
    }

    #if os(macOS)
    // given: a layer-backed view
    do {
      let view = View(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = view.layer()
      layer.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      view.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0) // default for macOS

      // when: setting the anchorPoint key path value
      layer.setKeyPathValue("anchorPoint", CGPoint(x: 0.5, y: 0.5))

      // then: the frame moves to keep the anchor point position in parent the same
      // the anchor point reads back as (0, 0) because AppKit re-normalizes the backing layer's anchor point to the
      // macOS default when the view's frame is set
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0)
      expect(layer.frame) == CGRect(x: 175, y: 125, width: 50, height: 50)
      expect(view.frame) == layer.frame
    }

    // given: a layer-hosted view
    do {
      let view = View(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = CALayer()
      view.layer = layer
      layer.delegate = view as? CALayerDelegate
      layer.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      view.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0) // default for macOS

      // when: setting the anchorPoint key path value
      layer.setKeyPathValue("anchorPoint", CGPoint(x: 0.5, y: 0.5))

      // then: the frame moves to keep the anchor point position in parent the same
      // the anchor point reads back as (0, 0) because AppKit re-normalizes the hosted layer's anchor point to the
      // macOS default when the view's frame is set
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0)
      expect(layer.frame) == CGRect(x: 175, y: 125, width: 50, height: 50)
      expect(view.frame) == layer.frame
    }
    #endif

    #if canImport(UIKit)
    // given: a view in the container view
    let view = UIView(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    expect(layer.anchorPoint) == CGPoint(x: 0.5, y: 0.5) // default for iOS

    // when: setting the anchorPoint key path value
    layer.setKeyPathValue("anchorPoint", CGPoint(x: 0, y: 0))

    // then: the anchor point is updated and the frame moves to keep the anchor point position in parent the same
    expect(layer.anchorPoint) == CGPoint(x: 0, y: 0)
    expect(layer.frame) == CGRect(x: 225, y: 175, width: 50, height: 50)
    expect(view.frame) == layer.frame
    #endif
  }

  func test_setKeyPathValue_bounds() throws {
    // given: a test window with a container view
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    #if os(macOS)
    // given: a layer-backed view with a child view
    do {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let childView = View(frame: CGRect(x: 30, y: 30, width: 10, height: 10))
      view.addSubview(childView)
      let layer = view.layer()
      layer.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      view.frame = CGRect(x: 100, y: 200, width: 100, height: 50)

      // when: setting the bounds key path value with a new origin and size, and committing
      layer.setKeyPathValue("bounds", CGRect(x: 10, y: 20, width: 150, height: 80))
      CATransaction.flush()

      // then: the layer bounds and frame are updated, the view follows, and the child shows shifted by the bounds origin
      expect(layer.bounds) == CGRect(x: 10, y: 20, width: 150, height: 80)
      expect(layer.frame) == CGRect(x: 100, y: 200, width: 150, height: 80)
      expect(view.frame) == layer.frame
      expect(view.bounds) == layer.bounds
      expect(try layer.convert(childView.layer().frame, to: layer.superlayer.unwrap())) == CGRect(x: 120, y: 210, width: 10, height: 10)

      // when: moving the view
      view.frame.origin = CGPoint(x: 110, y: 200)
      CATransaction.flush()

      // then: the bounds are kept
      expect(layer.bounds) == CGRect(x: 10, y: 20, width: 150, height: 80)
      expect(view.bounds) == layer.bounds
    }

    // given: a layer-hosted view with a child view
    do {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = CALayer()
      view.layer = layer
      layer.delegate = view as? CALayerDelegate
      let childView = View(frame: CGRect(x: 30, y: 30, width: 10, height: 10))
      view.addSubview(childView)
      layer.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      view.frame = CGRect(x: 100, y: 200, width: 100, height: 50)

      // when: setting the bounds key path value with a new origin and size, and committing
      layer.setKeyPathValue("bounds", CGRect(x: 10, y: 20, width: 150, height: 80))
      CATransaction.flush()

      // then: the layer bounds and frame are updated, the view follows, and the child shows shifted by the bounds origin
      expect(layer.bounds) == CGRect(x: 10, y: 20, width: 150, height: 80)
      expect(layer.frame) == CGRect(x: 100, y: 200, width: 150, height: 80)
      expect(view.frame) == layer.frame
      expect(view.bounds) == layer.bounds
      expect(try layer.convert(childView.layer().frame, to: layer.superlayer.unwrap())) == CGRect(x: 120, y: 210, width: 10, height: 10)

      // when: moving the view
      view.frame.origin = CGPoint(x: 110, y: 200)
      CATransaction.flush()

      // then: the bounds are kept
      expect(layer.bounds) == CGRect(x: 10, y: 20, width: 150, height: 80)
      expect(view.bounds) == layer.bounds
    }

    // given: a flipped layer-backed view with a child view
    do {
      let view = BaseView(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let childView = View(frame: CGRect(x: 30, y: 30, width: 10, height: 10))
      view.addSubview(childView)
      let layer = view.layer()
      layer.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      view.frame = CGRect(x: 100, y: 200, width: 100, height: 50)

      // when: setting the bounds key path value with a new origin and size, and committing
      layer.setKeyPathValue("bounds", CGRect(x: 10, y: 20, width: 150, height: 80))
      CATransaction.flush()

      // then: the layer bounds and frame are updated, the view follows, and the child shows shifted by the bounds origin.
      // the flipped view measures y down from its top edge at 280, so the child spans 10 to 20 points below it
      expect(layer.bounds) == CGRect(x: 10, y: 20, width: 150, height: 80)
      expect(layer.frame) == CGRect(x: 100, y: 200, width: 150, height: 80)
      expect(view.frame) == layer.frame
      expect(view.bounds) == layer.bounds
      expect(try layer.convert(childView.layer().frame, to: layer.superlayer.unwrap())) == CGRect(x: 120, y: 260, width: 10, height: 10)

      // when: moving the view
      view.frame.origin = CGPoint(x: 110, y: 200)
      CATransaction.flush()

      // then: the bounds are kept
      expect(layer.bounds) == CGRect(x: 10, y: 20, width: 150, height: 80)
      expect(view.bounds) == layer.bounds
    }
    #endif

    #if canImport(UIKit)
    // given: a view with a child view in the container view
    let view = UIView(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    containerView.addSubview(view)
    let childView = UIView(frame: CGRect(x: 30, y: 30, width: 10, height: 10))
    view.addSubview(childView)
    let layer = view.layer

    // when: setting the bounds key path value with a new origin and size, and committing
    layer.setKeyPathValue("bounds", CGRect(x: 10, y: 20, width: 150, height: 80))
    CATransaction.flush()

    // then: the layer bounds and frame are updated around the centered anchor point, the view follows, and the child
    // shows shifted by the bounds origin
    expect(layer.bounds) == CGRect(x: 10, y: 20, width: 150, height: 80)
    expect(view.frame) == CGRect(x: 75, y: 185, width: 150, height: 80)
    expect(view.frame) == layer.frame
    expect(view.bounds) == layer.bounds
    expect(layer.convert(childView.layer.frame, to: containerView.layer)) == CGRect(x: 95, y: 195, width: 10, height: 10)
    #endif
  }

  func test_setKeyPathValue_geometryComponent() throws {
    // given: four views in a test window
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()
    func makeView() -> View {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      #if os(macOS)
      view.wantsLayer = true
      #endif
      containerView.addSubview(view)
      return view
    }
    let movedView = makeView()
    let resizedView = makeView()
    let anchoredView = makeView()
    let shiftedView = makeView()

    // when: setting one component per view, of the position, the bounds size, the anchor point and the bounds origin,
    // and committing
    movedView.layer().setKeyPathValue("position.x", CGFloat(180))
    resizedView.layer().setKeyPathValue("bounds.size.width", CGFloat(120))
    anchoredView.layer().setKeyPathValue("anchorPoint.y", CGFloat(1))
    shiftedView.layer().setKeyPathValue("bounds.origin.x", CGFloat(10))
    CATransaction.flush()

    // then: the components are set, the layer frames follow, and so do the view frames and bounds. the anchor point is
    // the origin on macOS and the center on iOS
    expect(movedView.layer().position.x) == 180
    expect(resizedView.layer().bounds.size) == CGSize(width: 120, height: 50)
    expect(shiftedView.layer().bounds.origin) == CGPoint(x: 10, y: 0)
    #if os(macOS)
    expect(movedView.layer().frame) == CGRect(x: 180, y: 200, width: 100, height: 50)
    expect(resizedView.layer().frame) == CGRect(x: 100, y: 200, width: 120, height: 50)
    expect(anchoredView.layer().frame) == CGRect(x: 100, y: 150, width: 100, height: 50)
    #else
    expect(movedView.layer().frame) == CGRect(x: 130, y: 200, width: 100, height: 50)
    expect(resizedView.layer().frame) == CGRect(x: 90, y: 200, width: 120, height: 50)
    expect(anchoredView.layer().frame) == CGRect(x: 100, y: 175, width: 100, height: 50)
    #endif
    expect(shiftedView.layer().frame) == CGRect(x: 100, y: 200, width: 100, height: 50)
    expect(movedView.frame) == movedView.layer().frame
    expect(resizedView.frame) == resizedView.layer().frame
    expect(anchoredView.frame) == anchoredView.layer().frame
    expect(shiftedView.frame) == shiftedView.layer().frame
    expect(shiftedView.bounds) == shiftedView.layer().bounds
  }

  func test_setKeyPathValue_geometry_keepsTransform() throws {
    // given: three views in a test window, rotated by 30 degrees after their first commit
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()
    func makeView() -> View {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      #if os(macOS)
      view.wantsLayer = true
      #endif
      containerView.addSubview(view)
      return view
    }
    let movedView = makeView()
    let resizedView = makeView()
    let shiftedView = makeView()
    CATransaction.flush()
    let rotation = CATransform3DMakeRotation(.pi / 6, 0, 0, 1)
    CATransaction.disableAnimations {
      for view in [movedView, resizedView, shiftedView] {
        view.layer().transform = rotation
      }
    }
    CATransaction.flush()

    // when: setting a component of the position on one, the whole bounds on another and a component of the bounds
    // origin on the last, and committing
    movedView.layer().setKeyPathValue("position.x", CGFloat(180))
    resizedView.layer().setKeyPathValue("bounds", CGRect(x: 10, y: 20, width: 150, height: 80))
    shiftedView.layer().setKeyPathValue("bounds.origin.x", CGFloat(10))
    CATransaction.flush()

    // then: the layers take the new geometry and keep their rotation. on macOS, the view frames are the frames without
    // the rotation, and the view bounds match the layers'
    expect(movedView.layer().position.x) == 180
    expect(movedView.layer().bounds) == CGRect(x: 0, y: 0, width: 100, height: 50)
    expect(resizedView.layer().bounds) == CGRect(x: 10, y: 20, width: 150, height: 80)
    expect(shiftedView.layer().bounds) == CGRect(x: 10, y: 0, width: 100, height: 50)
    for view in [movedView, resizedView, shiftedView] {
      expect(CATransform3DEqualToTransform(view.layer().transform, rotation)) == true
    }
    #if os(macOS)
    expect(movedView.frame) == CGRect(x: 180, y: 200, width: 100, height: 50)
    expect(resizedView.frame) == CGRect(x: 100, y: 200, width: 150, height: 80)
    expect(shiftedView.frame) == CGRect(x: 100, y: 200, width: 100, height: 50)
    for view in [movedView, resizedView, shiftedView] {
      expect(view.bounds) == view.layer().bounds
    }
    #endif
  }

  #if canImport(AppKit)
  func test_setKeyPathValue_keyPathsNamedLikeGeometry_leaveTheViewAlone() {
    // given: a view in a test window whose layer moved without the view, as setting a layer's position directly leaves an
    // AppKit view behind
    let testWindow = TestWindow()
    let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    view.wantsLayer = true
    testWindow.contentView().addSubview(view)
    CATransaction.disableAnimations {
      view.layer().position = CGPoint(x: 300, y: 300)
    }
    let viewFrame = view.frame
    expect(viewFrame) != view.layer().frame

    // when: setting key paths whose first components only start like the name of a property the view's geometry comes
    // from
    view.layer().setKeyPathValue("anchorPointZ", CGFloat(1))
    view.layer().setKeyPathValue("positionOffset", CGFloat(2))
    view.layer().setKeyPathValue("boundsInset", CGFloat(3))

    // then: the values are set, and the view isn't moved to the layer's frame
    expect(view.layer().anchorPointZ) == 1
    expect(view.layer().value(forKey: "positionOffset") as? CGFloat) == 2
    expect(view.layer().value(forKey: "boundsInset") as? CGFloat) == 3
    expect(view.frame) == viewFrame

    // when: setting a component of the position
    view.layer().setKeyPathValue("position.x", CGFloat(300))

    // then: the view follows the layer
    expect(view.frame) == view.layer().frame
  }
  #endif

  func test_setKeyPathValue_opacity() throws {
    // given: a test window with a container view
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    #if os(macOS)
    // given: a layer-backed view with full opacity
    do {
      let view = View(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = view.layer()
      expect(layer.opacity) == 1.0
      expect(view.alpha) == 1.0

      // when: setting the opacity key path value
      layer.setKeyPathValue("opacity", Float(0.7))

      // then: the layer opacity is updated and the view alpha matches
      expect(layer.opacity) == 0.7
      expect(view.alpha) == CGFloat(layer.opacity) // view alpha should match layer opacity
    }

    // given: a layer-hosted view with full opacity
    do {
      let view = View(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = CALayer()
      view.layer = layer
      layer.delegate = view as? CALayerDelegate
      expect(layer.opacity) == 1.0
      expect(view.alpha) == 1.0
      expect(layer.backedView) === view

      // when: setting the opacity key path value
      layer.setKeyPathValue("opacity", Float(0.3))

      // then: the layer opacity is updated and the view alpha matches
      expect(layer.opacity) == 0.3
      expect(view.alpha) == CGFloat(layer.opacity) // view alpha should match layer opacity
    }
    #endif

    #if canImport(UIKit)
    // given: a view with full opacity in the container view
    let view = UIView(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    expect(layer.opacity) == 1.0
    expect(view.alpha) == 1.0

    // when: setting the opacity key path value
    layer.setKeyPathValue("opacity", Float(0.8))

    // then: the layer opacity is updated and the view alpha matches
    expect(layer.opacity) == 0.8
    expect(view.alpha) == CGFloat(layer.opacity) // view alpha should match layer opacity
    #endif
  }

  func test_setKeyPathValue_opacityOfOtherType_viewBacked_asserts() {
    // given: a view with full opacity in a test window
    let testWindow = TestWindow()
    let view = View(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
    #if canImport(AppKit)
    view.wantsLayer = true
    #endif
    testWindow.contentView().addSubview(view)

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: setting the opacity of the view's backing layer to a value that isn't a `Float`
    view.layer().setKeyPathValue("opacity", CGFloat(0.5))

    // then: it asserts, and the layer and the view keep their opacity
    expect(assertionMessages) == ["Expected Float value for \"opacity\" keyPath, got CGFloat"]
    expect(view.layer().opacity) == 1
    expect(view.alpha) == 1
  }

  func test_setKeyPathValue_directWrites() {
    // given: a layer that counts KVC writes
    let layer = KVCCountingLayer()

    // when: setting the properties set directly, with values of their property types
    layer.setKeyPathValue("position", CGPoint(x: 10, y: 20))
    layer.setKeyPathValue("bounds.size", CGSize(width: 30, height: 40))
    layer.setKeyPathValue("shadowOffset", CGSize(width: 5, height: 6))
    layer.setKeyPathValue("opacity", Float(0.5))
    layer.setKeyPathValue("shadowOpacity", Float(0.25))
    layer.setKeyPathValue("borderWidth", CGFloat(2))
    layer.setKeyPathValue("cornerRadius", CGFloat(3))
    layer.setKeyPathValue("shadowRadius", CGFloat(4))

    // then: they are set without KVC
    expect(layer.position) == CGPoint(x: 10, y: 20)
    expect(layer.bounds.size) == CGSize(width: 30, height: 40)
    expect(layer.shadowOffset) == CGSize(width: 5, height: 6)
    expect(layer.opacity) == 0.5
    expect(layer.shadowOpacity) == 0.25
    expect(layer.borderWidth) == 2
    expect(layer.cornerRadius) == 3
    expect(layer.shadowRadius) == 4
    expect(layer.kvcWriteCount) == 0

    // when: setting values wrapped in optionals, as the generic `animate` passes an optional value type and `retarget`
    // passes an optional `Any`
    layer.setKeyPathValue("shadowOpacity", Float?(0.75) as Any)
    layer.setKeyPathValue("cornerRadius", Any?(CGFloat(5)) as Any)

    // then: they are set without KVC
    expect(layer.shadowOpacity) == 0.75
    expect(layer.cornerRadius) == 5
    expect(layer.kvcWriteCount) == 0

    // when: setting the properties with values of other types
    layer.setKeyPathValue("position", CGSize(width: 11, height: 21))
    layer.setKeyPathValue("bounds.size", CGPoint(x: 31, y: 41))
    layer.setKeyPathValue("shadowOffset", CGPoint(x: 7, y: 8))
    layer.setKeyPathValue("opacity", CGFloat(0.25))
    layer.setKeyPathValue("shadowOpacity", CGFloat(0.5))
    layer.setKeyPathValue("borderWidth", Float(6))
    layer.setKeyPathValue("cornerRadius", 9)
    layer.setKeyPathValue("shadowRadius", Float(8))

    // then: they are set through KVC, which converts the boxed values
    expect(layer.position) == CGPoint(x: 11, y: 21)
    expect(layer.bounds.size) == CGSize(width: 31, height: 41)
    expect(layer.shadowOffset) == CGSize(width: 7, height: 8)
    expect(layer.opacity) == 0.25
    expect(layer.shadowOpacity) == 0.5
    expect(layer.borderWidth) == 6
    expect(layer.cornerRadius) == 9
    expect(layer.shadowRadius) == 8
    expect(layer.kvcWriteCount) == 8

    // when: setting other key paths
    layer.setKeyPathValue("anchorPoint", CGPoint(x: 0.25, y: 0.75))
    layer.setKeyPathValue("transform.scale", CGFloat(2))

    // then: they are set through KVC
    expect(layer.anchorPoint) == CGPoint(x: 0.25, y: 0.75)
    expect(CATransform3DEqualToTransform(layer.transform, CATransform3DMakeScale(2, 2, 2))) == true
    expect(layer.kvcWriteCount) == 10
  }

  func test_setKeyPathValue_directWrites_colorsAndPaths() {
    // given: a layer and a shape layer that count KVC writes, and colors and paths
    let layer = KVCCountingLayer()
    let shapeLayer = KVCCountingShapeLayer()
    let red = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
    let green = CGColor(red: 0, green: 1, blue: 0, alpha: 1)
    let blue = CGColor(red: 0, green: 0, blue: 1, alpha: 1)
    let rect = CGPath(rect: CGRect(x: 0, y: 0, width: 10, height: 20), transform: nil)
    let ellipse = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 10, height: 20), transform: nil)

    // when: setting the colors and the paths set directly
    layer.setKeyPathValue("backgroundColor", red)
    layer.setKeyPathValue("borderColor", green)
    layer.setKeyPathValue("shadowColor", blue)
    layer.setKeyPathValue("shadowPath", rect)
    shapeLayer.setKeyPathValue("path", rect)

    // then: they are set without KVC
    expect(layer.backgroundColor) == red
    expect(layer.borderColor) == green
    expect(layer.shadowColor) == blue
    expect(layer.shadowPath) == rect
    expect(shapeLayer.path) == rect
    expect(layer.kvcWriteCount) == 0
    expect(shapeLayer.kvcWriteCount) == 0

    // when: setting values wrapped in optionals, as the shadow modifier animates an optional path and `retarget` passes
    // an optional `Any`
    layer.setKeyPathValue("shadowPath", CGPath?(ellipse) as Any)
    layer.setKeyPathValue("backgroundColor", Any?(blue) as Any)

    // then: they are set without KVC
    expect(layer.shadowPath) == ellipse
    expect(layer.backgroundColor) == blue
    expect(layer.kvcWriteCount) == 0

    // when: setting nil colors and paths
    layer.setKeyPathValue("backgroundColor", CGColor?.none as Any)
    layer.setKeyPathValue("borderColor", CGColor?.none as Any)
    layer.setKeyPathValue("shadowColor", CGColor?.none as Any)
    layer.setKeyPathValue("shadowPath", CGPath?.none as Any)
    shapeLayer.setKeyPathValue("path", CGPath?.none as Any)

    // then: they are set to nil without KVC, which would set the null a nil optional bridges to as the colors, and
    // ignore it as the shape layer's path
    expect(layer.backgroundColor) == nil
    expect(layer.borderColor) == nil
    expect(layer.shadowColor) == nil
    expect(layer.shadowPath) == nil
    expect(shapeLayer.path) == nil
    expect(layer.kvcWriteCount) == 0
    expect(shapeLayer.kvcWriteCount) == 0
  }

  func test_setKeyPathValue_colorOrPathOfOtherType_asserts() {
    // given: a layer and a shape layer that count KVC writes, with colors and paths
    let red = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
    let rect = CGPath(rect: CGRect(x: 0, y: 0, width: 10, height: 20), transform: nil)
    let layer = KVCCountingLayer()
    layer.backgroundColor = red
    layer.borderColor = red
    layer.shadowColor = red
    layer.shadowPath = rect
    let shapeLayer = KVCCountingShapeLayer()
    shapeLayer.path = rect

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: setting a platform color as each color, and a color as each path
    let platformColor = Color.red
    layer.setKeyPathValue("backgroundColor", platformColor)
    layer.setKeyPathValue("borderColor", platformColor)
    layer.setKeyPathValue("shadowColor", platformColor)
    layer.setKeyPathValue("shadowPath", red)
    shapeLayer.setKeyPathValue("path", red)

    // then: each asserts and is left unset, since KVC would store the platform color as it is and can't make a path of
    // a color
    expect(assertionMessages) == [
      "expected a CGColor or nil at \"backgroundColor\", got \(platformColor)",
      "expected a CGColor or nil at \"borderColor\", got \(platformColor)",
      "expected a CGColor or nil at \"shadowColor\", got \(platformColor)",
      "expected a CGPath or nil at \"shadowPath\", got \(red)",
      "expected a CGPath or nil at \"path\", got \(red)",
    ]
    expect(layer.backgroundColor) == red
    expect(layer.borderColor) == red
    expect(layer.shadowColor) == red
    expect(layer.shadowPath) == rect
    expect(shapeLayer.path) == rect
    expect(layer.kvcWriteCount) == 0
    expect(shapeLayer.kvcWriteCount) == 0

    // when: setting a color at the `path` key path of a layer that isn't a shape layer
    layer.setKeyPathValue("path", red)

    // then: the layer has no `path` property, so the color is set through KVC as a value for the key, without asserting
    expect(layer.value(forKey: "path").map { $0 as AnyObject }) === red
    expect(layer.kvcWriteCount) == 1
    expect(assertionMessages.count) == 5
  }

  func test_setKeyPathValue_directWrites_viewBacked() throws {
    // given: a view whose backing layer counts KVC writes, in a test window
    let testWindow = TestWindow()
    let view = KVCCountingView(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    #if canImport(AppKit)
    view.wantsLayer = true
    #endif
    testWindow.contentView().addSubview(view)
    let layer = try (view.layer() as? KVCCountingLayer).unwrap()

    // when: setting the position and the bounds size with values of their property types
    layer.setKeyPathValue("position", CGPoint(x: 180, y: 250))
    layer.setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))

    // then: they are set without KVC, and the view follows
    expect(layer.position) == CGPoint(x: 180, y: 250)
    expect(layer.bounds.size) == CGSize(width: 150, height: 80)
    expect(view.frame) == layer.frame
    expect(layer.kvcWriteCount) == 0

    // when: setting a component of the position
    layer.setKeyPathValue("position.x", CGFloat(190))

    // then: it is set through KVC, and the view follows
    expect(layer.position) == CGPoint(x: 190, y: 250)
    expect(view.frame) == layer.frame
    expect(layer.kvcWriteCount) == 1
  }

  func test_setKeyPathValue_directWritesMatchKVC() {
    // given: pairs of plain layers, of shape layers and of views' backing layers, and a value for each property set
    // directly
    let testWindow = TestWindow()
    func makeViewLayer() -> CALayer {
      let view = View(frame: CGRect(x: 10, y: 20, width: 30, height: 40))
      #if canImport(AppKit)
      view.wantsLayer = true
      #endif
      testWindow.contentView().addSubview(view)
      return view.layer()
    }
    let layerPairs: [(CALayer, CALayer)] = [(CALayer(), CALayer()), (CAShapeLayer(), CAShapeLayer()), (makeViewLayer(), makeViewLayer())]
    let values: [(keyPath: String, value: Any)] = [
      ("position", CGPoint(x: 50, y: 60)),
      ("bounds.size", CGSize(width: 70, height: 80)),
      ("shadowOffset", CGSize(width: 5, height: 6)),
      ("opacity", Float(0.5)),
      ("shadowOpacity", Float(0.25)),
      ("borderWidth", CGFloat(2)),
      ("cornerRadius", CGFloat(3)),
      ("shadowRadius", CGFloat(4)),
      ("backgroundColor", CGColor(red: 1, green: 0, blue: 0, alpha: 1)),
      ("borderColor", CGColor(red: 0, green: 1, blue: 0, alpha: 1)),
      ("shadowColor", CGColor(red: 0, green: 0, blue: 1, alpha: 1)),
      ("shadowPath", CGPath(rect: CGRect(x: 0, y: 0, width: 10, height: 20), transform: nil)),
      ("path", CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 10, height: 20), transform: nil)),
    ]

    for (layer, kvcLayer) in layerPairs {
      for (keyPath, value) in values {
        // when: setting the value with `setKeyPathValue` on one layer and through KVC on the other
        layer.setKeyPathValue(keyPath, value)
        CATransaction.disableAnimations {
          kvcLayer.setValue(value, forKeyPath: keyPath)
        }

        // then: the layers have the same value
        expect(layer.value(forKeyPath: keyPath) as? NSObject) == kvcLayer.value(forKeyPath: keyPath) as? NSObject
      }
    }
  }

  func test_setKeyPathValue_disablesImplicitAnimations() {
    // given: a layer hosted in a window, committed so that its changes animate implicitly
    let testWindow = TestWindow()
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    testWindow.layer.addSublayer(layer)
    expect(layer.presentation()).toEventuallyNot(beNil())

    // when: setting values directly and through KVC, outside a transaction that disables actions
    layer.setKeyPathValue("position", CGPoint(x: 100, y: 100))
    layer.setKeyPathValue("cornerRadius", CGFloat(8))
    layer.setKeyPathValue("zPosition", CGFloat(1))

    // then: the values are set without implicit animations
    expect(layer.position) == CGPoint(x: 100, y: 100)
    expect(layer.cornerRadius) == 8
    expect(layer.zPosition) == 1
    expect(layer.animationKeys()) == nil

    // when: setting a value without `setKeyPathValue`
    layer.cornerRadius = 4

    // then: it animates implicitly, as the values set with `setKeyPathValue` would have
    expect(layer.animationKeys()) == ["cornerRadius"]
  }

  func test_setKeyPathValue_inTransactionDisablingActions() {
    // given: a layer hosted in a window, committed so that its changes animate implicitly, and a view in the window
    let testWindow = TestWindow()
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    testWindow.layer.addSublayer(layer)
    let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    #if canImport(AppKit)
    view.wantsLayer = true
    #endif
    testWindow.contentView().addSubview(view)
    expect(layer.presentation()).toEventuallyNot(beNil())

    // when: setting values inside a transaction that disables animations, as a render pass does
    CATransaction.disableAnimations {
      layer.setKeyPathValue("cornerRadius", CGFloat(8))
      layer.setKeyPathValue("zPosition", CGFloat(1))
      view.layer().setKeyPathValue("opacity", Float(0.5))
      view.layer().setKeyPathValue("position", CGPoint(x: 180, y: 250))
    }

    // then: the values are set without animations, and the view follows its layer
    expect(layer.cornerRadius) == 8
    expect(layer.zPosition) == 1
    expect(layer.animationKeys()) == nil
    expect(view.layer().opacity) == 0.5
    expect(view.alpha) == 0.5
    expect(view.layer().position) == CGPoint(x: 180, y: 250)
    expect(view.frame) == view.layer().frame
    expect(view.layer().animationKeys()) == nil
  }

  func test_setKeyPathValue_viewSettersTurningActionsOn_keepActionsOff() {
    // given: a view whose frame and alpha setters enable actions with a duration, as app code a view runs can, and a
    // layer hosted in a window, committed so that its changes animate implicitly
    let testWindow = TestWindow()
    let view = ActionsEnablingView(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    #if canImport(AppKit)
    view.wantsLayer = true
    #endif
    testWindow.contentView().addSubview(view)
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    testWindow.layer.addSublayer(layer)
    expect(layer.presentation()).toEventuallyNot(beNil())
    view.resetSetterCallCount()

    // when: in a transaction that disables animations, as a render pass does, setting the position and the opacity of
    // the view's backing layer, then changing the hosted layer
    CATransaction.disableAnimations {
      view.layer().setKeyPathValue("position", CGPoint(x: 180, y: 250))
      view.layer().setKeyPathValue("opacity", Float(0.5))
      layer.cornerRadius = 8
    }

    // then: the view's setters ran and turned actions on, but actions are turned off again after each write, so the
    // hosted layer's change doesn't animate. a UIKit view's frame follows its layer without its frame setter
    #if canImport(AppKit)
    expect(view.setterCallCount) == 2
    #else
    expect(view.setterCallCount) == 1
    #endif
    expect(view.layer().position) == CGPoint(x: 180, y: 250)
    expect(view.alpha) == 0.5
    expect(layer.cornerRadius) == 8
    expect(layer.animationKeys()) == nil
  }

  func test_skippingViewSync() {
    // given: two views in a window that count their frame sets
    let testWindow = TestWindow()
    let view = FrameTrackingView(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    let otherView = FrameTrackingView(frame: CGRect(x: 100, y: 300, width: 100, height: 50))
    testWindow.contentView().addSubview(view)
    testWindow.contentView().addSubview(otherView)
    view.resetFrameSetCount()
    otherView.resetFrameSetCount()

    // when: moving both views' layers, skipping the view sync of the first view's layer
    view.layer().skippingViewSync {
      view.layer().setKeyPathValue("position", CGPoint(x: 180, y: 250))
      otherView.layer().setKeyPathValue("position", CGPoint(x: 180, y: 350))
    }

    // then: both layers move and the other view follows its layer. on AppKit, the first view keeps its frame, while a
    // UIKit view's frame is its layer's, without its frame setter
    expect(view.layer().position) == CGPoint(x: 180, y: 250)
    expect(otherView.layer().position) == CGPoint(x: 180, y: 350)
    expect(otherView.frame) == otherView.layer().frame
    #if canImport(AppKit)
    expect(view.frame) == CGRect(x: 100, y: 200, width: 100, height: 50)
    expect(view.frameSetCount) == 0
    expect(otherView.frameSetCount) == 1
    #else
    expect(view.frame) == view.layer().frame
    expect(view.frameSetCount) == 0
    expect(otherView.frameSetCount) == 0
    #endif

    // when: resizing the first view's layer after the block
    view.layer().setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))

    // then: the first view follows both its layer's position and size
    expect(view.layer().position) == CGPoint(x: 180, y: 250)
    expect(view.layer().bounds.size) == CGSize(width: 150, height: 80)
    expect(view.frame) == view.layer().frame
    #if canImport(AppKit)
    expect(view.frameSetCount) == 1
    #endif
  }

  func test_skippingViewSync_nested() {
    // given: two views in a window that count their frame sets
    let testWindow = TestWindow()
    let view = FrameTrackingView(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    let otherView = FrameTrackingView(frame: CGRect(x: 100, y: 300, width: 100, height: 50))
    testWindow.contentView().addSubview(view)
    testWindow.contentView().addSubview(otherView)
    view.resetFrameSetCount()
    otherView.resetFrameSetCount()

    // when: in the first view layer's block, skipping the view sync of the other view's layer in an inner block, then
    // writing both layers' geometry after the inner block
    view.layer().skippingViewSync {
      otherView.layer().skippingViewSync {
        otherView.layer().setKeyPathValue("position", CGPoint(x: 180, y: 350))
      }
      otherView.layer().setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))
      view.layer().setKeyPathValue("position", CGPoint(x: 180, y: 250))
    }

    // then: the other view syncs again after the inner block, following both its layer's position and size. on AppKit,
    // the first view's sync stays skipped until the outer block ends
    expect(otherView.layer().position) == CGPoint(x: 180, y: 350)
    expect(otherView.layer().bounds.size) == CGSize(width: 150, height: 80)
    expect(otherView.frame) == otherView.layer().frame
    expect(view.layer().position) == CGPoint(x: 180, y: 250)
    #if canImport(AppKit)
    expect(otherView.frameSetCount) == 1
    expect(view.frame) == CGRect(x: 100, y: 200, width: 100, height: 50)
    expect(view.frameSetCount) == 0
    #else
    expect(view.frame) == view.layer().frame
    #endif

    // when: resizing the first view's layer after the outer block
    view.layer().setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))

    // then: the first view follows its layer again
    expect(view.frame) == view.layer().frame
    #if canImport(AppKit)
    expect(view.frameSetCount) == 1
    #endif
  }

  func test_skippingViewSync_layerWithoutView() {
    // given: a layer that doesn't back a view
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)

    // when: setting its position while skipping the view sync
    layer.skippingViewSync {
      layer.setKeyPathValue("position", CGPoint(x: 40, y: 60))
    }

    // then: the position is set
    expect(layer.position) == CGPoint(x: 40, y: 60)
  }
}

/// A view whose frame and alpha setters enable actions with a duration in the current transaction, as app code a view
/// runs to animate its own sublayers can.
private final class ActionsEnablingView: View {

  private(set) var setterCallCount = 0

  func resetSetterCallCount() {
    setterCallCount = 0
  }

  override var frame: CGRect {
    get {
      super.frame
    }
    set {
      enableActions()
      super.frame = newValue
    }
  }

  #if canImport(AppKit)
  override var alphaValue: CGFloat {
    get {
      super.alphaValue
    }
    set {
      enableActions()
      super.alphaValue = newValue
    }
  }
  #endif

  #if canImport(UIKit)
  override var alpha: CGFloat {
    get {
      super.alpha
    }
    set {
      enableActions()
      super.alpha = newValue
    }
  }
  #endif

  private func enableActions() {
    setterCallCount += 1
    CATransaction.setDisableActions(false)
    CATransaction.setAnimationDuration(1)
  }
}
