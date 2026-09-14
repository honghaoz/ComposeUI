//
//  ComposeView+RenderableUpdateBoundsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/12/26.
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

class ComposeView_RenderableUpdateBoundsTests: XCTestCase {

  func test_geometryUpdates_reportViewportChangesForRetainedViewAndLayer() throws {
    // given: view and layer renderables whose appearance follows the viewport rather than their own fixed size
    var viewContext: RenderableUpdateContext?
    var layerContext: RenderableUpdateContext?
    var renderedView: BaseView?
    var renderedLayer: CALayer?
    var builderCalls = 0
    let view = ComposeView {
      builderCalls += 1
      ZStack {
        ViewNode<BaseView>(update: { renderable, context in
          renderable.layer().cornerRadius = context.renderBounds.width / 10
          renderable.layer().backgroundColor = context.renderBounds.minY > 0 ? Color.blue.cgColor : Color.red.cgColor
          renderedView = renderable
          viewContext = context
        })
        .frame(width: 300, height: 400)
        LayerNode<CALayer>(update: { layer, context in
          layer.cornerRadius = context.renderBounds.width / 10
          layer.backgroundColor = context.renderBounds.minY > 0 ? Color.blue.cgColor : Color.red.cgColor
          renderedLayer = layer
          layerContext = context
        })
        .frame(width: 300, height: 400)
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let nativeView = try unwrap(renderedView)
    let layer = try unwrap(renderedLayer)
    let initialBounds = CGRect(x: 0, y: 0, width: 100, height: 100)

    // then: initial insertion has no previous viewport and initializes both renderables
    expect(viewContext?.updateType) == .insert
    expect(layerContext?.updateType) == .insert
    expect(viewContext?.previousRenderBounds) == nil
    expect(layerContext?.previousRenderBounds) == nil
    expect(viewContext?.renderBounds) == initialBounds
    expect(layerContext?.renderBounds) == initialBounds
    expect(nativeView.layer().cornerRadius) == 10
    expect(layer.cornerRadius) == 10
    expect(nativeView.layer().backgroundColor) == Color.red.cgColor
    expect(layer.backgroundColor) == Color.red.cgColor

    // when: only the viewport origin changes
    view.setContentOffset(CGPoint(x: 0, y: 20))
    view.layoutIfNeeded()
    let scrolledBounds = CGRect(x: 0, y: 20, width: 100, height: 100)

    // then: both updates describe the scroll as a bounds change while their own frames stay fixed
    for context in try [unwrap(viewContext), unwrap(layerContext)] {
      expect(context.updateType) == .boundsChange
      expect(context.previousRenderBounds) == initialBounds
      expect(context.renderBounds) == scrolledBounds
      expect(context.oldFrame) == context.newFrame
    }
    expect(nativeView.layer().backgroundColor) == Color.blue.cgColor
    expect(layer.backgroundColor) == Color.blue.cgColor

    // when: only the viewport size changes
    view.frame.size.width = 150
    view.setNeedsLayout()
    view.layoutIfNeeded()
    let resizedBounds = CGRect(x: 0, y: 20, width: 150, height: 100)

    // then: the same renderables observe the size change without rebuilding the content
    expect(renderedView) === nativeView
    expect(renderedLayer) === layer
    for context in try [unwrap(viewContext), unwrap(layerContext)] {
      expect(context.updateType) == .boundsChange
      expect(context.previousRenderBounds) == scrolledBounds
      expect(context.renderBounds) == resizedBounds
      expect(context.oldFrame) == context.newFrame
    }
    expect(nativeView.layer().cornerRadius) == 15
    expect(layer.cornerRadius) == 15
    expect(builderCalls) == 1

    // when: a resize and an offset adjustment happen in the same pass
    view.onWillRender { contentView, _ in
      contentView.setContentOffset(CGPoint(x: 0, y: 40))
    }
    view.frame.size.width = 180
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: both geometry changes are visible independently in the snapshots
    for context in try [unwrap(viewContext), unwrap(layerContext)] {
      expect(context.updateType) == .boundsChange
      expect(context.previousRenderBounds) == resizedBounds
      expect(context.renderBounds) == CGRect(x: 0, y: 40, width: 180, height: 100)
    }
    expect(nativeView.layer().cornerRadius) == 18
    expect(layer.cornerRadius) == 18
    expect(layer.backgroundColor) == Color.blue.cgColor
    expect(builderCalls) == 1
  }

  func test_refresh_reportsGeometryChangesAlongsideConfiguration() throws {
    // given: a retained layer before application configuration and geometry change
    var color = Color.red
    var context: RenderableUpdateContext?
    var layer: CALayer?
    var builderCalls = 0
    let view = ComposeView {
      builderCalls += 1
      ColorNode(color)
        .frame(width: 300, height: 400)
        .onUpdate { renderable, update in
          layer = renderable.layer
          context = update
        }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let originalLayer = try unwrap(layer)
    let initialBounds = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: a pending non-animated refresh is combined with a resize and scroll
    color = .blue
    view.onWillRender { contentView, _ in
      contentView.setContentOffset(CGPoint(x: 0, y: 30))
    }
    view.setNeedsRefresh(animated: false)
    view.frame.size.width = 150
    view.setNeedsLayout()
    view.layoutIfNeeded()
    let refreshedBounds = CGRect(x: 0, y: 30, width: 150, height: 100)

    // then: refresh remains the update reason and geometry changes remain available
    expect(context?.updateType) == .refresh
    expect(context?.previousRenderBounds) == initialBounds
    expect(context?.renderBounds) == refreshedBounds
    expect(layer) === originalLayer
    expect(originalLayer.backgroundColor) == Color.blue.cgColor
    expect(builderCalls) == 2

    // when: an animated refresh runs with unchanged geometry
    color = .green
    view.refresh(animated: true)

    // then: both snapshots match while the configured color changes
    expect(context?.updateType) == .refresh
    expect(context?.previousRenderBounds) == refreshedBounds
    expect(context?.renderBounds) == refreshedBounds
    expect(originalLayer.backgroundColor) == Color.green.cgColor
    expect(builderCalls) == 3
  }

  func test_willRenderOffset_usesUninsetViewportForAllItems() throws {
    // given: rendering extends beyond the viewport and a callback adjusts the offset before item selection
    var contexts: [RenderableUpdateContext] = []
    var layers: [CALayer] = []
    let view = ComposeView {
      ZStack {
        for _ in 0 ..< 2 {
          LayerNode<CALayer>(update: { layer, context in
            layer.cornerRadius = context.renderBounds.minY
            contexts.append(context)
            layers.append(layer)
          })
          .frame(width: 300, height: 400)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.visibleBoundsInsets = EdgeInsets(top: -20, left: -10, bottom: -30, right: -10)
    view.onWillRender { contentView, _ in
      contentView.setContentOffset(CGPoint(x: 0, y: 50))
    }

    // when: the adjusted viewport is rendered
    view.refresh(animated: false)

    // then: every item receives the same actual viewport, without visibility insets
    expect(contexts.count) == 2
    for context in contexts {
      expect(context.previousRenderBounds) == nil
      expect(context.renderBounds) == CGRect(x: 0, y: 50, width: 100, height: 100)
    }
    for layer in layers {
      expect(layer.cornerRadius) == 50
    }

    // when: a refresh renders at the same adjusted offset
    contexts.removeAll()
    view.refresh(animated: false)

    // then: the prior completed viewport includes the earlier callback adjustment
    for context in contexts {
      expect(context.previousRenderBounds) == CGRect(x: 0, y: 50, width: 100, height: 100)
      expect(context.renderBounds) == context.previousRenderBounds
    }
  }

  func test_itemOffsetChange_doesNotMutateTheCurrentPassSnapshot() throws {
    // given: the first item can change live scroll position while the remaining items are being updated
    var changesOffset = false
    var contexts: [RenderableUpdateContext] = []
    var layers: [CALayer] = []
    let view = ComposeView {
      ZStack {
        for index in 0 ..< 2 {
          LayerNode<CALayer>(update: { layer, context in
            if index == 0, changesOffset {
              changesOffset = false
              context.contentView.setContentOffset(CGPoint(x: 0, y: 40))
            }
            layer.cornerRadius = context.renderBounds.minY
            contexts.append(context)
            layers.append(layer)
          })
          .frame(width: 300, height: 400)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    contexts.removeAll()
    layers.removeAll()
    changesOffset = true

    // when: the first item changes the live offset during a refresh
    view.refresh(animated: false)

    // then: all item contexts and output use the viewport selected before item updates began
    expect(contexts.count) == 2
    for context in contexts {
      expect(context.updateType) == .refresh
      expect(context.previousRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
      expect(context.renderBounds) == context.previousRenderBounds
    }
    for layer in layers {
      expect(layer.cornerRadius) == 0
    }

    // when: the next layout renders the new offset
    contexts.removeAll()
    layers.removeAll()
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the next pass reports the change from the previous rendered viewport
    expect(contexts.count) == 2
    for context in contexts {
      expect(context.updateType) == .boundsChange
      expect(context.previousRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
      expect(context.renderBounds) == CGRect(x: 0, y: 40, width: 100, height: 100)
    }
    for layer in layers {
      expect(layer.cornerRadius) == 40
    }
  }

  func test_zeroSizedCompletedPass_isDifferentFromNoRenderHistory() throws {
    // given: a zero-sized view whose content will be supplied later
    var showsContent = false
    var builderCalls = 0
    var context: RenderableUpdateContext?
    var layer: CALayer?
    let view = ComposeView {
      builderCalls += 1
      if showsContent {
        LayerNode<CALayer>(update: { renderable, update in
          renderable.backgroundColor = Color.red.cgColor
          layer = renderable
          context = update
        })
      }
    }
    view.frame = .zero

    // when: zero-sized layout is requested before any render
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: layout alone keeps the existing no-render behavior at zero size
    expect(view.test.lastRenderBounds) == nil
    expect(builderCalls) == 0

    // when: an explicit refresh completes an empty, zero-sized pass
    view.refresh(animated: false)

    // then: the completed pass establishes real zero bounds
    expect(view.test.lastRenderBounds) == .some(.zero)
    expect(builderCalls) == 1
    expect(layer) == nil

    // when: a pending refresh supplies content as the view becomes nonzero
    showsContent = true
    view.setNeedsRefresh(animated: false)
    view.frame.size = CGSize(width: 100, height: 100)
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: insertion reports the completed zero-sized pass rather than missing history
    let update = try unwrap(context)
    expect(update.updateType) == .insert
    expect(update.previousRenderBounds) == .some(.zero)
    expect(update.renderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(layer?.backgroundColor) == Color.red.cgColor
    expect(layer?.frame) == update.renderBounds
    expect(builderCalls) == 2
  }

  func test_removingAllContent_doesNotResetViewportHistory() throws {
    // given: a view displaying a layer after its first completed pass
    var showsContent = true
    var context: RenderableUpdateContext?
    var layer: CALayer?
    let view = ComposeView {
      if showsContent {
        LayerNode<CALayer>(update: { renderable, update in
          renderable.backgroundColor = Color.blue.cgColor
          layer = renderable
          context = update
        })
      }
    }
    let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.frame = bounds
    view.refresh(animated: false)
    let originalLayer = try unwrap(layer)
    expect(context?.previousRenderBounds) == nil

    // when: a refresh removes every renderable and completes an empty pass
    showsContent = false
    view.refresh(animated: false)
    context = nil

    // then: the host still remembers the completed viewport
    expect(originalLayer.superlayer) == nil
    expect(view.test.lastRenderBounds) == bounds

    // when: another refresh supplies content
    showsContent = true
    view.refresh(animated: true)

    // then: the new insertion has previous bounds even though no renderables were retained
    let update = try unwrap(context)
    expect(update.updateType) == .insert
    expect(update.previousRenderBounds) == bounds
    expect(update.renderBounds) == bounds
    expect(layer?.backgroundColor) == Color.blue.cgColor
  }

  func test_emptyPassAndNewlyVisibleItems_preserveViewportHistory() throws {
    // given: the first viewport contains no renderables
    var context: RenderableUpdateContext?
    var layer: CALayer?
    let view = ComposeView {
      VStack(spacing: 0) {
        Spacer(height: 200)
        LayerNode<CALayer>(update: { renderable, update in
          renderable.backgroundColor = Color.blue.cgColor
          layer = renderable
          context = update
        })
        .frame(width: .flexible, height: 100)
        Spacer(height: 200)
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)

    // then: the offscreen layer has not been created
    expect(layer) == nil

    // when: scrolling reveals the layer
    view.setContentOffset(CGPoint(x: 0, y: 200))
    view.layoutIfNeeded()
    let originalLayer = try unwrap(layer)

    // then: insertion has the previous empty pass's viewport rather than missing history
    expect(context?.updateType) == .insert
    expect(context?.previousRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(context?.renderBounds) == CGRect(x: 0, y: 200, width: 100, height: 100)
    expect(originalLayer.backgroundColor) == Color.blue.cgColor

    // when: the layer is removed and revealed again
    view.setContentOffset(CGPoint(x: 0, y: 350))
    view.layoutIfNeeded()
    expect(originalLayer.superlayer) == nil
    context = nil
    view.setContentOffset(CGPoint(x: 0, y: 200))
    view.layoutIfNeeded()

    // then: a later insertion still reports the immediately preceding viewport
    expect(context?.updateType) == .insert
    expect(context?.previousRenderBounds) == CGRect(x: 0, y: 350, width: 100, height: 100)
    expect(context?.renderBounds) == CGRect(x: 0, y: 200, width: 100, height: 100)
    expect(layer?.backgroundColor) == Color.blue.cgColor
  }

  func test_nestedView_usesItsOwnViewportHistory() throws {
    // given: a nested view with independent bounds and scroll position
    var innerView: ComposeView?
    var parentContext: RenderableUpdateContext?
    var childContext: RenderableUpdateContext?
    var layer: CALayer?
    let parent = ComposeView {
      ComposeViewNode {
        LayerNode<CALayer>(update: { renderable, context in
          renderable.cornerRadius = context.renderBounds.minY
          layer = renderable
          childContext = context
        })
        .frame(width: .flexible, height: 400)
      }
      .flexibleSize()
      .frame(width: 100, height: 100)
      .onUpdate { renderable, context in
        innerView = renderable.view as? ComposeView
        parentContext = context
      }
    }
    parent.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
    parent.refresh(animated: false)
    let child = try unwrap(innerView)
    let originalLayer = try unwrap(layer)

    // then: parent and child insertion contexts describe their own viewports
    expect(parentContext?.previousRenderBounds) == nil
    expect(parentContext?.renderBounds) == CGRect(x: 0, y: 0, width: 200, height: 200)
    expect(childContext?.previousRenderBounds) == nil
    expect(childContext?.renderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: only the child scrolls
    child.setContentOffset(CGPoint(x: 0, y: 30))
    child.layoutIfNeeded()

    // then: the child's snapshots and output reflect its independent position
    expect(childContext?.updateType) == .boundsChange
    expect(childContext?.previousRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(childContext?.renderBounds) == CGRect(x: 0, y: 30, width: 100, height: 100)
    expect(originalLayer.cornerRadius) == 30

    // when: the parent refreshes and supplies the nested content again
    parent.refresh(animated: true)

    // then: the child's refresh keeps its own previous viewport and inherits the parent's animated decision
    expect(childContext?.updateType) == .refresh
    expect(childContext?.previousRenderBounds) == CGRect(x: 0, y: 30, width: 100, height: 100)
    expect(childContext?.renderBounds) == childContext?.previousRenderBounds
    expect(childContext?.animationDecision) == ComposeView.AnimationDecision.all
    expect(layer) === originalLayer
    expect(originalLayer.cornerRadius) == 30
  }

  func test_deferredRefresh_usesTheLastCompletedViewport() throws {
    // given: an item requests a refresh while its bounds update is still rendering
    var color = Color.red
    var requestsRefresh = false
    var contexts: [RenderableUpdateContext] = []
    var layer: CALayer?
    let view = ComposeView {
      ColorNode(color)
        .frame(width: .flexible, height: 400)
        .onUpdate { renderable, context in
          layer = renderable.layer
          contexts.append(context)
          if requestsRefresh {
            requestsRefresh = false
            color = .blue
            context.contentView.refresh(animated: false)
          }
        }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let originalLayer = try unwrap(layer)
    contexts.removeAll()
    requestsRefresh = true

    // when: scrolling starts the pass that requests another refresh
    view.setContentOffset(CGPoint(x: 0, y: 20))
    view.layoutIfNeeded()
    expect(contexts.last?.updateType).toEventually(beEqual(to: .refresh))

    // then: the deferred refresh starts from the completed scroll pass, not the earlier viewport
    expect(contexts.count) == 2
    expect(contexts[0].updateType) == .boundsChange
    expect(contexts[0].previousRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(contexts[0].renderBounds) == CGRect(x: 0, y: 20, width: 100, height: 100)
    expect(contexts[1].previousRenderBounds) == contexts[0].renderBounds
    expect(contexts[1].renderBounds) == contexts[0].renderBounds
    expect(layer) === originalLayer
    expect(originalLayer.backgroundColor) == Color.blue.cgColor
  }

  func test_pooledInsertion_usesTheHostViewportRatherThanTheLayerFrame() throws {
    // given: one row visible at a time and a private pool used to recycle its layer
    var layers: [Int: CALayer] = [:]
    var contexts: [Int: RenderableUpdateContext] = [:]
    let view = ComposeView {
      VStack(spacing: 0) {
        for index in 0 ..< 3 {
          ColorNode(index == 0 ? .red : .blue)
            .frame(width: .flexible, height: 100)
            .onUpdate { renderable, context in
              layers[index] = renderable.layer
              contexts[index] = context
            }
        }
      }
    }
    view.renderablePool = RenderablePool()
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let firstLayer = try unwrap(layers[0])

    // when: scrolling replaces the visible row
    view.setContentOffset(CGPoint(x: 0, y: 200))
    view.layoutIfNeeded()

    // then: the recycled layer is initialized with the new row's color and the host's history
    expect(layers[2]) === firstLayer
    expect(firstLayer.backgroundColor) == Color.blue.cgColor
    expect(contexts[2]?.updateType) == .insert
    expect(contexts[2]?.previousRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(contexts[2]?.renderBounds) == CGRect(x: 0, y: 200, width: 100, height: 100)
    expect(firstLayer.frame) == CGRect(x: 0, y: 200, width: 100, height: 100)
  }

  func test_revivedInsertion_usesTheViewportAfterRemoval() throws {
    // given: a row with an in-flight removal when scrolled offscreen
    var layer: CALayer?
    var context: RenderableUpdateContext?
    let view = ComposeView {
      VStack(spacing: 0) {
        ColorNode(.red)
          .frame(width: .flexible, height: 100)
          .transition(.opacity(timing: .linear(duration: 10)))
          .onUpdate { renderable, update in
            layer = renderable.layer
            context = update
          }
        Spacer(height: 400)
      }
    }
    view.renderablePool = nil
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let originalLayer = try unwrap(layer)

    // when: the row scrolls out of view and returns before removal completes
    view.setContentOffset(CGPoint(x: 0, y: 200))
    view.layoutIfNeeded()
    expect(originalLayer.superlayer) != nil
    context = nil
    view.setContentOffset(.zero)
    view.layoutIfNeeded()

    // then: the revived layer receives insertion with the immediately preceding viewport
    expect(layer) === originalLayer
    expect(context?.updateType) == .insert
    expect(originalLayer.animation(forKey: "opacity")) != nil
    expect(context?.previousRenderBounds) == CGRect(x: 0, y: 200, width: 100, height: 100)
    expect(context?.renderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(originalLayer.backgroundColor) == Color.red.cgColor
    expect(originalLayer.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    originalLayer.removeAllAnimations()
  }

  func test_contentShrink_rendersTheClampedViewportWithoutAWillRenderCallback() throws {
    // given: long content is scrolled near its bottom
    var height: CGFloat = 500
    var context: RenderableUpdateContext?
    var layer: CALayer?
    let view = ComposeView {
      LayerNode<CALayer>(update: { renderable, update in
        renderable.backgroundColor = Color.red.cgColor
        layer = renderable
        context = update
      })
      .frame(width: .flexible, height: height)
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    view.setContentOffset(CGPoint(x: 0, y: 350))
    view.layoutIfNeeded()
    let previousBounds = CGRect(x: 0, y: 350, width: 100, height: 100)
    expect(try unwrap(context).renderBounds) == previousBounds
    context = nil

    // when: refreshed content is shorter than the old scroll offset
    height = 150
    view.refresh(animated: false)

    // then: the scroll view clamps the offset to the new content size, and the pass renders the clamped viewport
    let clampedBounds = CGRect(x: 0, y: 50, width: 100, height: 100)
    expect(view.contentOffset()) == clampedBounds.origin
    let update = try unwrap(context)
    expect(update.updateType) == .refresh
    expect(update.previousRenderBounds) == previousBounds
    expect(update.renderBounds) == clampedBounds
    let renderedLayer = try unwrap(layer)
    expect(renderedLayer.superlayer) != nil
    expect(renderedLayer.frame) == CGRect(x: 0, y: 0, width: 100, height: 150)
    expect(renderedLayer.backgroundColor) == Color.red.cgColor
    expect(view.test.lastRenderBounds) == clampedBounds

    // when: laying out again without changing the viewport
    context = nil
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the clamped viewport is already the render history, so no pass is repeated
    expect(context) == nil
    expect(renderedLayer.superlayer) != nil
  }
}
