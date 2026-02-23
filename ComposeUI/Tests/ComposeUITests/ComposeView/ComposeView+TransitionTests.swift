//
//  ComposeView+TransitionTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
//

import ChouTiTest

@testable import ComposeUI

class ComposeView_TransitionTests: XCTestCase {

  func test_transitions() {
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var insertionCompletion: (() -> Void)?
    var removalCompletion: (() -> Void)?
    let transition = RenderableTransition(
      insert: RenderableTransition.InsertTransition { renderable, context, completion in
        renderable.setFrame(context.targetFrame)
        insertionCompletion = completion
      },
      remove: RenderableTransition.RemoveTransition { renderable, context, completion in
        removalCompletion = completion
      }
    )

    var didInsert = false
    contentView.setContent {
      ColorNode(.red)
        .onInsert { _, _ in
          didInsert = true
        }
        .transition(transition)
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: true)

    expect(didInsert) == false
    insertionCompletion?()
    expect(didInsert) == true // expect the didInsert is called after the transition completion

    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // before the removal completion, the renderable is still in the removingRenderableMap
    expect(contentView.test.removingRenderableMap.count) == 1
    expect(contentView.test.removingRenderableTransitionCompletionMap.count) == 1

    removalCompletion?()

    // after the removal completion, the renderable is removed from the removingRenderableMap
    expect(contentView.test.removingRenderableMap.count) == 0
    expect(contentView.test.removingRenderableTransitionCompletionMap.count) == 0
  }

  func test_reinsertRemovingRenderable() {
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var insertionCompletion: (() -> Void)?
    var removalCompletion: (() -> Void)?
    let transition = RenderableTransition(
      insert: RenderableTransition.InsertTransition { renderable, context, completion in
        renderable.setFrame(context.targetFrame)
        insertionCompletion = completion
      },
      remove: RenderableTransition.RemoveTransition { renderable, context, completion in
        removalCompletion = completion
      }
    )

    contentView.setContent {
      ColorNode(.red)
        .transition(transition)
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: false)

    contentView.setContent {
      Empty()
    }
    contentView.refresh(animated: true)

    // before the removal completion, the renderable is still in the removingRenderableMap
    expect(contentView.test.removingRenderableMap.count) == 1
    expect(contentView.test.removingRenderableTransitionCompletionMap.count) == 1

    // reinsert the renderable
    contentView.setContent {
      ColorNode(.red)
        .frame(width: 100, height: 100)
    }
    contentView.refresh(animated: true)

    // the renderable is not in the removingRenderableMap
    expect(contentView.test.removingRenderableMap.count) == 0
    expect(contentView.test.removingRenderableTransitionCompletionMap.count) == 0

    removalCompletion?()
    insertionCompletion?()
  }
}
