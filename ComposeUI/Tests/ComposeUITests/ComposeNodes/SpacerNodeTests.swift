//
//  SpacerNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 7/31/25.
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

import ChouTi
import ComposeUI

class SpacerNodeTests: XCTestCase {

  func test_init_default() {
    // given: a default spacer node
    let spacer = SpacerNode()

    // then: the size is zero
    expect(spacer.size) == .zero
  }

  func test_init_cgSize() {
    // given: a spacer node with a fixed size
    var spacer = SpacerNode(CGSize(100, 200))

    let containerSize = CGSize(width: 200, height: 200)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)

    // when: laying out the spacer
    let sizing = spacer.layout(containerSize: containerSize, context: context)

    // then: the sizing and size are fixed
    expect(sizing) == ComposeNodeSizing(width: .fixed(100), height: .fixed(200))
    expect(spacer.size) == CGSize(width: 100, height: 200)
  }

  func test_init_size() {
    // given: a spacer node with a fixed square size
    var spacer = SpacerNode(100)

    let containerSize = CGSize(width: 200, height: 200)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)

    // when: laying out the spacer
    let sizing = spacer.layout(containerSize: containerSize, context: context)

    // then: the sizing and size are fixed
    expect(sizing) == ComposeNodeSizing(width: .fixed(100), height: .fixed(100))
    expect(spacer.size) == CGSize(width: 100, height: 100)
  }

  func test_init_width_height() {
    // with width
    do {
      // given: a spacer node with a fixed width
      var spacer = SpacerNode(width: 100)

      let containerSize = CGSize(width: 200, height: 200)
      let context = ComposeNodeLayoutContext(scaleFactor: 2)

      // when: laying out the spacer
      let sizing = spacer.layout(containerSize: containerSize, context: context)

      // then: the width is fixed and the height is flexible
      expect(sizing) == ComposeNodeSizing(width: .fixed(100), height: .flexible)
      expect(spacer.size) == CGSize(width: 100, height: 200)
    }

    // with height
    do {
      // given: a spacer node with a fixed height
      var spacer = SpacerNode(height: 100)

      let containerSize = CGSize(width: 200, height: 200)
      let context = ComposeNodeLayoutContext(scaleFactor: 2)

      // when: laying out the spacer
      let sizing = spacer.layout(containerSize: containerSize, context: context)

      // then: the width is flexible and the height is fixed
      expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(100))
      expect(spacer.size) == CGSize(width: 200, height: 100)
    }

    // with both width and height
    do {
      // given: a spacer node with both fixed width and height
      var spacer = SpacerNode(width: 100, height: 200)

      let containerSize = CGSize(width: 200, height: 200)
      let context = ComposeNodeLayoutContext(scaleFactor: 2)

      // when: laying out the spacer
      let sizing = spacer.layout(containerSize: containerSize, context: context)

      // then: the sizing and size are fixed
      expect(sizing) == ComposeNodeSizing(width: .fixed(100), height: .fixed(200))
      expect(spacer.size) == CGSize(width: 100, height: 200)
    }
  }

  func test_renderableItems() {
    // given: a default spacer node
    var spacer = SpacerNode()

    let containerSize = CGSize(width: 200, height: 200)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)

    // when: laying out the spacer
    let sizing = spacer.layout(containerSize: containerSize, context: context)

    // then: the sizing is flexible and the size fills the container
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
    expect(spacer.size) == containerSize

    // when: getting renderable items
    let items = spacer.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))

    // then: no items are provided
    expect(items.isEmpty) == true
  }

  func test_renderableItemsBoundingRect() {
    // given: a laid out spacer node
    var spacer = SpacerNode()

    let context = ComposeNodeLayoutContext(scaleFactor: 2)
    _ = spacer.layout(containerSize: CGSize(width: 200, height: 200), context: context)

    // then: the bounding rect is null since the spacer node provides no renderable items
    expect(spacer.renderableItemsBoundingRect.isNull) == true
  }

  func test_modifier_width() {
    // given: a spacer node with the width modifier
    var spacer = SpacerNode()
    spacer = spacer.width(100)

    let containerSize = CGSize(width: 200, height: 200)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)

    // when: laying out the spacer
    let sizing = spacer.layout(containerSize: containerSize, context: context)

    // then: the width is fixed and the height is flexible
    expect(sizing) == ComposeNodeSizing(width: .fixed(100), height: .flexible)
    expect(spacer.size) == CGSize(width: 100, height: 200)

    // when: setting the width again on the laid out spacer
    // then: it does not crash
    spacer = spacer.width(100)
  }

  func test_modifier_height() {
    // given: a spacer node with the height modifier
    var spacer = SpacerNode()
    spacer = spacer.height(100)

    let containerSize = CGSize(width: 200, height: 200)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)

    // when: laying out the spacer
    let sizing = spacer.layout(containerSize: containerSize, context: context)

    // then: the width is flexible and the height is fixed
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(100))
    expect(spacer.size) == CGSize(width: 200, height: 100)

    // when: setting the height again on the laid out spacer
    // then: it does not crash
    spacer = spacer.height(100)
  }
}
