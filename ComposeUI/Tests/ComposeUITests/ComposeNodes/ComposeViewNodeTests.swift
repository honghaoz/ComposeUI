//
//  ComposeViewNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/12/25.
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

class ComposeViewNodeTests: XCTestCase {

  func test_init() throws {
    // then: compose view nodes can be created with various contents
    _ = ComposeViewNode {
      Empty()
    }

    _ = ComposeViewNode {
      ColorNode(.red)
    }

    _ = ComposeViewNode {
      VStack {
        ColorNode(.red)
        ColorNode(.blue)
      }
    }
  }

  func test_id() throws {
    // given: a compose view node
    let node = ComposeViewNode {
      Empty()
    }

    // then: the id is "CV"
    expect(node.id.id) == "CV"
  }

  func test_size() throws {
    // given: fixed size content + fixed size
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
          .frame(width: 50, height: 50)
      }

      // before layout, size should be zero
      expect(node.size) == .zero

      // when: laying out in a 100x100 container
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: after layout, the size is the fixed content size
      expect(node.size) == CGSize(width: 50, height: 50)
    }

    // given: fixed size content + fixed width, flexible height
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
          .frame(width: 50, height: 50)
      }
      .fixedSize(width: true, height: false)

      expect(node.size) == .zero

      // when: laying out in a 100x100 container
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the width is fixed and the height fills the container
      expect(node.size) == CGSize(width: 50, height: 100)
    }

    // given: fixed size content + flexible width, fixed height
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
          .frame(width: 50, height: 50)
      }
      .fixedSize(width: false, height: true)

      expect(node.size) == .zero

      // when: laying out in a 100x100 container
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the width fills the container and the height is fixed
      expect(node.size) == CGSize(width: 100, height: 50)
    }

    // given: fixed size content + flexible size
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
          .frame(width: 50, height: 50)
      }
      .fixedSize(width: false, height: false)

      expect(node.size) == .zero

      // when: laying out in a 100x100 container
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the size fills the container
      expect(node.size) == CGSize(width: 100, height: 100)
    }

    // given: flexible size content + flexible size
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
      }

      expect(node.size) == .zero

      // when: laying out in a 100x100 container
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the size fills the container
      expect(node.size) == CGSize(width: 100, height: 100)
    }

    // given: flexible size content + fixed width, flexible height
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
      }
      .fixedSize(width: true, height: false)

      expect(node.size) == .zero

      // when: laying out in a 100x100 container
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the size fills the container
      expect(node.size) == CGSize(width: 100, height: 100)
    }

    // given: flexible size content + flexible width, fixed height
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
      }
      .fixedSize(width: false, height: true)

      expect(node.size) == .zero

      // when: laying out in a 100x100 container
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the size fills the container
      expect(node.size) == CGSize(width: 100, height: 100)
    }

    // given: flexible size content + flexible size
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
      }
      .fixedSize(width: false, height: false)

      expect(node.size) == .zero

      // when: laying out in a 100x100 container
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the size fills the container
      expect(node.size) == CGSize(width: 100, height: 100)
    }
  }

  func test_layout() throws {
    // given: a layout context
    let context = ComposeNodeLayoutContext(scaleFactor: 1)

    // given: a node with fixed size content
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
          .frame(width: 50, height: 50)
      }

      // when: laying out in a 100x100 container
      let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the sizing and size are fixed to the content size
      expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .fixed(50))
      expect(node.size) == CGSize(width: 50, height: 50)
    }

    // given: a node with flexible size content
    do {
      var node = ComposeViewNode {
        ColorNode(.red)
      }

      // when: laying out in a 100x100 container
      let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the node is flexible and fills the container
      expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
      expect(node.size) == CGSize(width: 100, height: 100)
    }

    // given: a node with VStack content
    do {
      var node = ComposeViewNode {
        VStack {
          ColorNode(.red)
            .frame(width: 50, height: 30)
          ColorNode(.blue)
            .frame(width: 70, height: 20)
        }
      }

      // when: laying out in a 100x100 container
      let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the sizing and size fit the stack content
      expect(sizing) == ComposeNodeSizing(width: .fixed(70), height: .fixed(50))
      expect(node.size) == CGSize(width: 70, height: 50)
    }
  }

  func test_renderableItems() throws {
    // given: a laid out compose view node with fixed size content
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ComposeViewNode {
      ColorNode(.red)
        .frame(width: 50, height: 50)
    }
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when: visible bounds intersects with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)

      // then: a single compose view item is provided with the expected id, frame, and behaviors
      expect(items.count) == 1

      let item = items[0]
      expect(item.id.id) == "CV"
      expect(item.frame) == CGRect(x: 0, y: 0, width: 50, height: 50)

      // make
      do {
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 50, height: 50), contentView: nil))
        expect(renderable.view is ComposeView) == true
        expect(renderable.frame) == CGRect(x: 1, y: 2, width: 50, height: 50)
      }
      do {
        let renderable = item.make(RenderableMakeContext(initialFrame: nil, contentView: nil))
        expect(renderable.view is ComposeView) == true
        expect(renderable.frame) == .zero
      }

      expect(item.willInsert) == nil

      // given: a nested view that has not rendered its content
      do {
        let composeView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
        let renderable = Renderable.view(composeView)
        let layer = composeView.contentView().layer()

        // when: the view is inserted
        item.update(renderable, RenderableUpdateContext(updateType: .insert, oldFrame: .zero, newFrame: composeView.frame, animationTiming: nil, contentView: nil))

        // then: content installation renders immediately at the view's own bounds
        expect(layer.sublayers?.count) == 1
        let sublayer = try (layer.sublayers?.first).unwrap()
        expect(sublayer.backgroundColor) == Color.red.cgColor
        expect(sublayer.frame) == CGRect(x: 25.0, y: 75.0, width: 50, height: 50)
      }

      expect(item.didInsert) == nil
      expect(item.willUpdate) == nil
      expect(item.update) != nil
      expect(item.willRemove) == nil
      expect(item.didRemove) == nil
      expect(item.transition) == nil
      expect(item.animationTiming) == nil
    }

    // when: visible bounds does not intersect with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 50, width: 100, height: 100)
      let items = node.renderableItems(in: visibleBounds)

      // then: no items are provided
      expect(items.count) == 0
    }
  }

  func test_update_skipsGeometryChanges() throws {
    // given: a nested view rendering red content and a new blue configuration
    var node = ComposeViewNode {
      ColorNode(.blue)
    }
    let frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    _ = node.layout(containerSize: frame.size, context: ComposeNodeLayoutContext(scaleFactor: 1))
    let item = try node.renderableItems(in: frame).first.unwrap()
    let nestedView = ComposeView {
      ColorNode(.red)
    }
    nestedView.frame = frame
    nestedView.refresh(animated: false)
    let layer = try (nestedView.contentView().layer().sublayers?.first).unwrap()
    let renderable = Renderable.view(nestedView)

    for updateType in [RenderableUpdateType.scroll, .boundsChange] {
      // when: updating geometry without refreshing content
      item.update(renderable, RenderableUpdateContext(updateType: updateType, oldFrame: frame, newFrame: frame, animationTiming: nil, contentView: nil))
      nestedView.setNeedsLayout()
      nestedView.layoutIfNeeded()

      // then: the existing nested content is not replaced
      expect(layer.backgroundColor) == Color.red.cgColor
    }

    // when: explicitly refreshing the nested configuration
    item.update(renderable, RenderableUpdateContext(updateType: .refresh, oldFrame: frame, newFrame: frame, animationTiming: nil, contentView: nil))

    // then: the new color is applied immediately without replacing the layer
    expect(layer.backgroundColor) == Color.blue.cgColor
    expect(nestedView.contentView().layer().sublayers?.first) === layer
  }

  func test_refresh_updatesMountedContentWithUnchangedSize() throws {
    for animated in [false, true] {
      // given: nested color and text content with stable ids and fixed sizes
      var color = Color.red
      var text = "Before"
      var font = Font.systemFont(ofSize: 12)
      var selectable = false
      var nestedView: ComposeView?
      var colorLayer: CALayer?
      var textView: BaseTextView?
      let contentView = ComposeView {
        ComposeViewNode {
          VStack {
            ColorNode(color)
              .frame(width: 80, height: 20)
              .onUpdate { item, _ in
                colorLayer = item.layer
              }
            TextNode(NSAttributedString(string: text, attributes: [.font: font]))
              .selectable(selectable)
              .frame(width: 80, height: 30)
              .onUpdate { item, _ in
                textView = item.view as? BaseTextView
              }
          }
        }
        .onUpdate { item, _ in
          nestedView = item.view as? ComposeView
        }
      }
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      contentView.refresh(animated: false)
      let child = try nestedView.unwrap()
      let originalLayer = try colorLayer.unwrap()
      let originalTextView = try textView.unwrap()
      let originalFrame = child.frame
      let originalTextFrame = originalTextView.frame
      var childRenderType: ComposeView.RenderType?
      child.onDidRender { _, context in
        childRenderType = context.renderType
      }
      expect(originalTextView.attributedString.string) == "Before"
      expect(originalLayer.backgroundColor) == Color.red.cgColor
      expect(originalTextView.isSelectable) == false

      // when: the parent refreshes new configuration without changing ids or sizes
      color = .blue
      text = "After"
      font = .systemFont(ofSize: 18)
      selectable = true
      contentView.refresh(animated: animated)

      // then: the child keeps its native views and applies the configuration in the parent's pass with its animation
      expect(nestedView) === child
      expect(colorLayer) === originalLayer
      expect(textView) === originalTextView
      expect(child.frame) == originalFrame
      expect(originalTextView.frame) == originalTextFrame
      expect(originalLayer.backgroundColor) == Color.blue.cgColor
      expect(originalTextView.attributedString.string) == "After"
      expect(originalTextView.attributedString.attribute(.font, at: 0, effectiveRange: nil) as? Font) == font
      expect(originalTextView.isSelectable) == true
      expect(childRenderType) == .refresh(isAnimated: animated)
      #if canImport(AppKit)
      expect(originalTextView.string) == "After"
      #endif
      #if canImport(UIKit)
      expect(originalTextView.attributedText.string) == "After"
      #endif
    }
  }

  func test_refresh_updatesNestedContentAtEveryDepthInTheSamePass() throws {
    for nestingDepth in 1 ... 3 {
      // given: text nested under the given number of compose view nodes
      var text = "Before"
      var textView: BaseTextView?
      let contentView = ComposeView {
        var content: any ComposeNode = ComposeViewNode {
          LabelNode(text)
            .font(.systemFont(ofSize: 12))
            .frame(width: 80, height: 30)
            .onUpdate { item, _ in
              textView = item.view as? BaseTextView
            }
        }
        for _ in 1 ..< nestingDepth {
          let childContent = content
          content = ComposeViewNode { childContent }
        }
        return content
      }
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      contentView.refresh(animated: false)
      let originalTextView = try textView.unwrap()
      expect(originalTextView.attributedString.string) == "Before"

      // when: the parent refreshes with changed data
      text = "After"
      contentView.refresh(animated: false)

      // then: the deepest content shows the new data before the refresh call returns
      expect(textView) === originalTextView
      expect(originalTextView.attributedString.string) == "After"
    }
  }

  func test_insert_childFirstRenderFollowsParentAnimation() throws {
    for animated in [false, true] {
      // given: a parent whose nested view is observed before its first render
      var childRenderType: ComposeView.RenderType?
      var colorLayer: CALayer?
      let contentView = ComposeView {
        ComposeViewNode {
          ColorNode(.red)
            .frame(width: 80, height: 20)
            .onUpdate { item, _ in
              colorLayer = item.layer
            }
        }
        .willInsert { renderable, _ in
          (renderable.view as? ComposeView)?.onDidRender { _, context in
            childRenderType = context.renderType
          }
        }
      }
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

      // when: the parent's refresh inserts the nested view
      contentView.refresh(animated: animated)

      // then: the nested view renders its content within the parent's pass with the parent's animation decision
      expect(childRenderType) == .refresh(isAnimated: animated)
      expect(colorLayer?.backgroundColor) == Color.red.cgColor
      expect(colorLayer?.frame.size) == CGSize(width: 80, height: 20)
    }
  }

  func test_willInsert_configuresNestedViewBeforeItsFirstRender() throws {
    for disablesAnimations in [false, true] {
      // given: nested content with an insert transition, optionally disabling animations on the nested view up front
      var colorLayer: CALayer?
      let contentView = ComposeView {
        ComposeViewNode {
          ColorNode(.red)
            .frame(width: 80, height: 20)
            .transition(.opacity(timing: .linear(duration: 1)))
            .onUpdate { item, _ in
              colorLayer = item.layer
            }
        }
        .willInsert { renderable, _ in
          if disablesAnimations {
            (renderable.view as? ComposeView)?.animationBehavior = .disabled
          }
        }
      }
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

      // when: the parent's animated refresh inserts the nested view
      contentView.refresh(animated: true)

      // then: the nested view's own animation behavior, set before its first render, decides the insert transition
      let layer = try unwrap(colorLayer)
      expect(layer.backgroundColor) == Color.red.cgColor
      if disablesAnimations {
        expect(layer.animationKeys() ?? []) == []
      } else {
        expect(layer.animationKeys()?.contains("opacity")) == true
      }
    }
  }

  func test_parentRefresh_fromNestedRenderCallback_isDeferredUntilThePassCompletes() throws {
    // given: a nested view whose first render refreshes the parent synchronously, and a handler capturing assertions
    var color = Color.red
    var nestedViews: [ComposeView] = []
    var colorLayer: CALayer?
    var parentRefreshesFromChild = 0
    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }
    var contentView: ComposeView?
    contentView = ComposeView {
      ComposeViewNode {
        ColorNode(color)
          .frame(width: 80, height: 20)
          .onUpdate { item, _ in
            colorLayer = item.layer
          }
      }
      .willInsert { renderable, _ in
        guard let nestedView = renderable.view as? ComposeView else {
          return
        }
        nestedViews.append(nestedView)
        nestedView.onDidRender { _, _ in
          guard parentRefreshesFromChild == 0 else {
            return
          }
          parentRefreshesFromChild += 1
          color = .blue
          contentView?.refresh(animated: false)
        }
      }
    }
    let parent = try unwrap(contentView)
    parent.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the parent refreshes
    parent.refresh(animated: false)

    // then: the pass completes with its own content, one nested view, and no assertion
    expect(assertionMessages) == []
    expect(nestedViews.count) == 1
    expect(parent.contentView().subviews.filter { $0 is ComposeView }.count) == 1
    expect(colorLayer?.backgroundColor) == Color.red.cgColor
    expect(parentRefreshesFromChild) == 1

    // when: the run loop performs the deferred refresh
    var isDrained = false
    RunLoop.main.perform { isDrained = true }
    expect(isDrained).toEventually(beTrue())

    // then: the nested view shows the new configuration and is still the only nested view
    expect(assertionMessages) == []
    expect(nestedViews.count) == 1
    expect(parent.contentView().subviews.filter { $0 is ComposeView }.count) == 1
    expect(colorLayer?.backgroundColor) == Color.blue.cgColor
  }

  func test_scrollInsert_childFirstRenderFollowsScrollAnimation() throws {
    // given: a nested view laid out below the parent's visible bounds
    var childRenderType: ComposeView.RenderType?
    var colorLayer: CALayer?
    let contentView = ComposeView {
      VStack {
        Spacer(height: 150)
        ComposeViewNode {
          ColorNode(.red)
            .frame(width: 80, height: 20)
            .onUpdate { item, _ in
              colorLayer = item.layer
            }
        }
        .willInsert { renderable, _ in
          (renderable.view as? ComposeView)?.onDidRender { _, context in
            childRenderType = context.renderType
          }
        }
        Spacer(height: 150)
      }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    contentView.refresh(animated: false)
    expect(childRenderType) == nil

    // when: scrolling inserts the nested view
    contentView.setContentOffset(CGPoint(x: 0, y: 125))
    contentView.layoutIfNeeded()

    // then: the nested view's first render follows the scroll pass, which animates by default
    expect(childRenderType) == .refresh(isAnimated: true)
    expect(colorLayer?.backgroundColor) == Color.red.cgColor
  }

  func test_boundsChange_reflowsRetainedContentAfterMeasurement() throws {
    // given: multiline nested content
    let originalText = "Nested content wraps onto several lines when the available width becomes narrow."
    let font = Font.systemFont(ofSize: 14)
    var text = originalText
    var nestedView: ComposeView?
    var textView: BaseTextView?
    let contentView = ComposeView {
      ComposeViewNode {
        LabelNode(text)
          .font(font)
          .numberOfLines(0)
          .onUpdate { item, _ in
            textView = item.view as? BaseTextView
          }
      }
      .onUpdate { item, _ in
        nestedView = item.view as? ComposeView
      }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 240, height: 300)
    contentView.refresh(animated: false)
    expect(textView?.attributedString.string) == originalText
    let child = try nestedView.unwrap()
    let labelView = try textView.unwrap()
    let wideHeight = labelView.frame.height
    text = "Fresh"

    for width: CGFloat in [80, 240, 120, 240] {
      // when: fresh measurement uses different content and a different width before a resize
      let proposal = CGSize(width: width / 2, height: 300)
      var freshLabel = LabelNode(text).font(font).numberOfLines(0)
      let context = ComposeNodeLayoutContext(scaleFactor: contentView.contentScaleFactor)
      _ = freshLabel.layout(containerSize: proposal, context: context)
      let measuredSize = contentView.sizeThatFits(proposal)
      contentView.frame.size.width = width
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()
      child.setNeedsLayout()
      child.layoutIfNeeded()

      // then: measurement is fresh while the mounted label reflows its retained text
      expect(measuredSize) == freshLabel.size
      var retainedLabel = LabelNode(originalText).font(font).numberOfLines(0)
      _ = retainedLabel.layout(containerSize: CGSize(width: width, height: 300), context: context)
      expect(nestedView) === child
      expect(textView) === labelView
      expect(child.frame.size) == retainedLabel.size
      expect(labelView.frame.size) == retainedLabel.size
      expect(labelView.attributedString.string) == originalText
      expect(labelView.attributedString.attribute(.font, at: 0, effectiveRange: nil) as? Font) == font
      if width == 80 {
        expect(labelView.frame.height) > wideHeight
      }
    }
  }

  func test_boundsChange_doesNotLeakParentMeasurementIntoNestedContent() throws {
    for nestingDepth in 1 ... 3 {
      // given: nested content whose intrinsic height exceeds every ancestor's initial proposal
      var nestedView: ComposeView?
      var colorLayer: CALayer?
      var colorUpdateType: RenderableUpdateType?
      let contentView = ComposeView {
        var content: any ComposeNode = ComposeViewNode {
          ZStack {
            ColorNode(.red)
              .onUpdate { renderable, context in
                colorLayer = renderable.layer
                colorUpdateType = context.updateType
              }
            Spacer(height: 300)
            ViewNode<BaseView>()
              .frame(width: 1, height: 1)
          }
        }
        .onUpdate { renderable, _ in
          nestedView = renderable.view as? ComposeView
        }
        for _ in 1 ..< nestingDepth {
          let childContent = content
          content = ComposeViewNode { childContent }
        }
        return content
      }
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      contentView.refresh(animated: false)
      let child = try unwrap(nestedView)
      child.scrollBehavior = .always
      child.setContentInsets(EdgeInsets(top: 0, left: 0, bottom: 50, right: 0))
      child.setNeedsLayout()
      child.layoutIfNeeded()
      let layer = try unwrap(colorLayer)
      expect(child.bounds().size) == CGSize(width: 100, height: 300)
      expect(layer.frame) == CGRect(x: 0, y: 0, width: 100, height: 300)

      // when: the parent resizes, measuring its own copy of the content at the new size, while the nested view keeps
      // its intrinsic size
      contentView.frame.size.height = 200
      contentView.setNeedsLayout()
      contentView.layoutIfNeeded()
      child.setNeedsLayout()
      child.layoutIfNeeded()

      // then: the nested view keeps its original bounds
      expect(nestedView) === child
      expect(child.bounds().size) == CGSize(width: 100, height: 300)

      // when: scrolling causes the nested view to render from its cached layout
      colorUpdateType = nil
      child.setContentOffset(CGPoint(x: 0, y: 10))
      child.setNeedsLayout()
      child.layoutIfNeeded()

      // then: the retained content keeps the nested view's geometry, not the parent's measurement geometry
      expect(colorUpdateType) == .scroll
      expect(child.contentOffset().y) == 10
      expect(colorLayer) === layer
      expect(layer.frame) == CGRect(x: 0, y: 0, width: 100, height: 300)
      expect(layer.backgroundColor) == Color.red.cgColor
    }
  }

  func test_delayedInsertionAndReinsertion_useRetainedContent() throws {
    // given: nested content laid out offscreen before application data changes
    var color = Color.red
    var text = "Retained"
    var nestedView: ComposeView?
    var colorLayer: CALayer?
    var textView: BaseTextView?
    let contentView = ComposeView {
      VStack {
        Spacer(height: 150)
        ComposeViewNode {
          VStack {
            ColorNode(color)
              .frame(width: 80, height: 20)
              .onUpdate { item, _ in
                colorLayer = item.layer
              }
            LabelNode(text)
              .font(.systemFont(ofSize: 12))
              .frame(width: 80, height: 30)
              .onUpdate { item, _ in
                textView = item.view as? BaseTextView
              }
          }
        }
        .onUpdate { item, _ in nestedView = item.view as? ComposeView }
        Spacer(height: 150)
      }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    contentView.refresh(animated: false)
    expect(nestedView) == nil
    color = .blue
    text = "Changed"

    // when: the parent resizes before scrolling the nested view onscreen
    contentView.frame.size.width = 160
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()
    contentView.setContentOffset(CGPoint(x: 0, y: 125))
    contentView.layoutIfNeeded()

    // then: delayed insertion renders the retained configuration within the scroll pass
    expect(textView?.attributedString.string) == "Retained"
    let firstChild = try nestedView.unwrap()
    expect(firstChild.frame.size) == CGSize(width: 80, height: 50)
    expect(colorLayer?.backgroundColor) == Color.red.cgColor

    // when: scrolling the nested view offscreen removes it
    contentView.setContentOffset(.zero)
    contentView.layoutIfNeeded()

    // then: the first nested view is detached
    expect(firstChild.superview) == nil

    // when: the retained node is inserted again
    nestedView = nil
    textView = nil
    colorLayer = nil
    contentView.setContentOffset(CGPoint(x: 0, y: 125))
    contentView.layoutIfNeeded()

    // then: reinsertion initializes the nested content without reevaluating application data
    expect(textView?.attributedString.string) == "Retained"
    expect(nestedView?.superview) != nil
    expect(nestedView?.frame.size) == CGSize(width: 80, height: 50)
    expect(colorLayer?.backgroundColor) == Color.red.cgColor
  }

  func test_layoutCalledBeforeRenderableItems() {
    // given: a compose view node and a test assertion failure handler
    let node = ComposeViewNode {
      ColorNode(.red)
    }

    var assertionCount = 0
    Assert.setTestAssertionFailureHandler { message, file, line, column in
      expect(message) == "renderableItems(in:) is called before layout(containerSize:context:)."
      assertionCount += 1
    }

    // when: calling renderableItems without calling layout first
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))

    // then: the assertion is triggered and no items are provided
    expect(items.count) == 0
    expect(assertionCount) == 1

    // Clean up assertion handler
    Assert.resetTestAssertionFailureHandler()
  }
}
