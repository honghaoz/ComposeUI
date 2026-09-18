//
//  ComposeView+PreparedContentTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/8/26.
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
import SwiftUI

@testable import ComposeUI

class ComposeView_PreparedContentTests: XCTestCase {

  func test_preparedContent_appliesImmediatelyThenRefreshEvaluatesIndependently() throws {
    // given: intrinsic content measured by its parent before the child displays it
    var width: CGFloat = 80
    var providerCalls = 0
    var hostedView: MutableSwiftUIHostingView?
    var renderedRoot: ComposeView.LayoutCacheNode?
    var renderedEvaluation: ContentEvaluation?
    let evaluation = ContentEvaluation()
    var node = SwiftUIViewNode {
      providerCalls += 1
      return SwiftUI.Color.red.frame(width: width, height: 50)
    }
    .fixedSize()
    .onUpdate { renderable, _ in
      hostedView = renderable.view as? MutableSwiftUIHostingView
    }

    let proposal = CGSize(width: 200, height: 100)
    node.layout(containerSize: proposal, context: ComposeNodeLayoutContext(scaleFactor: 1, contentEvaluation: evaluation))

    let child = ComposeView()
    child.frame = CGRect(origin: .zero, size: proposal)
    child.debug { child, event in
      if case .renderWillBegin = event {
        renderedRoot = child.test.contentUpdateContext?.contentNode
        renderedEvaluation = child.test.contentUpdateContext?.contentEvaluation
      }
    }
    width = 140

    // when: the parent supplies the prepared content
    child.setPreparedContent(node, contentEvaluation: evaluation, animationDecision: ComposeView.AnimationDecision.disabled)

    // then: the supplied tree and evaluation render immediately without reevaluating the content
    let host = try unwrap(hostedView)
    var previousRoot = try unwrap(renderedRoot)
    var previousEvaluation = try unwrap(renderedEvaluation)
    expect(renderedEvaluation) === evaluation
    expect(host.bounds.size) == CGSize(width: 80, height: 50)
    expect(host.content.sizeThatFits(proposal)) == CGSize(width: 80, height: 50)
    expect(providerCalls) == 1

    for nextWidth in [CGFloat(160), 180] {
      // when: a later independent refresh requests updated content
      width = nextWidth
      child.refresh(animated: false)

      // then: each refresh replaces the root and evaluation without reinstalling the parent's evaluation
      expect(renderedRoot) !== previousRoot
      expect(renderedEvaluation) !== evaluation
      expect(renderedEvaluation) !== previousEvaluation
      expect(hostedView) === host
      expect(host.bounds.size) == CGSize(width: nextWidth, height: 50)
      expect(host.content.sizeThatFits(proposal)) == CGSize(width: nextWidth, height: 50)
      previousRoot = try unwrap(renderedRoot)
      previousEvaluation = try unwrap(renderedEvaluation)
    }
    expect(providerCalls) == 3
  }

  func test_preparedContent_withoutEvaluation_resolvesWhenAppliedThenRefreshReevaluates() throws {
    // given: lazy content without a parent-supplied evaluation
    var width: CGFloat = 80
    var providerCalls = 0
    var hostedView: MutableSwiftUIHostingView?
    var renderedRoot: ComposeView.LayoutCacheNode?
    var renderedEvaluation: ContentEvaluation?
    let child = ComposeView()
    let proposal = CGSize(width: 200, height: 100)
    child.frame = CGRect(origin: .zero, size: proposal)
    child.debug { child, event in
      if case .renderWillBegin = event {
        renderedRoot = child.test.contentUpdateContext?.contentNode
        renderedEvaluation = child.test.contentUpdateContext?.contentEvaluation
      }
    }
    let content = SwiftUIViewNode {
      providerCalls += 1
      return SwiftUI.Color.red.frame(width: width, height: 50)
    }
    .fixedSize()
    .onUpdate { renderable, _ in
      hostedView = renderable.view as? MutableSwiftUIHostingView
    }

    // when: the content is applied without an evaluation
    child.setPreparedContent(content, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)

    // then: a fresh evaluation resolves the content once with its current value and frame
    let host = try unwrap(hostedView)
    let firstRoot = try unwrap(renderedRoot)
    let firstEvaluation = try unwrap(renderedEvaluation)
    expect(host.bounds.size) == CGSize(width: 80, height: 50)
    expect(host.content.sizeThatFits(proposal)) == CGSize(width: 80, height: 50)
    expect(providerCalls) == 1

    // when: an independent refresh follows an external change
    width = 160
    child.refresh(animated: false)

    // then: the new evaluation updates the reused native view
    expect(renderedRoot) !== firstRoot
    expect(renderedEvaluation) !== firstEvaluation
    expect(hostedView) === host
    expect(host.bounds.size) == CGSize(width: 160, height: 50)
    expect(host.content.sizeThatFits(proposal)) == CGSize(width: 160, height: 50)
    expect(providerCalls) == 2
  }

