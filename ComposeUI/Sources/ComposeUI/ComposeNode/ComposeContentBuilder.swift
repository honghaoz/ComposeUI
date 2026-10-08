//
//  ComposeContentBuilder.swift
//  ComposéUI
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

import Foundation

/// A builder to compose the compose content.
@resultBuilder
public enum ComposeContentBuilder {

  public enum Item<Expression> {

    case array([Item])

    // indirect on this case instead of the enum: it's the only case that holds an item inline, and an indirect enum
    // puts every item, one for each expression in a block, in its own heap allocation
    indirect case optional(Item?)

    case expressionSingle(Expression)

    case expressionArray([Expression])

    case node(any ComposeNode)

    case nodes([any ComposeNode])

    case void
  }

  /// For a block of no statements, or more than ten.
  public static func buildBlock(_ items: Item<ComposeContent>...) -> Item<ComposeContent> {
    .array(items)
  }

  // A refresh builds every block again, so a block of up to ten statements has an overload of its own, which builds its
  // nodes without the array of items that the variadic overload takes.

  /// For a block of one statement.
  public static func buildBlock(_ item: Item<ComposeContent>) -> Item<ComposeContent> {
    item
  }

  /// For a block of two statements.
  public static func buildBlock(_ item0: Item<ComposeContent>,
                                _ item1: Item<ComposeContent>) -> Item<ComposeContent>
  {
    var nodes: [any ComposeNode] = []
    nodes.reserveCapacity(2)
    appendNodes(of: item0, to: &nodes)
    appendNodes(of: item1, to: &nodes)
    return .nodes(nodes)
  }

  /// For a block of three statements.
  public static func buildBlock(_ item0: Item<ComposeContent>,
                                _ item1: Item<ComposeContent>,
                                _ item2: Item<ComposeContent>) -> Item<ComposeContent>
  {
    var nodes: [any ComposeNode] = []
    nodes.reserveCapacity(3)
    appendNodes(of: item0, to: &nodes)
    appendNodes(of: item1, to: &nodes)
    appendNodes(of: item2, to: &nodes)
    return .nodes(nodes)
  }

  /// For a block of four statements.
  public static func buildBlock(_ item0: Item<ComposeContent>,
                                _ item1: Item<ComposeContent>,
                                _ item2: Item<ComposeContent>,
                                _ item3: Item<ComposeContent>) -> Item<ComposeContent>
  {
    var nodes: [any ComposeNode] = []
    nodes.reserveCapacity(4)
    appendNodes(of: item0, to: &nodes)
    appendNodes(of: item1, to: &nodes)
    appendNodes(of: item2, to: &nodes)
    appendNodes(of: item3, to: &nodes)
    return .nodes(nodes)
  }

  /// For a block of five statements.
  public static func buildBlock(_ item0: Item<ComposeContent>,
                                _ item1: Item<ComposeContent>,
                                _ item2: Item<ComposeContent>,
                                _ item3: Item<ComposeContent>,
                                _ item4: Item<ComposeContent>) -> Item<ComposeContent>
  {
    var nodes: [any ComposeNode] = []
    nodes.reserveCapacity(5)
    appendNodes(of: item0, to: &nodes)
    appendNodes(of: item1, to: &nodes)
    appendNodes(of: item2, to: &nodes)
    appendNodes(of: item3, to: &nodes)
    appendNodes(of: item4, to: &nodes)
    return .nodes(nodes)
  }

  /// For a block of six statements.
  public static func buildBlock(_ item0: Item<ComposeContent>,
                                _ item1: Item<ComposeContent>,
                                _ item2: Item<ComposeContent>,
                                _ item3: Item<ComposeContent>,
                                _ item4: Item<ComposeContent>,
                                _ item5: Item<ComposeContent>) -> Item<ComposeContent>
  {
    var nodes: [any ComposeNode] = []
    nodes.reserveCapacity(6)
    appendNodes(of: item0, to: &nodes)
    appendNodes(of: item1, to: &nodes)
    appendNodes(of: item2, to: &nodes)
    appendNodes(of: item3, to: &nodes)
    appendNodes(of: item4, to: &nodes)
    appendNodes(of: item5, to: &nodes)
    return .nodes(nodes)
  }

  /// For a block of seven statements.
  public static func buildBlock(_ item0: Item<ComposeContent>,
                                _ item1: Item<ComposeContent>,
                                _ item2: Item<ComposeContent>,
                                _ item3: Item<ComposeContent>,
                                _ item4: Item<ComposeContent>,
                                _ item5: Item<ComposeContent>,
                                _ item6: Item<ComposeContent>) -> Item<ComposeContent>
  {
    var nodes: [any ComposeNode] = []
    nodes.reserveCapacity(7)
    appendNodes(of: item0, to: &nodes)
    appendNodes(of: item1, to: &nodes)
    appendNodes(of: item2, to: &nodes)
    appendNodes(of: item3, to: &nodes)
    appendNodes(of: item4, to: &nodes)
    appendNodes(of: item5, to: &nodes)
    appendNodes(of: item6, to: &nodes)
    return .nodes(nodes)
  }

  /// For a block of eight statements.
  public static func buildBlock(_ item0: Item<ComposeContent>,
                                _ item1: Item<ComposeContent>,
                                _ item2: Item<ComposeContent>,
                                _ item3: Item<ComposeContent>,
                                _ item4: Item<ComposeContent>,
                                _ item5: Item<ComposeContent>,
                                _ item6: Item<ComposeContent>,
                                _ item7: Item<ComposeContent>) -> Item<ComposeContent>
  {
    var nodes: [any ComposeNode] = []
    nodes.reserveCapacity(8)
    appendNodes(of: item0, to: &nodes)
    appendNodes(of: item1, to: &nodes)
    appendNodes(of: item2, to: &nodes)
    appendNodes(of: item3, to: &nodes)
    appendNodes(of: item4, to: &nodes)
    appendNodes(of: item5, to: &nodes)
    appendNodes(of: item6, to: &nodes)
    appendNodes(of: item7, to: &nodes)
    return .nodes(nodes)
  }

