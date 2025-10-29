//
//  ComposeViewNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/12/25.
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

class ComposeViewNodeTests: XCTestCase {

  func test_init() throws {
    _ = ComposeViewNode {
      Empty()
    }

    _ = ComposeViewNode {
      ColorNode(.red)
    }

    _ = ComposeViewNode {
      VStack {
        ColorNode(.red)
        ColorNode(.blue)
      }
    }
  }

  func test_id() throws {
    let node = ComposeViewNode {
      Empty()
    }
    expect(node.id.id) == "CV"
  }

  func test_size() throws {
    // fixed size content + fixed size
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
          .frame(width: 50, height: 50)
      }

      // before layout, size should be zero
      expect(node.size) == .zero

      // after layout
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
      expect(node.size) == CGSize(width: 50, height: 50)
    }

    // fixed size content + fixed width, flexible height
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
          .frame(width: 50, height: 50)
      }
      .fixedSize(width: true, height: false)

      expect(node.size) == .zero

      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
      expect(node.size) == CGSize(width: 50, height: 100)
    }

    // fixed size content + flexible width, fixed height
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
          .frame(width: 50, height: 50)
      }
      .fixedSize(width: false, height: true)

      expect(node.size) == .zero

      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
      expect(node.size) == CGSize(width: 100, height: 50)
    }

    // fixed size content + flexible size
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
          .frame(width: 50, height: 50)
      }
      .fixedSize(width: false, height: false)

      expect(node.size) == .zero

      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
      expect(node.size) == CGSize(width: 100, height: 100)
    }

    // flexible size content + fixed size
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
      }

      expect(node.size) == .zero

      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
      expect(node.size) == CGSize(width: 100, height: 100)
    }

    // flexible size content + fixed width, flexible height
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
      }
      .fixedSize(width: true, height: false)

      expect(node.size) == .zero

      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
      expect(node.size) == CGSize(width: 100, height: 100)
    }

    // flexible size content + flexible width, fixed height
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
      }
      .fixedSize(width: false, height: true)

      expect(node.size) == .zero

      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
      expect(node.size) == CGSize(width: 100, height: 100)
    }

    // flexible size content + flexible size
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
      }
      .fixedSize(width: false, height: false)

      expect(node.size) == .zero

      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
      expect(node.size) == CGSize(width: 100, height: 100)
    }
  }

  func test_layout() throws {
    let context = ComposeNodeLayoutContext(scaleFactor: 1)

    // fixed size content
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
          .frame(width: 50, height: 50)
      }
      let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
      expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .fixed(50))
      expect(node.size) == CGSize(width: 50, height: 50)
    }

    // flexible size content
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
      }
      let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
      expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
      expect(node.size) == CGSize(width: 100, height: 100)
    }

    // VStack content
    do {
      var node = ComposeViewNode {
        VStack {
          ColorNode(.red)
            .frame(width: 50, height: 30)
          ColorNode(.blue)
            .frame(width: 70, height: 20)
        }
      }
      let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
      expect(sizing) == ComposeNodeSizing(width: .fixed(70), height: .fixed(50))
      expect(node.size) == CGSize(width: 70, height: 50)
    }
  }

  func test_renderableItems() throws {
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ComposeViewNode {
      ColorNode(.red)
        .frame(width: 50, height: 50)
    }
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when visible bounds intersects with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)
      expect(items.count) == 1

      let item = items[0]
      expect(item.id.id) == "CV"
      expect(item.frame) == CGRect(x: 0, y: 0, width: 50, height: 50)

      // make
      do {
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 50, height: 50), contentView: nil))
        expect(renderable.view is ComposeView) == true
        expect(renderable.frame) == CGRect(x: 1, y: 2, width: 50, height: 50)
      }
      do {
        let renderable = item.make(RenderableMakeContext(initialFrame: nil, contentView: nil))
        expect(renderable.view is ComposeView) == true
        expect(renderable.frame) == .zero
      }

      // willInsert
      do {
        let willInsert = try item.willInsert.unwrap()
        let composeView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
        let renderable = Renderable.view(composeView)
        willInsert(renderable, RenderableInsertContext(oldFrame: .zero, newFrame: .zero, contentView: nil))
        composeView.refresh()

        #if canImport(AppKit)
        let layer = try (composeView.subviews.first(where: { ($0 as? NSClipView) != nil })?.subviews[0].layer).unwrap()
        #endif
        #if canImport(UIKit)
        let layer = composeView.layer
        #endif
        expect(layer.sublayers?.count) == 1
        let sublayer = try (layer.sublayers?.first).unwrap()
        expect(sublayer.frame) == CGRect(x: 25.0, y: 75.0, width: 50, height: 50)
        expect(sublayer.backgroundColor) == Color.red.cgColor
      }

      expect(item.didInsert) == nil
      expect(item.willUpdate) == nil
      expect(item.update) != nil
      expect(item.willRemove) == nil
      expect(item.didRemove) == nil
      expect(item.transition) == nil
      expect(item.animationTiming) == nil
    }

    // when visible bounds does not intersect with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 50, width: 100, height: 100)
      let items = node.renderableItems(in: visibleBounds)
      expect(items.count) == 0
    }
  }

  func test_layoutCalledBeforeRenderableItems() {
    let node = ComposeViewNode {
      ColorNode(.red)
    }

    var assertionCount = 0
    Assert.setTestAssertionFailureHandler { message, file, line, column in
      expect(message) == "renderableItems(in:) is called before layout(containerSize:context:)."
      assertionCount += 1
    }

    // Call renderableItems without calling layout first
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))
    expect(items.count) == 0
    expect(assertionCount) == 1

    // Clean up assertion handler
    Assert.resetTestAssertionFailureHandler()
  }
}
