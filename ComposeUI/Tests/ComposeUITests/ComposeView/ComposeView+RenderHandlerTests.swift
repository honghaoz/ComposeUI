//
//  ComposeView+RenderHandlerTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/3/25.
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

class ComposeView_RenderHandlerTests: XCTestCase {

  func test_renderHandlers_contentSizeSmallerThanContainerSize() {
    // given: a compose view with content smaller than the container
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      ColorNode(.red)
        .frame(width: 50, height: 80)
    }

    var callOrder: [String] = []

    var willLayoutContainerSize: CGSize?
    var willLayoutRenderType: ComposeView.RenderType?
    view.onWillLayout { _, context in
      callOrder.append("willLayout")
      willLayoutContainerSize = context.containerSize
      willLayoutRenderType = context.renderType
    }

    var willRenderContentSize: CGSize?
    var willRenderRenderBounds: CGRect?
    var willRenderRenderType: ComposeView.RenderType?
    view.onWillRender { _, context in
      callOrder.append("willRender")
      willRenderContentSize = context.contentSize
      willRenderRenderBounds = context.renderBounds
      willRenderRenderType = context.renderType
    }

    var didRenderContentSize: CGSize?
    var didRenderRenderBounds: CGRect?
    var didRenderRenderType: ComposeView.RenderType?
    view.onDidRender { _, context in
      callOrder.append("didRender")
      didRenderContentSize = context.contentSize
      didRenderRenderBounds = context.renderBounds
      didRenderRenderType = context.renderType
    }

    // when: the view is refreshed
    view.refresh(animated: false)

    // then: all handlers should be called in the correct order
    expect(callOrder) == ["willLayout", "willRender", "didRender"]

    // then: willLayout should receive the container size
    expect(willLayoutContainerSize) == CGSize(width: 100, height: 100)
    expect(willLayoutRenderType) == .refresh(isAnimated: false)

    // then: willRender should receive the content size adjusted to the container size
    expect(willRenderContentSize) == CGSize(width: 100, height: 100)
    expect(willRenderRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(willRenderRenderType) == .refresh(isAnimated: false)

    // then: didRender should receive the same adjusted content size
    expect(didRenderContentSize) == CGSize(width: 100, height: 100)
    expect(didRenderRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(didRenderRenderType) == .refresh(isAnimated: false)

    // when: the view is resized
    callOrder = []
    willLayoutContainerSize = nil
    willLayoutRenderType = nil
    willRenderContentSize = nil
    willRenderRenderBounds = nil
    willRenderRenderType = nil
    didRenderContentSize = nil
    didRenderRenderBounds = nil
    didRenderRenderType = nil

    view.frame.size = CGSize(width: 150, height: 150)
    view.layoutIfNeeded()

    // then: all handlers should be called with bounds change
    expect(callOrder) == ["willLayout", "willRender", "didRender"]

    expect(willLayoutContainerSize) == CGSize(width: 150, height: 150)
    expect(willLayoutRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100), bounds: CGRect(x: 0, y: 0, width: 150, height: 150))

    // the content (50x80) is still smaller than the new container (150x150), so content size is adjusted
    expect(willRenderContentSize) == CGSize(width: 150, height: 150)
    expect(willRenderRenderBounds) == CGRect(x: 0, y: 0, width: 150, height: 150)
    expect(willRenderRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100), bounds: CGRect(x: 0, y: 0, width: 150, height: 150))

