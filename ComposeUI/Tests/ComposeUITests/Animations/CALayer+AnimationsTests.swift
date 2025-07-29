//
//  CALayer+AnimationsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/25/22.
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

class CALayer_AnimationsTests: XCTestCase {

  func test_animationKey() {
    let layer = CALayer()
    layer.animate(
      key: "test",
      keyPath: "position",
      timing: .easeInEaseOut(duration: 1),
      from: { _ in CGPoint(x: 100, y: 100) },
      to: { _ in CGPoint(x: 200, y: 200) }
    )
    expect(layer.animationKeys()) == ["test"]
  }

  func test_setKeyPathValue_position() {
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    #if os(macOS)
    // layer-backed view
    do {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = view.layer()
      layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
      layer.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      view.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      expect(layer.position) == CGPoint(x: 150, y: 225)

      layer.setKeyPathValue("position", CGPoint(x: 180, y: 250)) // x: 30, y: 25
      expect(layer.frame) == CGRect(x: 130, y: 225, width: 100, height: 50)
      expect(view.frame) == layer.frame
    }

    // layer-hosted view
    do {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = CALayer()
      view.layer = CALayer()
      layer.delegate = view as? CALayerDelegate
      layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
      layer.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      view.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      expect(layer.position) == CGPoint(x: 150, y: 225)

      layer.setKeyPathValue("position", CGPoint(x: 180, y: 250)) // x: 30, y: 25
      expect(layer.frame) == CGRect(x: 130, y: 225, width: 100, height: 50)
      expect(view.frame) == layer.frame
    }
    #endif

    #if canImport(UIKit)
    let view = UIView(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    layer.setKeyPathValue("position", CGPoint(x: 10, y: 20))
    expect(layer.position) == CGPoint(x: 10, y: 20)
    #endif
  }

  func test_setKeyPathValue_bounds_size() {
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    #if os(macOS)
    // layer-backed view
    do {
      let view = View(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = view.layer()
      layer.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      view.frame = CGRect(x: 100, y: 200, width: 100, height: 50)
      expect(layer.bounds.size) == CGSize(width: 100, height: 50)

      layer.setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))
      expect(layer.bounds.size) == CGSize(width: 150, height: 80)
      expect(view.bounds.size) == layer.bounds.size
      expect(layer.frame) == CGRect(x: 100, y: 200, width: 150, height: 80)
      expect(view.frame) == layer.frame
    }

    // layer-hosted view
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

      layer.setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))
      expect(layer.bounds.size) == CGSize(width: 150, height: 80)
      expect(view.bounds.size) == layer.bounds.size
      expect(layer.frame) == CGRect(x: 100, y: 200, width: 150, height: 80)
      expect(view.frame) == layer.frame
    }
    #endif

    #if canImport(UIKit)
    let view = UIView(frame: CGRect(x: 100, y: 200, width: 100, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    expect(layer.bounds.size) == CGSize(width: 100, height: 50)

    layer.setKeyPathValue("bounds.size", CGSize(width: 150, height: 80))
    expect(layer.bounds.size) == CGSize(width: 150, height: 80)
    expect(view.bounds.size) == layer.bounds.size
    expect(view.frame) == CGRect(x: 75, y: 185, width: 150, height: 80)
    expect(view.frame) == layer.frame
    #endif
  }

  func test_setKeyPathValue_anchorPoint() {
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    // test layer's behavior by changing anchor point
    do {
      let layer = CALayer()
      layer.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      expect(layer.anchorPoint) == CGPoint(x: 0.5, y: 0.5)

      layer.setKeyPathValue("anchorPoint", CGPoint(x: 0, y: 0))
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0) // anchor point doesn't change
      // frame should move to keep anchor point position in parent the same
      expect(layer.frame) == CGRect(x: 225, y: 175, width: 50, height: 50)
    }

    #if os(macOS)
    // layer-backed view
    do {
      let view = View(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = view.layer()
      layer.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      view.frame = CGRect(x: 200, y: 150, width: 50, height: 50)
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0) // default for macOS

      layer.setKeyPathValue("anchorPoint", CGPoint(x: 0.5, y: 0.5))
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0) // anchor point doesn't change
      // frame should move to keep anchor point position in parent the same
      expect(layer.frame) == CGRect(x: 175, y: 125, width: 50, height: 50)
      expect(view.frame) == layer.frame
    }

    // layer-hosted view
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

      layer.setKeyPathValue("anchorPoint", CGPoint(x: 0.5, y: 0.5))
      expect(layer.anchorPoint) == CGPoint(x: 0, y: 0) // anchor point doesn't change
      // frame should move to keep anchor point position in parent the same
      expect(layer.frame) == CGRect(x: 175, y: 125, width: 50, height: 50)
      expect(view.frame) == layer.frame
    }
    #endif

    #if canImport(UIKit)
    let view = UIView(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    expect(layer.anchorPoint) == CGPoint(x: 0.5, y: 0.5) // default for iOS

    layer.setKeyPathValue("anchorPoint", CGPoint(x: 0, y: 0))
    expect(layer.anchorPoint) == CGPoint(x: 0, y: 0)
    // Frame should move to keep anchor point position in parent the same
    expect(layer.frame) == CGRect(x: 225, y: 175, width: 50, height: 50)
    expect(view.frame) == layer.frame
    #endif
  }

  func test_setKeyPathValue_opacity() {
    let testWindow = TestWindow()
    let containerView = testWindow.contentView()

    #if os(macOS)
    // layer-backed view
    do {
      let view = View(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
      view.wantsLayer = true
      containerView.addSubview(view)
      let layer = view.layer()
      expect(layer.opacity) == 1.0
      expect(view.alpha) == 1.0

      layer.setKeyPathValue("opacity", Float(0.7))
      expect(layer.opacity) == 0.7
      expect(view.alpha) == CGFloat(layer.opacity) // view alpha should match layer opacity
    }

    // layer-hosted view
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

      layer.setKeyPathValue("opacity", Float(0.3))
      expect(layer.opacity) == 0.3
      expect(view.alpha) == CGFloat(layer.opacity) // view alpha should match layer opacity
    }
    #endif

    #if canImport(UIKit)
    let view = UIView(frame: CGRect(x: 200, y: 150, width: 50, height: 50))
    containerView.addSubview(view)
    let layer = view.layer
    expect(layer.opacity) == 1.0
    expect(view.alpha) == 1.0

    layer.setKeyPathValue("opacity", Float(0.8))
    expect(layer.opacity) == 0.8
    expect(view.alpha) == CGFloat(layer.opacity) // view alpha should match layer opacity
    #endif
  }

  func test_uniqueAnimationKey_noExistingAnimations() {
    let layer = CALayer()

    // given no animations exist
    // then should return original key
    expect(layer.uniqueAnimationKey(key: "opacity")) == "opacity"
  }

  func test_uniqueAnimationKey_withExistingAnimations() {
    let layer = CALayer()

    // given existing animations
    let animation = CABasicAnimation()
    layer.add(animation, forKey: "position")
    layer.add(animation, forKey: "position-1")

    // then should generate next available key
    expect(layer.uniqueAnimationKey(key: "position")) == "position-2"
  }

  func test_uniqueAnimationKey_withNonSequentialKeys() {
    let layer = CALayer()

    // given existing animations with non-sequential keys
    let animation = CABasicAnimation()
    layer.add(animation, forKey: "position")
    layer.add(animation, forKey: "position-2")

    // then should still use next sequential number
    expect(layer.uniqueAnimationKey(key: "position")) == "position-1"
  }
}
