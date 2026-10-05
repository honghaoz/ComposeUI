//
//  BenchmarkComparison.swift
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

import Foundation

/// Compares the benchmark results of a base build and a head build, for `scripts/benchmark-compare.sh`.
///
/// The test target compiles this file to test it, and the script compiles it with its entry point,
/// `scripts/benchmark-compare.swift`, so it uses Foundation only.
enum BenchmarkComparison {

  /// The changes, in percent, past which a comparison reports a cost.
  struct Thresholds {

    /// The slowdown past which the time warns.
    let time: Double

    /// The increase past which the instructions regress.
    let instructions: Double
  }

  /// The costs a benchmark reported in one run, `nil` for a cost it didn't report.
  struct Sample: Equatable {

    /// The median time of an iteration, in microseconds.
    let time: Double?

    /// The median instructions retired in an iteration.
    let instructions: Double?

    /// The allocations per iteration.
    let allocations: Double?
  }

  /// Parses a `[BENCHMARK] <name> | <key>: <value> | ...` line, which `BenchmarkTestCase.report(name:result:extra:)`
  /// prints.
  ///
  /// - Parameter line: The line.
  /// - Returns: The benchmark's name and costs, `nil` for a line that isn't a benchmark result.
  static func parse(_ line: String) -> (name: String, sample: Sample)? {
    let prefix = "[BENCHMARK] "
    guard line.hasPrefix(prefix) else {
      return nil
    }

    let fields = line.dropFirst(prefix.count).components(separatedBy: " | ")
    guard let name = fields.first, !name.isEmpty else {
      return nil
    }

    var values: [String: String] = [:]
    for field in fields.dropFirst() {
      guard let separator = field.range(of: ": ") else {
        continue
      }
      values[String(field[..<separator.lowerBound])] = String(field[separator.upperBound...])
    }

    let sample = Sample(time: microseconds(values["median"]), instructions: number(values["instructions"]), allocations: number(values["allocations"]))
    return (name, sample)
  }

  /// Reads a number, `nil` for `n/a` or a missing value.
  private static func number(_ value: String?) -> Double? {
    value.flatMap { Double($0) }
  }

  /// Reads a time such as `12.34 µs` or `1.234 ms`, in microseconds, `nil` for anything else.
  private static func microseconds(_ value: String?) -> Double? {
    guard let parts = value?.split(separator: " "), parts.count == 2, let amount = Double(parts[0]) else {
      return nil
    }
    switch parts[1] {
    case "µs":
      return amount
    case "ms":
      return amount * 1000
    default:
      return nil
    }
  }

  /// Returns the median of the values, `nil` for no values.
  static func median(_ values: [Double]) -> Double? {
    guard !values.isEmpty else {
      return nil
    }
    let sorted = values.sorted()
    let middle = sorted.count / 2
    return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
  }

  /// The change from the base to the head, in percent, `nil` for a base of zero.
  static func percentChange(from base: Double, to head: Double) -> Double? {
    base > 0 ? (head - base) / base * 100 : nil
  }

  // MARK: - Results

  /// The samples of a benchmark over the rounds of one side.
  ///
  /// A cost counts only when every round reported it, since a decision from some rounds wouldn't mean what it says.
  struct Samples {

    /// The number of results, one per round for a benchmark that reported once in every round.
    private(set) var count = 0

    private(set) var times: [Double] = []
    private(set) var instructions: [Double] = []
    private(set) var allocations: [Double] = []

    mutating func append(_ sample: Sample) {
      count += 1
      sample.time.map { times.append($0) }
      sample.instructions.map { instructions.append($0) }
      sample.allocations.map { allocations.append($0) }
    }

    /// The median time, `nil` unless every round reported one.
    var medianTime: Double? {
      times.count == count ? BenchmarkComparison.median(times) : nil
    }

    /// The median instructions, `nil` unless every round counted them.
    var medianInstructions: Double? {
      instructions.count == count ? BenchmarkComparison.median(instructions) : nil
    }

    /// The fewest and the most allocations of a round, `nil` unless every round counted them.
    var allocationRange: ClosedRange<Double>? {
      guard allocations.count == count, let lowest = allocations.min(), let highest = allocations.max() else {
        return nil
      }
      return lowest ... highest
    }
  }

  /// The samples of each benchmark of one side, in the order the benchmarks first reported.
  struct Results {

    private(set) var names: [String] = []
    private(set) var samples: [String: Samples] = [:]

    /// The benchmarks that didn't report exactly once in every round, such as one skipped in a round, or two benchmarks
    /// that report under one name, whose samples don't stand for the rounds.
    private(set) var irregularNames: Set<String> = []

