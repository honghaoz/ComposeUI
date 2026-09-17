//
//  ComposeView+ReentrantRefreshTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/12/26.
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

class ComposeView_ReentrantRefreshTests: XCTestCase {

  func test_refresh_duringRenderPass_isDeferredUntilThePassCompletes() throws {

    enum Trigger: CaseIterable {
      case willLayout
      case willRender
      case itemWillUpdate
      case itemUpdate
    }

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    for trigger in Trigger.allCases {
      // given: a rendered view with a one-shot reentrant refresh armed on one of its render handlers
      var color = Color.red
      var contentMakeCount = 0
      var layer: CALayer?
      var isArmed = false
      var reentrantRefreshes = 0
      var view: ComposeView?
      let refreshFromCallback = {
        guard isArmed else {
          return
        }
        isArmed = false
        reentrantRefreshes += 1
        color = .blue
        view?.refresh(animated: false)
      }
      view = ComposeView {
        contentMakeCount += 1
        ColorNode(color)
          .frame(width: 40, height: 40)
          .willUpdate { _, _ in
            if trigger == .itemWillUpdate {
              refreshFromCallback()
            }
          }
          .onUpdate { renderable, _ in
            layer = renderable.layer
            if trigger == .itemUpdate {
              refreshFromCallback()
            }
          }
      }
      let composeView = try unwrap(view)
      composeView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      composeView.onWillLayout { _, _ in
        if trigger == .willLayout {
          refreshFromCallback()
        }
      }
      composeView.onWillRender { _, _ in
        if trigger == .willRender {
          refreshFromCallback()
        }
      }
      composeView.refresh(animated: false)
      let originalLayer = try unwrap(layer)
      assertionMessages = []
      isArmed = true

      // when: a refresh runs while the callback refreshes the view again from inside the pass
      composeView.refresh(animated: false)

      // then: the pass completes with the content it started with, without a nested pass
      expect(assertionMessages) == []
      expect(reentrantRefreshes) == 1
      expect(contentMakeCount) == 2
      expect(layer) === originalLayer
      expect(originalLayer.backgroundColor) == Color.red.cgColor
      expect(composeView.contentView().layer().sublayers?.count) == 1

      // when: the run loop performs the deferred refresh
      var isDrained = false
      RunLoop.main.perform { isDrained = true }
      expect(isDrained).toEventually(beTrue())

      // then: the deferred refresh applies the new configuration to the same renderable
      expect(assertionMessages) == []
      expect(contentMakeCount) == 3
      expect(layer) === originalLayer
      expect(originalLayer.backgroundColor) == Color.blue.cgColor
      expect(composeView.contentView().layer().sublayers?.count) == 1
    }
  }

