//
//  BenchmarkTestCase.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/4/26.
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

/// A test case of benchmarks: measures blocks and reports their costs in one line format.
///
/// Benchmarks are skipped by default. To run them in release configuration on macOS:
///
/// ```bash
/// make -C ComposeUI benchmark FILTER=RenderPerformanceTests
/// ```
///
/// To compare them against a base revision, built and run in turns on this machine:
///
/// ```bash
/// make -C ComposeUI benchmark-compare BASE=origin/master FILTER=RenderPerformanceTests
/// ```
///
/// A benchmark reports three costs per iteration, which depend on different things:
/// - Time depends on the machine and its load. Compare times only between builds measured on the same machine at the
///   same time, interleaved.
/// - Instructions retired don't depend on the machine's speed or load, only on the CPU architecture, the compiler and the
///   OS. A change of about 1% shows in a few runs. The count covers the whole process, and is unavailable in virtual
///   machines, such as GitHub's macOS runners, which don't expose the CPU's counters.
/// - Allocations on the calling thread are exact for a given build, but differ between debug and release builds, and
///   with the OS for the allocations inside the system frameworks.
class BenchmarkTestCase: XCTestCase {

  override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipUnless(ProcessInfo.processInfo.environment["BENCHMARK"] == "1", "benchmarks are skipped by default, run with BENCHMARK=1")
  }

  /// Measures a block.
  ///
  /// Runs the warm-up iterations, then the measured iterations, each in its own autorelease pool, so that autoreleased
  /// objects don't pile up across iterations. The allocations are counted in the second half of the warm-up, once the
  /// first half has warmed up the state, instead of in the measured iterations, since counting slows every allocation
  /// down.
  ///
  /// - Parameters:
  ///   - warmup: The number of iterations to run before measuring.
  ///   - iterations: The number of iterations to measure. Must be positive.
  ///   - block: The block to measure, given the index of the iteration, counting the warm-up iterations first.
  /// - Returns: The costs of the measured iterations.
  func measure(warmup: Int, iterations: Int, _ block: (Int) -> Void) -> BenchmarkResult {
    precondition(iterations > 0, "a benchmark measures at least one iteration")

    let countedWarmupStart = warmup / 2
    for index in 0 ..< countedWarmupStart {
      autoreleasepool {
        block(index)
      }
    }
    let allocations = AllocationCounter.count {
      for index in countedWarmupStart ..< warmup {
        autoreleasepool {
          block(index)
        }
      }
    }

    var durations: [Double] = []
    durations.reserveCapacity(iterations)
    var instructions: [UInt64] = []
    instructions.reserveCapacity(iterations)
    for index in warmup ..< warmup + iterations {
      autoreleasepool {
        // read the instruction counter outside of the timed span, since the read is a system call
        let startInstructions = InstructionCounter.current()
        let start = DispatchTime.now().uptimeNanoseconds
        block(index)
        let end = DispatchTime.now().uptimeNanoseconds
        let endInstructions = InstructionCounter.current()

        durations.append(Double(end - start) / 1000)
        if let startInstructions, let endInstructions {
          instructions.append(endInstructions - startInstructions)
        }
      }
    }

    let countedWarmup = warmup - countedWarmupStart
    return BenchmarkResult(
      durations: durations.sorted(),
      instructions: instructions.count == iterations ? instructions.sorted() : nil,
      allocationsPerIteration: countedWarmup > 0 ? allocations.map { Double($0) / Double(countedWarmup) } : nil
    )
  }

  /// Prints the costs of a benchmark in one line, in this format:
  ///
  /// ```
  /// [BENCHMARK] <name> | iterations: <count> | median: <time> µs | p90: <time> µs | instructions: <median> | allocations: <per iteration>
  /// ```
  ///
  /// A cost that can't be measured reads `n/a`.
  ///
  /// - Parameters:
  ///   - name: The name of the benchmark.
  ///   - result: The costs to report.
  ///   - extra: Extra information to append, as `key: value` pairs separated by ` | `.
  func report(name: String, result: BenchmarkResult, extra: String? = nil) {
    print(Self.reportLine(name: name, result: result, extra: extra))
  }

  /// Returns the line that `report(name:result:extra:)` prints, which `BenchmarkComparison.parse(_:)` reads.
  ///
  /// - Parameters:
  ///   - name: The name of the benchmark.
  ///   - result: The costs to report.
  ///   - extra: Extra information to append, as `key: value` pairs separated by ` | `.
  /// - Returns: The line.
  static func reportLine(name: String, result: BenchmarkResult, extra: String? = nil) -> String {
    var line = "[BENCHMARK] \(name) | iterations: \(result.durations.count)"
    line += " | median: \(String(format: "%.2f", result.medianDuration)) µs | p90: \(String(format: "%.2f", result.p90Duration)) µs"
    line += " | instructions: \(result.medianInstructions.map { "\($0)" } ?? "n/a")"
    line += " | allocations: \(result.allocationsPerIteration.map { String(format: "%.2f", $0) } ?? "n/a")"
    if let extra {
      line += " | \(extra)"
    }
    return line
  }
}