    /// Reads the results of one side from the lines each of its rounds printed, skipping the lines that aren't results.
    ///
    /// - Parameter rounds: The lines of each round of the side.
    init(rounds: [[String]]) {
      for lines in rounds {
        var reportedNames: Set<String> = []
        for line in lines {
          guard let parsed = BenchmarkComparison.parse(line) else {
            continue
          }
          if samples[parsed.name] == nil {
            names.append(parsed.name)
          }
          if !reportedNames.insert(parsed.name).inserted {
            irregularNames.insert(parsed.name)
          }
          samples[parsed.name, default: Samples()].append(parsed.sample)
        }
      }
      for (name, benchmarkSamples) in samples where benchmarkSamples.count != rounds.count {
        irregularNames.insert(name)
      }
    }

    /// Reads the results of one side from the result files of its rounds, `<side>-<round>.txt` in the directory.
    ///
    /// - Parameters:
    ///   - side: The side, `base` or `head`.
    ///   - directory: The directory of the result files.
    init(side: String, in directory: URL) throws {
      let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .filter { $0.lastPathComponent.hasPrefix("\(side)-") && $0.pathExtension == "txt" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
      try self.init(rounds: files.map { try String(contentsOf: $0, encoding: .utf8).components(separatedBy: "\n") })
    }
  }

  // MARK: - Comparison

  /// What a comparison found about a benchmark.
  enum Finding: Equatable {

    /// The head allocates more in every round than the base did in any.
    case moreAllocations

    /// The head allocates less in every round than the base did in any.
    case fewerAllocations

    /// The head retires more instructions than the threshold allows.
    case moreInstructions

    /// The head retires fewer instructions, by more than the threshold.
    case fewerInstructions

    /// The head is slower than the threshold allows.
    case slower

    /// The head is faster, by more than the threshold.
    case faster

    /// Whether the finding fails the comparison. Time only warns, since it depends on the machine's load.
    var isRegression: Bool {
      switch self {
      case .moreAllocations,
           .moreInstructions:
        return true
      case .fewerAllocations,
           .fewerInstructions,
           .slower,
           .faster:
        return false
      }
    }

    var text: String {
      switch self {
      case .moreAllocations:
        return "regression: allocations"
      case .fewerAllocations:
        return "fewer allocations"
      case .moreInstructions:
        return "regression: instructions"
      case .fewerInstructions:
        return "fewer instructions"
      case .slower:
        return "warning: time"
      case .faster:
        return "faster"
      }
    }
  }

  /// The comparison of one benchmark, which only the base or only the head has when it's removed or new.
  struct Row {

    let name: String
    let base: Samples?
    let head: Samples?

    /// Whether a side didn't report the benchmark exactly once in every round, which leaves it out of the comparison.
    let isIrregular: Bool

    let findings: [Finding]

    /// Whether the base and the head both have a cost that can regress: the allocations or the instructions.
    var canRegress: Bool {
      guard !isIrregular, let base, let head else {
        return false
      }
      return (base.allocationRange != nil && head.allocationRange != nil) || (base.medianInstructions != nil && head.medianInstructions != nil)
    }

    var markdown: String {
      guard !isIrregular else {
        return "| \(name) | | | | not reported once per round |"
      }
      guard let head else {
        return "| \(name) | | | | removed |"
      }
      guard let base else {
        return "| \(name) | | | | new |"
      }

      let time = BenchmarkComparison.formatChange(from: base.medianTime, to: head.medianTime, format: "%.2f")
      let instructions = BenchmarkComparison.formatChange(from: base.medianInstructions, to: head.medianInstructions, format: "%.0f")
      var allocations = "n/a"
      if let baseRange = base.allocationRange, let headRange = head.allocationRange {
        allocations = "\(BenchmarkComparison.format(baseRange)) → \(BenchmarkComparison.format(headRange))"
      }

      // a benchmark can report none of the costs, only measures of its own, or a cost on one side only, and then there
      // is nothing to compare, which "ok" would hide
      let isCompared = canRegress || (base.medianTime != nil && head.medianTime != nil)
      let result: String
      if !isCompared {
        result = "not compared"
      } else if findings.isEmpty {
        result = "ok"
      } else {
        result = findings.map(\.text).joined(separator: ", ")
      }
      return "| \(name) | \(time) | \(instructions) | \(allocations) | \(result) |"
    }
  }

  /// The comparison of all benchmarks.
  struct Report {

    let rows: [Row]

    var regressionCount: Int {
      rows.reduce(0) { count, row in count + row.findings.filter(\.isRegression).count }
    }

    var warningCount: Int {
      rows.reduce(0) { count, row in count + row.findings.filter { $0 == .slower }.count }
    }

    /// Whether any round counted instructions, which none does on a machine that doesn't expose the CPU's counters.
    var countsInstructions: Bool {
      rows.contains { $0.base?.instructions.isEmpty == false || $0.head?.instructions.isEmpty == false }
    }

