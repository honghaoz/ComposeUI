//
//  ViewNodeTests.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
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
import ComposeUI

class ViewNodeTests: XCTestCase {

  func test_fixedSize() {
    do {
      // when using view factory
      var node = ViewNode()

      // then the size is flexible
      XCTAssertEqual(node.isFixedWidth, false)
      XCTAssertEqual(node.isFixedHeight, false)

      // when set fixed size
      node = node.fixed()

      // then the size is fixed
      XCTAssertEqual(node.isFixedWidth, true)
      XCTAssertEqual(node.isFixedHeight, true)
    }

    do {
      // when using external view
      var node = ViewNode(View())

      // then the size is fixed
      XCTAssertEqual(node.isFixedWidth, true)
      XCTAssertEqual(node.isFixedHeight, true)

      // when set flexible size
      node = node.flexible()

      // then the size is flexible
      XCTAssertEqual(node.isFixedWidth, false)
      XCTAssertEqual(node.isFixedHeight, false)
    }
  }
}
