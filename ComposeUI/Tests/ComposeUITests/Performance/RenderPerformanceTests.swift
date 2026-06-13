//
//  RenderPerformanceTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 6/11/26.
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

/// Render path benchmarks.
///
/// These tests are skipped by default. To run them:
///
/// ```bash
/// cd ComposeUI && BENCHMARK=1 swift test -c release -Xswiftc -enable-testing -Xswiftc -DDEBUG --filter RenderPerformanceTests
/// ```
///
/// Run in release configuration for meaningful numbers. `-DDEBUG` is required because the test
/// target depends on debug-only test hooks; note this also compiles in the render path's debug
/// assertions and event callbacks, so numbers include some debug instrumentation overhead.
class RenderPerformanceTests: XCTestCase {

  override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipUnless(ProcessInfo.processInfo.environment["BENCHMARK"] == "1", "benchmarks are skipped by default, run with BENCHMARK=1")
  }

  // MARK: - Scroll (view-level, full render pass per scroll step)

  func test_scroll_flatRows_10000() {
    runScrollBenchmark(name: "scroll.flat.10000", rowCount: 10000) { _ in
      ColorNode(.red)
        .frame(width: .flexible, height: Constants.rowHeight)
    }
  }

  func test_scroll_flatRows_1000() {
    runScrollBenchmark(name: "scroll.flat.1000", rowCount: 1000) { _ in
      ColorNode(.red)
        .frame(width: .flexible, height: Constants.rowHeight)
    }
  }

  func test_scroll_nestedRows_10000() {
    runScrollBenchmark(name: "scroll.nested.10000", rowCount: 10000) { i in
      Self.makeNestedRow(i)
    }
  }

  func test_scroll_nestedRows_10000_up() {
    // scrolling up makes new rows enter at the back of the z-order, which is the worst case
    // for z-order maintenance: a back insertion invalidates the "already in order" fast path.
    runScrollBenchmark(name: "scroll.nested.10000.up", rowCount: 10000, scrollUp: true) { i in
      Self.makeNestedRow(i)
    }
  }

  func test_scroll_flatSmallRows_5000() {
    // small rows make many items visible (~105), amplifying the per-item z-order maintenance cost
    runScrollBenchmark(name: "scroll.flatSmall.5000", rowCount: 5000, rowHeight: Constants.smallRowHeight) { _ in
      ColorNode(.red)
        .frame(width: .flexible, height: Constants.smallRowHeight)
    }
  }

  func test_scroll_flatSmallRows_5000_up() {
    runScrollBenchmark(name: "scroll.flatSmall.5000.up", rowCount: 5000, rowHeight: Constants.smallRowHeight, scrollUp: true) { _ in
      ColorNode(.red)
        .frame(width: .flexible, height: Constants.smallRowHeight)
    }
  }

  // MARK: - Scroll (view-level, recycle pool's payoff)

  func test_scroll_viewRows_5000() {
    // view-backed rows are expensive to create/tear down (unlike layer-backed `ColorNode`)
    runScrollBenchmark(name: "scroll.viewRows.5000", rowCount: 5000) { _ in
      Self.makeViewRow(pooled: false)
    }
  }

  func test_scroll_viewRowsPooled_5000() {
    runScrollBenchmark(name: "scroll.viewRows.pooled.5000", rowCount: 5000) { _ in
      Self.makeViewRow(pooled: true)
    }
  }

  // MARK: - Renderable Items (node-level, isolates the tree walk + id mapping)

  func test_renderableItems_flatRows_10000() {
    var node: any ComposeNode = VStack {
      for _ in 0 ..< 10000 {
        ColorNode(.red)
          .frame(width: .flexible, height: Constants.rowHeight)
      }
    }

    let containerSize = Constants.viewSize
    _ = node.layout(containerSize: containerSize, context: ComposeNodeLayoutContext(scaleFactor: 2))

    let contentHeight = node.size.height
    var itemsCount = 0

    let result = measure(warmup: 20, iterations: 500) { i in
      // vary the visible window position to simulate scrolling, using a step that is
      // a non-multiple of row height for varied row churn
      let y = (CGFloat(i) * 977.0).truncatingRemainder(dividingBy: contentHeight - containerSize.height)
      let visibleBounds = CGRect(origin: CGPoint(x: 0, y: y), size: containerSize)
      itemsCount = node.renderableItems(in: visibleBounds).count
    }

    report(name: "renderableItems.flat.10000", result: result, extra: "visibleItems: \(itemsCount)")
  }

  func test_renderableItems_nestedRows_10000() {
    var node: any ComposeNode = VStack {
      for i in 0 ..< 10000 {
        Self.makeNestedRow(i)
      }
    }

    let containerSize = Constants.viewSize
    _ = node.layout(containerSize: containerSize, context: ComposeNodeLayoutContext(scaleFactor: 2))

    let contentHeight = node.size.height
    var itemsCount = 0

    let result = measure(warmup: 20, iterations: 500) { i in
      // vary the visible window position to simulate scrolling, using a step that is
      // a non-multiple of row height for varied row churn
      let y = (CGFloat(i) * 977.0).truncatingRemainder(dividingBy: contentHeight - containerSize.height)
      let visibleBounds = CGRect(origin: CGPoint(x: 0, y: y), size: containerSize)
      itemsCount = node.renderableItems(in: visibleBounds).count
    }

    report(name: "renderableItems.nested.10000", result: result, extra: "visibleItems: \(itemsCount)")
  }

  // MARK: - Profile

  /// A long-running scroll loop for attaching a sampling profiler.
  ///
  /// ```bash
  /// BENCHMARK=1 PROFILE=1 swift test -c debug -Xswiftc -O --filter RenderPerformanceTests/test_profile_scroll_nested &
  /// sleep 20 && sample $(pgrep -f ComposeUIPackageTests | head -1) 8 -file /tmp/scroll_profile.txt
  /// ```
  func test_profile_scroll_nested() throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["PROFILE"] == "1", "profiling is skipped by default, run with PROFILE=1")

    let view = ComposeView {
      VStack {
        for i in 0 ..< 10000 {
          Self.makeNestedRow(i)
        }
      }
    }
    view.frame = CGRect(origin: .zero, size: Constants.viewSize)
    view.layoutIfNeeded()

    print("[PROFILE] pid: \(ProcessInfo.processInfo.processIdentifier), scrolling for 30s...")

    var offset: CGFloat = 0
    let maxOffset = view.contentSize().height - Constants.viewSize.height - 1000
    let deadline = Date().addingTimeInterval(30)
    while Date() < deadline {
      offset += Constants.scrollStep
      if offset > maxOffset {
        offset = 0
      }
      view.setContentOffset(CGPoint(x: 0, y: offset))
      view.layoutIfNeeded()
    }
  }

  /// A long-running pure-layer scroll loop for attaching a sampling profiler.
  ///
  /// Unlike `test_profile_scroll_nested`, this uses flat `ColorNode` (layer-backed) rows with no
  /// labels/text views, so the sample isolates the ComposeUI-controlled steady-state cost (the
  /// per-item `RenderItem` build + `eraseToRenderableItem` closure allocation + per-pass dictionary
  /// rebuild) without `NSTextView` layout noise. Small rows are used to maximize the visible item
  /// count (~107), which amplifies the per-item allocation churn we want to size.
  ///
  /// ```bash
  /// BENCHMARK=1 PROFILE=1 swift test -c debug -Xswiftc -O --filter RenderPerformanceTests/test_profile_scroll_flatLayers &
  /// sleep 20 && sample $(pgrep -f ComposeUIPackageTests | head -1) 8 -file /tmp/scroll_flat_profile.txt
  /// ```
  func test_profile_scroll_flatLayers() throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["PROFILE"] == "1", "profiling is skipped by default, run with PROFILE=1")

    let view = ComposeView {
      VStack {
        for _ in 0 ..< 10000 {
          ColorNode(.red)
            .frame(width: .flexible, height: Constants.smallRowHeight)
        }
      }
    }
    view.frame = CGRect(origin: .zero, size: Constants.viewSize)
    view.layoutIfNeeded()

    print("[PROFILE] pid: \(ProcessInfo.processInfo.processIdentifier), scrolling for 30s...")

    var offset: CGFloat = 0
    let maxOffset = view.contentSize().height - Constants.viewSize.height - 1000
    let deadline = Date().addingTimeInterval(30)
    while Date() < deadline {
      offset += Constants.scrollStep
      if offset > maxOffset {
        offset = 0
      }
      view.setContentOffset(CGPoint(x: 0, y: offset))
      view.layoutIfNeeded()
    }
  }

  /// A long-running view-backed scroll loop for attaching a sampling profiler.
  ///
  /// Uses plain view rows (expensive to create, unlike layer-backed `ColorNode`) to size the recycle pool's effect.
  /// Set `REUSE=1` to opt the rows into the pool; leave it unset to profile the baseline (a fresh view per scrolled-in
  /// row).
  ///
  /// ```bash
  /// BENCHMARK=1 PROFILE=1 REUSE=1 swift test -c debug -Xswiftc -O --filter RenderPerformanceTests/test_profile_scroll_viewRows &
  /// sleep 20 && sample $(pgrep -f ComposeUIPackageTests | head -1) 8 -file /tmp/scroll_view_profile.txt
  /// ```
  func test_profile_scroll_viewRows() throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["PROFILE"] == "1", "profiling is skipped by default, run with PROFILE=1")

    let pooled = ProcessInfo.processInfo.environment["REUSE"] == "1"

    let view = ComposeView {
      VStack {
        for _ in 0 ..< 10000 {
          Self.makeViewRow(pooled: pooled)
        }
      }
    }
    view.frame = CGRect(origin: .zero, size: Constants.viewSize)
    view.layoutIfNeeded()

    print("[PROFILE] pid: \(ProcessInfo.processInfo.processIdentifier), pooled: \(pooled), scrolling for 30s...")

    var offset: CGFloat = 0
    let maxOffset = view.contentSize().height - Constants.viewSize.height - 1000
    let deadline = Date().addingTimeInterval(30)
    while Date() < deadline {
      offset += Constants.scrollStep
      if offset > maxOffset {
        offset = 0
      }
      view.setContentOffset(CGPoint(x: 0, y: offset))
      view.layoutIfNeeded()
    }
  }

  // MARK: - Refresh (view-level, content rebuild + layout incl. text measurement)

  func test_refresh_nestedRows_200() {
    let view = ComposeView {
      VStack {
        for i in 0 ..< 200 {
          Self.makeNestedRow(i)
        }
      }
    }
    view.frame = CGRect(origin: .zero, size: Constants.viewSize)
    view.layoutIfNeeded()

    let result = measure(warmup: 3, iterations: 30) { _ in
      view.refresh(animated: false)
    }

    report(name: "refresh.nested.200", result: result)
  }

  // MARK: - Helpers

  private enum Constants {
    static let viewSize = CGSize(width: 390, height: 844)
    static let rowHeight: CGFloat = 50
    static let smallRowHeight: CGFloat = 8
    static let scrollStep: CGFloat = 137 // a non-multiple of row height for varied row churn
  }

  /// A plain view-backed row, optionally opted into the recycle pool via `reuseId`.
  private static func makeViewRow(pooled: Bool) -> any ComposeNode {
    let node = ViewNode<View>(make: { context in
      let view = View(frame: context.initialFrame ?? .zero)
      #if canImport(AppKit)
      view.wantsLayer = true
      #endif
      return view
    })
    .frame(width: .flexible, height: Constants.rowHeight)

    if pooled {
      return node.reuseId("viewRow")
    } else {
      return node
    }
  }

  /// A realistic list row: icon + two labels + spacer, with padding.
  private static func makeNestedRow(_ i: Int) -> some ComposeNode {
    HStack(spacing: 8) {
      ColorNode(.blue)
        .frame(width: 32, height: 32)
      VStack(alignment: .left, spacing: 2) {
        LabelNode("Row \(i) title")
        LabelNode("Subtitle for row \(i) with longer text")
      }
      Spacer()
    }
    .padding(8)
  }

  private func runScrollBenchmark(name: String,
                                  rowCount: Int,
                                  rowHeight: CGFloat = Constants.rowHeight,
                                  scrollUp: Bool = false,
                                  makeRow: @escaping (Int) -> any ComposeNode)
  {
    let view = ComposeView {
      VStack {
        for i in 0 ..< rowCount {
          makeRow(i)
        }
      }
    }

    view.frame = CGRect(origin: .zero, size: Constants.viewSize)

    let setupStart = DispatchTime.now()
    view.layoutIfNeeded() // initial render
    let setupDuration = durationInMilliseconds(from: setupStart, to: DispatchTime.now())

    let maxOffset = CGFloat(rowCount) * rowHeight - Constants.viewSize.height
    var offset: CGFloat = scrollUp ? maxOffset : 0
    let result = measure(warmup: 20, iterations: 120) { _ in
      offset += scrollUp ? -Constants.scrollStep : Constants.scrollStep
      view.setContentOffset(CGPoint(x: 0, y: offset)) // on AppKit, this triggers the render synchronously
      view.layoutIfNeeded() // on UIKit, this triggers the render
    }

    // sample the rendered item count with one extra scroll step, outside of the measured loop,
    // since the debug event handler adds overhead to the render pass.
    var renderedItemsCount = 0
    #if DEBUG
    view.debug { _, event in
      if case .renderDidFinish(let ids, _, _) = event {
        renderedItemsCount = ids.count
      }
    }
    offset += Constants.scrollStep
    view.setContentOffset(CGPoint(x: 0, y: offset))
    view.layoutIfNeeded()
    #endif

    report(name: name, result: result, extra: "initialRender: \(format(setupDuration)) ms | renderedItems: \(renderedItemsCount)")
  }

  // MARK: - Measurement

  private struct BenchmarkResult {
    let durations: [Double] // milliseconds, sorted ascending

    var median: Double { durations[durations.count / 2] }
    var mean: Double { durations.reduce(0, +) / Double(durations.count) }
    var p90: Double { durations[Int(Double(durations.count) * 0.9)] }
    var min: Double { durations.first ?? 0 }
    var max: Double { durations.last ?? 0 }
  }

  private func measure(warmup: Int, iterations: Int, _ block: (Int) -> Void) -> BenchmarkResult {
    for i in 0 ..< warmup {
      block(i)
    }

    var durations: [Double] = []
    durations.reserveCapacity(iterations)

    for i in 0 ..< iterations {
      let start = DispatchTime.now()
      block(warmup + i)
      let end = DispatchTime.now()
      durations.append(durationInMilliseconds(from: start, to: end))
    }

    return BenchmarkResult(durations: durations.sorted())
  }

  private func durationInMilliseconds(from start: DispatchTime, to end: DispatchTime) -> Double {
    Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1000000
  }

  private func report(name: String, result: BenchmarkResult, extra: String? = nil) {
    var line = "[BENCHMARK] \(name) | iterations: \(result.durations.count) | median: \(format(result.median)) ms | mean: \(format(result.mean)) ms | p90: \(format(result.p90)) ms | min: \(format(result.min)) ms | max: \(format(result.max)) ms"
    if let extra {
      line += " | \(extra)"
    }
    print(line)
  }

  private func format(_ value: Double) -> String {
    String(format: "%.3f", value)
  }
}