    /// Whether any benchmark can regress. Without one, a comparison that finds no regression hasn't checked anything.
    var checksRegressions: Bool {
      rows.contains(where: \.canRegress)
    }

    /// The number of benchmarks that a side didn't report exactly once in every round.
    var irregularCount: Int {
      rows.filter(\.isIrregular).count
    }

    /// Whether the comparison passes: a benchmark can regress, none did, and every benchmark reported once per round.
    var passes: Bool {
      checksRegressions && regressionCount == 0 && irregularCount == 0
    }

    /// The table and a summary, in markdown.
    var markdown: String {
      guard !rows.isEmpty else {
        return "🛑 No benchmark results found."
      }

      var lines = [
        "| Benchmark | Time (µs) | Instructions | Allocations | Result |",
        "|---|---|---|---|---|",
      ]
      lines += rows.map(\.markdown)
      lines.append("")
      lines.append("\(Self.counted(rows.count, "benchmark")): \(Self.counted(regressionCount, "regression")), \(Self.counted(warningCount, "time warning")).")
      if irregularCount > 0 {
        lines.append("🛑 \(Self.counted(irregularCount, "benchmark")) didn't report exactly once in every round, so \(irregularCount == 1 ? "it wasn't" : "they weren't") compared.")
      }
      if !countsInstructions {
        lines.append("Instructions weren't counted, as this machine doesn't expose the CPU's counters.")
      }
      if !checksRegressions {
        lines.append("🛑 Inconclusive: no benchmark has allocations or instructions on both sides to compare.")
      }
      return lines.joined(separator: "\n")
    }

    private static func counted(_ count: Int, _ noun: String) -> String {
      "\(count) \(noun)\(count == 1 ? "" : "s")"
    }
  }

  /// Compares the head's results with the base's.
  ///
  /// - Parameters:
  ///   - base: The base's results.
  ///   - head: The head's results.
  ///   - thresholds: The changes past which a cost is reported.
  /// - Returns: The comparison of each benchmark, in the head's order, followed by the benchmarks only the base has.
  static func compare(base: Results, head: Results, thresholds: Thresholds) -> Report {
    let names = head.names + base.names.filter { head.samples[$0] == nil }
    let rows = names.map { name in
      let baseSamples = base.samples[name]
      let headSamples = head.samples[name]
      let isIrregular = base.irregularNames.contains(name) || head.irregularNames.contains(name)
      return Row(
        name: name,
        base: baseSamples,
        head: headSamples,
        isIrregular: isIrregular,
        findings: isIrregular ? [] : findings(base: baseSamples, head: headSamples, thresholds: thresholds)
      )
    }
    return Report(rows: rows)
  }

  private static func findings(base: Samples?, head: Samples?, thresholds: Thresholds) -> [Finding] {
    guard let base, let head else {
      return []
    }

    var findings: [Finding] = []
    if let baseTime = base.medianTime, let headTime = head.medianTime, let change = percentChange(from: baseTime, to: headTime) {
      if change > thresholds.time {
        findings.append(.slower)
      } else if change < -thresholds.time {
        findings.append(.faster)
      }
    }
    if let baseInstructions = base.medianInstructions, let headInstructions = head.medianInstructions,
       let change = percentChange(from: baseInstructions, to: headInstructions)
    {
      if change > thresholds.instructions {
        findings.append(.moreInstructions)
      } else if change < -thresholds.instructions {
        findings.append(.fewerInstructions)
      }
    }
    if let baseRange = base.allocationRange, let headRange = head.allocationRange {
      // the counts are exact for code that runs only ComposeUI, and vary slightly between rounds for code through the
      // system frameworks, so only counts outside the base's range are a change
      if headRange.lowerBound > baseRange.upperBound {
        findings.append(.moreAllocations)
      } else if headRange.upperBound < baseRange.lowerBound {
        findings.append(.fewerAllocations)
      }
    }
    return findings
  }

  // MARK: - Formatting

  /// Formats a change of a cost as `base → head (+x.x%)`, `n/a` unless both sides have the cost.
  private static func formatChange(from base: Double?, to head: Double?, format: String) -> String {
    guard let base, let head else {
      return "n/a"
    }
    let change = percentChange(from: base, to: head).map { String(format: " (%+.1f%%)", $0) } ?? ""
    return "\(String(format: format, base)) → \(String(format: format, head))\(change)"
  }

  /// Formats a range of allocation counts, as one count when the rounds agree.
  private static func format(_ range: ClosedRange<Double>) -> String {
    func formatCount(_ count: Double) -> String {
      count.rounded() == count ? String(format: "%.0f", count) : String(format: "%.2f", count)
    }
    return range.lowerBound == range.upperBound ? formatCount(range.lowerBound) : "\(formatCount(range.lowerBound)) to \(formatCount(range.upperBound))"
  }
}
