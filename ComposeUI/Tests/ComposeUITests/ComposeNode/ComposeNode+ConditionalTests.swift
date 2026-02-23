//
//  ComposeNode+ConditionalTests.swift
//  ComposéUI
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

import ComposeUI

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
      let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))
      XCTAssertEqual(renderableItems.count, 2)
    }

    // when condition is false
    do {
      var node = makeNode(condition: false)
      node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
      let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))
      XCTAssertEqual(renderableItems.count, 1)
    }
  }

  func test_if_sameType() {
    _ = SpacerNode()
      .if(true) {
        $0.height(10)
      }
      .if(false) {
        XCTFail("shouldn't call")
        return $0.height(20)
      }
      .width(20)

    _ = SpacerNode()
      .width(20)
      .if(true) {
        $0.height(10)
      }
      .if(false) {
        XCTFail("shouldn't call")
        return $0.height(20)
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
      let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))
      XCTAssertEqual(renderableItems.count, 2)
    }

    // when condition is false
    do {
      var node = makeNode(condition: false)
      node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
      let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))
      XCTAssertEqual(renderableItems.count, 1)
      XCTAssertEqual(renderableItems[0].frame.origin.x, 2)
    }
  }

  func test_if_else_sameType() {
    _ = SpacerNode()
      .if(true, then: {
        $0.width(10)
      }, else: {
        XCTFail("shouldn't call")
        return $0.height(20)
      })
      .if(false, then: {
        XCTFail("shouldn't call")
        return $0.height(20)
      }, else: {
        $0.width(10)
      })
      .height(10)

    _ = SpacerNode()
      .height(10)
      .if(true, then: {
        $0.width(10)
      }, else: {
        XCTFail("shouldn't call")
        return $0.height(20)
      })
      .if(false, then: {
        XCTFail("shouldn't call")
        return $0.height(20)
      }, else: {
        $0.width(10)
      })
  }

  // MARK: - ifLet Tests

  func test_ifLet_withValue() {
    let optionalColor: UIColor? = .red

    var node = ViewNode()
      .ifLet(optionalColor) { node, color in
        XCTAssertEqual(color, .red)
        return node.background {
          ColorNode(color)
        }
      }

    node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
    let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))
    XCTAssertEqual(renderableItems.count, 2) // ViewNode + ColorNode background
  }

  func test_ifLet_withNil() {
    let optionalColor: UIColor? = nil

    var node = ViewNode()
      .ifLet(optionalColor) { node, color in
        XCTFail("shouldn't call")
        return node.background {
          ColorNode(color)
        }
      }

    node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
    let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))
    XCTAssertEqual(renderableItems.count, 1) // Only ViewNode, no background
  }

  func test_ifLet_sameType() {
    _ = SpacerNode()
      .ifLet(20 as CGFloat?) {
        XCTAssertEqual($1, 20)
        return $0.width(10)
      }
      .ifLet(nil as CGFloat?) {
        _ = $1
        XCTFail("shouldn't call")
        return $0.height(20)
      }
      .width(10)

    _ = SpacerNode()
      .width(10)
      .ifLet(20 as CGFloat?) {
        XCTAssertEqual($1, 20)
        return $0.width(10)
      }
      .ifLet(nil as CGFloat?) {
        _ = $1
        XCTFail("shouldn't call")
        return $0.height(20)
      }
  }

  func test_ifLet_then_else_withValue() {
    let optionalColor: UIColor? = .red

    var node = ViewNode()
      .ifLet(optionalColor, then: { node, color in
        XCTAssertEqual(color, .red)
        return node.background {
          ColorNode(color)
        }
      }, else: { node in
        XCTFail("shouldn't call")
        return node.background {
          ColorNode(.blue)
        }
      })

    node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
    let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))
    XCTAssertEqual(renderableItems.count, 2) // ViewNode + red background
  }

  func test_ifLet_then_else_withNil() {
    let optionalColor: UIColor? = nil

    var node = ViewNode()
      .ifLet(optionalColor, then: { node, color in
        XCTFail("shouldn't call")
        return node.background {
          ColorNode(color)
        }
      }, else: { node in
        return node.background {
          ColorNode(.blue)
        }
      })

    node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
    let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))
    XCTAssertEqual(renderableItems.count, 2) // ViewNode + blue background
  }

  func test_ifLet_then_else_sameType() {
    _ = SpacerNode()
      .ifLet(20 as CGFloat?, then: {
        XCTAssertEqual($1, 20)
        return $0.width(10)
      }, else: {
        XCTFail("shouldn't call")
        return $0.width(10)
      })
      .ifLet(nil as CGFloat?, then: {
        _ = $1
        XCTFail("shouldn't call")
        return $0.width(10)
      }, else: {
        return $0.width(10)
      })
      .width(10)

    _ = SpacerNode()
      .width(10)
      .ifLet(20 as CGFloat?, then: {
        XCTAssertEqual($1, 20)
        return $0.width(10)
      }, else: {
        XCTFail("shouldn't call")
        return $0.width(10)
      })
      .ifLet(nil as CGFloat?, then: {
        _ = $1
        XCTFail("shouldn't call")
        return $0.width(10)
      }, else: {
        return $0.width(10)
      })
  }
}
