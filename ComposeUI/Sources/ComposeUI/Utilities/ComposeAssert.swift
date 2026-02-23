//
//  ComposeAssert.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/18/25.
//

import Foundation

#if DEBUG
@usableFromInline
enum ComposeAssert {

    @inlinable
    @inline(__always)
    static func assert(_ condition: @autoclosure () -> Bool,
                       _ message: @autoclosure () -> String = String(),
                       file: StaticString = #fileID,
                       line: UInt = #line,
                       column: UInt = #column,
                       function: StaticString = #function)
    {
        #if DEBUG
        if !condition() {
            assertionFailure(message(), file: file, line: line, column: column, function: function)
        }
        #endif
    }

    @inlinable
    @inline(__always)
    static func assertionFailure(_ message: @autoclosure () -> String = String(),
                                 file: StaticString = #fileID,
                                 line: UInt = #line,
                                 column: UInt = #column,
                                 function: StaticString = #function)
    {
        #if DEBUG
        ComposeAssert.assertionFailureHandler?(message(), file, line, column)
        #endif
    }

    /// The test assertion failure type.
    @usableFromInline
    typealias TestAssertionFailureHandler = (_ message: String, _ file: StaticString, _ line: UInt, _ column: UInt) -> Void

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
