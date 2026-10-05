//
//  benchmark-compare.swift
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

// Compares the benchmark results of a base and a head build, for `benchmark-compare.sh`.
//
// Usage: swift benchmark-compare.swift <results directory> <time threshold %> <instructions threshold %>
//
// The results directory holds `base-<round>.txt` and `head-<round>.txt`, the `[BENCHMARK]` lines of each run. Prints a
// markdown table, and exits with 1 when a benchmark regressed.

import Foundation

/// The costs a benchmark reported in one run.
struct Sample {

  /// The median time of an iteration, in microseconds.
  let time: Double?

  /// The median instructions retired in an iteration.
  let instructions: Double?

  /// The allocations per iteration.
  let allocations: Double?
}

/// Parses a `[BENCHMARK] <name> | <key>: <value> | ...` line.
func parse(_ line: String) -> (name: String, sample: Sample)? {
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

  return (name, Sample(time: microseconds(values["median"]), instructions: number(values["instructions"]), allocations: number(values["allocations"])))
}

/// Reads a number, `nil` for `n/a` or a missing value.
func number(_ value: String?) -> Double? {
  value.flatMap { Double($0) }
}

/// Reads a time such as `12.34 µs` or `1.234 ms`, in microseconds.
func microseconds(_ value: String?) -> Double? {
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

func median(_ values: [Double]) -> Double? {
  guard !values.isEmpty else {
    return nil
  }
  let sorted = values.sorted()
  let middle = sorted.count / 2
  return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
}

/// The samples of a benchmark over the rounds of one side.
struct Samples {

  private(set) var times: [Double] = []
  private(set) var instructions: [Double] = []
  private(set) var allocations: [Double] = []
  private(set) var count = 0

  mutating func append(_ sample: Sample) {
    count += 1
    sample.time.map { times.append($0) }
    sample.instructions.map { instructions.append($0) }
    sample.allocations.map { allocations.append($0) }
  }

  /// The median instructions, `nil` unless every round counted them.
  var medianInstructions: Double? {
    instructions.count == count ? median(instructions) : nil
  }
}

/// Reads the samples of each benchmark from the result files of one side, keeping the order the benchmarks ran in.
func readSamples(side: String, in directory: URL) throws -> (order: [String], samples: [String: Samples]) {
  let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    .filter { $0.lastPathComponent.hasPrefix("\(side)-") && $0.pathExtension == "txt" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

  var order: [String] = []
  var samples: [String: Samples] = [:]
  for file in files {
    for line in try String(contentsOf: file, encoding: .utf8).split(separator: "\n") {
      guard let parsed = parse(String(line)) else {
        continue
      }
      if samples[parsed.name] == nil {
        order.append(parsed.name)
      }
      samples[parsed.name, default: Samples()].append(parsed.sample)
    }
  }
  return (order, samples)
}

/// The change from the base to the head, in percent, `nil` for a base of zero.
func percentChange(from base: Double, to head: Double) -> Double? {
  base > 0 ? (head - base) / base * 100 : nil
}

func formatChange(_ change: Double?) -> String {
  change.map { String(format: " (%+.1f%%)", $0) } ?? ""
}

/// Formats an allocation count, or the range of counts when the rounds differed.
func formatAllocations(_ values: [Double]) -> String {
  guard let lowest = values.min(), let highest = values.max() else {
    return "n/a"
  }
  func format(_ value: Double) -> String {
    value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.2f", value)
  }
  return lowest == highest ? format(lowest) : "\(format(lowest)) to \(format(highest))"
}

// MARK: - Main

let arguments = CommandLine.arguments
guard arguments.count == 4, let timeThreshold = Double(arguments[2]), let instructionsThreshold = Double(arguments[3]) else {
  print("usage: swift benchmark-compare.swift <results directory> <time threshold %> <instructions threshold %>")
  exit(2)
}

let directory = URL(fileURLWithPath: arguments[1])
let base = try readSamples(side: "base", in: directory)
let head = try readSamples(side: "head", in: directory)

let names = head.order + base.order.filter { head.samples[$0] == nil }
guard !names.isEmpty else {
  print("🛑 No benchmark results found.")
  exit(1)
}

var regressions = 0
var warnings = 0
var hasInstructions = false

print("| Benchmark | Time (µs) | Instructions | Allocations | Result |")
print("|---|---|---|---|---|")
for name in names {
  guard let headSamples = head.samples[name] else {
    print("| \(name) | | | | removed |")
    continue
  }
  guard let baseSamples = base.samples[name] else {
    print("| \(name) | | | | new |")
    continue
  }

  var results: [String] = []

  var timeCell = "n/a"
  if let baseTime = median(baseSamples.times), let headTime = median(headSamples.times) {
    let change = percentChange(from: baseTime, to: headTime)
    timeCell = String(format: "%.2f → %.2f", baseTime, headTime) + formatChange(change)
    if let change, change > timeThreshold {
      results.append("warning: time")
      warnings += 1
    } else if let change, change < -timeThreshold {
      results.append("faster")
    }
  }

  var instructionsCell = "n/a"
  if let baseInstructions = baseSamples.medianInstructions, let headInstructions = headSamples.medianInstructions {
    hasInstructions = true
    let change = percentChange(from: baseInstructions, to: headInstructions)
    instructionsCell = String(format: "%.0f → %.0f", baseInstructions, headInstructions) + formatChange(change)
    if let change, change > instructionsThreshold {
      results.append("regression: instructions")
      regressions += 1
    } else if let change, change < -instructionsThreshold {
      results.append("fewer instructions")
    }
  }

  var allocationsCell = "n/a"
  if let baseLowest = baseSamples.allocations.min(), let baseHighest = baseSamples.allocations.max(),
     let headLowest = headSamples.allocations.min(), let headHighest = headSamples.allocations.max()
  {
    allocationsCell = "\(formatAllocations(baseSamples.allocations)) → \(formatAllocations(headSamples.allocations))"
    // the counts are exact for code that runs only ComposeUI, and vary slightly between rounds for code through the
    // system frameworks, so the head regresses only when it allocates more in every round than the base did in any
    if headLowest > baseHighest {
      results.append("regression: allocations")
      regressions += 1
    } else if headHighest < baseLowest {
      results.append("fewer allocations")
    }
  }

  print("| \(name) | \(timeCell) | \(instructionsCell) | \(allocationsCell) | \(results.isEmpty ? "ok" : results.joined(separator: ", ")) |")
}

func counted(_ count: Int, _ noun: String) -> String {
  "\(count) \(noun)\(count == 1 ? "" : "s")"
}

print("")
print("\(counted(names.count, "benchmark")): \(counted(regressions, "regression")), \(counted(warnings, "time warning")).")
if !hasInstructions {
  print("Instructions weren't counted, as this machine doesn't expose the CPU's counters.")
}

exit(regressions > 0 ? 1 : 0)
