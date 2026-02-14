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
    let view = BaseView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)

    expect(renderable.view) === view
  }

  func test_view_case_layer_property() {
    let view = BaseView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)

    expect(renderable.layer) === view.layer()
  }

  func test_view_case_bounds_property() {
    let view = BaseView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)

    expect(renderable.bounds) == CGRect(x: 0, y: 0, width: 100, height: 200)
  }

  func test_view_case_frame_property() {
    let view = BaseView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)

    expect(renderable.frame) == CGRect(x: 10, y: 20, width: 100, height: 200)
  }

  func test_view_case_setFrame() {
    let view = BaseView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)
    let newFrame = CGRect(x: 30, y: 40, width: 300, height: 400)

    renderable.setFrame(newFrame)

    expect(view.frame) == newFrame
  }

  func test_view_case_addToParent() {
    let parentView = View()
    let childView = View()
    let renderable = Renderable.view(childView)

    renderable.addToParent(parentView)

    expect(childView.superview) === parentView
    expect(parentView.subviews.contains(childView)) == true
  }

  func test_view_case_addToParent_alreadyInSameParent() {
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
    let parentView = View()
    let otherView = View()
    let childView = View()
    parentView.addSubview(otherView)
    parentView.addSubview(childView)

    let renderable = Renderable.view(childView)

    expect(parentView.subviews) == [otherView, childView]

    // childView is already the front-most subview, should be a no-op.
    renderable.addToParent(parentView)

    expect(childView.superview) === parentView
    expect(parentView.subviews) == [otherView, childView]
  }

  func test_view_case_addToParent_differentParent() {
    let parentView1 = View()
    let parentView2 = View()
    let childView = View()
    parentView1.addSubview(childView)

    let renderable = Renderable.view(childView)

    // moving to a different parent should still call addSubview.
    renderable.addToParent(parentView2)

    expect(childView.superview) === parentView2
    expect(parentView1.subviews.contains(childView)) == false
    expect(parentView2.subviews.contains(childView)) == true
  }

  func test_view_case_removeFromParent() {
    let parentView = View()
    let childView = View()
    parentView.addSubview(childView)
    let renderable = Renderable.view(childView)

    renderable.removeFromParent()

    expect(childView.superview) == nil
    expect(parentView.subviews.contains(childView)) == false
  }

  func test_view_case_moveToFront() {
    let parentView = View()
    let firstView = View()
    let secondView = View()
    let thirdView = View()

    parentView.addSubview(firstView)
    parentView.addSubview(secondView)
    parentView.addSubview(thirdView)

    let renderable = Renderable.view(firstView)
    renderable.moveToFront()

    // First view should now be the last (front-most) subview
    expect(parentView.subviews.last) === firstView
  }

  // MARK: - Layer Case Tests

  func test_layer_case_view_property() {
    let layer = CALayer()
    let renderable = Renderable.layer(layer)

    expect(renderable.view) == nil
  }

  func test_layer_case_layer_property() {
    let layer = CALayer()
    let renderable = Renderable.layer(layer)

    expect(renderable.layer) === layer
  }

  func test_layer_case_bounds_property() {
    let layer = CALayer()
    layer.bounds = CGRect(x: 10, y: 20, width: 100, height: 200)
    let renderable = Renderable.layer(layer)

    expect(renderable.bounds) == CGRect(x: 10, y: 20, width: 100, height: 200)
  }

  func test_layer_case_frame_property() {
    let layer = CALayer()
    layer.frame = CGRect(x: 5, y: 15, width: 150, height: 250)
    let renderable = Renderable.layer(layer)

    expect(renderable.frame) == CGRect(x: 5, y: 15, width: 150, height: 250)
  }

  func test_layer_case_setFrame() {
    let layer = CALayer()
    let renderable = Renderable.layer(layer)
    let newFrame = CGRect(x: 30, y: 40, width: 300, height: 400)

    renderable.setFrame(newFrame)

    expect(layer.frame) == newFrame
  }

  func test_layer_case_addToParent() {
    let parentView = BaseView()
    let childLayer = CALayer()
    let renderable = Renderable.layer(childLayer)

    renderable.addToParent(parentView)

    expect(childLayer.superlayer) === parentView.layer()
    expect(parentView.layer().sublayers?.contains(childLayer)) == true
  }

  func test_layer_case_addToParent_alreadyInSameParent() {
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
    let parentView = BaseView()
    let otherLayer = CALayer()
    let childLayer = CALayer()
    parentView.layer().addSublayer(otherLayer)
    parentView.layer().addSublayer(childLayer)

    let renderable = Renderable.layer(childLayer)

    expect(parentView.layer().sublayers) == [otherLayer, childLayer]

    // childLayer is already the front-most sublayer, should be a no-op.
    renderable.addToParent(parentView)

    expect(childLayer.superlayer) === parentView.layer()
    expect(parentView.layer().sublayers) == [otherLayer, childLayer]
  }

  func test_layer_case_addToParent_differentParent() {
    let parentView1 = BaseView()
    let parentView2 = BaseView()
    let childLayer = CALayer()
    parentView1.layer().addSublayer(childLayer)

    let renderable = Renderable.layer(childLayer)

    // moving to a different parent should still call addSublayer.
    renderable.addToParent(parentView2)

    expect(childLayer.superlayer) === parentView2.layer()
    expect(parentView1.layer().sublayers) == nil
    expect(parentView2.layer().sublayers?.contains(childLayer)) == true
  }

  func test_layer_case_removeFromParent() {
    let parentView = BaseView()
    let childLayer = CALayer()
    parentView.layer().addSublayer(childLayer)
    let renderable = Renderable.layer(childLayer)

    renderable.removeFromParent()

    expect(childLayer.superlayer) == nil
    expect(parentView.layer().sublayers) == nil
  }

  func test_layer_case_moveToFront() {
    let parentView = BaseView()
    let firstLayer = CALayer()
    let secondLayer = CALayer()
    let thirdLayer = CALayer()

    parentView.layer().addSublayer(firstLayer)
    parentView.layer().addSublayer(secondLayer)
    parentView.layer().addSublayer(thirdLayer)

    let renderable = Renderable.layer(firstLayer)
    renderable.moveToFront()

    // First layer should now be the last (front-most) sublayer
    expect(parentView.layer().sublayers?.last) === firstLayer
  }
}
