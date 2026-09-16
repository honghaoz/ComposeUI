//
//  ComposeViewNode+ParentResizeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/15/26.
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

class ComposeViewNode_ParentResizeTests: XCTestCase {

  func test_parentResize_laysOutNestedContentWithinTheParentPass_cappedByTheParentDecision_atEveryDepth() throws {
    for nestingDepth in 1 ... 3 {
      // given: nested views whose dynamic behavior always animates, showing a row that shrinks when the width grows
      let timing = AnimationTiming.linear(duration: 10)
      var nestedViews: [Int: ComposeView] = [:]
      var nestedContexts: [Int: RenderableUpdateContext] = [:]
      var renderTypes: [Int: ComposeView.RenderType] = [:]
      var layers: [Int: CALayer] = [:]
      var layerContexts: [Int: RenderableUpdateContext] = [:]
      let parent = ComposeView {
        var content: any ComposeNode = VStack(spacing: 0) {
          LayerNode<CALayer>(
            intrinsicSize: { proposedSize in
              CGSize(width: proposedSize.width, height: 220 - proposedSize.width)
            },
            update: { layer, context in
              let radius = context.newFrame.width / 10
              if let timing = context.animationTiming {
                layer.animate(keyPath: "cornerRadius", to: radius, timing: timing)
              } else {
                layer.disableActions(for: "cornerRadius") {
                  layer.cornerRadius = radius
                }
              }
            }
          )
          .fixedSize(width: false, height: true)
          .backgroundColor(.red)
          .animation(timing)
          .onUpdate { renderable, context in
            layers[0] = renderable.layer
            layerContexts[0] = context
          }
          ColorNode(.blue)
            .frame(width: .flexible, height: 40)
            .animation(timing)
            .transition(.opacity(timing: timing))
            .onUpdate { renderable, context in
              layers[1] = renderable.layer
              layerContexts[1] = context
            }
          Spacer(height: 100)
        }
        for level in 0 ..< nestingDepth {
          let childContent = content
          content = ComposeViewNode { childContent }
            .flexibleSize()
            .frame(width: .flexible, height: 100)
            .animation(timing)
            .willInsert { renderable, _ in
              let child = renderable.view as? ComposeView
              child?.renderablePool = nil
              child?.animationBehavior = .dynamic { _, _ in true }
              child?.onDidRender { _, context in
                renderTypes[level] = context.renderType
              }
            }
            .onUpdate { renderable, context in
              nestedViews[level] = renderable.view as? ComposeView
              nestedContexts[level] = context
            }
        }
        return VStack(spacing: 0) {
          content
          Spacer(height: 400)
        }
      }
      parent.renderablePool = nil
      parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      parent.refresh(animated: false)
      let originalViews = try (0 ..< nestingDepth).map { try unwrap(nestedViews[$0]) }
      let retainedLayer = try unwrap(layers[0])
      expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 100, height: 120)
      expect(retainedLayer.cornerRadius) == 10
      expect(layers[1]) == nil
      defer {
        for view in originalViews {
          view.layer().removeAllAnimations()
        }
        for layer in layers.values {
          layer.removeAllAnimations()
        }
      }
      layerContexts.removeAll()
      nestedContexts.removeAll()
      renderTypes.removeAll()

      // when: the parent resizes, without laying out the nested views on their own
      parent.frame.size.width = 160
      parent.setNeedsLayout()
      parent.layoutIfNeeded()

      // then: every nested view lays out for its new size within the parent's render pass, capped by the parent's
      // decision, so the reused row snaps while the newly visible row runs its insert transition
      let transitionsOnly = ComposeView.AnimationDecision.transitionsOnly
      for level in 0 ..< nestingDepth {
        let child = originalViews[level]
        expect(nestedViews[level]) === child
        expect(child.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
        expect(child.layer().animation(forKey: "bounds.size")) == nil
        expect(nestedContexts[level]?.updateType) == .boundsChange
        expect(nestedContexts[level]?.animationDecision) == transitionsOnly
        expect(renderTypes[level]) == .boundsChange(
          previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
          bounds: CGRect(x: 0, y: 0, width: 160, height: 100)
        )
      }
      expect(layers[0]) === retainedLayer
      expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 160, height: 60)
      expect(retainedLayer.cornerRadius) == 16
      expect(retainedLayer.animationKeys()) == nil
      expect(layerContexts[0]?.updateType) == .boundsChange
      expect(layerContexts[0]?.animationTiming) == nil
      expect(layerContexts[0]?.animationDecision) == transitionsOnly
      let insertedLayer = try unwrap(layers[1])
      expect(insertedLayer.frame) == CGRect(x: 0, y: 60, width: 160, height: 40)
      expect(insertedLayer.backgroundColor) == Color.blue.cgColor
      expect(insertedLayer.opacity) == 1
      expect(insertedLayer.animationKeys()) == ["opacity"]
      expect(layerContexts[1]?.updateType) == .insert
      expect(layerContexts[1]?.animationDecision) == transitionsOnly

      // when: the nested views lay out on their own afterwards
      layerContexts.removeAll()
      renderTypes.removeAll()
      for view in originalViews {
        view.setNeedsLayout()
        view.layoutIfNeeded()
      }

      // then: their bounds already match their render history, so no pass is repeated
      expect(renderTypes.isEmpty) == true
      expect(layerContexts.isEmpty) == true

      // when: the parent scrolls with the nested views still visible
      nestedContexts.removeAll()
      parent.setContentOffset(CGPoint(x: 0, y: 50))
      parent.layoutIfNeeded()

      // then: the parent's render pass updates the outermost nested view, whose size is unchanged, so neither its
      // content nor the views nested inside it are touched
      expect(nestedContexts.count) == 1
      expect(nestedContexts[nestingDepth - 1]?.updateType) == .boundsChange
      for level in 0 ..< nestingDepth {
        expect(originalViews[level].frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
      }
      expect(renderTypes.isEmpty) == true
      expect(layerContexts.isEmpty) == true
      expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 160, height: 60)
    }
  }

  func test_parentResize_disabledParentSuppressesNestedTransitions() throws {
    // given: a parent without animations and a nested view with the default behavior, hiding a row until the width grows
    let timing = AnimationTiming.linear(duration: 10)
    var childView: ComposeView?
    var childRenderType: ComposeView.RenderType?
    var layers: [Int: CALayer] = [:]
    var layerContexts: [Int: RenderableUpdateContext] = [:]
    let parent = ComposeView {
      VStack(spacing: 0) {
        ComposeViewNode {
          VStack(spacing: 0) {
            LayerNode<CALayer>(intrinsicSize: { proposedSize in
              CGSize(width: proposedSize.width, height: 220 - proposedSize.width)
            })
            .fixedSize(width: false, height: true)
            .backgroundColor(.red)
            .animation(timing)
            .onUpdate { renderable, context in
              layers[0] = renderable.layer
              layerContexts[0] = context
            }
            ColorNode(.blue)
              .frame(width: .flexible, height: 40)
              .animation(timing)
              .transition(.opacity(timing: timing))
              .onUpdate { renderable, context in
                layers[1] = renderable.layer
                layerContexts[1] = context
              }
            Spacer(height: 100)
          }
        }
        .flexibleSize()
        .frame(width: .flexible, height: 100)
        .willInsert { renderable, _ in
          childView = renderable.view as? ComposeView
          childView?.renderablePool = nil
          childView?.onDidRender { _, context in
            childRenderType = context.renderType
          }
        }
        Spacer(height: 400)
      }
    }
    parent.animationBehavior = .disabled
    parent.renderablePool = nil
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    parent.refresh(animated: false)
    let child = try unwrap(childView)
    let retainedLayer = try unwrap(layers[0])
    expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 100, height: 120)
    expect(layers[1]) == nil
    defer {
      for layer in layers.values {
        layer.removeAllAnimations()
      }
    }
    childRenderType = nil

    // when: the parent resizes and reveals the nested row
    parent.frame.size.width = 160
    parent.setNeedsLayout()
    parent.layoutIfNeeded()

    // then: the nested view lays out within the parent's render pass, and the parent's decision suppresses the row's
    // insert transition that the nested view's own behavior would have run
    expect(child.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
    expect(childRenderType) == .boundsChange(
      previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
      bounds: CGRect(x: 0, y: 0, width: 160, height: 100)
    )
    expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 160, height: 60)
    expect(retainedLayer.animationKeys()) == nil
    expect(layerContexts[0]?.animationDecision) == ComposeView.AnimationDecision.disabled
    let insertedLayer = try unwrap(layers[1])
    expect(insertedLayer.frame) == CGRect(x: 0, y: 60, width: 160, height: 40)
    expect(insertedLayer.backgroundColor) == Color.blue.cgColor
    expect(insertedLayer.opacity) == 1
    expect(insertedLayer.animationKeys()) == nil
    expect(layerContexts[1]?.updateType) == .insert
    expect(layerContexts[1]?.animationDecision) == ComposeView.AnimationDecision.disabled
  }

  func test_parentResize_capsTheNestedLayoutTriggeredByAScrollOffsetClamp() throws {
    // given: a parent without animations and a scrolled nested view whose dynamic behavior always animates
    let timing = AnimationTiming.linear(duration: 10)
    var childView: ComposeView?
    var childRenderTypes: [ComposeView.RenderType] = []
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
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
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 400)
    row.removeAllAnimations()
    childRenderTypes.removeAll()
    layerContexts.removeAll()

    // when: the parent grows, so the nested view's taller viewport clamps its scroll offset while its frame changes
    parent.frame.size = CGSize(width: 140, height: 140)
    parent.setNeedsLayout()
    parent.layoutIfNeeded()

    // then: the one layout rendering the new bounds is capped by the parent's decision, so the row snaps
    expect(child.frame) == CGRect(x: 0, y: 0, width: 140, height: 140)
    expect(child.contentOffset()) == CGPoint(x: 0, y: 260)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 140, height: 400)
    expect(row.animationKeys()) == nil
    expect(childRenderTypes) == [.boundsChange(
      previousBounds: CGRect(x: 0, y: 290, width: 100, height: 100),
      bounds: CGRect(x: 0, y: 260, width: 140, height: 140)
    )]
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.updateType) == .boundsChange
    expect(layerContexts.first?.animationTiming) == nil
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.disabled
  }

  func test_parentResize_capsAPendingNestedRefresh() throws {
    // given: a nested view whose dynamic behavior always animates, with an animated refresh scheduled by the parent's
    // layout so it is pending while the parent resizes the nested view
    let timing = AnimationTiming.linear(duration: 10)
    var childView: ComposeView?
    var childRenderTypes: [ComposeView.RenderType] = []
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var schedulesChildRefresh = false
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
    parent.renderablePool = nil
    parent.onWillLayout { _, _ in
      if schedulesChildRefresh {
        schedulesChildRefresh = false
        childView?.setNeedsRefresh(animated: true)
      }
    }
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    parent.refresh(animated: false)
    let child = try unwrap(childView)
    let row = try unwrap(layer)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    childRenderTypes.removeAll()
    layerContexts.removeAll()
    schedulesChildRefresh = true

    // when: the parent resizes while the nested view has a pending animated refresh
    parent.frame.size.width = 200
    parent.setNeedsLayout()
    parent.layoutIfNeeded()

    // then: the pending refresh renders the new bounds within the parent's render pass, capped by the parent's decision,
    // so the row snaps although the nested view's own behavior would animate it
    expect(child.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
    expect(childRenderTypes) == [.refresh(isAnimated: true)]
    expect(row.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
    expect(row.animationKeys()) == nil
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.updateType) == .refresh
    expect(layerContexts.first?.animationTiming) == nil
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.transitionsOnly

    // when: the nested view later refreshes on its own with a new width
    childRenderTypes.removeAll()
    child.frame.size.width = 240
    child.refresh(animated: true)

    // then: the cap was consumed, so the nested view's own behavior animates the row again
    expect(row.frame) == CGRect(x: 0, y: 0, width: 240, height: 100)
    expect(row.animation(forKey: "bounds.size")) != nil
    expect(childRenderTypes) == [.refresh(isAnimated: true)]
    row.removeAllAnimations()
  }

  func test_parentResize_dropsTheCapWhenTheNestedViewAlreadyRenderedTheNewBounds() throws {
    // given: a nested view whose dynamic behavior always animates, laid out on its own at the size the parent is about
    // to give it, then set back to its old frame without a layout
    let timing = AnimationTiming.linear(duration: 10)
    var childView: ComposeView?
    var childRenderTypes: [ComposeView.RenderType] = []
    var layer: CALayer?
    let parent = ComposeView {
      ComposeViewNode {
        ColorNode(.red)
          .frame(width: .flexible, height: 100)
          .animation(timing)
          .onUpdate { renderable, _ in
            layer = renderable.layer
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
    parent.renderablePool = nil
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    parent.refresh(animated: false)
    let child = try unwrap(childView)
    let row = try unwrap(layer)
    child.frame.size.width = 200
    child.setNeedsLayout()
    child.layoutIfNeeded()
    expect(row.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
    child.frame.size.width = 100
    row.removeAllAnimations()
    childRenderTypes.removeAll()

    // when: the parent resizes the nested view to the size it already rendered
    parent.frame.size.width = 200
    parent.setNeedsLayout()
    parent.layoutIfNeeded()

    // then: the nested view has nothing to render for the parent's render pass
    expect(child.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
    expect(childRenderTypes) == []
    expect(row.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
    expect(row.animationKeys()) == nil

    // when: the nested view later refreshes on its own with a new width
    child.frame.size.width = 240
    child.refresh(animated: true)

    // then: the unused cap was dropped with the parent's render pass, so the nested view's own behavior animates the row
    expect(row.frame) == CGRect(x: 0, y: 0, width: 240, height: 100)
    expect(row.animation(forKey: "bounds.size")) != nil
    expect(childRenderTypes) == [.refresh(isAnimated: true)]
    row.removeAllAnimations()
  }

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

  func test_parentResize_withAPendingNestedRefreshThatQueuesAnotherRefresh_completesWithThePendingRefresh() throws {
    // given: a parent without animations and a nested view whose dynamic behavior always animates, with an animated
    // refresh pending while the parent resizes it. the row applies a corner radius with the pass's animation timing, and
    // the nested view's render handler changes the radius and queues another refresh once.
    let timing = AnimationTiming.linear(duration: 10)
    var cornerRadius: CGFloat = 4
    var childView: ComposeView?
    var childRenderTypes: [ComposeView.RenderType] = []
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var schedulesChildRefresh = false
    var queuesChildRefresh = false
    let parent = ComposeView {
      ComposeViewNode {
        ColorNode(.red)
          .frame(width: .flexible, height: 100)
          .onUpdate { renderable, context in
            layer = renderable.layer
            layerContexts.append(context)
            if let animationTiming = context.animationTiming {
              renderable.layer.animate(keyPath: "cornerRadius", to: cornerRadius, timing: animationTiming)
            } else {
              renderable.layer.cornerRadius = cornerRadius
            }
          }
          .animation(timing)
      }
      .flexibleSize()
      .frame(width: .flexible, height: 100)
      .willInsert { renderable, _ in
        childView = renderable.view as? ComposeView
        childView?.renderablePool = nil
        childView?.animationBehavior = .dynamic { _, _ in true }
        childView?.onDidRender { view, context in
          childRenderTypes.append(context.renderType)
          if queuesChildRefresh {
            queuesChildRefresh = false
            cornerRadius = 12
            view.setNeedsRefresh(animated: true)
          }
        }
      }
    }
    parent.animationBehavior = .disabled
    parent.renderablePool = nil
    parent.onWillLayout { _, _ in
      if schedulesChildRefresh {
        schedulesChildRefresh = false
        childView?.setNeedsRefresh(animated: true)
      }
    }
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    parent.refresh(animated: false)
    let child = try unwrap(childView)
    let row = try unwrap(layer)
    expect(row.cornerRadius) == 4
    childRenderTypes.removeAll()
    layerContexts.removeAll()
    schedulesChildRefresh = true
    queuesChildRefresh = true

    // when: the parent resizes the nested view, whose pending refresh renders the new bounds and queues another refresh,
    // then the nested view lays out, which performs the queued refresh if the parent's layout has not already
    parent.frame.size.width = 200
    parent.setNeedsLayout()
    parent.layoutIfNeeded()
    child.setNeedsLayout()
    child.layoutIfNeeded()

    // then: the pending refresh is capped by the parent's decision and completes the resize, so the queued refresh
    // follows the nested view's own behavior and animates the new corner radius
    expect(child.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
    expect(childRenderTypes) == [.refresh(isAnimated: true), .refresh(isAnimated: true)]
    expect(layerContexts.count) == 2
    expect(layerContexts[0].animationTiming) == nil
    expect(layerContexts[0].animationDecision) == ComposeView.AnimationDecision.disabled
    expect(layerContexts[1].animationTiming) == timing
    expect(layerContexts[1].animationDecision) == ComposeView.AnimationDecision.all
    expect(row.cornerRadius) == 12
    expect(row.animation(forKey: "cornerRadius")) != nil
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

  func test_parentResize_capsTheNestedLayoutAfterAWillUpdateCallbackRenderedTheView() throws {
    for callbackRefreshes in [false, true] {
      // given: a parent without animations and a nested view whose dynamic behavior always animates, with a will-update
      // callback that lays the nested view out, or refreshes it, before the parent applies the new frame
      let timing = AnimationTiming.linear(duration: 10)
      var childView: ComposeView?
      var childRenderTypes: [ComposeView.RenderType] = []
      var layer: CALayer?
      var layerContexts: [RenderableUpdateContext] = []
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
        .willUpdate { _, context in
          switch context.updateType {
          case .boundsChange:
            if callbackRefreshes {
              childView?.refresh(animated: false)
            } else {
              childView?.setNeedsLayout()
              childView?.layoutIfNeeded()
            }
          case .insert,
               .refresh:
            break
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
      layerContexts.removeAll()

      // when: the parent resizes the nested view
      parent.frame.size.width = 160
      parent.setNeedsLayout()
      parent.layoutIfNeeded()

      // then: the callback's layout renders nothing since the frame is unchanged at that point, while its refresh renders
      // the old bounds capped. either way the layout for the new frame is still capped by the parent's decision, so the
      // row snaps
      expect(child.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
      let boundsChange = ComposeView.RenderType.boundsChange(
        previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
        bounds: CGRect(x: 0, y: 0, width: 160, height: 100)
      )
      expect(childRenderTypes) == (callbackRefreshes ? [.refresh(isAnimated: false), boundsChange] : [boundsChange])
      expect(row.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
      expect(row.animationKeys()) == nil
      expect(layerContexts.count) == (callbackRefreshes ? 2 : 1)
      for context in layerContexts {
        expect(context.animationTiming) == nil
        expect(context.animationDecision) == ComposeView.AnimationDecision.disabled
      }
    }
  }

  func test_parentRefresh_resizingAViewNodeHostedView_laysItOutWithinTheParentPass() throws {
    // given: a parent without animations hosting a rendered view through a view node, whose dynamic behavior always
    // animates
    let timing = AnimationTiming.linear(duration: 10)
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var childRenderTypes: [ComposeView.RenderType] = []
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
    child.onDidRender { _, context in
      childRenderTypes.append(context.renderType)
    }
    let parent = ComposeView {
      ViewNode<ComposeView>(child).flexibleSize()
    }
    parent.animationBehavior = .disabled
    parent.renderablePool = nil
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    parent.refresh(animated: false)
    let row = try unwrap(layer)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    row.removeAllAnimations()
    layerContexts.removeAll()
    childRenderTypes.removeAll()

    // when: a refresh of the parent, not a layout, gives the hosted view a new size
    parent.frame.size.width = 200
    parent.refresh(animated: false)

    // then: the hosted view lays out within the parent's pass, capped by the parent's decision, so the row follows the
    // new size at once and snaps
    expect(child.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
    expect(childRenderTypes) == [.boundsChange(previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100), bounds: CGRect(x: 0, y: 0, width: 200, height: 100))]
    expect(row.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
    expect(row.animationKeys()) == nil
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.animationTiming) == nil
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.disabled

    // when: the hosted view later refreshes on its own with a new width
    child.frame.size.width = 240
    child.refresh(animated: true)

    // then: the parent's pass is over, so the hosted view's own behavior animates the row again
    expect(row.frame) == CGRect(x: 0, y: 0, width: 240, height: 100)
    expect(row.animation(forKey: "bounds.size")) != nil
    row.removeAllAnimations()
  }

  func test_parentInsert_ofAViewNodeHostedView_rendersItWithinTheParentPass() throws {
    // given: a parent without animations whose content can host a view, not rendered yet, through a view node. the
    // hosted view's dynamic behavior always animates and its row has an insert transition.
    let timing = AnimationTiming.linear(duration: 10)
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var childRenderTypes: [ComposeView.RenderType] = []
    let child = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: 100)
        .transition(.opacity(timing: timing))
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
    var showsChild = false
    let parent = ComposeView {
      if showsChild {
        ViewNode<ComposeView>(child).flexibleSize()
      } else {
        Empty()
      }
    }
    parent.animationBehavior = .disabled
    parent.renderablePool = nil
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    parent.refresh(animated: false)
    expect(layer) == nil

    // when: a refresh of the parent inserts the hosted view
    showsChild = true
    parent.refresh(animated: false)

    // then: the hosted view renders within the parent's pass, capped by the parent's decision, so its content is there
    // at once and the row's insert transition does not run
    let row = try unwrap(layer)
    expect(child.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(childRenderTypes) == [.boundsChange(previousBounds: nil, bounds: CGRect(x: 0, y: 0, width: 100, height: 100))]
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(row.animationKeys()) == nil
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.updateType) == .insert
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

  func test_parentResize_directViewNodeHost_capsDynamicChildAndAllowsLaterIndependentRefresh() throws {
    // given: a direct view node hosts a child that always animates, while the parent disables animations
    let timing = AnimationTiming.linear(duration: 10)
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var childRenderTypes: [ComposeView.RenderType] = []
    var embeddedView: ComposeView?
    let child = ComposeView {
      LayerNode<CALayer>(update: { layer, context in
        let radius = context.newFrame.width / 10
        if let timing = context.animationTiming {
          layer.animate(keyPath: "cornerRadius", to: radius, timing: timing)
        } else {
          layer.disableActions(for: "cornerRadius") {
            layer.cornerRadius = radius
          }
        }
      })
      .frame(width: .flexible, height: 100)
      .backgroundColor(.red)
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
    child.onDidRender { _, context in
      childRenderTypes.append(context.renderType)
    }
    let parent = ComposeView {
      ViewNode<ComposeView>(child)
        .flexibleSize()
        .animation(timing)
        .onUpdate { renderable, _ in
          embeddedView = renderable.view as? ComposeView
        }
    }
    parent.animationBehavior = .disabled
    parent.renderablePool = nil
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    parent.refresh(animated: false)
    let row = try unwrap(layer)
    expect(embeddedView) === child
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(row.backgroundColor) == Color.red.cgColor
    expect(row.cornerRadius) == 10
    row.removeAllAnimations()
    child.layer().removeAllAnimations()
    childRenderTypes.removeAll()
    layerContexts.removeAll()
    defer {
      row.removeAllAnimations()
      child.layer().removeAllAnimations()
    }

    // when: only the parent resizes, without explicitly laying out or refreshing the child
    parent.frame.size.width = 160
    parent.setNeedsLayout()
    parent.layoutIfNeeded()

    // then: the renderer caps the direct host just like a compose-view node and updates the retained row synchronously
    expect(embeddedView) === child
    expect(layer) === row
    expect(child.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
    expect(child.layer().animationKeys()) == nil
    expect(childRenderTypes) == [.boundsChange(
      previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
      bounds: CGRect(x: 0, y: 0, width: 160, height: 100)
    )]
    expect(row.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
    expect(row.backgroundColor) == Color.red.cgColor
    expect(row.cornerRadius) == 16
    expect(row.animationKeys()) == nil
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.updateType) == .boundsChange
    expect(layerContexts.first?.animationTiming) == nil
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.disabled

    // when: the child independently refreshes at a new width
    childRenderTypes.removeAll()
    layerContexts.removeAll()
    child.frame.size.width = 200
    child.refresh(animated: true)

    // then: the parent's completed resize no longer caps the child's own geometry and attribute animations
    expect(embeddedView) === child
    expect(layer) === row
    expect(row.frame) == CGRect(x: 0, y: 0, width: 200, height: 100)
    expect(row.backgroundColor) == Color.red.cgColor
    expect(row.cornerRadius) == 20
    expect(row.animation(forKey: "bounds.size")) != nil
    expect(row.animation(forKey: "cornerRadius")) != nil
    expect(childRenderTypes) == [.refresh(isAnimated: true)]
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.animationTiming) == timing
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.all
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

  func test_parentResize_capsEveryNestedLayoutTheResizeTriggers_withLegacyScrollers() throws {
    // given: a parent without animations and a scrolled nested view with legacy scrollers, whose dynamic behavior always
    // animates. resizing the nested view lays it out several times: the frame change clamps the scroll offset, and the
    // scroller toggling of each layout changes the bounds again.
    let timing = AnimationTiming.linear(duration: 10)
    var childView: ComposeView?
    var childRenderTypes: [ComposeView.RenderType] = []
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
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
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 400)
    row.removeAllAnimations()
    childRenderTypes.removeAll()
    layerContexts.removeAll()

    // when: the parent grows
    parent.frame.size = CGSize(width: 140, height: 140)
    parent.setNeedsLayout()
    parent.layoutIfNeeded()

    // then: every layout the resize triggers is capped by the parent's decision, so the row snaps
    expect(child.frame) == CGRect(x: 0, y: 0, width: 140, height: 140)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 140, height: 400)
    expect(row.animationKeys()) == nil
    expect(childRenderTypes.count) > 1
    expect(childRenderTypes.count) == layerContexts.count
    for context in layerContexts {
      expect(context.updateType) == .boundsChange
      expect(context.animationTiming) == nil
      expect(context.animationDecision) == ComposeView.AnimationDecision.disabled
    }
  }
  #endif
}
