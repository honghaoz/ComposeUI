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
    contentView = ComposeView()
  }

  func test_view_lifecycle() {
    var willInsertCount = 0
    var didInsertCount = 0
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
    XCTAssertEqual(updateCount, 1)
    XCTAssertEqual(willRemoveCount, 1)
    XCTAssertEqual(didRemoveCount, 1)
  }
}
