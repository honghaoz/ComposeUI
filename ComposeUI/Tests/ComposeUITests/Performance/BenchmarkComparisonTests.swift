//
//  BenchmarkComparisonTests.swift
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

import ChouTiTest

class BenchmarkComparisonTests: XCTestCase {

  // MARK: - Parse

  func test_parse_readsTheCosts() throws {
    // when: parsing a result line with extra information
    let parsed = try BenchmarkComparison.parse("[BENCHMARK] scroll | iterations: 120 | median: 42.42 µs | p90: 48.04 µs | instructions: 587210 | allocations: 110.10 | renderedItems: 18").unwrap()

    // then: it reads the name, the median time, the instructions and the allocations
    expect(parsed.name) == "scroll"
    expect(parsed.sample) == BenchmarkComparison.Sample(time: 42.42, instructions: 587210, allocations: 110.10)
  }

  func test_parse_millisecondsAndUncountedCosts() throws {
    // when: parsing a time in milliseconds, and costs that couldn't be counted
    let parsed = try BenchmarkComparison.parse("[BENCHMARK] refresh | median: 1.5 ms | instructions: n/a | allocations: n/a").unwrap()

    // then: the time is in microseconds, and the uncounted costs are missing
    expect(parsed.sample) == BenchmarkComparison.Sample(time: 1500, instructions: nil, allocations: nil)
  }

  func test_parse_unreadableCosts_areMissing() throws {
    // when: parsing a line without costs, a time in an unknown unit, a field without a value, a time without a unit, and
    // allocations that aren't a number
    let withoutCosts = try BenchmarkComparison.parse("[BENCHMARK] scroll.text.alloc | textViewCreations: 74 | reuses: 60").unwrap()
    let unknownUnit = try BenchmarkComparison.parse("[BENCHMARK] odd | median: 5 s | instructions | allocations: twelve").unwrap()
    let withoutUnit = try BenchmarkComparison.parse("[BENCHMARK] odd | median: 5").unwrap()

    // then: the costs are missing
    let missing = BenchmarkComparison.Sample(time: nil, instructions: nil, allocations: nil)
    expect(withoutCosts.sample) == missing
    expect(unknownUnit.sample) == missing
    expect(withoutUnit.sample) == missing
  }

  func test_parse_otherLines_areNotResults() {
    // then: lines without the prefix, or without a name, aren't results
    expect(BenchmarkComparison.parse("Test Case '-[ComposeUITests.RenderPerformanceTests test_scroll]' passed")) == nil
    expect(BenchmarkComparison.parse("")) == nil
    expect(BenchmarkComparison.parse("[BENCHMARK] ")) == nil
    expect(BenchmarkComparison.parse("[BENCHMARK]  | median: 1.00 µs")) == nil
  }

  // MARK: - Statistics

  func test_median() {
    // then: the median is the middle value, the mean of the two middle values for an even count, and missing for none
    expect(BenchmarkComparison.median([3, 1, 2])) == 2
    expect(BenchmarkComparison.median([4, 1, 3, 2])) == 2.5
    expect(BenchmarkComparison.median([])) == nil
  }

  func test_percentChange() {
    // then: the change is relative to the base, and missing for a base of zero
    expect(BenchmarkComparison.percentChange(from: 200, to: 250)) == 25
    expect(BenchmarkComparison.percentChange(from: 200, to: 150)) == -25
    expect(BenchmarkComparison.percentChange(from: 0, to: 1)) == nil
  }

  // MARK: - Results

  func test_results_readTheBenchmarksInTheOrderTheyFirstReported() throws {
    // when: reading the lines of two rounds, with other output between the results
    let results = BenchmarkComparison.Results(lines: [
      "[BENCHMARK] b | median: 1.00 µs | instructions: 10 | allocations: 1.00",
      "Test Suite 'Selected tests' passed",
      "[BENCHMARK] a | median: 2.00 µs | instructions: 20 | allocations: 2.00",
      "[BENCHMARK] b | median: 3.00 µs | instructions: 30 | allocations: 3.00",
      "[BENCHMARK] a | median: 4.00 µs | instructions: 40 | allocations: 2.00",
    ])

    // then: the benchmarks keep the order they first reported in, with the costs of both rounds
    expect(results.names) == ["b", "a"]
    let a = try results.samples["a"].unwrap()
    expect(a.count) == 2
    expect(a.medianTime) == 3
    expect(a.medianInstructions) == 30
    expect(a.allocationRange) == (2 ... 2)
  }