  func test_refresh_ofTheParent_duringANestedRenderPass_isDeferredUntilThePassCompletes() throws {
    // the will-render handler runs before the nested pass has its animation decision, the did-render handler after. the
    // parent is not nested in the nested view, so the refresh waits either way.
    enum Trigger: CaseIterable {
      case willRender
      case didRender
    }

    for trigger in Trigger.allCases {
      // given: a parent without animations and a nested view whose dynamic behavior always animates, with a render
      // handler that refreshes the parent with new content once
      let timing = AnimationTiming.linear(duration: 10)
      var color = Color.red
      var childView: ComposeView?
      var layer: CALayer?
      var layerContexts: [RenderableUpdateContext] = []
      var parentRenders = 0
      var refreshesParent = false
      let parent = ComposeView {
        ComposeViewNode {
          ColorNode(color)
            .frame(width: .flexible, height: 100)
            .animation(timing)
            .onUpdate { renderable, context in
              layer = renderable.layer
              layerContexts.append(context)
            }
        }
        .flexibleSize()
        .frame(width: .flexible, height: 100)
        .willInsert { renderable, _ in
          childView = renderable.view as? ComposeView
          childView?.renderablePool = nil
          childView?.animationBehavior = .dynamic { _, _ in true }
        }
      }
      parent.animationBehavior = .disabled
      parent.renderablePool = nil
      parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      parent.onDidRender { _, _ in
        parentRenders += 1
      }
      parent.refresh(animated: false)
      let child = try unwrap(childView)
      let row = try unwrap(layer)
      let refreshParent = {
        guard refreshesParent else {
          return
        }
        refreshesParent = false
        color = .blue
        parent.refresh(animated: false)
      }
      switch trigger {
      case .willRender:
        child.onWillRender { _, _ in refreshParent() }
      case .didRender:
        child.onDidRender { _, _ in refreshParent() }
      }
      refreshesParent = true
      layerContexts.removeAll()

      // when: the nested view refreshes on its own and its handler refreshes the parent
      child.refresh(animated: false)

      // then: the parent's refresh waits for the nested pass, which completes with the content it started with
      expect(parentRenders) == 1
      expect(row.backgroundColor) == Color.red.cgColor
      expect(layerContexts.count) == 1
      expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.all
      layerContexts.removeAll()
      row.removeAllAnimations()

      // when: the run loop performs the deferred refresh. the row's animations are read in the same run loop iteration,
      // since a layer outside a window keeps none past the transaction commit.
      var rowAnimationKeys: [String]?
      var isDrained = false
      RunLoop.main.perform {
        rowAnimationKeys = row.animationKeys()
        isDrained = true
      }
      expect(isDrained).toEventually(beTrue())

      // then: the parent's pass applies the new content to the nested view within the pass, capped by its decision
      expect(parentRenders) == 2
      expect(row.backgroundColor) == Color.blue.cgColor
      expect(rowAnimationKeys) == nil
      expect(layerContexts.count) == 1
      expect(layerContexts.first?.animationTiming) == nil
      expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.disabled

      // when: the nested view later refreshes on its own with a new width
      child.frame.size.width = 200
      child.refresh(animated: true)

      // then: nothing of the parent's pass remains, so the nested view's own behavior animates the row
      expect(row.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
      expect(row.animation(forKey: "bounds.size")) != nil
      row.removeAllAnimations()
    }
  }

  func test_layout_ofTheParent_duringANestedRenderPass_isDeferredUntilThePassCompletes() throws {
    // given: a parent without animations and a nested view whose dynamic behavior always animates, with a render
    // handler that resizes the parent and lays it out once, after the nested pass has its animation decision
    let timing = AnimationTiming.linear(duration: 10)
    var childView: ComposeView?
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var parentRenders = 0
    var resizesParent = false
    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }
    let parent = ComposeView {
      ComposeViewNode {
        ColorNode(.red)
          .frame(width: .flexible, height: 100)
          .animation(timing)
          .onUpdate { renderable, context in
            layer = renderable.layer
            layerContexts.append(context)
          }
      }
      .flexibleSize()
      .frame(width: .flexible, height: 100)
      .willInsert { renderable, _ in
        childView = renderable.view as? ComposeView
        childView?.renderablePool = nil
        childView?.animationBehavior = .dynamic { _, _ in true }
      }
    }
    parent.animationBehavior = .disabled
    parent.renderablePool = nil
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    parent.onDidRender { _, _ in
      parentRenders += 1
    }
    parent.refresh(animated: false)
    let child = try unwrap(childView)
    let row = try unwrap(layer)
    child.onDidRender { _, _ in
      guard resizesParent else {
        return
      }
      resizesParent = false
      parent.frame.size.width = 160
      parent.setNeedsLayout()
      parent.layoutIfNeeded()
    }
    resizesParent = true
    layerContexts.removeAll()

    // when: the nested view refreshes on its own and its handler lays the parent out
    child.refresh(animated: false)

    // then: the parent's layout waits for the nested pass, which completes at the size it started with
    expect(assertionMessages) == []
    expect(parentRenders) == 1
    expect(child.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    layerContexts.removeAll()
    row.removeAllAnimations()

    // when: the run loop performs the deferred layout. the row's animations are read in the same run loop iteration,
    // since a layer outside a window keeps none past the transaction commit.
    var rowAnimationKeys: [String]?
    var isDrained = false
    RunLoop.main.perform {
      rowAnimationKeys = row.animationKeys()
      isDrained = true
    }
    expect(isDrained).toEventually(beTrue())

    // then: the parent's pass resizes the nested view and lays it out within the pass, capped by its decision
    expect(parentRenders) == 2
    expect(child.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
    expect(rowAnimationKeys) == nil
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.updateType) == .boundsChange
    expect(layerContexts.first?.animationTiming) == nil
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.disabled

    // when: the nested view later refreshes on its own with a new width
    child.frame.size.width = 200
    child.refresh(animated: true)

    // then: nothing of the parent's pass remains, so the nested view's own behavior animates the row
    expect(row.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
    expect(row.animation(forKey: "bounds.size")) != nil
    row.removeAllAnimations()
  }

  func test_layout_ofTheRenderingView_duringItsRenderPass_hasNothingToDo() throws {
    // given: a rendered view with a render handler that lays the view out once
    var renderTypes: [ComposeView.RenderType] = []
    var laysOut = false
    let view = ComposeView {
      ColorNode(.red)
        .frame(width: 40, height: 40)
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.onDidRender { _, context in
      renderTypes.append(context.renderType)
    }
    view.onWillRender { view, _ in
      guard laysOut else {
        return
      }
      laysOut = false
      view.setNeedsLayout()
      view.layoutIfNeeded()
    }
    view.refresh(animated: false)
    renderTypes.removeAll()
    laysOut = true

    // when: the view refreshes and its handler lays it out from inside the pass
    view.refresh(animated: false)

    // then: the pass completes on its own, without a nested pass
    expect(renderTypes) == [.refresh(isAnimated: false)]

    // when: the run loop turns
    var isDrained = false
    RunLoop.main.perform { isDrained = true }
    expect(isDrained).toEventually(beTrue())

    // then: no pass was scheduled either, the bounds have not changed
    expect(renderTypes) == [.refresh(isAnimated: false)]
  }

  func test_refresh_ofAnUnrelatedView_duringARenderPass_isDeferredUntilThePassCompletes() throws {
    // given: two unrelated views, one with a render handler that refreshes the other with new content once, after the
    // pass has its animation decision
    var color = Color.red
    var layer: CALayer?
    var refreshesOther = false
    let other = ComposeView {
      ColorNode(color)
        .frame(width: 40, height: 40)
        .onUpdate { renderable, _ in
          layer = renderable.layer
        }
    }
    other.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    other.refresh(animated: false)
    let row = try unwrap(layer)
    let view = ComposeView {
      ColorNode(.red)
        .frame(width: 40, height: 40)
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.onDidRender { _, _ in
      guard refreshesOther else {
        return
      }
      refreshesOther = false
      color = .blue
      other.refresh(animated: false)
    }
    refreshesOther = true

    // when: the view refreshes and its handler refreshes the other view
    view.refresh(animated: false)

    // then: the other view's refresh waits for the pass
    expect(row.backgroundColor) == Color.red.cgColor

    // when: the run loop performs the deferred refresh
    var isDrained = false
    RunLoop.main.perform { isDrained = true }
    expect(isDrained).toEventually(beTrue())

    // then: the other view shows the new content
    expect(row.backgroundColor) == Color.blue.cgColor
  }

  func test_refresh_ofANestedView_duringTheParentRenderPass_runsWithinThePassCappedByItsDecision() throws {
    // given: a parent without animations and a nested view whose dynamic behavior always animates, with a parent render
    // handler that resizes and refreshes the nested view once after the parent updated its renderables
    let timing = AnimationTiming.linear(duration: 10)
    var childView: ComposeView?
    var childRenderTypes: [ComposeView.RenderType] = []
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var refreshesChild = false
    let parent = ComposeView {
      ComposeViewNode {
        ColorNode(.red)
          .frame(width: .flexible, height: 100)
          .animation(timing)
          .onUpdate { renderable, context in
            layer = renderable.layer
            layerContexts.append(context)
          }
      }
      .flexibleSize()
      .frame(width: .flexible, height: 100)
      .willInsert { renderable, _ in
        childView = renderable.view as? ComposeView
        childView?.renderablePool = nil
        childView?.animationBehavior = .dynamic { _, _ in true }
        childView?.onDidRender { _, context in
          childRenderTypes.append(context.renderType)
        }
      }
    }
    parent.animationBehavior = .disabled
    parent.renderablePool = nil
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    parent.refresh(animated: false)
    let child = try unwrap(childView)
    let row = try unwrap(layer)
    parent.onDidRender { _, _ in
      guard refreshesChild else {
        return
      }
      refreshesChild = false
      child.frame.size.width = 200
      child.refresh(animated: true)
    }
    refreshesChild = true
    childRenderTypes.removeAll()
    layerContexts.removeAll()

    // when: the parent refreshes and its handler resizes and refreshes the nested view
    parent.refresh(animated: false)

    // then: the nested view rendered the parent's prepared content and then its handler's refresh, both within the
    // parent's pass and capped by the parent's decision, so the animated refresh does not animate the row's new width
    expect(childRenderTypes) == [.refresh(isAnimated: false), .refresh(isAnimated: true)]
    expect(row.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
    expect(row.animationKeys()) == nil
    expect(layerContexts.count) == 2
    expect(layerContexts.last?.animationTiming) == nil
    expect(layerContexts.last?.animationDecision) == ComposeView.AnimationDecision.disabled
  }

  func test_refresh_ofANestedView_fromTheParentWillRenderHandler_isDeferredUntilThePassCompletes() throws {
    // given: a parent without animations hosting a view whose dynamic behavior always animates, with a parent render
    // handler that refreshes the hosted view with a new width once before the parent has its animation decision
    let timing = AnimationTiming.linear(duration: 10)
    var width: CGFloat = 40
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var childRenderTypes: [ComposeView.RenderType] = []
    var refreshesChild = false
    let child = ComposeView {
      ColorNode(.red)
        .frame(width: width, height: 40)
        .animation(timing)
        .onUpdate { renderable, context in
          layer = renderable.layer
          layerContexts.append(context)
        }
    }
    child.renderablePool = nil
    child.animationBehavior = .dynamic { _, _ in true }
    child.onDidRender { _, context in
      childRenderTypes.append(context.renderType)
    }
    let parent = ComposeView {
      ViewNode<ComposeView>(child)
        .flexibleSize()
    }
    parent.animationBehavior = .disabled
    parent.renderablePool = nil
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    parent.onWillRender { _, _ in
      guard refreshesChild else {
        return
      }
      refreshesChild = false
      width = 80
      child.refresh(animated: true)
    }
    parent.refresh(animated: false)
    let row = try unwrap(layer)
    expect(row.frame.size) == CGSize(width: 40, height: 40)
    childRenderTypes.removeAll()
    layerContexts.removeAll()
    refreshesChild = true

    // when: the parent refreshes and its will-render handler refreshes the hosted view
    parent.refresh(animated: false)

    // then: the parent has no animation decision yet to cap a nested pass with, so the refresh waits for the pass
    expect(childRenderTypes) == []
    expect(row.frame.size) == CGSize(width: 40, height: 40)

    // when: the run loop performs the deferred refresh. the row's animations are read in the same run loop iteration,
    // since a layer outside a window keeps none past the transaction commit.
    var rowAnimationKeys: [String]?
    var isDrained = false
    RunLoop.main.perform {
      rowAnimationKeys = row.animationKeys()
      isDrained = true
    }
    expect(isDrained).toEventually(beTrue())

    // then: the hosted view renders on its own, under its own animation behavior
    expect(childRenderTypes) == [.refresh(isAnimated: true)]
    expect(row.frame.size) == CGSize(width: 80, height: 40)
    expect(rowAnimationKeys?.contains("bounds.size")) == true
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.animationTiming) == timing
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.all
    row.removeAllAnimations()
  }

  func test_refresh_ofAViewInsideAHostedContainer_duringTheParentRenderPass_runsWithinThePassCappedByItsDecision() throws {
    // given: a parent without animations hosting a plain container that contains a view whose dynamic behavior always
    // animates, with a parent render handler that refreshes the contained view with new content once
    let timing = AnimationTiming.linear(duration: 10)
    var color = Color.red
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var refreshesChild = false
    let child = ComposeView {
      ColorNode(color)
        .frame(width: 40, height: 40)
        .animation(timing)
        .onUpdate { renderable, context in
          layer = renderable.layer
          layerContexts.append(context)
        }
    }
    child.renderablePool = nil
    child.animationBehavior = .dynamic { _, _ in true }
    child.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let container = BaseView()
    container.addSubview(child)
    let parent = ComposeView {
      ViewNode<BaseView>(container)
        .frame(width: 100, height: 100)
    }
    parent.animationBehavior = .disabled
    parent.renderablePool = nil
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    parent.refresh(animated: false)
    child.refresh(animated: false)
    let row = try unwrap(layer)
    parent.onDidRender { _, _ in
      guard refreshesChild else {
        return
      }
      refreshesChild = false
      color = .blue
      child.refresh(animated: true)
    }
    refreshesChild = true
    layerContexts.removeAll()

    // when: the parent refreshes and its handler refreshes the contained view
    parent.refresh(animated: false)

    // then: the contained view is inside the parent, so its pass runs within the parent's pass, capped by its decision
    expect(row.backgroundColor) == Color.blue.cgColor
    expect(row.animationKeys()) == nil
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.animationTiming) == nil
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.disabled
  }

  func test_layoutContent_ofARenderingView_asserts_andRendersTheNewSizeOnTheNextLayout() throws {
    // given: a rendered view whose dynamic behavior always animates, with a render handler that resizes the view and
    // lays out its content as a parent's pass would, once
    let timing = AnimationTiming.linear(duration: 10)
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var renderTypes: [ComposeView.RenderType] = []
    var laysOutContent = false
    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }
    let view = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: 100)
        .animation(timing)
        .onUpdate { renderable, context in
          layer = renderable.layer
          layerContexts.append(context)
        }
    }
    view.renderablePool = nil
    view.animationBehavior = .dynamic { _, _ in true }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let row = try unwrap(layer)
    view.onDidRender { _, context in
      renderTypes.append(context.renderType)
    }
    view.onWillRender { view, _ in
      guard laysOutContent else {
        return
      }
      laysOutContent = false
      view.frame.size.width = 160
      view.layoutContent()
    }
    laysOutContent = true
    layerContexts.removeAll()

    // when: the view refreshes and its handler lays out its content from inside the pass
    view.refresh(animated: false)

    // then: the call asserts and the pass completes at the size it started with
    expect(assertionMessages) == ["A parent's render pass laid out a nested ComposeView that is rendering."]
    expect(renderTypes) == [.refresh(isAnimated: false)]
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    layerContexts.removeAll()
    row.removeAllAnimations()

    // when: the view lays out
    view.layoutIfNeeded()

    // then: the new size renders under the view's own animation behavior
    expect(renderTypes) == [
      .refresh(isAnimated: false),
      .boundsChange(previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100), bounds: CGRect(x: 0, y: 0, width: 160, height: 100)),
    ]
    expect(row.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
    expect(row.animation(forKey: "bounds.size")) != nil
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.animationTiming) == timing
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.all
    row.removeAllAnimations()
  }

  // MARK: - Render Passes Held by a `render()` Override

  func test_render_ofAnUnrelatedViewHeldByAnOverride_duringARenderPass_isDeferredUntilThePassCompletes() throws {
    // given: a view holding a prepared render pass with new content, and an unrelated view with a render handler that
    // runs the held pass once
    var color = Color.red
    var contentMakeCount = 0
    var layer: CALayer?
    var rendersHeldPass = false
    let other = RenderHoldingView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    other.setContent {
      contentMakeCount += 1
      return ColorNode(color)
        .frame(width: 40, height: 40)
        .onUpdate { renderable, _ in
          layer = renderable.layer
        }
    }
    other.refresh(animated: false)
    let row = try unwrap(layer)
    other.holdsRenderPass = true
    color = .blue
    other.refresh(animated: false)
    expect(contentMakeCount) == 2
    expect(row.backgroundColor) == Color.red.cgColor
    let view = ComposeView {
      ColorNode(.red)
        .frame(width: 40, height: 40)
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.onDidRender { _, _ in
      guard rendersHeldPass else {
        return
      }
      rendersHeldPass = false
      other.releaseRenderPass()
    }
    rendersHeldPass = true

    // when: the view refreshes and its handler runs the held pass
    view.refresh(animated: false)

    // then: the held pass waits for the view's pass
    expect(row.backgroundColor) == Color.red.cgColor

    // when: the run loop performs the deferred pass
    var isDrained = false
    RunLoop.main.perform { isDrained = true }
    expect(isDrained).toEventually(beTrue())

    // then: the held pass renders the content it was prepared with, without making it again
    expect(row.backgroundColor) == Color.blue.cgColor
    expect(contentMakeCount) == 2
  }

  func test_render_ofANestedViewHeldByAnOverride_duringTheParentRenderPass_isCappedByTheParentDecision() throws {
    // given: a parent without animations hosting a view whose dynamic behavior always animates, which holds a render
    // pass it prepared on its own with new content, and a parent render handler that runs the held pass once
    let timing = AnimationTiming.linear(duration: 10)
    var color = Color.red
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var rendersHeldPass = false
    let child = RenderHoldingView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    child.setContent {
      ColorNode(color)
        .frame(width: .flexible, height: 100)
        .animation(timing)
        .onUpdate { renderable, context in
          layer = renderable.layer
          layerContexts.append(context)
        }
    }
    child.renderablePool = nil
    child.animationBehavior = .dynamic { _, _ in true }
    let parent = ComposeView {
      ViewNode<ComposeView>(child)
        .flexibleSize()
    }
    parent.animationBehavior = .disabled
    parent.renderablePool = nil
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    parent.refresh(animated: false)
    let row = try unwrap(layer)
    child.holdsRenderPass = true
    color = .blue
    child.refresh(animated: true)
    expect(row.backgroundColor) == Color.red.cgColor
    parent.onDidRender { _, _ in
      guard rendersHeldPass else {
        return
      }
      rendersHeldPass = false
      child.releaseRenderPass()
    }
    rendersHeldPass = true
    layerContexts.removeAll()
    row.removeAllAnimations()

    // when: the parent refreshes and its handler runs the held pass
    parent.refresh(animated: false)

    // then: the held pass, prepared uncapped on its own, runs within the parent's pass and is capped by the parent's
    // decision, so the animated refresh does not animate the new color
    expect(row.backgroundColor) == Color.blue.cgColor
    expect(row.animationKeys()) == nil
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.updateType) == .refresh
    expect(layerContexts.first?.animationTiming) == nil
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.disabled
  }

  func test_render_ofTheParentHeldByAnOverride_duringANestedRenderPass_isDeferredUntilThePassCompletes() throws {
    // given: a parent without animations holding a render pass for a new width, with a nested view whose dynamic
    // behavior always animates and whose render handler runs the held pass once
    let timing = AnimationTiming.linear(duration: 10)
    var childView: ComposeView?
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var parentRenders = 0
    var rendersHeldPass = false
    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }
    let parent = RenderHoldingView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    parent.setContent {
      ComposeViewNode {
        ColorNode(.red)
          .frame(width: .flexible, height: 100)
          .animation(timing)
          .onUpdate { renderable, context in
            layer = renderable.layer
            layerContexts.append(context)
          }
      }
      .flexibleSize()
      .frame(width: .flexible, height: 100)
      .willInsert { renderable, _ in
        childView = renderable.view as? ComposeView
        childView?.renderablePool = nil
        childView?.animationBehavior = .dynamic { _, _ in true }
      }
    }
    parent.animationBehavior = .disabled
    parent.renderablePool = nil
    parent.onDidRender { _, _ in
      parentRenders += 1
    }
    parent.refresh(animated: false)
    let child = try unwrap(childView)
    let row = try unwrap(layer)
    parent.holdsRenderPass = true
    parent.frame.size.width = 160
    parent.setNeedsLayout()
    parent.layoutIfNeeded()
    expect(parentRenders) == 1
    expect(child.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    child.onDidRender { _, _ in
      guard rendersHeldPass else {
        return
      }
      rendersHeldPass = false
      parent.releaseRenderPass()
    }
    rendersHeldPass = true
    layerContexts.removeAll()

    // when: the nested view refreshes on its own and its handler runs the parent's held pass
    child.refresh(animated: false)

    // then: the held pass waits for the nested pass instead of resizing the nested view while it is rendering
    expect(assertionMessages) == []
    expect(parentRenders) == 1
    expect(child.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    layerContexts.removeAll()
    row.removeAllAnimations()

    // when: the run loop performs the deferred pass. the row's animations are read in the same run loop iteration,
    // since a layer outside a window keeps none past the transaction commit.
    var rowAnimationKeys: [String]?
    var isDrained = false
    RunLoop.main.perform {
      rowAnimationKeys = row.animationKeys()
      isDrained = true
    }
    expect(isDrained).toEventually(beTrue())

    // then: the parent's pass resizes the nested view and lays it out within the pass, capped by its decision
    expect(assertionMessages) == []
    expect(parentRenders) == 2
    expect(child.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
    expect(rowAnimationKeys) == nil
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.animationTiming) == nil
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.disabled
  }
}

/// A view whose `render()` override can hold a prepared render pass until released, as a subclass may.
private final class RenderHoldingView: ComposeView {

  /// Whether `render()` holds the prepared render pass instead of running it.
  var holdsRenderPass = false

  override func render() {
    if !holdsRenderPass {
      super.render()
    }
  }

  /// Stops holding and runs the held render pass.
  func releaseRenderPass() {
    holdsRenderPass = false
    render()
  }
}
