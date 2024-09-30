//
//  ComposeContentBuilder.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import Foundation

@resultBuilder
public enum ComposeContentBuilder {

  public indirect enum Item<Expression> {
    case array([Item])
    case optional(Item?)
    case expressionSingle(Expression)
    case expressionArray([Expression])
    case void
  }

  /// For a list of statements.
  public static func buildBlock(_ items: Item<ComposeContent>...) -> Item<ComposeContent> {
    .array(items)
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
      return items.flatMap {
        buildFinalResult($0).asNodes()
      }
    case .optional(let item?):
      return buildFinalResult(item)
    case .optional(nil):
      return []
    case .expressionSingle(let input):
      return input
    case .expressionArray(let inputArray):
      return inputArray.flatMap {
        $0.asNodes()
      }
    case .void:
      return []
    }
  }
}
