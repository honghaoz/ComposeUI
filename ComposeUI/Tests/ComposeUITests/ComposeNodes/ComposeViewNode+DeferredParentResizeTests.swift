//
//  ComposeViewNode+DeferredParentResizeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/16/26.
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

@_spi(Private) @testable import ComposeUI

class ComposeViewNode_DeferredParentResizeTests: XCTestCase {

  func test_parentResize_duringNestedRender_capsTheDeferredNestedLayout() throws {
    // given: a parent without animations and a nested view whose dynamic behavior always animates
    let timing = AnimationTiming.linear(duration: 10)
    var childView: ComposeView?
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var resizesParent = false
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
    parent.refresh(animated: false)
    let child = try unwrap(childView)
    let row = try unwrap(layer)
    child.onWillRender { _, _ in
      if resizesParent {
        resizesParent = false
        parent.frame.size.width = 160
        parent.setNeedsLayout()
        parent.layoutIfNeeded()
      }
    }
    resizesParent = true

    // when: the nested view's own refresh resizes the parent from a render handler, so the parent resizes the nested
    // view while it is rendering
    child.refresh(animated: false)

    // then: the active pass completes at the old size and leaves the new size to a later layout
    expect(child.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    row.removeAllAnimations()
    layerContexts.removeAll()

    // when: the nested view lays out for its new size
    child.setNeedsLayout()
    child.layoutIfNeeded()

    // then: the deferred layout is still capped by the parent's decision, so the row snaps to the new width
    expect(row.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
    expect(row.animationKeys()) == nil
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.updateType) == .boundsChange
    expect(layerContexts.first?.animationTiming) == nil
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.disabled

    // when: the nested view later refreshes on its own with a new width
    child.frame.size.width = 200
    child.refresh(animated: true)

    // then: the deferred layout ended the cap, so the nested view's own behavior animates the row again
    expect(row.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
    expect(row.animation(forKey: "bounds.size")) != nil
    row.removeAllAnimations()
  }

  func test_parentResize_duringNestedRender_andAgainDuringTheDeferredLayout_capsBothDeferredLayouts() throws {
    // given: a parent without animations and a nested view whose dynamic behavior always animates, with a render
    // callback that resizes the parent on its next two renders
    let timing = AnimationTiming.linear(duration: 10)
    var childView: ComposeView?
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var parentWidths: [CGFloat] = []
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
    parent.refresh(animated: false)
    let child = try unwrap(childView)
    let row = try unwrap(layer)
    child.onWillRender { _, _ in
      guard !parentWidths.isEmpty else {
        return
      }
      parent.frame.size.width = parentWidths.removeFirst()
      parent.setNeedsLayout()
      parent.layoutIfNeeded()
    }
    parentWidths = [160, 200]

    // when: the nested view's own refresh resizes the parent, so the parent resizes the nested view while it is rendering
    child.refresh(animated: false)
    row.removeAllAnimations()
    layerContexts.removeAll()

    // when: the deferred layout renders the first size, and its render handler resizes the parent again
    child.setNeedsLayout()
    child.layoutIfNeeded()

    // then: the deferred layout is capped, and the second resize is left to another layout
    expect(child.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
    expect(row.animationKeys()) == nil
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.animationTiming) == nil
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.disabled
    layerContexts.removeAll()

    // when: the nested view lays out for the second size
    child.setNeedsLayout()
    child.layoutIfNeeded()

    // then: the second deferred layout is capped as well, so the row snaps again
    expect(row.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
    expect(row.animationKeys()) == nil
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.animationTiming) == nil
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.disabled

    // when: the nested view later refreshes on its own with a new width
    child.frame.size.width = 240
    child.refresh(animated: true)

    // then: the cap ended with the last deferred layout, so the nested view's own behavior animates the row again
    expect(row.frame) == CGRect(x: 0, y: 0, width: 240, height: 100)
    expect(row.animation(forKey: "bounds.size")) != nil
    row.removeAllAnimations()
  }

  func test_parentResize_duringNestedRender_withAPendingNestedRefresh_capsTheDeferredRefresh() throws {
    // given: a parent without animations and a nested view whose dynamic behavior always animates, with a render
    // callback that requests an animated refresh and then resizes the parent
    let timing = AnimationTiming.linear(duration: 10)
    var childView: ComposeView?
    var childRenderTypes: [ComposeView.RenderType] = []
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var resizesParent = false
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
    childRenderTypes.removeAll()
    child.onWillRender { view, _ in
      if resizesParent {
        resizesParent = false
        view.setNeedsRefresh(animated: true)
        parent.frame.size.width = 160
        parent.setNeedsLayout()
        parent.layoutIfNeeded()
      }
    }
    resizesParent = true

    // when: the nested view's own refresh requests another refresh and resizes the parent, so the parent resizes the
    // nested view while it is rendering with a refresh pending
    child.refresh(animated: false)

    // then: the active pass completes at the old size, and the pending refresh could not run within the parent's render pass
    expect(child.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(childRenderTypes) == [.refresh(isAnimated: false)]
    row.removeAllAnimations()
    childRenderTypes.removeAll()
    layerContexts.removeAll()

    // when: the nested view lays out, which performs the pending refresh
    child.setNeedsLayout()
    child.layoutIfNeeded()

    // then: the refresh renders the new bounds capped by the parent's decision, so the row snaps although the refresh
    // was requested animated and the nested view's own behavior would animate it
    expect(childRenderTypes) == [.refresh(isAnimated: true)]
    expect(row.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
    expect(row.animationKeys()) == nil
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.updateType) == .refresh
    expect(layerContexts.first?.animationTiming) == nil
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.disabled

    // when: the nested view later refreshes on its own with a new width
    child.frame.size.width = 200
    child.refresh(animated: true)

    // then: the cap ended with the deferred refresh, so the nested view's own behavior animates the row again
    expect(row.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
    expect(row.animation(forKey: "bounds.size")) != nil
    row.removeAllAnimations()
  }

  func test_parentResize_duringNestedRender_completesWithADirectNestedRefresh() throws {
    // given: a parent without animations and a nested view whose dynamic behavior always animates, resized by the parent
    // while it was rendering, so the new bounds are left for the nested view's next layout
    let timing = AnimationTiming.linear(duration: 10)
    var childView: ComposeView?
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var resizesParent = false
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
    parent.refresh(animated: false)
    let child = try unwrap(childView)
    let row = try unwrap(layer)
    child.onWillRender { _, _ in
      if resizesParent {
        resizesParent = false
        parent.frame.size.width = 160
        parent.setNeedsLayout()
        parent.layoutIfNeeded()
      }
    }
    resizesParent = true
    child.refresh(animated: false)
    expect(child.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    row.removeAllAnimations()
    layerContexts.removeAll()

    // when: the nested view refreshes directly instead of laying out
    child.refresh(animated: true)

    // then: the refresh renders the new bounds capped by the parent's decision, so the row snaps
    expect(row.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
    expect(row.animationKeys()) == nil
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.updateType) == .refresh
    expect(layerContexts.first?.animationTiming) == nil
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.disabled

    // when: the nested view refreshes again on its own with a new width, before any layout
    child.frame.size.width = 180
    child.refresh(animated: true)

    // then: the direct refresh completed the parent's resize, so the nested view's own behavior animates the row again
    expect(row.frame) == CGRect(x: 0, y: 0, width: 180, height: 100)
    expect(row.animation(forKey: "bounds.size")) != nil
    row.removeAllAnimations()
  }

  func test_parentResize_duringNestedRender_toTheLastRenderedSize_capsTheDeferredNestedLayout() throws {
    // given: a parent without animations and a nested view whose dynamic behavior always animates, rendered 100 wide
    let timing = AnimationTiming.linear(duration: 10)
    var childView: ComposeView?
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var resizesParent = false
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
    parent.refresh(animated: false)
    let child = try unwrap(childView)
    let row = try unwrap(layer)
    child.onWillRender { _, _ in
      if resizesParent {
        resizesParent = false
        parent.frame.size.height = 150
        parent.setNeedsLayout()
        parent.layoutIfNeeded()
      }
    }
    resizesParent = true

    // when: the nested view lays out for a width it was given directly, and that pass resizes the parent from a render
    // callback, so the parent sets the nested view back to the size it last rendered while it is rendering
    child.frame.size.width = 120
    child.setNeedsLayout()
    child.layoutIfNeeded()

    // then: the active pass completes at the given width and leaves the size change to a later layout
    expect(child.frame) == CGRect(x: 0, y: 25, width: 100, height: 100)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 120, height: 100)
    row.removeAllAnimations()
    layerContexts.removeAll()

    // when: the nested view lays out for its size
    child.setNeedsLayout()
    child.layoutIfNeeded()

    // then: the deferred layout is still capped by the parent's decision, so the row snaps back
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(row.animationKeys()) == nil
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.updateType) == .boundsChange
    expect(layerContexts.first?.animationTiming) == nil
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.disabled
  }

  func test_parentResize_duringNestedRender_revertedBeforeThePassEnds_withAScrolledView_completesBeforeAnIndependentRefresh() throws {
    // given: a parent without animations and a scrolled nested view whose dynamic behavior always animates, with a
    // render handler that grows the parent and then puts it back, so the first resize clamps the scroll offset
    let timing = AnimationTiming.linear(duration: 10)
    var childView: ComposeView?
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var resizesParent = false
    let parent = ComposeView {
      ComposeViewNode {
        ColorNode(.red)
          .frame(width: .flexible, height: 400)
          .animation(timing)
          .onUpdate { renderable, context in
            layer = renderable.layer
            layerContexts.append(context)
          }
      }
      .flexibleSize()
      .willInsert { renderable, _ in
        childView = renderable.view as? ComposeView
        childView?.renderablePool = nil
        childView?.animationBehavior = .dynamic { _, _ in true }
      }
    }
    parent.animationBehavior = .disabled
    parent.renderablePool = nil
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    parent.refresh(animated: false)
    let child = try unwrap(childView)
    let row = try unwrap(layer)
    child.setContentOffset(CGPoint(x: 0, y: 290))
    child.layoutIfNeeded()
    expect(child.contentOffset()) == CGPoint(x: 0, y: 290)
    child.onWillRender { _, _ in
      guard resizesParent else {
        return
      }
      resizesParent = false
      for size in [CGSize(width: 140, height: 140), CGSize(width: 100, height: 100)] {
        parent.frame.size = size
        parent.setNeedsLayout()
        parent.layoutIfNeeded()
      }
    }
    resizesParent = true

    // when: the nested view's own refresh resizes the parent twice, ending at the size the pass renders
    child.refresh(animated: false)

    // then: the pass in progress renders the clamped offset at the original size, so nothing is left for a later layout
    expect(child.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(child.contentOffset()) == CGPoint(x: 0, y: 260)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 400)
    row.removeAllAnimations()
    layerContexts.removeAll()
    child.setNeedsLayout()
    child.layoutIfNeeded()
    expect(layerContexts.isEmpty) == true

    // when: the nested view refreshes on its own with a new width
    child.frame.size.width = 160
    child.refresh(animated: true)

    // then: no decision was left behind, so the nested view's own behavior animates the row
    expect(row.frame) == CGRect(x: 0, y: 0, width: 160, height: 400)
    expect(row.animation(forKey: "bounds.size")) != nil
    expect(layerContexts.last?.animationDecision) == ComposeView.AnimationDecision.all
    row.removeAllAnimations()
  }

  func test_parentResize_duringNestedRender_revertedBeforeThePassEnds_completesOnANoOpLayout() throws {
    // given: a child that always animates and a disabled parent, both rendered at width 100
    let timing = AnimationTiming.linear(duration: 10)
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    let child = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: 100)
        .animation(timing)
        .onUpdate { renderable, context in
          layer = renderable.layer
          layerContexts.append(context)
        }
    }
    child.renderablePool = nil
    child.animationBehavior = .dynamic { _, _ in true }
    child.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    child.refresh(animated: false)
    let parent = ComposeView {
      ViewNode<ComposeView>(child).flexibleSize()
    }
    parent.renderablePool = nil
    parent.animationBehavior = .disabled
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    parent.refresh(animated: false)
    let row = try unwrap(layer)
    var resizesParent = true
    var parentWidths: [CGFloat] = []
    child.onWillRender { _, _ in
      guard resizesParent else {
        return
      }
      resizesParent = false
      for width: CGFloat in [160, 100] {
        parent.frame.size.width = width
        parent.setNeedsLayout()
        parent.layoutIfNeeded()
        parentWidths.append(child.frame.width)
      }
    }
    defer {
      row.removeAllAnimations()
      child.layer().removeAllAnimations()
    }

    // when: two newer parent operations return to the bounds of the child's active render
    child.refresh(animated: false)

    // then: the completed render already matches the latest parent geometry
    expect(parentWidths) == [160, 100]
    expect(child.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(row.backgroundColor) == Color.red.cgColor
    row.removeAllAnimations()
    layerContexts.removeAll()

    // when: native layout finds no remaining geometry to render
    child.setNeedsLayout()
    child.layoutIfNeeded()

    // then: the no-op layout does not update or animate the row
    expect(layerContexts.isEmpty) == true
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(row.animationKeys()) == nil

    // when: the child later refreshes independently at a new width
    child.frame.size.width = 140
    child.refresh(animated: true)

    // then: the no-op layout completed the pending parent operation, so the child animates again
    expect(layer) === row
    expect(row.frame) == CGRect(x: 0, y: 0, width: 140, height: 100)
    expect(row.backgroundColor) == Color.red.cgColor
    expect(row.animation(forKey: "bounds.size")) != nil
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.updateType) == .refresh
    expect(layerContexts.first?.animationTiming) == timing
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.all
  }

  func test_parentResize_duringNestedRender_revertedBeforeThePassEnds_completesBeforeAnIndependentRefresh() throws {
    // given: a dynamic child whose content follows an external radius value
    var radius: CGFloat = 4
    var layer: CALayer?
    var context: RenderableUpdateContext?
    let child = ComposeView {
      LayerNode<CALayer>(update: { renderable, update in
        if let timing = update.animationTiming {
          renderable.animate(keyPath: "cornerRadius", to: radius, timing: timing)
        } else {
          renderable.disableActions { renderable.cornerRadius = radius }
        }
        layer = renderable
        context = update
      })
      .frame(width: .flexible, height: 100)
      .animation(.linear(duration: 10))
    }
    child.animationBehavior = .dynamic { _, _ in true }
    child.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    child.refresh(animated: false)
    let parent = ComposeView { ViewNode<ComposeView>(child).flexibleSize() }
    parent.animationBehavior = .disabled
    parent.frame = child.frame
    parent.refresh(animated: false)
    let row = try unwrap(layer)
    var resizesParent = true
    child.onWillRender { [weak parent] _, _ in
      guard let parent, resizesParent else {
        return
      }
      resizesParent = false
      for width: CGFloat in [160, 100] {
        parent.frame.size.width = width
        parent.setNeedsLayout()
        parent.layoutIfNeeded()
      }
    }
    defer { row.removeAllAnimations() }

    // when: the child finishes a pass at the final size selected by reentrant parent resizes
    child.refresh(animated: false)
    expect(child.frame.size) == CGSize(width: 100, height: 100)
    expect(row.frame.size) == CGSize(width: 100, height: 100)
    expect(row.cornerRadius) == 4
    row.removeAllAnimations()
    context = nil

    // when: a content-only refresh runs immediately, with no intervening native layout
    radius = 12
    child.refresh(animated: true)

    // then: the completed geometry no longer caps independent attribute animation
    expect(context?.animationDecision) == ComposeView.AnimationDecision.all
    expect(row.cornerRadius) == 12
    let animation = try unwrap(row.animation(forKey: "cornerRadius") as? CABasicAnimation)
    expect(animation.fromValue as? CGFloat) == -8
    expect(animation.toValue as? CGFloat) == 0
    expect(animation.isAdditive) == true
    expect(animation.duration) == 10
  }

  func test_parentResize_duringNestedRender_rendersTheDeferredBoundsOnTheNextRunLoop() throws {
    // given: a disabled parent will resize its child while the child is rendering
    var row: CALayer?
    var contexts: [RenderableUpdateContext] = []
    let child = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: 100)
        .animation(.linear(duration: 10))
        .onUpdate { renderable, context in
          row = renderable.layer
          contexts.append(context)
        }
    }
    child.animationBehavior = .dynamic { _, _ in true }
    child.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    child.refresh(animated: false)
    let parent = ComposeView { ViewNode<ComposeView>(child).flexibleSize() }
    parent.animationBehavior = .disabled
    parent.frame = child.frame
    parent.refresh(animated: false)
    let layer = try unwrap(row)
    var resizeOnce = true
    child.onWillRender { [weak parent] _, _ in
      guard let parent, resizeOnce else {
        return
      }
      resizeOnce = false
      parent.frame.size.width = 160
      parent.setNeedsLayout()
      parent.layoutIfNeeded()
    }
    defer { layer.removeAllAnimations() }

