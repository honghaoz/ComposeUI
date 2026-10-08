//
//  ComposeContentTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/7/26.
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

class ComposeContentTests: XCTestCase {

  func test_asVStack() {
    // given: contents of no node, one node, and two nodes of different widths
    let none = Self.content {}
    let one = Self.content {
      ColorNode(.red).id("a")
    }
    let two = Self.content {
      ColorNode(.red).frame(width: 10, height: 10)
      ColorNode(.red).frame(width: 20, height: 10)
    }

    // when: converting them to vertical stacks, the two nodes aligned to the left, and laying out the two nodes' stack
    let noneNode = none.asVStack()
    let oneNode = one.asVStack()
    var twoNode = two.asVStack(alignment: .left)
    twoNode.layout(containerSize: Constants.containerSize, context: ComposeNodeLayoutContext(scaleFactor: 1))

    // then: no node gives an empty node, one node gives the node itself, and two nodes give a vertical stack of them,
    // with the alignment
    expect(noneNode is EmptyNode) == true
    expect(oneNode is ColorNode) == true
    expect(oneNode.id.id) == "a"
    expect(twoNode is VerticalStackNode) == true
    expect(twoNode.renderableItems(in: Constants.visibleBounds).map(\.frame)) == [
      CGRect(x: 0, y: 0, width: 10, height: 10),
      CGRect(x: 0, y: 10, width: 20, height: 10),
    ]
  }

  func test_asZStack() {
    // given: contents of no node, one node, and two nodes of different sizes
    let none = Self.content {}
    let one = Self.content {
      ColorNode(.red).id("a")
    }
    let two = Self.content {
      ColorNode(.red).frame(width: 10, height: 10)
      ColorNode(.red).frame(width: 20, height: 20)
    }

    // when: converting them to layered stacks, the two nodes aligned to the top left, and laying out the two nodes'
    // stack
    let noneNode = none.asZStack()
    let oneNode = one.asZStack()
    var twoNode = two.asZStack(alignment: .topLeft)
    twoNode.layout(containerSize: Constants.containerSize, context: ComposeNodeLayoutContext(scaleFactor: 1))

    // then: no node gives an empty node, one node gives the node itself, and two nodes give a layered stack of them,
    // with the alignment
    expect(noneNode is EmptyNode) == true
    expect(oneNode is ColorNode) == true
    expect(oneNode.id.id) == "a"
    expect(twoNode is LayeredStackNode) == true
    expect(twoNode.renderableItems(in: Constants.visibleBounds).map(\.frame)) == [
      CGRect(x: 0, y: 0, width: 10, height: 10),
      CGRect(x: 0, y: 0, width: 20, height: 20),
    ]
  }

  // MARK: - Helpers

  /// Returns the content that the builder makes of the block.
  private static func content(@ComposeContentBuilder _ content: () -> ComposeContent) -> ComposeContent {
    content()
  }

  // MARK: - Constants

  private enum Constants {

    /// The container size that the stacks lay out in.
    static let containerSize = CGSize(width: 100, height: 100)

    /// The visible bounds that the stacks' items are queried in.
    static let visibleBounds = CGRect(origin: .zero, size: containerSize)
  }
}
