//
//  ComposeNodeLayoutContextTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/6/26.
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

class ComposeNodeLayoutContextTests: XCTestCase {

  func test_init_onTheMainThread_makesEachContextItsOwnPass() {
    // when: creating two contexts on the main thread
    let first = ComposeNodeLayoutContext(scaleFactor: 2)
    let second = ComposeNodeLayoutContext(scaleFactor: 2)

    // then: each context is a pass of its own
    expect(first.passId) != second.passId
  }

  func test_init_offTheMainThread_asserts() {
    // given: a handler that records the assertion failures
    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: creating a context on a background thread
    let created = XCTestExpectation(description: "created")
    DispatchQueue.global().async {
      _ = ComposeNodeLayoutContext(scaleFactor: 2)
      created.fulfill()
    }
    wait(for: [created], timeout: 5)

    // then: it asserts, since the pass ids are main thread state
    expect(assertionMessages) == ["ComposeNodeLayoutContext must be created on the main thread"]
  }
}
