//
//  ComposeView+AnimationBehaviorTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 7/13/25.
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

class ComposeView_AnimationBehaviorTests: XCTestCase {

  func test_animationBehavior_default() throws {
    var layer1Context: RenderableUpdateContext?
    var layer2Context: RenderableUpdateContext?
    let view = ComposeView {
      LayerNode().frame(width: .flexible, height: 10)
        .animation(.easeInEaseOut(duration: 1))
        .onUpdate { renderable, context in
          layer1Context = context
        }
      LayerNode().frame(width: .flexible, height: 10)
        .animation(.easeInEaseOut(duration: 1))
        .onUpdate { renderable, context in
          layer2Context = context
        }
    }

    // initial refresh
    view.frame.size = CGSize(width: 100, height: 5)
    view.refresh()
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for insertion
    expect(layer2Context) == nil

    // resizing
    view.frame.size = CGSize(width: 100, height: 7)
    view.layoutIfNeeded()
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for resizing
    expect(layer2Context) == nil

    // scrolling
    view.setContentOffset(CGPoint(x: 0, y: 4))
    view.layoutIfNeeded()
    try expect(layer1Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // animation for scrolling
    try expect(layer2Context.unwrap().animationTiming) == nil // no animation for insertion

    view.refresh(animated: true)
    try expect(layer1Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // animation for refreshing
    try expect(layer2Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // animation for refreshing
  }

  func test_animationBehavior_disabled() throws {
    var layer1Context: RenderableUpdateContext?
    var layer2Context: RenderableUpdateContext?
    let view = ComposeView {
      LayerNode().frame(width: .flexible, height: 10)
        .animation(.easeInEaseOut(duration: 1))
        .onUpdate { renderable, context in
          layer1Context = context
        }
      LayerNode().frame(width: .flexible, height: 10)
        .animation(.easeInEaseOut(duration: 1))
        .onUpdate { renderable, context in
          layer2Context = context
        }
    }

    view.animationBehavior = .disabled

    // initial refresh
    view.frame.size = CGSize(width: 100, height: 5)
    view.refresh()
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for insertion
    expect(layer2Context) == nil

    // resizing
    view.frame.size = CGSize(width: 100, height: 7)
    view.layoutIfNeeded()
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for resizing
    expect(layer2Context) == nil

    // scrolling
    view.setContentOffset(CGPoint(x: 0, y: 4))
    view.layoutIfNeeded()
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for scrolling
    try expect(layer2Context.unwrap().animationTiming) == nil // no animation for insertion

    view.refresh(animated: true)
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for refreshing
    try expect(layer2Context.unwrap().animationTiming) == nil // no animation for refreshing
  }

  func test_animationBehavior_dynamic() throws {
    var layer1Context: RenderableUpdateContext?
    var layer2Context: RenderableUpdateContext?
    let view = ComposeView {
      LayerNode().frame(width: .flexible, height: 10)
        .animation(.easeInEaseOut(duration: 1))
        .onUpdate { renderable, context in
          layer1Context = context
        }
      LayerNode().frame(width: .flexible, height: 10)
        .animation(.easeInEaseOut(duration: 1))
        .onUpdate { renderable, context in
          layer2Context = context
        }
    }

    var calledIsAnimated: Bool?
    var calledPreviousBounds: CGRect?
    view.animationBehavior = .dynamic { contentView, renderType in
      switch renderType {
      case .refresh(let isAnimated):
        calledIsAnimated = isAnimated
        return false
      case .boundsChange(let previousBounds):
        calledPreviousBounds = previousBounds
        return true
      case .scroll(let previousBounds):
        calledPreviousBounds = previousBounds
        if contentView.contentOffset().y == 4 {
          return false
        } else if contentView.contentOffset().y == 5 {
          return true
        } else {
          return true
        }
      }
    }

    // initial refresh
    view.frame.size = CGSize(width: 100, height: 5)
    view.refresh()
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for insertion
    expect(layer2Context) == nil

    expect(calledIsAnimated) == true
    expect(calledPreviousBounds) == nil
    calledIsAnimated = nil
    calledPreviousBounds = nil

    // resizing
    view.frame.size = CGSize(width: 100, height: 7)
    view.layoutIfNeeded()
    try expect(layer1Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // has animation for resizing
    expect(layer2Context) == nil

    expect(calledIsAnimated) == nil
    expect(calledPreviousBounds) == CGRect(x: 0, y: 0, width: 100, height: 5)
    calledIsAnimated = nil
    calledPreviousBounds = nil

    // scrolling
    view.setContentOffset(CGPoint(x: 0, y: 4))
    view.layoutIfNeeded()
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for scrolling
    try expect(layer2Context.unwrap().animationTiming) == nil // no animation for insertion

    expect(calledIsAnimated) == nil
    expect(calledPreviousBounds) == CGRect(x: 0, y: 0, width: 100, height: 7)
    calledIsAnimated = nil
    calledPreviousBounds = nil

    view.setContentOffset(CGPoint(x: 0, y: 5))
    view.layoutIfNeeded()
    try expect(layer1Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // has animation for scrolling
    try expect(layer2Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // has animation for scrolling

    expect(calledIsAnimated) == nil
    expect(calledPreviousBounds) == CGRect(x: 0, y: 4, width: 100, height: 7)
    calledIsAnimated = nil
    calledPreviousBounds = nil

    view.setContentOffset(CGPoint(x: 0, y: 6))
    view.layoutIfNeeded()
    try expect(layer1Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // has animation for scrolling
    try expect(layer2Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // has animation for scrolling

    expect(calledIsAnimated) == nil
    expect(calledPreviousBounds) == CGRect(x: 0, y: 5, width: 100, height: 7)
    calledIsAnimated = nil
    calledPreviousBounds = nil

    view.refresh(animated: true)
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for refreshing
    try expect(layer2Context.unwrap().animationTiming) == nil // no animation for refreshing

    expect(calledIsAnimated) == true
    expect(calledPreviousBounds) == nil
  }

  func test_previousBounds_withAppKitScrollers() {
    // given: a compose view with a layer node that has an animation and an update hook to track the context
    var calledContext: RenderableUpdateContext?
    let view = ComposeView {
      LayerNode()
        .frame(width: 200, height: 200)
        .animation(.easeInEaseOut(duration: 1))
        .onUpdate { _, context in
          calledContext = context
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 120, height: 80)

    #if canImport(AppKit)
    // use legacy scrollers so the scroller thickness affects bounds().
    view.scrollerStyle = .legacy
    view.hasHorizontalScroller = true
    view.hasVerticalScroller = true
    #endif

    view.layoutIfNeeded()

    // verify the scrollers does affect the bounds
    expect(view.bounds()) == CGRect(x: 0, y: 0, width: 105, height: 65)

    // with default animation behavior
    view.animationBehavior = .default

    // when: scroll the view
    view.setContentOffset(CGPoint(x: 0, y: 10))
    view.layoutIfNeeded()

    // verify the scrollers does affect the bounds
    expect(view.bounds()) == CGRect(x: 0, y: 10, width: 105, height: 65)

    // expect the update should be animated, this verifies the underlying render bounds is correct
    try expect(calledContext.unwrap().animationTiming) != nil

    // then set the animation behavior to dynamic so we can verify the render type
    var calledRenderType: ComposeView.RenderType?
    view.animationBehavior = .dynamic { _, renderType in
      calledRenderType = renderType
      return false
    }

    // when: scroll the view again
    view.setContentOffset(CGPoint(x: 0, y: 20))
    view.layoutIfNeeded()

    // expect the render type should have correct previous bounds
    expect(calledRenderType) == .scroll(previousBounds: CGRect(x: 0, y: 10, width: 120, height: 80))

    // when: resize the view
    view.frame.size = CGSize(width: 140, height: 90)
    view.layoutIfNeeded()

    // expect the render type should have correct previous bounds
    expect(calledRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 20, width: 120, height: 80))
  }
}
