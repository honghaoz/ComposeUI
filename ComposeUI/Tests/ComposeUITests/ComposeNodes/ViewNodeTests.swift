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

import ChouTiTest

@testable import ComposeUI

class ViewNodeTests: XCTestCase {

  func test_id() throws {
    // then: a factory view node uses the default id
    expect(ViewNode().id.id) == "V"

    // given: an external view
    let view = View()
    let id = ObjectIdentifier(view)

    // then: a view node with the external view uses the view's identity in the id
    expect(ViewNode(view).id.id) == "view-\(id)"
  }

  func test_fixedSize() {
    do {
      // given: a view node using a view factory
      var node = ViewNode()

      // then: the size is flexible
      expect(node.isFixedWidth) == false
      expect(node.isFixedHeight) == false

      // when: setting fixed size
      node = node.fixedSize()

      // then: the size is fixed
      expect(node.isFixedWidth) == true
      expect(node.isFixedHeight) == true
    }

    do {
      // given: a view node using an external view
      var node = ViewNode(View())

      // then: the size is fixed
      expect(node.isFixedWidth) == true
      expect(node.isFixedHeight) == true

      // when: setting flexible size
      node = node.flexibleSize()

      // then: the size is flexible
      expect(node.isFixedWidth) == false
      expect(node.isFixedHeight) == false
    }
  }

  func test_constraint_based_view() {
    // given: a view with constraints
    let view = BaseView(frame: CGRect(x: 10, y: 20, width: 100, height: 50))
    expect(view.frame) == CGRect(x: 10, y: 20, width: 100, height: 50) // test initial frame

    // with constraints
    view.translatesAutoresizingMaskIntoConstraints = false
    view.widthAnchor.constraint(equalToConstant: 200).isActive = true
    view.heightAnchor.constraint(equalToConstant: 100).isActive = true

    // when the view is used in ViewNode with fixed size
    do {
      // given: the view in a fixed size ViewNode, in a compose view
      let node = ViewNode(view)
        .fixedSize()
        .padding(10)
        .frame(.flexible, alignment: .topLeft)

      let container = ComposeView(content: { node })
      container.frame = CGRect(x: 0, y: 0, width: 500, height: 500)

      // when: the compose view is refreshed
      container.refresh(animated: false)

      // then: the view's translatesAutoresizingMaskIntoConstraints is changed to true
      expect(view.translatesAutoresizingMaskIntoConstraints) == true

      // then: the view's size should not be changed
      expect(view.frame) == CGRect(x: 10, y: 10, width: 100, height: 50)

      // when: force a layout pass
      container.setNeedsLayout()
      container.layoutIfNeeded()

      // then: the view's size should not be changed
      expect(view.frame) == CGRect(x: 10, y: 10, width: 100, height: 50)

      // when: have the view update its size by constraints
      view.translatesAutoresizingMaskIntoConstraints = false
      view.setNeedsLayout()
      view.layoutIfNeeded()

      // then: the view sizes itself by the constraints
      expect(view.bounds.size) == view.intrinsicSize(for: CGSize(width: 500, height: 500))

      // when: the compose view is refreshed
      container.refresh(animated: false)

      // then: the view's frame should be changed to the size of the constraints
      expect(view.frame) == CGRect(x: 10, y: 10, width: 200, height: 100)
    }

    // when the view is used in ViewNode with flexible size
    do {
      // given: the view in a flexible size ViewNode, in a compose view
      let node = ViewNode(view)
        .flexibleSize()
        .frame(width: 210, height: 110)
        .padding(10)
        .frame(.flexible, alignment: .topLeft)

      let container = ComposeView(content: { node })
      container.frame = CGRect(x: 0, y: 0, width: 500, height: 500)

      // when: the compose view is refreshed
      container.refresh(animated: false)

      // then: the view's frame should be set by ComposéUI, not by the constraints
      expect(view.frame) == CGRect(x: 10, y: 10, width: 210, height: 110)

      // when: force a layout pass
      container.setNeedsLayout()
      container.layoutIfNeeded()

      // then: the view's frame should not be changed by the constraints
      expect(view.frame) == CGRect(x: 10, y: 10, width: 210, height: 110)
    }
  }

