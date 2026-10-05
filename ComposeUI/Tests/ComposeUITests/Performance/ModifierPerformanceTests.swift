//
//  ModifierPerformanceTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/27/26.
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

import CoreGraphics
import Foundation

import ChouTiTest

@testable import ComposeUI

/// Modifier chain benchmarks: building, rendering and refreshing rows that each have one modifier chain.
///
/// These tests are skipped by default. To run them:
///
/// ```bash
/// make -C ComposeUI benchmark FILTER=ModifierPerformanceTests
/// ```
///
/// The allocation count includes the allocations freed before the measured work returns, so the gap between the
/// allocations and the retained allocations is the churn.
class ModifierPerformanceTests: BenchmarkTestCase {

  // MARK: - Construction

  func test_construction() {
    for workload in Workload.allCases {
      // when: building the rows
      let result = measure(warmup: Constants.warmup, iterations: Constants.iterations) { _ in
        _ = Self.makeRows(workload, count: Constants.rowCount)
      }
      let retainedMemory = MemoryUsage.retained(by: {
        Self.makeRows(workload, count: Constants.rowCount)
      })

      // then: report the timings and the allocations
      report(
        name: "modifiers.construction.\(workload)",
        result: result,
        extra: perRow(result, retainedMemory: retainedMemory)
      )
    }
  }

  // MARK: - Renderable Items

  func test_renderableItems() {
    for workload in Workload.allCases {
      // given: a laid out stack of rows, all in the visible bounds
      var node: any ComposeNode = VStack {
        for _ in 0 ..< Constants.rowCount {
          Self.makeRow(workload)
        }
      }
      _ = node.layout(containerSize: Constants.allRowsSize, context: ComposeNodeLayoutContext(scaleFactor: 2))
      let visibleBounds = CGRect(origin: .zero, size: node.size)

      // when: making the render items
      let result = measure(warmup: Constants.warmup, iterations: Constants.iterations) { _ in
        _ = node.renderableItems(in: visibleBounds)
      }

      // then: report the timings and the allocations
      report(name: "modifiers.renderableItems.\(workload)", result: result, extra: perRow(result))
    }
  }

  // MARK: - Refresh

  func test_refresh() {
    for workload in Workload.allCases {
      // given: a compose view showing all the rows
      let view = ComposeView {
        VStack {
          for _ in 0 ..< Constants.rowCount {
            Self.makeRow(workload)
          }
        }
      }
      view.frame = CGRect(origin: .zero, size: Constants.allRowsSize)
      view.refresh(animated: false)

      // when: refreshing without animation, which rebuilds the rows and updates every renderable
      let result = measure(warmup: Constants.warmup, iterations: Constants.iterations) { _ in
        view.refresh(animated: false)
      }

      // then: report the timings and the allocations
      report(name: "modifiers.refresh.\(workload)", result: result, extra: perRow(result))
    }
  }

  func test_refresh_changingValues() {
    // given: a compose view showing rows of four built-in modifiers whose values alternate between two sets
    var isAlternate = false
    let view = ComposeView {
      VStack {
        for _ in 0 ..< Constants.rowCount {
          Self.makeAlternatingRow(isAlternate)
        }
      }
    }
    view.frame = CGRect(origin: .zero, size: Constants.allRowsSize)
    view.refresh(animated: false)

    // when: refreshing without animation with the other values each time, which sets every property of every row
    let result = measure(warmup: Constants.warmup, iterations: Constants.iterations) { _ in
      isAlternate.toggle()
      view.refresh(animated: false)
    }

    // then: report the timings and the allocations
    report(name: "modifiers.refresh.changingValues", result: result, extra: perRow(result))
  }

  func test_refresh_changingValues_whileAnimating() {
    // given: a compose view showing rows of four built-in modifiers whose values alternate between two sets, animating
    // to the other set over a duration longer than the measurement
    var isAlternate = false
    let view = ComposeView {
      VStack {
        for _ in 0 ..< Constants.rowCount {
          Self.makeAlternatingRow(isAlternate)
            .animation(.easeInEaseOut(duration: Constants.longAnimationDuration))
        }
      }
    }
    view.frame = CGRect(origin: .zero, size: Constants.allRowsSize)
    view.refresh(animated: false)
    isAlternate.toggle()
    view.refresh(animated: true)

    // when: refreshing without animation with the other values each time, which continues the in-flight animations
    // toward them. No time passes between the refreshes, so the border width's and the corner radius's additive glides
    // fold into their start values and are set directly, and the colors and the opacity keep animations in flight
    let result = measure(warmup: Constants.warmup, iterations: Constants.iterations) { _ in
      isAlternate.toggle()
      view.refresh(animated: false)
    }

    // then: report the timings and the allocations
    report(name: "modifiers.refresh.changingValues.whileAnimating", result: result, extra: perRow(result))
  }

  // MARK: - Scroll

  func test_scroll() {
    for workload in Workload.allCases {
      // given: a compose view with reusable rows, rendered at the top
      let view = ComposeView {
        VStack {
          for _ in 0 ..< Constants.scrollRowCount {
            Self.makeRow(workload).reuseId("row")
          }
        }
      }
      view.renderablePool = RenderablePool() // isolate from the shared pool so each workload starts cold
      view.frame = CGRect(origin: .zero, size: Constants.scrollViewSize)
      view.layoutIfNeeded()

      // when: scrolling down, which makes the visible rows' render items and reuses the renderables of the rows that
      // leave for the rows that enter
      var offset: CGFloat = 0
      let result = measure(warmup: Constants.scrollWarmup, iterations: Constants.scrollIterations) { _ in
        offset += Constants.scrollStep
        view.contentOffset = CGPoint(x: 0, y: offset) // on AppKit, this triggers the render synchronously
        view.layoutIfNeeded() // on UIKit, this triggers the render
      }

      // then: report the timings and the allocations, per step
      report(name: "modifiers.scroll.\(workload)", result: result)
    }
  }

