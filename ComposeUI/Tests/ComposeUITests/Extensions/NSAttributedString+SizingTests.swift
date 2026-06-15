//
//  NSAttributedString+SizingTests.swift
//  ComposéUI
//
//  Created by Honghao on 6/21/25.
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

class NSAttributedString_SizingTests: XCTestCase {

  // MARK: - Singleline

  func test_singleLine_empty() throws {
    let attributedString = NSAttributedString(string: "")
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    expect(size) == .zero
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byWordWrapping_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    // ascent: 15.46875, descent: 3.375, leading: 0.0, height: 18.84375
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    // ascent: 15.234375, descent: 3.859375, leading: 0.0, height: 19.09375
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byWordWrapping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byCharWrapping_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byCharWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    // ascent: 15.46875, descent: 3.375, leading: 0.0, height: 18.84375
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    // ascent: 15.234375, descent: 3.859375, leading: 0.0, height: 19.09375
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byCharWrapping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byClipping_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byClipping)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    // ascent: 15.46875, descent: 3.375, leading: 0.0, height: 18.84375
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    // ascent: 15.234375, descent: 3.859375, leading: 0.0, height: 19.09375
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byClipping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingTail_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingTail)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingTail_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingHead_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingHead)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingHead_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingMiddle_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingMiddle)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingMiddle_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byWordWrapping_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    // ascent: 15.46875, descent: 3.375, leading: 0.0, height: 18.84375
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    // ascent: 15.234375, descent: 3.859375, leading: 0.0, height: 19.09375
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byWordWrapping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byCharWrapping_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byCharWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    // ascent: 15.46875, descent: 3.375, leading: 0.0, height: 18.84375
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    // ascent: 15.234375, descent: 3.859375, leading: 0.0, height: 19.09375
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byCharWrapping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byClipping_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byClipping)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    // ascent: 15.46875, descent: 3.375, leading: 0.0, height: 18.84375
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    // ascent: 15.234375, descent: 3.859375, leading: 0.0, height: 19.09375
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byClipping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingTail_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingTail)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingTail_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingHead_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingHead)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingHead_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingMiddle_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingMiddle)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingMiddle_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  // MARK: - Multiline

  func test_multiline_empty() throws {
    let attributedString = NSAttributedString(string: "")
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100)
    expect(size) == .zero
  }

  func test_multiline_byWordWrapping_paragraphStyle_byWordWrapping_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 89.02, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.0, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 89.02, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.18, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byWordWrapping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 89.79, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.90, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 89.79, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.18, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byCharWrapping_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byCharWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.10, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 99.10, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.18, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byCharWrapping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.06, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.90, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 98.06, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.18, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byClipping_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byClipping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.0, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09375, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byClipping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byTruncatingTail_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingTail)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 95.53, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.390625, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09375, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byTruncatingTail_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.26, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.2, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byTruncatingHead_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingHead)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 92.12, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 94.5234375, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09375, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byTruncatingHead_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.73, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 96.896, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byTruncatingMiddle_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingMiddle)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.87, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 99.8359375, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09375, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byTruncatingMiddle_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.82, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 93.648, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byWordWrapping_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.45, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 144, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 99.45, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 152.75, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byWordWrapping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.78, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 147.59, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.78, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 152.70, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byCharWrapping_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byCharWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.63, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 126, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 99.63, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 133.66, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byCharWrapping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.96, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 147.59, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 98.96, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 152.70, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byClipping_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byClipping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.0, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09375, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byClipping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byTruncatingTail_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingTail)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 95.53, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.390625, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09375, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byTruncatingTail_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.26, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.2, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byTruncatingHead_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingHead)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 92.12, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 94.5234375, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09375, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byTruncatingHead_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.73, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 96.896, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byTruncatingMiddle_systemFont() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingMiddle)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.87, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 99.8359375, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09375, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byTruncatingMiddle_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.82, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 93.648, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byClipping_paragraphStyle_byWordWrapping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.90, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.176, within: 1e-1))
    #endif
  }

  func test_multiline_byClipping_paragraphStyle_byCharWrapping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.90, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.176, within: 1e-1))
    #endif
  }

  func test_multiline_byClipping_paragraphStyle_byClipping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byClipping_paragraphStyle_byTruncatingTail_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.26, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.2, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byClipping_paragraphStyle_byTruncatingHead_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.73, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 96.896, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byClipping_paragraphStyle_byTruncatingMiddle_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.82, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 93.648, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingTail_paragraphStyle_byWordWrapping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 95.376, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.89599609375, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 95.376, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.176, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingTail_paragraphStyle_byCharWrapping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.064, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.89599609375, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 98.064, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.176, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingTail_paragraphStyle_byClipping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingTail_paragraphStyle_byTruncatingTail_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.26, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.2, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingTail_paragraphStyle_byTruncatingHead_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.73, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 96.896, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingTail_paragraphStyle_byTruncatingMiddle_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.82, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 93.648, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingHead_paragraphStyle_byWordWrapping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 96.896, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.89599609375, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 96.896, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.176, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingHead_paragraphStyle_byCharWrapping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.064, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.89599609375, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 98.064, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.176, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingHead_paragraphStyle_byClipping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingHead_paragraphStyle_byTruncatingTail_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.26400000000001, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.2, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingHead_paragraphStyle_byTruncatingHead_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.73, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 96.896, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingHead_paragraphStyle_byTruncatingMiddle_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.816, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 93.648, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingMiddle_paragraphStyle_byWordWrapping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.672, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.89599609375, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 98.672, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.176, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingMiddle_paragraphStyle_byCharWrapping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.064, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.89599609375, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 98.064, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.176, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingMiddle_paragraphStyle_byClipping_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingMiddle_paragraphStyle_byTruncatingTail_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.26400000000001, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.2, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingMiddle_paragraphStyle_byTruncatingHead_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.72800000000001, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 96.896, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingMiddle_paragraphStyle_byTruncatingMiddle_customFont() throws {
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.816, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 93.648, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  // MARK: - Cache

  func test_cache_cachedMatchesUncached_singleLine() throws {
    NSAttributedString.clearTextSizeCache()

    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)

    let uncached = attributedString.computeBoundingRectSize(numberOfLines: 1, layoutWidth: 100)
    let cachedMiss = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100) // computes + caches
    let cachedHit = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100) // served from cache

    expect(cachedMiss) == uncached
    expect(cachedHit) == uncached
  }

  func test_cache_cachedMatchesUncached_multiLine() throws {
    NSAttributedString.clearTextSizeCache()

    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)

    let uncached = attributedString.computeBoundingRectSize(numberOfLines: 0, layoutWidth: 100)
    let cachedMiss = attributedString.boundingRectSize(numberOfLines: 0, layoutWidth: 100)
    let cachedHit = attributedString.boundingRectSize(numberOfLines: 0, layoutWidth: 100)

    expect(cachedMiss) == uncached
    expect(cachedHit) == uncached
  }

  func test_cache_distinctFonts_notConfused() throws {
    NSAttributedString.clearTextSizeCache()

    // same text, different font: the key includes the attributed string (which carries the font), so the two sizes
    // must not collapse to one cached entry.
    let small = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)
    let large = try makeAttributedString(font: Font.systemFont(ofSize: 32), lineBreakMode: .byWordWrapping)

    let smallSize = small.boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    let largeSize = large.boundingRectSize(numberOfLines: 1, layoutWidth: 100)

    expect(smallSize) != largeSize
    expect(largeSize.height) > smallSize.height
  }

  func test_cache_distinctWidths_notConfused() throws {
    NSAttributedString.clearTextSizeCache()

    // same multi-line text at different widths wraps differently, so the cache (keyed by width) must keep them distinct.
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)

    let narrow = attributedString.boundingRectSize(numberOfLines: 0, layoutWidth: 80)
    let wide = attributedString.boundingRectSize(numberOfLines: 0, layoutWidth: 300)

    expect(narrow) != wide
    expect(narrow.height) > wide.height // narrower wraps to more lines -> taller
  }

  func test_cache_clear_recomputesSameValue() throws {
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)

    let before = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 120)
    NSAttributedString.clearTextSizeCache()
    let after = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 120)

    expect(after) == before
  }

  func test_cache_mutableAttributedString_afterMutation_returnsNewSize() throws {
    NSAttributedString.clearTextSizeCache()

    let attributes: [NSAttributedString.Key: Any] = [.font: Font.systemFont(ofSize: 16)]
    let mutableString = NSMutableAttributedString(string: "Hi", attributes: attributes)

    let sizeBeforeMutation = mutableString.boundingRectSize(numberOfLines: 1, layoutWidth: 1000)

    // mutate the same instance that was just used as a cache key, then ask again with that same instance.
    mutableString.append(NSAttributedString(string: " there, this is a much longer piece of text", attributes: attributes))
    let sizeAfterMutation = mutableString.boundingRectSize(numberOfLines: 1, layoutWidth: 1000)

    // the size must reflect the mutated (longer) content, not a stale value keyed by the pre-mutation string.
    expect(sizeAfterMutation) != sizeBeforeMutation
    expect(sizeAfterMutation.width) > sizeBeforeMutation.width
    expect(sizeAfterMutation) == mutableString.computeBoundingRectSize(numberOfLines: 1, layoutWidth: 1000)
  }

  func test_cache_singleLine_sizeIndependentOfWidthAndLineBreakMode() throws {
    NSAttributedString.clearTextSizeCache()

    // single-line sizing ignores layoutWidth and lineBreakMode (it measures the natural, unwrapped line)
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)

    let narrow = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 50)
    let wide = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 5000)
    let charWrap = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 123, lineBreakMode: .byCharWrapping)

    expect(narrow) == wide
    expect(narrow) == charWrap
  }

  // MARK: - Helpers

  private func makeAttributedString(font: Font, lineBreakMode: NSLineBreakMode) throws -> NSAttributedString {
    NSAttributedString(
      string: Constants.string,
      attributes: [
        .font: font,
        .foregroundColor: Color.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .left
          style.lineBreakMode = lineBreakMode
          // style.lineSpacing = 50
          return style
        }(),
      ]
    )
  }

  // MARK: - Constants

  private enum Constants {
    static let string: String = "ComposéUI is a Swift framework for building UI using AppKit and UIKit with declarative syntax."
  }
}
