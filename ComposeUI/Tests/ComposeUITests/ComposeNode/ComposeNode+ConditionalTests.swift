//
//  ComposeNode+ConditionalTests.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 11/5/24.
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

class ComposeNode_ConditionalTests: XCTestCase {

  func test_if() {
    func makeNode(condition: Bool) -> any ComposeNode {
      ViewNode()
        .if(condition) {
          if Bool.random() { // test return "any ComposeNode"
            return $0.background {
              ColorNode(.red)
            }
          } else {
            return $0.overlay {
              ColorNode(.blue)
            }
          }
        }
    }

    // when condition is true
    do {
      var node = makeNode(condition: true)
      node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
      let viewItems = node.viewItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))
      XCTAssert(viewItems.count == 2)
    }

    // when condition is false
    do {
      var node = makeNode(condition: false)
      node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
      let viewItems = node.viewItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))
      XCTAssert(viewItems.count == 1)
    }
  }

  func test_if_else() {
    func makeNode(condition: Bool) -> any ComposeNode {
      ViewNode()
        .if(condition) {
          if Bool.random() { // test return "any ComposeNode"
            return $0.background {
              ColorNode(.red)
            }
          } else {
            return $0.overlay {
              ColorNode(.blue)
            }
          }
        } else: {
          if condition { // test return "any ComposeNode"
            return $0.padding(4)
          } else {
            return $0.offset(x: 2)
          }
        }
    }

    // when condition is true
    do {
      var node = makeNode(condition: true)
      node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
      let viewItems = node.viewItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))
      XCTAssert(viewItems.count == 2)
    }

    // when condition is false
    do {
      var node = makeNode(condition: false)
      node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
      let viewItems = node.viewItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))
      XCTAssert(viewItems.count == 1)
      XCTAssert(viewItems[0].frame.origin.x == 2)
    }
  }
}
