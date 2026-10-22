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

import ChouTiTest

@testable import ComposeUI

class LayerNodeTests: XCTestCase {

  func test_id() throws {
    // then: a factory layer node has the standard id
    expect(LayerNode().id.id) == "L"

    // given: two external layers
    let layer = CALayer()
    let otherLayer = CALayer()

    // then: an external layer node's id is the layer's, which the nodes of the layer share, and the nodes of another
    // layer don't
    expect(LayerNode(layer).id) == ComposeNodeId.object(layer, kind: .layer)
    expect(LayerNode(layer).id) == LayerNode(layer).id
    expect(LayerNode(layer).id) != LayerNode(otherLayer).id
  }

  func test_fixedSize() {
    do {
      // given: a node using layer factory
      var node = LayerNode<CALayer>()

      // then: the size is flexible
      expect(node.isFixedWidth) == false
      expect(node.isFixedHeight) == false

      // when: set fixed size
      node = node.fixedSize()

      // then: the size is fixed
      expect(node.isFixedWidth) == true
      expect(node.isFixedHeight) == true
    }

    do {
      // given: a node using external layer
      var node = LayerNode(CALayer())

      // then: the size is fixed
      expect(node.isFixedWidth) == true
      expect(node.isFixedHeight) == true

      // when: set flexible size
      node = node.flexibleSize()

      // then: the size is flexible
      expect(node.isFixedWidth) == false
      expect(node.isFixedHeight) == false
    }
  }

  func test_size() {
    // using layer's bounds.size as intrinsic size
    do {
      // given: a node with an external layer
      do {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        var node = LayerNode(layer)

        // when: laying out with fixed size
        do {
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the size is the layer's size
          expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .fixed(50))
          expect(node.size) == CGSize(width: 50, height: 50)
        }

        // when: laying out with fixed width, flexible height
        do {
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width is the layer's width and the height fills the container
          expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .flexible)
          expect(node.size) == CGSize(width: 50, height: 100)
        }

        // when: laying out with flexible width, fixed height
        do {
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width fills the container and the height is the layer's height
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(50))
          expect(node.size) == CGSize(width: 100, height: 50)
        }

