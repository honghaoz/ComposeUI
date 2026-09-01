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
    // given: a compose view with two animated layer nodes and update context tracking
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

    // when: initial refresh
    view.frame.size = CGSize(width: 100, height: 5)
    view.refresh()

    // then: no animation for insertion
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for insertion
    expect(layer2Context) == nil

    // when: resizing
    view.frame.size = CGSize(width: 100, height: 7)
    view.layoutIfNeeded()

    // then: no animation for resizing
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for resizing
    expect(layer2Context) == nil

    // when: scrolling
    view.setContentOffset(CGPoint(x: 0, y: 4))
    view.layoutIfNeeded()

    // then: animation for scrolling, no animation for the newly inserted layer
    try expect(layer1Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // animation for scrolling
    try expect(layer2Context.unwrap().animationTiming) == nil // no animation for insertion

    // when: animated refresh
    view.refresh(animated: true)

    // then: animation for refreshing
    try expect(layer1Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // animation for refreshing
    try expect(layer2Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // animation for refreshing
  }

  func test_animationBehavior_disabled() throws {
    // given: a compose view with two animated layer nodes and the animation behavior disabled
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

    // when: initial refresh
    view.frame.size = CGSize(width: 100, height: 5)
    view.refresh()

    // then: no animation for insertion
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for insertion
    expect(layer2Context) == nil

    // when: resizing
    view.frame.size = CGSize(width: 100, height: 7)
    view.layoutIfNeeded()

    // then: no animation for resizing
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for resizing
    expect(layer2Context) == nil

    // when: scrolling
    view.setContentOffset(CGPoint(x: 0, y: 4))
    view.layoutIfNeeded()

    // then: no animation for scrolling or insertion
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for scrolling
    try expect(layer2Context.unwrap().animationTiming) == nil // no animation for insertion

    // when: animated refresh
    view.refresh(animated: true)

    // then: no animation for refreshing
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for refreshing
    try expect(layer2Context.unwrap().animationTiming) == nil // no animation for refreshing
  }

  func test_animationBehavior_dynamic() throws {
    // given: a compose view with two animated layer nodes and a dynamic animation behavior that records its calls
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

    // when: initial refresh
    view.frame.size = CGSize(width: 100, height: 5)
    view.refresh()

    // then: no animation for insertion, the behavior is asked for the refresh
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for insertion
    expect(layer2Context) == nil

    expect(calledIsAnimated) == true
    expect(calledPreviousBounds) == nil
    calledIsAnimated = nil
    calledPreviousBounds = nil

    // when: resizing
    view.frame.size = CGSize(width: 100, height: 7)
    view.layoutIfNeeded()

    // then: has animation for resizing (the behavior returns true), the behavior receives the previous bounds
    try expect(layer1Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // has animation for resizing
    expect(layer2Context) == nil

    expect(calledIsAnimated) == nil
    expect(calledPreviousBounds) == CGRect(x: 0, y: 0, width: 100, height: 5)
    calledIsAnimated = nil
    calledPreviousBounds = nil

    // when: scrolling to the offset the behavior rejects
    view.setContentOffset(CGPoint(x: 0, y: 4))
    view.layoutIfNeeded()

    // then: no animation for scrolling or insertion, the behavior receives the previous bounds
    try expect(layer1Context.unwrap().animationTiming) == nil // no animation for scrolling
    try expect(layer2Context.unwrap().animationTiming) == nil // no animation for insertion

    expect(calledIsAnimated) == nil
    expect(calledPreviousBounds) == CGRect(x: 0, y: 0, width: 100, height: 7)
    calledIsAnimated = nil
    calledPreviousBounds = nil

    // when: scrolling to an offset the behavior accepts
    view.setContentOffset(CGPoint(x: 0, y: 5))
    view.layoutIfNeeded()

    // then: has animation for scrolling, the behavior receives the previous bounds
    try expect(layer1Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // has animation for scrolling
    try expect(layer2Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // has animation for scrolling

    expect(calledIsAnimated) == nil
    expect(calledPreviousBounds) == CGRect(x: 0, y: 4, width: 100, height: 7)
    calledIsAnimated = nil
    calledPreviousBounds = nil

    // when: scrolling again
    view.setContentOffset(CGPoint(x: 0, y: 6))
    view.layoutIfNeeded()

    // then: has animation for scrolling, the behavior receives the previous bounds
    try expect(layer1Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // has animation for scrolling
    try expect(layer2Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // has animation for scrolling

    expect(calledIsAnimated) == nil
    expect(calledPreviousBounds) == CGRect(x: 0, y: 5, width: 100, height: 7)
    calledIsAnimated = nil
    calledPreviousBounds = nil

    // when: animated refresh
    view.refresh(animated: true)

    // then: no animation for refreshing (the behavior returns false for refreshes)
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
    view.scrollIndicatorBehavior = .auto
    // use legacy scrollers so the scroller thickness affects bounds().
    view.scrollerStyle = .legacy
    view.hasHorizontalScroller = true
    view.hasVerticalScroller = true
    #endif

    view.layoutIfNeeded()

    #if canImport(AppKit)
    // verify the scrollers does affect the bounds
    if #available(macOS 26.0, *) {
      expect(view.bounds()) == CGRect(x: 0, y: 0, width: 103, height: 63)
    } else {
      expect(view.bounds()) == CGRect(x: 0, y: 0, width: 105, height: 65)
    }
    #endif
    #if canImport(UIKit)
    expect(view.bounds()) == CGRect(x: 0, y: 0, width: 120, height: 80)
    #endif

    // with default animation behavior
    view.animationBehavior = .default

    // when: scroll the view
    view.setContentOffset(CGPoint(x: 0, y: 10))
    view.layoutIfNeeded()

    // then: the bounds reflect the scroll and the update is animated
    #if canImport(AppKit)
    // verify the scrollers does affect the bounds
    if #available(macOS 26.0, *) {
      expect(view.bounds()) == CGRect(x: 0, y: 10, width: 103, height: 63)
    } else {
      expect(view.bounds()) == CGRect(x: 0, y: 10, width: 105, height: 65)
    }
    #endif
    #if canImport(UIKit)
    expect(view.bounds()) == CGRect(x: 0, y: 10, width: 120, height: 80)
    #endif

    // the animated update verifies the underlying render bounds is correct
    try expect(calledContext.unwrap().animationTiming) != nil

    // when: scroll the view again, with the animation behavior set to dynamic so we can verify the render type
    var calledRenderType: ComposeView.RenderType?
    view.animationBehavior = .dynamic { _, renderType in
      calledRenderType = renderType
      return false
    }

    view.setContentOffset(CGPoint(x: 0, y: 20))
    view.layoutIfNeeded()

    // then: the render type should have correct previous bounds
    expect(calledRenderType) == .scroll(previousBounds: CGRect(x: 0, y: 10, width: 120, height: 80))

    // when: resize the view
    view.frame.size = CGSize(width: 140, height: 90)
    view.layoutIfNeeded()

    // then: the render type should have correct previous bounds
    expect(calledRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 20, width: 120, height: 80))
  }
}
