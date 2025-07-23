//
//  ComposeNode+Conditional.swift
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

public extension ComposeNode {

  /// If the condition is true, then return the result of the then closure. Otherwise, return the original node.
  ///
  /// - Parameters:
  ///   - condition: The condition to check.
  ///   - then: The closure to evaluate if the condition is true.
  /// - Returns: A new node with the result of the then closure if the condition is true, otherwise the original node.
  func `if`(_ condition: Bool, then: (Self) -> any ComposeNode) -> any ComposeNode {
    return condition ? then(self) : self
  }

  /// If the condition is true, then return the result of the then closure. Otherwise, return the original node.
  ///
  /// - Parameters:
  ///   - condition: The condition to check.
  ///   - then: The closure to evaluate if the condition is true.
  /// - Returns: A new node with the result of the then closure if the condition is true, otherwise the original node.
  func `if`(_ condition: Bool, then: (Self) -> Self) -> Self {
    return condition ? then(self) : self
  }

  /// If the condition is true, then return the result of the then closure. Otherwise, return the result of the else closure.
  ///
  /// - Parameters:
  ///   - condition: The condition to check.
  ///   - then: The closure to evaluate if the condition is true.
  ///   - else: The closure to evaluate if the condition is false.
  /// - Returns: A new node with the result of the then closure if the condition is true, otherwise the result of the else closure.
  func `if`(_ condition: Bool, then: (Self) -> any ComposeNode, else: (Self) -> any ComposeNode) -> any ComposeNode {
    condition ? then(self) : `else`(self)
  }

  /// If the condition is true, then return the result of the then closure. Otherwise, return the result of the else closure.
  ///
  /// - Parameters:
  ///   - condition: The condition to check.
  ///   - then: The closure to evaluate if the condition is true.
  ///   - else: The closure to evaluate if the condition is false.
  /// - Returns: A new node with the result of the then closure if the condition is true, otherwise the result of the else closure.
  func `if`(_ condition: Bool, then: (Self) -> Self, else: (Self) -> Self) -> Self {
    condition ? then(self) : `else`(self)
  }

  /// If the optional value is not nil, then return the result of the transform closure with the unwrapped value. Otherwise, return the original node.
  ///
  /// - Parameters:
  ///   - value: The optional value to check.
  ///   - transform: The closure to evaluate if the value is not nil. The closure receives the current node and the unwrapped value.
  /// - Returns: A new node with the result of the transform closure if the value is not nil, otherwise the original node.
  func ifLet<T>(_ value: T?, transform: (Self, T) -> any ComposeNode) -> any ComposeNode {
    if let value {
      return transform(self, value)
    } else {
      return self
    }
  }

  /// If the optional value is not nil, then return the result of the transform closure with the unwrapped value. Otherwise, return the original node.
  ///
  /// - Parameters:
  ///   - value: The optional value to check.
  ///   - transform: The closure to evaluate if the value is not nil. The closure receives the current node and the unwrapped value.
  /// - Returns: A new node with the result of the transform closure if the value is not nil, otherwise the original node.
  func ifLet<T>(_ value: T?, transform: (Self, T) -> Self) -> Self {
    if let value {
      return transform(self, value)
    } else {
      return self
    }
  }

  /// If the optional value is not nil, then return the result of the then closure with the unwrapped value. Otherwise, return the result of the else closure.
  ///
  /// - Parameters:
  ///   - value: The optional value to check.
  ///   - then: The closure to evaluate if the value is not nil. The closure receives the current node and the unwrapped value.
  ///   - else: The closure to evaluate if the value is nil. The closure receives the current node.
  /// - Returns: A new node with the result of the then closure if the value is not nil, otherwise the result of the else closure.
  func ifLet<T>(_ value: T?, then: (Self, T) -> any ComposeNode, else: (Self) -> any ComposeNode) -> any ComposeNode {
    if let value {
      return then(self, value)
    } else {
      return `else`(self)
    }
  }

  /// If the optional value is not nil, then return the result of the then closure with the unwrapped value. Otherwise, return the result of the else closure.
  ///
  /// - Parameters:
  ///   - value: The optional value to check.
  ///   - then: The closure to evaluate if the value is not nil. The closure receives the current node and the unwrapped value.
  ///   - else: The closure to evaluate if the value is nil. The closure receives the current node.
  /// - Returns: A new node with the result of the then closure if the value is not nil, otherwise the result of the else closure.
  func ifLet<T>(_ value: T?, then: (Self, T) -> Self, else: (Self) -> Self) -> Self {
    if let value {
      return then(self, value)
    } else {
      return `else`(self)
    }
  }
}
