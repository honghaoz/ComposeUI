//
//  ComposeViewTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/13/24.
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

class ComposeViewTests: XCTestCase {

  private var contentView: ComposeView!

  override func setUp() {
    super.setUp()
    contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
  }

  func test_refresh() {
    var refreshCount = 0
    contentView.setContent {
      ColorNode(.red)
        .onUpdate { _, _ in
          refreshCount += 1
        }
    }
    contentView.refresh(animated: false)
    expect(refreshCount) == 1

    contentView.setNeedsRefresh(animated: false)
    contentView.setNeedsRefresh(animated: false)
    expect(refreshCount) == 1

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-9))
    expect(refreshCount) == 2
  }

  func test_centerContent() {
    // when content size is smaller than the bounds size
    do {
      let view = BaseView()
      contentView.setContent {
        ViewNode(view)
          .flexibleSize()
          .frame(width: 50, height: 80)
      }
      contentView.refresh(animated: false)

      expect(contentView.contentSize) == CGSize(width: 100, height: 100)
      expect(view.frame) == CGRect(x: 25, y: 10, width: 50, height: 80)
    }

    // when content width is smaller than the bounds width
    do {
      let view = BaseView()
      contentView.setContent {
        ViewNode(view)
          .flexibleSize()
          .frame(width: 50, height: 120)
      }
      contentView.refresh(animated: false)

      expect(contentView.contentSize) == CGSize(width: 100, height: 120)
      expect(view.frame) == CGRect(x: 25, y: 0, width: 50, height: 120)
    }

    // when content height is smaller than the bounds height
    do {
      let view = BaseView()
      contentView.setContent {
        ViewNode(view)
          .flexibleSize()
          .frame(width: 120, height: 80)
      }
      contentView.refresh(animated: false)

      expect(contentView.contentSize) == CGSize(width: 120, height: 100)
      expect(view.frame) == CGRect(x: 0, y: 10, width: 120, height: 80)
    }
  }

  func test_isScrollable() {
    // when content size is smaller than bounds size
    do {
      contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 50, height: 50)
      }
      contentView.refresh(animated: false)
      expect(contentView.isScrollable) == false

      // when isScrollable is set explicitly
      contentView.isScrollable = true
      contentView.refresh(animated: false)
      expect(contentView.isScrollable) == true

      // when isScrollable is set explicitly
      contentView.isScrollable = false
      contentView.refresh(animated: false)
      expect(contentView.isScrollable) == false
    }

    // when content size is equal to bounds size
    do {
      contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 100, height: 100)
      }
      contentView.refresh(animated: false)
      expect(contentView.isScrollable) == false

      // when isScrollable is set explicitly
      contentView.isScrollable = true
      contentView.refresh(animated: false)
      expect(contentView.isScrollable) == true

      // when isScrollable is set explicitly
      contentView.isScrollable = false
      contentView.refresh(animated: false)
      expect(contentView.isScrollable) == false
    }

    // when content size is larger than bounds size
    do {
      contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 150, height: 150)
      }
      contentView.refresh(animated: false)
      expect(contentView.isScrollable) == true

      // when isScrollable is set explicitly
      contentView.isScrollable = false
      contentView.refresh(animated: false)
      expect(contentView.isScrollable) == false

      // when isScrollable is set explicitly
      contentView.isScrollable = true
      contentView.refresh(animated: false)
      expect(contentView.isScrollable) == true
    }
  }

  func test_view_lifecycle() {
    var willInsertCount = 0
    var didInsertCount = 0
    var willUpdateCount = 0
    var updateCount = 0
    var willRemoveCount = 0
    var didRemoveCount = 0

    // show view
    contentView.setContent {
      ViewNode(
        willInsert: { view, context in
          willInsertCount += 1
        },
        didInsert: { view, context in
          didInsertCount += 1
        },
        willUpdate: { view, context in
          willUpdateCount += 1
        },
        update: { view, context in
          updateCount += 1
        },
        willRemove: { view, context in
          willRemoveCount += 1
        },
        didRemove: { view, context in
          didRemoveCount += 1
        }
      )
    }
    contentView.refresh(animated: false)

    expect(willInsertCount) == 1
    expect(didInsertCount) == 1
    expect(updateCount) == 1
    expect(willRemoveCount) == 0
    expect(didRemoveCount) == 0

    // remove view
    contentView.setContent {
      Empty()
    }

    contentView.refresh(animated: false)

    expect(willInsertCount) == 1
    expect(didInsertCount) == 1
    expect(willUpdateCount) == 1
    expect(updateCount) == 1
    expect(willRemoveCount) == 1
    expect(didRemoveCount) == 1
  }

  func test_visibleBoundsInsets() {
    var isTopRendered = false
    var isBottomRendered = false

    contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.visibleBoundsInsets = EdgeInsets(top: -1, left: 0, bottom: -1, right: 0)

    contentView.setContent {
      ZStack {
        // top view
        ViewNode()
          .frame(width: 100, height: 100)
          .offset(x: 0, y: -100) // move the view above the normal bounds
          .onInsert { _, _ in
            isTopRendered = true
          }
          .onRemove { _, _ in
            isTopRendered = false
          }

        // bottom view
        ViewNode()
          .frame(width: 100, height: 100)
          .offset(x: 0, y: 100) // move the view below the normal bounds
          .onInsert { _, _ in
            isBottomRendered = true
          }
          .onRemove { _, _ in
            isBottomRendered = false
          }
      }
    }

    contentView.refresh(animated: false)

    expect(contentView.contentSize) == CGSize(width: 100, height: 100)
    expect(isTopRendered) == true
    expect(isBottomRendered) == true
  }

  func test_transitions() {
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

  func test_transition_reinsertRemovingRenderable() {
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
