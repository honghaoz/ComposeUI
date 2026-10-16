//
//  ComposeView+RenderableReplacementTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/15/26.
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

class ComposeView_RenderableReplacementTests: XCTestCase {

  func test_render_itemOfAnotherRenderableType_replacesTheRenderable() throws {
    // given: a compose view showing a view node of one view type, which records its lifecycle events
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let recorder = EventRecorder()
    contentView.setContent {
      Self.recorded(ViewNode<FirstView>().id("item"), by: recorder)
    }
    contentView.refresh(animated: false)
    let firstView = try recorder.insertedViews.first.unwrap()
    recorder.events = []

    // when: the content shows a view node of another view type, under the same id
    contentView.setContent {
      Self.recorded(ViewNode<SecondView>().id("item"), by: recorder)
    }
    contentView.refresh(animated: false)

    // then: the first view is removed, and a view of the new type is inserted in its place, instead of the first view
    // being updated as a view of the new type
    expect(recorder.events) == ["remove FirstView", "update SecondView", "insert SecondView"]
    expect(firstView.superview) == nil
    let secondView = try recorder.insertedViews.last.unwrap()
    expect(secondView is SecondView) == true
    expect(secondView.superview) != nil
  }

  func test_render_itemOfAnotherRenderableType_animatedRefresh_replacesWithoutTransitions() throws {
    // given: a compose view showing a view node with a transition that records its insertions and removals
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    var transitionEvents: [String] = []
    let transition = RenderableTransition(
      insert: RenderableTransition.InsertTransition { renderable, context, completion in
        transitionEvents.append("insert \(Self.name(of: renderable))")
        renderable.setFrame(context.targetFrame)
        completion()
      },
      remove: RenderableTransition.RemoveTransition { renderable, _, completion in
        transitionEvents.append("remove \(Self.name(of: renderable))")
        completion()
      }
    )
    contentView.setContent {
      ZStack {
        ViewNode<FirstView>().id("item").transition(transition)
      }
    }
    contentView.refresh(animated: false)

    // when: in an animated refresh, the content shows a view node of another view type under the same id, and a new
    // view node with the same transition
    contentView.setContent {
      ZStack {
        ViewNode<SecondView>().id("item").transition(transition)
        ViewNode<ThirdView>().id("new").transition(transition)
      }
    }
    contentView.refresh(animated: true)

    // then: only the new view node's view is inserted with the transition, while the view of the other type replaces the
    // first view without the transitions, since its item stays in the content
    expect(transitionEvents) == ["insert ThirdView"]
    expect(contentView.test.removingRenderableMap.count) == 0
  }

  func test_render_itemOfAnotherRenderableType_poolsTheReplacedRenderable() throws {
    // given: a compose view with its own pool, showing a pooled view node of one view type
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.renderablePool = RenderablePool()
    let recorder = EventRecorder()
    contentView.setContent {
      Self.recorded(ViewNode<FirstView>().id("item").reuseId("item"), by: recorder)
    }
    contentView.refresh(animated: false)
    let firstView = try recorder.insertedViews.first.unwrap()

    // when: the content shows a pooled view node of another view type under the same id, and then the first one again
    contentView.setContent {
      Self.recorded(ViewNode<SecondView>().id("item").reuseId("item"), by: recorder)
    }
    contentView.refresh(animated: false)
    contentView.setContent {
      Self.recorded(ViewNode<FirstView>().id("item").reuseId("item"), by: recorder)
    }
    contentView.refresh(animated: false)

    // then: the first view comes back from the pool, which kept it when the view of the other type replaced it
    expect(recorder.insertedViews.count) == 3
    expect(recorder.insertedViews.last) === firstView
  }

  func test_render_itemOfAnotherRenderableType_keepsTheSubviewOrder() throws {
    // given: a compose view showing three view nodes on top of each other
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let recorder = EventRecorder()
    var middleIsSecondView = false
    contentView.setContent {
      ZStack {
        Self.recorded(ViewNode<FirstView>().id("bottom"), by: recorder)
        Self.middleNode(isSecondView: middleIsSecondView, recordedBy: recorder)
        Self.recorded(ViewNode<FirstView>().id("top"), by: recorder)
      }
    }
    contentView.refresh(animated: false)
    expect(recorder.insertedViews.count) == 3
    let bottomView = recorder.insertedViews[0]
    let topView = recorder.insertedViews[2]

    // when: the middle view node changes to another view type, under the same id
    middleIsSecondView = true
    contentView.refresh(animated: false)

    // then: the middle node's new view is between the other two in the subviews, whose order the hit testing follows,
    // instead of above them, where the update pass inserts a new view
    let middleView = try recorder.insertedViews.last.unwrap()
    expect(middleView is SecondView) == true
    let views = [bottomView, middleView, topView]
    let subviewOrder = try bottomView.superview.unwrap().subviews.filter { subview in views.contains { $0 === subview } }
    expect(subviewOrder.map { ObjectIdentifier($0) }) == views.map { ObjectIdentifier($0) }
  }