  func test_consecutivePreparedContent_latestReplacesTreeAndEvaluationTogether() throws {
    // given: two complete parent-supplied updates
    var layer: CALayer?
    var renderedEvaluation: ContentEvaluation?
    let first = ColorNode(.red)
      .frame(width: .flexible, height: 40)
      .onUpdate { renderable, _ in layer = renderable.layer }
    let firstEvaluation = ContentEvaluation()
    let second = ColorNode(.blue)
      .frame(width: .flexible, height: 80)
      .onUpdate { renderable, _ in layer = renderable.layer }
    let secondEvaluation = ContentEvaluation()
    let child = ComposeView()
    child.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    child.debug { child, event in
      if case .renderWillBegin = event {
        renderedEvaluation = child.test.contentUpdateContext?.contentEvaluation
      }
    }

    // when: the first update is applied
    child.setPreparedContent(first, contentEvaluation: firstEvaluation, animationDecision: ComposeView.AnimationDecision.disabled)

    // then: the first content and evaluation determine the displayed configuration and frame
    let renderedLayer = try unwrap(layer)
    expect(renderedEvaluation) === firstEvaluation
    expect(renderedLayer.backgroundColor) == ComposeUI.Color.red.cgColor
    expect(renderedLayer.bounds.size) == CGSize(width: 100, height: 40)

    // when: the second update is applied
    child.setPreparedContent(second, contentEvaluation: secondEvaluation, animationDecision: ComposeView.AnimationDecision.disabled)

    // then: the reused layer shows the latest content and the evaluation is replaced with it
    expect(layer) === renderedLayer
    expect(renderedEvaluation) === secondEvaluation
    expect(renderedLayer.backgroundColor) == ComposeUI.Color.blue.cgColor
    expect(renderedLayer.bounds.size) == CGSize(width: 100, height: 80)
  }

  func test_measurement_usesSuppliedContentWithoutChangingPreparedRoot() throws {
    // given: a prepared root displaying flexible content at the child's size
    var renderedRoot: ComposeView.LayoutCacheNode?
    var renderedLayer: CALayer?
    let content = ColorNode(.red)
      .onUpdate { renderable, _ in
        renderedLayer = renderable.layer
      }
    let child = ComposeView()
    child.frame = CGRect(x: 0, y: 0, width: 100, height: 80)
    child.debug { child, event in
      if case .renderWillBegin = event {
        renderedRoot = child.test.contentUpdateContext?.contentNode
      }
    }
    child.setPreparedContent(content, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)
    let preparedRoot = try unwrap(renderedRoot)
    let layer = try unwrap(renderedLayer)
    let originalBounds = CGRect(x: 0, y: 0, width: 100, height: 80)

    // when: measurement uses a different proposal from the displayed view
    let measuredSize = child.sizeThatFits(CGSize(width: 200, height: 160))

    // then: measurement leaves the prepared root's size and displayed layer unchanged
    expect(measuredSize) == CGSize(width: 200, height: 160)
    expect(preparedRoot.size) == originalBounds.size
    expect(preparedRoot.renderableItems(in: originalBounds).first?.frame) == originalBounds
    expect(layer.frame) == originalBounds
    expect(layer.backgroundColor) == ComposeUI.Color.red.cgColor

    // when: a later refresh builds content for a resized child
    child.frame.size = CGSize(width: 150, height: 120)
    child.refresh(animated: false)

    // then: a new root renders the supplied content without mutating the old prepared root
    expect(renderedRoot) !== preparedRoot
    expect(renderedLayer) === layer
    expect(layer.frame) == CGRect(x: 0, y: 0, width: 150, height: 120)
    expect(layer.backgroundColor) == ComposeUI.Color.red.cgColor
    expect(preparedRoot.size) == originalBounds.size
    expect(preparedRoot.renderableItems(in: originalBounds).first?.frame) == originalBounds
  }

