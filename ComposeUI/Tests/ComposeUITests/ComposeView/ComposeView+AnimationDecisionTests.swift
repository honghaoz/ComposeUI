//
//  ComposeView+AnimationDecisionTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/13/26.
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

class ComposeView_AnimationDecisionTests: XCTestCase {

  func test_scroll_runsTransitionsWithoutAnimatingRetainedItems() throws {
    // given: rows with both transitions and update animations
    let timing = AnimationTiming.linear(duration: 10)
    var layers: [Int: CALayer] = [:]
    var contexts: [Int: RenderableUpdateContext] = [:]
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
    let leaving = try unwrap(layers[0])
    let retained = try unwrap(layers[1])

    // when: scrolling removes a row, retains a row, and inserts another
    view.setContentOffset(CGPoint(x: 0, y: 100))
    view.layoutIfNeeded()

    // then: the leaving and entering rows transition while the retained row updates immediately
    let entering = try unwrap(layers[2])
    expect(leaving.superlayer) != nil
    expect(leaving.opacity) == 0
    let removal = try unwrap(leaving.animation(forKey: "opacity") as? CABasicAnimation)
    expect(removal.isAdditive) == true
    expect(removal.fromValue as? Float) == 1
    expect(removal.toValue as? Float) == 0
    expect(layers[1]) === retained
    expect(retained.frame) == CGRect(x: 0, y: 100, width: 100, height: 100)
    expect(retained.opacity) == 1
    expect(retained.animationKeys()) == nil
    expect(contexts[1]?.animationTiming) == nil
    expect(entering.opacity) == 1
    let insertion = try unwrap(entering.animation(forKey: "opacity") as? CABasicAnimation)
    expect(insertion.fromValue as? Float) == -1
    expect(insertion.toValue as? Float) == 0
    expect(contexts[2]?.animationTiming) == nil

    // when: another scroll retains the entering row during its insertion transition
    let insertionBeginTime = insertion.beginTime
    let insertionKeys = entering.animationKeys()
    view.setContentOffset(CGPoint(x: 0, y: 110))
    view.layoutIfNeeded()

    // then: the existing transition continues without restarting or adding update animations
    expect(layers[2]) === entering
    expect(entering.animationKeys()) == insertionKeys
    let continued = try unwrap(entering.animation(forKey: "opacity") as? CABasicAnimation)
    expect(continued.beginTime) == insertionBeginTime
    expect(continued.fromValue as? Float) == -1
    expect(continued.toValue as? Float) == 0
    expect(entering.animation(forKey: "position")) == nil
    expect(entering.animation(forKey: "bounds.size")) == nil
    for layer in layers.values {
      layer.removeAllAnimations()
    }
  }

