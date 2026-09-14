//
//  ComposeView+ContentUpdateContextTests.swift
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

@testable import ComposeUI

class ComposeView_ContentUpdateContextTests: XCTestCase {

  func test_equality_comparesContentAndUpdateInputs() {
    // given: matching contexts and a second context for each changed field
    let node = ComposeView.LayoutCacheNode(node: ColorNode(.red))
    let evaluation = ContentEvaluation()
    let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
    let original = ComposeView.ContentUpdateContext(contentNode: node, contentEvaluation: evaluation, updateType: .refresh(isAnimated: false), previousRenderBounds: .zero, renderBounds: bounds, inheritedAnimationDecision: .all)
    let same = ComposeView.ContentUpdateContext(contentNode: node, contentEvaluation: evaluation, updateType: .refresh(isAnimated: false), previousRenderBounds: .zero, renderBounds: bounds, inheritedAnimationDecision: .all)
    let different = [
      ComposeView.ContentUpdateContext(contentNode: ComposeView.LayoutCacheNode(node: ColorNode(.red)), contentEvaluation: evaluation, updateType: .refresh(isAnimated: false), previousRenderBounds: .zero, renderBounds: bounds, inheritedAnimationDecision: .all),
      ComposeView.ContentUpdateContext(contentNode: node, contentEvaluation: ContentEvaluation(), updateType: .refresh(isAnimated: false), previousRenderBounds: .zero, renderBounds: bounds, inheritedAnimationDecision: .all),
      ComposeView.ContentUpdateContext(contentNode: node, contentEvaluation: evaluation, updateType: .refresh(isAnimated: true), previousRenderBounds: .zero, renderBounds: bounds, inheritedAnimationDecision: .all),
      ComposeView.ContentUpdateContext(contentNode: node, contentEvaluation: evaluation, updateType: .boundsChange, previousRenderBounds: .zero, renderBounds: bounds, inheritedAnimationDecision: .all),
      ComposeView.ContentUpdateContext(contentNode: node, contentEvaluation: evaluation, updateType: .refresh(isAnimated: false), previousRenderBounds: .zero, renderBounds: .zero, inheritedAnimationDecision: .all),
      ComposeView.ContentUpdateContext(contentNode: node, contentEvaluation: evaluation, updateType: .refresh(isAnimated: false), previousRenderBounds: bounds, renderBounds: bounds, inheritedAnimationDecision: .all),
      ComposeView.ContentUpdateContext(contentNode: node, contentEvaluation: evaluation, updateType: .refresh(isAnimated: false), previousRenderBounds: nil, renderBounds: bounds, inheritedAnimationDecision: .all),
      ComposeView.ContentUpdateContext(contentNode: node, contentEvaluation: evaluation, updateType: .refresh(isAnimated: false), previousRenderBounds: .zero, renderBounds: bounds, inheritedAnimationDecision: ComposeView.AnimationDecision.transitionsOnly),
    ]

    // then: content identity and every update field participate in equality
    expect(original) == same
    for context in different {
      expect(original) != context
    }
  }

