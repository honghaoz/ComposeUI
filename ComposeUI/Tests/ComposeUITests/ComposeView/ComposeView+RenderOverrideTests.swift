//
//  ComposeView+RenderOverrideTests.swift
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

@testable import ComposeUI

class ComposeView_RenderOverrideTests: XCTestCase {

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

  func test_render_heldByAnOverride_afterTheViewResized_rendersTheNewSizeAfterThePass() throws {
    // given: a view holding a render pass prepared with new content, then resized and laid out while holding it
    var color = Color.red
    var layer: CALayer?
    var renderTypes: [ComposeView.RenderType] = []
    let view = RenderHoldingView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      ColorNode(color)
        .frame(width: .flexible, height: 100)
        .onUpdate { renderable, _ in
          layer = renderable.layer
        }
    }
    view.refresh(animated: false)
    let row = try unwrap(layer)
    view.onDidRender { _, context in
      renderTypes.append(context.renderType)
    }
    view.holdsRenderPass = true
    color = .blue
    view.refresh(animated: false)
    view.frame.size.width = 160
    view.setNeedsLayout()
    view.layoutIfNeeded()
    expect(renderTypes) == []
    expect(row.backgroundColor) == Color.red.cgColor

    // when: the held pass is released
    view.releaseRenderPass()

    // then: the held pass renders its content for the bounds it was prepared with
    expect(renderTypes) == [.refresh(isAnimated: false)]
    expect(row.backgroundColor) == Color.blue.cgColor
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the run loop performs the follow-up layout
    var isDrained = false
    RunLoop.main.perform { isDrained = true }
    expect(isDrained).toEventually(beTrue())

    // then: the pass found the bounds changed when it ended, so the new size renders
    expect(renderTypes) == [
      .refresh(isAnimated: false),
      .boundsChange(previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100), bounds: CGRect(x: 0, y: 0, width: 160, height: 100)),
    ]
    expect(row.backgroundColor) == Color.blue.cgColor
    expect(row.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
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
