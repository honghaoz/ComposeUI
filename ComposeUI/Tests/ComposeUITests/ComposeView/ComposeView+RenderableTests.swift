//
//  ComposeView+RenderableTests.swift
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

class ComposeView_RenderableTests: XCTestCase {

  func test_lifecycle() {
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

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

  func test_updateContext() {
    // test the update context provided to the renderable update block is correct

    // given: a compose view
    var willUpdateContext: RenderableUpdateContext?
    var updateContext: RenderableUpdateContext?
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 150))

    #if canImport(AppKit)
    view.scrollIndicatorBehavior = .auto
    // use legacy scrollers so the scroller thickness affects bounds().
    view.scrollerStyle = .legacy
    view.hasHorizontalScroller = true
    view.hasVerticalScroller = true
    #endif

    view.setContent {
      ViewNode()
        .frame(width: 100, height: 200)
        .willUpdate { renderable, context in
          willUpdateContext = context
        }
        .onUpdate { renderable, context in
          updateContext = context
        }
    }

    // when: refresh the view initially
    view.refresh(animated: false)

    // then: expect the update context is correct
    expect(willUpdateContext) == RenderableUpdateContext(
      updateType: .insert,
      oldFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
      newFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
      animationTiming: nil,
      contentView: view
    )
    expect(updateContext) == RenderableUpdateContext(
      updateType: .insert,
      oldFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
      newFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
      animationTiming: nil,
      contentView: view
    )

    // when: refresh the view again
    view.refresh(animated: false)

    // then: expect the update context is correct
    expect(willUpdateContext) == RenderableUpdateContext(
      updateType: .refresh,
      oldFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
      newFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
      animationTiming: nil,
      contentView: view
    )
    expect(updateContext) == RenderableUpdateContext(
      updateType: .refresh,
      oldFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
      newFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
      animationTiming: nil,
      contentView: view
    )

    // when: scroll the view
    view.setContentOffset(CGPoint(x: 0, y: 10))
    view.layoutIfNeeded()

    // then: expect the update context is correct
    expect(willUpdateContext) == RenderableUpdateContext(
      updateType: .scroll,
      oldFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
      newFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
      animationTiming: nil,
      contentView: view
    )
    expect(updateContext) == RenderableUpdateContext(
      updateType: .scroll,
      oldFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
      newFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
      animationTiming: nil,
      contentView: view
    )

    // when: resize the view
    view.frame.size = CGSize(width: 200, height: 200)
    view.layoutIfNeeded()

    // then: expect the update context is correct
    expect(willUpdateContext) == RenderableUpdateContext(
      updateType: .boundsChange,
      oldFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
      newFrame: CGRect(x: 50, y: 0, width: 100, height: 200),
      animationTiming: nil,
      contentView: view
    )
    expect(updateContext) == RenderableUpdateContext(
      updateType: .boundsChange,
      oldFrame: CGRect(x: 0, y: 0, width: 100, height: 200),
      newFrame: CGRect(x: 50, y: 0, width: 100, height: 200),
      animationTiming: nil,
      contentView: view
    )
  }
}
