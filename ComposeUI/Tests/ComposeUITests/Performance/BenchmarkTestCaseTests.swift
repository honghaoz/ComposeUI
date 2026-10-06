//
//  BenchmarkTestCaseTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/5/26.
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

import Darwin
import Foundation

import ChouTiTest

class BenchmarkTestCaseTests: XCTestCase {

  // MARK: - Measure

  func test_measure_runsEveryIterationOnceInOrder() {
    // given: a benchmark harness
    let harness = BenchmarkTestCase()
    var indices: [Int] = []

    // when: measuring a block with a warm-up
    let result = harness.measure(warmup: 4, iterations: 2) { index in
      indices.append(index)
    }

    // then: the warm-up iterations run before the measured ones, each once, and the allocations are counted
    expect(indices) == [0, 1, 2, 3, 4, 5]
    expect(result.durations.count) == 2
    expect(result.allocationsPerIteration) != nil
  }

  func test_measure_allocationHookTaken_runsEveryIterationOnceInOrder() throws {
    // given: a benchmark harness, and another tool's logger in libmalloc's allocation hook
    let harness = BenchmarkTestCase()
    var indices: [Int] = []
    let restoreHook = try takeAllocationHook()
    defer {
      restoreHook()
    }

    // when: measuring a block with a warm-up
    let result = harness.measure(warmup: 4, iterations: 2) { index in
      indices.append(index)
    }

    // then: the warm-up iterations still run, so the measured iterations start from the same state, and the allocations
    // aren't counted
    expect(indices) == [0, 1, 2, 3, 4, 5]
    expect(result.durations.count) == 2
    expect(result.allocationsPerIteration) == nil
  }

  // MARK: - Report

  func test_reportLine_parsesBackIntoTheSameCosts() throws {
    // given: the costs of three measured iterations
    let result = BenchmarkResult(durations: [10, 20, 30], instructions: [100, 200, 300], allocationsPerIteration: 2.5)

    // when: making the line that report prints, with extra information
    let line = BenchmarkTestCase.reportLine(name: "scroll", result: result, extra: "rows: 10")

    // then: the line has the median and the p90 time, the median instructions and the allocations, and the comparison
    // reads the same costs back from it
    expect(line) == "[BENCHMARK] scroll | iterations: 3 | median: 20.00 µs | p90: 30.00 µs | instructions: 200 | allocations: 2.50 | rows: 10"
    let parsed = try BenchmarkComparison.parse(line).unwrap()
    expect(parsed.name) == "scroll"
    expect(parsed.sample) == BenchmarkComparison.Sample(time: 20, instructions: 200, allocations: 2.5)
  }

  func test_reportLine_uncountedCosts_parseBackAsMissing() throws {
    // given: the costs of an iteration on a machine that counts neither instructions nor allocations
    let result = BenchmarkResult(durations: [12.5], instructions: nil, allocationsPerIteration: nil)

    // when: making the line that report prints
    let line = BenchmarkTestCase.reportLine(name: "scroll", result: result)

    // then: the uncounted costs read n/a, and the comparison reads them back as missing
    expect(line) == "[BENCHMARK] scroll | iterations: 1 | median: 12.50 µs | p90: 12.50 µs | instructions: n/a | allocations: n/a"
    let parsed = try BenchmarkComparison.parse(line).unwrap()
    expect(parsed.sample) == BenchmarkComparison.Sample(time: 12.5, instructions: nil, allocations: nil)
  }

  func test_failIfUnreported_withoutReport_fails() {
    // given: a benchmark harness that hasn't reported its costs
    let harness = BenchmarkTestCase()
    let options = XCTExpectedFailure.Options()
    options.issueMatcher = { $0.compactDescription == "failed - the benchmark didn't report its costs" }

    // then: a run that wasn't skipped fails, since a comparison couldn't tell it from a benchmark that both sides
    // stopped reporting
    XCTExpectFailure("the benchmark didn't report its costs", options: options) {
      harness.failIfUnreported(wasSkipped: false)
    }
  }

  func test_failIfUnreported_profilingTest_passes() {
    // given: a benchmark harness running a profiling test, which runs for a profiler and reports nothing
    let harness = RenderPerformanceTests(selector: #selector(RenderPerformanceTests.test_profile_scroll_nested))

    // then: a run passes without a report
    harness.failIfUnreported(wasSkipped: false)
  }

  func test_failIfUnreported_skippedOrReported_passes() {
    // given: a benchmark harness that hasn't reported its costs
    let harness = BenchmarkTestCase()

    // then: a skipped run passes without a report, since the comparison reports a skipped test itself
    harness.failIfUnreported(wasSkipped: true)

    // when: the benchmark reports its costs
    harness.report(name: "reported", result: BenchmarkResult(durations: [1], instructions: nil, allocationsPerIteration: nil))

    // then: a run passes
    harness.failIfUnreported(wasSkipped: false)
  }

  // MARK: - AllocationCounter

  func test_allocationCounter_countsEachAllocation() {
    // given: a body that allocates three objects, run once already, since a first run can also allocate what the runtime
    // makes on first use, such as type metadata. The body has no loop, since a loop over a range allocates on each
    // step in a debug build
    let body = {
      _ = NSObject()
      _ = NSObject()
      _ = NSObject()
    }
    _ = AllocationCounter.count(body)

    // when: counting the allocations of the body
    let count = AllocationCounter.count(body)

    // then: each allocation counts once
    expect(count) == 3
  }

  func test_allocationCounter_skipsTheAllocationsOfOtherThreads() {
    // given: another thread that allocates five objects each time it's told to, and a body that tells it to and waits,
    // run once already, since a first run also allocates what the runtime makes on first use
    let start = DispatchSemaphore(value: 0)
    let done = DispatchSemaphore(value: 0)
    let thread = Thread {
      for _ in 0 ..< 2 {
        start.wait()
        for _ in 0 ..< 5 {
          _ = NSObject()
        }
        done.signal()
      }
    }
    thread.start()
    let body = {
      start.signal()
      done.wait()
    }
    _ = AllocationCounter.count(body)

    // when: counting the allocations of the body
    let count = AllocationCounter.count(body)

    // then: the other thread's allocations don't count
    expect(count) == 0
  }

  func test_allocationCounter_hookTaken_runsTheBodyWithoutCounting() throws {
    // given: another tool's logger in libmalloc's allocation hook
    let restoreHook = try takeAllocationHook()
    defer {
      restoreHook()
    }

    // when: counting the allocations of a body
    var runs = 0
    let count = AllocationCounter.count {
      runs += 1
    }

    // then: the body runs once, and its allocations aren't counted
    expect(runs) == 1
    expect(count) == nil
  }

  // MARK: - Helpers

  /// Sets a logger that does nothing as libmalloc's allocation hook, as another tool would, and returns a closure that
  /// restores the previous logger.
  private func takeAllocationHook() throws -> () -> Void {
    typealias Logger = @convention(c) (UInt32, UInt, UInt, UInt, UInt, UInt32) -> Void
    let hook = try dlsym(UnsafeMutableRawPointer(bitPattern: -2), "malloc_logger").unwrap() // RTLD_DEFAULT
      .assumingMemoryBound(to: Logger?.self)
    let previousLogger = hook.pointee
    hook.pointee = { _, _, _, _, _, _ in }
    return {
      hook.pointee = previousLogger
    }
  }
}
