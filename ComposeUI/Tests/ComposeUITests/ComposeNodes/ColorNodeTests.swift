//
//  ColorNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/2/25.
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

class ColorNodeTests: XCTestCase {

  func test_init() throws {
    // then: color nodes can be created with plain and themed colors
    _ = ColorNode(.red)
    _ = ColorNode(ThemedColor(light: .red, dark: .blue))
  }

  func test_id() throws {
    // then: the id is "C"
    expect(ColorNode(.red).id.id) == "C"
  }

  func test_size() throws {
    // then: the default size is zero
    expect(ColorNode(.red).size) == .zero
  }

  func test_layout() throws {
    // given: a color node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ColorNode(.red)

    // when: laying out in a 100x100 container
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the node is flexible and fills the container
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
    expect(node.size) == CGSize(width: 100, height: 100)
  }

  func test_renderableItems() throws {
    // given: a laid out themed color node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ColorNode(ThemedColor(light: .red, dark: .blue))
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when: visible bounds intersects with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)

      // then: a single color item is provided with the expected id, frame, and behaviors
      expect(items.count) == 1

      let item = items[0]
      expect(item.id.id) == "C"
      expect(item.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      // make
      do {
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: nil))
        expect(renderable.layer.frame) == CGRect(x: 1, y: 2, width: 3, height: 4)
      }

      expect(item.willInsert) == nil
      expect(item.didInsert) == nil
      expect(item.willUpdate) == nil

      // update
      do {
        // when with light theme
        do {
          let contentView = ComposeView()
          contentView.overrideTheme = .light
          let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

          // without animations
          do {
            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
            item.update(renderable, context)
            let layer = renderable.layer
            expect(layer.backgroundColor) == Color.red.cgColor
            expect(layer.animation(forKey: "backgroundColor")) == nil
          }

          // with animations
          do {
            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: .easeInEaseOut(), contentView: contentView)
            item.update(renderable, context)
            let layer = renderable.layer
            expect(layer.backgroundColor) == Color.red.cgColor

            let animation = try (layer.animation(forKey: "backgroundColor") as? CABasicAnimation).unwrap()
            expect(animation.duration) == Animations.defaultAnimationDuration
            expect(animation.toValue as! CGColor) == Color.red.cgColor // swiftlint:disable:this force_cast
          }
        }

        // when with dark theme
        do {
          let contentView = ComposeView()
          contentView.overrideTheme = .dark
          let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

          // without animations
          do {
            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
            item.update(renderable, context)
            let layer = renderable.layer
            expect(layer.backgroundColor) == Color.blue.cgColor
            expect(layer.animation(forKey: "backgroundColor")) == nil
          }

          // with animations
          do {
            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: .easeInEaseOut(), contentView: contentView)
            item.update(renderable, context)
            let layer = renderable.layer
            expect(layer.backgroundColor) == Color.blue.cgColor

            let animation = try (layer.animation(forKey: "backgroundColor") as? CABasicAnimation).unwrap()
            expect(animation.duration) == Animations.defaultAnimationDuration
            expect(animation.toValue as! CGColor) == Color.blue.cgColor // swiftlint:disable:this force_cast
          }
        }
      }

      // update with various update types
      do {
        // given: an unconfigured renderable in the light theme
        let contentView = ComposeView()
        contentView.overrideTheme = .light
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

        // when: updating for a scroll
        item.update(renderable, RenderableUpdateContext(updateType: .scroll, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView))

        // then: the background color is not applied
        expect(renderable.layer.backgroundColor) == nil

        // when: updating for a bounds change
        item.update(renderable, RenderableUpdateContext(updateType: .boundsChange, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView))

        // then: geometry updates do not initialize configuration
        expect(renderable.layer.backgroundColor) == nil

        // when: inserting the renderable
        item.update(renderable, RenderableUpdateContext(updateType: .insert, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView))

        // then: insertion applies the configured color
        expect(renderable.layer.backgroundColor) == Color.red.cgColor

        // given: a different theme before refresh
        contentView.overrideTheme = .dark
        for updateType in [RenderableUpdateType.scroll, .boundsChange] {
          // when: updating geometry with an animation timing
          item.update(renderable, RenderableUpdateContext(updateType: updateType, oldFrame: .zero, newFrame: .zero, animationTiming: .easeInEaseOut(), contentView: contentView))

          // then: geometry updates retain the applied color without animation
          expect(renderable.layer.backgroundColor) == Color.red.cgColor
          expect(renderable.layer.animation(forKey: "backgroundColor")) == nil
        }

        // when: refreshing with the different theme
        item.update(renderable, RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView))

        // then: the background color reflects the current theme
        expect(renderable.layer.backgroundColor) == Color.blue.cgColor
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

  func test_boundsChange_retainsColor_withUnchangedItemFrame() throws {
    // given: a fixed-size color node configured from the container width
    var renderedLayer: CALayer?
    var updateType: RenderableUpdateType?
    let contentView = ComposeView { contentView in
      let color: Color = contentView.bounds().width < 150 ? .red : .blue
      ColorNode(color)
        .fixedId("color")
        .frame(width: 40, height: 40)
        .alignment(.topLeft)
        .onUpdate { renderable, context in
          renderedLayer = renderable.layer
          updateType = context.updateType
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: rendering in the narrow container
    contentView.refresh(animated: false)

    // then: insertion initializes the fixed-size layer with the narrow color
    let layer = try renderedLayer.unwrap()
    let itemFrame = CGRect(x: 0, y: 0, width: 40, height: 40)
    expect(updateType) == .insert
    expect(layer.frame) == itemFrame
    expect(layer.backgroundColor) == Color.red.cgColor

    // when: resizing the container without refreshing explicitly
    contentView.frame.size.width = 200
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: the same layer retains its configured color and frame
    expect(updateType) == .boundsChange
    expect(renderedLayer === layer) == true
    expect(layer.frame) == itemFrame
    expect(layer.backgroundColor) == Color.red.cgColor

    // when: refreshing content at the new container size
    contentView.refresh(animated: false)

    // then: refresh applies the new color to the same layer
    expect(updateType) == .refresh
    expect(renderedLayer === layer) == true
    expect(layer.frame) == itemFrame
    expect(layer.backgroundColor) == Color.blue.cgColor
  }

  func test_boundsChange_retainsColor_andInitializesNewlyVisibleItem() throws {
    // given: two flexible-width rows sharing a configured color
    var color = Color.red
    var firstLayer: CALayer?
    var secondLayer: CALayer?
    let contentView = ComposeView {
      VStack {
        ColorNode(color)
          .fixedId("first")
          .frame(width: .flexible, height: 120)
          .onUpdate { renderable, _ in
            firstLayer = renderable.layer
          }
        ColorNode(color)
          .fixedId("second")
          .frame(width: .flexible, height: 120)
          .onUpdate { renderable, _ in
            secondLayer = renderable.layer
          }
      }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    contentView.scrollIndicatorBehavior = .never

    // when: rendering with only the first row visible
    contentView.refresh(animated: false)

    // then: the first row has the configured color and size
    let retainedLayer = try firstLayer.unwrap()
    expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 100, height: 120)
    expect(retainedLayer.backgroundColor) == Color.red.cgColor
    expect(secondLayer) == nil

    // when: resizing to reveal the second row without refreshing changed data
    color = .blue
    contentView.frame.size = CGSize(width: 200, height: 200)
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: both rows use the retained configuration at the new width
    let insertedLayer = try secondLayer.unwrap()
    expect(firstLayer === retainedLayer) == true
    expect(insertedLayer === retainedLayer) == false
    expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 200, height: 120)
    expect(insertedLayer.frame) == CGRect(x: 0, y: 120, width: 200, height: 120)
    expect(retainedLayer.backgroundColor) == Color.red.cgColor
    expect(insertedLayer.backgroundColor) == Color.red.cgColor

    // when: refreshing the changed data with both rows visible
    contentView.refresh(animated: false)

    // then: both retained layers receive the new color consistently
    expect(firstLayer === retainedLayer) == true
    expect(secondLayer === insertedLayer) == true
    expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 200, height: 120)
    expect(insertedLayer.frame) == CGRect(x: 0, y: 120, width: 200, height: 120)
    expect(retainedLayer.backgroundColor) == Color.blue.cgColor
    expect(insertedLayer.backgroundColor) == Color.blue.cgColor
  }

  func test_scroll_retainsColor_andInitializesNewlyVisibleItem() throws {
    // given: two color rows with only the first row visible
    var firstColor = Color.red
    var secondColor = Color.blue
    var firstLayer: CALayer?
    var secondLayer: CALayer?
    var firstUpdateType: RenderableUpdateType?
    var secondUpdateType: RenderableUpdateType?
    let contentView = ComposeView {
      VStack {
        ColorNode(firstColor)
          .fixedId("first")
          .frame(width: 100, height: 120)
          .onUpdate { renderable, context in
            firstLayer = renderable.layer
            firstUpdateType = context.updateType
          }
        ColorNode(secondColor)
          .fixedId("second")
          .frame(width: 100, height: 120)
          .onUpdate { renderable, context in
            secondLayer = renderable.layer
            secondUpdateType = context.updateType
          }
      }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    contentView.scrollIndicatorBehavior = .never

    // when: rendering the initial viewport
    contentView.refresh(animated: false)

    // then: only the first color is inserted and initialized
    let retainedLayer = try firstLayer.unwrap()
    expect(firstUpdateType) == .insert
    expect(retainedLayer.backgroundColor) == Color.red.cgColor
    expect(secondLayer) == nil

    // when: scrolling to reveal the second row without refreshing changed data
    firstColor = .green
    secondColor = .yellow
    contentView.setContentOffset(CGPoint(x: 0, y: 50))
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: the retained layer keeps its color and the newly visible layer is initialized
    let insertedLayer = try secondLayer.unwrap()
    expect(firstUpdateType) == .scroll
    expect(firstLayer === retainedLayer) == true
    expect(retainedLayer.frame) == CGRect(x: 0, y: 0, width: 100, height: 120)
    expect(retainedLayer.backgroundColor) == Color.red.cgColor
    expect(secondUpdateType) == .insert
    expect(insertedLayer === retainedLayer) == false
    expect(insertedLayer.frame) == CGRect(x: 0, y: 120, width: 100, height: 120)
    expect(insertedLayer.backgroundColor) == Color.blue.cgColor

    // when: refreshing the changed data while both rows are visible
    contentView.refresh(animated: false)

    // then: both existing layers receive the refreshed colors
    expect(firstUpdateType) == .refresh
    expect(secondUpdateType) == .refresh
    expect(firstLayer === retainedLayer) == true
    expect(secondLayer === insertedLayer) == true
    expect(retainedLayer.backgroundColor) == Color.green.cgColor
    expect(insertedLayer.backgroundColor) == Color.yellow.cgColor
  }

  func test_resetForReuse() throws {
    // given: a color renderable updated with a background color
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ColorNode(.red)
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
    let item = try node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100)).first.unwrap()

    let contentView = ComposeView()
    contentView.overrideTheme = .light
    let renderable = item.make(RenderableMakeContext(initialFrame: .zero, contentView: contentView))
    item.update(renderable, RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView))
    expect(renderable.layer.backgroundColor) == Color.red.cgColor

    // when: resetting the renderable for reuse
    item.resetForReuse?(renderable)

    // then: the background color is cleared so the pooled layer is freshly-made-equivalent
    expect(renderable.layer.backgroundColor) == nil
  }
}
