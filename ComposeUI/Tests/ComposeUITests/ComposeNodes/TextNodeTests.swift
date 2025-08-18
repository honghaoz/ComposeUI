//
//  TextNodeTests.swift
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

class TextNodeTests: XCTestCase {

  func test_defaultSize() {
    var node = TextNode("Hello, world!")

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
    expect(node.size) == CGSize(width: 100, height: 50)
  }

  func test_fixedSize() throws {
    let font = try unwrap(Font(name: "HelveticaNeue", size: 18))
    var node = TextNode("Hello, world!", font: font).fixedSize()

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    #if canImport(AppKit)
    expect(sizing) == ComposeNodeSizing(width: .fixed(51), height: .fixed(44))
    expect(node.size) == CGSize(width: 51, height: 44)
    #endif
    #if canImport(UIKit)
    expect(sizing) == ComposeNodeSizing(width: .fixed(51), height: .fixed(43))
    expect(node.size) == CGSize(width: 51, height: 43)
    #endif
  }

  func test_longString_multipleLines() throws {
    let font = try unwrap(Font(name: "HelveticaNeue", size: 18))
    var node = TextNode(
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
      font: font
    )
    .numberOfLines(0)
    .fixedSize()

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    expect(sizing) == ComposeNodeSizing(width: .fixed(100), height: .fixed(280))
    expect(node.size) == CGSize(width: 100, height: 280)
  }

  func test_longString_singleLine() throws {
    let font = try unwrap(Font(name: "HelveticaNeue", size: 18))
    var node = TextNode(
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut",
      font: font
    )
    .numberOfLines(1)
    .fixedSize()

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 1000, height: 50), context: context)

    expect(sizing) == ComposeNodeSizing(width: .fixed(751.0), height: .fixed(22))
    expect(node.size) == CGSize(width: 751.0, height: 22)
  }

  func test_view() {
    var textView: TextView?
    let contentView = ComposeView {
      TextNode("Hello, world!")
        .onUpdate { item, _ in
          textView = item.view as? TextView
        }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    contentView.refresh()

    #if !os(tvOS)
    expect(textView?.isEditable) == false
    #endif
    expect(textView?.isSelectable) == true

    contentView.setContent {
      TextNode("Hello, world!")
        .selectable(false)
        .editable(false)
        .onUpdate { item, _ in
          textView = item.view as? TextView
        }
    }
    contentView.refresh()

    #if !os(tvOS)
    expect(textView?.isEditable) == false
    #endif
    expect(textView?.isSelectable) == false

    contentView.setContent {
      TextNode("Hello, world!")
        .selectable()
        .editable()
        .onUpdate { item, _ in
          textView = item.view as? TextView
        }
    }
    contentView.refresh()

    #if !os(tvOS)
    expect(textView?.isEditable) == true
    #endif
    expect(textView?.isSelectable) == true

    contentView.setContent {
      TextNode("Hello, world!")
        .textContainerInset(horizontal: 10, vertical: 20)
        .onUpdate { item, _ in
          textView = item.view as? TextView
        }
    }
    contentView.refresh()

    #if canImport(AppKit)
    expect(textView?.textContainerInset) == CGSize(width: 10, height: 20)
    #endif

    #if canImport(UIKit)
    expect(textView?.textContainerInset) == EdgeInsets(top: 20, left: 10, bottom: 20, right: 10)
    #endif
  }

  func test_adjustIntrinsicTextSize() throws {
    var textView: BaseTextView?
    let view = ComposeView {
      try TextNode("Hello, world!", font: unwrap(Font(name: "HelveticaNeue", size: 13)))
        .numberOfLines(1)
        .fixedSize()
        .intrinsicTextSizeAdjustment { original in
          CGSize(width: 10, height: 20)
        }
        .onInsert { renderable, _ in
          textView = renderable.view as? BaseTextView
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    view.refresh()

    expect(textView?.bounds.size) == CGSize(width: 83, height: 36)
  }
}
