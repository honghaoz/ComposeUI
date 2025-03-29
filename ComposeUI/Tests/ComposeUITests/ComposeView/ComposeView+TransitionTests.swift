//
//  ComposeView+TransitionTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
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

final class ComposeView_TransitionTests: XCTestCase {

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
