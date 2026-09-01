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

import ChouTiTest

import ComposeUI

class ComposeNode_ConditionalTests: XCTestCase {

  func test_if() {
    // given: a node factory that conditionally adds a background or an overlay
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

    // when: condition is true
    do {
      var node = makeNode(condition: true)
      node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
      let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))

      // then: the modifier applies and produces two renderable items
      expect(renderableItems.count) == 2
    }

    // when: condition is false
    do {
      var node = makeNode(condition: false)
      node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
      let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))

      // then: the modifier is skipped and produces one renderable item
      expect(renderableItems.count) == 1
    }
  }

  func test_if_sameType() {
    // then: a same-type if chains with other modifiers and the false branch is not called
    _ = LabelNode("")
      .if(true) {
        $0.font(.systemFont(ofSize: 20))
      }
      .if(false) {
        fail("shouldn't call")
        return $0.font(.systemFont(ofSize: 20))
      }
      .lineBreakMode(.byCharWrapping)

    // then: the same holds with the if modifiers applied after other modifiers
    _ = LabelNode("")
      .lineBreakMode(.byCharWrapping)
      .if(true) {
        $0.font(.systemFont(ofSize: 20))
      }
      .if(false) {
        fail("shouldn't call")
        return $0.font(.systemFont(ofSize: 20))
      }
  }

  func test_if_else() {
    // given: a node factory with an if branch and an else branch
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

    // when: condition is true
    do {
      var node = makeNode(condition: true)
      node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
      let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))

      // then: the then branch applies and produces two renderable items
      expect(renderableItems.count) == 2
    }

    // when: condition is false
    do {
      var node = makeNode(condition: false)
      node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
      let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))

      // then: the else branch applies, producing one renderable item with the offset
      expect(renderableItems.count) == 1
      expect(renderableItems[0].frame.origin.x) == 2
    }
  }

  func test_if_else_sameType() {
    // then: a same-type if-else runs only the matching branch when chained before other modifiers
    _ = LabelNode("")
      .if(true, then: {
        $0.font(.systemFont(ofSize: 20))
      }, else: {
        fail("shouldn't call")
        return $0.lineBreakMode(.byCharWrapping)
      })
      .if(false, then: {
        fail("shouldn't call")
        return $0.font(.systemFont(ofSize: 20))
      }, else: {
        $0.lineBreakMode(.byCharWrapping)
      })
      .lineBreakMode(.byCharWrapping)

    // then: the same holds with the if-else modifiers applied after other modifiers
    _ = LabelNode("")
      .lineBreakMode(.byCharWrapping)
      .if(true, then: {
        $0.font(.systemFont(ofSize: 20))
      }, else: {
        fail("shouldn't call")
        return $0.lineBreakMode(.byCharWrapping)
      })
      .if(false, then: {
        fail("shouldn't call")
        return $0.font(.systemFont(ofSize: 20))
      }, else: {
        $0.lineBreakMode(.byCharWrapping)
      })
  }

  // MARK: - ifLet Tests

  func test_ifLet_withValue() {
    // given: a non-nil optional color
    let optionalColor: Color? = .red

    // when: applying ifLet and rendering the node
    var node = ViewNode()
      .ifLet(optionalColor) { node, color in
        expect(color) == .red
        return node.background {
          ColorNode(color)
        }
      }

    node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
    let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))

    // then: the block receives the value and adds the background
    expect(renderableItems.count) == 2 // ViewNode + ColorNode background
  }

  func test_ifLet_withNil() {
    // given: a nil optional color
    let optionalColor: Color? = nil

    // when: applying ifLet and rendering the node
    var node = ViewNode()
      .ifLet(optionalColor) { node, color in
        fail("shouldn't call")
        return node.background {
          ColorNode(color)
        }
      }

    node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
    let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))

    // then: the block is not called and no background is added
    expect(renderableItems.count) == 1 // Only ViewNode, no background
  }

  func test_ifLet_sameType() {
    // then: a same-type ifLet passes the value, skips the nil case, and chains with other modifiers
    _ = LabelNode("")
      .ifLet(20 as CGFloat?) {
        expect($1) == 20
        return $0.font(.systemFont(ofSize: $1))
      }
      .ifLet(nil as CGFloat?) {
        fail("shouldn't call")
        return $0.font(.systemFont(ofSize: $1))
      }
      .lineBreakMode(.byCharWrapping)

    // then: the same holds with the ifLet modifiers applied after other modifiers
    _ = LabelNode("")
      .lineBreakMode(.byCharWrapping)
      .ifLet(20 as CGFloat?) {
        expect($1) == 20
        return $0.font(.systemFont(ofSize: $1))
      }
      .ifLet(nil as CGFloat?) {
        fail("shouldn't call")
        return $0.font(.systemFont(ofSize: $1))
      }
  }

  func test_ifLet_then_else_withValue() {
    // given: a non-nil optional color
    let optionalColor: Color? = .red

    // when: applying ifLet with then and else blocks and rendering the node
    var node = ViewNode()
      .ifLet(optionalColor, then: { node, color in
        expect(color) == .red
        return node.background {
          ColorNode(color)
        }
      }, else: { node in
        fail("shouldn't call")
        return node.background {
          ColorNode(.blue)
        }
      })

    node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
    let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))

    // then: the then block receives the value and adds the red background
    expect(renderableItems.count) == 2 // ViewNode + red background
  }

  func test_ifLet_then_else_withNil() {
    // given: a nil optional color
    let optionalColor: Color? = nil

    // when: applying ifLet with then and else blocks and rendering the node
    var node = ViewNode()
      .ifLet(optionalColor, then: { node, color in
        fail("shouldn't call")
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

    // then: the else block runs and adds the blue background
    expect(renderableItems.count) == 2 // ViewNode + blue background
  }

  func test_ifLet_then_else_sameType() {
    // then: a same-type ifLet then-else runs only the matching block when chained before other modifiers
    _ = LabelNode("")
      .ifLet(20 as CGFloat?, then: {
        expect($1) == 20
        return $0.font(.systemFont(ofSize: $1))
      }, else: {
        fail("shouldn't call")
        return $0.font(.systemFont(ofSize: 10))
      })
      .ifLet(nil as CGFloat?, then: {
        fail("shouldn't call")
        return $0.font(.systemFont(ofSize: $1))
      }, else: {
        return $0.lineBreakMode(.byCharWrapping)
      })
      .lineBreakMode(.byCharWrapping)

    // then: the same holds with the ifLet then-else modifiers applied after other modifiers
    _ = LabelNode("")
      .lineBreakMode(.byCharWrapping)
      .ifLet(20 as CGFloat?, then: {
        expect($1) == 20
        return $0.font(.systemFont(ofSize: $1))
      }, else: {
        fail("shouldn't call")
        return $0.font(.systemFont(ofSize: 10))
      })
      .ifLet(nil as CGFloat?, then: {
        fail("shouldn't call")
        return $0.font(.systemFont(ofSize: $1))
      }, else: {
        return $0.lineBreakMode(.byCharWrapping)
      })
  }
}