  func test_results_readOnlyTheResultFilesOfTheSide() throws {
    // given: a directory with the result files of two base rounds and a head round, and a log of the base
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("BenchmarkComparisonTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: directory)
    }
    let files = [
      "base-1.txt": "[BENCHMARK] scroll | median: 1.00 µs\n",
      "base-2.txt": "[BENCHMARK] scroll | median: 3.00 µs\n",
      "head-1.txt": "[BENCHMARK] scroll | median: 10.00 µs\n",
      "base-1.log": "[BENCHMARK] scroll | median: 100.00 µs\n",
    ]
    for (name, contents) in files {
      try contents.write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    // when: reading the results of each side
    let base = try BenchmarkComparison.Results(side: "base", in: directory)
    let head = try BenchmarkComparison.Results(side: "head", in: directory)

    // then: each side reads only its own result files
    expect(base.samples["scroll"]?.count) == 2
    expect(base.samples["scroll"]?.medianTime) == 2
    expect(head.samples["scroll"]?.count) == 1
    expect(head.samples["scroll"]?.medianTime) == 10
  }

  func test_samples_costCountsOnlyWhenEveryRoundReportedIt() {
    // given: a benchmark that reported every cost in one round, and only its time in the other
    var samples = BenchmarkComparison.Samples()
    samples.append(BenchmarkComparison.Sample(time: 10, instructions: 100, allocations: 5))
    samples.append(BenchmarkComparison.Sample(time: 12, instructions: nil, allocations: nil))

    // then: only the time counts, since a decision from some rounds wouldn't mean what it says
    expect(samples.medianTime) == 11
    expect(samples.medianInstructions) == nil
    expect(samples.allocationRange) == nil
  }

  // MARK: - Compare

  func test_compare_sameCosts_passes() {
    // given: the same results on both sides
    let lines = ["[BENCHMARK] steady | median: 10.00 µs | instructions: 1000 | allocations: 50.00"]

    // when: comparing them
    let report = compare(base: lines, head: lines)

    // then: nothing is found, and the comparison passes
    expect(report.rows.map(\.findings)) == [[]]
    expect(report.regressionCount) == 0
    expect(report.passes) == true
  }

  func test_compare_allocations_changeOnlyOutsideTheBasesRange() {
    // given: benchmarks whose allocations rise, jitter within the base's range, partly overlap it, and fall
    let base = [
      "[BENCHMARK] more | allocations: 100.00",
      "[BENCHMARK] jitter | allocations: 242050.00",
      "[BENCHMARK] overlap | allocations: 100.00",
      "[BENCHMARK] fewer | allocations: 100.00",
      "[BENCHMARK] more | allocations: 100.00",
      "[BENCHMARK] jitter | allocations: 242110.00",
      "[BENCHMARK] overlap | allocations: 102.00",
      "[BENCHMARK] fewer | allocations: 100.00",
    ]
    let head = [
      "[BENCHMARK] more | allocations: 101.00",
      "[BENCHMARK] jitter | allocations: 242090.00",
      "[BENCHMARK] overlap | allocations: 101.00",
      "[BENCHMARK] fewer | allocations: 90.00",
      "[BENCHMARK] more | allocations: 101.00",
      "[BENCHMARK] jitter | allocations: 242090.00",
      "[BENCHMARK] overlap | allocations: 103.00",
      "[BENCHMARK] fewer | allocations: 90.00",
    ]

    // when: comparing them
    let report = compare(base: base, head: head)

    // then: only allocations outside the base's range in every round are a change, and more of them is a regression
    expect(report.rows.map(\.findings)) == [[.moreAllocations], [], [], [.fewerAllocations]]
    expect(report.regressionCount) == 1
    expect(report.passes) == false
  }

  func test_compare_instructions_atAndPastTheThreshold() {
    // given: benchmarks whose instructions change by exactly 1%, and by 1.1%, both ways, and one whose instructions a
    // round didn't count
    let base = [
      "[BENCHMARK] up.at | instructions: 1000",
      "[BENCHMARK] up.past | instructions: 1000",
      "[BENCHMARK] down.at | instructions: 1000",
      "[BENCHMARK] down.past | instructions: 1000",
      "[BENCHMARK] uncounted | instructions: 1000",
    ]
    let head = [
      "[BENCHMARK] up.at | instructions: 1010",
      "[BENCHMARK] up.past | instructions: 1011",
      "[BENCHMARK] down.at | instructions: 990",
      "[BENCHMARK] down.past | instructions: 989",
      "[BENCHMARK] uncounted | instructions: n/a",
    ]

    // when: comparing them with a threshold of 1%
    let report = compare(base: base, head: head)

    // then: only a change past the threshold counts, and more instructions are a regression
    expect(report.rows.map(\.findings)) == [[], [.moreInstructions], [], [.fewerInstructions], []]
    expect(report.regressionCount) == 1
    expect(report.passes) == false
  }

  func test_compare_time_atAndPastTheThreshold_onlyWarns() {
    // given: benchmarks whose times change by exactly 20%, and by 25%, both ways, with the same allocations
    let base = [
      "[BENCHMARK] slower.at | median: 100.00 µs | allocations: 10.00",
      "[BENCHMARK] slower.past | median: 100.00 µs | allocations: 10.00",
      "[BENCHMARK] faster.past | median: 100.00 µs | allocations: 10.00",
    ]
    let head = [
      "[BENCHMARK] slower.at | median: 120.00 µs | allocations: 10.00",
      "[BENCHMARK] slower.past | median: 125.00 µs | allocations: 10.00",
      "[BENCHMARK] faster.past | median: 75.00 µs | allocations: 10.00",
    ]

    // when: comparing them with a threshold of 20%
    let report = compare(base: base, head: head)

    // then: only a change past the threshold counts, and a slower time warns without failing, as time depends on the
    // machine's load
    expect(report.rows.map(\.findings)) == [[], [.slower], [.faster]]
    expect(report.warningCount) == 1
    expect(report.passes) == true
  }

  func test_compare_newAndRemovedBenchmarks() {
    // given: a benchmark on both sides, one only the head has, and one only the base has
    let base = [
      "[BENCHMARK] gone | median: 1.00 µs | allocations: 1.00",
      "[BENCHMARK] kept | median: 1.00 µs | allocations: 1.00",
    ]
    let head = [
      "[BENCHMARK] kept | median: 1.00 µs | allocations: 1.00",
      "[BENCHMARK] fresh | median: 1.00 µs | allocations: 1.00",
    ]

    // when: comparing them
    let report = compare(base: base, head: head)

    // then: the head's benchmarks come first, in its order, then the removed ones, and neither a new nor a removed
    // benchmark fails the comparison
    expect(report.rows.map(\.name)) == ["kept", "fresh", "gone"]
    expect(report.rows.map(\.markdown)) == [
      "| kept | 1.00 → 1.00 (+0.0%) | n/a | 1 → 1 | ok |",
      "| fresh | | | | new |",
      "| gone | | | | removed |",
    ]
    expect(report.passes) == true
  }

  func test_compare_onlyNewAndRemovedBenchmarks_isInconclusive() {
    // given: a base and a head that share no benchmark
    let base = ["[BENCHMARK] gone | median: 1.00 µs | instructions: 10 | allocations: 1.00"]
    let head = ["[BENCHMARK] fresh | median: 1.00 µs | instructions: 10 | allocations: 1.00"]

    // when: comparing them
    let report = compare(base: base, head: head)

    // then: nothing is compared, so the comparison is inconclusive and fails
    expect(report.passes) == false
    expect(report.markdown) == """
    | Benchmark | Time (µs) | Instructions | Allocations | Result |
    |---|---|---|---|---|
    | fresh | | | | new |
    | gone | | | | removed |

    2 benchmarks: 0 regressions, 0 time warnings.
    🛑 Inconclusive: no benchmark has allocations or instructions on both sides to compare.
    """

    // when: comparing the head with a base without results
    let reportWithoutBase = compare(base: [], head: head)

    // then: the comparison is inconclusive too
    expect(reportWithoutBase.rows.map(\.markdown)) == ["| fresh | | | | new |"]
    expect(reportWithoutBase.passes) == false
  }

  func test_compare_onlyTimes_isInconclusive() {
    // given: a benchmark whose rounds counted neither allocations nor instructions, and that got slower
    let base = ["[BENCHMARK] scroll | median: 10.00 µs | instructions: n/a | allocations: n/a"]
    let head = ["[BENCHMARK] scroll | median: 13.00 µs | instructions: n/a | allocations: n/a"]

    // when: comparing them
    let report = compare(base: base, head: head)

    // then: the time warns, but a time can't regress, so the comparison is inconclusive and fails
    expect(report.passes) == false
    expect(report.markdown) == """
    | Benchmark | Time (µs) | Instructions | Allocations | Result |
    |---|---|---|---|---|
    | scroll | 10.00 → 13.00 (+30.0%) | n/a | n/a | warning: time |

    1 benchmark: 0 regressions, 1 time warning.
    Instructions weren't counted, as this machine doesn't expose the CPU's counters.
    🛑 Inconclusive: no benchmark has allocations or instructions on both sides to compare.
    """
  }

  func test_compare_benchmarkWithoutACostOnBothSides_isNotCompared() {
    // given: a benchmark with allocations on both sides, one that reports only measures of its own, and one whose head
    // didn't count its allocations
    let base = [
      "[BENCHMARK] steady | allocations: 5.00",
      "[BENCHMARK] scroll.text.alloc | textViewCreations: 74 | reuses: 60",
      "[BENCHMARK] half | allocations: 5.00",
    ]
    let head = [
      "[BENCHMARK] steady | allocations: 5.00",
      "[BENCHMARK] scroll.text.alloc | textViewCreations: 74 | reuses: 60",
      "[BENCHMARK] half | allocations: n/a",
    ]

    // when: comparing them
    let report = compare(base: base, head: head)

    // then: the benchmarks without a cost on both sides show as not compared, and the comparison passes on the other
    expect(report.rows.map(\.markdown)) == [
      "| steady | n/a | n/a | 5 → 5 | ok |",
      "| scroll.text.alloc | n/a | n/a | n/a | not compared |",
      "| half | n/a | n/a | n/a | not compared |",
    ]
    expect(report.passes) == true
  }

  func test_compare_noResults_fails() {
    // when: comparing sides without results
    let report = compare(base: ["Build complete!"], head: [])

    // then: the comparison fails, as it checked nothing
    expect(report.rows.isEmpty) == true
    expect(report.passes) == false
    expect(report.markdown) == "🛑 No benchmark results found."
  }

  // MARK: - Markdown

  func test_markdown_tableAndSummary() {
    // given: benchmarks that keep their costs, cost more of each, cost less of each, take no measurable time, and that are
    // new and removed
    let base = [
      "[BENCHMARK] steady | median: 10.00 µs | instructions: 1000 | allocations: 50.00",
      "[BENCHMARK] heavier | median: 10.00 µs | instructions: 1000 | allocations: 50.00",
      "[BENCHMARK] lighter | median: 10.00 µs | instructions: 1000 | allocations: 50.00",
      "[BENCHMARK] instant | median: 0.00 µs | instructions: 1000 | allocations: 0.00",
      "[BENCHMARK] gone | median: 1.00 µs | instructions: 10 | allocations: 1.00",
    ]
    let head = [
      "[BENCHMARK] steady | median: 10.00 µs | instructions: 1000 | allocations: 50.00",
      "[BENCHMARK] heavier | median: 13.00 µs | instructions: 1100 | allocations: 50.50",
      "[BENCHMARK] lighter | median: 7.00 µs | instructions: 900 | allocations: 49.00",
      "[BENCHMARK] instant | median: 0.00 µs | instructions: 1000 | allocations: 0.00",
      "[BENCHMARK] fresh | median: 1.00 µs | instructions: 10 | allocations: 1.00",
    ]

    // when: comparing them
    let report = compare(base: base, head: head)

    // then: the table shows each cost's change and the findings, and the summary counts them
    expect(report.markdown) == """
    | Benchmark | Time (µs) | Instructions | Allocations | Result |
    |---|---|---|---|---|
    | steady | 10.00 → 10.00 (+0.0%) | 1000 → 1000 (+0.0%) | 50 → 50 | ok |
    | heavier | 10.00 → 13.00 (+30.0%) | 1000 → 1100 (+10.0%) | 50 → 50.50 | warning: time, regression: instructions, regression: allocations |
    | lighter | 10.00 → 7.00 (-30.0%) | 1000 → 900 (-10.0%) | 50 → 49 | faster, fewer instructions, fewer allocations |
    | instant | 0.00 → 0.00 | 1000 → 1000 (+0.0%) | 0 → 0 | ok |
    | fresh | | | | new |
    | gone | | | | removed |

    6 benchmarks: 2 regressions, 1 time warning.
    """
  }

  func test_markdown_jitteringAllocations_andUncountedInstructions() {
    // given: a benchmark whose allocations differ between rounds, on a machine that doesn't count instructions
    let base = [
      "[BENCHMARK] scroll | median: 700.00 µs | instructions: n/a | allocations: 242050.00",
      "[BENCHMARK] scroll | median: 710.00 µs | instructions: n/a | allocations: 242110.00",
    ]
    let head = [
      "[BENCHMARK] scroll | median: 690.00 µs | instructions: n/a | allocations: 242090.50",
      "[BENCHMARK] scroll | median: 700.00 µs | instructions: n/a | allocations: 242090.50",
    ]

    // when: comparing them
    let report = compare(base: base, head: head)

    // then: the allocations show as a range, and the summary notes that instructions weren't counted
    expect(report.markdown) == """
    | Benchmark | Time (µs) | Instructions | Allocations | Result |
    |---|---|---|---|---|
    | scroll | 705.00 → 695.00 (-1.4%) | n/a | 242050 to 242110 → 242090.50 | ok |

    1 benchmark: 0 regressions, 0 time warnings.
    Instructions weren't counted, as this machine doesn't expose the CPU's counters.
    """
  }

  // MARK: - Helpers

  /// Compares the lines of a base and a head with the thresholds `benchmark-compare.sh` uses.
  private func compare(base: [String], head: [String]) -> BenchmarkComparison.Report {
    BenchmarkComparison.compare(
      base: BenchmarkComparison.Results(lines: base),
      head: BenchmarkComparison.Results(lines: head),
      thresholds: BenchmarkComparison.Thresholds(time: 20, instructions: 1)
    )
  }
}
