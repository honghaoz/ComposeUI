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

import XCTest

@testable import ComposeUI

class RenderableTests: XCTestCase {

  // MARK: - View Case Tests

  func test_view_case_view_property() {
    let view = UIView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)

    XCTAssertTrue(renderable.view === view)
  }

  func test_view_case_layer_property() {
    let view = UIView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)

    XCTAssertTrue(renderable.layer === view.layer)
  }

  func test_view_case_bounds_property() {
    let view = UIView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)

    XCTAssertEqual(renderable.bounds, CGRect(x: 0, y: 0, width: 100, height: 200))
  }

  func test_view_case_frame_property() {
    let view = UIView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)

    XCTAssertEqual(renderable.frame, CGRect(x: 10, y: 20, width: 100, height: 200))
  }

  func test_view_case_setFrame() {
    let view = UIView(frame: CGRect(x: 10, y: 20, width: 100, height: 200))
    let renderable = Renderable.view(view)
    let newFrame = CGRect(x: 30, y: 40, width: 300, height: 400)

    renderable.setFrame(newFrame)

    XCTAssertEqual(view.frame, newFrame)
  }

  func test_view_case_addToParent() {
    let parentView = UIView()
    let childView = UIView()
    let renderable = Renderable.view(childView)

    renderable.addToParent(parentView)

    XCTAssertTrue(childView.superview === parentView)
    XCTAssertTrue(parentView.subviews.contains(childView))
  }

  func test_view_case_addToParent_alreadyInSameParent() {
    let parentView = UIView()
    let childView = UIView()
    parentView.addSubview(childView)

    let renderable = Renderable.view(childView)

    let otherView = UIView()
    parentView.addSubview(otherView)

    XCTAssertEqual(parentView.subviews, [childView, otherView])

    // when: add the renderable to the parent
    renderable.addToParent(parentView)

    // then: the child view should be brought to the front
    XCTAssertTrue(childView.superview === parentView)
    XCTAssertEqual(parentView.subviews, [otherView, childView])
  }

  func test_view_case_addToParent_alreadyAtFront() {
    let parentView = UIView()
    let otherView = UIView()
    let childView = UIView()
    parentView.addSubview(otherView)
    parentView.addSubview(childView)

    let renderable = Renderable.view(childView)

    XCTAssertEqual(parentView.subviews, [otherView, childView])

    // childView is already the front-most subview, should be a no-op.
    renderable.addToParent(parentView)

    XCTAssertTrue(childView.superview === parentView)
    XCTAssertEqual(parentView.subviews, [otherView, childView])
  }

  func test_view_case_addToParent_differentParent() {
    let parentView1 = UIView()
    let parentView2 = UIView()
    let childView = UIView()
    parentView1.addSubview(childView)

    let renderable = Renderable.view(childView)

    // moving to a different parent should still call addSubview.
    renderable.addToParent(parentView2)

    XCTAssertTrue(childView.superview === parentView2)
    XCTAssertFalse(parentView1.subviews.contains(childView))
    XCTAssertTrue(parentView2.subviews.contains(childView))
  }

  func test_view_case_removeFromParent() {
    let parentView = UIView()
    let childView = UIView()
    parentView.addSubview(childView)
    let renderable = Renderable.view(childView)

    renderable.removeFromParent()

    XCTAssertNil(childView.superview)
    XCTAssertFalse(parentView.subviews.contains(childView))
  }

  func test_view_case_moveToFront() {
    let parentView = UIView()
    let firstView = UIView()
    let secondView = UIView()
    let thirdView = UIView()

    parentView.addSubview(firstView)
    parentView.addSubview(secondView)
    parentView.addSubview(thirdView)

    let renderable = Renderable.view(firstView)
    renderable.moveToFront()

    // First view should now be the last (front-most) subview
    XCTAssertTrue(parentView.subviews.last === firstView)
  }

  // MARK: - Layer Case Tests

  func test_layer_case_view_property() {
    let layer = CALayer()
    let renderable = Renderable.layer(layer)

    XCTAssertNil(renderable.view)
  }

  func test_layer_case_layer_property() {
    let layer = CALayer()
    let renderable = Renderable.layer(layer)

    XCTAssertTrue(renderable.layer === layer)
  }

  func test_layer_case_bounds_property() {
    let layer = CALayer()
    layer.bounds = CGRect(x: 10, y: 20, width: 100, height: 200)
    let renderable = Renderable.layer(layer)

    XCTAssertEqual(renderable.bounds, CGRect(x: 10, y: 20, width: 100, height: 200))
  }

  func test_layer_case_frame_property() {
    let layer = CALayer()
    layer.frame = CGRect(x: 5, y: 15, width: 150, height: 250)
    let renderable = Renderable.layer(layer)

    XCTAssertEqual(renderable.frame, CGRect(x: 5, y: 15, width: 150, height: 250))
  }

  func test_layer_case_setFrame() {
    let layer = CALayer()
    let renderable = Renderable.layer(layer)
    let newFrame = CGRect(x: 30, y: 40, width: 300, height: 400)

    renderable.setFrame(newFrame)

    XCTAssertEqual(layer.frame, newFrame)
  }

  func test_layer_case_addToParent() {
    let parentView = UIView()
    let childLayer = CALayer()
    let renderable = Renderable.layer(childLayer)

    renderable.addToParent(parentView)

    XCTAssertTrue(childLayer.superlayer === parentView.layer)
    XCTAssertEqual(parentView.layer.sublayers?.contains(childLayer), true)
  }

  func test_layer_case_addToParent_alreadyInSameParent() {
    let parentView = UIView()
    let childLayer = CALayer()
    parentView.layer.addSublayer(childLayer)

    let renderable = Renderable.layer(childLayer)

    let otherLayer = CALayer()
    parentView.layer.addSublayer(otherLayer)

    XCTAssertEqual(parentView.layer.sublayers, [childLayer, otherLayer])

    // when: add the renderable to the parent
    renderable.addToParent(parentView)

    // then: the child layer should be brought to the front
    XCTAssertTrue(childLayer.superlayer === parentView.layer)
    XCTAssertEqual(parentView.layer.sublayers, [otherLayer, childLayer])
  }

  func test_layer_case_addToParent_alreadyAtFront() {
    let parentView = UIView()
    let otherLayer = CALayer()
    let childLayer = CALayer()
    parentView.layer.addSublayer(otherLayer)
    parentView.layer.addSublayer(childLayer)

    let renderable = Renderable.layer(childLayer)

    XCTAssertEqual(parentView.layer.sublayers, [otherLayer, childLayer])

    // childLayer is already the front-most sublayer, should be a no-op.
    renderable.addToParent(parentView)

    XCTAssertTrue(childLayer.superlayer === parentView.layer)
    XCTAssertEqual(parentView.layer.sublayers, [otherLayer, childLayer])
  }

  func test_layer_case_addToParent_differentParent() {
    let parentView1 = UIView()
    let parentView2 = UIView()
    let childLayer = CALayer()
    parentView1.layer.addSublayer(childLayer)

    let renderable = Renderable.layer(childLayer)

    // moving to a different parent should still call addSublayer.
    renderable.addToParent(parentView2)

    XCTAssertTrue(childLayer.superlayer === parentView2.layer)
    XCTAssertNil(parentView1.layer.sublayers)
    XCTAssertEqual(parentView2.layer.sublayers?.contains(childLayer), true)
  }

  func test_layer_case_removeFromParent() {
    let parentView = UIView()
    let childLayer = CALayer()
    parentView.layer.addSublayer(childLayer)
    let renderable = Renderable.layer(childLayer)

    renderable.removeFromParent()

    XCTAssertNil(childLayer.superlayer)
    XCTAssertNil(parentView.layer.sublayers)
  }

  func test_layer_case_moveToFront() {
    let parentView = UIView()
    let firstLayer = CALayer()
    let secondLayer = CALayer()
    let thirdLayer = CALayer()

    parentView.layer.addSublayer(firstLayer)
    parentView.layer.addSublayer(secondLayer)
    parentView.layer.addSublayer(thirdLayer)

    let renderable = Renderable.layer(firstLayer)
    renderable.moveToFront()

    // First layer should now be the last (front-most) sublayer
    XCTAssertTrue(parentView.layer.sublayers?.last === firstLayer)
  }
}
