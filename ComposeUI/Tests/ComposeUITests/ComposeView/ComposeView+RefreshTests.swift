//
//  ComposeView+RefreshTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/3/25.
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
import ChouTi

class ComposeView_RefreshTests: XCTestCase {

  func test_refresh() {
    // given: a compose view with render, refresh and animation tracking
    var renderCount = 0
    var refreshCount = 0
    var isAnimated: Bool?
    let view = ComposeView {
      renderCount += 1
      LayerNode()
        .animation(.linear())
        .onUpdate { _, context in
          isAnimated = context.animationTiming != nil
          refreshCount += 1
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

    // when: the view is refreshed
    view.refresh()

    // then: one render is performed, not animated
    expect(renderCount) == 1
    expect(refreshCount) == 1
    expect(isAnimated) == false // initial render is always not animated
    isAnimated = nil

    // when: the view is refreshed again
    view.refresh()

    // then: another render is performed, animated
    expect(renderCount) == 2
    expect(refreshCount) == 2
    expect(isAnimated) == true
    isAnimated = nil

    // when: the view is refreshed without animation
    view.refresh(animated: false)

    // then: another render is performed, not animated
    expect(renderCount) == 3
    expect(refreshCount) == 3
    expect(isAnimated) == false
    isAnimated = nil

    // when: an animated refresh is requested
    view.setNeedsRefresh(animated: true)

    // then: no refresh is performed immediately
    expect(renderCount) == 3
    expect(refreshCount) == 3

    // when: a refresh is requested with the default animation
    view.setNeedsRefresh()

    // then: no refresh is performed immediately
    expect(renderCount) == 3
    expect(refreshCount) == 3

    // when: a non-animated refresh is requested
    view.setNeedsRefresh(animated: false)

    // then: no refresh is performed immediately
    expect(renderCount) == 3
    expect(refreshCount) == 3

    // then: one merged refresh is performed, not animated
    expect(renderCount).toEventually(beEqual(to: 4))
    expect(refreshCount) == 4
    expect(isAnimated) == false // a non-animated request pins the merged refresh to non-animated
  }

  func test_refresh_nonAnimated_continuesInFlightAnimations() throws {
    // given: a themed color row rendered in the light theme, then grown and recolored by an animated refresh
    var height: CGFloat = 40
    var layer: CALayer?
    let view = ComposeView {
      ColorNode(ThemedColor(light: .red, dark: .blue))
        .frame(width: .flexible, height: height)
        .animation(.linear(duration: 10))
        .onUpdate { renderable, _ in
          layer = renderable.layer
        }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.overrideTheme = .light
    view.refresh(animated: false)
    let renderable = try unwrap(layer)
    expect(renderable.backgroundColor) == Color.red.cgColor

    view.overrideTheme = .dark
    height = 200
    view.refresh(animated: true)
    expect(renderable.animationKeys()?.sorted()) == ["backgroundColor", "bounds.size", "position"]
    let sizeAnimation = try unwrap(renderable.animation(forKey: "bounds.size") as? CABasicAnimation)
    let positionAnimation = try unwrap(renderable.animation(forKey: "position") as? CABasicAnimation)

    // when: a non-animated refresh changes the height and the theme back while the animations are in flight
    view.overrideTheme = .light
    height = 120
    view.refresh(animated: false)

    // then: the model has the new frame and color
    expect(renderable.bounds.size) == CGSize(width: 100, height: 120)
    expect(renderable.backgroundColor) == Color.red.cgColor

    // then: the frame animations keep going and land on the new frame, and the color animation is retargeted to the
    // new color over its remaining time instead of finishing towards the dark one
    expect(renderable.animationKeys()?.sorted()) == ["backgroundColor", "bounds.size", "position"]
    let continuedSizeAnimation = try unwrap(renderable.animation(forKey: "bounds.size") as? CABasicAnimation)
    expect(continuedSizeAnimation.fromValue as? CGSize) == sizeAnimation.fromValue as? CGSize
    expect(continuedSizeAnimation.toValue as? CGSize) == .zero
    expect(continuedSizeAnimation.duration) == sizeAnimation.duration
    expect(continuedSizeAnimation.isAdditive) == true

    let continuedPositionAnimation = try unwrap(renderable.animation(forKey: "position") as? CABasicAnimation)
    expect(continuedPositionAnimation.fromValue as? CGPoint) == positionAnimation.fromValue as? CGPoint
    expect(continuedPositionAnimation.duration) == positionAnimation.duration

    let colorAnimation = try unwrap(renderable.animation(forKey: "backgroundColor") as? CABasicAnimation)
    expect(colorAnimation.duration) == 10
    expect(colorAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(colorAnimation.toValue as! CGColor) == Color.red.cgColor // swiftlint:disable:this force_cast
    renderable.removeAllAnimations()
  }

  func test_setNeedsRefresh_merging() {
    // given: a compose view that has done its initial render
    var renderCount = 0
    var isAnimated: Bool?
    let view = ComposeView {
      renderCount += 1
      LayerNode()
        .animation(.linear())
        .onUpdate { _, context in
          isAnimated = context.animationTiming != nil
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    view.refresh()
    expect(renderCount) == 1
    expect(isAnimated) == false // initial render is always not animated
    isAnimated = nil

    // when: a non-animated request is followed by an animated one in the same run loop window
    view.setNeedsRefresh(animated: false)
    view.setNeedsRefresh(animated: true)

    // then: one merged refresh is performed, non-animated
    // a layout pass performs the pending refresh synchronously, so the test does not depend on run loop timing
    view.setNeedsLayout()
    view.layoutIfNeeded()
    expect(renderCount) == 2
    expect(isAnimated) == false
    isAnimated = nil

    // when: an animated request is followed by a non-animated one in the same run loop window
    view.setNeedsRefresh(animated: true)
    view.setNeedsRefresh(animated: false)

    // then: one merged refresh is performed, non-animated
    view.setNeedsLayout()
    view.layoutIfNeeded()
    expect(renderCount) == 3
    expect(isAnimated) == false
    isAnimated = nil

    // when: all requests in the same run loop window are animated
    view.setNeedsRefresh(animated: true)
    view.setNeedsRefresh(animated: true)

    // then: one merged refresh is performed, animated
    view.setNeedsLayout()
    view.layoutIfNeeded()
    expect(renderCount) == 4
    expect(isAnimated) == true
  }

  func test_setNeedsRefresh() {
    // given: a compose view
    var renderCount = 0
    var refreshCount = 0
    var isAnimated: Bool?
    let view = ComposeView {
      renderCount += 1
      LayerNode()
        .animation(.linear())
        .onUpdate { _, context in
          isAnimated = context.animationTiming != nil
          refreshCount += 1
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

    // when: set needs refresh
    view.setNeedsRefresh()

    // then: expect a pending refresh is scheduled but the refresh is not performed immediately
    expect(DynamicLookup(view).property("pendingRefresh")) != nil
    expect(renderCount) == 0
    expect(refreshCount) == 0
    expect(isAnimated) == nil
    isAnimated = nil

    // wait for next run loop iteration
    wait(timeout: 1e-3)

    // then: expect the refresh is performed
    expect(DynamicLookup(view).property("pendingRefresh")) == nil
    expect(renderCount) == 1
    expect(refreshCount) == 1
    expect(isAnimated) == false
    isAnimated = nil

    // when: set needs refresh again
    view.setNeedsRefresh()

    expect(DynamicLookup(view).property("pendingRefresh")) != nil
    expect(renderCount) == 1
    expect(refreshCount) == 1
    expect(isAnimated) == nil
    isAnimated = nil

    // when: refresh the view
    view.refresh()

    // then: expect the refresh is performed and the pending refresh is cancelled
    expect(DynamicLookup(view).property("pendingRefresh")) == nil
    expect(renderCount) == 2
    expect(refreshCount) == 2
    expect(isAnimated) == true
  }

  func test_subview_order() {
    // verify that the subviews are in the correct order after a refresh.

    // given: a compose view showing three views in an horizontal stack
    let view1 = BaseView()
    let view2 = BaseView()
    let view3 = BaseView()

    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))

    contentView.setContent {
      HStack {
        ViewNode(view1, update: { _, _ in })
          .frame(width: 100, height: 100)
        ViewNode(view2, update: { _, _ in })
          .frame(width: 100, height: 100)
        ViewNode(view3, update: { _, _ in })
          .frame(width: 100, height: 100)
      }
    }

    // when: the view is refreshed
    contentView.refresh(animated: false)

    // then: the subviews are in the content order
    expect(contentView.contentView().subviews) == [view1, view2, view3]

    // when: the view is refreshed again
    contentView.refresh(animated: false)

    // then: the subviews keep the same order
    expect(contentView.contentView().subviews) == [view1, view2, view3]

    // when: the content changes the order of the views and the view is refreshed
    contentView.setContent {
      HStack {
        ViewNode(view3, update: { _, _ in })
          .frame(width: 100, height: 100)
        ViewNode(view2, update: { _, _ in })
          .frame(width: 100, height: 100)
      }
    }

    contentView.refresh(animated: false)

    // then: the subviews are in the new order
    expect(contentView.contentView().subviews) == [view3, view2]
  }
}
