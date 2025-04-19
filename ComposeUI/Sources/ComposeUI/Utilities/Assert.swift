//
//  Assert.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/18/25.
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

@inlinable
@inline(__always)
func assert(_ condition: @autoclosure () -> Bool,
            _ message: @autoclosure () -> String = String(),
            file: StaticString = #fileID,
            line: UInt = #line,
            column: UInt = #column,
            function: StaticString = #function)
{
  #if DEBUG
  if !condition() {
    assertFailure(message(), file: file, line: line, column: column, function: function)
  }
  #endif
}

@inlinable
@inline(__always)
func assertFailure(_ message: @autoclosure () -> String = String(),
                   file: StaticString = #fileID,
                   line: UInt = #line,
                   column: UInt = #column,
                   function: StaticString = #function)
{
  #if DEBUG
  Assert.assertionFailureHandler?(message(), file, line, column)
  #endif
}

#if DEBUG
@usableFromInline
enum Assert {

  /// The test assertion failure type.
  public typealias TestAssertionFailureHandler = (_ message: String, _ file: StaticString, _ line: UInt, _ column: UInt) -> Void

  /// The test assertion failure handler.
  @usableFromInline
  private(set) static var assertionFailureHandler: TestAssertionFailureHandler? = defaultAssertionFailureHandler

  /// Set the test assertion failure handler.
  static func setTestAssertionFailureHandler(_ handler: TestAssertionFailureHandler?) {
    assertionFailureHandler = handler
  }

  /// Reset the test assertion failure handler to the default one.
  static func resetTestAssertionFailureHandler() {
    assertionFailureHandler = defaultAssertionFailureHandler
  }

  private static let defaultAssertionFailureHandler: TestAssertionFailureHandler = { message, file, line, column in
    print("Assertion failed: \(message) - \(file):\(line):\(column)")
    raise(SIGABRT)
  }
}
#endif