    // when: the callback leaves geometry pending after the current pass finishes
    child.refresh(animated: false)
    layer.removeAllAnimations()
    contexts.removeAll()
    expect(layer.frame.width) == 100

    // then: the next run-loop opportunity renders the size without an explicit child layout call
    expect(layer.frame.width).toEventually(beEqual(to: 160))
    expect(contexts.last?.animationDecision) == ComposeView.AnimationDecision.disabled
    expect(layer.animationKeys()) == nil

    // when: independent content is refreshed after deferred geometry is applied
    child.frame.size.width = 180
    child.refresh(animated: true)

    // then: the completed request no longer affects the child's policy
    expect(layer.frame.width) == 180
    expect(contexts.last?.animationDecision) == ComposeView.AnimationDecision.all
    expect(layer.animation(forKey: "bounds.size")) != nil
  }

  #if canImport(AppKit)
  func test_parentResize_duringNestedRender_revertedBeforeThePassEnds_withLegacyScrollers_completesBeforeAnIndependentRefresh() throws {
    // given: a parent without animations and a scrolled nested view with legacy scrollers, whose dynamic behavior always
    // animates, with a render handler that grows the parent and then puts it back. the nested view reads its bounds
    // while it renders, which toggles the legacy scrollers and lays the view out again.
    let timing = AnimationTiming.linear(duration: 10)
    var childView: ComposeView?
    var childRenderTypes: [ComposeView.RenderType] = []
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var resizesParent = false
    let parent = ComposeView {
      ComposeViewNode {
        ColorNode(.red)
          .frame(width: .flexible, height: 400)
          .animation(timing)
          .onUpdate { renderable, context in
            layer = renderable.layer
            layerContexts.append(context)
          }
      }
      .flexibleSize()
      .willInsert { renderable, _ in
        childView = renderable.view as? ComposeView
        childView?.renderablePool = nil
        childView?.animationBehavior = .dynamic { _, _ in true }
        childView?.scrollIndicatorBehavior = .always
        childView?.scrollerStyle = .legacy
        childView?.hasHorizontalScroller = true
        childView?.hasVerticalScroller = true
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
    child.setContentOffset(CGPoint(x: 0, y: 290))
    child.layoutIfNeeded()
    expect(child.contentOffset()) == CGPoint(x: 0, y: 290)
    childRenderTypes.removeAll()
    child.onWillRender { _, _ in
      guard resizesParent else {
        return
      }
      resizesParent = false
      for size in [CGSize(width: 140, height: 140), CGSize(width: 100, height: 100)] {
        parent.frame.size = size
        parent.setNeedsLayout()
        parent.layoutIfNeeded()
      }
    }
    resizesParent = true

    // when: the nested view's own refresh resizes the parent twice, ending at the size the pass renders
    child.refresh(animated: false)

    // then: the pass in progress is the only pass, and nothing is left for a later layout. the offset was clamped while
    // a bounds read had the scrollers hidden, so it matches the grown viewport without them.
    expect(child.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(child.contentOffset()) == CGPoint(x: 0, y: 260)
    expect(childRenderTypes) == [.refresh(isAnimated: false)]
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 400)
    row.removeAllAnimations()
    layerContexts.removeAll()
    child.setNeedsLayout()
    child.layoutIfNeeded()
    expect(layerContexts.isEmpty) == true

    // when: the nested view refreshes on its own with a new width
    child.frame.size.width = 160
    child.refresh(animated: true)

    // then: no decision was left behind, so the nested view's own behavior animates the row
    expect(row.frame) == CGRect(x: 0, y: 0, width: 160, height: 400)
    expect(row.animation(forKey: "bounds.size")) != nil
    expect(layerContexts.last?.animationDecision) == ComposeView.AnimationDecision.all
    row.removeAllAnimations()
  }
  #endif
}
