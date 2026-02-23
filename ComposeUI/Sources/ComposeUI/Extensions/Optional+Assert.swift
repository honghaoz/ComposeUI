//
//  Optional+Assert.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/27/25.
//

import Foundation

extension Optional {

    /// Access optional value with assertion failure if the value is `nil`.
    ///
    /// - Parameters:
    ///   - assertionMessage: The message to show when assertion fails.
    /// - Returns: The unwrapped value.
    @inlinable
    func assertNotNil(_ assertionMessage: @autoclosure () -> String = "Unexpected nil value") -> Wrapped? {
        #if DEBUG
        guard let unwrapped = self else {
            assertionFailure(assertionMessage())
            return self
        }
        return unwrapped
        #else
        return self
        #endif
    }
}
