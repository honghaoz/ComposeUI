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

// The entry point of the comparison in `benchmark-compare.sh`, which compiles it with the comparison's logic,
// `Tests/ComposeUITests/Performance/BenchmarkComparison.swift`, where the tests cover it.
//
// Usage: benchmark-compare <results directory> <time threshold %> <instructions threshold %>
//
// The results directory holds `base-<round>.txt` and `head-<round>.txt`, the `[BENCHMARK]` lines of each run. Prints a
// markdown table, and exits with 1 when a benchmark regressed, or when no benchmark has allocations or instructions on
// both sides to compare.

import Foundation

@main
enum BenchmarkCompare {

  static func main() throws {
    let arguments = CommandLine.arguments
    guard arguments.count == 4, let time = Double(arguments[2]), let instructions = Double(arguments[3]) else {
      print("usage: benchmark-compare <results directory> <time threshold %> <instructions threshold %>")
      exit(2)
    }

    let directory = URL(fileURLWithPath: arguments[1])
    let report = try BenchmarkComparison.compare(
      base: BenchmarkComparison.Results(side: "base", in: directory),
      head: BenchmarkComparison.Results(side: "head", in: directory),
      thresholds: BenchmarkComparison.Thresholds(time: time, instructions: instructions)
    )
    print(report.markdown)
    exit(report.passes ? 0 : 1)
  }
}
