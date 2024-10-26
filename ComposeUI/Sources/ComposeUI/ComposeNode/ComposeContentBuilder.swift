//
//  ComposeContentBuilder.swift
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

import Foundation

/// A builder to compose the compose content.
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
