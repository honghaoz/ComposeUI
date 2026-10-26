//
//  NodeBufferPerformanceTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/25/26.
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

/// Benchmarks of the buffer that keeps a stack's children.
///
/// These tests are skipped by default. To run them:
///
/// ```bash
/// make -C ComposeUI benchmark FILTER=NodeBufferPerformanceTests
/// ```
class NodeBufferPerformanceTests: BenchmarkTestCase {

  func test_release_childrenOfOneType_200() {
    // given: a buffer of 200 labels, made before each iteration
    var buffer: NodeBuffer?

    // when: measuring releasing the buffer, which destroys its children
    let result = measure(warmup: 3, iterations: 30, beforeEach: {
      let made = NodeBuffer.make(capacity: 200, valuesByteCount: 200 * NodeBuffer.room(for: LabelNode.self))
      for _ in 0 ..< 200 {
        made.append(LabelNode("Row"))
      }
      buffer = made
    }, { _ in
      _ = buffer.take()
    })

    // then: report the timings
    report(name: "nodeBuffer.release.oneType.200", result: result)
  }

  func test_release_childrenOfAlternatingTypes_200() {
    // given: a buffer of 200 children that alternate between a label and a color, so that no two neighbors have one
    // type, made before each iteration
    var buffer: NodeBuffer?

    // when: measuring releasing the buffer, which destroys its children
    let result = measure(warmup: 3, iterations: 30, beforeEach: {
      let made = NodeBuffer.make(capacity: 200, valuesByteCount: 100 * (NodeBuffer.room(for: LabelNode.self) + NodeBuffer.room(for: ColorNode.self)))
      for _ in 0 ..< 100 {
        made.append(LabelNode("Row"))
        made.append(ColorNode(.blue))
      }
      buffer = made
    }, { _ in
      _ = buffer.take()
    })

    // then: report the timings
    report(name: "nodeBuffer.release.alternatingTypes.200", result: result)
  }
}
