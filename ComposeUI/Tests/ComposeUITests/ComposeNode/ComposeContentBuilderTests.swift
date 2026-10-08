//
//  ComposeContentBuilderTests.swift
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

import QuartzCore

import ChouTiTest

@testable import ComposeUI

class ComposeContentBuilderTests: XCTestCase {

  func test_block_keepsTheNodesInOrder() {
    // when: building a block of nodes
    let ids = Self.nodeIds {
      ColorNode(.red).id("a")
      ColorNode(.red).id("b")
      ColorNode(.red).id("c")
    }

    // then: the nodes are kept in order
    expect(ids) == ["a", "b", "c"]
  }

  func test_emptyBlock_buildsNoNodes() {
    // when: building an empty block
    let ids = Self.nodeIds {}

    // then: there are no nodes
    expect(ids) == []
  }

  func test_ifElse_buildsTheChosenBranchInPlace() {
    for condition in [true, false] {
      // when: building a block with an if-else between two nodes
      let ids = Self.nodeIds {
        ColorNode(.red).id("before")
        if condition {
          ColorNode(.red).id("then")
        } else {
          ColorNode(.red).id("else1")
          ColorNode(.red).id("else2")
        }
        ColorNode(.red).id("after")
      }

      // then: only the chosen branch's nodes are built, where the branch is
      expect(ids) == (condition ? ["before", "then", "after"] : ["before", "else1", "else2", "after"])
    }
  }

  func test_switch_buildsTheMatchingCase() {
    for value in 0 ..< 3 {
      // when: building a block with a switch
      let ids = Self.nodeIds {
        switch value {
        case 0:
          ColorNode(.red).id("zero")
        case 1:
          ColorNode(.red).id("one")
        default:
          ColorNode(.red).id("other")
        }
      }

      // then: only the matching case's node is built
      expect(ids) == [["zero"], ["one"], ["other"]][value]
    }
  }

  func test_ifWithoutElse_buildsItsNodesOnlyWhenTrue() {
    for condition in [true, false] {
      // when: building a block with an if without an else between two nodes
      let ids = Self.nodeIds {
        ColorNode(.red).id("before")
        if condition {
          ColorNode(.red).id("then1")
          ColorNode(.red).id("then2")
        }
        ColorNode(.red).id("after")
      }

      // then: the if's nodes are built only when its condition is true
      expect(ids) == (condition ? ["before", "then1", "then2", "after"] : ["before", "after"])
    }
  }

  func test_forLoop_buildsEachIterationInOrder() {
    for count in [0, 3] {
      // when: building a block with a for loop of two nodes per iteration
      let ids = Self.nodeIds {
        for index in 0 ..< count {
          ColorNode(.red).id("\(index)a")
          ColorNode(.red).id("\(index)b")
        }
      }

      // then: each iteration's nodes are built in order
      expect(ids) == (0 ..< count).flatMap { ["\($0)a", "\($0)b"] }
    }
  }

  func test_arrayExpression_flattensItsContent() {
    // given: an array of a node and an array of two nodes
    let contents: [ComposeContent] = [ColorNode(.red).id("a"), [ColorNode(.red).id("b"), ColorNode(.red).id("c")] as [ComposeNode]]

    // when: building a block with a node and the array
    let ids = Self.nodeIds {
      ColorNode(.red).id("first")
      contents
    }

    // then: the array's content is flattened into nodes after the first node
    expect(ids) == ["first", "a", "b", "c"]
  }

  func test_voidExpression_buildsNoNode() {
    // when: building a block with a statement of type `Void` between two nodes
    var statementCount = 0
    let ids = Self.nodeIds {
      ColorNode(.red).id("a")
      statementCount += 1
      ColorNode(.red).id("b")
    }

    // then: the statement runs but builds no node
    expect(ids) == ["a", "b"]
    expect(statementCount) == 1
  }

  func test_availabilityCheck_buildsTheAvailableBranch() {
    // when: building a block with an availability check that every supported system passes
    let ids = Self.nodeIds {
      if #available(macOS 10.15, iOS 13.0, tvOS 13.0, visionOS 1.0, *) {
        ColorNode(.red).id("available")
      } else {
        ColorNode(.red).id("unavailable")
      }
    }

