//
//  HorizontalStackNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/31/25.
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

import XCTest

import ComposeUI

class HorizontalStackNodeTests: XCTestCase {

  func test_typealias() {
    _ = HorizontalStack {}
    _ = HorizontalStackNode {}
  }

  func test_empty() {
    var node = HorizontalStack {}

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(0), height: .fixed(0)))
    XCTAssertEqual(node.size, .zero)
  }

  func test_flexibleWidth_flexibleHeight() {
    var node = HorizontalStack {
      LayerNode()
      LayerNode()
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .flexible))
    XCTAssertEqual(node.size, CGSize(width: 100, height: 50))

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    guard items.count == 2 else {
      XCTFail("Expected 2 items")
      return
    }

    XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 50, height: 50))
    XCTAssertEqual(items[1].frame, CGRect(x: 50, y: 0, width: 50, height: 50))
  }

  func test_flexibleWidth_flexibleHeight_spacing() {
    var node = HorizontalStack(spacing: 10) {
      LayerNode()
      LayerNode()
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    XCTAssertEqual(sizing, ComposeNodeSizing(width: .range(min: 10, max: .infinity), height: .flexible))
    XCTAssertEqual(node.size, CGSize(width: 100, height: 50))

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    guard items.count == 2 else {
      XCTFail("Expected 2 items")
      return
    }

    XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 45, height: 50))
    XCTAssertEqual(items[1].frame, CGRect(x: 55, y: 0, width: 45, height: 50))
  }

  func test_flexibleWidth_fixedHeight() {
    var node = HorizontalStack {
      LayerNode().frame(width: .flexible, height: 30)
      LayerNode().frame(width: .flexible, height: 20)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .fixed(30)))
    XCTAssertEqual(node.size, CGSize(width: 100, height: 30))

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    guard items.count == 2 else {
      XCTFail("Expected 2 items")
      return
    }

    XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 50, height: 30))
    XCTAssertEqual(items[1].frame, CGRect(x: 50, y: 5, width: 50, height: 20))
  }

  func test_fixedWidth_flexibleHeight() {
    var node = HorizontalStack {
      LayerNode().frame(width: 50, height: .flexible)
      LayerNode().frame(width: 20, height: .flexible)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(70), height: .flexible))
    XCTAssertEqual(node.size, CGSize(width: 70, height: 50))

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    guard items.count == 2 else {
      XCTFail("Expected 2 items")
      return
    }

    XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 50, height: 50))
    XCTAssertEqual(items[1].frame, CGRect(x: 50, y: 0, width: 20, height: 50))
  }

  func test_fixedWidth_fixedHeight() {
    var node = HorizontalStack {
      LayerNode().frame(width: 50, height: 30)
      LayerNode().frame(width: 20, height: 20)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(70), height: .fixed(30)))
    XCTAssertEqual(node.size, CGSize(width: 70, height: 30))

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    guard items.count == 2 else {
      XCTFail("Expected 2 items")
      return
    }

    XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 50, height: 30))
    XCTAssertEqual(items[1].frame, CGRect(x: 50, y: 5, width: 20, height: 20))
  }

  func test_fixedWidth_fixedHeight_spacer() {
    var node = HorizontalStack {
      LayerNode().frame(width: 50, height: 30)
      SpacerNode()
      LayerNode().frame(width: 20, height: 20)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    XCTAssertEqual(sizing, ComposeNodeSizing(width: .range(min: 70, max: .infinity), height: .fixed(30)))
    XCTAssertEqual(node.size, CGSize(width: 100, height: 30))

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    guard items.count == 2 else {
      XCTFail("Expected 2 items")
      return
    }

    XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 50, height: 30))
    XCTAssertEqual(items[1].frame, CGRect(x: 80, y: 5, width: 20, height: 20))
  }

  func test_fixedWidth_fixedHeight_alignment() {
    // top alignment
    do {
      var node = HorizontalStack(alignment: .top) {
        LayerNode().frame(width: 50, height: 30)
        LayerNode().frame(width: 20, height: 20)
      }

      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

      XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(70), height: .fixed(30)))
      XCTAssertEqual(node.size, CGSize(width: 70, height: 30))

      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

      guard items.count == 2 else {
        XCTFail("Expected 2 items")
        return
      }

      XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 50, height: 30))
      XCTAssertEqual(items[1].frame, CGRect(x: 50, y: 0, width: 20, height: 20))
    }

    // bottom alignment
    do {
      var node = HorizontalStack(alignment: .bottom) {
        LayerNode().frame(width: 50, height: 30)
        LayerNode().frame(width: 20, height: 20)
      }

      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

      XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(70), height: .fixed(30)))
      XCTAssertEqual(node.size, CGSize(width: 70, height: 30))

      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

      guard items.count == 2 else {
        XCTFail("Expected 2 items")
        return
      }

      XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 50, height: 30))
      XCTAssertEqual(items[1].frame, CGRect(x: 50, y: 10, width: 20, height: 20))
    }
  }

  func test_renderableItems_filtersOffscreenChildren() {
    var node = HorizontalStack {
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 30, height: 10), context: context)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))

    guard items.count == 1 else {
      XCTFail("Expected 1 item")
      return
    }

    XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 10, height: 10))
  }

  func test_renderableItems_includesOffsetChildren() {
    var node = HorizontalStack {
      LayerNode().frame(width: 10, height: 10)
      LayerNode().frame(width: 10, height: 10)
        .offset(x: -10, y: 0)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 20, height: 10), context: context)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))

    guard items.count == 2 else {
      XCTFail("Expected 2 items")
      return
    }

    XCTAssertEqual(items[0].frame, CGRect(x: 0, y: 0, width: 10, height: 10))
    XCTAssertEqual(items[1].frame, CGRect(x: 0, y: 0, width: 10, height: 10))
  }
}
