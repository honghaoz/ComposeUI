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

  func test_measure_beforeEach_runsBeforeEachIteration() {
    // given: a benchmark harness, and a block to run before each iteration
    let harness = BenchmarkTestCase()
    var events: [String] = []
    let beforeEach = {
      events.append("before")
    }

    // when: measuring a block with a warm-up
    _ = harness.measure(warmup: 4, iterations: 2, beforeEach: beforeEach) { index in
      events.append("\(index)")
    }

    // then: the block runs once before each iteration, of the warm-up and measured
    expect(events) == ["before", "0", "before", "1", "before", "2", "before", "3", "before", "4", "before", "5"]
  }

  func test_measure_beforeEach_isNotCounted() {
    // given: a benchmark harness, a counter that counts 100 instructions for each of its reads, and a block to run before
    // each iteration that retires 5,000 instructions and allocates an object
    let harness = BenchmarkTestCase()
    let counted = CountedInstructions()
    let counter = { () -> UInt64? in
      counted.retired += 100
      return counted.retired
    }
    var objects: [NSObject] = []
    let beforeEach = {
      counted.retired += 5000
      objects.append(NSObject())
    }

    // when: measuring a block that retires 1,000 instructions
    let result = harness.measure(warmup: 4, iterations: 3, instructionCounter: counter, beforeEach: beforeEach) { _ in
      counted.retired += 1000
    }

    // then: the iterations count only the measured block's instructions and allocations
    expect(objects.count) == 7
    expect(result.instructions) == [1000, 1000, 1000]
    expect(result.allocationsPerIteration) == 0
  }

  func test_measure_beforeEach_releasesWhatItAutoreleasesBeforeTheIteration() {
    // given: a benchmark harness, and a block to run before each iteration that autoreleases an object
    let harness = BenchmarkTestCase()
    weak var autoreleasedObject: NSObject?
    let beforeEach = {
      let object = NSObject()
      autoreleasedObject = object
      _ = Unmanaged.passRetained(object).autorelease()
    }
    var objectsAliveInIterations: [Bool] = []

    // when: measuring a block that checks whether the object is alive
    _ = harness.measure(warmup: 2, iterations: 2, beforeEach: beforeEach) { _ in
      objectsAliveInIterations.append(autoreleasedObject != nil)
    }

    // then: each object went away before its iteration, of the warm-up and measured
    expect(objectsAliveInIterations) == [false, false, false, false]
  }

  func test_measure_takesTheCounterReadsOutOfEachIteration() {
    // given: a benchmark harness, and a counter that counts 100 instructions for each of its reads
    let harness = BenchmarkTestCase()
    let counted = CountedInstructions()
    let counter = { () -> UInt64? in
      counted.retired += 100
      return counted.retired
    }

    // when: measuring a block that retires 1,000 instructions
    let result = harness.measure(warmup: 2, iterations: 3, instructionCounter: counter) { _ in
      counted.retired += 1000
    }

    // then: each iteration counts the block's instructions, without the read in its span
    expect(result.instructions) == [1000, 1000, 1000]
  }

  func test_measure_iterationUnderTheEmptyIterationsMedian_countsNoInstructions() {
    // given: a benchmark harness, and a counter that counts 300 instructions for each read until the measured
    // iterations, and 100 in them, so a measured iteration counts fewer instructions than an empty one before it
    let harness = BenchmarkTestCase()
    let counted = CountedInstructions()
    let counter = { () -> UInt64? in
      counted.retired += counted.blockCalls > 2 ? 100 : 300
      return counted.retired
    }

    // when: measuring a block that only counts its calls, after 2 warm-up iterations
    let result = harness.measure(warmup: 2, iterations: 3, instructionCounter: counter) { _ in
      counted.blockCalls += 1
    }

    // then: each iteration counts no instructions, instead of a count that wraps around
    expect(result.instructions) == [0, 0, 0]
  }

  func test_measure_instructionsNotCounted_reportsNone() {
    // given: a benchmark harness, and a counter that can't count, as in a virtual machine
    let harness = BenchmarkTestCase()
    let counter: () -> UInt64? = { nil }

    // when: measuring a block
    let result = harness.measure(warmup: 2, iterations: 3, instructionCounter: counter) { _ in }

    // then: the result has no instructions
    expect(result.instructions) == nil
  }

  func test_measure_emptyBlock_countsAlmostNoInstructions() throws {
    // given: a benchmark harness on a machine that counts instructions
    try XCTSkipIf(InstructionCounter.current() == nil, "the instructions can't be counted on this machine")
    let harness = BenchmarkTestCase()

    // when: measuring a block that does nothing
    let result = harness.measure(warmup: 10, iterations: 201) { _ in }

    // then: the iterations leave out the counter reads around them, which retire thousands of instructions
    let instructions = try result.medianInstructions.unwrap()
    expect(instructions) < 1000
  }

  func test_measure_threadsStartedInTheMeasuredIterations_countAlmostNoInstructions() throws {
    // given: a benchmark harness on a machine that counts instructions
    try XCTSkipIf(InstructionCounter.current() == nil, "the instructions can't be counted on this machine")
    let harness = BenchmarkTestCase()
    var threadEnds: [DispatchSemaphore] = []
    defer {
      threadEnds.forEach { $0.signal() }
    }

    // when: measuring a block that starts 16 threads that wait, in the first measured iteration after 10 warm-up
    // iterations, and does nothing in the others
    let result = harness.measure(warmup: 10, iterations: 201) { index in
      guard index == 10 else {
        return
      }
      for _ in 0 ..< 16 {
        let started = DispatchSemaphore(value: 0)
        let end = DispatchSemaphore(value: 0)
        let thread = Thread {
          started.signal()
          end.wait()
        }
        // Xcode's thread performance checker reports a wait on a thread of a lower quality of service with work on the
        // waiting thread, so the threads run at this thread's
        thread.qualityOfService = Thread.current.qualityOfService
        thread.start()
        started.wait()
        threadEnds.append(end)
      }
    }

    // then: the iterations after it count almost no instructions, though the counter reads that each iteration leaves
    // out were measured before the threads started
    let instructions = try result.medianInstructions.unwrap()
    expect(instructions) < 1000
  }

  // MARK: - Report

  func test_reportLine_parsesBackIntoTheSameCosts() throws {
    // given: the costs of three measured iterations
    let result = BenchmarkResult(durations: [10, 20, 30], instructions: [100, 200, 300], allocationsPerIteration: 2.5)

    // when: making the line that report prints, with extra information
    let line = BenchmarkTestCase.reportLine(name: "scroll", result: result, extra: "rows: 10")

    // then: the line has the median and the p90 time, the median instructions and the allocations, and the comparison
    // reads the same costs back from it
    expect(line) == "[BENCHMARK] scroll | iterations: 3 | median: 20.00 us | p90: 30.00 us | instructions: 200 | allocations: 2.50 | rows: 10"
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
    expect(line) == "[BENCHMARK] scroll | iterations: 1 | median: 12.50 us | p90: 12.50 us | instructions: n/a | allocations: n/a"
    let parsed = try BenchmarkComparison.parse(line).unwrap()
    expect(parsed.sample) == BenchmarkComparison.Sample(time: 12.5, instructions: nil, allocations: nil)
  }

  func test_report_writesTheLineToTheStandardError() {
    // given: a benchmark harness, and the costs of an iteration
    let harness = BenchmarkTestCase()
    let result = BenchmarkResult(durations: [12.5], instructions: nil, allocationsPerIteration: nil)

    // when: reporting the costs, with extra information
    let output = standardError {
      harness.report(name: "scroll", result: result, extra: "rows: 10")
    }

    // then: the report goes to the standard error, where XCTest writes its own lines, as one line
    expect(output) == "[BENCHMARK] scroll | iterations: 1 | median: 12.50 us | p90: 12.50 us | instructions: n/a | allocations: n/a | rows: 10\n"
  }

  func test_report_notASCII_failsWithoutWriting() {
    // given: a benchmark harness
    let harness = BenchmarkTestCase()
    let options = XCTExpectedFailure.Options()
    options.issueMatcher = { $0.compactDescription == "failed - the benchmark's report isn't ASCII" }

    // when: reporting the costs of a benchmark whose name isn't ASCII
    var output: String?
    XCTExpectFailure("the benchmark's report isn't ASCII", options: options) {
      output = standardError {
        harness.report(name: "scroll.10×10", result: BenchmarkResult(durations: [1], instructions: nil, allocationsPerIteration: nil))
      }
    }

    // then: the benchmark fails, and writes no report, only XCTest's note of the expected failure
    expect(output?.contains("[BENCHMARK]")) == false
    expect(output?.contains("the benchmark's report isn't ASCII")) == true
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

  // MARK: - InstructionCounter

  func test_instructionCounter_returnsTheInstructionsOfTheCounts() {
    // given: a function that writes 42 instructions and then 99 cycles, when it's asked for both in a buffer of their
    // size, as `thread_selfcounts` does
    let threadSelfCounts: InstructionCounter.ThreadSelfCounts = { kind, buffer, size in
      guard kind == 1, size == 16, let buffer else {
        return -1
      }
      buffer.storeBytes(of: UInt64(42), as: UInt64.self)
      buffer.storeBytes(of: UInt64(99), toByteOffset: 8, as: UInt64.self)
      return 0
    }

    // when: reading the instructions through it
    let instructions = InstructionCounter.current(threadSelfCounts: threadSelfCounts)

    // then: the counter returns the instructions
    expect(instructions) == 42
  }

  func test_instructionCounter_uncountable_returnsNil() {
    // then: the instructions can't be counted where the system has no function to read them, where the function fails,
    // whatever it wrote, and where it counts none, as in a virtual machine that doesn't expose the CPU's counters
    expect(InstructionCounter.current(threadSelfCounts: nil)) == nil
    expect(InstructionCounter.current(threadSelfCounts: { _, buffer, _ in
      buffer?.storeBytes(of: UInt64(42), as: UInt64.self)
      return -1
    })) == nil
    expect(InstructionCounter.current(threadSelfCounts: { _, _, _ in 0 })) == nil
  }

  func test_instructionCounter_skipsTheInstructionsOfOtherThreads() throws {
    // given: another thread that allocates 100,000 objects when it's told to, which retires millions of instructions, on
    // a machine that counts instructions
    try XCTSkipIf(InstructionCounter.current() == nil, "the instructions can't be counted on this machine")
    let start = DispatchSemaphore(value: 0)
    let done = DispatchSemaphore(value: 0)
    let thread = Thread {
      start.wait()
      for _ in 0 ..< 100000 {
        _ = NSObject()
      }
      done.signal()
    }
    // Xcode's thread performance checker reports a wait on a thread of a lower quality of service with work on the
    // waiting thread, which its count would include, so the other thread runs at this thread's, which differs between
    // platforms
    thread.qualityOfService = Thread.current.qualityOfService
    thread.start()

    // when: counting this thread's instructions while it tells the other thread to allocate and waits for it
    let startInstructions = try InstructionCounter.current().unwrap()
    start.signal()
    done.wait()
    let endInstructions = try InstructionCounter.current().unwrap()

    // then: the count leaves out the other thread's instructions
    expect(endInstructions - startInstructions) < 1000000
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

  /// Returns what a block writes to the standard error, which goes to a pipe while the block runs, `nil` if it isn't
  /// UTF-8.
  private func standardError(of block: () -> Void) -> String? {
    let pipe = Pipe()
    let savedStandardError = dup(STDERR_FILENO)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
    block()
    dup2(savedStandardError, STDERR_FILENO)
    close(savedStandardError)
    try? pipe.fileHandleForWriting.close()
    return String(bytes: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
  }

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

/// The instructions that a scripted counter has counted, and the calls to the block it measures, in one object that the
/// counter and the block both change.
private final class CountedInstructions {

  var retired: UInt64 = 0
  var blockCalls = 0
}