    // then: the available branch's node is built
    expect(ids) == ["available"]
  }

  func test_nestedControlFlow_flattensInOrder() {
    // when: building a block with an if-else inside a for loop, and a for loop inside the else
    let ids = Self.nodeIds {
      for index in 0 ..< 2 {
        if index == 0 {
          ColorNode(.red).id("first")
        } else {
          for inner in 0 ..< 2 {
            ColorNode(.red).id("inner\(inner)")
          }
        }
      }
    }

    // then: the nodes are flattened in order
    expect(ids) == ["first", "inner0", "inner1"]
  }

  func test_node_isPlacedAsItselfWithoutCallingItsNodesPlumbing() {
    // given: a node type that implements `_nodes()` to stand for two other nodes, which a node type shouldn't
    let state = ExpandingNode.State()

    // when: building a block with the node between two nodes
    let ids = Self.nodeIds {
      ColorNode(.red).id("a")
      ExpandingNode(state: state)
      ColorNode(.red).id("c")
    }

    // then: the node is placed as itself, and its `_nodes()` isn't called
    expect(ids) == ["a", "expanding", "c"]
    expect(state.nodesCallCount) == 0
  }

  func test_contentThatIsNotANode_expandsIntoItsNodesInPlace() {
    // when: building a block with a layer and a content of two nodes that another block built, between two nodes
    let nodes = Self.nodes {
      ColorNode(.red).id("a")
      CALayer()
      Self.twoNodes()
      ColorNode(.red).id("d")
    }

    // then: the layer becomes a layer node, and the content expands into its two nodes, in place
    expect(nodes.count) == 5
    expect(nodes[1] is LayerNode) == true
    expect([nodes[0], nodes[2], nodes[3], nodes[4]].map(\.id.id)) == ["a", "b", "c", "d"]
  }

  func test_buildFinalResult_itemOtherThanABlock_buildsItsContent() {
    // given: a node, and an array of two nodes
    let node = ColorNode(.red).id("a")
    let array: [ComposeNode] = [ColorNode(.red).id("b"), ColorNode(.red).id("c")]

    // when: building items other than a block directly, which a builder block never does
    let single = ComposeContentBuilder.buildFinalResult(.expressionSingle(node))
    let someOptional = ComposeContentBuilder.buildFinalResult(.optional(.expressionSingle(node)))
    let noneOptional = ComposeContentBuilder.buildFinalResult(.optional(nil))
    let expressionArray = ComposeContentBuilder.buildFinalResult(.expressionArray([node, array]))
    let nodeItem = ComposeContentBuilder.buildFinalResult(.node(node))
    let void = ComposeContentBuilder.buildFinalResult(.void)

    // then: a single expression or a node gives itself, an optional gives its item's content, or none, an array
    // expression gives its contents' nodes, and void gives none
    expect((single as? ColorNode)?.id.id) == "a"
    expect((someOptional as? ColorNode)?.id.id) == "a"
    expect(noneOptional.nodes.isEmpty) == true
    expect(expressionArray.nodes.map(\.id.id)) == ["a", "b", "c"]
    expect((nodeItem as? ColorNode)?.id.id) == "a"
    expect(void.nodes.isEmpty) == true
  }

  // MARK: - Helpers

  /// Returns the nodes that the builder makes of the content.
  private static func nodes(@ComposeContentBuilder _ content: () -> ComposeContent) -> [any ComposeNode] {
    content().nodes
  }

  /// Returns the ids of the nodes that the builder makes of the content.
  private static func nodeIds(@ComposeContentBuilder _ content: () -> ComposeContent) -> [String] {
    nodes(content).map(\.id.id)
  }

  /// Returns a content of two color nodes.
  @ComposeContentBuilder
  private static func twoNodes() -> ComposeContent {
    ColorNode(.red).id("b")
    ColorNode(.red).id("c")
  }
}

/// A node that implements `_nodes()` to stand for two color nodes, and tracks the calls to it.
private struct ExpandingNode: ComposeNode {

  final class State {

    /// The number of times `_nodes()` is called.
    var nodesCallCount = 0
  }

  private let state: State

  init(state: State) {
    self.state = state
  }

  // MARK: - ComposeNode

  var id: ComposeNodeId = .custom("expanding")

  let size: CGSize = .zero

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
  }

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    []
  }

  func _nodes() -> [any ComposeNode] {
    state.nodesCallCount += 1
    return [ColorNode(.red).id("b1"), ColorNode(.red).id("b2")]
  }
}
