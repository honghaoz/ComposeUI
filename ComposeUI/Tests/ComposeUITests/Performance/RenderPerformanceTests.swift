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
    // when: scrolling through 10000 flat color rows
    runScrollBenchmark(name: "scroll.flat.10000", rowCount: 10000) { _ in
      ColorNode(.red)
        .frame(width: .flexible, height: Constants.rowHeight)
    }
  }

  func test_scroll_flatRows_1000() {
    // when: scrolling through 1000 flat color rows
    runScrollBenchmark(name: "scroll.flat.1000", rowCount: 1000) { _ in
      ColorNode(.red)
        .frame(width: .flexible, height: Constants.rowHeight)
    }
  }

  func test_scroll_nestedRows_10000() {
    // when: scrolling through 10000 nested rows
    runScrollBenchmark(name: "scroll.nested.10000", rowCount: 10000) { i in
      Self.makeNestedRow(i)
    }
  }

  func test_scroll_nestedRows_10000_up() {
    // when: scrolling up through 10000 nested rows
    // scrolling up makes new rows enter at the back of the z-order, which is the worst case
    // for z-order maintenance: a back insertion invalidates the "already in order" fast path.
    runScrollBenchmark(name: "scroll.nested.10000.up", rowCount: 10000, scrollUp: true) { i in
      Self.makeNestedRow(i)
    }
  }

  func test_scroll_flatSmallRows_5000() {
    // when: scrolling through 5000 flat small rows
    // small rows make many items visible (~105), amplifying the per-item z-order maintenance cost
    runScrollBenchmark(name: "scroll.flatSmall.5000", rowCount: 5000, rowHeight: Constants.smallRowHeight) { _ in
      ColorNode(.red)
        .frame(width: .flexible, height: Constants.smallRowHeight)
    }
  }

  func test_scroll_flatSmallRows_5000_up() {
    // when: scrolling up through 5000 flat small rows
    runScrollBenchmark(name: "scroll.flatSmall.5000.up", rowCount: 5000, rowHeight: Constants.smallRowHeight, scrollUp: true) { _ in
      ColorNode(.red)
        .frame(width: .flexible, height: Constants.smallRowHeight)
    }
  }

  // MARK: - Scroll (view-level, recycle pool's payoff)

  func test_scroll_viewRows_5000() {
    // when: scrolling through 5000 unpooled view rows
    // view-backed rows are expensive to create/tear down (unlike layer-backed `ColorNode`)
    runScrollBenchmark(name: "scroll.viewRows.5000", rowCount: 5000) { _ in
      Self.makeViewRow(pooled: false)
    }
  }

  func test_scroll_viewRowsPooled_5000() {
    // when: scrolling through 5000 pooled view rows
    runScrollBenchmark(name: "scroll.viewRows.pooled.5000", rowCount: 5000) { _ in
      Self.makeViewRow(pooled: true)
    }
  }

  // MARK: - Scroll (shadow nodes, default-pooled, - measure the pooling payoff vs disabled)

  func test_scroll_dropShadowRows_2000_noPool() {
    // when: scrolling through 2000 drop shadow rows without pooling
    // baseline: pooling disabled, so each scrolled-in row creates a fresh `DropShadowLayer` (mask shape layer + setup).
    runScrollBenchmark(name: "scroll.dropShadow.2000.noPool", rowCount: 2000, poolingEnabled: false) { _ in
      Self.makeDropShadowRow()
    }
  }

  func test_scroll_dropShadowRows_2000_pooled() {
    // when: scrolling through 2000 drop shadow rows with pooling
    // DropShadowNode pools by default; leaving rows are recycled instead of recreated.
    runScrollBenchmark(name: "scroll.dropShadow.2000.pooled", rowCount: 2000, poolingEnabled: true) { _ in
      Self.makeDropShadowRow()
    }
  }

  func test_scroll_dropShadowCutoutRows_2000_noPool() {
    // when: scrolling through 2000 drop shadow cutout rows without pooling
    // a cutout installs a `CAShapeLayer` mask, so a fresh layer pays that allocation per scrolled-in row.
    runScrollBenchmark(name: "scroll.dropShadowCutout.2000.noPool", rowCount: 2000, poolingEnabled: false) { _ in
      Self.makeDropShadowCutoutRow()
    }
  }

  func test_scroll_dropShadowCutoutRows_2000_pooled() {
    // when: scrolling through 2000 drop shadow cutout rows with pooling
    // pooling reuses a layer that already has its mask, and the reset detaches it so the recycled layer is clean.
    runScrollBenchmark(name: "scroll.dropShadowCutout.2000.pooled", rowCount: 2000, poolingEnabled: true) { _ in
      Self.makeDropShadowCutoutRow()
    }
  }

  func test_scroll_innerShadowRows_2000_noPool() {
    // when: scrolling through 2000 inner shadow rows without pooling
    runScrollBenchmark(name: "scroll.innerShadow.2000.noPool", rowCount: 2000, poolingEnabled: false) { _ in
      Self.makeInnerShadowRow()
    }
  }

  func test_scroll_innerShadowRows_2000_pooled() {
    // when: scrolling through 2000 inner shadow rows with pooling
    runScrollBenchmark(name: "scroll.innerShadow.2000.pooled", rowCount: 2000, poolingEnabled: true) { _ in
      Self.makeInnerShadowRow()
    }
  }

  // MARK: - Scroll (text views, default-pooled - measure the BaseTextView reuse payoff vs disabled)

  func test_scroll_textRows_2000_noPool() {
    // when: scrolling through 2000 text rows without pooling
    // baseline (pre-reuse behavior): pooling disabled, so each scrolled-in row creates a fresh `BaseTextView`
    // (an NSTextView/UITextView backed by a full TextKit stack), then tears it down when the row leaves.
    runScrollBenchmark(name: "scroll.text.2000.noPool", rowCount: 2000, poolingEnabled: false) { i in
      Self.makeTextRow(i)
    }
  }

  func test_scroll_textRows_2000_pooled() {
    // when: scrolling through 2000 text rows with pooling
    // TextNode pools its `BaseTextView` by default; a leaving row is reset and recycled for an entering row instead of
    // allocating a new text view + TextKit stack. This is the path added by the text-view reuse change.
    runScrollBenchmark(name: "scroll.text.2000.pooled", rowCount: 2000, poolingEnabled: true) { i in
      Self.makeTextRow(i)
    }
  }

  /// Deterministic mechanism metric for the text-view reuse change: how many `BaseTextView` instances are allocated
  /// while scrolling, with vs without pooling.
  ///
  /// The same scroll reveals the same rows in both modes, so the total number of entering inserts is identical; pooling
  /// only changes whether an entering row is served from the pool (a hit) or freshly made (a miss). Instrumenting a
  /// single pooled run therefore yields both figures: total inserts = creations without pooling, misses = creations with
  /// pooling, hits = allocations the pool avoided.
  func test_scroll_textRows_2000_allocationCounts() {
    // given: a compose view with 2000 text rows and a counting pool, rendered for the initial fill
    let pool = CountingRenderablePool()
    let view = ComposeView {
      VStack {
        for i in 0 ..< 2000 {
          Self.makeTextRow(i)
        }
      }
    }
    view.renderablePool = pool
    view.frame = CGRect(origin: .zero, size: Constants.viewSize)
    view.layoutIfNeeded() // initial fill (all misses: pool starts empty)

    // when: scrolling through the rows
    var offset: CGFloat = 0
    for _ in 0 ..< Constants.scrollSteps {
      offset += Constants.scrollStep
      view.setContentOffset(CGPoint(x: 0, y: offset))
      view.layoutIfNeeded()
    }

    // then: report the text view allocation counts with and without pooling
    let creationsNoPool = pool.hitCount + pool.missCount
    let creationsPooled = pool.missCount
    // hits / (hits + misses): the share of entering rows served from the pool, which equals the reduction in
    // text-view allocations that pooling buys.
    let reuseRate = creationsNoPool > 0 ? Double(pool.hitCount) / Double(creationsNoPool) * 100 : 0
    print("[BENCHMARK] scroll.text.2000.alloc | textViewCreations.noPool: \(creationsNoPool) | textViewCreations.pooled: \(creationsPooled) | reuses(allocationsAvoided): \(pool.hitCount) | reuseRate(=allocationReduction): \(format(reuseRate))%")
  }

  // MARK: - Renderable Items (node-level, isolates the tree walk + id mapping)

  func test_renderableItems_flatRows_10000() {
    // given: a laid out stack of 10000 flat color rows
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

    // when: measuring renderable items queries across a moving visible window
    let result = measure(warmup: 20, iterations: 500) { i in
      // vary the visible window position to simulate scrolling, using a step that is
      // a non-multiple of row height for varied row churn
      let y = (CGFloat(i) * 977.0).truncatingRemainder(dividingBy: contentHeight - containerSize.height)
      let visibleBounds = CGRect(origin: CGPoint(x: 0, y: y), size: containerSize)
      itemsCount = node.renderableItems(in: visibleBounds).count
    }

    // then: report the timings
    report(name: "renderableItems.flat.10000", result: result, extra: "visibleItems: \(itemsCount)")
  }

  func test_renderableItems_nestedRows_10000() {
    // given: a laid out stack of 10000 nested rows
    var node: any ComposeNode = VStack {
      for i in 0 ..< 10000 {
        Self.makeNestedRow(i)
      }
    }

    let containerSize = Constants.viewSize
    _ = node.layout(containerSize: containerSize, context: ComposeNodeLayoutContext(scaleFactor: 2))

    let contentHeight = node.size.height
    var itemsCount = 0

    // when: measuring renderable items queries across a moving visible window
    let result = measure(warmup: 20, iterations: 500) { i in
      // vary the visible window position to simulate scrolling, using a step that is
      // a non-multiple of row height for varied row churn
      let y = (CGFloat(i) * 977.0).truncatingRemainder(dividingBy: contentHeight - containerSize.height)
      let visibleBounds = CGRect(origin: CGPoint(x: 0, y: y), size: containerSize)
      itemsCount = node.renderableItems(in: visibleBounds).count
    }

    // then: report the timings
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
    // given: profiling is enabled and a compose view with 10000 nested rows is laid out
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

    // when: scrolling continuously for 30 seconds so a sampling profiler can attach
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
    // given: profiling is enabled and a compose view with 10000 flat small color rows is laid out
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

    // when: scrolling continuously for 30 seconds so a sampling profiler can attach
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
    // given: profiling is enabled and a compose view with 10000 view rows, pooled per the REUSE flag, is laid out
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

    // when: scrolling continuously for 30 seconds so a sampling profiler can attach
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
    // given: a compose view with 200 nested rows laid out
    let view = ComposeView {
      VStack {
        for i in 0 ..< 200 {
          Self.makeNestedRow(i)
        }
      }
    }
    view.frame = CGRect(origin: .zero, size: Constants.viewSize)
    view.layoutIfNeeded()

    // when: measuring repeated non-animated refreshes
    let result = measure(warmup: 3, iterations: 30) { _ in
      view.refresh(animated: false)
    }

    // then: report the timings
    report(name: "refresh.nested.200", result: result)
  }

  // MARK: - Helpers

  private enum Constants {
    static let viewSize = CGSize(width: 390, height: 844)
    static let rowHeight: CGFloat = 50
    static let smallRowHeight: CGFloat = 8
    static let scrollStep: CGFloat = 137 // a non-multiple of row height for varied row churn
    static let scrollSteps = 140 // mirrors the timed scroll benchmark's warmup (20) + iterations (120)
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

  /// A drop-shadow row. The `DropShadowLayer` is non-trivial to create (mask shape layer + content scaling setup),
  /// so this sizes the recycle pool's payoff. DropShadowNode pools by default; pooling is toggled at the view level.
  private static func makeDropShadowRow() -> some ComposeNode {
    DropShadowNode(color: .black, opacity: 0.5, radius: 4, offset: CGSize(width: 0, height: 2), path: { renderable in
      CGPath(roundedRect: CGRect(origin: .zero, size: renderable.frame.size), cornerWidth: 8, cornerHeight: 8, transform: nil)
    })
    .frame(width: .flexible, height: Constants.rowHeight)
  }

  /// A drop-shadow row with a cutout path. The cutout installs a `CAShapeLayer` mask on the layer, so an unpooled row
  /// pays the mask allocation per scrolled-in row (unlike the plain drop-shadow row). This sizes the pooling payoff for
  /// the masked case and exercises the cutout-mask reset on the recycle path.
  private static func makeDropShadowCutoutRow() -> some ComposeNode {
    DropShadowNode(color: .black, opacity: 0.5, radius: 4, offset: CGSize(width: 0, height: 2), paths: { renderable in
      let rect = CGRect(origin: .zero, size: renderable.frame.size)
      let shadowPath = CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil)
      let cutoutPath = CGPath(roundedRect: rect.insetBy(dx: 8, dy: 8), cornerWidth: 8, cornerHeight: 8, transform: nil)
      return DropShadowPaths(shadowPath: shadowPath, cutoutPath: cutoutPath)
    })
    .frame(width: .flexible, height: Constants.rowHeight)
  }

  /// A text-backed row. The `BaseTextView` (NSTextView/UITextView with a TextKit stack) is one of the most expensive
  /// renderables to create and tear down, so this sizes the text-view reuse payoff. TextNode pools by default; pooling
  /// is toggled at the view level. The per-row text varies so each recycled view is genuinely reconfigured (not a no-op).
  private static func makeTextRow(_ i: Int) -> some ComposeNode {
    TextNode("Row \(i)")
      .frame(width: .flexible, height: Constants.rowHeight)
  }

  /// An inner-shadow row. Like the drop-shadow row, the `InnerShadowLayer` is non-trivial to create.
  private static func makeInnerShadowRow() -> some ComposeNode {
    InnerShadowNode(color: .black, opacity: 0.5, radius: 4, offset: CGSize(width: 0, height: 2), path: { renderable in
      CGPath(roundedRect: CGRect(origin: .zero, size: renderable.frame.size), cornerWidth: 8, cornerHeight: 8, transform: nil)
    })
    .frame(width: .flexible, height: Constants.rowHeight)
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
                                  poolingEnabled: Bool = true,
                                  makeRow: @escaping (Int) -> any ComposeNode)
  {
    let view = ComposeView {
      VStack {
        for i in 0 ..< rowCount {
          makeRow(i)
        }
      }
    }
    // isolate from the shared pool so each benchmark starts cold; `nil` disables reuse to measure the no-pooling baseline.
    view.renderablePool = poolingEnabled ? RenderablePool() : nil

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

// MARK: - Instrumentation

/// A `RenderablePoolType` that delegates to a real pool while counting reuse hits and misses, used to derive a
/// deterministic allocation count for the text-view reuse benchmark.
private final class CountingRenderablePool: RenderablePoolType {

  private(set) var hitCount = 0
  private(set) var missCount = 0
  private(set) var enqueueCount = 0

  private let backing = RenderablePool()

  func enqueue(_ renderable: Renderable, key: ReuseKey) {
    enqueueCount += 1
    backing.enqueue(renderable, key: key)
  }

  func dequeue(_ key: ReuseKey) -> Renderable? {
    if let renderable = backing.dequeue(key) {
      hitCount += 1
      return renderable
    } else {
      missCount += 1
      return nil
    }
  }
}