  // MARK: - Workloads

  private enum Workload: CaseIterable {

    /// A layer without modifiers.
    case zeroModifiers

    /// One built-in modifier.
    case oneModifier

    /// One `onUpdate` callback.
    case oneCallback

    /// Four `onUpdate` callbacks.
    case callbacks

    /// Four built-in modifiers of different properties.
    case distinctModifiers

    /// Four built-in modifiers of one property, of which only the outermost applies.
    case duplicateModifiers

    /// Built-in modifiers and callbacks, interleaved in one chain.
    case mixedChain

    /// Built-in modifiers and callbacks, split by a node the modifiers don't coalesce across.
    case mixedAcrossNodes
  }

  /// A row of four built-in modifiers of different properties, with one of two sets of values.
  private static func makeAlternatingRow(_ isAlternate: Bool) -> some ComposeNode {
    LayerNode()
      .backgroundColor(isAlternate ? .red : .blue)
      .opacity(isAlternate ? 0.5 : 0.6)
      .cornerRadius(isAlternate ? 4 : 6)
      .border(color: isAlternate ? .blue : .red, width: isAlternate ? 1 : 2)
      .frame(width: Constants.rowWidth, height: Constants.rowHeight)
  }

  private static func makeRows(_ workload: Workload, count: Int) -> [any ComposeNode] {
    (0 ..< count).map { _ in makeRow(workload) }
  }

  private static func makeRow(_ workload: Workload) -> any ComposeNode {
    switch workload {
    case .zeroModifiers:
      return LayerNode()
        .frame(width: Constants.rowWidth, height: Constants.rowHeight)
    case .oneModifier:
      return LayerNode()
        .opacity(0.5)
        .frame(width: Constants.rowWidth, height: Constants.rowHeight)
    case .oneCallback:
      return LayerNode()
        .onUpdate { renderable, _ in renderable.layer.name = "one" }
        .frame(width: Constants.rowWidth, height: Constants.rowHeight)
    case .callbacks:
      return LayerNode()
        .onUpdate { renderable, _ in renderable.layer.name = "one" }
        .onUpdate { renderable, _ in renderable.layer.name = "two" }
        .onUpdate { renderable, _ in renderable.layer.name = "three" }
        .onUpdate { renderable, _ in renderable.layer.name = "four" }
        .frame(width: Constants.rowWidth, height: Constants.rowHeight)
    case .distinctModifiers:
      return LayerNode()
        .backgroundColor(.red)
        .opacity(0.5)
        .cornerRadius(4)
        .border(color: .blue, width: 1)
        .frame(width: Constants.rowWidth, height: Constants.rowHeight)
    case .duplicateModifiers:
      return LayerNode()
        .opacity(0.2)
        .opacity(0.4)
        .opacity(0.6)
        .opacity(0.8)
        .frame(width: Constants.rowWidth, height: Constants.rowHeight)
    case .mixedChain:
      return LayerNode()
        .opacity(0.5)
        .onUpdate { renderable, _ in renderable.layer.name = "one" }
        .backgroundColor(.red)
        .onUpdate { renderable, _ in renderable.layer.name = "two" }
        .frame(width: Constants.rowWidth, height: Constants.rowHeight)
    case .mixedAcrossNodes:
      return LayerNode()
        .opacity(0.3)
        .onUpdate { renderable, _ in renderable.layer.name = "one" }
        .padding(1)
        .opacity(0.6)
        .onUpdate { renderable, _ in renderable.layer.name = "two" }
        .frame(width: Constants.rowWidth, height: Constants.rowHeight)
    }
  }

  // MARK: - Measurement

  /// The allocations per row of an iteration over all the rows, and the memory the rows retain per row, as extra
  /// information for a report.
  private func perRow(_ result: BenchmarkResult, retainedMemory: MemoryUsage? = nil) -> String {
    func format(_ value: Double) -> String {
      String(format: "%.2f", value / Double(Constants.rowCount))
    }

    var extra = "allocations per row: \(result.allocationsPerIteration.map(format) ?? "n/a")"
    if let retainedMemory {
      extra += " | retained allocations per row: \(format(Double(retainedMemory.blocks))) | retained bytes per row: \(format(Double(retainedMemory.bytes)))"
    }
    return extra
  }

  // MARK: - Constants

  private enum Constants {

    static let rowCount = 500
    static let rowWidth: CGFloat = 200
    static let rowHeight: CGFloat = 20
    static let allRowsSize = CGSize(width: rowWidth, height: CGFloat(rowCount) * rowHeight)

    static let warmup = 10
    static let iterations = 60

    /// An animation duration that outlasts the measurement, so the animations stay in flight throughout.
    static let longAnimationDuration: TimeInterval = 60

    static let scrollRowCount = 5000
    static let scrollViewSize = CGSize(width: rowWidth, height: 844)
    static let scrollStep: CGFloat = 137 // a non-multiple of the row height for varied row churn
    static let scrollWarmup = 20
    static let scrollIterations = 120
  }
}