  /// For a block of nine statements.
  public static func buildBlock(_ item0: Item<ComposeContent>,
                                _ item1: Item<ComposeContent>,
                                _ item2: Item<ComposeContent>,
                                _ item3: Item<ComposeContent>,
                                _ item4: Item<ComposeContent>,
                                _ item5: Item<ComposeContent>,
                                _ item6: Item<ComposeContent>,
                                _ item7: Item<ComposeContent>,
                                _ item8: Item<ComposeContent>) -> Item<ComposeContent>
  {
    var nodes: [any ComposeNode] = []
    nodes.reserveCapacity(9)
    appendNodes(of: item0, to: &nodes)
    appendNodes(of: item1, to: &nodes)
    appendNodes(of: item2, to: &nodes)
    appendNodes(of: item3, to: &nodes)
    appendNodes(of: item4, to: &nodes)
    appendNodes(of: item5, to: &nodes)
    appendNodes(of: item6, to: &nodes)
    appendNodes(of: item7, to: &nodes)
    appendNodes(of: item8, to: &nodes)
    return .nodes(nodes)
  }

  /// For a block of ten statements.
  public static func buildBlock(_ item0: Item<ComposeContent>,
                                _ item1: Item<ComposeContent>,
                                _ item2: Item<ComposeContent>,
                                _ item3: Item<ComposeContent>,
                                _ item4: Item<ComposeContent>,
                                _ item5: Item<ComposeContent>,
                                _ item6: Item<ComposeContent>,
                                _ item7: Item<ComposeContent>,
                                _ item8: Item<ComposeContent>,
                                _ item9: Item<ComposeContent>) -> Item<ComposeContent>
  {
    var nodes: [any ComposeNode] = []
    nodes.reserveCapacity(10)
    appendNodes(of: item0, to: &nodes)
    appendNodes(of: item1, to: &nodes)
    appendNodes(of: item2, to: &nodes)
    appendNodes(of: item3, to: &nodes)
    appendNodes(of: item4, to: &nodes)
    appendNodes(of: item5, to: &nodes)
    appendNodes(of: item6, to: &nodes)
    appendNodes(of: item7, to: &nodes)
    appendNodes(of: item8, to: &nodes)
    appendNodes(of: item9, to: &nodes)
    return .nodes(nodes)
  }

  /// For `if`/`else`/`switch` statements.
  public static func buildEither(first: Item<ComposeContent>) -> Item<ComposeContent> {
    first
  }

  /// For `if`/`else`/`switch` statements.
  public static func buildEither(second: Item<ComposeContent>) -> Item<ComposeContent> {
    second
  }

  /// For `if` only (without `else`) statements.
  public static func buildOptional(_ item: Item<ComposeContent>?) -> Item<ComposeContent> {
    .optional(item)
  }

  /// For `for` loop.
  public static func buildArray(_ items: [Item<ComposeContent>]) -> Item<ComposeContent> {
    .array(items)
  }

  /// For `#available` statements.
  public static func buildLimitedAvailability(_ item: Item<ComposeContent>) -> Item<ComposeContent> {
    item
  }

  /// For a single expression.
  public static func buildExpression(_ expression: ComposeContent) -> Item<ComposeContent> {
    .expressionSingle(expression)
  }

  /// For a node, which the block places as itself.
  public static func buildExpression(_ node: any ComposeNode) -> Item<ComposeContent> {
    // a node is boxed once, as a node, instead of as content and then again in the array its `_nodes()` returns
    .node(node)
  }

  /// For an array of expressions.
  public static func buildExpression(_ expression: [ComposeContent]) -> Item<ComposeContent> {
    .expressionArray(expression)
  }

  /// For a void expression.
  public static func buildExpression(_ expression: Void) -> Item<ComposeContent> {
    .void
  }

  public static func buildFinalResult(_ item: Item<ComposeContent>) -> ComposeContent {
    switch item {
    case .array(let items):
      // a refresh builds every block again, so the nested items are flattened into one array, instead of an array for
      // each item, joined into the block's
      var nodes: [any ComposeNode] = []
      nodes.reserveCapacity(items.count)
      for item in items {
        appendNodes(of: item, to: &nodes)
      }
      return nodes
    case .optional(let item?):
      return buildFinalResult(item)
    case .optional(nil):
      return []
    case .expressionSingle(let input):
      return input
    case .expressionArray(let inputArray):
      return inputArray.flatMap(\.nodes)
    case .node(let node):
      // an array of the node, instead of the node, so a container reads the node without its `_nodes()` boxing it again
      return [node]
    case .nodes(let nodes):
      return nodes
    case .void:
      return []
    }
  }

  /// Appends the nodes of an item to the array, in order.
  private static func appendNodes(of item: Item<ComposeContent>, to nodes: inout [any ComposeNode]) {
    switch item {
    case .array(let items):
      for item in items {
        appendNodes(of: item, to: &nodes)
      }
    case .optional(let item?):
      appendNodes(of: item, to: &nodes)
    case .optional(nil),
         .void:
      break
    case .expressionSingle(let input):
      nodes.append(contentsOf: input.nodes)
    case .expressionArray(let inputArray):
      for input in inputArray {
        nodes.append(contentsOf: input.nodes)
      }
    case .node(let node):
      nodes.append(node)
    case .nodes(let blockNodes):
      nodes.append(contentsOf: blockNodes)
    }
  }
}