  func test_renderPass_retainsContentAcrossBoundsUpdates() throws {
    // given: a layer whose configuration is captured when its builder runs
    var color = Color.red
    var layer: CALayer?
    var pass: ComposeView.ContentUpdateContext?
    var itemContext: RenderableUpdateContext?
    let view = ComposeView {
      ColorNode(color)
        .frame(width: .flexible, height: 300)
        .onUpdate { renderable, context in
          layer = renderable.layer
          itemContext = context
        }
    }
    view.debug { view, event in
      if case .renderWillBegin = event {
        pass = view.test.contentUpdateContext
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the initial bounds change renders the content
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the pass and insertion share one content evaluation
    let initial = try unwrap(pass)
    let originalLayer = try unwrap(layer)
    expect(itemContext?.contentEvaluation) === initial.contentEvaluation
    expect(itemContext?.updateType) == .insert
    expect(originalLayer.backgroundColor) == Color.red.cgColor
    expect(originalLayer.bounds.size) == CGSize(width: 100, height: 300)

    // when: changed external data is followed by resize and scrolling
    color = .blue
    view.frame.size.width = 150
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: resize reuses the content pair while updating geometry
    expect(pass?.contentNode) === initial.contentNode
    expect(pass?.contentEvaluation) === initial.contentEvaluation
    expect(itemContext?.contentEvaluation) === initial.contentEvaluation
    expect(itemContext?.updateType) == .boundsChange
    expect(layer) === originalLayer
    expect(originalLayer.backgroundColor) == Color.red.cgColor
    expect(originalLayer.bounds.size) == CGSize(width: 150, height: 300)

    // when: the view scrolls
    view.setContentOffset(CGPoint(x: 0, y: 20))
    view.layoutIfNeeded()

    // then: scrolling also uses the retained pair and forwards its evaluation
    expect(pass?.contentNode) === initial.contentNode
    expect(pass?.contentEvaluation) === initial.contentEvaluation
    expect(itemContext?.contentEvaluation) === initial.contentEvaluation
    expect(itemContext?.updateType) == .boundsChange
    expect(originalLayer.backgroundColor) == Color.red.cgColor

    // when: an explicit refresh replaces the content
    view.refresh(animated: false)

    // then: root and evaluation change together while the renderable receives the new configuration
    let refreshed = try unwrap(pass)
    expect(refreshed.contentNode) !== initial.contentNode
    expect(refreshed.contentEvaluation) !== initial.contentEvaluation
    expect(itemContext?.contentEvaluation) === refreshed.contentEvaluation
    expect(itemContext?.updateType) == .refresh
    expect(layer) === originalLayer
    expect(originalLayer.backgroundColor) == Color.blue.cgColor
  }

  func test_updateContext_preservesContentAfterReplacement() throws {
    // given: a pass created before the current node and evaluation are replaced
    let provider = ContentEvaluation.Provider { Color.red.cgColor }
    var contentNode = ComposeView.LayoutCacheNode(node: ColorNode(.red))
    var contentEvaluation = ContentEvaluation()
    let originalNode = contentNode
    let originalEvaluation = contentEvaluation
    let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
    let pass = ComposeView.ContentUpdateContext(contentNode: contentNode, contentEvaluation: contentEvaluation, updateType: .refresh(isAnimated: false), previousRenderBounds: .zero, renderBounds: bounds, inheritedAnimationDecision: .all)
    let originalValue = pass.contentEvaluation.lazyValue(for: provider)

    // when: a later refresh selects different content while the earlier pass is retained
    contentNode = ComposeView.LayoutCacheNode(node: ColorNode(.blue))
    contentEvaluation = ContentEvaluation()
    _ = pass.contentNode.layout(containerSize: bounds.size, context: ComposeNodeLayoutContext(scaleFactor: 1, contentEvaluation: pass.contentEvaluation))
    let item = try unwrap(pass.contentNode.renderableItems(in: bounds).first)
    let view = ComposeView()
    let renderable = item.make(RenderableMakeContext(initialFrame: item.frame, contentView: view))
    item.update(renderable, RenderableUpdateContext(updateType: .insert, oldFrame: .zero, newFrame: item.frame, previousRenderBounds: .zero, renderBounds: bounds, animationTiming: nil, contentView: view, contentEvaluation: pass.contentEvaluation, animationDecision: ComposeView.AnimationDecision.disabled))

    // then: the pass still measures and renders its original node and evaluation
    expect(pass.contentNode) === originalNode
    expect(pass.contentEvaluation) === originalEvaluation
    expect(pass.contentNode) !== contentNode
    expect(pass.contentEvaluation) !== contentEvaluation
    expect(pass.contentEvaluation.lazyValue(for: provider)) === originalValue
    expect(renderable.layer.backgroundColor) == Color.red.cgColor
    expect(renderable.frame) == bounds
  }

  func test_renderPass_resolvesTimingForItemContexts() throws {
    // given: an item with a configured timing whose update context records the resolved result
    var itemContext: RenderableUpdateContext?
    var layer: CALayer?
    let timing = AnimationTiming.linear()
    let view = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: 300)
        .animation(timing)
        .onUpdate { renderable, context in
          itemContext = context
          layer = renderable.layer
        }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the initial bounds change inserts the content
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: first insertion applies its configuration without update animations
    expect(itemContext?.updateType) == .insert
    expect(itemContext?.animationTiming) == nil

    for animated in [true, false] {
      // when: the view refreshes with an explicit animation flag
      view.refresh(animated: animated)

      // then: the reused item receives timing only when the refresh permits it
      expect(itemContext?.updateType) == .refresh
      expect(itemContext?.animationTiming) == (animated ? timing : nil)
      expect(layer?.backgroundColor) == Color.red.cgColor
    }

    // when: the view scrolls
    view.setContentOffset(CGPoint(x: 0, y: 20))
    view.layoutIfNeeded()

    // then: retained scroll updates are immediate by default
    expect(itemContext?.updateType) == .boundsChange
    expect(itemContext?.animationTiming) == nil

    // when: the view resizes
    view.frame.size.width = 150
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: a size change updates immediately
    expect(itemContext?.updateType) == .boundsChange
    expect(itemContext?.animationTiming) == nil

    // when: animations are disabled and an animated refresh is requested
    view.animationBehavior = .disabled
    view.refresh(animated: true)

    // then: the animation behavior overrides the request
    expect(itemContext?.updateType) == .refresh
    expect(itemContext?.animationTiming) == nil

    // when: a dynamic behavior animates scrolls only and an animated refresh is requested
    var dynamicRenderTypes: [ComposeView.RenderType] = []
    view.animationBehavior = .dynamic { _, renderType in
      dynamicRenderTypes.append(renderType)
      if case .boundsChange(let previousBounds, let bounds) = renderType {
        return previousBounds?.size == bounds.size
      }
      return false
    }
    view.refresh(animated: true)

    // then: the closure sees the refresh and its decision, not the request, reaches the item
    expect(dynamicRenderTypes.last) == .refresh(isAnimated: true)
    expect(itemContext?.updateType) == .refresh
    expect(itemContext?.animationTiming) == nil

    // when: the view scrolls under the dynamic behavior
    view.setContentOffset(CGPoint(x: 0, y: 40))
    view.layoutIfNeeded()

    // then: the closure sees the scroll and its decision reaches the item
    expect(dynamicRenderTypes.last) == .boundsChange(previousBounds: CGRect(x: 0, y: 20, width: 150, height: 100), bounds: CGRect(x: 0, y: 40, width: 150, height: 100))
    expect(itemContext?.updateType) == .boundsChange
    expect(itemContext?.animationTiming) == timing

    // when: another view's first render is an animated refresh
    var insertContext: RenderableUpdateContext?
    let animatedView = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: 300)
        .animation(timing)
        .onUpdate { _, context in
          insertContext = context
        }
    }
    animatedView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    animatedView.refresh(animated: true)

