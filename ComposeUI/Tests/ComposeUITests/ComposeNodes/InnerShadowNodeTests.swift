//
//  InnerShadowNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/5/25.
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

class InnerShadowNodeTests: XCTestCase {

  func test_init() throws {
    // then: inner shadow nodes can be created with all initializer variants
    // themed + simple path
    _ = InnerShadowNode(
      color: ThemedColor(light: Color.red, dark: Color.blue),
      opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
      radius: Themed<CGFloat>(light: 10, dark: 15),
      offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
      path: { size in
        let rect = CGRect(origin: .zero, size: size)
        return CGPath(rect: rect, transform: nil)
      }
    )

    // themed + paths
    _ = InnerShadowNode(
      color: ThemedColor(light: Color.red, dark: Color.blue),
      opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
      radius: Themed<CGFloat>(light: 10, dark: 15),
      offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
      paths: { size in
        let rect = CGRect(origin: .zero, size: size)
        return InnerShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), clipPath: nil)
      }
    )

    // color + simple path
    _ = InnerShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      path: { size in
        let rect = CGRect(origin: .zero, size: size)
        return CGPath(rect: rect, transform: nil)
      }
    )

    // color + paths
    _ = InnerShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      paths: { size in
        let rect = CGRect(origin: .zero, size: size)
        return InnerShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), clipPath: nil)
      }
    )
  }

  func test_id() throws {
    // given: an inner shadow node
    let node = InnerShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      path: { size in
        let rect = CGRect(origin: .zero, size: size)
        return CGPath(rect: rect, transform: nil)
      }
    )

    // then: the id is "IS"
    expect(node.id.id) == "IS"
  }

  func test_size() throws {
    // given: an inner shadow node
    let node = InnerShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      path: { size in
        let rect = CGRect(origin: .zero, size: size)
        return CGPath(rect: rect, transform: nil)
      }
    )

    // then: the default size is zero
    expect(node.size) == .zero
  }

  func test_layout() throws {
    // given: an inner shadow node
    var node = InnerShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      path: { size in
        let rect = CGRect(origin: .zero, size: size)
        return CGPath(rect: rect, transform: nil)
      }
    )

    // when: laying out in a 100x100 container
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the node is flexible and fills the container
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
    expect(node.size) == CGSize(width: 100, height: 100)
  }

  func test_renderableItems() throws {
    // given: a laid out themed inner shadow node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = InnerShadowNode(
      color: ThemedColor(light: Color.red, dark: Color.blue),
      opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
      radius: Themed<CGFloat>(light: 10, dark: 15),
      offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
      paths: { size in
        let rect = CGRect(origin: .zero, size: size)
        return InnerShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), clipPath: nil)
      }
    )
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when: visible bounds intersects with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)

      // then: a single shadow item is provided with the expected id, frame, and behaviors
      expect(items.count) == 1

      let item = items[0]
      expect(item.id.id) == "IS"
      expect(item.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      // when: making a renderable
      do {
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: nil))

        // then: the layer starts at the initial frame
        expect(renderable.layer.frame) == CGRect(x: 1, y: 2, width: 3, height: 4)
      }

      // updates
      do {
        // given: a renderable in a content view with the light theme
        do {
          let contentView = ComposeView()
          contentView.overrideTheme = .light
          let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

          // when: updating without animation
          do {
            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, previousRenderBounds: .zero, renderBounds: .zero, animationTiming: nil, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)
            item.update(renderable, context)
            let layer = renderable.layer

            // then: the light shadow and its mask are applied without animations
            expect(layer.invertsShadow) == true
            expect(layer.shadowColor) == Color.red.cgColor
            expect(layer.shadowOpacity) == 0.5
            expect(layer.shadowRadius) == 10
            expect(layer.shadowOffset) == CGSize(width: 2, height: 5)
            expect(layer.shadowPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 4), transform: nil)

            expect(layer.animation(forKey: "shadowColor")) == nil
            expect(layer.animation(forKey: "shadowOpacity")) == nil
            expect(layer.animation(forKey: "shadowRadius")) == nil
            expect(layer.animation(forKey: "shadowOffset")) == nil
            expect(layer.animation(forKey: "shadowPath")) == nil

            let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
            expect(maskLayer.frame) == CGRect(x: 0, y: 0, width: 3, height: 4)
            expect(maskLayer.path) == CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 4), transform: nil)
            expect(maskLayer.animation(forKey: "position")) == nil
            expect(maskLayer.animation(forKey: "bounds.size")) == nil
            expect(maskLayer.animation(forKey: "path")) == nil
          }

          // when: updating with animation timing and the same values
          do {
            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, previousRenderBounds: .zero, renderBounds: .zero, animationTiming: .easeInEaseOut(), contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.all)
            item.update(renderable, context)
            let layer = renderable.layer

            // then: nothing changed since the update above, so nothing animates
            expect(layer.shadowColor) == Color.red.cgColor
            expect(layer.shadowOpacity) == 0.5
            expect(layer.shadowRadius) == 10
            expect(layer.shadowOffset) == CGSize(width: 2, height: 5)
            expect(layer.shadowPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 4), transform: nil)
            expect(layer.animationKeys()) == nil

            let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
            expect(maskLayer.frame) == CGRect(x: 0, y: 0, width: 3, height: 4)
            expect(maskLayer.path) == CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 4), transform: nil)
            expect(maskLayer.animationKeys()) == nil
          }

          // given: a fresh renderable
          do {
            let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

            // when: updating with animation timing
            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, previousRenderBounds: .zero, renderBounds: .zero, animationTiming: .easeInEaseOut(), contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.all)
            item.update(renderable, context)
            let layer = renderable.layer

            // then: every shadow property animates from the layer's defaults, and the path shows at once
            expect(layer.invertsShadow) == true
            expect(layer.shadowColor) == Color.red.cgColor
            expect(layer.shadowOpacity) == 0.5
            expect(layer.shadowRadius) == 10
            expect(layer.shadowOffset) == CGSize(width: 2, height: 5)
            expect(layer.shadowPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 4), transform: nil)

            expect(layer.animation(forKey: "shadowColor")) != nil
            expect(layer.animation(forKey: "shadowOpacity")) != nil
            expect(layer.animation(forKey: "shadowRadius")) != nil
            expect(layer.animation(forKey: "shadowOffset")) != nil
            expect(layer.animation(forKey: "shadowPath")) == nil

            // then: the mask's frame and path are set at once, so nothing animates on it
            let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
            expect(maskLayer.frame) == CGRect(x: 0, y: 0, width: 3, height: 4)
            expect(maskLayer.path) == CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 4), transform: nil)
            expect(maskLayer.animationKeys()) == nil
          }
        }

        // given: a renderable in a content view with the dark theme
        do {
          let contentView = ComposeView()
          contentView.overrideTheme = .dark
          let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

          // when: updating without animation
          do {
            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, previousRenderBounds: .zero, renderBounds: .zero, animationTiming: nil, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)
            item.update(renderable, context)
            let layer = renderable.layer

            // then: the dark shadow and its mask are applied without animations
            expect(layer.invertsShadow) == true
            expect(layer.shadowColor) == Color.blue.cgColor
            expect(layer.shadowOpacity) == 0.7
            expect(layer.shadowRadius) == 15
            expect(layer.shadowOffset) == CGSize(width: 3, height: 6)
            expect(layer.shadowPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 4), transform: nil)

            expect(layer.animation(forKey: "shadowColor")) == nil
            expect(layer.animation(forKey: "shadowOpacity")) == nil
            expect(layer.animation(forKey: "shadowRadius")) == nil
            expect(layer.animation(forKey: "shadowOffset")) == nil
            expect(layer.animation(forKey: "shadowPath")) == nil

            let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
            expect(maskLayer.frame) == CGRect(x: 0, y: 0, width: 3, height: 4)
            expect(maskLayer.path) == CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 4), transform: nil)
            expect(maskLayer.animation(forKey: "position")) == nil
            expect(maskLayer.animation(forKey: "bounds.size")) == nil
            expect(maskLayer.animation(forKey: "path")) == nil
          }

          // when: updating with animation timing and the same values
          do {
            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, previousRenderBounds: .zero, renderBounds: .zero, animationTiming: .easeInEaseOut(), contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.all)
            item.update(renderable, context)
            let layer = renderable.layer

            // then: nothing changed since the update above, so nothing animates
            expect(layer.shadowColor) == Color.blue.cgColor
            expect(layer.shadowOpacity) == 0.7
            expect(layer.shadowRadius) == 15
            expect(layer.shadowOffset) == CGSize(width: 3, height: 6)
            expect(layer.shadowPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 4), transform: nil)
            expect(layer.animationKeys()) == nil

            let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
            expect(maskLayer.frame) == CGRect(x: 0, y: 0, width: 3, height: 4)
            expect(maskLayer.path) == CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 4), transform: nil)
            expect(maskLayer.animationKeys()) == nil
          }

          // given: a fresh renderable
          do {
            let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

            // when: updating with animation timing
            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, previousRenderBounds: .zero, renderBounds: .zero, animationTiming: .easeInEaseOut(), contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.all)
            item.update(renderable, context)
            let layer = renderable.layer

            // then: every shadow property animates from the layer's defaults, and the path shows at once
            expect(layer.invertsShadow) == true
            expect(layer.shadowColor) == Color.blue.cgColor
            expect(layer.shadowOpacity) == 0.7
            expect(layer.shadowRadius) == 15
            expect(layer.shadowOffset) == CGSize(width: 3, height: 6)
            expect(layer.shadowPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 4), transform: nil)

            expect(layer.animation(forKey: "shadowColor")) != nil
            expect(layer.animation(forKey: "shadowOpacity")) != nil
            expect(layer.animation(forKey: "shadowRadius")) != nil
            expect(layer.animation(forKey: "shadowOffset")) != nil
            expect(layer.animation(forKey: "shadowPath")) == nil

            // then: the mask's frame and path are set at once, so nothing animates on it
            let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
            expect(maskLayer.frame) == CGRect(x: 0, y: 0, width: 3, height: 4)
            expect(maskLayer.path) == CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 4), transform: nil)
            expect(maskLayer.animationKeys()) == nil
          }
        }

        // given: a renderable in a content view with the light theme, updated by bounds changes
        do {
          let contentView = ComposeView()
          contentView.overrideTheme = .light
          let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

          for animationTiming in [nil, AnimationTiming.easeInEaseOut()] {
            // when: scrolling with or without animation
            let context = RenderableUpdateContext(updateType: .boundsChange, oldFrame: renderable.frame, newFrame: renderable.frame, previousRenderBounds: visibleBounds, renderBounds: visibleBounds.offsetBy(dx: 0, dy: 20), animationTiming: animationTiming, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision(allowsTransitions: animationTiming != nil, allowsAnimations: animationTiming != nil))
            item.update(renderable, context)
            let layer = renderable.layer

            // then: the shadow remains unconfigured without animations
            expect(layer.shadowOpacity) == 0
            expect(layer.shadowRadius) == 3
            expect(layer.shadowOffset) == CGSize(width: 0, height: -3)
            expect(layer.shadowPath) == nil
            expect(layer.mask) == nil
            expect(layer.animationKeys()) == nil
          }

          // when: resizing the viewport without changing the renderable's frame
          do {
            let context = RenderableUpdateContext(updateType: .boundsChange, oldFrame: renderable.frame, newFrame: renderable.frame, previousRenderBounds: visibleBounds.offsetBy(dx: 0, dy: 20), renderBounds: CGRect(x: 0, y: 20, width: 100, height: 60), animationTiming: nil, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)
            item.update(renderable, context)
            let layer = renderable.layer

            // then: the viewport change does not configure the unchanged renderable
            expect(layer.shadowOpacity) == 0
            expect(layer.shadowRadius) == 3
            expect(layer.shadowOffset) == CGSize(width: 0, height: -3)
            expect(layer.shadowPath) == nil
            expect(layer.mask) == nil
            expect(layer.animationKeys()) == nil
          }

          // when: resizing the renderable with unchanged viewport bounds
          do {
            let oldFrame = renderable.frame
            let newFrame = CGRect(x: 1, y: 2, width: 6, height: 8)
            let layer = renderable.layer
            layer.disableActions { layer.frame = newFrame }
            let context = RenderableUpdateContext(updateType: .boundsChange, oldFrame: oldFrame, newFrame: newFrame, previousRenderBounds: visibleBounds, renderBounds: visibleBounds, animationTiming: nil, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)
            item.update(renderable, context)

            // then: the shadow and clip paths use the renderable's new size
            expect(layer.shadowColor) == Color.red.cgColor
            expect(layer.shadowOpacity) == 0.5
            expect(layer.shadowRadius) == 10
            expect(layer.shadowOffset) == CGSize(width: 2, height: 5)
            expect(layer.shadowPath) == CGPath(rect: CGRect(origin: .zero, size: newFrame.size), transform: nil)
            let mask = try unwrap(layer.mask as? CAShapeLayer)
            expect(mask.frame) == CGRect(origin: .zero, size: newFrame.size)
            expect(mask.path) == layer.shadowPath
          }
        }
      }
    }

    // when: visible bounds does not intersect with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 100, width: 100, height: 100)
      let items = node.renderableItems(in: visibleBounds)

      // then: no items are provided
      expect(items.count) == 0
    }
  }

  func test_render_pathsFollowFrame_acrossInterruptedResizes() throws {
    // given: a hosted inner shadow with its hole inset from its clip, whose width animates linearly over a second after
    // a short delay, as explicit begin times keep the frame and the paths in step, see
    // https://github.com/honghaoz/ComposeUI/issues/51
    let window = TestWindow()
    var width: CGFloat = 100
    var layer: CALayer?
    let view = ComposeView {
      InnerShadowNode(color: .black, opacity: 0.5, radius: 4, offset: .zero, paths: { size in
        let bounds = CGRect(origin: .zero, size: size)
        return InnerShadowPaths(shadowPath: CGPath(rect: bounds.insetBy(dx: 5, dy: 5), transform: nil), clipPath: CGPath(rect: bounds, transform: nil))
      })
      .frame(width: width, height: 100)
      .animation(.linear(duration: 1, delay: 0.05))
      .onUpdate { renderable, _ in
        layer = renderable.layer
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    let shadowLayer = try unwrap(layer)
    let mask = try unwrap(shadowLayer.mask as? CAShapeLayer)
    CATransaction.flush()
    expect(shadowLayer.presentation()).toEventuallyNot(beNil())

    // the inverted shadow's path is the hole
    expect(shadowLayer.invertsShadow) == true

    // the shown widths of the layer, its hole, and its clip, which is the mask path
    func shownWidths() throws -> (bounds: CGFloat, hole: CGFloat, clip: CGFloat) {
      let presentation = try unwrap(shadowLayer.presentation())
      return try (
        presentation.bounds.width,
        unwrap(presentation.shadowPath).boundingBoxOfPath.width,
        unwrap(unwrap(mask.presentation()).path).boundingBoxOfPath.width
      )
    }

    func expectOnTheFrame(_ shown: (bounds: CGFloat, hole: CGFloat, clip: CGFloat)) {
      expect(shown.hole).to(beApproximatelyEqual(to: shown.bounds - 10, within: 1))
      expect(shown.clip).to(beApproximatelyEqual(to: shown.bounds, within: 1))
    }

    // when: an animated refresh widens the shadow
    width = 200
    view.refresh(animated: true)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))

    // then: mid-flight, the shown paths are on the shown bounds
    let shownDuringResize = try shownWidths()
    expect(shownDuringResize.bounds) > 105
    expect(shownDuringResize.bounds) < 195
    expectOnTheFrame(shownDuringResize)

    // when: an animated refresh widens the shadow further while the resize is in flight
    width = 250
    view.refresh(animated: true)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))

    // then: the resizes add up, far short of the new width, and the paths stay on the bounds
    let shownDuringInterruption = try shownWidths()
    expect(shownDuringInterruption.bounds) > 105
    expect(shownDuringInterruption.bounds) < 240
    expectOnTheFrame(shownDuringInterruption)

    // when: a non-animated refresh narrows the shadow while both resizes are in flight
    width = 220
    view.refresh(animated: false)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))

    // then: the bounds and the paths change by the same amount at once and keep moving together
    let shownAfterNonAnimatedResize = try shownWidths()
    expect(shownAfterNonAnimatedResize.bounds) > 75
    expect(shownAfterNonAnimatedResize.bounds) < 210
    expectOnTheFrame(shownAfterNonAnimatedResize)

    // then: all land on the new width when the resizes would have ended
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1))
    let shownAtEnd = try shownWidths()
    expect(shownAtEnd.bounds).to(beApproximatelyEqual(to: 220, within: 0.5))
    expectOnTheFrame(shownAtEnd)
  }

  func test_boundsChange_updatesPathsOnlyForRenderableResize() throws {
    for animationTiming in [nil, AnimationTiming.easeInEaseOut()] {
      // given: local shadow and clip paths with an external input that requires refresh
      let window = TestWindow()
      let contentView = ComposeView()
      let viewport = CGRect(x: 0, y: 0, width: 200, height: 200)
      let frame = CGRect(x: 0, y: 0, width: 40, height: 40)
      var inset: CGFloat = 0
      var node = InnerShadowNode(color: .red, opacity: 0.5, radius: 4, offset: .zero, paths: { size in
        let bounds = CGRect(origin: .zero, size: size)
        return InnerShadowPaths(
          shadowPath: CGPath(rect: bounds.insetBy(dx: inset, dy: inset), transform: nil),
          clipPath: CGPath(rect: bounds.insetBy(dx: inset / 2, dy: inset / 2), transform: nil)
        )
      })
      _ = node.layout(containerSize: frame.size, context: ComposeNodeLayoutContext(scaleFactor: 1))
      let item = try unwrap(node.renderableItems(in: frame).first)
      let renderable = item.make(RenderableMakeContext(initialFrame: frame, contentView: contentView))
      let layer = renderable.layer
      window.layer.addSublayer(layer)

      // when: inserting at the already assigned frame
      item.update(renderable, RenderableUpdateContext(updateType: .insert, oldFrame: frame, newFrame: frame, previousRenderBounds: nil, renderBounds: viewport, animationTiming: nil, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled))

      // then: both paths are initialized even though the size did not change
      let initialPath = CGPath(rect: layer.bounds, transform: nil)
      let mask = try unwrap(layer.mask as? CAShapeLayer)
      expect(layer.shadowPath) == initialPath
      expect(mask.path) == initialPath
      expect(layer.shadowColor) == Color.red.cgColor
      CATransaction.flush()
      inset = 2

      // when: only the viewport changes, including missing viewport history
      for previousBounds in [viewport, nil] {
        item.update(renderable, RenderableUpdateContext(updateType: .boundsChange, oldFrame: frame, newFrame: frame, previousRenderBounds: previousBounds, renderBounds: CGRect(x: 0, y: 20, width: 300, height: 250), animationTiming: animationTiming, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision(allowsTransitions: animationTiming != nil, allowsAnimations: animationTiming != nil)))

        // then: both local paths and their animation state remain unchanged
        expect(layer.shadowPath) == initialPath
        expect(mask.path) == initialPath
        expect(layer.animationKeys()) == nil
        expect(mask.animationKeys()) == nil
      }

      // when: the renderable moves without changing size
      let movedFrame = frame.offsetBy(dx: 10, dy: 20)
      layer.disableActions { layer.frame = movedFrame }
      item.update(renderable, RenderableUpdateContext(updateType: .boundsChange, oldFrame: frame, newFrame: movedFrame, previousRenderBounds: viewport, renderBounds: viewport, animationTiming: animationTiming, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision(allowsTransitions: animationTiming != nil, allowsAnimations: animationTiming != nil)))

      // then: position-only updates preserve the paths
      expect(layer.shadowPath) == initialPath
      expect(mask.path) == initialPath
      expect(layer.animationKeys()) == nil
      expect(mask.animationKeys()) == nil

      // when: resizing each dimension without a viewport change, adding to any preceding path animation
      for size in [CGSize(width: 60, height: 40), CGSize(width: 60, height: 80)] {
        let oldFrame = layer.frame
        layer.disableActions { layer.frame.size = size }
        item.update(renderable, RenderableUpdateContext(updateType: .boundsChange, oldFrame: oldFrame, newFrame: layer.frame, previousRenderBounds: viewport, renderBounds: viewport, animationTiming: animationTiming, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision(allowsTransitions: animationTiming != nil, allowsAnimations: animationTiming != nil)))

        // then: shadow and clip paths use the new local bounds
        let expectedPath = CGPath(rect: layer.bounds.insetBy(dx: inset, dy: inset), transform: nil)
        let expectedClipPath = CGPath(rect: layer.bounds.insetBy(dx: inset / 2, dy: inset / 2), transform: nil)
        expect(layer.shadowPath) == expectedPath
        expect(mask.path) == expectedClipPath
        expect(mask.frame) == layer.bounds
        if animationTiming != nil {
          // no resize has begun, so the paths animate from the paths before the resizes to the new size's paths
          let shadowPathEnds = try pathEnds(of: unwrap(layer.animation(forKey: "shadowPath")))
          let maskPathEnds = try pathEnds(of: unwrap(mask.animation(forKey: "path")))
          expect(PathPoints(shadowPathEnds.from)) == PathPoints(initialPath)
          expect(shadowPathEnds.to) == expectedPath
          expect(PathPoints(maskPathEnds.from)) == PathPoints(initialPath)
          expect(maskPathEnds.to) == expectedClipPath
        } else {
          expect(layer.animation(forKey: "shadowPath")) == nil
          expect(mask.animation(forKey: "path")) == nil
        }
      }

      // when: explicit refresh changes an external input without changing size
      inset = 4
      item.update(renderable, RenderableUpdateContext(updateType: .refresh, oldFrame: layer.frame, newFrame: layer.frame, previousRenderBounds: viewport, renderBounds: viewport, animationTiming: animationTiming, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision(allowsTransitions: animationTiming != nil, allowsAnimations: animationTiming != nil)))

      // then: refresh applies both paths independently of size changes
      expect(layer.shadowPath) == CGPath(rect: layer.bounds.insetBy(dx: inset, dy: inset), transform: nil)
      expect(mask.path) == CGPath(rect: layer.bounds.insetBy(dx: inset / 2, dy: inset / 2), transform: nil)
      expect(layer.shadowColor) == Color.red.cgColor
      layer.removeAllAnimations()
      mask.removeAllAnimations()
    }
  }

  func test_overlay() throws {
    // given: a laid out color node with an inner shadow (themed + simple path)
    do {
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      var node = ColorNode(.red)
        .innerShadow(
          color: ThemedColor(light: Color.red, dark: Color.blue),
          opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
          radius: Themed<CGFloat>(light: 10, dark: 15),
          offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
          path: { size in
            let rect = CGRect(origin: .zero, size: size)
            return CGPath(rect: rect, transform: nil)
          }
        )
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // when: requesting renderable items
      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))

      // then: host and shadow items are provided in order
      expect(items.count) == 2

      let hostItem = items[0]
      expect(hostItem.id.id) == "OV|C"
      expect(hostItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      let shadowItem = items[1]
      expect(shadowItem.id.id) == "OV|O|IS"
      expect(shadowItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    }

    // given: a laid out color node with an inner shadow (themed + paths)
    do {
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      var node = ColorNode(.red)
        .innerShadow(
          color: ThemedColor(light: Color.red, dark: Color.blue),
          opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
          radius: Themed<CGFloat>(light: 10, dark: 15),
          offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
          paths: { size in
            let rect = CGRect(origin: .zero, size: size)
            return InnerShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), clipPath: nil)
          }
        )
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // when: requesting renderable items
      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))

      // then: host and shadow items are provided in order
      expect(items.count) == 2

      let hostItem = items[0]
      expect(hostItem.id.id) == "OV|C"
      expect(hostItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      let shadowItem = items[1]
      expect(shadowItem.id.id) == "OV|O|IS"
      expect(shadowItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    }

    // given: a laid out color node with an inner shadow (color + simple path)
    do {
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      var node = ColorNode(.red)
        .innerShadow(
          color: .black,
          opacity: 0.5,
          radius: 10,
          offset: CGSize(width: 2, height: 5),
          path: { size in
            let rect = CGRect(origin: .zero, size: size)
            return CGPath(rect: rect, transform: nil)
          }
        )
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // when: requesting renderable items
      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))

      // then: host and shadow items are provided in order
      expect(items.count) == 2

      let hostItem = items[0]
      expect(hostItem.id.id) == "OV|C"
      expect(hostItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      let shadowItem = items[1]
      expect(shadowItem.id.id) == "OV|O|IS"
      expect(shadowItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    }

    // given: a laid out color node with an inner shadow (color + paths)
    do {
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      var node = ColorNode(.red)
        .innerShadow(
          color: .black,
          opacity: 0.5,
          radius: 10,
          offset: CGSize(width: 2, height: 5),
          paths: { size in
            let rect = CGRect(origin: .zero, size: size)
            return InnerShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), clipPath: nil)
          }
        )
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // when: requesting renderable items
      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))

      // then: host and shadow items are provided in order
      expect(items.count) == 2

      let hostItem = items[0]
      expect(hostItem.id.id) == "OV|C"
      expect(hostItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      let shadowItem = items[1]
      expect(shadowItem.id.id) == "OV|O|IS"
      expect(shadowItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    }
  }

  func test() throws {
    // given: a compose view with two inner shadow nodes in a vstack
    let view = ComposeView {
      VStack {
        InnerShadowNode(color: .black, opacity: 0.5, radius: 10, offset: CGSize(width: 2, height: 5), path: { size in
          CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: 4, cornerHeight: 4, transform: nil)
        })

        InnerShadowNode(color: .black, opacity: 0.5, radius: 10, offset: CGSize(width: 2, height: 5), paths: { size in
          let shadowPath = CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: 4, cornerHeight: 4, transform: nil)
          let clipPath = CGPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 10, dy: 10), cornerWidth: 4, cornerHeight: 4, transform: nil)
          return InnerShadowPaths(shadowPath: shadowPath, clipPath: clipPath)
        })
      }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the view is refreshed
    view.refresh()

    // then: the first inner shadow layer is configured with a full clip mask
    #if canImport(AppKit)
    let shadowLayer1 = try unwrap(view.contentView().layer?.sublayers?[0])
    #endif
    #if canImport(UIKit)
    let shadowLayer1 = try unwrap(view.contentView().layer.sublayers?[0])
    #endif

    expect(shadowLayer1.shadowColor) == Color.black.cgColor
    expect(shadowLayer1.shadowOpacity) == 0.5
    expect(shadowLayer1.shadowRadius) == 10
    expect(shadowLayer1.shadowOffset) == CGSize(width: 2, height: 5)
    expect(shadowLayer1.shadowPath) != nil
    expect(shadowLayer1.invertsShadow) == true

    let maskLayer1 = try unwrap(shadowLayer1.mask as? CAShapeLayer)
    expect(maskLayer1.path) == CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 50), cornerWidth: 4, cornerHeight: 4, transform: nil)

    // then: the second inner shadow layer is configured with an inset clip mask
    #if canImport(AppKit)
    let shadowLayer2 = try unwrap(view.contentView().layer?.sublayers?[1])
    #endif
    #if canImport(UIKit)
    let shadowLayer2 = try unwrap(view.contentView().layer.sublayers?[1])
    #endif

    expect(shadowLayer2.shadowColor) == Color.black.cgColor
    expect(shadowLayer2.shadowOpacity) == 0.5
    expect(shadowLayer2.shadowRadius) == 10
    expect(shadowLayer2.shadowOffset) == CGSize(width: 2, height: 5)
    expect(shadowLayer2.shadowPath) != nil
    expect(shadowLayer1.invertsShadow) == true

    let maskLayer2 = try unwrap(shadowLayer2.mask as? CAShapeLayer)
    expect(maskLayer2.path) == CGPath(roundedRect: CGRect(x: 10, y: 10, width: 80, height: 30), cornerWidth: 4, cornerHeight: 4, transform: nil)
  }

  func test_renderableItems_doesNotRetainNodeThroughItemCache() {
    // The cached item's `update` closure must not capture `self` (the node): the node holds the item cache, so capturing
    // `self` would form `itemCache -> cachedItem -> update -> self -> itemCache`, a retain cycle that leaks the node and
    // everything it captures when the node tree is replaced (refresh / size change).

    // given: a node whose path closure captures a probe object
    weak var weakProbe: AnyObject?
    do {
      let probe = NSObject()
      weakProbe = probe
      var node: any ComposeNode = InnerShadowNode(color: .black, opacity: 0.5, radius: 4, offset: .zero, path: { size in
        _ = probe // captured by the node's path closure; only reachable from the cached update closure if it captures `self`
        return CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
      })

      // when: laying out and populating the item cache, and the node goes out of scope
      _ = node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
      _ = node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10)) // populates the item cache
    }

    // then: the probe is released, the cached item does not retain the node
    expect(weakProbe).to(beNil())
  }

  // MARK: - Helpers

  /// The first and last paths of a basic or keyframe animation of paths.
  private func pathEnds(of animation: CAAnimation) throws -> (from: CGPath, to: CGPath) {
    let ends: (from: Any?, to: Any?)
    if let basicAnimation = animation as? CABasicAnimation {
      ends = (basicAnimation.fromValue, basicAnimation.toValue)
    } else {
      let values = try unwrap((animation as? CAKeyframeAnimation)?.values)
      ends = (values.first, values.last)
    }
    // a Core Foundation type can't be checked at runtime, so the casts are forced
    return try (unwrap(ends.from) as! CGPath, unwrap(ends.to) as! CGPath) // swiftlint:disable:this force_cast
  }
}
