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

import XCTest
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
    XCTAssertEqual(refreshCount, 1)

    contentView.setNeedsRefresh(animated: false)
    contentView.setNeedsRefresh(animated: false)
    XCTAssertEqual(refreshCount, 1)

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-9))
    XCTAssertEqual(refreshCount, 2)
  }

  func test_centerContent() {
    // when content size is smaller than the bounds size
    do {
      let view = BaseView()
      contentView.setContent {
        ViewNode(view)
          .flexible()
          .frame(width: 50, height: 80)
      }
      contentView.refresh(animated: false)

      XCTAssertEqual(contentView.contentSize, CGSize(width: 100, height: 100))
      XCTAssertEqual(view.frame, CGRect(x: 25, y: 10, width: 50, height: 80))
    }

    // when content width is smaller than the bounds width
    do {
      let view = BaseView()
      contentView.setContent {
        ViewNode(view)
          .flexible()
          .frame(width: 50, height: 120)
      }
      contentView.refresh(animated: false)

      XCTAssertEqual(contentView.contentSize, CGSize(width: 100, height: 120))
      XCTAssertEqual(view.frame, CGRect(x: 25, y: 0, width: 50, height: 120))
    }

    // when content height is smaller than the bounds height
    do {
      let view = BaseView()
      contentView.setContent {
        ViewNode(view)
          .flexible()
          .frame(width: 120, height: 80)
      }
      contentView.refresh(animated: false)

      XCTAssertEqual(contentView.contentSize, CGSize(width: 120, height: 100))
      XCTAssertEqual(view.frame, CGRect(x: 0, y: 10, width: 120, height: 80))
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
      XCTAssertFalse(contentView.isScrollable)

      // when isScrollable is set explicitly
      contentView.isScrollable = true
      contentView.refresh(animated: false)
      XCTAssertTrue(contentView.isScrollable)

      // when isScrollable is set explicitly
      contentView.isScrollable = false
      contentView.refresh(animated: false)
      XCTAssertFalse(contentView.isScrollable)
    }

    // when content size is equal to bounds size
    do {
      contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 100, height: 100)
      }
      contentView.refresh(animated: false)
      XCTAssertFalse(contentView.isScrollable)

      // when isScrollable is set explicitly
      contentView.isScrollable = true
      contentView.refresh(animated: false)
      XCTAssertTrue(contentView.isScrollable)

      // when isScrollable is set explicitly
      contentView.isScrollable = false
      contentView.refresh(animated: false)
      XCTAssertFalse(contentView.isScrollable)
    }

    // when content size is larger than bounds size
    do {
      contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 150, height: 150)
      }
      contentView.refresh(animated: false)
      XCTAssertTrue(contentView.isScrollable)

      // when isScrollable is set explicitly
      contentView.isScrollable = false
      contentView.refresh(animated: false)
      XCTAssertFalse(contentView.isScrollable)

      // when isScrollable is set explicitly
      contentView.isScrollable = true
      contentView.refresh(animated: false)
      XCTAssertTrue(contentView.isScrollable)
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

    XCTAssertEqual(willInsertCount, 1)
    XCTAssertEqual(didInsertCount, 1)
    XCTAssertEqual(updateCount, 1)
    XCTAssertEqual(willRemoveCount, 0)
    XCTAssertEqual(didRemoveCount, 0)

    // remove view
    contentView.setContent {
      Empty()
    }

    contentView.refresh(animated: false)

    XCTAssertEqual(willInsertCount, 1)
    XCTAssertEqual(didInsertCount, 1)
    XCTAssertEqual(willUpdateCount, 1)
    XCTAssertEqual(updateCount, 1)
    XCTAssertEqual(willRemoveCount, 1)
    XCTAssertEqual(didRemoveCount, 1)
  }
}