    // then: insertion still applies initial configuration immediately despite its configured timing
    expect(insertContext?.updateType) == .insert
    expect(insertContext?.animationTiming) == nil
  }

  func test_renderType() {
    // given: update contexts for a refresh and for bounds changes with and without render history
    let node = ComposeView.LayoutCacheNode(node: ColorNode(.red))
    let evaluation = ContentEvaluation()
    let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
    let scrolledBounds = CGRect(x: 0, y: 20, width: 100, height: 100)
    func makeContext(_ updateType: ComposeView.ContentUpdateContext.ContentUpdateType, previousRenderBounds: CGRect?) -> ComposeView.ContentUpdateContext {
      ComposeView.ContentUpdateContext(contentNode: node, contentEvaluation: evaluation, updateType: updateType, previousRenderBounds: previousRenderBounds, renderBounds: bounds, inheritedAnimationDecision: .all)
    }
    let animatedRefresh = makeContext(.refresh(isAnimated: true), previousRenderBounds: bounds)
    let refresh = makeContext(.refresh(isAnimated: false), previousRenderBounds: nil)
    let initial = makeContext(.boundsChange, previousRenderBounds: nil)
    let scroll = makeContext(.boundsChange, previousRenderBounds: bounds)

    // then: a refresh reports its animation flag and no viewport
    expect(animatedRefresh.renderType(bounds: bounds)) == .refresh(isAnimated: true)
    expect(refresh.renderType(bounds: bounds)) == .refresh(isAnimated: false)

    // then: a bounds change reports the render history and the callback's viewport, without inventing missing history
    expect(initial.renderType(bounds: bounds)) == .boundsChange(previousBounds: nil, bounds: bounds)
    expect(initial.renderType(bounds: .zero)) == .boundsChange(previousBounds: nil, bounds: .zero)
    expect(scroll.renderType(bounds: scrolledBounds)) == .boundsChange(previousBounds: bounds, bounds: scrolledBounds)
    expect(scroll.renderType(bounds: bounds)) == .boundsChange(previousBounds: bounds, bounds: bounds)
  }
}
