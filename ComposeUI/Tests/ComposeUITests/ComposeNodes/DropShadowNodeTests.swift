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
    // themed + simple path
    _ = DropShadowNode(
      color: ThemedColor(light: Color.red, dark: Color.blue),
      opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
      radius: Themed<CGFloat>(light: 10, dark: 15),
      offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
      path: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return CGPath(rect: rect, transform: nil)
      }
    )

    // themed + shadow paths
    _ = DropShadowNode(
      color: ThemedColor(light: Color.red, dark: Color.blue),
      opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
      radius: Themed<CGFloat>(light: 10, dark: 15),
      offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
      paths: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: nil)
      }
    )

    // color + simple path
    _ = DropShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      path: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return CGPath(rect: rect, transform: nil)
      }
    )

    // color + shadow paths
    _ = DropShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      paths: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: nil)
      }
    )
  }

  func test_id() throws {
    let node = DropShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      paths: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: nil)
      }
    )
    expect(node.id.id) == "DS"
  }

  func test_size() throws {
    let node = DropShadowNode(
      color: .black,
      opacity: 0.5,
      radius: 10,
      offset: CGSize(width: 2, height: 5),
      paths: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: nil)
      }
    )
    expect(node.size) == .zero
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
    var node = DropShadowNode(
      color: ThemedColor(light: Color.red, dark: Color.blue),
      opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
      radius: Themed<CGFloat>(light: 10, dark: 15),
      offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
      paths: { renderable in
        let rect = CGRect(origin: .zero, size: renderable.frame.size)
        return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: nil)
      }
    )
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when visible bounds intersects with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)
      expect(items.count) == 1

      let item = items[0]
      expect(item.id.id) == "DS"
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

          // with animations
          do {
            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: .easeInEaseOut(), contentView: contentView)
            item.update(renderable, context)
            let layer = renderable.layer
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

          // with animations
          do {
            let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: .easeInEaseOut(), contentView: contentView)
            item.update(renderable, context)
            let layer = renderable.layer
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
          }
        }

        // requires full update
        do {
          let contentView = ComposeView()
          let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

          // scroll doesn't require a full update
          let context = RenderableUpdateContext(updateType: .scroll, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
          item.update(renderable, context)
          let layer = renderable.layer
          expect(layer.backgroundColor) == nil // doesn't update
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

  func test_underlay() throws {
    // themed + simple path
    do {
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      var node = ColorNode(.red)
        .dropShadow(
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

      let shadowItem = items[0]
      expect(shadowItem.id.id) == "UL|U|DS"
      expect(shadowItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      let hostItem = items[1]
      expect(hostItem.id.id) == "UL|C"
      expect(hostItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    }

    // themed + shadow paths
    do {
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      var node = ColorNode(.red)
        .dropShadow(
          color: ThemedColor(light: Color.red, dark: Color.blue),
          opacity: Themed<CGFloat>(light: 0.5, dark: 0.7),
          radius: Themed<CGFloat>(light: 10, dark: 15),
          offset: Themed<CGSize>(light: CGSize(width: 2, height: 5), dark: CGSize(width: 3, height: 6)),
          paths: { renderable in
            let rect = CGRect(origin: .zero, size: renderable.frame.size)
            return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: nil)
          }
        )
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))
      expect(items.count) == 2

      let shadowItem = items[0]
      expect(shadowItem.id.id) == "UL|U|DS"
      expect(shadowItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      let hostItem = items[1]
      expect(hostItem.id.id) == "UL|C"
      expect(hostItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    }

    // color + simple path
    do {
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      var node = ColorNode(.red)
        .dropShadow(
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

      let shadowItem = items[0]
      expect(shadowItem.id.id) == "UL|U|DS"
      expect(shadowItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      let hostItem = items[1]
      expect(hostItem.id.id) == "UL|C"
      expect(hostItem.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    }

    // color + shadow paths
    do {
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      var node = ColorNode(.red)
        .dropShadow(
          color: .black,
          opacity: 0.5,
          radius: 10,
          offset: CGSize(width: 2, height: 5),
          paths: { renderable in
            let rect = CGRect(origin: .zero, size: renderable.frame.size)
            return DropShadowPaths(shadowPath: CGPath(rect: rect, transform: nil), cutoutPath: nil)
          }
        )
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))
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
    let view = ComposeView {
      VStack {
        DropShadowNode(color: .black, opacity: 0.5, radius: 10, offset: CGSize(width: 2, height: 5), path: { renderItem in
          let size = renderItem.frame.size
          let cornerRadius = renderItem.layer.cornerRadius
          return CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        })

        DropShadowNode(color: .black, opacity: 0.5, radius: 10, offset: CGSize(width: 2, height: 5), paths: { renderItem in
          let size = renderItem.frame.size
          let cornerRadius = renderItem.layer.cornerRadius
          let shadowPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
          let cutoutPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height).insetBy(dx: 10, dy: 10), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
          return DropShadowPaths(shadowPath: shadowPath, cutoutPath: cutoutPath)
        })
      }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    view.refresh()

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
    expect(shadowLayer1.shadowPath) == CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 50), cornerWidth: 0, cornerHeight: 0, transform: nil)

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
    expect(shadowLayer2.shadowPath) == CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 50), cornerWidth: 0, cornerHeight: 0, transform: nil)

    let maskLayer = try unwrap(shadowLayer2.mask as? CAShapeLayer)
    expect(maskLayer.fillRule) == .evenOdd

    let cutoutPath = CGPath(roundedRect: CGRect(x: 10, y: 10, width: 80, height: 30), cornerWidth: 0, cornerHeight: 0, transform: nil)

    let radius: CGFloat = 10
    let offset = CGSize(width: 2, height: 5)
    let hExtraSize = radius + abs(offset.width) + 1000
    let vExtraSize = radius + abs(offset.height) + 1000
    let biggerBounds = cutoutPath.boundingBoxOfPath.insetBy(dx: -hExtraSize, dy: -vExtraSize)

    let biggerPath = CGMutablePath()
    biggerPath.addPath(CGPath(rect: biggerBounds, transform: nil))
    biggerPath.addPath(cutoutPath)
    expect(maskLayer.path) == biggerPath
  }
}