/// The costs of a benchmark's measured iterations.
struct BenchmarkResult {

  /// The wall-clock time of each measured iteration, in microseconds, sorted ascending.
  let durations: [Double]

  /// The instructions the process retired in each measured iteration, sorted ascending, `nil` if they can't be counted.
  let instructions: [UInt64]?

  /// The allocations on the calling thread per iteration, `nil` if they can't be counted.
  let allocationsPerIteration: Double?

  /// The median time, in microseconds.
  var medianDuration: Double {
    durations[durations.count / 2]
  }

  /// The 90th percentile time, in microseconds.
  var p90Duration: Double {
    durations[Int(Double(durations.count) * 0.9)]
  }

  /// The median instructions retired, `nil` if they can't be counted.
  var medianInstructions: UInt64? {
    instructions.map { $0[$0.count / 2] }
  }
}

// MARK: - Counters

/// Reads the instructions the process has retired, through `proc_pid_rusage`.
enum InstructionCounter {

  private typealias ProcPidRUsage = @convention(c) (_ pid: Int32, _ flavor: Int32, _ buffer: UnsafeMutableRawPointer) -> Int32

  /// `proc_pid_rusage`, looked up at run time, since only the macOS SDK declares it.
  private static let procPidRUsage: ProcPidRUsage? = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "proc_pid_rusage") // RTLD_DEFAULT
    .map { unsafeBitCast($0, to: ProcPidRUsage.self) }

  /// Returns the instructions the process has retired, `nil` if they can't be counted.
  static func current() -> UInt64? {
    guard let procPidRUsage else {
      return nil
    }

    var info = rusage_info_v4()
    let result = withUnsafeMutableBytes(of: &info) { buffer in
      buffer.baseAddress.map { procPidRUsage(getpid(), RUSAGE_INFO_V4, $0) } ?? -1
    }

    // the count stays 0 where the CPU's counters aren't exposed
    guard result == 0, info.ri_instructions > 0 else {
      return nil
    }
    return info.ri_instructions
  }
}

/// Counts the allocations made on the calling thread, through libmalloc's `malloc_logger` hook, which libmalloc calls
/// for every allocation while it is set.
enum AllocationCounter {

  private typealias Logger = @convention(c) (_ type: UInt32, _ arg1: UInt, _ arg2: UInt, _ arg3: UInt, _ result: UInt, _ skippedFrames: UInt32) -> Void

  /// The `malloc_logger` variable, `nil` if libmalloc doesn't export it.
  private static let logger: UnsafeMutablePointer<Logger?>? = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "malloc_logger") // RTLD_DEFAULT
    .map { $0.assumingMemoryBound(to: Logger?.self) }

  /// The count and the counted thread, in memory that the logger reaches without capturing anything, since a C
  /// function pointer can't capture.
  private static let counter = UnsafeMutablePointer<Int>.allocate(capacity: 1)
  private static let countedThread = UnsafeMutablePointer<pthread_t?>.allocate(capacity: 1)

  /// Runs the body once, and returns the number of allocations it makes on the calling thread, `nil` if the allocations
  /// can't be counted.
  static func count(_ body: () -> Void) -> Int? {
    guard let logger, logger.pointee == nil else {
      // the caller relies on the body running, as a benchmark's warm-up moves its state forward, so the body runs
      // without counting when libmalloc doesn't export the hook or another tool already uses it
      body()
      return nil
    }

    counter.pointee = 0
    countedThread.pointee = pthread_self()
    logger.pointee = { type, _, _, _, _, _ in
      let allocateType: UInt32 = 2 // MALLOC_LOG_TYPE_ALLOCATE, also set for a reallocation
      if type & allocateType != 0, pthread_equal(pthread_self(), AllocationCounter.countedThread.pointee) != 0 {
        AllocationCounter.counter.pointee += 1
      }
    }
    body()
    logger.pointee = nil
    return counter.pointee
  }
}

/// The number of heap blocks and bytes in use.
struct MemoryUsage {

  let blocks: Int
  let bytes: Int

  /// Returns the memory that the value the body makes keeps in use.
  static func retained(by body: () -> some Any) -> MemoryUsage {
    let before = current()
    let value = body()
    let after = current()
    withExtendedLifetime(value) {}
    return MemoryUsage(blocks: after.blocks - before.blocks, bytes: after.bytes - before.bytes)
  }

  private static func current() -> MemoryUsage {
    var statistics = malloc_statistics_t()
    malloc_zone_statistics(nil, &statistics) // all zones
    return MemoryUsage(blocks: Int(statistics.blocks_in_use), bytes: Int(statistics.size_in_use))
  }
}
