//
//  DropShadowNodeTests.swift
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

class DropShadowNodeTests: XCTestCase {

  func test_init() throws {
    // then: drop shadow nodes can be created with all initializer variants
    // themed + simple path
    _ = DropShadowNode(
      color: ThemedColor(light: Color.red, dark: Color.blue),
      opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
      radius: Themed<CGFloat>(light: 10, dark: 15),
      offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
      path: { size in
        let rect = CGRect(origin: .zero, size: size)
        return CGPath(rect: rect, transform: nil)
      }
    )

    // themed + shadow paths
    _ = DropShadowNode(
      color: ThemedColor(light: Color.red, dark: Color.blue),
      opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
      radius: Themed<CGFloat>(light: 10, dark: 15),
      offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
      paths: { size in
        let rect = CGRect(origin: .zero, size: size)
        return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: nil)
      }
    )

    // color + simple path
    _ = DropShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      path: { size in
        let rect = CGRect(origin: .zero, size: size)
        return CGPath(rect: rect, transform: nil)
      }
    )

    // color + shadow paths
    _ = DropShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      paths: { size in
        let rect = CGRect(origin: .zero, size: size)
        return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: nil)
      }
    )
  }

  func test_id() throws {
    // given: a drop shadow node
    let node = DropShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      paths: { size in
        let rect = CGRect(origin: .zero, size: size)
        return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: nil)
      }
    )

    // then: the id is "DS"
    expect(node.id.id) == "DS"
  }

  func test_size() throws {
    // given: a drop shadow node
    let node = DropShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      paths: { size in
        let rect = CGRect(origin: .zero, size: size)
        return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: nil)
      }
    )

    // then: the default size is zero
    expect(node.size) == .zero
  }

  func test_layout() throws {
    // given: a drop shadow node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = DropShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      paths: { size in
        let rect = CGRect(origin: .zero, size: size)
        return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: nil)
      }
    )

    // when: laying out in a 100x100 container
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the node is flexible and fills the container
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
    expect(node.size) == CGSize(width: 100, height: 100)
  }

  func test_renderableItems() throws {
    // given: a laid out themed drop shadow node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = DropShadowNode(
      color: ThemedColor(light: Color.red, dark: Color.blue),
      opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
      radius: Themed<CGFloat>(light: 10, dark: 15),
      offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
      paths: { size in
        let rect = CGRect(origin: .zero, size: size)
        return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: nil)
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
      expect(item.id.id) == "DS"
      expect(item.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      // when: making a renderable
      do {
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: nil))

        // then: the layer starts at the initial frame
        expect(renderable.layer.frame) == CGRect(x: 1, y: 2, width: 3, height: 4)
      }

      expect(item.willInsert) == nil
      expect(item.didInsert) == nil
      expect(item.willUpdate) == nil

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

            // then: the light shadow is applied without animations
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
          }

          // given: a fresh renderable
          do {
            let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

            // when: updating with animation timing
            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, previousRenderBounds: .zero, renderBounds: .zero, animationTiming: .easeInEaseOut(), contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.all)
            item.update(renderable, context)
            let layer = renderable.layer

            // then: every shadow property animates from the layer's defaults, and the path shows at once
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

            // then: the dark shadow is applied without animations
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
          }

          // given: a fresh renderable
          do {
            let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

            // when: updating with animation timing
            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, previousRenderBounds: .zero, renderBounds: .zero, animationTiming: .easeInEaseOut(), contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.all)
            item.update(renderable, context)
            let layer = renderable.layer

            // then: every shadow property animates from the layer's defaults, and the path shows at once
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

            // then: the shadow path and configuration are applied to the new size
            expect(layer.shadowColor) == Color.red.cgColor
            expect(layer.shadowOpacity) == 0.5
            expect(layer.shadowRadius) == 10
            expect(layer.shadowOffset) == CGSize(width: 2, height: 5)
            expect(layer.shadowPath) == CGPath(rect: CGRect(origin: .zero, size: newFrame.size), transform: nil)
          }
        }
      }

      expect(item.willRemove) == nil
      expect(item.didRemove) == nil
      expect(item.transition) == nil
      expect(item.animationTiming) == nil
    }

    // when: visible bounds does not intersect with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 100, width: 100, height: 100)
      let items = node.renderableItems(in: visibleBounds)

      // then: no items are provided
      expect(items.count) == 0
    }
  }

  func test_update_withoutAnimation_continuesInFlightAnimations() throws {
    // given: a themed drop shadow node rendered in the light theme, then animated towards the dark theme
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = DropShadowNode(
      color: ThemedColor(light: Color.red, dark: Color.blue),
      opacity: Themed<CGFloat>(0.5),
      radius: Themed<CGFloat>(light: 10, dark: 20),
      offset: Themed<CGSize>(.zero),
      paths: { size in
        DropShadowPaths(shadowPath: CGPath(rect: CGRect(origin: .zero, size: size), transform: nil), cutoutPath: nil)
      }
    )
    let viewport = CGRect(x: 0, y: 0, width: 100, height: 100)
    _ = node.layout(containerSize: viewport.size, context: context)
    let item = try node.renderableItems(in: viewport).first.unwrap()

    let contentView = ComposeView()
    contentView.overrideTheme = .light
    let renderable = item.make(RenderableMakeContext(initialFrame: viewport, contentView: contentView))
    let layer = renderable.layer

    func update(animationTiming: AnimationTiming?) {
      let animationDecision = animationTiming == nil ? ComposeView.AnimationDecision.disabled : ComposeView.AnimationDecision.all
      item.update(renderable, RenderableUpdateContext(updateType: .refresh, oldFrame: viewport, newFrame: viewport, previousRenderBounds: viewport, renderBounds: viewport, animationTiming: animationTiming, contentView: contentView, contentEvaluation: nil, animationDecision: animationDecision))
    }

    update(animationTiming: nil)
    contentView.overrideTheme = .dark
    update(animationTiming: .linear(duration: 10))
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor", "shadowRadius"]

    // when: the theme flips back and the node is refreshed without animation
    contentView.overrideTheme = .light
    update(animationTiming: nil)

    // then: the model has the light shadow. the radius animation hasn't begun, so the radius still shows the light
    // value: the animation is removed and nothing glides. the color animation is retargeted over its remaining time
    // instead of finishing towards the dark one
    expect(layer.shadowColor) == Color.red.cgColor
    expect(layer.shadowRadius) == 10
    expect(Set(layer.animationKeys() ?? [])) == ["shadowColor"]

    let colorAnimation = try (layer.animation(forKey: "shadowColor") as? CABasicAnimation).unwrap()
    expect(colorAnimation.duration) == 10
    expect(colorAnimation.timingFunction) == CAMediaTimingFunction(name: .easeOut)
    // a Core Foundation type can't be checked at runtime, so the cast is forced
    expect(colorAnimation.toValue as! CGColor) == Color.red.cgColor // swiftlint:disable:this force_cast
  }

  func test_render_pathsFollowFrame_acrossInterruptedResizes() throws {
    // given: a hosted drop shadow with a cutout, whose width animates linearly over a second after a short delay, as
    // explicit begin times keep the frame and the paths in step, see https://github.com/honghaoz/ComposeUI/issues/51
    let window = TestWindow()
    var width: CGFloat = 100
    var layer: CALayer?
    let view = ComposeView {
      DropShadowNode(color: .black, opacity: 0.5, radius: 4, offset: .zero, paths: { size in
        let bounds = CGRect(origin: .zero, size: size)
        return DropShadowPaths(shadowPath: CGPath(rect: bounds, transform: nil), cutoutPath: CGPath(rect: bounds.insetBy(dx: 10, dy: 10), transform: nil))
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

    // the shown widths of the layer, its shadow path, and the cutout, which the mask path pads by a million points
    func shownWidths() throws -> (bounds: CGFloat, shadowPath: CGFloat, cutout: CGFloat) {
      let presentation = try unwrap(shadowLayer.presentation())
      let maskPath = try unwrap(unwrap(mask.presentation()).path)
      return try (
        presentation.bounds.width,
        unwrap(presentation.shadowPath).boundingBoxOfPath.width,
        maskPath.boundingBoxOfPath.width - 2000000
      )
    }

    func expectOnTheFrame(_ shown: (bounds: CGFloat, shadowPath: CGFloat, cutout: CGFloat)) {
      expect(shown.shadowPath).to(beApproximatelyEqual(to: shown.bounds, within: 1))
      expect(shown.cutout).to(beApproximatelyEqual(to: shown.bounds - 20, within: 1))
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
      // given: a shadow with local paths and an external path input that requires refresh
      let window = TestWindow()
      let contentView = ComposeView()
      let viewport = CGRect(x: 0, y: 0, width: 200, height: 200)
      let frame = CGRect(x: 0, y: 0, width: 40, height: 40)
      var inset: CGFloat = 0
      var node = DropShadowNode(color: .red, opacity: 0.5, radius: 4, offset: .zero, paths: { size in
        let path = CGPath(rect: CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset), transform: nil)
        return DropShadowPaths(shadowPath: path, cutoutPath: path)
      })
      _ = node.layout(containerSize: frame.size, context: ComposeNodeLayoutContext(scaleFactor: 1))
      let item = try unwrap(node.renderableItems(in: frame).first)
      let renderable = item.make(RenderableMakeContext(initialFrame: frame, contentView: contentView))
      let layer = renderable.layer
      window.layer.addSublayer(layer)

      // when: inserting at the already assigned frame
      item.update(renderable, RenderableUpdateContext(updateType: .insert, oldFrame: frame, newFrame: frame, previousRenderBounds: nil, renderBounds: viewport, animationTiming: nil, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled))

      // then: insertion initializes the shadow even though its size did not change
      let initialPath = CGPath(rect: layer.bounds, transform: nil)
      let mask = try unwrap(layer.mask as? CAShapeLayer)
      expect(layer.shadowPath) == initialPath
      expect(layer.shadowColor) == Color.red.cgColor
      expect(layer.shadowOpacity) == 0.5
      let initialMaskPath = try unwrap(mask.path)
      CATransaction.flush()
      inset = 2

      // when: only the viewport changes, including missing viewport history
      for previousBounds in [viewport, nil] {
        item.update(renderable, RenderableUpdateContext(updateType: .boundsChange, oldFrame: frame, newFrame: frame, previousRenderBounds: previousBounds, renderBounds: CGRect(x: 0, y: 20, width: 300, height: 250), animationTiming: animationTiming, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision(allowsTransitions: animationTiming != nil, allowsAnimations: animationTiming != nil)))

        // then: external input changes do not alter the shadow or start animations
        expect(layer.shadowPath) == initialPath
        expect(mask.path) == initialMaskPath
        expect(layer.animationKeys()) == nil
        expect(mask.animationKeys()) == nil
      }

      // when: the renderable moves without changing size
      let movedFrame = frame.offsetBy(dx: 10, dy: 20)
      layer.disableActions { layer.frame = movedFrame }
      item.update(renderable, RenderableUpdateContext(updateType: .boundsChange, oldFrame: frame, newFrame: movedFrame, previousRenderBounds: viewport, renderBounds: viewport, animationTiming: animationTiming, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision(allowsTransitions: animationTiming != nil, allowsAnimations: animationTiming != nil)))

      // then: local paths remain unchanged during position-only updates
      expect(layer.shadowPath) == initialPath
      expect(mask.path) == initialMaskPath
      expect(layer.animationKeys()) == nil
      expect(mask.animationKeys()) == nil

      // when: resizing each dimension without a viewport change, adding to any preceding path animation
      for size in [CGSize(width: 60, height: 40), CGSize(width: 60, height: 80)] {
        let oldFrame = layer.frame
        layer.disableActions { layer.frame.size = size }
        item.update(renderable, RenderableUpdateContext(updateType: .boundsChange, oldFrame: oldFrame, newFrame: layer.frame, previousRenderBounds: viewport, renderBounds: viewport, animationTiming: animationTiming, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision(allowsTransitions: animationTiming != nil, allowsAnimations: animationTiming != nil)))

        // then: the new size and external path input are applied
        let expectedPath = CGPath(rect: layer.bounds.insetBy(dx: inset, dy: inset), transform: nil)
        expect(layer.shadowPath) == expectedPath
        expect(mask.frame) == layer.bounds
        expect(mask.path?.contains(CGPoint(x: inset / 2, y: size.height / 2), using: .evenOdd)) == true
        expect(mask.path?.contains(CGPoint(x: size.width / 2, y: size.height / 2), using: .evenOdd)) == false
        if animationTiming != nil {
          // no resize has begun, so the paths animate from the paths before the resizes to the new size's paths
          let shadowPathEnds = try pathEnds(of: unwrap(layer.animation(forKey: "shadowPath")))
          let maskPathEnds = try pathEnds(of: unwrap(mask.animation(forKey: "path")))
          expect(PathPoints(shadowPathEnds.from)) == PathPoints(initialPath)
          expect(shadowPathEnds.to) == expectedPath
          expect(PathPoints(maskPathEnds.from)) == PathPoints(initialMaskPath)
          expect(mask.path) == maskPathEnds.to
        } else {
          expect(layer.animation(forKey: "shadowPath")) == nil
          expect(mask.animation(forKey: "path")) == nil
        }
      }

      // when: explicit refresh changes an external input with the same renderable and viewport sizes
      inset = 4
      item.update(renderable, RenderableUpdateContext(updateType: .refresh, oldFrame: layer.frame, newFrame: layer.frame, previousRenderBounds: viewport, renderBounds: viewport, animationTiming: animationTiming, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision(allowsTransitions: animationTiming != nil, allowsAnimations: animationTiming != nil)))

      // then: refresh recalculates the supplied paths independently of size changes
      expect(layer.shadowPath) == CGPath(rect: layer.bounds.insetBy(dx: inset, dy: inset), transform: nil)
      expect(layer.shadowColor) == Color.red.cgColor
      expect(mask.path?.contains(CGPoint(x: 3, y: layer.bounds.midY), using: .evenOdd)) == true
      expect(mask.path?.contains(CGPoint(x: layer.bounds.midX, y: layer.bounds.midY), using: .evenOdd)) == false
      expect(layer.animation(forKey: "shadowPath") != nil) == (animationTiming != nil)
      layer.removeAllAnimations()
      mask.removeAllAnimations()
    }
  }

  func test_underlay() throws {
    // given: a laid out color node with a drop shadow (themed + simple path)
    do {
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      var node = ColorNode(.red)
        .dropShadow(
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

      // then: shadow and host items are provided in order
      expect(items.count) == 2

      let shadowItem = items[0]
      expect(shadowItem.id.id) == "UL|U|DS"
      expect(shadowItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      let hostItem = items[1]
      expect(hostItem.id.id) == "UL|C"
      expect(hostItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    }

    // given: a laid out color node with a drop shadow (themed + shadow paths)
    do {
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      var node = ColorNode(.red)
        .dropShadow(
          color: ThemedColor(light: Color.red, dark: Color.blue),
          opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
          radius: Themed<CGFloat>(light: 10, dark: 15),
          offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
          paths: { size in
            let rect = CGRect(origin: .zero, size: size)
            return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: nil)
          }
        )
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // when: requesting renderable items
      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))

      // then: shadow and host items are provided in order
      expect(items.count) == 2

      let shadowItem = items[0]
      expect(shadowItem.id.id) == "UL|U|DS"
      expect(shadowItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      let hostItem = items[1]
      expect(hostItem.id.id) == "UL|C"
      expect(hostItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    }

    // given: a laid out color node with a drop shadow (color + simple path)
    do {
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      var node = ColorNode(.red)
        .dropShadow(
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

      // then: shadow and host items are provided in order
      expect(items.count) == 2

      let shadowItem = items[0]
      expect(shadowItem.id.id) == "UL|U|DS"
      expect(shadowItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      let hostItem = items[1]
      expect(hostItem.id.id) == "UL|C"
      expect(hostItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    }

    // given: a laid out color node with a drop shadow (color + shadow paths)
    do {
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      var node = ColorNode(.red)
        .dropShadow(
          color: .black,
          opacity: 0.5,
          radius: 10,
          offset: CGSize(width: 2, height: 5),
          paths: { size in
            let rect = CGRect(origin: .zero, size: size)
            return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: nil)
          }
        )
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // when: requesting renderable items
      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))

      // then: shadow and host items are provided in order
      expect(items.count) == 2

      let shadowItem = items[0]
      expect(shadowItem.id.id) == "UL|U|DS"
      expect(shadowItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      let hostItem = items[1]
      expect(hostItem.id.id) == "UL|C"
      expect(hostItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    }
  }

  func test() throws {
    // given: a compose view with two drop shadow nodes in a vstack
    let view = ComposeView {
      VStack {
        DropShadowNode(color: .black, opacity: 0.5, radius: 10, offset: CGSize(width: 2, height: 5), path: { size in
          CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: 4, cornerHeight: 4, transform: nil)
        })

        DropShadowNode(color: .black, opacity: 0.5, radius: 10, offset: CGSize(width: 2, height: 5), paths: { size in
          let shadowPath = CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: 4, cornerHeight: 4, transform: nil)
          let cutoutPath = CGPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 10, dy: 10), cornerWidth: 4, cornerHeight: 4, transform: nil)
          return DropShadowPaths(shadowPath: shadowPath, cutoutPath: cutoutPath)
        })
      }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the view is refreshed
    view.refresh()

    // then: the first shadow layer is configured with the shadow path
    #if canImport(AppKit)
    let shadowLayer1 = try unwrap(view.contentView().layer?.sublayers?.first)
    #endif
    #if canImport(UIKit)
    let shadowLayer1 = try unwrap(view.contentView().layer.sublayers?.first)
    #endif

    expect(shadowLayer1.shadowColor) == Color.black.cgColor
    expect(shadowLayer1.shadowOpacity) == 0.5
    expect(shadowLayer1.shadowRadius) == 10
    expect(shadowLayer1.shadowOffset) == CGSize(width: 2, height: 5)
    expect(shadowLayer1.shadowPath) == CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 50), cornerWidth: 4, cornerHeight: 4, transform: nil)

    // then: the second shadow layer is configured with a cutout mask
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
    expect(shadowLayer2.shadowPath) == CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 50), cornerWidth: 4, cornerHeight: 4, transform: nil)

    let maskLayer = try unwrap(shadowLayer2.mask as? CAShapeLayer)
    expect(maskLayer.fillRule) == .evenOdd

    let cutoutPath = CGPath(roundedRect: CGRect(x: 10, y: 10, width: 80, height: 30), cornerWidth: 4, cornerHeight: 4, transform: nil)

    // the mask is a rect reaching a million points past the cutout, with the cutout punched out
    let biggerBounds = cutoutPath.boundingBoxOfPath.insetBy(dx: -1000000, dy: -1000000)

    let biggerPath = CGMutablePath()
    biggerPath.addPath(CGPath(rect: biggerBounds, transform: nil))
    biggerPath.addPath(cutoutPath)
    expect(maskLayer.path) == biggerPath
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
      var node: any ComposeNode = DropShadowNode(color: .black, opacity: 0.5, radius: 4, offset: .zero, path: { size in
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
