//
//  XCTAssertEventuallyEqual.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 2/22/26.
//

import XCTest
import Foundation

func XCTAssertEventuallyEqual<T: Equatable>(
    _ expression: @autoclosure @escaping () -> T,
    _ expected: T,
    timeout: TimeInterval = 1,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if expression() == expected {
            break
        }
        RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
    }
    XCTAssertEqual(expression(), expected, file: file, line: line)
}
