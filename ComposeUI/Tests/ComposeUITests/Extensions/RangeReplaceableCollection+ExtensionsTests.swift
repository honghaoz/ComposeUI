//
//  RangeReplaceableCollection+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/3/24.
//

import ChouTiTest

@testable import ComposeUI

class RangeReplaceableCollection_ExtensionsTests: XCTestCase {

    func testSwapRemove() {
        var array = [1, 2, 3, 4, 5]
        let removed = array.swapRemove(at: 2)
        expect(removed) == 3
        expect(array) == [1, 2, 5, 4]
    }

    // Test correctness
    func testSwapRemoveCorrectness() {
        var array = [1, 2, 3, 4, 5]
        let removed = array.swapRemove(at: 1)

        expect(removed) == 2
        expect(array) == [1, 5, 3, 4]
    }

    // Test edge cases
    func testSwapRemoveLastElement() {
        var array = [1, 2, 3]
        let removed = array.swapRemove(at: 2)

        expect(removed) == 3
        expect(array) == [1, 2]
    }

    // MARK: - Performance tests

    func testPerformanceSwapRemoveBulk() throws {
        try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

        let size = 100000
        let array = Array(0 ..< size)

        measure {
            var testArray = array
            for i in stride(from: 0, to: size / 2, by: 1) {
                _ = testArray.swapRemove(at: i)
            }
        }
    }

    func testPerformanceRegularRemoveBulk() throws {
        try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

        let size = 100000
        let array = Array(0 ..< size)

        measure {
            var testArray = array
            for i in stride(from: 0, to: size / 2, by: 1) {
                _ = testArray.remove(at: i)
            }
        }
    }

    func testPerformanceSwapRemoveFirst() throws {
        try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

        let size = 100000
        let array = Array(0 ..< size)

        measure {
            var testArray = array
            _ = testArray.swapRemove(at: 0)
        }
    }

    func testPerformanceRegularRemoveFirst() throws {
        try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

        let size = 100000
        let array = Array(0 ..< size)

        measure {
            var testArray = array
            _ = testArray.remove(at: 0)
        }
    }

    func testPerformanceSwapRemoveMiddle() throws {
        try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

        let size = 100000
        let array = Array(0 ..< size)
        let middleIndex = size / 2

        measure {
            var testArray = array
            _ = testArray.swapRemove(at: middleIndex)
        }
    }

    func testPerformanceRegularRemoveMiddle() throws {
        try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

        let size = 100000
        let array = Array(0 ..< size)
        let middleIndex = size / 2

        measure {
            var testArray = array
            _ = testArray.remove(at: middleIndex)
        }
    }

    func testPerformanceSwapRemoveLast() throws {
        try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

        let size = 100000
        let array = Array(0 ..< size)
        let lastIndex = size - 1

        measure {
            var testArray = array
            _ = testArray.swapRemove(at: lastIndex)
        }
    }

    func testPerformanceRegularRemoveLast() throws {
        try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

        let size = 100000
        let array = Array(0 ..< size)
        let lastIndex = size - 1

        measure {
            var testArray = array
            _ = testArray.remove(at: lastIndex)
        }
    }

    func testPerformanceSwapRemoveContiguousArray() throws {
        try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

        let size = 100000
        let array = ContiguousArray(0 ..< size)
        let middleIndex = size / 2

        measure {
            var testArray = array
            _ = testArray.swapRemove(at: middleIndex)
        }
    }

    func testPerformanceRegularRemoveContiguousArray() throws {
        try skipIf(ProcessInfo.isRunningInGitHubActions, "Skipping performance tests in GitHub Actions")

        let size = 100000
        let array = ContiguousArray(0 ..< size)
        let middleIndex = size / 2

        measure {
            var testArray = array
            _ = testArray.remove(at: middleIndex)
        }
    }
}
