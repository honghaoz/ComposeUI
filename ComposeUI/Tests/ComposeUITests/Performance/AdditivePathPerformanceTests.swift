//
//  AdditivePathPerformanceTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/24/26.
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

import QuartzCore

import ChouTiTest

@_spi(Private) @testable import ComposeUI

/// Additive path animation benchmarks.
///
/// These tests are skipped by default. To run them:
///
/// ```bash
/// cd ComposeUI && BENCHMARK=1 swift test -c release -Xswiftc -enable-testing -Xswiftc -DDEBUG --filter AdditivePathPerformanceTests
/// ```
///
/// Run in release configuration for meaningful numbers. Each benchmark measures one call in a state the calls themselves
/// create: no commit happens, so the changes in flight keep their full duration from call to call.
class AdditivePathPerformanceTests: XCTestCase {

  override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipUnless(ProcessInfo.processInfo.environment["BENCHMARK"] == "1", "benchmarks are skipped by default, run with BENCHMARK=1")
  }

  // MARK: - Animate Path

  func test_animatePath_atRest() {
    // given: layers at rest, one per call
    let layers = makeLayers(count: Constants.warmup + Constants.iterations, path: roundedRect(width: 100))

    // when: animating each layer's path once
    let result = measure { i in
      layers[i].animatePath(keyPath: "path", to: self.roundedRect(width: 200), timing: .easeInEaseOut(duration: 0.5))
    }
    report(name: "animatePath.atRest", result: result)
  }

  func test_animatePath_changeInFlight() {
    for (name, timing) in [("easeInEaseOut.0.5s", AnimationTiming.easeInEaseOut(duration: 0.5)), ("spring", AnimationTiming.spring())] {
      // given: layers with a change in flight, one per call
      let layers = makeLayers(count: Constants.warmup + Constants.iterations, path: roundedRect(width: 100))
      for layer in layers {
        layer.animatePath(keyPath: "path", to: roundedRect(width: 200), timing: timing)
      }

      // when: animating each layer's path again, which makes keyframes of the two changes
      let result = measure { i in
        layers[i].animatePath(keyPath: "path", to: self.roundedRect(width: 150), timing: timing)
      }
      report(name: "animatePath.changeInFlight.\(name)", result: result)
    }
  }

  // MARK: - Set Path

  func test_setPath_atRest() {
    // given: a layer at rest
    let layer = makeLayers(count: 1, path: roundedRect(width: 100))[0]

    // when: setting another path on every call, as a live resize does
    let result = measure { i in
      layer.setPath(keyPath: "path", to: self.roundedRect(width: i.isMultiple(of: 2) ? 120 : 100))
    }
    report(name: "setPath.atRest", result: result)
  }

  func test_setPath_changesInFlight() {
    let cases: [(name: String, changeCount: Int, duration: TimeInterval, path: (CGFloat) -> CGPath)] = [
      ("roundedRect.2changes.0.5s", 2, 0.5, { self.roundedRect(width: $0) }),
      ("roundedRect.2changes.2s", 2, 2, { self.roundedRect(width: $0) }),
      ("roundedRect.10changes.2s", 10, 2, { self.roundedRect(width: $0) }),
      ("blob48.2changes.0.5s", 2, 0.5, { self.blob(width: $0) }),
    ]
    for testCase in cases {
      // given: a layer with changes in flight
      let layer = makeLayers(count: 1, path: testCase.path(100))[0]
      for index in 0 ..< testCase.changeCount {
        layer.animatePath(keyPath: "path", to: testCase.path(CGFloat(110 + index * 10)), timing: .easeInEaseOut(duration: testCase.duration))
      }

      // when: setting another path on every call, as a live resize during the changes does
      let result = measure { i in
        layer.setPath(keyPath: "path", to: testCase.path(i.isMultiple(of: 2) ? 300 : 310))
      }
      report(name: "setPath.changesInFlight.\(testCase.name)", result: result)
    }
  }

  // MARK: - Helpers

  private func makeLayers(count: Int, path: CGPath) -> [CAShapeLayer] {
    (0 ..< count).map { _ in
      let layer = CAShapeLayer()
      layer.setPath(keyPath: "path", to: path)
      return layer
    }
  }

  /// A rounded rect of the given width and 100 points high.
  private func roundedRect(width: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: 0, y: 0, width: width, height: 100), cornerWidth: 12, cornerHeight: 12, transform: nil)
  }

  /// A closed shape of 48 cubic curves around an ellipse of the given width and 100 points high.
  private func blob(width: CGFloat) -> CGPath {
    let curveCount = 48
    let center = CGPoint(x: width / 2, y: 50)
    func point(at angle: CGFloat, scale: CGFloat) -> CGPoint {
      CGPoint(x: center.x + cos(angle) * width / 2 * scale, y: center.y + sin(angle) * 50 * scale)
    }
    let path = CGMutablePath()
    path.move(to: point(at: 0, scale: 1))
    for index in 0 ..< curveCount {
      let start = CGFloat(index) / CGFloat(curveCount) * 2 * .pi
      let end = CGFloat(index + 1) / CGFloat(curveCount) * 2 * .pi
      path.addCurve(
        to: point(at: end, scale: 1),
        control1: point(at: start + (end - start) / 3, scale: 1.05),
        control2: point(at: start + (end - start) * 2 / 3, scale: 0.95)
      )
    }
    path.closeSubpath()
    return path
  }

  private struct BenchmarkResult {
    let durations: [Double] // microseconds, sorted ascending

    var median: Double { durations[durations.count / 2] }
    var p90: Double { durations[Int(Double(durations.count) * 0.9)] }
  }

  private func measure(_ block: (Int) -> Void) -> BenchmarkResult {
    for i in 0 ..< Constants.warmup {
      block(i)
    }

    var durations: [Double] = []
    durations.reserveCapacity(Constants.iterations)
    for i in 0 ..< Constants.iterations {
      let start = DispatchTime.now()
      block(Constants.warmup + i)
      let end = DispatchTime.now()
      durations.append(Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1000)
    }
    return BenchmarkResult(durations: durations.sorted())
  }

  private func report(name: String, result: BenchmarkResult) {
    print("[BENCHMARK] \(name) | iterations: \(result.durations.count) | median: \(String(format: "%.2f", result.median)) µs | p90: \(String(format: "%.2f", result.p90)) µs")
  }

  // MARK: - Constants

  private enum Constants {
    static let warmup = 50
    static let iterations = 500
  }
}