        // when: laying out with flexible size
        do {
          node = node.flexibleSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the node fills the container
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
          expect(node.size) == CGSize(width: 100, height: 100)
        }
      }

      // given: a node created with a layer factory and custom intrinsic size
      do {
        var node = LayerNode(
          make: { _ in
            let layer = CALayer()
            layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            return layer
          },
          intrinsicSize: { containerSize in CGSize(width: containerSize.width * 2, height: containerSize.height * 2) }
        )

        // when: laying out with flexible size
        do {
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the node fills the container
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
          expect(node.size) == CGSize(width: 100, height: 100)
        }

        // when: laying out with fixed width, flexible height
        do {
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width is the intrinsic width and the height fills the container
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .flexible)
          expect(node.size) == CGSize(width: 200, height: 100)
        }

        // when: laying out with flexible width, fixed height
        do {
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width fills the container and the height is the intrinsic height
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(200))
          expect(node.size) == CGSize(width: 100, height: 200)
        }

        // when: laying out with fixed size
        do {
          node = node.fixedSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the size is the intrinsic size
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .fixed(200))
          expect(node.size) == CGSize(width: 200, height: 200)
        }
      }
    }

    // using custom intrinsic size
    do {
      // given: a node with an external layer and custom intrinsic size
      do {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        var node = LayerNode(layer, intrinsicSize: { containerSize in CGSize(width: containerSize.width * 2, height: containerSize.height * 2) })

        // when: laying out with fixed size
        do {
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the size is the custom intrinsic size
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .fixed(200))
          expect(node.size) == CGSize(width: 200, height: 200)
        }

        // when: laying out with fixed width, flexible height
        do {
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width is the intrinsic width and the height fills the container
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .flexible)
          expect(node.size) == CGSize(width: 200, height: 100)
        }

        // when: laying out with flexible width, fixed height
        do {
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width fills the container and the height is the intrinsic height
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(200))
          expect(node.size) == CGSize(width: 100, height: 200)
        }

        // when: laying out with flexible size
        do {
          node = node.flexibleSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the node fills the container
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
          expect(node.size) == CGSize(width: 100, height: 100)
        }
      }

      // given: a node created with a layer factory and custom intrinsic size
      do {
        var node = LayerNode(
          make: { _ in
            let layer = CALayer()
            layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            return layer
          },
          intrinsicSize: { containerSize in CGSize(width: containerSize.width * 2, height: containerSize.height * 2) }
        )

        // when: laying out with flexible size
        do {
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the node fills the container
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
          expect(node.size) == CGSize(width: 100, height: 100)
        }

        // when: laying out with fixed width, flexible height
        do {
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width is the intrinsic width and the height fills the container
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .flexible)
          expect(node.size) == CGSize(width: 200, height: 100)
        }

        // when: laying out with flexible width, fixed height
        do {
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width fills the container and the height is the intrinsic height
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(200))
          expect(node.size) == CGSize(width: 100, height: 200)
        }

        // when: laying out with fixed size
        do {
          node = node.fixedSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the size is the intrinsic size
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .fixed(200))
          expect(node.size) == CGSize(width: 200, height: 200)
        }
      }
    }
  }

  func test_make_default_makesTheLayerTypeAtTheInitialFrame() throws {
    // given: a node of a layer subclass with the default layer factory
    let node = LayerNode<CAShapeLayer>()

    // when: making its layer with an initial frame
    let layer = try makeLayer(of: node, initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4))

    // then: the layer is of the node's type, at the initial frame
    expect(layer is CAShapeLayer) == true
    expect(layer.frame) == CGRect(x: 1, y: 2, width: 3, height: 4)

    // when: making its layer without an initial frame
    let layerWithoutInitialFrame = try makeLayer(of: node, initialFrame: nil)

    // then: the layer is of the node's type, at a zero frame
    expect(layerWithoutInitialFrame is CAShapeLayer) == true
    expect(layerWithoutInitialFrame.frame) == .zero
  }

  func test_make_nil_makesTheDefaultLayer() throws {
    // given: a node of a layer subclass with a nil layer factory
    let node = LayerNode<CAShapeLayer>(make: nil)

    // when: making its layer with an initial frame
    let layer = try makeLayer(of: node, initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4))

    // then: the layer is the default one, of the node's type at the initial frame
    expect(layer is CAShapeLayer) == true
    expect(layer.frame) == CGRect(x: 1, y: 2, width: 3, height: 4)
  }

  func test_make_custom_makesTheCustomLayer() throws {
    // given: a node with a custom layer factory
    let customLayer = CALayer()
    let node = LayerNode(make: { _ in customLayer })

    // when: making its layer
    let layer = try makeLayer(of: node, initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4))

    // then: the layer is the custom one
    expect(layer) === customLayer
  }

  func test_init_withALayerFactory_keepsTheFactoryWithoutAllocating() {
    // given: a layer factory and an update, and a body that makes a node with them, run once already, since a first run
    // can also allocate what the runtime makes on first use, such as type metadata
    let make: (RenderableMakeContext) -> CAShapeLayer = { _ in CAShapeLayer() }
    let update: (CAShapeLayer, RenderableUpdateContext) -> Void = { _, _ in }
    let body = {
      _ = LayerNode(make: make, update: update)
    }
    _ = AllocationCounter.count(body)

    // when: counting the allocations of the body
    let allocations = AllocationCounter.count(body)

    // then: the node keeps the factory as it is, without wrapping it in a reabstraction thunk
    expect(allocations) == 0
  }

  func test_factoryLayer_requiresIntrinsicSizeForFixedSizing() {
    // given: a fixed size layer node with a layer factory and no intrinsic size
    var node = LayerNode()
      .fixedSize()

    var assertionCount = 0
    Assert.setTestAssertionFailureHandler { message, file, line, column in
      expect(message) == "LayerNode requires `intrinsicSize` when using fixed size with a layer factory."
      assertionCount += 1
    }

    // when: laying out in a 100x100 container
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 1))

    // then: the assertion is triggered and the size falls back to zero
    expect(sizing) == ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
    expect(node.size) == .zero
    expect(assertionCount) == 1

    Assert.resetTestAssertionFailureHandler()
  }

  func test_renderableItems() throws {
    // given: a laid out layer node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = LayerNode()
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when: visible bounds intersects with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)

      // then: a single layer item is provided with the expected id, frame, and behaviors
      expect(items.count) == 1

      let item = items[0]
      expect(item.id.id) == "L"
      expect(item.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      // make
      do {
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: nil))
        expect(renderable.layer.frame) == CGRect(x: 1, y: 2, width: 3, height: 4)
      }

      expect(item.willInsert) == nil
      expect(item.didInsert) == nil
      expect(item.willUpdate) == nil

      // update
      do {
        let contentView = ComposeView()
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

        let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, previousRenderBounds: .zero, renderBounds: .zero, animationTiming: nil, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)
        item.update(renderable, context)
        let layer = renderable.layer
        expect(layer.frame) == CGRect(x: 1, y: 2, width: 3, height: 4)
      }

      expect(item.willRemove) == nil
      expect(item.didRemove) == nil
      expect(item.transition) == nil
      expect(item.animationTiming) == nil
    }

    // when: visible bounds does not intersect with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 100, width: 100, height: 100)
      let items = node.renderableItems(in: visibleBounds)

      // then: no items are provided
      expect(items.count) == 0
    }
  }

  func test_renderableItems_visibleBounds() {
    // given: a layer node with specific size
    let layer = CALayer()
    layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    var node = LayerNode(layer)

    // layout the node to set its size
    _ = node.layout(containerSize: CGSize(width: 50, height: 50), context: ComposeNodeLayoutContext(scaleFactor: 1))
    expect(node.size) == CGSize(width: 50, height: 50)

    // when: visible bounds intersects with the node frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 100) // intersects
      let items = node.renderableItems(in: visibleBounds)

      // then: one item is provided
      expect(items.count) == 1
    }

    // when: visible bounds partially intersects with the node frame
    do {
      let visibleBounds = CGRect(x: 25, y: 25, width: 50, height: 50) // partially intersects
      let items = node.renderableItems(in: visibleBounds)

      // then: one item is provided
      expect(items.count) == 1
    }

    // when: visible bounds does not intersect with the node frame
    do {
      let visibleBounds = CGRect(x: 100, y: 100, width: 50, height: 50) // no intersection
      let items = node.renderableItems(in: visibleBounds)

      // then: no items are provided
      expect(items.count) == 0 // should return empty array
    }
  }

  func test_update_appliesBoundsAndScrollDependentConfiguration() throws {
    // given: a layer whose appearance depends on its width and the container's scroll position
    var renderedLayer: CALayer?
    var updateType: RenderableUpdateType?
    let contentView = ComposeView {
      LayerNode<CALayer>(update: { layer, context in
        layer.cornerRadius = context.newFrame.width / 4
        layer.backgroundColor = context.contentView.contentOffset.y > 0 ? Color.blue.cgColor : Color.red.cgColor
        renderedLayer = layer
        updateType = context.updateType
      })
      .frame(width: .flexible, height: 200)
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the layer is inserted
    contentView.refresh(animated: false)

    // then: the initial configuration is applied
    let layer = try unwrap(renderedLayer)
    expect(layer.frame) == CGRect(x: 0, y: 0, width: 100, height: 200)
    expect(layer.cornerRadius) == 25
    expect(layer.backgroundColor) == Color.red.cgColor
    expect(updateType) == .insert

    // when: the container is resized
    contentView.frame.size.width = 200
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: the same layer receives its new size-dependent configuration
    expect(renderedLayer) === layer
    expect(layer.frame) == CGRect(x: 0, y: 0, width: 200, height: 200)
    expect(layer.cornerRadius) == 50
    expect(layer.backgroundColor) == Color.red.cgColor
    expect(updateType) == .boundsChange

    // when: the container scrolls
    contentView.contentOffset = CGPoint(x: 0, y: 20)
    contentView.layoutIfNeeded()

    // then: custom updates can also apply scroll-dependent configuration without changing the content-space frame
    expect(renderedLayer) === layer
    expect(layer.frame) == CGRect(x: 0, y: 0, width: 200, height: 200)
    expect(layer.cornerRadius) == 50
    expect(layer.backgroundColor) == Color.blue.cgColor
    expect(updateType) == .boundsChange
  }

  func test_layer_as_composeContent() {
    // given: a compose view with a fixed size layer as content
    let view = ComposeView {
      let layer = CALayer()
      layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
      return layer
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the view is refreshed
    view.refresh(animated: false)

    // then: the layer is rendered centered at its fixed size
    #if canImport(AppKit)
    expect(view.contentContainerView.layer?.sublayers?.count) == 1
    expect(view.contentContainerView.layer?.sublayers?[0].frame) == CGRect(x: 25, y: 25, width: 50, height: 50)
    #endif
    #if canImport(UIKit)
    expect(view.contentContainerView.layer.sublayers?.count) == 1
    expect(view.contentContainerView.layer.sublayers?[0].frame) == CGRect(x: 25, y: 25, width: 50, height: 50)
    #endif
  }

  // MARK: - Helpers

  /// Lays out the node and makes the layer of its item.
  private func makeLayer(of node: LayerNode<some Any>, initialFrame: CGRect?) throws -> CALayer {
    var node = node
    _ = node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 1))
    let item = try unwrap(node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10)).first)
    return item.make(RenderableMakeContext(initialFrame: initialFrame, contentView: nil)).layer
  }
}