  func test_preparedContent_rendersOnceWithSuppliedAnimationAndCancelsPendingRequest() throws {
    for (pendingAnimated, suppliedAnimated) in [(false, true), (true, false)] {
      // given: a reused layer with an animated frame and a pending request with the opposite animation preference
      var layer: CALayer?
      var animationTiming: AnimationTiming?
      var renderCount = 0
      let child = ComposeView {
        ColorNode(.red)
          .frame(width: 40, height: 40)
          .animation(.linear())
          .onUpdate { renderable, _ in
            layer = renderable.layer
          }
      }
      child.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
      child.refresh(animated: false)
      let originalLayer = try unwrap(layer)
      let prepared = ColorNode(.blue)
        .frame(width: 80, height: 60)
        .animation(.linear())
        .onUpdate { renderable, context in
          layer = renderable.layer
          animationTiming = context.animationTiming
          renderCount += 1
        }
      child.setNeedsRefresh(animated: pendingAnimated)

      // when: the parent supplies prepared content with its own animation decision
      child.setPreparedContent(prepared, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision(allowsTransitions: suppliedAnimated, allowsAnimations: suppliedAnimated))

      // then: the content renders immediately with the supplied decision rather than the pending preference
      expect(layer) === originalLayer
      expect(layer?.backgroundColor) == ComposeUI.Color.blue.cgColor
      expect(layer?.bounds.size) == CGSize(width: 80, height: 60)
      expect(animationTiming) == (suppliedAnimated ? .linear() : nil)
      expect(renderCount) == 1

      // when: the run loop reaches the callback scheduled by the cancelled request
      var isDrained = false
      RunLoop.main.perform { isDrained = true }
      expect(isDrained).toEventually(beTrue())

      // then: the cancelled request does not render again
      expect(renderCount) == 1
    }
  }

