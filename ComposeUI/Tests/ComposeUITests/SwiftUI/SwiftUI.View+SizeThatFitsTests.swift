//
//  SwiftUI.View+SizeThatFitsTests.swift
//  ComposéUI
//
//  Created by Honghao on 6/30/25.
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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import ChouTiTest

import SwiftUI
import ComposeUI

class SwiftUI_View_SizeThatFitsTests: XCTestCase {

  func test_sizeThatFits() {
    // when the view has a fixed size
    do {
      let view = SwiftUI.Color.black.frame(width: 80, height: 50)

      // when proposing size is larger
      expect(
        view.sizeThatFits(CGSize(width: 100, height: 100))
      ) == CGSize(width: 80, height: 50)

      // when proposing size is smaller
      expect(
        view.sizeThatFits(CGSize(width: 50, height: 40))
      ) == CGSize(width: 80, height: 50)
    }

    // when the view has a flexible size
    do {
      let view = SwiftUI.Color.black

      // when proposing size is larger
      expect(
        view.sizeThatFits(CGSize(width: 100, height: 100))
      ) == CGSize(width: 100, height: 100)

      // when proposing size is smaller
      expect(
        view.sizeThatFits(CGSize(width: 50, height: 50))
      ) == CGSize(width: 50, height: 50)
    }
  }

  func test_sizeThatFits_zeroProposingSize_fixedView_returnsFixedSize() {
    let view = SwiftUI.Color.black.frame(width: 80, height: 50)
    expect(view.sizeThatFits(.zero)) == CGSize(width: 80, height: 50)
  }

  func test_sizeThatFits_largeProposingSize_flexibleView_returnsProposing() {
    let size = SwiftUI.Color.black.sizeThatFits(CGSize(width: 10000, height: 10000))
    expect(size) == CGSize(width: 10000, height: 10000)
  }

  func test_sizeThatFits_multipleSequentialCalls_returnsConsistentSizes() {
    // exercises the pool: first call creates a host, subsequent calls reuse it.
    // verifying each call returns the correct size proves the host is properly reset between calls.
    let fixed = SwiftUI.Color.black.frame(width: 80, height: 50)
    let flexible = SwiftUI.Color.black

    for _ in 0 ..< 5 {
      expect(fixed.sizeThatFits(CGSize(width: 200, height: 200))) == CGSize(width: 80, height: 50)
      expect(flexible.sizeThatFits(CGSize(width: 70, height: 90))) == CGSize(width: 70, height: 90)
    }
  }

  func test_sizeThatFits_alternatingViewTypes_returnsCorrectSizes() {
    // proves the host's `rootView` is properly swapped between calls (no stale measurement).
    let small = SwiftUI.Color.black.frame(width: 30, height: 20)
    let large = SwiftUI.Color.black.frame(width: 150, height: 120)

    expect(small.sizeThatFits(CGSize(width: 200, height: 200))) == CGSize(width: 30, height: 20)
    expect(large.sizeThatFits(CGSize(width: 200, height: 200))) == CGSize(width: 150, height: 120)
    expect(small.sizeThatFits(CGSize(width: 200, height: 200))) == CGSize(width: 30, height: 20)
    expect(large.sizeThatFits(CGSize(width: 200, height: 200))) == CGSize(width: 150, height: 120)
  }

  func test_sizeThatFits_alternatingProposingSize_fixedView_returnsFixed() {
    // proves the proposing size doesn't get cached between pool reuse calls.
    let view = SwiftUI.Color.black.frame(width: 80, height: 50)

    expect(view.sizeThatFits(CGSize(width: 10, height: 10))) == CGSize(width: 80, height: 50)
    expect(view.sizeThatFits(CGSize(width: 1000, height: 1000))) == CGSize(width: 80, height: 50)
    expect(view.sizeThatFits(CGSize(width: 10, height: 10))) == CGSize(width: 80, height: 50)
  }

  func test_sizeThatFits_reentrantCall_innerAndOuterReturnCorrectSizes() {
    // a SwiftUI view whose `body` measures a child view re-enters the pool while the outer
    // measurement is still in flight. both measurements must return correct sizes, proving
    // the inner call gets its own host (rather than corrupting the outer's host state).
    let recorder = ReentrancyRecorder()
    let view = ReentrantSizingView(
      recorder: recorder,
      child: SwiftUI.Color.black.frame(width: 60, height: 40),
      proposingSize: CGSize(width: 200, height: 200)
    )

    let outerSize = view.sizeThatFits(CGSize(width: 100, height: 100))

    expect(recorder.bodyCallCount) == 1
    expect(recorder.innerSize) == CGSize(width: 60, height: 40)
    expect(outerSize) == CGSize(width: 30, height: 20) // body returns Color.black.frame(30, 20)
  }

  func test_sizeThatFits_nestedReentrantCalls_returnCorrectSizes() {
    // measure an outer view, whose body measures an inner view, whose body measures a leaf.
    // exercises pool growth beyond a single reentrant level.
    let innerRecorder = ReentrancyRecorder()
    let outerRecorder = ReentrancyRecorder()

    let inner = ReentrantSizingView(
      recorder: innerRecorder,
      child: SwiftUI.Color.black.frame(width: 60, height: 40),
      proposingSize: CGSize(width: 100, height: 100)
    )

    let outer = ReentrantSizingView(
      recorder: outerRecorder,
      child: inner,
      proposingSize: CGSize(width: 150, height: 150)
    )

    let outerSize = outer.sizeThatFits(CGSize(width: 200, height: 200))

    expect(outerRecorder.bodyCallCount) == 1
    expect(outerRecorder.innerSize) == CGSize(width: 30, height: 20) // measured `inner` (its body returns 30x20 frame)
    expect(innerRecorder.bodyCallCount) == 1
    expect(innerRecorder.innerSize) == CGSize(width: 60, height: 40) // measured the leaf
    expect(outerSize) == CGSize(width: 30, height: 20) // outer's body also returns 30x20 frame
  }
}

