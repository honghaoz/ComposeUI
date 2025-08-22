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
    _ = ColorNode(.red)
    _ = ColorNode(ThemedColor(light: .red, dark: .blue))
  }

  func test_id() throws {
    expect(ColorNode(.red).id.id) == "C"
  }

  func test_size() throws {
    expect(ColorNode(.red).size) == .zero
  }

  func test_layout() throws {
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ColorNode(.red)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
    expect(node.size) == CGSize(width: 100, height: 100)
  }

  func test_renderableItems() throws {
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ColorNode(ThemedColor(light: .red, dark: .blue))
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when visible bounds intersects with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)
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

        // conditional update
        do {
          let contentView = ComposeView()
          contentView.overrideTheme = .light
          let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

          // scroll doesn't trigger update
          do {
            let context = RenderableUpdateContext(updateType: .scroll, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
            item.update(renderable, context)
            let layer = renderable.layer
            expect(layer.backgroundColor) == nil // doesn't update
          }

          // bounds change doesn't trigger update
          do {
            let context = RenderableUpdateContext(updateType: .boundsChange, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
            item.update(renderable, context)
            let layer = renderable.layer
            expect(layer.backgroundColor) == nil // doesn't update
          }
        }
      }

      expect(item.willRemove) == nil
      expect(item.didRemove) == nil
      expect(item.transition) == nil
      expect(item.animationTiming) == nil
    }

    // when visible bounds does not intersect with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 100, width: 100, height: 100)
      let items = node.renderableItems(in: visibleBounds)
      expect(items.count) == 0
    }
  }
}
