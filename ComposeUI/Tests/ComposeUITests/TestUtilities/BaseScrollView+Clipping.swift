//
//  BaseScrollView+Clipping.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/1/26.
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

import ChouTiTest

@testable import ComposeUI

/// Expects a scroll view to clip or not: its layer masks to its bounds, which its corner radius rounds, and on AppKit,
/// its clip view clips the document view too.
///
/// - Parameters:
///   - scrollView: The scroll view.
///   - clips: Whether the scroll view clips.
func expectClipping(of scrollView: BaseScrollView, toBe clips: Bool, file: StaticString = #filePath, line: UInt = #line) {
  expect(scrollView.clipsToBounds, file: file, line: line) == clips
  expect(scrollView.layer().masksToBounds, file: file, line: line) == clips
  #if canImport(AppKit)
  expect(scrollView.contentView.clipsToBounds, file: file, line: line) == clips
  #endif
}
