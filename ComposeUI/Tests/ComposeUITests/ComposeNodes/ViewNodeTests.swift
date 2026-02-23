//
//  ViewNodeTests.swift
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

class ViewNodeTests: XCTestCase {

  func test_id() throws {
    XCTAssertEqual(ViewNode().id.id, "V")

    let view = UIView()
    let id = ObjectIdentifier(view)
    XCTAssertEqual(ViewNode(view).id.id, "view-\(id)")
  }

  func test_fixedSize() {
    do {
      // when using view factory
      var node = ViewNode()

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
      // when using external view
      var node = ViewNode(UIView())

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

  func test_constraint_based_view() {
    // given a view with constraints
    let view = UIView(frame: CGRect(x: 10, y: 20, width: 100, height: 50))
    XCTAssertEqual(view.frame, CGRect(x: 10, y: 20, width: 100, height: 50)) // test initial frame

    // with constraints
    view.translatesAutoresizingMaskIntoConstraints = false
    view.widthAnchor.constraint(equalToConstant: 200).isActive = true
    view.heightAnchor.constraint(equalToConstant: 100).isActive = true

    // when the view is used in ViewNode with fixed size
    do {
      let node = ViewNode(view)
        .fixedSize()
        .padding(10)
        .frame(.flexible, alignment: .topLeft)

      let container = ComposeView(content: { node })
      container.frame = CGRect(x: 0, y: 0, width: 500, height: 500)

      container.refresh(animated: false)

      // the view's translatesAutoresizingMaskIntoConstraints is changed to true
      XCTAssertEqual(view.translatesAutoresizingMaskIntoConstraints, true)

      // the view's size should not be changed
      XCTAssertEqual(view.frame, CGRect(x: 10, y: 10, width: 100, height: 50))

      // force a layout pass
      container.setNeedsLayout()
      container.layoutIfNeeded()
      // the view's size should not be changed
      XCTAssertEqual(view.frame, CGRect(x: 10, y: 10, width: 100, height: 50))

      // have the view update its size by constraints
      view.translatesAutoresizingMaskIntoConstraints = false
      view.setNeedsLayout()
      view.layoutIfNeeded()
      XCTAssertEqual(view.bounds.size, view.intrinsicSize(for: CGSize(width: 500, height: 500)))
      container.refresh(animated: false)
      // the view's frame should be changed to the size of the constraints
      XCTAssertEqual(view.frame, CGRect(x: 10, y: 10, width: 200, height: 100))
    }

    // when the view is used in ViewNode with flexible size
    do {
      let node = ViewNode(view)
        .flexibleSize()
        .frame(width: 210, height: 110)
        .padding(10)
        .frame(.flexible, alignment: .topLeft)

      let container = ComposeView(content: { node })
      container.frame = CGRect(x: 0, y: 0, width: 500, height: 500)

      container.refresh(animated: false)

      // the view's frame should be set by ComposéUI, not by the constraints
      XCTAssertEqual(view.frame, CGRect(x: 10, y: 10, width: 210, height: 110))

      // force a layout pass
      container.setNeedsLayout()
      container.layoutIfNeeded()
      // the view's frame should not be changed by the constraints
      XCTAssertEqual(view.frame, CGRect(x: 10, y: 10, width: 210, height: 110))
    }
  }

  func test_size() {
    // using view's bounds.size as intrinsic size
    do {
      // with external view
      do {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        var node = ViewNode(view)

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

      // with view factory
      do {
        var node = ViewNode(
          make: { _ in UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50)) },
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
      // with external view
      do {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        var node = ViewNode(view, intrinsicSize: { containerSize in CGSize(width: containerSize.width * 2, height: containerSize.height * 2) })

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

      // with view factory
      do {
        var node = ViewNode(
          make: { _ in UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50)) },
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

  func test_factoryView_requiresIntrinsicSizeForFixedSizing() {
    var node = ViewNode()
      .fixedSize()

    var assertionCount = 0
    ComposeAssert.setTestAssertionFailureHandler { message, file, line, column in
      XCTAssertEqual(message, "ViewNode requires `intrinsicSize` when using fixed size with a view factory.")
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
    var node = ViewNode()
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when visible bounds intersects with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)
      XCTAssertEqual(items.count, 1)

      let item = items[0]
      XCTAssertEqual(item.id.id, "V")
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
    // given a view node with specific size
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    var node = ViewNode(view)

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
}
