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

  func test_blockOfEachSize_keepsTheNodesInOrder() {
    // when: building blocks of one to ten statements, which have an overload each, and of eleven, which doesn't
    let blocks = [
      Self.nodeIds {
        Self.node(0)
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        Self.node(2)
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        Self.node(2)
        Self.node(3)
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        Self.node(2)
        Self.node(3)
        Self.node(4)
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        Self.node(2)
        Self.node(3)
        Self.node(4)
        Self.node(5)
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        Self.node(2)
        Self.node(3)
        Self.node(4)
        Self.node(5)
        Self.node(6)
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        Self.node(2)
        Self.node(3)
        Self.node(4)
        Self.node(5)
        Self.node(6)
        Self.node(7)
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        Self.node(2)
        Self.node(3)
        Self.node(4)
        Self.node(5)
        Self.node(6)
        Self.node(7)
        Self.node(8)
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        Self.node(2)
        Self.node(3)
        Self.node(4)
        Self.node(5)
        Self.node(6)
        Self.node(7)
        Self.node(8)
        Self.node(9)
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        Self.node(2)
        Self.node(3)
        Self.node(4)
        Self.node(5)
        Self.node(6)
        Self.node(7)
        Self.node(8)
        Self.node(9)
        Self.node(10)
      },
    ]

    // then: each block keeps its nodes in order
    expect(blocks) == (1 ... 11).map { count in
      (0 ..< count).map { "\($0)" }
    }
  }

  func test_blockOfEachSize_withAStatementThatIsNotANode_keepsTheNodesInOrder() {
    // given: a true condition, so that an if statement adds its two nodes
    let condition = true

    // when: building blocks of two to ten statements, whose last statement is an if statement instead of a node
    let blocks = [
      Self.nodeIds {
        Self.node(0)
        if condition {
          Self.node(1)
          Self.node(2)
        }
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        if condition {
          Self.node(2)
          Self.node(3)
        }
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        Self.node(2)
        if condition {
          Self.node(3)
          Self.node(4)
        }
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        Self.node(2)
        Self.node(3)
        if condition {
          Self.node(4)
          Self.node(5)
        }
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        Self.node(2)
        Self.node(3)
        Self.node(4)
        if condition {
          Self.node(5)
          Self.node(6)
        }
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        Self.node(2)
        Self.node(3)
        Self.node(4)
        Self.node(5)
        if condition {
          Self.node(6)
          Self.node(7)
        }
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        Self.node(2)
        Self.node(3)
        Self.node(4)
        Self.node(5)
        Self.node(6)
        if condition {
          Self.node(7)
          Self.node(8)
        }
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        Self.node(2)
        Self.node(3)
        Self.node(4)
        Self.node(5)
        Self.node(6)
        Self.node(7)
        if condition {
          Self.node(8)
          Self.node(9)
        }
      },
      Self.nodeIds {
        Self.node(0)
        Self.node(1)
        Self.node(2)
        Self.node(3)
        Self.node(4)
        Self.node(5)
        Self.node(6)
        Self.node(7)
        Self.node(8)
        if condition {
          Self.node(9)
          Self.node(10)
        }
      },
    ]

    // then: each block keeps its nodes in order, including the two nodes of its if statement
    expect(blocks) == (2 ... 10).map { count in
      (0 ... count).map { "\($0)" }
    }
  }

  func test_blockOfEachSize_withoutNodes_buildsNoNodesWithoutAllocating() {
    // given: bodies that build blocks of two to ten statements, which have an overload each, and of eleven, which
    // doesn't, whose statements count up a counter and make no nodes, each run once already, since a first run can also
    // allocate what the runtime makes on first use
    var count = 0
    let bodies: [() -> ComposeContent] = [
      {
        Self.content {
          count += 1
          count += 1
        }
      },
      {
        Self.content {
          count += 1
          count += 1
          count += 1
        }
      },
      {
        Self.content {
          count += 1
          count += 1
          count += 1
          count += 1
        }
      },
      {
        Self.content {
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
        }
      },
      {
        Self.content {
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
        }
      },
      {
        Self.content {
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
        }
      },
      {
        Self.content {
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
        }
      },
      {
        Self.content {
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
        }
      },
      {
        Self.content {
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
        }
      },
      {
        Self.content {
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
          count += 1
        }
      },
    ]
    let nodeCounts = bodies.map { $0().nodes.count }
    count = 0

    // when: counting the allocations of each body
    let allocations = bodies.map { body in
      AllocationCounter.count {
        _ = body()
      }
    }

    // then: each block runs its statements and builds no nodes, without a buffer for them
    expect(nodeCounts) == Array(repeating: 0, count: 10)
    expect(count) == (2 ... 11).reduce(0, +)
    expect(allocations) == Array(repeating: 0, count: 10)
  }

  func test_emptyContent_takesNoBuffer() {
    // given: bodies that build stacks of empty content: no statements, an `if` whose condition is false and a loop with
    // no iterations, each run once already, since a first run can also allocate what the runtime makes on first use
    let condition = false
    let empty: [Int] = []
    let bodies: [() -> Void] = [
      { _ = VStack {} },
      { _ = HStack {} },
      { _ = ZStack {} },
      {
        _ = VStack {
          if condition {
            ColorNode(.red)
          }
        }
      },
      {
        _ = VStack {
          for _ in empty {
            ColorNode(.red)
          }
        }
      },
    ]
    for body in bodies {
      body()
    }

    // when: counting the allocations of each body
    let allocations = bodies.map { AllocationCounter.count($0) }

    // then: none allocates, since empty content shares the empty buffer
    expect(allocations) == Array(repeating: 0, count: bodies.count)
  }

  func test_emptyContentInABlock_takesNoRoom() {
    // given: the content of a loop with no iterations, which shares the empty buffer
    let empty: [Int] = []
    let emptyContent = Self.content {
      for _ in empty {
        ColorNode(.red)
      }
    }

    // when: making the content's component, as a block that holds the content does
    let component = ComposeContentBuilder.buildExpression(emptyContent)

    // then: it has no nodes, and adds no bytes to the block's buffer
    expect(component.nodeCount) == 0
    expect(component.valuesByteCount) == 0
  }

  func test_arrayExpressionOfBlocks_keepsTheirNodesInOrder() {
    // given: an array of the contents of a block of two nodes and of a block of four nodes
    let blocks: [ComposeContent] = [Self.twoNodes(), Self.fourNodes()]

    // when: building a block of the array between two nodes
    let ids = Self.nodeIds {
      ColorNode(.red).id("a")
      blocks
      ColorNode(.red).id("f")
    }

    // then: each block's nodes are placed in order, where the array is
    expect(ids) == ["a", "b", "c", "b", "c", "d", "e", "f"]
  }

  func test_blockContentWrittenTwice_asserts() {
    // given: the content of a block of two nodes, which holds the nodes it wrote, and a test assertion failure handler
    let content = ComposeContentBuilder.buildBlock(
      ComposeContentBuilder.buildExpression(ColorNode(.red).id("a")),
      ComposeContentBuilder.buildExpression(ColorNode(.red).id("b"))
    )
    var messages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      messages.append(message)
    }

    // when: writing the content in a block twice, which the builder never does
    _ = ComposeContentBuilder.buildBlock(content, content)

    // then: the second write asserts, since the first moved the nodes
    expect(messages) == ["a block's content is written once, since writing it moves its nodes"]

    // when: reading the content after it's written
    _ = ComposeContentBuilder.buildFinalResult(content)

    // then: the read asserts too
    expect(messages.count) == 2

    Assert.resetTestAssertionFailureHandler()
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

    // when: building a block with the node between two nodes, and a block of only the node
    let ids = Self.nodeIds {
      ColorNode(.red).id("a")
      ExpandingNode(state: state)
      ColorNode(.red).id("c")
    }
    let onlyIds = Self.nodeIds {
      ExpandingNode(state: state)
    }

    // then: the node is placed as itself, and its `_nodes()` isn't called
    expect(ids) == ["a", "expanding", "c"]
    expect(onlyIds) == ["expanding"]
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

  func test_blockOfOneStatement_buildsItsContent() {
    // when: building blocks of one statement each: a layer, content that another block built, an `if` without `else`
    // whose condition is false, a loop, and a node in a box
    let condition = false
    let boxedNode: any ComposeNode = ColorNode(.red).id("boxed")
    let layerNodes = Self.nodes {
      CALayer()
    }
    let contentIds = Self.nodeIds {
      Self.twoNodes()
    }
    let falseIfIds = Self.nodeIds {
      if condition {
        ColorNode(.red).id("never")
      }
    }
    let loopIds = Self.nodeIds {
      for index in 0 ..< 3 {
        ColorNode(.red).id("\(index)")
      }
    }
    let boxedIds = Self.nodeIds {
      boxedNode
    }

    // then: each block builds its statement's nodes
    expect(layerNodes.count) == 1
    expect(layerNodes.first is LayerNode) == true
    expect(contentIds) == ["b", "c"]
    expect(falseIfIds) == []
    expect(loopIds) == ["0", "1", "2"]
    expect(boxedIds) == ["boxed"]
  }

  func test_boxedNode_isPlacedAsItselfWithoutCallingItsNodesPlumbing() {
    // given: a node in a box, as a variable of type `any ComposeNode` keeps it, of a type that implements `_nodes()` to
    // stand for two other nodes, which a node type shouldn't
    let state = ExpandingNode.State()
    let boxedNode: any ComposeNode = ExpandingNode(state: state)

    // when: building a block with the boxed node between two nodes, a block of only the boxed node, and a loop of it
    let ids = Self.nodeIds {
      ColorNode(.red).id("a")
      boxedNode
      ColorNode(.red).id("c")
    }
    let onlyIds = Self.nodeIds {
      boxedNode
    }
    let loopIds = Self.nodeIds {
      for _ in 0 ..< 2 {
        boxedNode
      }
    }

    // then: the node is placed as itself, in place, and its `_nodes()` isn't called
    expect(ids) == ["a", "expanding", "c"]
    expect(onlyIds) == ["expanding"]
    expect(loopIds) == ["expanding", "expanding"]
    expect(state.nodesCallCount) == 0
  }

  func test_boxedNodeFromAnOverloadedCall_isPlacedInPlace() {
    // when: building a block with a node that a call of an overloaded method returns in a box, between two nodes
    let ids = Self.nodeIds {
      ColorNode(.red).id("a")
      ColorNode(.red).frame(width: .flexible, height: .flexible).id("b")
      ColorNode(.red).id("c")
    }

    // then: the boxed node is placed in place
    expect(ids) == ["a", "b", "c"]
  }

  func test_bodiesOfSeveralStatements_keepTheNodesInOrder() {
    // when: building a block with a loop and an if-else whose bodies have two statements each
    let condition = true
    let ids = Self.nodeIds {
      for index in 0 ..< 2 {
        ColorNode(.red).id("\(index)a")
        ColorNode(.red).id("\(index)b")
      }
      if condition {
        ColorNode(.red).id("c")
        ColorNode(.red).id("d")
      } else {
        ColorNode(.red).id("never")
      }
    }

    // then: the bodies' nodes are in order
    expect(ids) == ["0a", "0b", "1a", "1b", "c", "d"]
  }

  func test_nodesThatABodyWrote_areDestroyedOnce() {
    // given: objects for nodes to keep
    var objects: [Token]? = [Token(), Token(), Token(), Token()]
    let weakObjects = objects!.map { WeakToken(token: $0) } // swiftlint:disable:this force_unwrapping

    // when: building content of a loop whose body writes two nodes that keep the objects, which the block moves
    var content: ComposeContent? = Self.content {
      for index in 0 ..< 2 {
        TokenNode(token: objects![index * 2]) // swiftlint:disable:this force_unwrapping
        TokenNode(token: objects![index * 2 + 1]) // swiftlint:disable:this force_unwrapping
      }
    }
    objects = nil

    // then: the content keeps the objects
    expect(content?.nodes.count) == 4
    expect(weakObjects.allSatisfy { $0.token != nil }) == true

    // when: releasing the content
    content = nil

    // then: each node is destroyed, which releases its object
    expect(weakObjects.allSatisfy { $0.token == nil }) == true
  }

  // MARK: - Helpers

  /// Returns the content that the builder makes.
  private static func content(@ComposeContentBuilder _ content: () -> ComposeContent) -> ComposeContent {
    content()
  }

  /// Returns the nodes that the builder makes of the content.
  private static func nodes(@ComposeContentBuilder _ content: () -> ComposeContent) -> [any ComposeNode] {
    content().nodes
  }

  /// Returns the ids of the nodes that the builder makes of the content.
  private static func nodeIds(@ComposeContentBuilder _ content: () -> ComposeContent) -> [String] {
    nodes(content).map(\.id.id)
  }

  /// Returns a color node with the index as its id.
  private static func node(_ index: Int) -> some ComposeNode {
    ColorNode(.red).id("\(index)")
  }

  /// Returns a content of two color nodes.
  @ComposeContentBuilder
  private static func twoNodes() -> ComposeContent {
    ColorNode(.red).id("b")
    ColorNode(.red).id("c")
  }

  /// Returns a content of four color nodes.
  @ComposeContentBuilder
  private static func fourNodes() -> ComposeContent {
    ColorNode(.red).id("b")
    ColorNode(.red).id("c")
    ColorNode(.red).id("d")
    ColorNode(.red).id("e")
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

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {}

  func _nodes() -> [any ComposeNode] {
    state.nodesCallCount += 1
    return [ColorNode(.red).id("b1"), ColorNode(.red).id("b2")]
  }
}

/// An object that a test node keeps, to tell when the node is destroyed.
private final class Token {}

private struct WeakToken {

  weak var token: Token?
}

/// A node that keeps an object.
private struct TokenNode: ComposeNode {

  let token: Token

  var id: ComposeNodeId = .custom("token")

  var size: CGSize {
    .zero
  }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {}
}
