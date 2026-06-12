//
//  PaddingNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 6/11/26.
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

class PaddingNodeTests: XCTestCase {

  func test_padding() {
    let context = ComposeNodeLayoutContext(scaleFactor: 1)

    // padding(top:left:bottom:right:)
    do {
      var node = LayerNode().frame(width: 10, height: 10).padding(top: 1, left: 2, bottom: 3, right: 4)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      expect(node.size) == CGSize(width: 16, height: 14)
      expect(node.renderableItemsBoundingRect) == CGRect(x: 2, y: 1, width: 10, height: 10)
    }

    // padding(horizontal:vertical:)
    do {
      var node = LayerNode().frame(width: 10, height: 10).padding(horizontal: 2, vertical: 3)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      expect(node.size) == CGSize(width: 14, height: 16)
      expect(node.renderableItemsBoundingRect) == CGRect(x: 2, y: 3, width: 10, height: 10)
    }
  }

  func test_renderableItemsBoundingRect() {
    let context = ComposeNodeLayoutContext(scaleFactor: 1)

    // the bounding rect should be translated by the padding insets
    do {
      var node = LayerNode().frame(width: 10, height: 10).padding(5)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      expect(node.size) == CGSize(width: 20, height: 20)
      expect(node.renderableItemsBoundingRect) == CGRect(x: 5, y: 5, width: 10, height: 10)
    }

    // when the child node has no renderable items
    do {
      var node = Spacer().padding(5)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      expect(node.renderableItemsBoundingRect.isNull) == true
    }
  }
}