  func test_preparedContent_goesThroughRefreshOverride() throws {
    for transitions in [false, true] {
      for updates in [false, true] {
        // given: a child subclass that participates in the refresh lifecycle
        let child = RefreshOverrideView()
        var layer: CALayer?
        var context: RenderableUpdateContext?
        let prepared = ColorNode(.blue)
          .transition(.opacity(timing: .linear(duration: 10)))
          .onUpdate { renderable, update in
            layer = renderable.layer
            context = update
          }
        let decision = ComposeView.AnimationDecision(allowsTransitions: transitions, allowsAnimations: updates)

        // when: prepared content is applied with one resolved decision
        child.setPreparedContent(prepared, contentEvaluation: nil, animationDecision: decision)

        // then: the refresh override receives permission for either animation type while rendering keeps both flags
        let renderable = try unwrap(layer)
        let update = try unwrap(context)
        expect(child.refreshCount) == 1
        expect(child.lastAnimated) == (transitions || updates)
        expect(update.animationDecision) == decision
        expect(update.animationTiming) == nil
        expect(renderable.backgroundColor) == ComposeUI.Color.blue.cgColor
        expect(renderable.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
        expect(renderable.animation(forKey: "opacity") != nil) == transitions
        renderable.removeAllAnimations()
      }
    }
  }

  func test_deferredPreparedContent_respectsCoalescedNonAnimatedRefresh() throws {
    for nonAnimatedFirst in [false, true] {
      for decision in [ComposeView.AnimationDecision.transitionsOnly, ComposeView.AnimationDecision(allowsTransitions: false, allowsAnimations: true)] {
        // given: a reused item and a prepared replacement requested during rendering
        let view = ComposeView()
        view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        var layers: [String: CALayer] = [:]
        var contexts: [String: RenderableUpdateContext] = [:]
        view.setContent {
          ColorNode(.red)
            .id("reused")
            .frame(width: 40, height: 40)
            .animation(.linear(duration: 10))
            .onUpdate { renderable, context in
              layers["reused"] = renderable.layer
              contexts["reused"] = context
            }
        }
        view.refresh(animated: false)
        let originalLayer = try unwrap(layers["reused"])
        let prepared = ZStack {
          ColorNode(.blue)
            .id("reused")
            .frame(width: 80, height: 60)
            .animation(.linear(duration: 10))
            .onUpdate { renderable, context in
              layers["reused"] = renderable.layer
              contexts["reused"] = context
            }
          ColorNode(.green)
            .id("inserted")
            .frame(width: 20, height: 20)
            .transition(.opacity(timing: .linear(duration: 10)))
            .onUpdate { renderable, context in
              layers["inserted"] = renderable.layer
              contexts["inserted"] = context
            }
        }
        var requestsPreparedContent = true
        view.onDidRender { contentView, _ in
          guard requestsPreparedContent else {
            return
          }
          requestsPreparedContent = false
          if nonAnimatedFirst {
            contentView.setNeedsRefresh(animated: false)
          }
          contentView.setPreparedContent(prepared, contentEvaluation: nil, animationDecision: decision)
          if !nonAnimatedFirst {
            contentView.setNeedsRefresh(animated: false)
          }
        }

        // when: the current pass queues the prepared decision and a non-animated request
        view.refresh(animated: false)

        // then: prepared content remains unapplied until the current pass finishes
        expect(originalLayer.backgroundColor) == ComposeUI.Color.red.cgColor
        expect(layers["inserted"]) == nil

        // when: the run loop applies the coalesced refresh
        expect(layers["inserted"] != nil).toEventually(beTrue())

        // then: non-animated dominates in either order without losing the prepared content
        let inserted = try unwrap(layers["inserted"])
        expect(layers["reused"]) === originalLayer
        expect(originalLayer.backgroundColor) == ComposeUI.Color.blue.cgColor
        expect(originalLayer.bounds.size) == CGSize(width: 80, height: 60)
        expect(originalLayer.animationKeys()) == nil
        expect(inserted.backgroundColor) == ComposeUI.Color.green.cgColor
        expect(inserted.bounds.size) == CGSize(width: 20, height: 20)
        expect(inserted.animationKeys()) == nil
        for context in contexts.values {
          expect(context.animationDecision) == ComposeView.AnimationDecision.disabled
          expect(context.animationTiming) == nil
        }
      }
    }
  }

  func test_refreshOverrideWithoutSuper_preservesPreparedStateUntilApplied() throws {
    // given: parent-measured content and a child that declines its refresh
    var width: CGFloat = 80
    var hostedView: MutableSwiftUIHostingView?
    var renderedRoot: ComposeView.LayoutCacheNode?
    var renderedEvaluation: ContentEvaluation?
    let evaluation = ContentEvaluation()
    var node = SwiftUIViewNode {
      SwiftUI.Color.blue.frame(width: width, height: 50)
    }
    .fixedSize()
    .onUpdate { renderable, _ in
      hostedView = renderable.view as? MutableSwiftUIHostingView
    }
    node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 1, contentEvaluation: evaluation))
    let child = RefreshOverrideView()
    child.callsSuper = false
    child.debug { child, event in
      if case .renderWillBegin = event {
        renderedRoot = child.test.contentUpdateContext?.contentNode
        renderedEvaluation = child.test.contentUpdateContext?.contentEvaluation
      }
    }

    // when: the override handles the prepared update without calling super
    child.setPreparedContent(node, contentEvaluation: evaluation, animationDecision: ComposeView.AnimationDecision.disabled)