  func test_render_reorderedItemsOfDifferentRenderableTypes_keepTheirRenderables() throws {
    // given: a compose view showing view nodes of two view types, with fixed ids that reordering keeps
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let recorder = EventRecorder()
    var order = ["first", "second"]
    contentView.setContent {
      ZStack {
        for key in order {
          if key == "first" {
            Self.recorded(ViewNode<FirstView>().fixedId(key), by: recorder)
          } else {
            Self.recorded(ViewNode<SecondView>().fixedId(key), by: recorder)
          }
        }
      }
    }
    contentView.refresh(animated: false)
    expect(recorder.insertedViews.count) == 2
    recorder.events = []

    // when: the view nodes swap places
    order = ["second", "first"]
    contentView.refresh(animated: false)

    // then: each view node updates its own view, since each item is compared with the previous item of its id, instead
    // of the one that was in its place
    expect(recorder.events) == ["update SecondView", "update FirstView"]
    expect(recorder.insertedViews.count) == 2
  }

  func test_render_removedItemBackAsAnotherRenderableType_insertsANewRenderable() throws {
    // given: a compose view whose view node is being removed, with a transition that hasn't completed
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    var removalCompletion: (() -> Void)?
    let transition = RenderableTransition(
      insert: nil,
      remove: RenderableTransition.RemoveTransition { _, _, completion in
        removalCompletion = completion
      }
    )
    let recorder = EventRecorder()
    contentView.setContent {
      Self.recorded(ViewNode<FirstView>().id("item").transition(transition), by: recorder)
    }
    contentView.refresh(animated: false)
    let firstView = try recorder.insertedViews.first.unwrap()
    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)
    expect(contentView.test.removingRenderableMap.count) == 1

    // when: the content shows a view node of another view type under the same id, before the removal completes
    contentView.setContent {
      Self.recorded(ViewNode<SecondView>().id("item").transition(transition), by: recorder)
    }
    contentView.refresh(animated: true)

    // then: a view of the new type is inserted, and the first view, which an item of another type can't take back, is
    // still being removed
    let secondView = try recorder.insertedViews.last.unwrap()
    expect(secondView is SecondView) == true
    expect(firstView.superview) != nil
    expect(contentView.test.removingRenderableMap.count) == 1

    // when: the removal completes
    try removalCompletion.unwrap()()

    // then: the first view is removed
    expect(firstView.superview) == nil
    expect(contentView.test.removingRenderableMap.count) == 0
  }

  func test_render_renderableItemsMakingOtherViews_keepTheRenderable() throws {
    // given: a compose view showing a node whose renderable item makes a view of one type, and has no view type of its
    // own, as a `RenderableItem` made with its own initializer
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    var makeView: () -> View = { FirstView() }
    var updatedViews: [View] = []
    contentView.setContent {
      RenderableItemNode(makeView: makeView) { renderable in
        renderable.view.map { updatedViews.append($0) }
      }
    }
    contentView.refresh(animated: false)
    let firstView = try updatedViews.first.unwrap()

    // when: the node's renderable item makes a view of another type, under the same id
    makeView = { SecondView() }
    contentView.refresh(animated: false)

    // then: the renderable item updates the view it made first, since it has no view type to compare
    expect(updatedViews.count) == 2
    expect(updatedViews.last) === firstView
  }

  // MARK: - Helpers

  /// Returns the node with lifecycle blocks that record the events and the inserted views.
  private static func recorded(_ node: some ComposeNode, by recorder: EventRecorder) -> some ComposeNode {
    node
      .onInsert { renderable, _ in
        recorder.events.append("insert \(name(of: renderable))")
        if let view = renderable.view {
          recorder.insertedViews.append(view)
        }
      }
      .onUpdate { renderable, _ in
        recorder.events.append("update \(name(of: renderable))")
      }
      .onRemove { renderable, _ in
        recorder.events.append("remove \(name(of: renderable))")
      }
  }

  /// Returns the middle view node of a stack, of the second or the first view type.
  private static func middleNode(isSecondView: Bool, recordedBy recorder: EventRecorder) -> any ComposeNode {
    if isSecondView {
      return recorded(ViewNode<SecondView>().id("middle"), by: recorder)
    } else {
      return recorded(ViewNode<FirstView>().id("middle"), by: recorder)
    }
  }

  /// Returns the name of the renderable's view type.
  private static func name(of renderable: Renderable) -> String {
    renderable.view.map { "\(type(of: $0))" } ?? "layer"
  }
}

// MARK: - Test Types

private final class FirstView: BaseView {}

private final class SecondView: BaseView {}

private final class ThirdView: BaseView {}

/// The lifecycle events and the inserted views of renderables.
private final class EventRecorder {

  var events: [String] = []

  var insertedViews: [View] = []
}

/// A node with a renderable item made with `RenderableItem`'s own initializer, which has no view type of its own.
private struct RenderableItemNode: ComposeNode {

  let makeView: () -> View

  let update: (Renderable) -> Void

  var id: ComposeNodeId = .custom("item", isFixed: false)

  private(set) var size: CGSize = .zero

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    size = containerSize
    return ComposeNodeSizing(width: .flexible, height: .flexible)
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
    let makeView = makeView
    let update = update
    items.append(
      RenderableItem(
        id: id,
        frame: CGRect(origin: .zero, size: size),
        make: { _ in .view(makeView()) },
        update: { renderable, _ in
          update(renderable)
        }
      )
    )
  }
}
