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

@testable import ComposeUI

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

    // then: resizing applies the retained layer's geometry without animation
    try expect(layer1Context.unwrap().animationTiming) == nil
    expect(layer2Context) == nil

    // when: scrolling
    view.setContentOffset(CGPoint(x: 0, y: 4))
    view.layoutIfNeeded()

    // then: retained updates follow scrolling immediately, and insertion has no frame animation
    try expect(layer1Context.unwrap().animationTiming) == nil
    try expect(layer2Context.unwrap().animationTiming) == nil // no animation for insertion

    // when: animated refresh
    view.refresh(animated: true)

    // then: animation for refreshing
    try expect(layer1Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // animation for refreshing
    try expect(layer2Context.unwrap().animationTiming) == .easeInEaseOut(duration: 1) // animation for refreshing
  }

  func test_boundsChange_dynamicBehaviorAnimatesTransitionsAndRetainedFrames() throws {
    // given: a view explicitly allowing resize animations for its configured rows
    var layers: [Int: CALayer] = [:]
    var contexts: [Int: RenderableUpdateContext] = [:]
    let timing = AnimationTiming.linear(duration: 10)
    let view = ComposeView {
      VStack(spacing: 0) {
        for index in 0 ..< 3 {
          ColorNode(index == 0 ? .red : .blue)
            .frame(width: .flexible, height: 60)
            .animation(timing)
            .transition(.opacity(timing: timing))
            .onUpdate { renderable, context in
              layers[index] = renderable.layer
              contexts[index] = context
            }
        }
      }
    }
    view.renderablePool = nil
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    view.refresh(animated: false)
    let retainedLayer = try unwrap(layers[0])
    expect(retainedLayer.animationKeys()) == nil
    expect(layers[1]) == nil
    view.animationBehavior = .dynamic { _, _ in true }

    // when: resizing changes retained geometry and reveals another row
    view.frame.size = CGSize(width: 140, height: 100)
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the retained row animates its frame and the new row runs its insert transition
    let insertedLayer = try unwrap(layers[1])
    expect(layers[0]) === retainedLayer
    expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 140, height: 60)
    expect(retainedLayer.backgroundColor) == Color.red.cgColor
    expect(contexts[0]?.updateType) == .boundsChange
    expect(contexts[0]?.animationTiming) == timing
    let frameAnimation = try unwrap(retainedLayer.animation(forKey: "bounds.size") as? CABasicAnimation)
    expect(frameAnimation.fromValue as? CGSize) == CGSize(width: -40, height: 0)
    expect(frameAnimation.toValue as? CGSize) == .zero
    expect(frameAnimation.isAdditive) == true
    expect(frameAnimation.duration) == 10
    expect(insertedLayer.frame) == CGRect(x: 0, y: 60, width: 140, height: 60)
    expect(insertedLayer.backgroundColor) == Color.blue.cgColor
    expect(insertedLayer.opacity) == 1
    expect(contexts[1]?.updateType) == .insert
    expect(contexts[1]?.animationTiming) == nil
    let insertAnimation = try unwrap(insertedLayer.animation(forKey: "opacity") as? CABasicAnimation)
    expect(insertAnimation.fromValue as? Float) == -1
    expect(insertAnimation.toValue as? Float) == 0
    expect(insertAnimation.isAdditive) == true
    expect(insertAnimation.duration) == 10
    retainedLayer.removeAllAnimations()
    insertedLayer.removeAllAnimations()

    // when: shrinking the viewport removes that row
    view.frame.size.height = 50
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the row remains attached while its removal transition runs
    expect(insertedLayer.superlayer) != nil
    expect(insertedLayer.opacity) == 0
    let removeAnimation = try unwrap(insertedLayer.animation(forKey: "opacity") as? CABasicAnimation)
    expect(removeAnimation.fromValue as? Float) == 1
    expect(removeAnimation.toValue as? Float) == 0
    expect(removeAnimation.isAdditive) == true
    expect(removeAnimation.duration) == 10

    // when: growing the viewport revives the row before removal completes
    view.frame.size.height = 100
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the same row is revived with an insert transition and its target appearance
    expect(layers[1]) === insertedLayer
    expect(insertedLayer.superlayer) != nil
    expect(insertedLayer.opacity) == 1
    expect(insertedLayer.frame) == CGRect(x: 0, y: 60, width: 140, height: 60)
    expect(contexts[1]?.updateType) == .insert
    expect(contexts[1]?.animationTiming) == nil
    expect(insertedLayer.animation(forKey: "opacity")) != nil
    for layer in layers.values {
      layer.removeAllAnimations()
    }
  }

  func test_boundsChange_respectsAnimationBehaviorFromFirstRender() throws {
    let behaviors: [(ComposeView.AnimationBehavior, Bool, Bool)] = [
      (.default, true, false),
      (.disabled, false, false),
      (.dynamic { _, _ in false }, false, false),
      (.dynamic { _, _ in true }, true, true),
    ]
    for (behavior, allowsTransitions, allowsUpdates) in behaviors {
      // given: configured transitions and frame animations controlled by the view's animation behavior
      var layers: [Int: CALayer] = [:]
      var views: [Int: View] = [:]
      var contexts: [Int: RenderableUpdateContext] = [:]
      let timing = AnimationTiming.linear(duration: 10)
      let view = ComposeView {
        VStack(spacing: 0) {
          for index in 0 ..< 3 {
            ViewNode<BaseView>()
              .backgroundColor(.red)
              .frame(width: .flexible, height: 60)
              .animation(timing)
              .transition(.opacity(timing: timing))
              .onUpdate { renderable, context in
                layers[index] = renderable.layer
                views[index] = renderable.view
                contexts[index] = context
              }
          }
        }
      }
      view.animationBehavior = behavior
      view.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

      // when: the first bounds-driven pass renders the initial row
      view.setNeedsLayout()
      view.layoutIfNeeded()

      // then: first insertion honors the configured behavior without inventing a frame animation
      let first = try unwrap(layers[0])
      expect(contexts[0]?.previousRenderBounds) == nil
      expect(contexts[0]?.updateType) == .insert
      expect(contexts[0]?.animationTiming) == nil
      expect(first.animation(forKey: "opacity") != nil) == allowsTransitions
      expect(first.animation(forKey: "bounds.size")) == nil
      expect(first.frame) == CGRect(x: 0, y: 0, width: 100, height: 60)
      expect(first.backgroundColor) == Color.red.cgColor
      first.removeAllAnimations()

      // when: resizing changes the retained row and inserts another row
      view.frame.size = CGSize(width: 140, height: 100)
      view.setNeedsLayout()
      view.layoutIfNeeded()

      // then: the policy resolves insertion transitions independently from retained updates
      let second = try unwrap(layers[1])
      let secondView = try unwrap(views[1])
      expect(layers[0]) === first
      expect(first.frame) == CGRect(x: 0, y: 0, width: 140, height: 60)
      expect(contexts[0]?.animationTiming) == (allowsUpdates ? timing : nil)
      expect(first.animation(forKey: "bounds.size") != nil) == allowsUpdates
      expect(contexts[1]?.animationTiming) == nil
      expect(second.animation(forKey: "opacity") != nil) == allowsTransitions
      expect(second.frame) == CGRect(x: 0, y: 60, width: 140, height: 60)
      first.removeAllAnimations()
      second.removeAllAnimations()

      // when: shrinking removes the second row
      view.frame.size.height = 50
      view.setNeedsLayout()
      view.layoutIfNeeded()

      // then: removal obeys the transition decision
      expect(secondView.superview != nil) == allowsTransitions
      expect(second.animation(forKey: "opacity") != nil) == allowsTransitions
      expect(second.opacity) == (allowsTransitions ? 0 : 1)
      for layer in layers.values {
        layer.removeAllAnimations()
      }
    }
  }

  func test_boundsChange_withoutConfiguredAnimations_updatesImmediately() throws {
    // given: rows without animation timings or transitions
    var layers: [Int: CALayer] = [:]
    let view = ComposeView {
      VStack(spacing: 0) {
        for index in 0 ..< 3 {
          ColorNode(.red)
            .frame(width: .flexible, height: 60)
            .onUpdate { renderable, _ in
              layers[index] = renderable.layer
            }
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    view.setNeedsLayout()
    view.layoutIfNeeded()
    let first = try unwrap(layers[0])
    expect(first.animationKeys()) == nil

    // when: resizing updates one row and reveals another
    view.frame.size = CGSize(width: 140, height: 100)
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: both rows have their target appearance without animations
    let second = try unwrap(layers[1])
    expect(first.frame) == CGRect(x: 0, y: 0, width: 140, height: 60)
    expect(second.frame) == CGRect(x: 0, y: 60, width: 140, height: 60)
    expect(first.animationKeys()) == nil
    expect(second.animationKeys()) == nil
    expect(second.backgroundColor) == Color.red.cgColor

    // when: shrinking hides the second row
    view.frame.size.height = 50
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: removal is immediate because no transition is configured
    expect(second.superlayer) == nil
    expect(first.animationKeys()) == nil
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
      case .boundsChange(let previousBounds, let bounds):
        calledPreviousBounds = previousBounds
        return previousBounds?.size != bounds.size || bounds.minY != 4
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

  func test_animationBehavior_dynamic_decidesOncePerPass() throws {
    // given: rows with transitions and frame animations, and a dynamic behavior whose answer flips on every call
    var layers: [Int: CALayer] = [:]
    var contexts: [Int: RenderableUpdateContext] = [:]
    let timing = AnimationTiming.linear(duration: 10)
    let view = ComposeView {
      VStack(spacing: 0) {
        for index in 0 ..< 4 {
          ColorNode(.red)
            .frame(width: .flexible, height: 100)
            .animation(timing)
            .transition(.opacity(timing: timing))
            .onUpdate { renderable, context in
              layers[index] = renderable.layer
              contexts[index] = context
            }
        }
      }
    }
    view.renderablePool = nil
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
    view.refresh(animated: false)
    let firstRow = try unwrap(layers[0])
    let secondRow = try unwrap(layers[1])

    var callCount = 0
    view.animationBehavior = .dynamic { _, _ in
      callCount += 1
      return callCount % 2 == 1
    }

    // when: one scroll removes a row, retains a row, and reveals a row
    view.setContentOffset(CGPoint(x: 0, y: 100))
    view.layoutIfNeeded()

    // then: the behavior is asked once and its answer applies to the removal, the retained update, and the insertion
    let thirdRow = try unwrap(layers[2])
    expect(callCount) == 1
    expect(firstRow.superlayer) != nil
    expect(firstRow.opacity) == 0
    expect(firstRow.animation(forKey: "opacity")) != nil
    expect(layers[1]) === secondRow
    expect(contexts[1]?.updateType) == .boundsChange
    expect(contexts[1]?.animationTiming) == timing
    expect(contexts[2]?.updateType) == .insert
    expect(contexts[2]?.animationTiming) == nil
    expect(thirdRow.animation(forKey: "opacity")) != nil

    // when: the next scroll removes, retains, and reveals again
    view.setContentOffset(CGPoint(x: 0, y: 200))
    view.layoutIfNeeded()

    // then: the flipped answer applies to the whole pass, so nothing animates
    let fourthRow = try unwrap(layers[3])
    expect(callCount) == 2
    expect(secondRow.superlayer) == nil
    expect(layers[2]) === thirdRow
    expect(contexts[2]?.updateType) == .boundsChange
    expect(contexts[2]?.animationTiming) == nil
    expect(contexts[3]?.updateType) == .insert
    expect(contexts[3]?.animationTiming) == nil
    expect(fourthRow.animationKeys()) == nil
    for layer in layers.values {
      layer.removeAllAnimations()
    }
  }

  func test_animationDecision() {
    // given: refreshes and bounds changes with missing, equal, and changing geometry
    let view = ComposeView()
    let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
    let renderTypes: [ComposeView.RenderType] = [
      .refresh(isAnimated: true),
      .refresh(isAnimated: false),
      .boundsChange(previousBounds: nil, bounds: bounds),
      .boundsChange(previousBounds: nil, bounds: .zero),
      .boundsChange(previousBounds: bounds, bounds: bounds),
      .boundsChange(previousBounds: CGRect(x: 0, y: 20, width: 100, height: 100), bounds: bounds),
      .boundsChange(previousBounds: CGRect(x: 0, y: 0, width: 50, height: 100), bounds: bounds),
      .boundsChange(previousBounds: CGRect(x: 0, y: 20, width: 50, height: 100), bounds: bounds),
    ]
    let both = ComposeView.AnimationDecision(allowsTransitions: true, allowsAnimations: true)
    let neither = ComposeView.AnimationDecision(allowsTransitions: false, allowsAnimations: false)
    let transitionsOnly = ComposeView.AnimationDecision(allowsTransitions: true, allowsAnimations: false)

    // then: refresh controls both decisions, while all bounds changes allow only transitions
    expect(
      renderTypes.map { ComposeView.AnimationBehavior.default.animationDecision(renderType: $0, inheritedDecision: nil, contentView: view) }
    ) == [
      both, neither, transitionsOnly, transitionsOnly, transitionsOnly, transitionsOnly, transitionsOnly, transitionsOnly
    ]

    // then: disabled behavior permits neither animation type
    expect(
      renderTypes.map { ComposeView.AnimationBehavior.disabled.animationDecision(renderType: $0, inheritedDecision: nil, contentView: view) }
    ) == Array(repeating: neither, count: renderTypes.count)

    // when: dynamic behavior returns one answer for each pass
    for decision in [true, false] {
      var receivedViews: [ComposeView] = []
      var receivedRenderTypes: [ComposeView.RenderType] = []
      let behavior = ComposeView.AnimationBehavior.dynamic { contentView, renderType in
        receivedViews.append(contentView)
        receivedRenderTypes.append(renderType)
        return decision
      }
      let results = renderTypes.map { behavior.animationDecision(renderType: $0, inheritedDecision: nil, contentView: view) }

      // then: its single answer controls both decisions and each pass is queried once
      expect(results) == Array(repeating: decision ? both : neither, count: renderTypes.count)
      expect(receivedViews.count) == renderTypes.count
      for receivedView in receivedViews {
        expect(receivedView) === view
      }
      expect(receivedRenderTypes) == renderTypes
    }
  }

  func test_animationDecision_inheritsPreparedContentWithoutCollapsingTheDecisions() {
    // given: all possible inherited transition and update decisions
    let view = ComposeView()
    for transitions in [false, true] {
      for updates in [false, true] {
        let inherited = ComposeView.AnimationDecision(allowsTransitions: transitions, allowsAnimations: updates)
        for animated in [false, true] {
          let renderType = ComposeView.RenderType.refresh(isAnimated: animated)

          // then: the refresh flag gates each inherited decision independently
          expect(ComposeView.AnimationBehavior.default.animationDecision(renderType: renderType, inheritedDecision: inherited, contentView: view)) == ComposeView.AnimationDecision(allowsTransitions: animated && transitions, allowsAnimations: animated && updates)
          expect(ComposeView.AnimationBehavior.disabled.animationDecision(renderType: renderType, inheritedDecision: inherited, contentView: view)) == ComposeView.AnimationDecision(allowsTransitions: false, allowsAnimations: false)

          // then: a child's explicit dynamic behavior keeps its existing override semantics
          for decision in [false, true] {
            let behavior = ComposeView.AnimationBehavior.dynamic { _, _ in decision }
            expect(behavior.animationDecision(renderType: renderType, inheritedDecision: inherited, contentView: view)) == ComposeView.AnimationDecision(allowsTransitions: decision, allowsAnimations: decision)
          }
        }
      }
    }
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

    // then: the bounds reflect the scroll while the retained update stays immediate
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

    // the retained update does not animate
    try expect(calledContext.unwrap().animationTiming) == nil

    // when: scroll the view again, with the animation behavior set to dynamic so we can verify the render type
    var calledRenderType: ComposeView.RenderType?
    view.animationBehavior = .dynamic { _, renderType in
      calledRenderType = renderType
      return false
    }

    view.setContentOffset(CGPoint(x: 0, y: 20))
    view.layoutIfNeeded()

    // then: the render type should have correct previous bounds
    expect(calledRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 10, width: 120, height: 80), bounds: CGRect(x: 0, y: 20, width: 120, height: 80))

    // when: resize the view
    view.frame.size = CGSize(width: 140, height: 90)
    view.layoutIfNeeded()

    // then: the render type should have correct previous bounds
    expect(calledRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 20, width: 120, height: 80), bounds: CGRect(x: 0, y: 20, width: 140, height: 90))
  }
}
