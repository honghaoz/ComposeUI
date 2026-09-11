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

  func test_preparedContent_isAppliedOnceThenRefreshEvaluatesIndependently() throws {
    // given: intrinsic content measured by its parent before the child displays it
    var width: CGFloat = 80
    var providerCalls = 0
    var hostedView: MutableSwiftUIHostingView?
    var renderedRoot: LayoutCacheNode?
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

    // when: the child queues the prepared content and additional refresh requests
    child.setPreparedContent(node, contentEvaluation: evaluation)
    child.setNeedsRefresh(animated: false)
    child.setNeedsRefresh(animated: true)
    width = 140

    // then: queuing does not render or reevaluate the prepared content
    expect(hostedView) == nil
    expect(providerCalls) == 1

    // when: layout performs the merged refresh
    child.setNeedsLayout()
    child.layoutIfNeeded()

    // then: the supplied tree and evaluation are applied together
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

  func test_preparedContent_withoutEvaluation_resolvesLazilyThenRefreshReevaluates() throws {
    // given: lazy content without a parent-supplied evaluation
    var width: CGFloat = 80
    var providerCalls = 0
    var hostedView: MutableSwiftUIHostingView?
    var renderedRoot: LayoutCacheNode?
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

    // when: content is queued without an evaluation and its external value changes
    child.setPreparedContent(
      SwiftUIViewNode {
        providerCalls += 1
        return SwiftUI.Color.red.frame(width: width, height: 50)
      }
      .fixedSize()
      .onUpdate { renderable, _ in
        hostedView = renderable.view as? MutableSwiftUIHostingView
      },
      contentEvaluation: nil
    )
    width = 140

    // then: queuing leaves the provider unresolved
    expect(hostedView) == nil
    expect(providerCalls) == 0

    // when: the first render resolves the lazy content
    child.setNeedsLayout()
    child.layoutIfNeeded()

    // then: a fresh evaluation displays the latest value and geometry
    let host = try unwrap(hostedView)
    let firstRoot = try unwrap(renderedRoot)
    let firstEvaluation = try unwrap(renderedEvaluation)
    expect(host.bounds.size) == CGSize(width: 140, height: 50)
    expect(host.content.sizeThatFits(proposal)) == CGSize(width: 140, height: 50)
    expect(providerCalls) == 1

    // when: an independent refresh follows another external change
    width = 160
    child.refresh(animated: false)

    // then: the new evaluation updates the retained native view
    expect(renderedRoot) !== firstRoot
    expect(renderedEvaluation) !== firstEvaluation
    expect(hostedView) === host
    expect(host.bounds.size) == CGSize(width: 160, height: 50)
    expect(host.content.sizeThatFits(proposal)) == CGSize(width: 160, height: 50)
    expect(providerCalls) == 2
  }

  func test_latestPreparedContent_replacesTreeAndEvaluationTogether() throws {
    // given: two parent-supplied updates before the child refreshes
    var layer: CALayer?
    var renderedEvaluation: ContentEvaluation?
    let first = ColorNode(.red).frame(width: .flexible, height: 40)
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

    // when: both complete updates are queued before rendering
    child.setPreparedContent(first, contentEvaluation: firstEvaluation)
    child.setPreparedContent(second, contentEvaluation: secondEvaluation)
    child.setNeedsLayout()
    child.layoutIfNeeded()

    // then: only the latest content and evaluation determine displayed configuration and geometry
    let renderedLayer = try unwrap(layer)
    expect(renderedEvaluation) === secondEvaluation
    expect(renderedEvaluation) !== firstEvaluation
    expect(renderedLayer.backgroundColor) == ComposeUI.Color.blue.cgColor
    expect(renderedLayer.bounds.size) == CGSize(width: 100, height: 80)
  }

  func test_measurement_preservesQueuedPreparedContent() throws {
    // given: parent-measured content queued for a child that has not rendered it
    var width: CGFloat = 80
    var providerCalls = 0
    var hostedView: MutableSwiftUIHostingView?
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
    child.setPreparedContent(node, contentEvaluation: evaluation)
    width = 140

    // when: standalone measurement resolves the latest provider value
    let measuredSize = child.sizeThatFits(proposal)

    // then: measurement does not display or consume the queued content
    expect(measuredSize) == CGSize(width: 140, height: 50)
    expect(hostedView) == nil
    expect(providerCalls) == 2

    // when: the pending child update renders
    child.setNeedsLayout()
    child.layoutIfNeeded()

    // then: the prepared evaluation restores its originally measured value and geometry
    let host = try unwrap(hostedView)
    expect(host.bounds.size) == CGSize(width: 80, height: 50)
    expect(host.content.sizeThatFits(proposal)) == CGSize(width: 80, height: 50)
    expect(providerCalls) == 2
  }

  func test_measurement_usesSuppliedContentWithoutChangingPreparedRoot() throws {
    // given: a prepared root displaying flexible content at the child's size
    var renderedRoot: LayoutCacheNode?
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
    child.setPreparedContent(content)
    child.refresh(animated: false)
    let preparedRoot = try unwrap(renderedRoot)
    let layer = try unwrap(renderedLayer)
    let originalBounds = CGRect(x: 0, y: 0, width: 100, height: 80)

    // when: measurement uses a different proposal from the displayed view
    let measuredSize = child.sizeThatFits(CGSize(width: 200, height: 160))

    // then: measurement leaves the prepared root's geometry and displayed layer unchanged
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

  func test_preparedContent_mergesAnimationRequestsInEitherOrder() throws {
    for requestBeforeContent in [true, false] {
      // given: a retained layer and parent-supplied content with animated geometry
      var layer: CALayer?
      var animationTiming: AnimationTiming?
      let child = ComposeView {
        ColorNode(.red)
          .frame(width: 40, height: 40)
          .animation(.linear())
          .onUpdate { renderable, context in
            layer = renderable.layer
            animationTiming = context.animationTiming
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
        }

      // when: a non-animated request is merged before or after the prepared content
      if requestBeforeContent {
        child.setNeedsRefresh(animated: false)
      }
      child.setPreparedContent(prepared, contentEvaluation: nil)
      if !requestBeforeContent {
        child.setNeedsRefresh(animated: false)
      }
      child.setNeedsRefresh(animated: true)
      child.setNeedsLayout()
      child.layoutIfNeeded()

      // then: geometry changes without animation while the supplied content is still applied
      expect(layer) === originalLayer
      expect(layer?.backgroundColor) == ComposeUI.Color.blue.cgColor
      expect(layer?.bounds.size) == CGSize(width: 80, height: 60)
      expect(animationTiming) == nil
    }
  }

  func test_immediateRefresh_appliesPreparedContentWithExplicitAnimation() throws {
    // given: an existing layer and a non-animated pending content request
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
    child.setPreparedContent(prepared, contentEvaluation: nil)
    child.setNeedsRefresh(animated: false)

    // when: an immediate refresh overrides the queued animation preference
    child.refresh(animated: true)

    // then: the prepared content is applied once with the explicitly requested animation
    expect(layer) === originalLayer
    expect(layer?.backgroundColor) == ComposeUI.Color.blue.cgColor
    expect(layer?.bounds.size) == CGSize(width: 80, height: 60)
    expect(animationTiming) == .linear()
    expect(renderCount) == 1

    // when: the previously scheduled callback has an opportunity to run
    wait(timeout: 0.01)

    // then: the consumed prepared request is not rendered again
    expect(renderCount) == 1
  }

  func test_scheduledPreparedContent_usesRefreshOverride() throws {
    // given: a child subclass that participates in the refresh lifecycle
    let child = RefreshOverrideView()
    var layer: CALayer?
    let prepared = ColorNode(.blue)
      .onUpdate { renderable, _ in
        layer = renderable.layer
      }

    // when: prepared content is dispatched on the run loop
    child.setPreparedContent(prepared, contentEvaluation: nil)

    // then: the open refresh override runs before rendering the supplied content
    expect(layer?.backgroundColor).toEventually(beEqual(to: ComposeUI.Color.blue.cgColor))
    expect(child.refreshCount) == 1
    expect(child.lastAnimated) == true
    expect(layer?.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
  }

  func test_refreshOverrideWithoutSuper_preservesPreparedStateUntilApplied() throws {
    // given: parent-measured content and a child that declines its first scheduled refresh
    var width: CGFloat = 80
    var hostedView: MutableSwiftUIHostingView?
    var renderedRoot: LayoutCacheNode?
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
    child.setPreparedContent(node, contentEvaluation: evaluation)

    // when: the override handles the request without calling super
    expect(child.refreshCount).toEventually(beEqual(to: 1))

    // then: the prepared content remains unapplied
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

  func test_refreshOverride_preservesRequestQueuedAfterSuper() throws {
    // given: a child whose override queues replacement content after its first render
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
      view.setPreparedContent(second, contentEvaluation: nil)
      view.setNeedsRefresh(animated: false)
    }

    // when: the first prepared update triggers the override and its follow-up request
    child.setPreparedContent(first, contentEvaluation: nil)

    // then: cleanup of the first dispatch leaves the replacement request intact
    expect(colors).toEventually(beEqual(to: [ComposeUI.Color.red.cgColor, ComposeUI.Color.blue.cgColor]))
    expect(child.refreshCount) == 2
    expect(child.lastAnimated) == false
    expect(child.contentView().layer().sublayers?.first?.backgroundColor) == ComposeUI.Color.blue.cgColor
  }

  func test_refreshOverride_consumesReplacementQueuedBeforeSuper() throws {
    // given: an override replacing the prepared content before calling the base refresh
    let child = RefreshOverrideView()
    var color: CGColor?
    let second = ColorNode(.blue)
      .onUpdate { renderable, _ in
        color = renderable.layer.backgroundColor
      }
    child.beforeRefresh = { view in
      view.beforeRefresh = nil
      view.setPreparedContent(second, contentEvaluation: nil)
    }

    // when: the base implementation sees the replacement queued by its override
    child.setPreparedContent(ColorNode(.red), contentEvaluation: nil)

    // then: the latest prepared content is applied by that refresh
    expect(color).toEventually(beEqual(to: ComposeUI.Color.blue.cgColor))
    expect(child.refreshCount) == 1

    // when: the redundant scheduled callback has an opportunity to run
    wait(timeout: 0.01)

    // then: the consumed replacement does not cause another refresh
    expect(child.refreshCount) == 1
    expect(child.contentView().layer().sublayers?.first?.backgroundColor) == ComposeUI.Color.blue.cgColor
  }

  func test_refreshOverrideWithoutSuper_preservesReplacementRequest() throws {
    // given: an override that defers rendering by scheduling a replacement before returning
    let child = RefreshOverrideView()
    child.callsSuper = false
    child.afterRefresh = { view in
      view.afterRefresh = nil
      view.callsSuper = true
      view.setPreparedContent(ColorNode(.blue), contentEvaluation: nil)
    }

    // when: the initial override skips super but leaves a replacement scheduled
    child.setPreparedContent(ColorNode(.red), contentEvaluation: nil)

    // then: the replacement is dispatched instead of being cleared with the first request
    expect(child.contentView().layer().sublayers?.first?.backgroundColor).toEventually(beEqual(to: ComposeUI.Color.blue.cgColor))
    expect(child.refreshCount) == 2
    expect(child.contentView().layer().sublayers?.count) == 1
  }

  func test_refreshOverride_replacementKeepsItsOwnAnimationPreference() throws {
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
          view.setPreparedContent(replacement, contentEvaluation: nil)
          view.setNeedsRefresh(animated: replacementAnimated)
        }

        // when: the handled request is followed by a new prepared update from its override
        child.setNeedsRefresh(animated: handledAnimated)

        // then: the replacement follows its own animation preference, independently of the handled request
        expect(child.refreshCount).toEventually(beEqual(to: 3))
        expect(child.lastAnimated) == replacementAnimated
        expect(layer) === originalLayer
        expect(layer?.backgroundColor) == ComposeUI.Color.blue.cgColor
        expect(layer?.bounds.size) == CGSize(width: 80, height: 60)
        expect(animationTiming) == (replacementAnimated ? .linear() : nil)
      }
    }
  }

  func test_publicContentReplacement_discardsPreparedPairAndKeepsAnimationPreference() throws {
    // given: queued parent content followed by an application replacement
    var layer: CALayer?
    var animationTiming: AnimationTiming?
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
    child.setPreparedContent(ColorNode(.blue).frame(width: 80, height: 60), contentEvaluation: ContentEvaluation())
    child.setNeedsRefresh(animated: false)

    // when: the application replaces the builder before the pending refresh
    child.setContent {
      ColorNode(.green)
        .frame(width: 120, height: 70)
        .animation(.linear())
        .onUpdate { renderable, context in
          layer = renderable.layer
          animationTiming = context.animationTiming
        }
    }
    let measuredSize = child.sizeThatFits(CGSize(width: 200, height: 100))
    child.setNeedsLayout()
    child.layoutIfNeeded()

    // then: the application builder wins without losing the existing non-animated requirement
    expect(measuredSize) == CGSize(width: 120, height: 70)
    expect(layer?.backgroundColor) == ComposeUI.Color.green.cgColor
    expect(layer?.bounds.size) == CGSize(width: 120, height: 70)
    expect(animationTiming) == nil
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