  func test_customCallbacks_useResolvedTimingIndependentlyOfTransitions() throws {
    for usesView in [false, true] {
      for configuredTiming in [nil, AnimationTiming.linear(duration: 10)] {
        for transitions in [false, true] {
          for updates in [false, true] {
            // given: custom view or layer updates use only the resolved timing
            let child = ComposeView()
            child.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
            var cornerRadius: CGFloat = 8
            var borderWidth: CGFloat = 2
            var willUpdateContext: RenderableUpdateContext?
            var updateContext: RenderableUpdateContext?
            var renderedLayer: CALayer?
            let node: any ComposeNode
            if usesView {
              node = ViewNode<BaseView>()
            } else {
              node = LayerNode<CALayer>()
            }
            var content: any ComposeNode = node
              .frame(width: 50, height: 50)
              .transition(.opacity(timing: .linear(duration: 10)))
              .willUpdate { renderable, context in
                willUpdateContext = context
                let layer = renderable.layer
                if let timing = context.animationTiming {
                  layer.animate(keyPath: "cornerRadius", timing: timing, from: { $0.cornerRadius }, to: { _ in cornerRadius })
                } else {
                  layer.disableActions { layer.cornerRadius = cornerRadius }
                }
              }
              .onUpdate { renderable, context in
                updateContext = context
                let layer = renderable.layer
                renderedLayer = layer
                if let timing = context.animationTiming {
                  layer.animate(keyPath: "borderWidth", timing: timing, from: { $0.borderWidth }, to: { _ in borderWidth })
                } else {
                  layer.disableActions { layer.borderWidth = borderWidth }
                }
              }
            if let configuredTiming {
              content = content.animation(configuredTiming)
            }
            let decision = ComposeView.AnimationDecision(allowsTransitions: transitions, allowsAnimations: updates)

            // when: the item is inserted
            child.setPreparedContent(content, contentEvaluation: nil, animationDecision: decision)

            // then: initial properties apply immediately regardless of policy or configured timing
            let layer = try unwrap(renderedLayer)
            let before = try unwrap(willUpdateContext)
            let after = try unwrap(updateContext)
            expect(before) == after
            expect(before.updateType) == .insert
            expect(before.animationTiming) == nil
            expect(layer.bounds.size) == CGSize(width: 50, height: 50)
            expect(layer.cornerRadius) == 8
            expect(layer.borderWidth) == 2
            expect(layer.animation(forKey: "cornerRadius")) == nil
            expect(layer.animation(forKey: "borderWidth")) == nil
            expect(layer.animation(forKey: "bounds.size")) == nil
            expect(layer.opacity) == 1
            expect(layer.animation(forKey: "opacity") != nil) == transitions
            layer.removeAllAnimations()

            // when: a refresh changes the properties while retaining the same renderable
            cornerRadius = 12
            borderWidth = 4
            child.setPreparedContent(content, contentEvaluation: nil, animationDecision: decision)

            // then: callbacks animate only with the effective timing supplied for this update
            expect(renderedLayer) === layer
            expect(willUpdateContext) == updateContext
            expect(updateContext?.updateType) == .refresh
            expect(updateContext?.animationTiming) == (updates ? configuredTiming : nil)
            expect(layer.cornerRadius) == 12
            expect(layer.borderWidth) == 4
            expect(layer.animation(forKey: "opacity")) == nil
            if updates, configuredTiming != nil {
              let corner = try unwrap(layer.animation(forKey: "cornerRadius") as? CABasicAnimation)
              let border = try unwrap(layer.animation(forKey: "borderWidth") as? CABasicAnimation)
              expect(corner.fromValue as? CGFloat) == 8
              expect(corner.toValue as? CGFloat) == 12
              expect(corner.duration) == 10
              expect(border.fromValue as? CGFloat) == 2
              expect(border.toValue as? CGFloat) == 4
              expect(border.duration) == 10
            } else {
              expect(layer.animation(forKey: "cornerRadius")) == nil
              expect(layer.animation(forKey: "borderWidth")) == nil
            }
            layer.removeAllAnimations()
          }
        }
      }
    }
  }

