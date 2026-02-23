//
//  LayeredStackNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/31/25.
//

import ChouTiTest

import ComposeUI

class LayeredStackNodeTests: XCTestCase {

  func test_typealias() {
    _ = ZStack {}
    _ = LayeredStack {}
    _ = LayeredStackNode {}
  }

  func test_empty() {
    var node = ZStack {}

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    expect(sizing) == ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
    expect(node.size) == .zero
  }

  func test_flexibleWidth_flexibleHeight() {
    var node = ZStack {
      LayerNode()
      LayerNode()
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
    expect(node.size) == CGSize(width: 100, height: 50)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 100, height: 50)
    expect(items[1].frame) == CGRect(x: 0, y: 0, width: 100, height: 50)
  }

  func test_flexibleWidth_fixedHeight() {
    var node = ZStack {
      LayerNode().frame(width: .flexible, height: 30)
      LayerNode().frame(width: .flexible, height: 20)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(30))
    expect(node.size) == CGSize(width: 100, height: 30)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 100, height: 30)
    expect(items[1].frame) == CGRect(x: 0, y: 5, width: 100, height: 20)
  }

  func test_fixedWidth_flexibleHeight() {
    var node = ZStack {
      LayerNode().frame(width: 50, height: .flexible)
      LayerNode().frame(width: 20, height: .flexible)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .flexible)
    expect(node.size) == CGSize(width: 50, height: 50)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 50)
    expect(items[1].frame) == CGRect(x: 15, y: 0, width: 20, height: 50)
  }

  func test_fixedWidth_fixedHeight() {
    var node = ZStack {
      LayerNode().frame(width: 50, height: 30)
      LayerNode().frame(width: 20, height: 20)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .fixed(30))
    expect(node.size) == CGSize(width: 50, height: 30)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 0, y: 0, width: 50, height: 30)
    expect(items[1].frame) == CGRect(x: 15, y: 5, width: 20, height: 20)
  }

  func test_fixedWidth_fixedHeight_spacer() {
    var node = ZStack {
      LayerNode().frame(width: 50, height: 30)
      Spacer()
      LayerNode().frame(width: 20, height: 20)
    }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    expect(sizing) == ComposeNodeSizing(width: .range(min: 50, max: .infinity), height: .range(min: 30, max: .infinity))
    expect(node.size) == CGSize(width: 100, height: 100)

    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))

    guard items.count == 2 else {
      fail("Expected 2 items")
      return
    }

    expect(items[0].frame) == CGRect(x: 25, y: 35, width: 50, height: 30)
    expect(items[1].frame) == CGRect(x: 40, y: 40, width: 20, height: 20)
  }
}