    expect(didRenderContentSize) == CGSize(width: 150, height: 150)
    expect(didRenderRenderBounds) == CGRect(x: 0, y: 0, width: 150, height: 150)
    expect(didRenderRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100), bounds: CGRect(x: 0, y: 0, width: 150, height: 150))
  }

  func test_renderHandlers_contentSizeLargerThanContainerSize() {
    // given: a compose view with content larger than the container
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      ColorNode(.red)
        .frame(width: 100, height: 200)
    }

    var callOrder: [String] = []

    var willLayoutContainerSize: CGSize?
    var willLayoutRenderType: ComposeView.RenderType?
    view.onWillLayout { _, context in
      callOrder.append("willLayout")
      willLayoutContainerSize = context.containerSize
      willLayoutRenderType = context.renderType
    }

    var willRenderContentSize: CGSize?
    var willRenderRenderBounds: CGRect?
    var willRenderRenderType: ComposeView.RenderType?
    view.onWillRender { _, context in
      callOrder.append("willRender")
      willRenderContentSize = context.contentSize
      willRenderRenderBounds = context.renderBounds
      willRenderRenderType = context.renderType
    }

    var didRenderContentSize: CGSize?
    var didRenderRenderBounds: CGRect?
    var didRenderRenderType: ComposeView.RenderType?
    view.onDidRender { _, context in
      callOrder.append("didRender")
      didRenderContentSize = context.contentSize
      didRenderRenderBounds = context.renderBounds
      didRenderRenderType = context.renderType
    }

    // when: the view is refreshed
    view.refresh(animated: false)

    // then: all handlers should be called in the correct order
    expect(callOrder) == ["willLayout", "willRender", "didRender"]

    // then: willLayout should receive the container size
    expect(willLayoutContainerSize) == CGSize(width: 100, height: 100)
    expect(willLayoutRenderType) == .refresh(isAnimated: false)

    // then: willRender should receive the actual content size (not adjusted)
    expect(willRenderContentSize) == CGSize(width: 100, height: 200)
    expect(willRenderRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(willRenderRenderType) == .refresh(isAnimated: false)

    // then: didRender should receive the same content size
    expect(didRenderContentSize) == CGSize(width: 100, height: 200)
    expect(didRenderRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(didRenderRenderType) == .refresh(isAnimated: false)

    // when: the view is scrolled
    callOrder = []
    willLayoutContainerSize = nil
    willLayoutRenderType = nil
    willRenderContentSize = nil
    willRenderRenderBounds = nil
    willRenderRenderType = nil
    didRenderContentSize = nil
    didRenderRenderBounds = nil
    didRenderRenderType = nil

    view.setContentOffset(CGPoint(x: 0, y: 50))
    view.layoutIfNeeded()

    // then: all handlers should be called with scroll render type
    expect(callOrder) == ["willLayout", "willRender", "didRender"]

    expect(willLayoutContainerSize) == CGSize(width: 100, height: 100)
    expect(willLayoutRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100), bounds: CGRect(x: 0, y: 50, width: 100, height: 100))

    expect(willRenderContentSize) == CGSize(width: 100, height: 200)
    expect(willRenderRenderBounds) == CGRect(x: 0, y: 50, width: 100, height: 100)
    expect(willRenderRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100), bounds: CGRect(x: 0, y: 50, width: 100, height: 100))

    expect(didRenderContentSize) == CGSize(width: 100, height: 200)
    expect(didRenderRenderBounds) == CGRect(x: 0, y: 50, width: 100, height: 100)
    expect(didRenderRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100), bounds: CGRect(x: 0, y: 50, width: 100, height: 100))

    // when: the view is resized
    callOrder = []
    willLayoutContainerSize = nil
    willLayoutRenderType = nil
    willRenderContentSize = nil
    willRenderRenderBounds = nil
    willRenderRenderType = nil
    didRenderContentSize = nil
    didRenderRenderBounds = nil
    didRenderRenderType = nil

    view.frame.size = CGSize(width: 150, height: 150)
    view.layoutIfNeeded()

    // then: all handlers should be called with bounds change render type
    expect(callOrder) == ["willLayout", "willRender", "didRender"]

    expect(willLayoutContainerSize) == CGSize(width: 150, height: 150)
    expect(willLayoutRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 50, width: 100, height: 100), bounds: CGRect(x: 0, y: 50, width: 150, height: 150))

    // the content width (100) is now smaller than the container width (150), so content size width is adjusted
    expect(willRenderContentSize) == CGSize(width: 150, height: 200)
    expect(willRenderRenderBounds) == CGRect(x: 0, y: 50, width: 150, height: 150)
    expect(willRenderRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 50, width: 100, height: 100), bounds: CGRect(x: 0, y: 50, width: 150, height: 150))

    expect(didRenderContentSize) == CGSize(width: 150, height: 200)
    expect(didRenderRenderBounds) == CGRect(x: 0, y: 50, width: 150, height: 150)
    expect(didRenderRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 50, width: 100, height: 100), bounds: CGRect(x: 0, y: 50, width: 150, height: 150))
  }

  func test_willRenderHandler() {
    // given: a compose view with a content
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      ColorNode(.red)
        .frame(width: 100, height: 200)
    }

    // set up the will-render handler to track the callback arguments
    var eventOrder: [String] = []

    var willRenderCallCount = 0
    var willRenderContentSize: CGSize?
    var willRenderRenderBounds: CGRect?
    var willRenderRenderType: ComposeView.RenderType?

    view.onWillRender { view, context in
      eventOrder.append("willRender")

      willRenderCallCount += 1
      willRenderContentSize = context.contentSize
      willRenderRenderBounds = context.renderBounds
      willRenderRenderType = context.renderType

      // when: adjust the content offset to be at the bottom
      view.setContentOffset(CGPoint(x: 0, y: 100))
    }

    var requestedVisibleBounds: CGRect?
    view.debug { _, event in
      switch event {
      case .renderWillRequestRenderableItems(let visibleBounds):
        requestedVisibleBounds = visibleBounds
        eventOrder.append("renderItems")
      default:
        break
      }
    }

    // when: the view is refreshed initially
    view.refresh(animated: false)

    // then: the will-render handler should be called with the correct arguments
    expect(willRenderCallCount) == 1
    expect(willRenderContentSize) == CGSize(width: 100, height: 200)
    expect(willRenderRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(willRenderRenderType) == .refresh(isAnimated: false)

    // then: the content offset should be updated
    expect(view.contentOffset().y) == 100

    expect(eventOrder) == ["willRender", "renderItems"]
    expect(requestedVisibleBounds) == CGRect(x: 0, y: 100, width: 100, height: 100)

    // when: the view is scrolled
    view.setContentOffset(CGPoint(x: 0, y: 10))
    view.layoutIfNeeded()

    // then: the will-render handler should be called with the correct arguments
    expect(willRenderCallCount) == 2
    expect(willRenderContentSize) == CGSize(width: 100, height: 200)
    expect(willRenderRenderBounds) == CGRect(x: 0, y: 10, width: 100, height: 100)
    expect(willRenderRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 100, width: 100, height: 100), bounds: CGRect(x: 0, y: 10, width: 100, height: 100))
    expect(view.contentOffset().y) == 100

    expect(eventOrder) == ["willRender", "renderItems", "willRender", "renderItems"]
    expect(requestedVisibleBounds) == CGRect(x: 0, y: 100, width: 100, height: 100)

    expect(view.bounds()) == CGRect(x: 0, y: 100, width: 100, height: 100)

    // when: the view is resized
    view.frame.size = CGSize(width: 150, height: 150)
    expect(view.bounds()) == CGRect(x: 0, y: 50, width: 150, height: 150) // y: 50 (maxOffsetY) = 200 - 150

    view.layoutIfNeeded()

    // then: the will-render handler should be called with the correct arguments
    expect(willRenderCallCount) == 3
    expect(willRenderContentSize) == CGSize(width: 150, height: 200)
    expect(willRenderRenderBounds) == CGRect(x: 0, y: 50, width: 150, height: 150)
    expect(willRenderRenderType) == .boundsChange(previousBounds: CGRect(x: 0, y: 100, width: 100, height: 100), bounds: CGRect(x: 0, y: 50, width: 150, height: 150))
    #if canImport(AppKit)
    expect(view.contentOffset().y) == 50 // AppKit doesn't allow over scroll
    #endif
    #if canImport(UIKit)
    expect(view.contentOffset().y) == 100
    #endif

    expect(eventOrder) == [
      "willRender", "renderItems", "willRender", "renderItems", "willRender", "renderItems",
    ]
    #if canImport(AppKit)
    expect(requestedVisibleBounds) == CGRect(x: -25, y: 50, width: 150, height: 150) // AppKit doesn't allow over scroll
    #endif
    #if canImport(UIKit)
    expect(requestedVisibleBounds) == CGRect(x: -25, y: 100, width: 150, height: 150)
    #endif
  }

  func test_boundsChange_renderTypeMatchesEachCallbackViewport() throws {
    // given: a view whose dynamic animation policy uses the bounds supplied with the render type
    var willLayoutType: ComposeView.RenderType?
    var willRenderContext: ComposeView.WillRenderContext?
    var didRenderContext: ComposeView.DidRenderContext?
    var animationTypes: [ComposeView.RenderType] = []
    var itemContext: RenderableUpdateContext?
    var layer: CALayer?
    var adjustedOffset: CGFloat?
    let timing = AnimationTiming.linear(duration: 10)
    let view = ComposeView {
      LayerNode<CALayer>(update: { renderable, context in
        renderable.cornerRadius = context.renderBounds.minY
        layer = renderable
        itemContext = context
      })
      .frame(width: .flexible, height: 400)
      .animation(timing)
    }
    view.visibleBoundsInsets = EdgeInsets(top: -20, left: -10, bottom: -30, right: -10)
    view.onWillLayout { _, context in
      willLayoutType = context.renderType
    }
    view.onWillRender { contentView, context in
      willRenderContext = context
      if let adjustedOffset {
        contentView.setContentOffset(CGPoint(x: 0, y: adjustedOffset))
      }
    }
    view.onDidRender { _, context in
      didRenderContext = context
    }
    view.animationBehavior = .dynamic { _, renderType in
      animationTypes.append(renderType)
      switch renderType {
      case .refresh:
        return false
      case .boundsChange(_, let bounds):
        return bounds.minY == 40
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the first bounds-driven pass renders without previous history
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: all callbacks report nil previous bounds and the actual viewport, without visibility insets
    let initialBounds = CGRect(x: 0, y: 0, width: 100, height: 100)
    let initialType = ComposeView.RenderType.boundsChange(previousBounds: nil, bounds: initialBounds)
    let renderedLayer = try unwrap(layer)
    expect(willLayoutType) == initialType
    expect(willRenderContext?.renderType) == initialType
    expect(willRenderContext?.renderBounds) == initialBounds
    expect(didRenderContext?.renderType) == initialType
    expect(didRenderContext?.renderBounds) == initialBounds
    expect(animationTypes) == [initialType]
    expect(itemContext?.animationTiming) == nil
    expect(renderedLayer.cornerRadius) == 0

    // when: resizing also adjusts the offset from onWillRender
    animationTypes.removeAll()
    adjustedOffset = 40
    view.frame.size.width = 150
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: early callbacks use the proposed viewport, while animation and completion use the adjusted viewport
    let proposedBounds = CGRect(x: 0, y: 0, width: 150, height: 100)
    let finalBounds = CGRect(x: 0, y: 40, width: 150, height: 100)
    let finalType = ComposeView.RenderType.boundsChange(previousBounds: initialBounds, bounds: finalBounds)
    expect(willLayoutType) == .boundsChange(previousBounds: initialBounds, bounds: proposedBounds)
    expect(willRenderContext?.renderType) == .boundsChange(previousBounds: initialBounds, bounds: proposedBounds)
    expect(willRenderContext?.renderBounds) == proposedBounds
    expect(didRenderContext?.renderType) == finalType
    expect(didRenderContext?.renderBounds) == finalBounds
    expect(animationTypes) == [finalType]
    expect(itemContext?.animationTiming) == timing
    expect(itemContext?.renderBounds) == finalBounds
    expect(layer) === renderedLayer
    expect(renderedLayer.frame) == CGRect(x: 0, y: 0, width: 150, height: 400)
    expect(renderedLayer.cornerRadius) == 40
    let animation = try unwrap(renderedLayer.animation(forKey: "bounds.size") as? CABasicAnimation)
    expect(animation.fromValue as? CGSize) == CGSize(width: -50, height: 0)
    expect(animation.toValue as? CGSize) == .zero
    expect(animation.isAdditive) == true
    renderedLayer.removeAllAnimations()

    // when: a later scroll uses the completed adjusted viewport as history
    adjustedOffset = nil
    animationTypes.removeAll()
    view.setContentOffset(CGPoint(x: 0, y: 60))
    view.layoutIfNeeded()

    // then: scrolling uses the same public case and the dynamic policy can reject its new bounds
    let scrolledBounds = CGRect(x: 0, y: 60, width: 150, height: 100)
    let scrollType = ComposeView.RenderType.boundsChange(previousBounds: finalBounds, bounds: scrolledBounds)
    expect(willLayoutType) == scrollType
    expect(willRenderContext?.renderType) == scrollType
    expect(didRenderContext?.renderType) == scrollType
    expect(animationTypes) == [scrollType]
    expect(itemContext?.animationTiming) == nil
    expect(renderedLayer.cornerRadius) == 60
    expect(renderedLayer.animationKeys()) == nil
  }

  func test_boundsChange_keepsSnapshotsWhenAnItemChangesLiveBounds() throws {
    // given: the first renderable may change the live offset during an item update
    var changesOffset = false
    var animationTypes: [ComposeView.RenderType] = []
    var itemContexts: [RenderableUpdateContext] = []
    var layers: [CALayer] = []
    var didRenderContext: ComposeView.DidRenderContext?
    let view = ComposeView {
      ZStack {
        for index in 0 ..< 2 {
          LayerNode<CALayer>(update: { renderable, context in
            if index == 0, changesOffset {
              changesOffset = false
              context.contentView.setContentOffset(CGPoint(x: 0, y: 40))
            }
            renderable.cornerRadius = context.renderBounds.minY
            layers.append(renderable)
            itemContexts.append(context)
          })
          .frame(width: .flexible, height: 400)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    layers.removeAll()
    itemContexts.removeAll()
    view.onDidRender { _, context in
      didRenderContext = context
    }
    view.animationBehavior = .dynamic { _, renderType in
      animationTypes.append(renderType)
      return true
    }
    changesOffset = true

    // when: a size change renders and the first item moves the live viewport
    view.frame.size.width = 150
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the pass-level policy and all items keep the bounds chosen before item updates, despite the live offset change
    let initialBounds = CGRect(x: 0, y: 0, width: 100, height: 100)
    let passBounds = CGRect(x: 0, y: 0, width: 150, height: 100)
    let expectedType = ComposeView.RenderType.boundsChange(previousBounds: initialBounds, bounds: passBounds)
    expect(view.contentOffset().y) == 40
    expect(animationTypes) == [expectedType]
    expect(didRenderContext?.renderType) == expectedType
    expect(didRenderContext?.renderBounds) == passBounds
    expect(itemContexts.count) == 2
    for context in itemContexts {
      expect(context.previousRenderBounds) == initialBounds
      expect(context.renderBounds) == passBounds
    }
    for layer in layers {
      expect(layer.cornerRadius) == 0
    }

    // when: the next layout renders the changed live offset
    animationTypes.removeAll()
    itemContexts.removeAll()
    layers.removeAll()
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the next pass reports the scroll from the last completed viewport
    let scrolledBounds = CGRect(x: 0, y: 40, width: 150, height: 100)
    let scrolledType = ComposeView.RenderType.boundsChange(previousBounds: passBounds, bounds: scrolledBounds)
    expect(animationTypes) == [scrolledType]
    expect(didRenderContext?.renderType) == scrolledType
    expect(didRenderContext?.renderBounds) == scrolledBounds
    for layer in layers {
      expect(layer.cornerRadius) == 40
    }
  }

  func test_boundsChange_reportsCompletedZeroBoundsInsteadOfMissingHistory() throws {
    // given: a host completes a render at zero size before any renderable is visible
    var layer: CALayer?
    var renderType: ComposeView.RenderType?
    let view = ComposeView {
      LayerNode<CALayer>(update: { renderable, _ in
        renderable.backgroundColor = Color.red.cgColor
        layer = renderable
      })
    }
    view.refresh(animated: false)
    view.onDidRender { _, context in
      renderType = context.renderType
    }

    // when: a size change makes the first renderable visible
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: history is a real zero viewport, not nil merely because the renderable is being inserted
    let renderedLayer = try unwrap(layer)
    expect(renderType) == .boundsChange(previousBounds: .zero, bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
    expect(renderedLayer.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(renderedLayer.backgroundColor) == Color.red.cgColor
  }

  func test_willRenderHandler_boundsSizeChanged() {
    // test that the will-render handler is called with bounds size changed
    // should expect a follow-up layout to be scheduled

    // given: a compose view with a content
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      ColorNode(.red)
        .frame(width: 100, height: 200)
    }

    // set up the will-render handler that changes the bounds size
    view.onWillRender { view, _ in
      view.setBounds(CGRect(x: 0, y: 10, width: 150, height: 150))
    }

    // when: the view is refreshed
    view.refresh(animated: false)

    // then: the old bounds should be used for the immediate render
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 10, width: 100, height: 100)

    // then: the follow-up render should use the new bounds eventually
    expect(view.test.lastRenderBounds).toEventually(
      beEqual(to: CGRect(x: 0, y: 10, width: 150, height: 150))
    )
  }

  func test_didRenderHandler_boundsChanged() throws {
    // given: a rendered view whose dynamic behavior always animates, with a did-render handler that resizes and scrolls
    // the view and lays it out once
    let timing = AnimationTiming.linear(duration: 10)
    var layer: CALayer?
    var layerContexts: [RenderableUpdateContext] = []
    var renderTypes: [ComposeView.RenderType] = []
    var changesBounds = false
    let view = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: 200)
        .animation(timing)
        .onUpdate { renderable, context in
          layer = renderable.layer
          layerContexts.append(context)
        }
    }
    view.renderablePool = nil
    view.animationBehavior = .dynamic { _, _ in true }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let row = try unwrap(layer)
    view.onDidRender { view, context in
      renderTypes.append(context.renderType)
      guard changesBounds else {
        return
      }
      changesBounds = false
      view.setBounds(CGRect(x: 0, y: 10, width: 160, height: 100))
      view.setNeedsLayout()
      view.layoutIfNeeded()
    }
    changesBounds = true
    layerContexts.removeAll()

    // when: the view refreshes and its handler changes the bounds from inside the pass
    view.refresh(animated: false)

    // then: the pass completes with the bounds it started with, and the layout during the pass has nothing to do
    expect(renderTypes) == [.refresh(isAnimated: false)]
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 100, height: 200)
    layerContexts.removeAll()
    row.removeAllAnimations()

    // when: the run loop performs the follow-up layout. the row's animations are read in the same run loop iteration,
    // since a layer outside a window keeps none past the transaction commit.
    var rowAnimationKeys: [String]?
    var isDrained = false
    RunLoop.main.perform {
      rowAnimationKeys = row.animationKeys()
      isDrained = true
    }
    expect(isDrained).toEventually(beTrue())

    // then: the new bounds render as a bounds change under the view's own animation behavior
    expect(renderTypes) == [
      .refresh(isAnimated: false),
      .boundsChange(previousBounds: CGRect(x: 0, y: 0, width: 100, height: 100), bounds: CGRect(x: 0, y: 10, width: 160, height: 100)),
    ]
    expect(view.test.lastRenderBounds) == CGRect(x: 0, y: 10, width: 160, height: 100)
    expect(row.frame) == CGRect(x: 0, y: 0, width: 160, height: 200)
    expect(rowAnimationKeys?.contains("bounds.size")) == true
    expect(layerContexts.count) == 1
    expect(layerContexts.first?.animationTiming) == timing
    expect(layerContexts.first?.animationDecision) == ComposeView.AnimationDecision.all
  }
}
