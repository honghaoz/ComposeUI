//
//  LayerNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
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

@testable import ComposeUI

class LayerNodeTests: XCTestCase {

  func test_id() throws {
    XCTAssertEqual(LayerNode().id.id, "L")

    let layer = CALayer()
    let id = ObjectIdentifier(layer)
    XCTAssertEqual(LayerNode(layer).id.id, "layer-\(id)")
  }

  func test_fixedSize() {
    do {
      // when using layer factory
      var node = LayerNode<CALayer>()

      // then the size is flexible
      XCTAssertFalse(node.isFixedWidth)
      XCTAssertFalse(node.isFixedHeight)

      // when set fixed size
      node = node.fixedSize()

      // then the size is fixed
      XCTAssertTrue(node.isFixedWidth)
      XCTAssertTrue(node.isFixedHeight)
    }

    do {
      // when using external layer
      var node = LayerNode(CALayer())

      // then the size is fixed
      XCTAssertTrue(node.isFixedWidth)
      XCTAssertTrue(node.isFixedHeight)

      // when set flexible size
      node = node.flexibleSize()

      // then the size is flexible
      XCTAssertFalse(node.isFixedWidth)
      XCTAssertFalse(node.isFixedHeight)
    }
  }

  func test_size() {
    // using layer's bounds.size as intrinsic size
    do {
      // with external layer
      do {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        var node = LayerNode(layer)

        // fixed size
        do {
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(50), height: .fixed(50)))
          XCTAssertEqual(node.size, CGSize(width: 50, height: 50))
        }

        // fixed width, flexible height
        do {
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(50), height: .flexible))
          XCTAssertEqual(node.size, CGSize(width: 50, height: 100))
        }

        // flexible width, fixed height
        do {
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .fixed(50)))
          XCTAssertEqual(node.size, CGSize(width: 100, height: 50))
        }

        // flexible size
        do {
          node = node.flexibleSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .flexible))
          XCTAssertEqual(node.size, CGSize(width: 100, height: 100))
        }
      }

      // with layer factory
      do {
        var node = LayerNode(
          make: { _ in
            let layer = CALayer()
            layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            return layer
          },
          intrinsicSize: { containerSize in CGSize(width: containerSize.width * 2, height: containerSize.height * 2) }
        )

        // flexible size
        do {
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .flexible))
          XCTAssertEqual(node.size, CGSize(width: 100, height: 100))
        }

        // fixed width, flexible height
        do {
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(200), height: .flexible))
          XCTAssertEqual(node.size, CGSize(width: 200, height: 100))
        }

        // flexible width, fixed height
        do {
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .fixed(200)))
          XCTAssertEqual(node.size, CGSize(width: 100, height: 200))
        }

        // fixed size
        do {
          node = node.fixedSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(200), height: .fixed(200)))
          XCTAssertEqual(node.size, CGSize(width: 200, height: 200))
        }
      }
    }

    // using custom intrinsic size
    do {
      // with external layer
      do {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        var node = LayerNode(layer, intrinsicSize: { containerSize in CGSize(width: containerSize.width * 2, height: containerSize.height * 2) })

        // fixed size
        do {
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(200), height: .fixed(200)))
          XCTAssertEqual(node.size, CGSize(width: 200, height: 200))
        }

        // fixed width, flexible height
        do {
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(200), height: .flexible))
          XCTAssertEqual(node.size, CGSize(width: 200, height: 100))
        }

        // flexible width, fixed height
        do {
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .fixed(200)))
          XCTAssertEqual(node.size, CGSize(width: 100, height: 200))
        }

        // flexible size
        do {
          node = node.flexibleSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .flexible))
          XCTAssertEqual(node.size, CGSize(width: 100, height: 100))
        }
      }

      // with layer factory
      do {
        var node = LayerNode(
          make: { _ in
            let layer = CALayer()
            layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            return layer
          },
          intrinsicSize: { containerSize in CGSize(width: containerSize.width * 2, height: containerSize.height * 2) }
        )

        // flexible size
        do {
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .flexible))
          XCTAssertEqual(node.size, CGSize(width: 100, height: 100))
        }

        // fixed width, flexible height
        do {
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(200), height: .flexible))
          XCTAssertEqual(node.size, CGSize(width: 200, height: 100))
        }

        // flexible width, fixed height
        do {
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          XCTAssertEqual(sizing, ComposeNodeSizing(width: .flexible, height: .fixed(200)))
          XCTAssertEqual(node.size, CGSize(width: 100, height: 200))
        }

        // fixed size
        do {
          node = node.fixedSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(200), height: .fixed(200)))
          XCTAssertEqual(node.size, CGSize(width: 200, height: 200))
        }
      }
    }
  }

  func test_factoryLayer_requiresIntrinsicSizeForFixedSizing() {
    var node = LayerNode()
      .fixedSize()

    var assertionCount = 0
    ComposeAssert.setTestAssertionFailureHandler { message, file, line, column in
      XCTAssertEqual(message, "LayerNode requires `intrinsicSize` when using fixed size with a layer factory.")
      assertionCount += 1
    }

    let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 1))
    XCTAssertEqual(sizing, ComposeNodeSizing(width: .fixed(0), height: .fixed(0)))
    XCTAssertEqual(node.size, .zero)
    XCTAssertEqual(assertionCount, 1)

    ComposeAssert.resetTestAssertionFailureHandler()
  }

  func test_renderableItems() throws {
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = LayerNode()
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when visible bounds intersects with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)
      XCTAssertEqual(items.count, 1)

      let item = items[0]
      XCTAssertEqual(item.id.id, "L")
      XCTAssertEqual(item.frame, CGRect(x: 0, y: 0, width: 100, height: 100))

      // make
      do {
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: nil))
        XCTAssertEqual(renderable.layer.frame, CGRect(x: 1, y: 2, width: 3, height: 4))
      }

      XCTAssertNil(item.willInsert)
      XCTAssertNil(item.didInsert)
      XCTAssertNil(item.willUpdate)

      // update
      do {
        let contentView = ComposeView()
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

        let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
        item.update(renderable, context)
        let layer = renderable.layer
        XCTAssertEqual(layer.frame, CGRect(x: 1, y: 2, width: 3, height: 4))
      }

      XCTAssertNil(item.willRemove)
      XCTAssertNil(item.didRemove)
      XCTAssertNil(item.transition)
      XCTAssertNil(item.animationTiming)
    }

    // when visible bounds does not intersect with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 100, width: 100, height: 100)
      let items = node.renderableItems(in: visibleBounds)
      XCTAssertEqual(items.count, 0)
    }
  }

  func test_renderableItems_visibleBounds() {
    // given a layer node with specific size
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    var node = LayerNode(layer)

    // layout the node to set its size
    _ = node.layout(containerSize: CGSize(width: 50, height: 50), context: ComposeNodeLayoutContext(scaleFactor: 1))
    XCTAssertEqual(node.size, CGSize(width: 50, height: 50))

    // when visible bounds intersects with the node frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 100) // intersects
      let items = node.renderableItems(in: visibleBounds)
      XCTAssertEqual(items.count, 1)
    }

    // when visible bounds partially intersects with the node frame
    do {
      let visibleBounds = CGRect(x: 25, y: 25, width: 50, height: 50) // partially intersects
      let items = node.renderableItems(in: visibleBounds)
      XCTAssertEqual(items.count, 1)
    }

    // when visible bounds does not intersect with the node frame
    do {
      let visibleBounds = CGRect(x: 100, y: 100, width: 50, height: 50) // no intersection
      let items = node.renderableItems(in: visibleBounds)
      XCTAssertEqual(items.count, 0) // should return empty array
    }
  }

  func test_layer_as_composeContent() {
    let view = ComposeView {
      let layer = CALayer()
      layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
      return layer
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)

    XCTAssertEqual(view.layer.sublayers?.count, 1)
    XCTAssertEqual(view.layer.sublayers?[0].frame, CGRect(x: 25, y: 25, width: 50, height: 50))
  }
}