    // then: the prepared content remains unapplied
    expect(child.refreshCount) == 1
    expect(hostedView) == nil
    expect(child.contentView().layer().sublayers?.isEmpty ?? true) == true

    // when: a later request allows the base implementation to render after external data changes
    width = 140
    child.callsSuper = true
    child.setNeedsRefresh(animated: false)

    // then: the child applies the original prepared evaluation rather than reevaluating its content
    expect(hostedView != nil).toEventually(beEqual(to: true))
    let host = try unwrap(hostedView)
    let preparedRoot = try unwrap(renderedRoot)
    expect(child.refreshCount) == 2
    expect(child.lastAnimated) == false
    expect(renderedEvaluation) === evaluation
    expect(host.bounds.size) == CGSize(width: 80, height: 50)
    expect(host.content.sizeThatFits(child.bounds().size)) == CGSize(width: 80, height: 50)

    // when: the child refreshes after consuming the prepared evaluation
    child.refresh(animated: false)

    // then: the independent refresh replaces the root and evaluation with the latest value
    expect(renderedRoot) !== preparedRoot
    expect(renderedEvaluation) !== evaluation
    expect(hostedView) === host
    expect(host.bounds.size) == CGSize(width: 140, height: 50)
    expect(host.content.sizeThatFits(child.bounds().size)) == CGSize(width: 140, height: 50)
  }

  func test_refreshOverride_appliesReplacementSuppliedAfterSuper() throws {
    // given: a child whose override supplies replacement content after its first render
    let child = RefreshOverrideView()
    var colors: [CGColor] = []
    let first = ColorNode(.red)
      .onUpdate { renderable, _ in
        if let color = renderable.layer.backgroundColor {
          colors.append(color)
        }
      }
    let second = ColorNode(.blue)
      .onUpdate { renderable, _ in
        if let color = renderable.layer.backgroundColor {
          colors.append(color)
        }
      }
    child.afterRefresh = { view in
      view.afterRefresh = nil
      view.setPreparedContent(second, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)
    }

    // when: the first prepared update triggers the override and its nested replacement
    child.setPreparedContent(first, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.all)

    // then: both updates render in order and the replacement uses its own animation decision
    expect(colors) == [ComposeUI.Color.red.cgColor, ComposeUI.Color.blue.cgColor]
    expect(child.refreshCount) == 2
    expect(child.lastAnimated) == false
    expect(child.contentView().layer().sublayers?.first?.backgroundColor) == ComposeUI.Color.blue.cgColor
  }

  func test_refreshOverride_replacementSuppliedBeforeSuper_supersedesOriginalContent() throws {
    // given: an override replacing the prepared content before calling the base refresh
    let child = RefreshOverrideView()
    var colors: [CGColor] = []
    let first = ColorNode(.red)
      .onUpdate { renderable, _ in
        if let color = renderable.layer.backgroundColor {
          colors.append(color)
        }
      }
    let second = ColorNode(.blue)
      .onUpdate { renderable, _ in
        if let color = renderable.layer.backgroundColor {
          colors.append(color)
        }
      }
    child.beforeRefresh = { view in
      view.beforeRefresh = nil
      view.setPreparedContent(second, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)
    }

    // when: the original prepared update is replaced from within its own refresh
    child.setPreparedContent(first, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)

    // then: the superseded content never renders and the replacement is displayed once
    expect(colors.isEmpty) == false
    expect(colors.contains(ComposeUI.Color.red.cgColor)) == false
    expect(child.refreshCount) == 2
    expect(child.contentView().layer().sublayers?.count) == 1
    expect(child.contentView().layer().sublayers?.first?.backgroundColor) == ComposeUI.Color.blue.cgColor
  }

  func test_refreshOverrideWithoutSuper_appliesReplacementSuppliedByOverride() throws {
    // given: an override that skips rendering once and supplies a replacement before returning
    let child = RefreshOverrideView()
    child.callsSuper = false
    child.afterRefresh = { view in
      view.afterRefresh = nil
      view.callsSuper = true
      view.setPreparedContent(ColorNode(.blue), contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)
    }

    // when: the initial override skips super and supplies the replacement
    child.setPreparedContent(ColorNode(.red), contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)

    // then: the replacement renders instead of the superseded content
    expect(child.contentView().layer().sublayers?.first?.backgroundColor) == ComposeUI.Color.blue.cgColor
    expect(child.refreshCount) == 2
    expect(child.contentView().layer().sublayers?.count) == 1
  }

  func test_refreshOverride_replacementKeepsItsOwnAnimationDecision() throws {
    for handledAnimated in [false, true] {
      for replacementAnimated in [false, true] {
        // given: a rendered layer and an override that handles one request without calling super
        let child = RefreshOverrideView()
        var layer: CALayer?
        var animationTiming: AnimationTiming?
        child.setContent {
          ColorNode(.red)
            .frame(width: 40, height: 40)
            .animation(.linear())
            .onUpdate { renderable, _ in
              layer = renderable.layer
            }
        }
        child.refresh(animated: false)
        let originalLayer = try unwrap(layer)
        let replacement = ColorNode(.blue)
          .frame(width: 80, height: 60)
          .animation(.linear())
          .onUpdate { renderable, context in
            layer = renderable.layer
            animationTiming = context.animationTiming
          }
        child.callsSuper = false
        child.afterRefresh = { view in
          view.afterRefresh = nil
          view.callsSuper = true
          view.setPreparedContent(replacement, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision(allowsTransitions: replacementAnimated, allowsAnimations: replacementAnimated))
        }

        // when: the handled request is followed by a prepared update from its override
        child.setNeedsRefresh(animated: handledAnimated)

        // then: the replacement follows its own animation decision, independently of the handled request
        expect(child.refreshCount).toEventually(beEqual(to: 3))
        expect(child.lastAnimated) == replacementAnimated
        expect(layer) === originalLayer
        expect(layer?.backgroundColor) == ComposeUI.Color.blue.cgColor
        expect(layer?.bounds.size) == CGSize(width: 80, height: 60)
        expect(animationTiming) == (replacementAnimated ? .linear() : nil)
      }
    }
  }

  func test_publicContentReplacement_discardsPendingPreparedContent() throws {
    // given: prepared content left pending by an override that skipped super
    let child = RefreshOverrideView()
    var layer: CALayer?
    var renderedEvaluation: ContentEvaluation?
    let preparedEvaluation = ContentEvaluation()
    child.debug { child, event in
      if case .renderWillBegin = event {
        renderedEvaluation = child.test.contentUpdateContext?.contentEvaluation
      }
    }
    child.callsSuper = false
    child.setPreparedContent(ColorNode(.blue), contentEvaluation: preparedEvaluation, animationDecision: ComposeView.AnimationDecision.disabled)
    expect(child.refreshCount) == 1
    expect(child.contentView().layer().sublayers?.isEmpty ?? true) == true

    // when: the application replaces the builder before the prepared content is applied
    child.callsSuper = true
    child.setContent {
      ColorNode(.green)
        .onUpdate { renderable, _ in
          layer = renderable.layer
        }
    }
    child.setNeedsLayout()
    child.layoutIfNeeded()

    // then: the application builder renders with its own evaluation and the prepared pair is discarded
    expect(child.refreshCount) == 2
    expect(layer?.backgroundColor) == ComposeUI.Color.green.cgColor
    expect(renderedEvaluation) !== preparedEvaluation
    expect(child.contentView().layer().sublayers?.count) == 1
  }
}

private final class RefreshOverrideView: ComposeView {

  var callsSuper = true
  var refreshCount = 0
  var lastAnimated: Bool?
  var beforeRefresh: ((RefreshOverrideView) -> Void)?
  var afterRefresh: ((RefreshOverrideView) -> Void)?

  init() {
    super.init(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
  }

  override func refresh(animated: Bool = true) {
    refreshCount += 1
    lastAnimated = animated
    beforeRefresh?(self)
    if callsSuper {
      super.refresh(animated: animated)
    }
    afterRefresh?(self)
  }
}