/// A reference-type recorder so SwiftUI body side effects propagate back to the test, regardless of capture semantics.
private final class ReentrancyRecorder {

  var bodyCallCount = 0
  var innerSize: CGSize?
}

/// A SwiftUI view that measures a child inside its `body`, simulating reentrant calls into the sizing pool.
private struct ReentrantSizingView<Child: SwiftUI.View>: SwiftUI.View {

  let recorder: ReentrancyRecorder
  let child: Child
  let proposingSize: CGSize

  var body: some SwiftUI.View {
    recorder.bodyCallCount += 1
    recorder.innerSize = child.sizeThatFits(proposingSize)
    return SwiftUI.Color.black.frame(width: 30, height: 20)
  }
}

// MARK: - Performance Tests

#if canImport(AppKit)
private typealias TestHostingController = NSHostingController
#endif

#if canImport(UIKit)
private typealias TestHostingController = UIHostingController
#endif

/// Compares the pooled `sizeThatFits` against a baseline that allocates a fresh
/// `HostingController` per call. The pool is expected to be faster because it
/// avoids per-call hosting controller allocation.
class SwiftUI_View_SizeThatFits_PerformanceTests: XCTestCase {

  func test_pool_vs_freshHostAllocation_simpleView() {
    let iterations = 200
    let view = SwiftUI.Color.black.frame(width: 80, height: 50)
    let proposingSize = CGSize(width: 200, height: 200)

    // warm up the pool so the first allocation isn't counted in the measured run.
    _ = view.sizeThatFits(proposingSize)

    let pooledTime = ChouTiTest.measure(repeat: iterations) {
      _ = view.sizeThatFits(proposingSize)
    }

    let freshTime = ChouTiTest.measure(repeat: iterations) {
      let host = TestHostingController(rootView: AnyView(view))
      _ = host.sizeThatFits(in: proposingSize)
    }

    let pooledMs = pooledTime * 1000
    let freshMs = freshTime * 1000
    let speedup = freshMs / pooledMs

    print("""
    SwiftUISizingHostPool Performance (simple view, \(iterations) iterations):
    • Pooled:     \(String(format: "%.2f", pooledMs)) ms (\(String(format: "%.4f", pooledMs / Double(iterations))) ms/call)
    • Fresh host: \(String(format: "%.2f", freshMs)) ms (\(String(format: "%.4f", freshMs / Double(iterations))) ms/call)
    • Speedup:    \(String(format: "%.2fx", speedup))
    """)

    // sanity check: the pool should not be slower than per-call allocation.
    expect(pooledMs <= freshMs) == true
  }

  func test_pool_vs_freshHostAllocation_complexView() {
    let iterations = 200
    let view = SwiftUI.VStack(spacing: 4) {
      SwiftUI.HStack(spacing: 4) {
        SwiftUI.Color.black.frame(width: 30, height: 30)
        SwiftUI.Color.gray.frame(width: 30, height: 30)
        SwiftUI.Color.black.frame(width: 30, height: 30)
      }
      SwiftUI.Text("Hello, World!")
      SwiftUI.HStack(spacing: 4) {
        SwiftUI.Color.gray.frame(width: 30, height: 30)
        SwiftUI.Color.black.frame(width: 30, height: 30)
      }
    }
    let proposingSize = CGSize(width: 200, height: 200)

    // warm up
    _ = view.sizeThatFits(proposingSize)

    let pooledTime = ChouTiTest.measure(repeat: iterations) {
      _ = view.sizeThatFits(proposingSize)
    }

    let freshTime = ChouTiTest.measure(repeat: iterations) {
      let host = TestHostingController(rootView: AnyView(view))
      _ = host.sizeThatFits(in: proposingSize)
    }

    let pooledMs = pooledTime * 1000
    let freshMs = freshTime * 1000
    let speedup = freshMs / pooledMs

    print("""
    SwiftUISizingHostPool Performance (complex view, \(iterations) iterations):
    • Pooled:     \(String(format: "%.2f", pooledMs)) ms (\(String(format: "%.4f", pooledMs / Double(iterations))) ms/call)
    • Fresh host: \(String(format: "%.2f", freshMs)) ms (\(String(format: "%.4f", freshMs / Double(iterations))) ms/call)
    • Speedup:    \(String(format: "%.2fx", speedup))
    """)

    // on Mac
    // SwiftUISizingHostPool Performance (simple view, 200 iterations):
    // • Pooled:     0.41 ms (0.0020 ms/call)
    // • Fresh host: 11.47 ms (0.0574 ms/call)
    // • Speedup:    28.23x
    //
    // SwiftUISizingHostPool Performance (complex view, 200 iterations):
    // • Pooled:     0.58 ms (0.0029 ms/call)
    // • Fresh host: 30.11 ms (0.1505 ms/call)
    // • Speedup:    51.47x

    // on iPhone simulator
    // SwiftUISizingHostPool Performance (simple view, 200 iterations):
    // • Pooled:     0.33 ms (0.0017 ms/call)
    // • Fresh host: 14.62 ms (0.0731 ms/call)
    // • Speedup:    43.66x
    //
    // SwiftUISizingHostPool Performance (complex view, 200 iterations):
    // • Pooled:     0.50 ms (0.0025 ms/call)
    // • Fresh host: 37.66 ms (0.1883 ms/call)
    // • Speedup:    75.58x

    expect(pooledMs <= freshMs) == true
  }
}
