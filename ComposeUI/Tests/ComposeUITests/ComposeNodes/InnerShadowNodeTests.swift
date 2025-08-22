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
    // themed + simple path
    _ = InnerShadowNode(
      color: ThemedColor(light: Color.red, dark: Color.blue),
      opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
      radius: Themed<CGFloat>(light: 10, dark: 15),
      offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
      path: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return CGPath(rect: rect, transform: nil)
      }
    )

    // themed + paths
    _ = InnerShadowNode(
      color: ThemedColor(light: Color.red, dark: Color.blue),
      opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
      radius: Themed<CGFloat>(light: 10, dark: 15),
      offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
      paths: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return InnerShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), clipPath: nil)
      }
    )

    // color + simple path
    _ = InnerShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      path: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return CGPath(rect: rect, transform: nil)
      }
    )

    // color + paths
    _ = InnerShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      paths: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return InnerShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), clipPath: nil)
      }
    )
  }

  func test_id() throws {
    let node = InnerShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      path: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return CGPath(rect: rect, transform: nil)
      }
    )
    expect(node.id.id) == "IS"
  }

  func test_size() throws {
    let node = InnerShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      path: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return CGPath(rect: rect, transform: nil)
      }
    )
    expect(node.size) == .zero
  }

  func test_layout() throws {
    var node = InnerShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      path: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return CGPath(rect: rect, transform: nil)
      }
    )
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
    expect(node.size) == CGSize(width: 100, height: 100)
  }

  func test_renderableItems() throws {
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = InnerShadowNode(
      color: ThemedColor(light: Color.red, dark: Color.blue),
      opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
      radius: Themed<CGFloat>(light: 10, dark: 15),
      offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
      paths: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return InnerShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), clipPath: nil)
      }
    )
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when visible bounds intersects with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)
      expect(items.count) == 1

      let item = items[0]
      expect(item.id.id) == "IS"
      expect(item.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      // make
      do {
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: nil))
        expect(renderable.layer.frame) == CGRect(x: 1, y: 2, width: 3, height: 4)
      }

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

          // with animations
          do {
            ComposeUI.Assert.setTestAssertionFailureHandler(nil)

            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: .easeInEaseOut(), contentView: contentView)
            item.update(renderable, context)
            let layer = renderable.layer

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
            expect(layer.animation(forKey: "shadowPath")) != nil

            let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
            expect(maskLayer.frame) == CGRect(x: 0, y: 0, width: 3, height: 4)
            expect(maskLayer.path) == CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 4), transform: nil)
            expect(maskLayer.animation(forKey: "position")) != nil
            expect(maskLayer.animation(forKey: "bounds.size")) != nil
            expect(maskLayer.animation(forKey: "path")) != nil

            ComposeUI.Assert.resetTestAssertionFailureHandler()
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

          // with animations
          do {
            ComposeUI.Assert.setTestAssertionFailureHandler(nil)

            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: .easeInEaseOut(), contentView: contentView)
            item.update(renderable, context)
            let layer = renderable.layer

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
            expect(layer.animation(forKey: "shadowPath")) != nil

            let maskLayer = try (layer.mask as? CAShapeLayer).unwrap()
            expect(maskLayer.frame) == CGRect(x: 0, y: 0, width: 3, height: 4)
            expect(maskLayer.path) == CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 4), transform: nil)
            expect(maskLayer.animation(forKey: "position")) != nil
            expect(maskLayer.animation(forKey: "bounds.size")) != nil
            expect(maskLayer.animation(forKey: "path")) != nil

            ComposeUI.Assert.resetTestAssertionFailureHandler()
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
            expect(layer.shadowOpacity) == 0 // doesn't update
            expect(layer.shadowRadius) == 3 // doesn't update
            expect(layer.shadowOffset) == CGSize(width: 0, height: -3) // doesn't update
            expect(layer.mask) == nil // doesn't update
          }

          // bounds change triggers update
          do {
            let context = RenderableUpdateContext(updateType: .boundsChange, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
            item.update(renderable, context)
            let layer = renderable.layer
            expect(layer.shadowColor) == Color.red.cgColor
            expect(layer.shadowOpacity) == 0.5
            expect(layer.shadowRadius) == 10
            expect(layer.shadowOffset) == CGSize(width: 2, height: 5)
            expect(layer.shadowPath) == CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 4), transform: nil)
          }
        }
      }
    }

    // when visible bounds does not intersect with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 100, width: 100, height: 100)
      let items = node.renderableItems(in: visibleBounds)
      expect(items.count) == 0
    }
  }

  func test_overlay() throws {
    // themed + simple path
    do {
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      var node = ColorNode(.red)
        .innerShadow(
          color: ThemedColor(light: Color.red, dark: Color.blue),
          opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
          radius: Themed<CGFloat>(light: 10, dark: 15),
          offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
          path: { renderable in
            let rect = CGRect(origin: .zero, size: renderable.frame.size)
            return CGPath(rect: rect, transform: nil)
          }
        )
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))
      expect(items.count) == 2

      let hostItem = items[0]
      expect(hostItem.id.id) == "OV|C"
      expect(hostItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      let shadowItem = items[1]
      expect(shadowItem.id.id) == "OV|O|IS"
      expect(shadowItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    }

    // themed + paths
    do {
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      var node = ColorNode(.red)
        .innerShadow(
          color: ThemedColor(light: Color.red, dark: Color.blue),
          opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
          radius: Themed<CGFloat>(light: 10, dark: 15),
          offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
          paths: { renderable in
            let rect = CGRect(origin: .zero, size: renderable.frame.size)
            return InnerShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), clipPath: nil)
          }
        )
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))
      expect(items.count) == 2

      let hostItem = items[0]
      expect(hostItem.id.id) == "OV|C"
      expect(hostItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      let shadowItem = items[1]
      expect(shadowItem.id.id) == "OV|O|IS"
      expect(shadowItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    }

    // color + simple path
    do {
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      var node = ColorNode(.red)
        .innerShadow(
          color: .black,
          opacity: 0.5,
          radius: 10,
          offset: CGSize(width: 2, height: 5),
          path: { renderable in
            let rect = CGRect(origin: .zero, size: renderable.frame.size)
            return CGPath(rect: rect, transform: nil)
          }
        )
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))
      expect(items.count) == 2

      let hostItem = items[0]
      expect(hostItem.id.id) == "OV|C"
      expect(hostItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      let shadowItem = items[1]
      expect(shadowItem.id.id) == "OV|O|IS"
      expect(shadowItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    }

    // color + paths
    do {
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      var node = ColorNode(.red)
        .innerShadow(
          color: .black,
          opacity: 0.5,
          radius: 10,
          offset: CGSize(width: 2, height: 5),
          paths: { renderable in
            let rect = CGRect(origin: .zero, size: renderable.frame.size)
            return InnerShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), clipPath: nil)
          }
        )
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))
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
    let view = ComposeView {
      VStack {
        InnerShadowNode(color: .black, opacity: 0.5, radius: 10, offset: CGSize(width: 2, height: 5), path: { renderItem in
          let size = renderItem.frame.size
          let cornerRadius = renderItem.layer.cornerRadius
          return CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        })

        InnerShadowNode(color: .black, opacity: 0.5, radius: 10, offset: CGSize(width: 2, height: 5), paths: { renderItem in
          let size = renderItem.frame.size
          let cornerRadius = renderItem.layer.cornerRadius
          let shadowPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
          let clipPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height).insetBy(dx: 10, dy: 10), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
          return InnerShadowPaths(shadowPath: shadowPath, clipPath: clipPath)
        })
      }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    view.refresh()

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
    expect(maskLayer1.path) == CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 50), cornerWidth: 0, cornerHeight: 0, transform: nil)

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
    expect(maskLayer2.path) == CGPath(roundedRect: CGRect(x: 10, y: 10, width: 80, height: 30), cornerWidth: 0, cornerHeight: 0, transform: nil)
  }
}
