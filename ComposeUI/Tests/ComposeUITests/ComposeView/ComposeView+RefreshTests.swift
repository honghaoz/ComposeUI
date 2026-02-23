//
//  ComposeView+RefreshTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/3/25.
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

import XCTest
import Foundation

@testable import ComposeUI

class ComposeView_RefreshTests: XCTestCase {

  func test_refresh() {
    var renderCount = 0
    var refreshCount = 0
    var isAnimated: Bool?
    let view = ComposeView {
      renderCount += 1
      LayerNode()
        .animation(.linear())
        .onUpdate { _, context in
          isAnimated = context.animationTiming != nil
          refreshCount += 1
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

    view.refresh()
    XCTAssertEqual(renderCount, 1)
    XCTAssertEqual(refreshCount, 1)
    XCTAssertEqual(isAnimated, false) // initial render is always not animated
    isAnimated = nil

    view.refresh()
    XCTAssertEqual(renderCount, 2)
    XCTAssertEqual(refreshCount, 2)
    XCTAssertEqual(isAnimated, true)
    isAnimated = nil

    view.refresh(animated: false)
    XCTAssertEqual(renderCount, 3)
    XCTAssertEqual(refreshCount, 3)
    XCTAssertEqual(isAnimated, false)
    isAnimated = nil

    view.setNeedsRefresh(animated: true)
    XCTAssertEqual(renderCount, 3)
    XCTAssertEqual(refreshCount, 3)
    view.setNeedsRefresh()
    XCTAssertEqual(renderCount, 3)
    XCTAssertEqual(refreshCount, 3)
    view.setNeedsRefresh(animated: false)
    XCTAssertEqual(renderCount, 3)
    XCTAssertEqual(refreshCount, 3)

    XCTAssertEventuallyEqual(renderCount, 4)
    XCTAssertEqual(refreshCount, 4)
    XCTAssertEqual(isAnimated, false) // the refresh animation flag should be the last scheduled refresh
  }

  func test_setNeedsRefresh() {
    // given: a compose view
    var renderCount = 0
    var refreshCount = 0
    var isAnimated: Bool?
    let view = ComposeView {
      renderCount += 1
      LayerNode()
        .animation(.linear())
        .onUpdate { _, context in
          isAnimated = context.animationTiming != nil
          refreshCount += 1
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

    // when: set needs refresh
    view.setNeedsRefresh()

    // then: expect a pending refresh is scheduled but the refresh is not performed immediately
    XCTAssertTrue(view.test.hasPendingRefresh)
    XCTAssertEqual(renderCount, 0)
    XCTAssertEqual(refreshCount, 0)
    XCTAssertNil(isAnimated)
    isAnimated = nil

    // wait for next run loop iteration
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    // then: expect the refresh is performed
    XCTAssertFalse(view.test.hasPendingRefresh)
    XCTAssertEqual(renderCount, 1)
    XCTAssertEqual(refreshCount, 1)
    XCTAssertEqual(isAnimated, false)
    isAnimated = nil

    // when: set needs refresh again
    view.setNeedsRefresh()

    XCTAssertTrue(view.test.hasPendingRefresh)
    XCTAssertEqual(renderCount, 1)
    XCTAssertEqual(refreshCount, 1)
    XCTAssertNil(isAnimated)
    isAnimated = nil

    // when: refresh the view
    view.refresh()

    // then: expect the refresh is performed and the pending refresh is cancelled
    XCTAssertFalse(view.test.hasPendingRefresh)
    XCTAssertEqual(renderCount, 2)
    XCTAssertEqual(refreshCount, 2)
    XCTAssertEqual(isAnimated, true)
  }

  func test_subview_order() {
    // verify that the subviews are in the correct order after a refresh.

    let view1 = UIView()
    let view2 = UIView()
    let view3 = UIView()

    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))

    contentView.setContent {
      HorizontalStack {
        ViewNode(view1, update: { _, _ in })
          .frame(width: 100, height: 100)
        ViewNode(view2, update: { _, _ in })
          .frame(width: 100, height: 100)
        ViewNode(view3, update: { _, _ in })
          .frame(width: 100, height: 100)
      }
    }
    contentView.refresh(animated: false)

    XCTAssertEqual(contentView.subviews, [view1, view2, view3])

    contentView.refresh(animated: false)

    XCTAssertEqual(contentView.subviews, [view1, view2, view3])

    // change the order of the views
    contentView.setContent {
      HorizontalStack {
        ViewNode(view3, update: { _, _ in })
          .frame(width: 100, height: 100)
        ViewNode(view2, update: { _, _ in })
          .frame(width: 100, height: 100)
      }
    }

    contentView.refresh(animated: false)

    XCTAssertEqual(contentView.subviews, [view3, view2])
  }
}
