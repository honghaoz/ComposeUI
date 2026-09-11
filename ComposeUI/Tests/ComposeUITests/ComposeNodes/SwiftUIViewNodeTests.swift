//
//  SwiftUIViewNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/6/25.
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
import SwiftUI

class SwiftUIViewNodeTests: XCTestCase {

  func test() {
    // given: static and dynamic SwiftUI view nodes in a compose view
    var view1: SwiftUIHostingView<AnyView>?
    var view2: MutableSwiftUIHostingView?
    let contentView = ComposeView {
      // static
      SwiftUIViewNode(
        id: "text",
        Text("Hello, World!")
      )
      .onInsert { renderable, _ in
        view1 = renderable.view as? SwiftUIHostingView<AnyView>
      }

      // dynamic
      SwiftUIViewNode {
        Text("Hello, World!")
      }
      .onInsert { renderable, _ in
        view2 = renderable.view as? MutableSwiftUIHostingView
      }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

    // when: the view is refreshed
    contentView.refresh()

    // then: both hosting views are sized and interactive
    expect(view1?.bounds.size) == CGSize(width: 100, height: 25)
    expect(view1?.isUserInteractionEnabled) == true
    expect(view2?.bounds.size) == CGSize(width: 100, height: 25)
    expect(view2?.isUserInteractionEnabled) == true
  }

  func test_conditional_update() throws {
    // given: a laid out node with fixed size SwiftUI content
    let containerSize = CGSize(width: 100, height: 100)
    var node = SwiftUIViewNode {
      SwiftUI.Color.red.frame(width: 80, height: 50)
    }
    _ = node.layout(containerSize: containerSize, context: ComposeNodeLayoutContext(scaleFactor: 1))
    let item = try node.renderableItems(in: CGRect(origin: .zero, size: containerSize)).first.unwrap()
    let contentView = ComposeView()

    // when: making hosts with and without an initial frame
    let initialFrame = CGRect(x: 1, y: 2, width: 3, height: 4)
    let renderable = item.make(RenderableMakeContext(initialFrame: initialFrame, contentView: contentView))
    let view = try (renderable.view as? MutableSwiftUIHostingView).unwrap()
    let unframedRenderable = item.make(RenderableMakeContext(initialFrame: nil, contentView: contentView))
    let offscreenItems = node.renderableItems(in: CGRect(x: 0, y: 200, width: 100, height: 100))

    // then: the hosts use the supplied frames and start with empty content
    expect(item.id.id) == "SUI"
    expect(item.frame) == CGRect(origin: .zero, size: containerSize)
    expect(view.frame) == initialFrame
    expect(unframedRenderable.frame) == .zero
    expect(view.content.sizeThatFits(containerSize)) == EmptyView().sizeThatFits(containerSize)
    expect(offscreenItems.isEmpty) == true

    for updateType in [RenderableUpdateType.insert, .refresh] {
      // given: a host with different content
      view.content = AnyView(SwiftUI.Color.blue.frame(width: 30, height: 20))

      // when: applying a configuration update
      let context = RenderableUpdateContext(updateType: updateType, oldFrame: .zero, newFrame: item.frame, animationTiming: nil, contentView: contentView)
      item.update(renderable, context)

      // then: the supplied content replaces the host's previous content
      expect(view.content.sizeThatFits(containerSize)) == CGSize(width: 80, height: 50)
    }

    for updateType in [RenderableUpdateType.boundsChange, .scroll] {
      // given: a host with different content
      view.content = AnyView(SwiftUI.Color.blue.frame(width: 30, height: 20))

      // when: applying a geometry-only update directly
      let context = RenderableUpdateContext(updateType: updateType, oldFrame: .zero, newFrame: item.frame, animationTiming: nil, contentView: contentView)
      item.update(renderable, context)

      // then: geometry-only updates retain the host's current content
      expect(view.content.sizeThatFits(containerSize)) == CGSize(width: 30, height: 20)
    }
  }

  func test_dynamic_update_rejectsNonMutableHost() throws {
    // given: a dynamic node and a non-mutable host
    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    var node = SwiftUIViewNode {
      SwiftUI.Color.blue
    }
    _ = node.layout(containerSize: frame.size, context: ComposeNodeLayoutContext(scaleFactor: 1))
    let item = try node.renderableItems(in: frame).first.unwrap()
    let view = BaseView(frame: frame)
    view.layer().backgroundColor = ComposeUI.Color.red.cgColor
    var messages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      messages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: applying the configuration to an incompatible host
    let context = RenderableUpdateContext(updateType: .refresh, oldFrame: frame, newFrame: frame, animationTiming: nil, contentView: nil)
    item.update(.view(view), context)

    // then: the invalid host is reported without changing its appearance
    expect(messages) == ["view should be a MutableSwiftUIHostingView"]
    expect(view.layer().backgroundColor) == ComposeUI.Color.red.cgColor
  }

  func test_dynamic_preconstructedNode_retainsContentUntilRefresh() throws {
    // given: a preconstructed node whose content has a captured intrinsic width
    var width: CGFloat = 80
    var providerCalls = 0
    let node = SwiftUIViewNode {
      providerCalls += 1
      return SwiftUI.Color.red.frame(width: width, height: 50)
    }
    .fixedSize(width: true, height: false)
    var renderedView: MutableSwiftUIHostingView?
    let contentView = ComposeView {
      node.onUpdate { renderable, _ in
        renderedView = renderable.view as? MutableSwiftUIHostingView
      }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: mounting the node
    contentView.refresh(animated: false)
    let view = try renderedView.unwrap()

    // then: measurement and rendering share the first resolved content
    expect(view.bounds.size) == CGSize(width: 80, height: 100)
    expect(view.content.sizeThatFits(contentView.bounds.size)) == CGSize(width: 80, height: 50)
    expect(providerCalls) == 1

    // when: external content changes and the container resizes
    width = 140
    contentView.frame.size = CGSize(width: 200, height: 150)
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: geometry changes without replacing the supplied content
    expect(renderedView) === view
    expect(view.bounds.size) == CGSize(width: 80, height: 150)
    expect(view.content.sizeThatFits(contentView.bounds.size)) == CGSize(width: 80, height: 50)
    expect(providerCalls) == 1

    // when: refreshing with the same preconstructed node
    contentView.refresh(animated: false)

    // then: refresh reevaluates the provider before measuring and updating the same host
    expect(renderedView) === view
    expect(view.bounds.size) == CGSize(width: 140, height: 150)
    expect(view.content.sizeThatFits(contentView.bounds.size)) == CGSize(width: 140, height: 50)
    expect(providerCalls) == 2
  }

  func test_dynamic_flexibleContent_isLazyUntilInsertionAndRefresh() throws {
    // given: a preconstructed flexible node whose provider reads changing data
    var suppliedWidth: CGFloat = 80
    var providerCalls = 0
    let node = SwiftUIViewNode {
      providerCalls += 1
      return SwiftUI.Color.red.frame(width: suppliedWidth, height: 50)
    }
    var renderedView: MutableSwiftUIHostingView?
    let contentView = ComposeView {
      VStack {
        Spacer(height: 150)
        node.frame(width: .flexible, height: 100)
          .onInsert { renderable, _ in
            renderedView = renderable.view as? MutableSwiftUIHostingView
          }
        Spacer(height: 150)
      }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // then: constructing the node does not evaluate the provider
    expect(providerCalls) == 0

    // when: offscreen layout and fresh measurement need no intrinsic content size
    contentView.refresh(animated: false)
    let measuredSize = contentView.sizeThatFits(CGSize(width: 120, height: 100))

    // then: no SwiftUI content is constructed for the offscreen node
    expect(providerCalls) == 0
    expect(renderedView) == nil
    expect(measuredSize) == CGSize(width: 120, height: 400)

    // when: the node first becomes visible after external data changes
    suppliedWidth = 90
    contentView.setContentOffset(CGPoint(x: 0, y: 150))
    contentView.layoutIfNeeded()

    // then: insertion evaluates the current provider exactly once
    let view = try renderedView.unwrap()
    expect(view.content.sizeThatFits(view.bounds.size)) == CGSize(width: 90, height: 50)
    expect(providerCalls) == 1

    // when: data changes and geometry updates retain the node
    suppliedWidth = 110
    contentView.frame.size.width = 160
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()
    contentView.setContentOffset(CGPoint(x: 0, y: 160))
    contentView.layoutIfNeeded()

    // then: resizing and scrolling keep the resolved value
    expect(view.bounds.size) == CGSize(width: 160, height: 100)
    expect(view.content.sizeThatFits(view.bounds.size)) == CGSize(width: 90, height: 50)
    expect(providerCalls) == 1

    // when: the same node is removed and inserted again before a refresh
    contentView.setContentOffset(.zero)
    contentView.layoutIfNeeded()
    expect(view.superview) == nil
    renderedView = nil
    contentView.setContentOffset(CGPoint(x: 0, y: 150))
    contentView.layoutIfNeeded()

    // then: the new host receives the existing resolved content
    let reinsertedView = try renderedView.unwrap()
    expect(reinsertedView.content.sizeThatFits(reinsertedView.bounds.size)) == CGSize(width: 90, height: 50)
    expect(providerCalls) == 1

    // when: the visible node is explicitly refreshed without changing its frame
    contentView.refresh(animated: false)

    // then: the provider is reevaluated for the new refresh
    expect(reinsertedView.content.sizeThatFits(reinsertedView.bounds.size)) == CGSize(width: 110, height: 50)
    expect(providerCalls) == 2
  }

  func test_dynamic_rebuiltNode_refreshUpdatesMeasuredAndHostedContent() throws {
    // given: a builder that constructs a node from the current content size
    var suppliedSize = CGSize(width: 80, height: 50)
    var providerCalls = 0
    var renderedView: MutableSwiftUIHostingView?
    let contentView = ComposeView {
      SwiftUIViewNode {
        providerCalls += 1
        return SwiftUI.Color.red.frame(width: suppliedSize.width, height: suppliedSize.height)
      }
      .fixedSize()
      .onUpdate { renderable, _ in
        renderedView = renderable.view as? MutableSwiftUIHostingView
      }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
    contentView.refresh(animated: false)
    let view = try renderedView.unwrap()

    // when: external content changes and the container resizes
    suppliedSize = CGSize(width: 140, height: 70)
    contentView.frame.size = CGSize(width: 250, height: 250)
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: resizing retains both the measured and hosted content
    expect(renderedView) === view
    expect(view.bounds.size) == CGSize(width: 80, height: 50)
    expect(view.content.sizeThatFits(contentView.bounds.size)) == CGSize(width: 80, height: 50)
    expect(providerCalls) == 1

    // when: refreshing constructs a new node
    contentView.refresh(animated: false)

    // then: the retained host and its layout receive the new supplied value
    expect(renderedView) === view
    expect(view.bounds.size) == suppliedSize
    expect(view.content.sizeThatFits(contentView.bounds.size)) == suppliedSize
    expect(providerCalls) == 2
  }

  func test_dynamic_offscreenIntrinsicContent_isResolvedDuringMeasurement() throws {
    // given: an offscreen node whose intrinsic size requires its content
    var suppliedSize = CGSize(width: 80, height: 50)
    var providerCalls = 0
    let node = SwiftUIViewNode {
      providerCalls += 1
      return SwiftUI.Color.red.frame(width: suppliedSize.width, height: suppliedSize.height)
    }
    .fixedSize()
    var renderedView: MutableSwiftUIHostingView?
    let contentView = ComposeView {
      VStack {
        Spacer(width: 0, height: 100)
        node.onInsert { renderable, _ in
          renderedView = renderable.view as? MutableSwiftUIHostingView
        }
      }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // then: construction defers the provider
    expect(providerCalls) == 0
    expect(renderedView) == nil

    // when: external content changes before the offscreen layout
    suppliedSize = CGSize(width: 140, height: 70)
    contentView.refresh(animated: false)

    // then: the offscreen node remains unmounted
    expect(renderedView) == nil
    expect(providerCalls) == 1

    // when: scrolling reveals the node after its external data changes again
    suppliedSize = CGSize(width: 160, height: 90)
    contentView.setContentOffset(CGPoint(x: 0, y: 100))
    contentView.layoutIfNeeded()

    // then: late insertion mounts the same content that determined its intrinsic size
    let view = try renderedView.unwrap()
    expect(view.bounds.size) == CGSize(width: 140, height: 70)
    expect(view.content.sizeThatFits(contentView.bounds.size)) == CGSize(width: 140, height: 70)
    expect(providerCalls) == 1
  }

  func test_dynamic_layout_repeatedProposals_retainsResolvedContent() {
    // given: all fixed and flexible sizing combinations
    let proposals = [CGSize(width: 20, height: 10), CGSize(width: 400, height: 300), .zero, CGSize(width: 20, height: 10)]
    for (fixedWidth, fixedHeight) in [(true, true), (true, false), (false, true), (false, false)] {
      var suppliedSize = CGSize(width: 80, height: 50)
      var node = SwiftUIViewNode {
        SwiftUI.Color.red.frame(width: suppliedSize.width, height: suppliedSize.height)
      }
      .fixedSize(width: fixedWidth, height: fixedHeight)

      for proposal in proposals {
        // when: laying out the same node at small, large, zero, and repeated sizes
        let sizing = node.layout(containerSize: proposal, context: ComposeNodeLayoutContext(scaleFactor: 1))

        // then: intrinsic dimensions retain the first resolved content and flexible dimensions use the proposal
        expect(node.size) == CGSize(width: fixedWidth ? 80 : proposal.width, height: fixedHeight ? 50 : proposal.height)
        expect(sizing) == ComposeNodeSizing(width: fixedWidth ? .fixed(80) : .flexible, height: fixedHeight ? .fixed(50) : .flexible)
        suppliedSize = CGSize(width: 140, height: 70)
      }
    }
  }

  func test_dynamic_layout_flexibleContent_usesCurrentProposal() {
    // given: flexible SwiftUI content in every sizing combination
    let proposals = [CGSize(width: 20, height: 10), CGSize(width: 400, height: 300), .zero, CGSize(width: 20, height: 10)]
    for (fixedWidth, fixedHeight) in [(true, true), (true, false), (false, true), (false, false)] {
      var node = SwiftUIViewNode { SwiftUI.Color.red }
        .fixedSize(width: fixedWidth, height: fixedHeight)

      for proposal in proposals {
        // when: laying out the same content with a new proposal
        let sizing = node.layout(containerSize: proposal, context: ComposeNodeLayoutContext(scaleFactor: 1))

        // then: measurement reflects the current proposal instead of a previous layout
        expect(node.size) == proposal
        expect(sizing) == ComposeNodeSizing(width: fixedWidth ? .fixed(proposal.width) : .flexible, height: fixedHeight ? .fixed(proposal.height) : .flexible)
      }
    }
  }

  func test_dynamic_measurement_doesNotReplaceMountedContent() throws {
    // given: a preconstructed node with retained intrinsic content
    var width: CGFloat = 80
    var providerCalls = 0
    let node = SwiftUIViewNode {
      providerCalls += 1
      return SwiftUI.Color.red.frame(width: width, height: 300)
    }.fixedSize()
    var renderedView: MutableSwiftUIHostingView?
    let contentView = ComposeView {
      node.onInsert { renderable, _ in
        renderedView = renderable.view as? MutableSwiftUIHostingView
      }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.refresh(animated: false)
    let view = try renderedView.unwrap()

    // when: measuring fresh content after external data changes
    width = 140
    let measuredSize = contentView.sizeThatFits(CGSize(width: 240, height: 100))
    contentView.setContentOffset(CGPoint(x: 0, y: 20))
    contentView.layoutIfNeeded()
    contentView.frame.size.width = 240
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: measurement sees fresh data without changing the mounted layout or supplied value
    expect(measuredSize) == CGSize(width: 140, height: 300)
    expect(view.bounds.size) == CGSize(width: 80, height: 300)
    expect(view.content.sizeThatFits(view.bounds.size)) == CGSize(width: 80, height: 300)
    expect(providerCalls) == 2

    // when: another measurement runs while a content refresh is pending
    width = 160
    contentView.setNeedsRefresh(animated: false)
    let pendingSize = contentView.sizeThatFits(CGSize(width: 260, height: 100))

    // then: measurement does not consume the pending refresh or change the mounted value
    expect(pendingSize) == CGSize(width: 160, height: 300)
    expect(view.bounds.size) == CGSize(width: 80, height: 300)
    expect(view.content.sizeThatFits(view.bounds.size)) == CGSize(width: 80, height: 300)
    expect(providerCalls) == 3

    // when: layout performs the pending refresh
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: refresh resolves its own value for both measurement and rendering
    expect(view.bounds.size) == CGSize(width: 160, height: 300)
    expect(view.content.sizeThatFits(view.bounds.size)) == CGSize(width: 160, height: 300)
    expect(providerCalls) == 4
  }

  func test_dynamic_preconstructedNode_resolvesIndependentlyForEachHost() throws {
    // given: one preconstructed node supplied to two independent hosts
    var width: CGFloat = 80
    var providerCalls = 0
    let node = SwiftUIViewNode {
      providerCalls += 1
      return SwiftUI.Color.red.frame(width: width, height: 300)
    }.fixedSize()
    var firstView: MutableSwiftUIHostingView?
    var secondView: MutableSwiftUIHostingView?
    let first = ComposeView {
      node.onInsert { renderable, _ in
        firstView = renderable.view as? MutableSwiftUIHostingView
      }
    }
    let second = ComposeView {
      node.onInsert { renderable, _ in
        secondView = renderable.view as? MutableSwiftUIHostingView
      }
    }
    first.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    second.frame = first.frame

    // when: the hosts are refreshed with different external data
    first.refresh(animated: false)
    width = 140
    second.refresh(animated: false)
    let firstHost = try firstView.unwrap()
    let secondHost = try secondView.unwrap()

    // then: each host measures and renders its own resolved content
    expect(firstHost.bounds.width) == 80
    expect(firstHost.content.sizeThatFits(firstHost.bounds.size)) == CGSize(width: 80, height: 300)
    expect(secondHost.bounds.width) == 140
    expect(secondHost.content.sizeThatFits(secondHost.bounds.size)) == CGSize(width: 140, height: 300)
    expect(providerCalls) == 2

    // when: the first host resizes and scrolls after the second host's refresh
    first.frame.size.width = 240
    first.setNeedsLayout()
    first.layoutIfNeeded()
    first.setContentOffset(CGPoint(x: 0, y: 20))
    first.layoutIfNeeded()

    // then: another host's evaluation does not invalidate the first host's value
    expect(firstHost.bounds.width) == 80
    expect(firstHost.content.sizeThatFits(firstHost.bounds.size)) == CGSize(width: 80, height: 300)
    expect(providerCalls) == 2

    // when: only the first host is explicitly refreshed
    width = 160
    first.refresh(animated: false)

    // then: only that host receives the new content
    expect(firstHost.bounds.width) == 160
    expect(firstHost.content.sizeThatFits(firstHost.bounds.size)) == CGSize(width: 160, height: 300)
    expect(secondHost.bounds.width) == 140
    expect(secondHost.content.sizeThatFits(secondHost.bounds.size)) == CGSize(width: 140, height: 300)
    expect(providerCalls) == 3
  }

  func test_dynamic_cachedNode_refreshInvalidatesContentBeforeMeasurement() throws {
    // given: a persistent layout cache wrapping lazy intrinsic content
    var width: CGFloat = 80
    var providerCalls = 0
    let node = LayoutCacheNode(node: SwiftUIViewNode {
      providerCalls += 1
      return SwiftUI.Color.red.frame(width: width, height: 50)
    }.fixedSize())
    var renderedView: MutableSwiftUIHostingView?
    let contentView = ComposeView {
      node.onInsert { renderable, _ in
        renderedView = renderable.view as? MutableSwiftUIHostingView
      }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.refresh(animated: false)
    let view = try renderedView.unwrap()

    // when: the host refreshes at the same proposed size
    width = 140
    contentView.refresh(animated: false)

    // then: the persistent layout cache cannot hide the new content evaluation
    expect(view.bounds.size) == CGSize(width: 140, height: 50)
    expect(view.content.sizeThatFits(view.bounds.size)) == CGSize(width: 140, height: 50)
    expect(providerCalls) == 2

    // when: resizing without a refresh after another data change
    width = 160
    contentView.frame.size.width = 240
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: the same cache keeps the value from the most recent refresh
    expect(view.bounds.size) == CGSize(width: 140, height: 50)
    expect(view.content.sizeThatFits(view.bounds.size)) == CGSize(width: 140, height: 50)
    expect(providerCalls) == 2
  }

  func test_dynamic_sameFrameRefresh_updatesNativeAppearance() throws {
    // given: a lazy flexible node with native content
    let window = TestWindow()
    let nativeView = BaseView()
    var color = ComposeUI.Color.red
    var renderedView: MutableSwiftUIHostingView?
    let node = SwiftUIViewNode { NativeColorContent(view: nativeView, color: color) }
    let contentView = ComposeView {
      node.onUpdate { renderable, _ in
        renderedView = renderable.view as? MutableSwiftUIHostingView
      }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    window.contentView().addSubview(contentView)
    contentView.refresh(animated: false)
    let view = try renderedView.unwrap()
    view.layoutIfNeeded()

    // then: initial insertion renders the first resolved appearance
    expect(nativeView.layer().backgroundColor).toEventually(beEqual(to: ComposeUI.Color.red.cgColor))

    // when: resize keeps the same node after its data changes
    color = .blue
    contentView.frame.size.width = 160
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()
    view.layoutIfNeeded()

    // then: the native appearance remains unchanged while geometry adapts
    expect(renderedView) === view
    expect(view.bounds.size) == CGSize(width: 160, height: 100)
    expect(nativeView.layer().backgroundColor) == ComposeUI.Color.red.cgColor

    // when: an explicit refresh keeps the same renderable id and frame
    contentView.refresh(animated: false)
    view.layoutIfNeeded()

    // then: cached render-item closures use the new content on the same native host
    expect(renderedView) === view
    expect(nativeView.layer().backgroundColor).toEventually(beEqual(to: ComposeUI.Color.blue.cgColor))
    expect(nativeView.superview) != nil
  }

  func test_dynamic_unlaidOutNode_doesNotEvaluateContent() {
    // given: a lazy node that has not been laid out
    var providerCalls = 0
    let node = SwiftUIViewNode {
      providerCalls += 1
      return SwiftUI.Color.red
    }

    // when: requesting renderable items before layout
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))

    // then: no renderable or content value is created before a valid layout
    expect(items.isEmpty) == true
    expect(providerCalls) == 0
  }

  func test_dynamic_layoutContext_replacesValueWithoutChangingEarlierItems() throws {
    // given: a measured node and a render item using its standalone content
    var width: CGFloat = 80
    var providerCalls = 0
    var node = SwiftUIViewNode {
      providerCalls += 1
      return SwiftUI.Color.red.frame(width: width, height: 50)
    }.fixedSize()
    let proposal = CGSize(width: 200, height: 100)
    let standalone = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: proposal, context: standalone)
    let firstItem = try node.renderableItems(in: CGRect(origin: .zero, size: proposal)).first.unwrap()

    // when: the same mutable node is measured in a new content context
    width = 140
    let refreshed = ComposeNodeLayoutContext(scaleFactor: 1, contentEvaluation: ContentEvaluation())
    _ = node.layout(containerSize: proposal, context: refreshed)
    let secondItem = try node.renderableItems(in: CGRect(origin: .zero, size: proposal)).first.unwrap()
    let firstRenderable = firstItem.make(RenderableMakeContext(initialFrame: firstItem.frame, contentView: nil))
    let secondRenderable = secondItem.make(RenderableMakeContext(initialFrame: secondItem.frame, contentView: nil))
    firstItem.update(firstRenderable, RenderableUpdateContext(updateType: .insert, oldFrame: .zero, newFrame: firstItem.frame, animationTiming: nil, contentView: nil))
    secondItem.update(secondRenderable, RenderableUpdateContext(updateType: .insert, oldFrame: .zero, newFrame: secondItem.frame, animationTiming: nil, contentView: nil))
    let firstHost = try (firstRenderable.view as? MutableSwiftUIHostingView).unwrap()
    let secondHost = try (secondRenderable.view as? MutableSwiftUIHostingView).unwrap()

    // then: each item retains the content that determined its own frame
    expect(firstHost.bounds.size) == CGSize(width: 80, height: 50)
    expect(firstHost.content.sizeThatFits(proposal)) == CGSize(width: 80, height: 50)
    expect(secondHost.bounds.size) == CGSize(width: 140, height: 50)
    expect(secondHost.content.sizeThatFits(proposal)) == CGSize(width: 140, height: 50)
    expect(providerCalls) == 2

    // when: another proposal uses the same content context
    width = 160
    _ = node.layout(containerSize: CGSize(width: 240, height: 100), context: refreshed)

    // then: geometry updates keep that context's resolved value
    expect(node.size) == CGSize(width: 140, height: 50)
    expect(providerCalls) == 2

    // when: direct standalone layout resumes with a different context
    _ = node.layout(containerSize: proposal, context: standalone)

    // then: the node resolves new standalone content without changing either existing item
    expect(node.size) == CGSize(width: 160, height: 50)
    expect(firstHost.content.sizeThatFits(proposal)) == CGSize(width: 80, height: 50)
    expect(secondHost.content.sizeThatFits(proposal)) == CGSize(width: 140, height: 50)
    expect(providerCalls) == 3
  }

  func test_dynamic_nestedInsertion_reusesParentMeasuredContent() throws {
    // given: intrinsic content that changes after parent measurement but before the nested view renders
    var width: CGFloat = 80
    var providerCalls = 0
    var innerHost: MutableSwiftUIHostingView?
    var nestedView: ComposeView?
    let contentView = ComposeView {
      ComposeViewNode {
        SwiftUIViewNode {
          providerCalls += 1
          return SwiftUI.Color.red.frame(width: width, height: 50)
        }
        .fixedSize()
        .onInsert { renderable, _ in
          innerHost = renderable.view as? MutableSwiftUIHostingView
        }
      }
      .onUpdate { renderable, _ in
        nestedView = renderable.view as? ComposeView
        width = 140
      }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)

    // when: the parent inserts the nested view and the child performs its scheduled refresh
    contentView.refresh(animated: false)
    expect(innerHost != nil).toEventually(beEqual(to: true))
    let view = try innerHost.unwrap()

    // then: the nested host renders the value used to measure its parent's frame
    expect(nestedView?.bounds().size) == CGSize(width: 80, height: 50)
    expect(view.content.sizeThatFits(view.bounds.size)) == CGSize(width: 80, height: 50)
    expect(providerCalls) == 1

    // when: the nested view independently requests a refresh after receiving its content
    let child = try nestedView.unwrap()
    child.refresh(animated: false)

    // then: the child's refresh resolves a new value without requiring a new node
    expect(view.content.sizeThatFits(view.bounds.size)) == CGSize(width: 140, height: 50)
    expect(providerCalls) == 2
  }

  func test_dynamic_nestedUpdate_usesPassEvaluationInsteadOfHostState() throws {
    for updateType in [RenderableUpdateType.insert, .refresh] {
      // given: nested content already measured for a pass whose host has since refreshed
      var width: CGFloat = 80
      var providerCalls = 0
      var innerHost: MutableSwiftUIHostingView?
      var node = ComposeViewNode {
        SwiftUIViewNode {
          providerCalls += 1
          return SwiftUI.Color.red.frame(width: width, height: 50)
        }
        .fixedSize()
        .onUpdate { renderable, _ in
          innerHost = renderable.view as? MutableSwiftUIHostingView
        }
      }
      let evaluation = ContentEvaluation()
      let proposal = CGSize(width: 200, height: 100)
      _ = node.layout(containerSize: proposal, context: ComposeNodeLayoutContext(scaleFactor: 1, contentEvaluation: evaluation))
      let item = try unwrap(node.renderableItems(in: CGRect(origin: .zero, size: proposal)).first)
      let parent = ComposeView { ColorNode(.blue) }
      parent.frame = CGRect(origin: .zero, size: proposal)
      width = 140
      parent.refresh(animated: false)
      let renderable = item.make(RenderableMakeContext(initialFrame: item.frame, contentView: parent))
      let child = try unwrap(renderable.view as? ComposeView)

      // when: the original pass supplies its content to the nested view after the parent's state changed
      item.update(renderable, RenderableUpdateContext(updateType: updateType, oldFrame: .zero, newFrame: item.frame, animationTiming: nil, contentView: parent, contentEvaluation: evaluation))
      child.setNeedsLayout()
      child.layoutIfNeeded()

      // then: the child uses the value measured by the pass rather than evaluating against the new host state
      let host = try unwrap(innerHost)
      expect(child.bounds().size) == CGSize(width: 80, height: 50)
      expect(host.content.sizeThatFits(host.bounds.size)) == CGSize(width: 80, height: 50)
      expect(providerCalls) == 1
    }
  }

  func test_dynamic_cachedNode_measurementDoesNotChangeReinsertedContent() throws {
    // given: a persistent cache whose visible content has already been resolved
    var width: CGFloat = 80
    let node = LayoutCacheNode(node: SwiftUIViewNode {
      SwiftUI.Color.red.frame(width: width, height: 50)
    }.fixedSize())
    var renderedView: MutableSwiftUIHostingView?
    let contentView = ComposeView {
      VStack {
        node.onInsert { renderable, _ in
          renderedView = renderable.view as? MutableSwiftUIHostingView
        }
        Spacer(height: 300)
      }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.refresh(animated: false)
    let initialView = try renderedView.unwrap()
    expect(initialView.content.sizeThatFits(initialView.bounds.size)) == CGSize(width: 80, height: 50)

    // when: standalone measurement resolves different content through the persistent cache
    width = 140
    let measuredSize = contentView.sizeThatFits(contentView.bounds().size)
    contentView.setContentOffset(CGPoint(x: 0, y: 150))
    contentView.layoutIfNeeded()
    expect(initialView.superview) == nil
    renderedView = nil
    contentView.setContentOffset(.zero)
    contentView.layoutIfNeeded()

    // then: reinsertion still uses the rendered tree's content rather than the measurement result
    let view = try renderedView.unwrap()
    expect(measuredSize.width) == 140
    expect(view.content.sizeThatFits(view.bounds.size)) == CGSize(width: 80, height: 50)
  }

  func test_dynamic_publicSetContent_replacesPendingInheritedContent() throws {
    // given: measured content and its evaluation waiting to be installed in another view
    var width: CGFloat = 80
    let evaluation = ContentEvaluation()
    var node = SwiftUIViewNode {
      SwiftUI.Color.red.frame(width: width, height: 50)
    }.fixedSize()
    _ = node.layout(containerSize: CGSize(width: 200, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 1, contentEvaluation: evaluation))
    var renderedView: MutableSwiftUIHostingView?
    let contentView = ComposeView()
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.setPreparedContent(node, contentEvaluation: evaluation)

    // when: the application replaces the pending inherited content through the public API
    width = 140
    contentView.setContent {
      node.onInsert { renderable, _ in
        renderedView = renderable.view as? MutableSwiftUIHostingView
      }
    }
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: the application refresh gets a new evaluation rather than reusing the inherited value
    let view = try renderedView.unwrap()
    expect(view.bounds.size) == CGSize(width: 140, height: 50)
    expect(view.content.sizeThatFits(view.bounds.size)) == CGSize(width: 140, height: 50)
  }

  func test_static_refreshWithSameId_retainsMountedContent() throws {
    // given: a static node displaying a native red view
    let window = TestWindow()
    let initialNativeView = BaseView()
    var suppliedView = initialNativeView
    var color = ComposeUI.Color.red
    var id = "static"
    var renderedView: SwiftUIHostingView<AnyView>?
    let contentView = ComposeView {
      SwiftUIViewNode(id: id, NativeColorContent(view: suppliedView, color: color))
        .onUpdate { renderable, _ in
          renderedView = renderable.view as? SwiftUIHostingView<AnyView>
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    window.contentView().addSubview(contentView)
    contentView.refresh(animated: false)
    let view = try renderedView.unwrap()
    view.layoutIfNeeded()

    // then: the static host mounts the supplied appearance
    expect(initialNativeView.layer().backgroundColor).toEventually(beEqual(to: ComposeUI.Color.red.cgColor))
    expect(initialNativeView.superview) != nil
    expect(view is MutableSwiftUIHostingView) == false

    // when: a resize follows changes to the supplied content
    suppliedView = BaseView()
    color = .blue
    contentView.frame.size = CGSize(width: 200, height: 150)
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()
    view.layoutIfNeeded()

    // then: resizing preserves the original content while updating its host frame
    expect(renderedView) === view
    expect(view.bounds.size) == CGSize(width: 200, height: 150)
    expect(initialNativeView.layer().backgroundColor) == ComposeUI.Color.red.cgColor
    expect(suppliedView.superview) == nil

    // when: refreshing with a new static value under the same id
    contentView.refresh(animated: false)
    view.layoutIfNeeded()

    // then: a static host does not replace its original content on refresh
    expect(renderedView) === view
    expect(initialNativeView.layer().backgroundColor) == ComposeUI.Color.red.cgColor
    expect(suppliedView.superview) == nil

    // when: the static content receives a new id
    id = "replacement"
    contentView.refresh(animated: false)
    renderedView?.layoutIfNeeded()

    // then: a new host mounts the new appearance
    expect(renderedView) !== view
    expect(suppliedView.layer().backgroundColor).toEventually(beEqual(to: ComposeUI.Color.blue.cgColor))
    expect(suppliedView.superview) != nil
    expect(renderedView?.window) === window
  }

  func test_static_fixedWidth_fixedHeight() {
    // given: a static SwiftUI view node with fixed width and height
    var view: SwiftUIHostingView<AnyView>?
    let contentView = ComposeView {
      // static
      SwiftUIViewNode(
        id: "text",
        SwiftUI.Color.black
          .frame(width: 80, height: 50)
      )
      .fixedSize(width: true, height: true)
      .onInsert { renderable, _ in
        view = renderable.view as? SwiftUIHostingView<AnyView>
      }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the view is refreshed
    contentView.refresh()

    // then: the hosting view uses the intrinsic size
    expect(view?.bounds.size) == CGSize(width: 80, height: 50)
  }

  func test_static_fixedWidth_flexibleHeight() {
    // given: a static SwiftUI view node with fixed width and flexible height
    var view: SwiftUIHostingView<AnyView>?
    let contentView = ComposeView {
      // static
      SwiftUIViewNode(
        id: "text",
        SwiftUI.Color.black
          .frame(width: 80, height: 50)
      )
      .fixedSize(width: true, height: false)
      .onInsert { renderable, _ in
        view = renderable.view as? SwiftUIHostingView<AnyView>
      }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the view is refreshed
    contentView.refresh()

    // then: the width is intrinsic and the height fills the container
    expect(view?.bounds.size) == CGSize(width: 80, height: 100)
  }

  func test_static_flexibleWidth_fixedHeight() {
    // given: a static SwiftUI view node with flexible width and fixed height
    var view: SwiftUIHostingView<AnyView>?
    let contentView = ComposeView {
      // static
      SwiftUIViewNode(
        id: "text",
        SwiftUI.Color.black
          .frame(width: 80, height: 50)
      )
      .fixedSize(width: false, height: true)
      .onInsert { renderable, _ in
        view = renderable.view as? SwiftUIHostingView<AnyView>
      }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the view is refreshed
    contentView.refresh()

    // then: the width fills the container and the height is intrinsic
    expect(view?.bounds.size) == CGSize(width: 100, height: 50)
  }

  func test_static_flexibleWidth_flexibleHeight() {
    // given: a static SwiftUI view node with flexible width and height
    var view: SwiftUIHostingView<AnyView>?
    let contentView = ComposeView {
      // static
      SwiftUIViewNode(
        id: "text",
        SwiftUI.Color.black
          .frame(width: 80, height: 50)
      )
      .fixedSize(width: false, height: false)
      .onInsert { renderable, _ in
        view = renderable.view as? SwiftUIHostingView<AnyView>
      }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the view is refreshed
    contentView.refresh()

    // then: the hosting view fills the container
    expect(view?.bounds.size) == CGSize(width: 100, height: 100)
  }

  func test_view_outOfBounds() {
    // given: a compose view with the SwiftUI view node placed below the visible bounds
    var view: SwiftUIHostingView<AnyView>?
    let contentView = ComposeView {
      VStack {
        Spacer(width: 0, height: 100)
        // static
        SwiftUIViewNode(
          id: "text",
          SwiftUI.Color.black
            .frame(width: 80, height: 50)
        )
        .fixedSize(width: true, height: true)
        .onInsert { renderable, _ in
          view = renderable.view as? SwiftUIHostingView<AnyView>
        }
      }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the view is refreshed
    contentView.refresh()

    // then: the out of bounds view is not created
    expect(view) == nil
  }

  func test_refreshOwnedCache_releasesProviderWhenHostIsReleased() {
    // given: a provider retained by an intrinsic node and the host's refresh cache
    weak var weakProbe: NSObject?
    weak var weakHost: ComposeView?
    autoreleasepool {
      let probe = NSObject()
      weakProbe = probe
      let node = SwiftUIViewNode { [probe] in
        _ = probe
        return SwiftUI.Color.red.frame(width: 80, height: 50)
      }.fixedSize()
      let contentView = ComposeView { node }
      weakHost = contentView
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

      // when: the host resolves content, renders, and leaves scope
      contentView.refresh(animated: false)
    }

    // then: the host, content evaluation, provider, and cached item do not form a retain cycle
    expect(weakHost).toEventually(beNil())
    expect(weakProbe).toEventually(beNil())
  }

  func test_renderableItems_doesNotRetainNodeThroughItemCache() {
    for resolvesContent in [false, true] {
      // given: a provider-owned probe that cannot be retained by SwiftUI's native sizing graph
      weak var weakProbe: AnyObject?
      do {
        let probe = NSObject()
        weakProbe = probe
        var node: any ComposeNode = SwiftUIViewNode { [probe] in
          _ = probe
          return SwiftUI.Color.red
        }
        .fixedSize(width: resolvesContent, height: resolvesContent)

        // when: the node lays out, provides renderable items, and goes out of scope
        _ = node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
        _ = node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))
      }

      // then: the provider, resolved value, and cached renderable item do not keep the node alive
      expect(weakProbe).to(beNil())
    }
  }
}

private struct NativeColorContent {

  let view: BaseView
  let color: ComposeUI.Color
}

#if canImport(AppKit)
extension NativeColorContent: NSViewRepresentable {

  func makeNSView(context: Context) -> BaseView {
    view
  }

  func updateNSView(_ nsView: BaseView, context: Context) {
    nsView.layer().backgroundColor = color.cgColor
  }
}
#endif

#if canImport(UIKit)
extension NativeColorContent: UIViewRepresentable {

  func makeUIView(context: Context) -> BaseView {
    view
  }

  func updateUIView(_ uiView: BaseView, context: Context) {
    uiView.layer().backgroundColor = color.cgColor
  }
}
#endif
