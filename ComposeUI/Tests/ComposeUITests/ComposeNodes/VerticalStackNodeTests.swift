//
//  VerticalStackNodeTests.swift
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

import ChouTiTest

import ComposeUI

class VerticalStackNodeTests: XCTestCase {

  func test_typealias() {
    _ = VStack {}
    _ = VerticalStack {}
    _ = VerticalStackNode {}
  }

  func test_empty() {
    var node = VStack {}

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

    expect(sizing) == ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
    expect(node.size) == .zero
  }

  func test_flexibleWidth_flexibleHeight() {
    var node = VStack {
      LayerNode()
      LayerNode()
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
    expect(node.size) == CGSize(width: 50, height: 100)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 50)
    expect(items[1].frame) == CGRect(x: 0, y: 50, width: 50, height: 50)
  }

  func test_flexibleWidth_flexibleHeight_spacing() {
    var node = VStack(spacing: 10) {
      LayerNode()
      LayerNode()
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .range(min: 10, max: .infinity))
    expect(node.size) == CGSize(width: 50, height: 100)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 45)
    expect(items[1].frame) == CGRect(x: 0, y: 55, width: 50, height: 45)
  }

  func test_flexibleWidth_fixedHeight() {
    var node = VStack {
      LayerNode().frame(width: .flexible, height: 30)
      LayerNode().frame(width: .flexible, height: 20)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(50))
    expect(node.size) == CGSize(width: 50, height: 50)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 30)
    expect(items[1].frame) == CGRect(x: 0, y: 30, width: 50, height: 20)
  }

  func test_fixedWidth_flexibleHeight() {
    var node = VStack {
      LayerNode().frame(width: 20, height: .flexible)
      LayerNode().frame(width: 30, height: .flexible)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

    expect(sizing) == ComposeNodeSizing(width: .fixed(30), height: .flexible)
    expect(node.size) == CGSize(width: 30, height: 100)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 5, y: 0, width: 20, height: 50)
    expect(items[1].frame) == CGRect(x: 0, y: 50, width: 30, height: 50)
  }

  func test_fixedWidth_fixedHeight() {
    var node = VStack {
      LayerNode().frame(width: 30, height: 50)
      LayerNode().frame(width: 20, height: 20)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

    expect(sizing) == ComposeNodeSizing(width: .fixed(30), height: .fixed(70))
    expect(node.size) == CGSize(width: 30, height: 70)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 30, height: 50)
    expect(items[1].frame) == CGRect(x: 5, y: 50, width: 20, height: 20)
  }

  func test_fixedWidth_fixedHeight_spacer() {
    var node = VStack {
      LayerNode().frame(width: 30, height: 50)
      Spacer()
      LayerNode().frame(width: 20, height: 20)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

    expect(sizing) == ComposeNodeSizing(width: .fixed(30), height: .range(min: 70, max: .infinity))
    expect(node.size) == CGSize(width: 30, height: 100)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 30, height: 50)
    expect(items[1].frame) == CGRect(x: 5, y: 80, width: 20, height: 20)
  }

  func test_fixedWidth_fixedHeight_alignment() {
    // left alignment
    do {
      var node = VStack(alignment: .left) {
        LayerNode().frame(width: 30, height: 50)
        LayerNode().frame(width: 20, height: 20)
      }

      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

      expect(sizing) == ComposeNodeSizing(width: .fixed(30), height: .fixed(70))
      expect(node.size) == CGSize(width: 30, height: 70)

      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

      guard items.count == 2 else {
        fail("Expected 2 items")
        return
      }

      expect(items[0].frame) == CGRect(x: 0, y: 0, width: 30, height: 50)
      expect(items[1].frame) == CGRect(x: 0, y: 50, width: 20, height: 20)
    }

    // right alignment
    do {
      var node = VStack(alignment: .right) {
        LayerNode().frame(width: 30, height: 50)
        LayerNode().frame(width: 20, height: 20)
      }

      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      let sizing = node.layout(containerSize: CGSize(width: 50, height: 100), context: context)

      expect(sizing) == ComposeNodeSizing(width: .fixed(30), height: .fixed(70))
      expect(node.size) == CGSize(width: 30, height: 70)

      let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 50, height: 100))

      guard items.count == 2 else {
        fail("Expected 2 items")
        return
      }

      expect(items[0].frame) == CGRect(x: 0, y: 0, width: 30, height: 50)
      expect(items[1].frame) == CGRect(x: 10, y: 50, width: 20, height: 20)
    }
  }
}
