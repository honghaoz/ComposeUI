//
//  ComposeViewNode+AnimationTests.swift
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

class ComposeViewNode_AnimationTests: XCTestCase {

  func test_boundsRevival_preservesTransitionsWithoutAnimatingRetainedDescendants_atEveryDepth() throws {
    for nestingDepth in 1 ... 3 {
      // given: nested viewports retaining a row that shrinks when the available width grows
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
          content.transition(.opacity(timing: timing))
          Spacer(height: 400)
        }
      }
      parent.renderablePool = nil
      parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      parent.refresh(animated: false)
      let originalViews = try (0 ..< nestingDepth).map { try unwrap(nestedViews[$0]) }
      let outerView = try unwrap(originalViews.last)
      let retainedLayer = try unwrap(layers[0])
      expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 100, height: 120)
      expect(retainedLayer.cornerRadius) == 10
      expect(retainedLayer.backgroundColor) == Color.red.cgColor
      expect(retainedLayer.animationKeys()) == nil
      expect(layers[1]) == nil
      defer {
        for view in originalViews {
          view.layer().removeAllAnimations()
        }
        for layer in layers.values {
          layer.removeAllAnimations()
        }
      }

      // when: scrolling the outer view offscreen starts its removal transition
      parent.setContentOffset(CGPoint(x: 0, y: 200))
      parent.layoutIfNeeded()

      // then: the removed view and its descendants remain mounted during removal
      expect(outerView.superview) != nil
      expect(outerView.layer().opacity) == 0
      let removal = try unwrap(outerView.layer().animation(forKey: "opacity") as? CABasicAnimation)
      expect(removal.fromValue as? Float) == 1
      expect(removal.toValue as? Float) == 0
      expect(removal.duration) == 10
      expect(removal.isAdditive) == true
      expect(retainedLayer.superlayer) === originalViews[0].contentView().layer()

      // when: the parent resizes while the nested subtree is still offscreen
      parent.frame.size.width = 160
      parent.setNeedsLayout()
      parent.layoutIfNeeded()

      // then: the retained subtree has not yet received the new geometry
      expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 100, height: 120)
      expect(layers[1]) == nil
      layerContexts.removeAll()
      nestedContexts.removeAll()
      renderTypes.removeAll()

      // when: scrolling back revives the outer view before removal completes
      parent.setContentOffset(.zero)
      parent.layoutIfNeeded()

      // then: every nested view is retained and refreshes with the parent's separate decisions
      let transitionsOnly = ComposeView.AnimationDecision(allowsTransitions: true, allowsAnimations: false)
      for level in 0 ..< nestingDepth {
        let child = originalViews[level]
        expect(nestedViews[level]) === child
        expect(child.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
        expect(nestedContexts[level]?.updateType) == (level == nestingDepth - 1 ? .insert : .refresh)
        expect(nestedContexts[level]?.animationDecision) == transitionsOnly
        expect(renderTypes[level]) == .refresh(isAnimated: true)
        expect(child.layer().animation(forKey: "bounds.size")) == nil
        expect(child.layer().animation(forKey: "position")) == nil
      }
      expect(outerView.layer().opacity) == 1
      expect(outerView.layer().animation(forKey: "opacity")) != nil
      expect(layers[0]) === retainedLayer
      expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 160, height: 60)
      expect(retainedLayer.cornerRadius) == 16
      expect(retainedLayer.backgroundColor) == Color.red.cgColor
      expect(retainedLayer.animationKeys()) == nil
      expect(layerContexts[0]?.updateType) == .refresh
      expect(layerContexts[0]?.animationTiming) == nil
      expect(layerContexts[0]?.animationDecision) == transitionsOnly

      // then: the newly visible row still runs its insert transition inside the retained subtree
      let insertedLayer = try unwrap(layers[1])
      expect(insertedLayer.superlayer) === retainedLayer.superlayer
      expect(insertedLayer.frame) == CGRect(x: 0, y: 60, width: 160, height: 40)
      expect(insertedLayer.backgroundColor) == Color.blue.cgColor
      expect(insertedLayer.opacity) == 1
      expect(layerContexts[1]?.updateType) == .insert
      expect(layerContexts[1]?.animationTiming) == nil
      expect(layerContexts[1]?.animationDecision) == transitionsOnly
      expect(insertedLayer.animationKeys()) == ["opacity"]
      let insertion = try unwrap(insertedLayer.animation(forKey: "opacity") as? CABasicAnimation)
      expect(insertion.fromValue as? Float) == -1
      expect(insertion.toValue as? Float) == 0
      expect(insertion.duration) == 10
      expect(insertion.isAdditive) == true
    }
  }

  func test_boundsRevival_dynamicChildCannotExceedTheHostDecision() throws {
    // given: a nested view whose dynamic behavior always animates, retaining a row that shrinks when the width grows
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
        .transition(.opacity(timing: timing))
        .willInsert { renderable, _ in
          let child = renderable.view as? ComposeView
          child?.renderablePool = nil
          child?.animationBehavior = .dynamic { _, _ in true }
          child?.onDidRender { _, context in
            childRenderType = context.renderType
          }
        }
        .onUpdate { renderable, _ in
          childView = renderable.view as? ComposeView
        }
        Spacer(height: 400)
      }
    }
    parent.renderablePool = nil
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    parent.refresh(animated: false)
    let child = try unwrap(childView)
    let retainedLayer = try unwrap(layers[0])
    expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 100, height: 120)
    expect(retainedLayer.animationKeys()) == nil
    expect(layers[1]) == nil
    defer {
      child.layer().removeAllAnimations()
      for layer in layers.values {
        layer.removeAllAnimations()
      }
    }

    // when: scrolling the nested view offscreen starts its removal transition
    parent.setContentOffset(CGPoint(x: 0, y: 200))
    parent.layoutIfNeeded()

    // then: the nested view stays mounted during the removal
    expect(child.superview) != nil
    expect(child.layer().animation(forKey: "opacity")) != nil

    // when: the parent resizes while the nested view is still offscreen
    parent.frame.size.width = 160
    parent.setNeedsLayout()
    parent.layoutIfNeeded()

    // then: the retained row has not received the new geometry yet
    expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 100, height: 120)
    layerContexts.removeAll()
    childRenderType = nil

    // when: scrolling back revives the nested view before its removal completes
    parent.setContentOffset(.zero)
    parent.layoutIfNeeded()

    // then: the host's scroll decision caps the nested view's own behavior, so the retained row snaps to its new
    // geometry while the newly visible row still runs its insert transition
    expect(childView) === child
    expect(child.frame) == CGRect(x: 0, y: 0, width: 160, height: 100)
    expect(childRenderType) == .refresh(isAnimated: true)
    expect(layers[0]) === retainedLayer
    expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 160, height: 60)
    expect(retainedLayer.animationKeys()) == nil
    expect(layerContexts[0]?.updateType) == .refresh
    expect(layerContexts[0]?.animationTiming) == nil
    let insertedLayer = try unwrap(layers[1])
    expect(insertedLayer.frame) == CGRect(x: 0, y: 60, width: 160, height: 40)
    expect(insertedLayer.opacity) == 1
    expect(insertedLayer.animationKeys()) == ["opacity"]
    expect(layerContexts[1]?.updateType) == .insert

    // when: the nested view refreshes its own content with animation
    for layer in layers.values {
      layer.removeAllAnimations()
    }
    child.frame.size.width = 200
    child.refresh(animated: true)

    // then: the nested view's own pass is not capped, so the retained row animates its frame
    expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 200, height: 20)
    expect(retainedLayer.animation(forKey: "bounds.size")) != nil
    expect(layerContexts[0]?.updateType) == .refresh
    expect(layerContexts[0]?.animationTiming) == timing
  }

  func test_applicationRefresh_controlsDescendantUpdates_atEveryDepth() throws {
    for nestingDepth in 1 ... 3 {
      for animated in [false, true] {
        // given: a retained descendant with configured frame and attribute animations
        var height: CGFloat = 40
        var radius: CGFloat = 4
        var color = Color.red
        var layer: CALayer?
        let parent = ComposeView {
          var content: any ComposeNode = VStack(spacing: 0) {
            ColorNode(color)
              .frame(width: .flexible, height: height)
              .cornerRadius(radius)
              .animation(.linear(duration: 10))
              .onUpdate { renderable, _ in layer = renderable.layer }
            Spacer(height: 100)
          }
          for _ in 0 ..< nestingDepth {
            let childContent = content
            content = ComposeViewNode { childContent }
              .flexibleSize()
              .frame(width: .flexible, height: 100)
          }
          return content
        }
        parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        parent.refresh(animated: false)
        let retainedLayer = try unwrap(layer)
        expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 100, height: 40)
        expect(retainedLayer.cornerRadius) == 4
        expect(retainedLayer.backgroundColor) == Color.red.cgColor
        expect(retainedLayer.animationKeys()) == nil
        defer { retainedLayer.removeAllAnimations() }

        // when: an application refresh changes the descendant's frame and attributes
        height = 60
        radius = 12
        color = .blue
        parent.refresh(animated: animated)

        // then: the retained layer reaches its target with only the requested animations
        expect(layer) === retainedLayer
        expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 100, height: 60)
        expect(retainedLayer.cornerRadius) == 12
        expect(retainedLayer.backgroundColor) == Color.blue.cgColor
        if animated {
          let frameAnimation = try unwrap(retainedLayer.animation(forKey: "bounds.size") as? CABasicAnimation)
          expect(frameAnimation.fromValue as? CGSize) == CGSize(width: 0, height: -20)
          expect(frameAnimation.toValue as? CGSize) == .zero
          expect(frameAnimation.duration) == 10
          expect(frameAnimation.isAdditive) == true
          let radiusAnimation = try unwrap(retainedLayer.animation(forKey: "cornerRadius") as? CABasicAnimation)
          expect(radiusAnimation.fromValue as? CGFloat) == -8
          expect(radiusAnimation.toValue as? CGFloat) == 0
          expect(radiusAnimation.duration) == 10
          expect(radiusAnimation.isAdditive) == true
        } else {
          expect(retainedLayer.animationKeys()) == nil
        }
      }
    }
  }

  func test_willInsert_disabledChildSuppressesFirstRenderTransitions_atEveryDepth() throws {
    for nestingDepth in 1 ... 3 {
      for usesRefresh in [false, true] {
        // given: a disabled child configured before its first render, with nested insert transitions
        var layer: CALayer?
        let parent = ComposeView {
          var content: any ComposeNode = ColorNode(.red)
            .frame(width: .flexible, height: 100)
            .animation(.linear(duration: 10))
            .transition(.opacity(timing: .linear(duration: 10)))
            .onUpdate { renderable, _ in layer = renderable.layer }
          for _ in 0 ..< nestingDepth {
            let childContent = content
            content = ComposeViewNode { childContent }
          }
          return content.willInsert { renderable, _ in
            (renderable.view as? ComposeView)?.animationBehavior = .disabled
          }
        }
        parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

        // when: an animated application refresh or initial bounds pass inserts the child
        if usesRefresh {
          parent.refresh(animated: true)
        } else {
          parent.setNeedsLayout()
          parent.layoutIfNeeded()
        }

        // then: the deepest content is applied without transitions or update animations
        let renderedLayer = try unwrap(layer)
        expect(renderedLayer.superlayer) != nil
        expect(renderedLayer.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
        expect(renderedLayer.backgroundColor) == Color.red.cgColor
        expect(renderedLayer.opacity) == 1
        expect(renderedLayer.animationKeys()) == nil
      }
    }
  }
}