  func test_size() {
    // using view's bounds.size as intrinsic size
    do {
      // with external view
      do {
        // given: a view node with an external view
        let view = BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        var node = ViewNode(view)

        // fixed size
        do {
          // when: laying out the node
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the sizing and size use the view's size
          expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .fixed(50))
          expect(node.size) == CGSize(width: 50, height: 50)
        }

        // fixed width, flexible height
        do {
          // when: setting fixed width only and laying out
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width uses the view's width and the height fills the container
          expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .flexible)
          expect(node.size) == CGSize(width: 50, height: 100)
        }

        // flexible width, fixed height
        do {
          // when: setting fixed height only and laying out
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width fills the container and the height uses the view's height
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(50))
          expect(node.size) == CGSize(width: 100, height: 50)
        }

        // flexible size
        do {
          // when: setting flexible size and laying out
          node = node.flexibleSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the sizing is flexible and the size fills the container
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
          expect(node.size) == CGSize(width: 100, height: 100)
        }
      }

      // with view factory
      do {
        // given: a view node with a view factory and a custom intrinsic size
        var node = ViewNode(
          make: { _ in BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50)) },
          intrinsicSize: { containerSize in CGSize(width: containerSize.width * 2, height: containerSize.height * 2) }
        )

        // flexible size
        do {
          // when: laying out the node
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the sizing is flexible and the size fills the container
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
          expect(node.size) == CGSize(width: 100, height: 100)
        }

        // fixed width, flexible height
        do {
          // when: setting fixed width only and laying out
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width uses the intrinsic width and the height fills the container
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .flexible)
          expect(node.size) == CGSize(width: 200, height: 100)
        }

        // flexible width, fixed height
        do {
          // when: setting fixed height only and laying out
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width fills the container and the height uses the intrinsic height
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(200))
          expect(node.size) == CGSize(width: 100, height: 200)
        }

        // fixed size
        do {
          // when: setting fixed size and laying out
          node = node.fixedSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the sizing and size use the intrinsic size
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .fixed(200))
          expect(node.size) == CGSize(width: 200, height: 200)
        }
      }
    }

    // using custom intrinsic size
    do {
      // with external view
      do {
        // given: a view node with an external view and a custom intrinsic size
        let view = BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        var node = ViewNode(view, intrinsicSize: { containerSize in CGSize(width: containerSize.width * 2, height: containerSize.height * 2) })

        // fixed size
        do {
          // when: laying out the node
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the sizing and size use the intrinsic size
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .fixed(200))
          expect(node.size) == CGSize(width: 200, height: 200)
        }

        // fixed width, flexible height
        do {
          // when: setting fixed width only and laying out
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width uses the intrinsic width and the height fills the container
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .flexible)
          expect(node.size) == CGSize(width: 200, height: 100)
        }

        // flexible width, fixed height
        do {
          // when: setting fixed height only and laying out
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width fills the container and the height uses the intrinsic height
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(200))
          expect(node.size) == CGSize(width: 100, height: 200)
        }

        // flexible size
        do {
          // when: setting flexible size and laying out
          node = node.flexibleSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the sizing is flexible and the size fills the container
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
          expect(node.size) == CGSize(width: 100, height: 100)
        }
      }

      // with view factory
      do {
        // given: a view node with a view factory and a custom intrinsic size
        var node = ViewNode(
          make: { _ in BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50)) },
          intrinsicSize: { containerSize in CGSize(width: containerSize.width * 2, height: containerSize.height * 2) }
        )

        // flexible size
        do {
          // when: laying out the node
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the sizing is flexible and the size fills the container
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
          expect(node.size) == CGSize(width: 100, height: 100)
        }

        // fixed width, flexible height
        do {
          // when: setting fixed width only and laying out
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width uses the intrinsic width and the height fills the container
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .flexible)
          expect(node.size) == CGSize(width: 200, height: 100)
        }

        // flexible width, fixed height
        do {
          // when: setting fixed height only and laying out
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width fills the container and the height uses the intrinsic height
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(200))
          expect(node.size) == CGSize(width: 100, height: 200)
        }

        // fixed size
        do {
          // when: setting fixed size and laying out
          node = node.fixedSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the sizing and size use the intrinsic size
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .fixed(200))
          expect(node.size) == CGSize(width: 200, height: 200)
        }
      }
    }
  }

  func test_factoryView_fixedSize_fallbackToMeasurementView() {
    // when a factory ViewNode has fixedSize but no intrinsicSize provider, it falls back to creating a throwaway view via `make` and using its `intrinsicSize(for:)`.

    // empty view
    do {
      // given: a fixed size factory view node without an intrinsic size provider
      var node = ViewNode()
        .fixedSize()

      // when: laying out the node
      let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 1))

      // then: the sizing and size are zero
      expect(sizing) == ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
      expect(node.size) == .zero
    }

    // fixed size (width: true, height: true)
    do {
      // given: a fixed size factory node for a fixed size view, with a make call counter
      var makeCallCount = 0
      var node = ViewNode<FixedSizeView>(
        make: { _ in
          makeCallCount += 1
          return FixedSizeView()
        }
      ).fixedSize()

      // when: laying out the node
      let sizing = node.layout(containerSize: CGSize(width: 200, height: 200), context: ComposeNodeLayoutContext(scaleFactor: 1))

      // then: the measurement view provides the fixed size and make is called once
      expect(sizing) == ComposeNodeSizing(width: .fixed(80), height: .fixed(60))
      expect(node.size) == CGSize(width: 80, height: 60)
      expect(makeCallCount) == 1
    }

    // fixed width only (width: true, height: false)
    do {
      // given: a fixed width factory node for a fixed size view, with a make call counter
      var makeCallCount = 0
      var node = ViewNode<FixedSizeView>(
        make: { _ in
          makeCallCount += 1
          return FixedSizeView()
        }
      ).fixedSize(width: true, height: false)

      // when: laying out the node
      let sizing = node.layout(containerSize: CGSize(width: 200, height: 200), context: ComposeNodeLayoutContext(scaleFactor: 1))

      // then: the width uses the measurement view and the height fills the container
      expect(sizing) == ComposeNodeSizing(width: .fixed(80), height: .flexible)
      expect(node.size) == CGSize(width: 80, height: 200)
      expect(makeCallCount) == 1
    }

    // fixed height only (width: false, height: true)
    do {
      // given: a fixed height factory node for a fixed size view, with a make call counter
      var makeCallCount = 0
      var node = ViewNode<FixedSizeView>(
        make: { _ in
          makeCallCount += 1
          return FixedSizeView()
        }
      ).fixedSize(width: false, height: true)

      // when: laying out the node
      let sizing = node.layout(containerSize: CGSize(width: 200, height: 200), context: ComposeNodeLayoutContext(scaleFactor: 1))

      // then: the height uses the measurement view and the width fills the container
      expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(60))
      expect(node.size) == CGSize(width: 200, height: 60)
      expect(makeCallCount) == 1
    }
  }

  func test_view_as_composeContent() {
    // given: a compose view using a plain view as content
    let view = ComposeView {
      BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50)) as ViewType
    }

    // when: the view is sized and refreshed
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)

    // then: the view is added and centered
    expect(view.contentView().subviews.count) == 1
    expect(view.contentView().subviews[0].frame) == CGRect(x: 25, y: 25, width: 50, height: 50)
  }

  func test_renderableItems() throws {
    // given: a laid out view node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ViewNode()
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    do {
      // when: getting renderable items in visible bounds intersecting the node's frame
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)

      // then: one item with the node's id and frame is provided
      expect(items.count) == 1

      let item = items[0]
      expect(item.id.id) == "V"
      expect(item.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      do {
        // when: making a renderable
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: nil))

        // then: the renderable uses the initial frame
        expect(renderable.layer.frame) == CGRect(x: 1, y: 2, width: 3, height: 4)
      }

      // then: the item has no insert or update callbacks
      expect(item.willInsert) == nil
      expect(item.didInsert) == nil
      expect(item.willUpdate) == nil

      do {
        // given: a renderable made from the item
        let contentView = ComposeView()
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

        // when: updating the renderable
        let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
        item.update(renderable, context)

        // then: the renderable keeps its frame
        let layer = renderable.layer
        expect(layer.frame) == CGRect(x: 1, y: 2, width: 3, height: 4)
      }

      // then: the item has no remove callbacks, transition, or animation timing
      expect(item.willRemove) == nil
      expect(item.didRemove) == nil
      expect(item.transition) == nil
      expect(item.animationTiming) == nil
    }

    do {
      // when: getting renderable items in visible bounds not intersecting the node's frame
      let visibleBounds = CGRect(x: 0, y: 100, width: 100, height: 100)
      let items = node.renderableItems(in: visibleBounds)

      // then: no items are provided
      expect(items.count) == 0
    }
  }

  func test_renderableItems_visibleBounds() {
    // given: a view node with specific size
    let view = BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    var node = ViewNode(view)

    // layout the node to set its size
    _ = node.layout(containerSize: CGSize(width: 50, height: 50), context: ComposeNodeLayoutContext(scaleFactor: 1))
    expect(node.size) == CGSize(width: 50, height: 50)

    do {
      // when: getting renderable items with visible bounds intersecting the node frame
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 100) // intersects
      let items = node.renderableItems(in: visibleBounds)

      // then: one item is provided
      expect(items.count) == 1
    }

    do {
      // when: getting renderable items with visible bounds partially intersecting the node frame
      let visibleBounds = CGRect(x: 25, y: 25, width: 50, height: 50) // partially intersects
      let items = node.renderableItems(in: visibleBounds)

      // then: one item is provided
      expect(items.count) == 1
    }

    do {
      // when: getting renderable items with visible bounds not intersecting the node frame
      let visibleBounds = CGRect(x: 100, y: 100, width: 50, height: 50) // no intersection
      let items = node.renderableItems(in: visibleBounds)

      // then: no items are provided
      expect(items.count) == 0 // should return empty array
    }
  }

  #if canImport(AppKit)
  func test_nonLayerBackedView_assertion() {
    // given: a view that is not layer backed, in a compose view, with a test assertion failure handler
    let view = BaseView()
    view.wantsLayer = false // explicitly disable layer backing

    let node = ViewNode(view)
      .frame(width: 100, height: 100)

    let container = ComposeView(content: { node })
    container.frame = CGRect(x: 0, y: 0, width: 200, height: 200)

    var assertionCount = 0
    Assert.setTestAssertionFailureHandler { message, file, line, column in
      expect(message) == "\(view) should be layer backed. Please set `wantsLayer == true`."
      assertionCount += 1
    }

    // when: refreshing the compose view
    container.refresh(animated: false)

    // then: it should trigger the assertion for non-layer-backed view
    expect(assertionCount) == 1
  }
  #endif
}

// MARK: - Test Helpers

private class FixedSizeView: BaseView {

  override init(frame: CGRect) {
    super.init(frame: frame)

    #if canImport(AppKit)
    translatesAutoresizingMaskIntoConstraints = false
    widthAnchor.constraint(equalToConstant: 80).isActive = true
    heightAnchor.constraint(equalToConstant: 60).isActive = true
    #endif
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  #if canImport(UIKit)
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: 80, height: 60)
  }
  #endif
}
