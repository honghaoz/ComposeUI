//
//  BackgroundDrawing.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/17/26.
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

@testable import ComposeUI

/// The drawing that compose views do ahead of time on other threads, which benchmarks finish outside of their measured
/// iterations.
///
/// The benchmarks reach the drawing through this type, instead of through the framework's types, since a benchmark
/// comparison builds the working tree's benchmark files against a base revision, with the base's own test utilities.
enum BackgroundDrawing {

  /// Waits for the drawing in progress and queued to finish, and keeps the drawing queued after it from starting until
  /// the next call to this method or to `finish()`.
  static func finishAndPause() {
    #if canImport(AppKit)
    TextLabelImageCache.Test.finishDrawingsAndPause()
    #endif
  }

  /// Waits for the drawing in progress and queued to finish, and lets the drawing queued after it start.
  static func finish() {
    #if canImport(AppKit)
    TextLabelImageCache.Test.waitForDrawings()
    #endif
  }
}
