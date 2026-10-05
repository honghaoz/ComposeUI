//
//  WorkCounter.swift
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

import Foundation

#if DEBUG

/// Counts work the framework does internally, where tests can't observe it, so that tests can expect exact counts for
/// an operation.
///
/// A count doesn't depend on the machine's speed or load, so a test that expects one passes the same on a fast
/// development machine and on a slow CI runner, unlike a test of time. Work that tests can observe from outside, such as
/// layouts, render passes and renderable inserts, is counted through the existing hooks instead: test nodes, renderable
/// pools and debug events.
///
/// The counter exists in debug builds only, and each call site is wrapped in `#if DEBUG`, so a release build contains
/// none of it regardless of optimization. It only counts work done on the main thread, where the framework works.
enum WorkCounter {

  /// A kind of work.
  enum Work {

    /// A text layout made to measure a text's size, on a text size cache miss.
    case textMeasurement

    /// An animation added to a layer.
    case animation

    /// A step of solving a cubic bezier timing function for the progress at a fraction.
    case bezierSolverStep
  }

  /// Counts work done on the main thread while a block is counted.
  ///
  /// - Parameters:
  ///   - work: The kind of work.
  ///   - amount: The amount of work. Default is 1.
  static func count(_ work: Work, _ amount: Int = 1) {
    // check the depth first, since it's a plain load, and the main thread check is a message send
    guard depth > 0, Thread.isMainThread else {
      return
    }

    switch work {
    case .textMeasurement:
      counts.textMeasurements += amount
    case .animation:
      counts.animations += amount
    case .bezierSolverStep:
      counts.bezierSolverSteps += amount
    }
  }

  /// The work done in a counted block.
  struct Counts {

    /// The text layouts made to measure text sizes.
    fileprivate(set) var textMeasurements = 0

    /// The animations added to layers.
    fileprivate(set) var animations = 0

    /// The steps taken to solve cubic bezier timing functions.
    fileprivate(set) var bezierSolverSteps = 0

    /// Returns the sum of these counts and the other counts.
    fileprivate func adding(_ other: Counts) -> Counts {
      var sum = self
      sum.textMeasurements += other.textMeasurements
      sum.animations += other.animations
      sum.bezierSolverSteps += other.bezierSolverSteps
      return sum
    }
  }

  /// The counts of the innermost counted block.
  private static var counts = Counts()

  /// The number of nested blocks being counted.
  private static var depth = 0

  /// Counts the work done in the block.
  ///
  /// The work of a nested counted block also counts for the enclosing block.
  ///
  /// - Parameter block: The block to count the work of. Must be called on the main thread.
  /// - Returns: The work done in the block.
  static func counting(_ block: () throws -> Void) rethrows -> Counts {
    guard Thread.isMainThread else {
      ComposeUI.assertFailure("counting(_:) must be called on the main thread")
      try block()
      return Counts()
    }

    let outerCounts = counts
    counts = Counts()
    depth += 1
    defer {
      depth -= 1
      counts = outerCounts.adding(counts)
    }

    try block()
    return counts
  }
}

#endif
