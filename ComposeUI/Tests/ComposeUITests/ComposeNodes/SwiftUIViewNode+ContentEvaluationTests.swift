//
//  SwiftUIViewNode+ContentEvaluationTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/11/26.
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

class SwiftUIViewNode_ContentEvaluationTests: XCTestCase {

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
    // given: all fixed and flexible sizing combinations laid out with one context
    let proposals = [CGSize(width: 20, height: 10), CGSize(width: 400, height: 300), .zero, CGSize(width: 20, height: 10)]
    for (fixedWidth, fixedHeight) in [(true, true), (true, false), (false, true), (false, false)] {
      var suppliedSize = CGSize(width: 80, height: 50)
      var node = SwiftUIViewNode {
        SwiftUI.Color.red.frame(width: suppliedSize.width, height: suppliedSize.height)
      }
      .fixedSize(width: fixedWidth, height: fixedHeight)
      let context = ComposeNodeLayoutContext(scaleFactor: 1)

      for proposal in proposals {
        // when: laying out the same node at small, large, zero, and repeated sizes with the same context
        let sizing = node.layout(containerSize: proposal, context: context)

        // then: intrinsic dimensions retain the first resolved content and flexible dimensions use the proposal
        expect(node.size) == CGSize(width: fixedWidth ? 80 : proposal.width, height: fixedHeight ? 50 : proposal.height)
        expect(sizing) == ComposeNodeSizing(width: fixedWidth ? .fixed(80) : .flexible, height: fixedHeight ? .fixed(50) : .flexible)
        suppliedSize = CGSize(width: 140, height: 70)
      }
    }
  }

  func test_dynamic_layout_newContext_resolvesContentAgain() {
    // given: intrinsic content whose external data changes between layouts
    var suppliedSize = CGSize(width: 80, height: 50)
    var providerCalls = 0
    var node = SwiftUIViewNode {
      providerCalls += 1
      return SwiftUI.Color.red.frame(width: suppliedSize.width, height: suppliedSize.height)
    }
    .fixedSize()
    let proposal = CGSize(width: 400, height: 300)

    // when: laying out with a new context after the data changes
    _ = node.layout(containerSize: proposal, context: ComposeNodeLayoutContext(scaleFactor: 1))
    suppliedSize = CGSize(width: 140, height: 70)
    _ = node.layout(containerSize: proposal, context: ComposeNodeLayoutContext(scaleFactor: 1))

    // then: each context starts a new content evaluation, so the node measures the latest content
    expect(node.size) == CGSize(width: 140, height: 70)
    expect(providerCalls) == 2
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

    // when: direct standalone layout resumes with the earlier context
    _ = node.layout(containerSize: proposal, context: standalone)

    // then: the node returns to that context's resolved content without evaluating again or changing either item
    expect(node.size) == CGSize(width: 80, height: 50)
    expect(firstHost.content.sizeThatFits(proposal)) == CGSize(width: 80, height: 50)
    expect(secondHost.content.sizeThatFits(proposal)) == CGSize(width: 140, height: 50)
    expect(providerCalls) == 2
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

    // when: the parent inserts the nested view, which renders within the parent's pass
    contentView.refresh(animated: false)
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

  func test_dynamic_publicSetContent_replacesInheritedContentWithNewEvaluation() throws {
    // given: measured content displayed with its parent's evaluation
    var width: CGFloat = 80
    let evaluation = ContentEvaluation()
    var renderedView: MutableSwiftUIHostingView?
    var node = SwiftUIViewNode {
      SwiftUI.Color.red.frame(width: width, height: 50)
    }
    .fixedSize()
    .onUpdate { renderable, _ in
      renderedView = renderable.view as? MutableSwiftUIHostingView
    }
    _ = node.layout(containerSize: CGSize(width: 200, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 1, contentEvaluation: evaluation))
    let contentView = ComposeView()
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    contentView.setPreparedContent(node, contentEvaluation: evaluation, animated: false)
    let view = try renderedView.unwrap()
    expect(view.bounds.size) == CGSize(width: 80, height: 50)

    // when: the application replaces the inherited content through the public API after its data changes
    width = 140
    contentView.setContent { node }
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: the application refresh reuses the host but evaluates the content anew instead of reusing the inherited value
    expect(renderedView) === view
    expect(view.bounds.size) == CGSize(width: 140, height: 50)
    expect(view.content.sizeThatFits(view.bounds.size)) == CGSize(width: 140, height: 50)
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
}