  func test_scrollDependentGeometry_updatesImmediatelyDespiteConfiguredAnimation() throws {
    // given: a renderable whose frame follows the viewport during scrolling
    var layer: CALayer?
    var updateContext: RenderableUpdateContext?
    let view = ComposeView {
      ScrollFollowingNode { renderable, context in
        layer = renderable
        updateContext = context
      }
      .animation(.linear(duration: 10))
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let renderable = try unwrap(layer)

    // when: repeated scroll positions change the renderable's frame
    for offset: CGFloat in [20, 40, 10] {
      view.setContentOffset(CGPoint(x: 0, y: offset))
      view.layoutIfNeeded()

      // then: geometry follows the offset without creating additive frame animations
      expect(layer) === renderable
      expect(renderable.frame) == CGRect(x: 0, y: offset, width: 100, height: 30)
      expect(renderable.backgroundColor) == Color.red.cgColor
      expect(updateContext?.updateType) == .boundsChange
      expect(updateContext?.animationTiming) == nil
      expect(renderable.animationKeys()) == nil
    }

    // when: resizing changes the same renderable's width
    view.frame.size.width = 160
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the new width also applies without interpolation
    expect(renderable.frame) == CGRect(x: 0, y: 10, width: 160, height: 30)
    expect(renderable.animationKeys()) == nil
  }

  func test_refreshFlag_controlsTransitionsAndUpdatesTogether() throws {
    for animated in [false, true] {
      for disablesAnimations in [false, true] {
        // given: initial content and a retained item that will change size on refresh
        let timing = AnimationTiming.linear(duration: 10)
        var replacement = false
        var height: CGFloat = 40
        var layers: [String: CALayer] = [:]
        var contexts: [String: RenderableUpdateContext] = [:]
        let view = ComposeView {
          ZStack {
            ColorNode(.red)
              .id("retained")
              .frame(width: 40, height: height)
              .animation(timing)
              .onUpdate { renderable, context in
                layers["retained"] = renderable.layer
                contexts["retained"] = context
              }
            ColorNode(.blue)
              .id(replacement ? "entering" : "leaving")
              .frame(width: 20, height: 20)
              .transition(.opacity(timing: timing))
              .onUpdate { renderable, context in
                layers[replacement ? "entering" : "leaving"] = renderable.layer
                contexts[replacement ? "entering" : "leaving"] = context
              }
          }
        }
        view.renderablePool = nil
        view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        view.refresh(animated: false)
        let retained = try unwrap(layers["retained"])
        let leaving = try unwrap(layers["leaving"])
        view.animationBehavior = disablesAnimations ? .disabled : .default
        replacement = true
        height = 60

        // when: a refresh removes, inserts, and updates renderables
        view.refresh(animated: animated)

        // then: its flag controls both types of animation unless the view disables them
        let allowed = animated && !disablesAnimations
        let entering = try unwrap(layers["entering"])
        expect(layers["retained"]) === retained
        expect(retained.bounds.size) == CGSize(width: 40, height: 60)
        expect(retained.backgroundColor) == Color.red.cgColor
        expect(contexts["retained"]?.animationTiming) == (allowed ? timing : nil)
        expect(retained.animation(forKey: "bounds.size") != nil) == allowed
        expect(entering.opacity) == 1
        expect(entering.backgroundColor) == Color.blue.cgColor
        expect(contexts["entering"]?.animationTiming) == nil
        expect(entering.animation(forKey: "opacity") != nil) == allowed
        expect(leaving.superlayer != nil) == allowed
        expect(leaving.animation(forKey: "opacity") != nil) == allowed
        for layer in layers.values {
          layer.removeAllAnimations()
        }
      }
    }
  }

  func test_preparedDecision_isConsumedBeforeIndependentRefresh() throws {
    // given: a mounted item and a prepared update that permits transitions but not retained animations
    var height: CGFloat = 70
    var layers: [Int: CALayer] = [:]
    var contexts: [Int: RenderableUpdateContext] = [:]
    func content() -> some ComposeNode {
      VStack(spacing: 0) {
        ColorNode(.red)
          .frame(width: .flexible, height: height)
          .animation(.linear(duration: 10))
          .onUpdate { renderable, context in
            layers[0] = renderable.layer
            contexts[0] = context
          }
        ColorNode(.blue)
          .frame(width: 40, height: 30)
          .transition(.opacity(timing: .linear(duration: 10)))
          .onUpdate { renderable, context in
            layers[1] = renderable.layer
            contexts[1] = context
          }
      }
    }
    let child = ComposeView { content() }
    child.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    child.refresh(animated: false)
    let retained = try unwrap(layers[0])
    for layer in layers.values {
      layer.removeAllAnimations()
    }
    height = 20

    // when: prepared content updates the existing row and reveals the next row
    child.setPreparedContent(content(), contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision(allowsTransitions: true, allowsAnimations: false))

    // then: the two inherited decisions apply separately in the child
    expect(layers[0]) === retained
    expect(retained.bounds.size) == CGSize(width: 100, height: 20)
    expect(retained.animationKeys()) == nil
    expect(contexts[0]?.animationTiming) == nil
    expect(layers[1]?.animation(forKey: "opacity")) != nil
    for layer in layers.values {
      layer.removeAllAnimations()
    }

    // when: the child independently refreshes its supplied content at a new size
    child.frame.size.width = 140
    child.refresh(animated: true)

    // then: consuming the prepared decision restores ordinary animated refresh behavior
    expect(contexts[0]?.animationDecision) == ComposeView.AnimationDecision(allowsTransitions: true, allowsAnimations: true)
    expect(contexts[0]?.animationTiming) == .linear(duration: 10)
    expect(layers[0]) === retained
    expect(retained.bounds.size) == CGSize(width: 140, height: 20)
    expect(retained.animation(forKey: "bounds.size")) != nil
    for layer in layers.values {
      layer.removeAllAnimations()
    }

    // when: the child independently refreshes after replacing its builder
    child.setContent {
      ColorNode(.green)
        .frame(width: 60, height: 50)
        .animation(.linear(duration: 10))
        .onUpdate { renderable, context in
          layers[0] = renderable.layer
          contexts[0] = context
        }
    }
    child.refresh(animated: true)

    // then: the new tree has no inherited suppression and initializes its inserted item immediately
    expect(contexts[0]?.animationDecision) == ComposeView.AnimationDecision(allowsTransitions: true, allowsAnimations: true)
    expect(contexts[0]?.updateType) == .insert
    expect(contexts[0]?.animationTiming) == nil
    expect(layers[0]?.backgroundColor) == Color.green.cgColor
    for layer in layers.values {
      layer.removeAllAnimations()
    }
  }

  func test_publicSetContent_discardsUnconsumedPreparedAnimationDecision() throws {
    // given: a subclass holds a prepared update without rendering it
    let child = DeferredPreparedView()
    let neither = ComposeView.AnimationDecision(allowsTransitions: false, allowsAnimations: false)
    child.setPreparedContent(ColorNode(.red), contentEvaluation: nil, animationDecision: neither)
    var layer: CALayer?
    var context: RenderableUpdateContext?

    // when: the application replaces the prepared content through the public API
    child.defersRefresh = false
    child.setContent {
      ColorNode(.blue)
        .transition(.opacity(timing: .linear(duration: 10)))
        .onUpdate { renderable, update in
          layer = renderable.layer
          context = update
        }
    }
    child.refresh(animated: true)

    // then: the new request permits its configured insertion transition
    let renderable = try unwrap(layer)
    expect(context?.animationDecision) == ComposeView.AnimationDecision(allowsTransitions: true, allowsAnimations: true)
    expect(context?.animationTiming) == nil
    expect(renderable.backgroundColor) == Color.blue.cgColor
    expect(renderable.animation(forKey: "opacity")) != nil
    renderable.removeAllAnimations()
  }

  func test_boundsChanges_preserveExistingAdditiveAndCustomAnimations() throws {
    // given: an animated refresh has started an additive size animation and an unrelated custom animation
    var height: CGFloat = 40
    var layer: CALayer?
    var updateContext: RenderableUpdateContext?
    let view = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: height)
        .animation(.linear(duration: 10))
        .onUpdate { renderable, context in
          layer = renderable.layer
          updateContext = context
        }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let renderable = try unwrap(layer)
    height = 200
    view.refresh(animated: true)
    let original = try unwrap(renderable.animation(forKey: "bounds.size") as? CABasicAnimation)
    let originalPosition = try unwrap(renderable.animation(forKey: "position") as? CABasicAnimation)
    let custom = CABasicAnimation(keyPath: "opacity")
    custom.fromValue = Float(1)
    custom.toValue = Float(0.5)
    custom.duration = 10
    renderable.add(custom, forKey: "customOpacity")
    let originalKeys = renderable.animationKeys()?.sorted()

    // when: successive viewport sizes change the model geometry without new update animations
    for width: CGFloat in [150, 180, 120] {
      view.frame.size.width = width
      view.setNeedsLayout()
      view.layoutIfNeeded()

      // then: existing animations remain while the model tracks the new size
      expect(layer) === renderable
      expect(renderable.bounds.size) == CGSize(width: width, height: 200)
      expect(updateContext?.animationTiming) == nil
      expect(renderable.animationKeys()?.sorted()) == originalKeys
      let continued = try unwrap(renderable.animation(forKey: "bounds.size") as? CABasicAnimation)
      expect(continued.fromValue as? CGSize) == original.fromValue as? CGSize
      expect(continued.toValue as? CGSize) == original.toValue as? CGSize
      expect(continued.beginTime) == original.beginTime
      expect(continued.duration) == original.duration
      expect(continued.isAdditive) == true
      let position = try unwrap(renderable.animation(forKey: "position") as? CABasicAnimation)
      expect(position.beginTime) == originalPosition.beginTime
      expect(position.fromValue as? CGPoint) == originalPosition.fromValue as? CGPoint
      expect(renderable.animation(forKey: "customOpacity")?.duration) == 10
    }

    // when: the same retained item scrolls
    view.setContentOffset(CGPoint(x: 0, y: 20))
    view.layoutIfNeeded()

    // then: scroll also leaves the existing animations running unchanged
    expect(renderable.animationKeys()?.sorted()) == originalKeys
    expect(renderable.bounds.size) == CGSize(width: 120, height: 200)
    expect(updateContext?.animationTiming) == nil
    renderable.removeAllAnimations()
  }
}

private struct ScrollFollowingNode: ComposeNode {

  var id: ComposeNodeId = .custom("scroll-following")
  var size: CGSize = .zero
  let update: (CALayer, RenderableUpdateContext) -> Void

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    size = CGSize(width: containerSize.width, height: 400)
    return ComposeNodeSizing(width: .flexible, height: .fixed(400))
  }

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    let item = LayerItem<CALayer>(
      id: id,
      frame: CGRect(x: 0, y: visibleBounds.minY, width: size.width, height: 30),
      make: { _ in CALayer() },
      update: { layer, context in
        layer.backgroundColor = Color.red.cgColor
        update(layer, context)
      }
    )
    return [item.eraseToRenderableItem()]
  }
}

private final class DeferredPreparedView: ComposeView {

  var defersRefresh = true

  init() {
    super.init(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
  }

  override func refresh(animated: Bool = true) {
    if !defersRefresh {
      super.refresh(animated: animated)
    }
  }
}
