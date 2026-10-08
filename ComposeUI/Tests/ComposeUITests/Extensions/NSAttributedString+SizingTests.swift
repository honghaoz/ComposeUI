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
    // given: an empty attributed string
    let attributedString = NSAttributedString(string: "")

    // when: measuring the size for 1 line
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100)

    // then: the size is zero
    expect(size) == .zero
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byWordWrapping_systemFont() throws {
    // given: an attributed string with system font and .byWordWrapping paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)

    // when: measuring the size for 1 line with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
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
    // given: an attributed string with HelveticaNeue font and .byWordWrapping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)

    // when: measuring the size for 1 line with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byCharWrapping_systemFont() throws {
    // given: an attributed string with system font and .byCharWrapping paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byCharWrapping)

    // when: measuring the size for 1 line with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
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
    // given: an attributed string with HelveticaNeue font and .byCharWrapping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)

    // when: measuring the size for 1 line with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byClipping_systemFont() throws {
    // given: an attributed string with system font and .byClipping paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byClipping)

    // when: measuring the size for 1 line with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
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
    // given: an attributed string with HelveticaNeue font and .byClipping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)

    // when: measuring the size for 1 line with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingTail_systemFont() throws {
    // given: an attributed string with system font and .byTruncatingTail paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingTail)

    // when: measuring the size for 1 line with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingTail_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingTail paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)

    // when: measuring the size for 1 line with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingHead_systemFont() throws {
    // given: an attributed string with system font and .byTruncatingHead paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingHead)

    // when: measuring the size for 1 line with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingHead_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingHead paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)

    // when: measuring the size for 1 line with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingMiddle_systemFont() throws {
    // given: an attributed string with system font and .byTruncatingMiddle paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingMiddle)

    // when: measuring the size for 1 line with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byWordWrapping_paragraphStyle_byTruncatingMiddle_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingMiddle paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)

    // when: measuring the size for 1 line with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byWordWrapping_systemFont() throws {
    // given: an attributed string with system font and .byWordWrapping paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)

    // when: measuring the size for 1 line with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
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
    // given: an attributed string with HelveticaNeue font and .byWordWrapping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)

    // when: measuring the size for 1 line with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byCharWrapping_systemFont() throws {
    // given: an attributed string with system font and .byCharWrapping paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byCharWrapping)

    // when: measuring the size for 1 line with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
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
    // given: an attributed string with HelveticaNeue font and .byCharWrapping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)

    // when: measuring the size for 1 line with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byClipping_systemFont() throws {
    // given: an attributed string with system font and .byClipping paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byClipping)

    // when: measuring the size for 1 line with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
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
    // given: an attributed string with HelveticaNeue font and .byClipping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)

    // when: measuring the size for 1 line with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingTail_systemFont() throws {
    // given: an attributed string with system font and .byTruncatingTail paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingTail)

    // when: measuring the size for 1 line with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingTail_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingTail paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)

    // when: measuring the size for 1 line with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingHead_systemFont() throws {
    // given: an attributed string with system font and .byTruncatingHead paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingHead)

    // when: measuring the size for 1 line with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingHead_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingHead paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)

    // when: measuring the size for 1 line with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingMiddle_systemFont() throws {
    // given: an attributed string with system font and .byTruncatingMiddle paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingMiddle)

    // when: measuring the size for 1 line with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.84, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 681.98, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
    #endif
  }

  func test_singleLine_byCharWrapping_paragraphStyle_byTruncatingMiddle_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingMiddle paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)

    // when: measuring the size for 1 line with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    expect(size.width).to(beApproximatelyEqual(to: 678.848, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09, within: 1e-1))
  }

  // MARK: - Multiline

  func test_multiline_empty() throws {
    // given: an empty attributed string
    let attributedString = NSAttributedString(string: "")

    // when: measuring the size for 2 lines
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100)

    // then: the size is zero
    expect(size) == .zero
  }

  func test_multiline_byWordWrapping_paragraphStyle_byWordWrapping_systemFont() throws {
    // given: an attributed string with system font and .byWordWrapping paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)

    // when: measuring the size for 2 lines with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 89.02, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.0, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 89.02, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.18, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byWordWrapping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byWordWrapping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)

    // when: measuring the size for 2 lines with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 89.79, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.90, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 89.79, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.18, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byCharWrapping_systemFont() throws {
    // given: an attributed string with system font and .byCharWrapping paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byCharWrapping)

    // when: measuring the size for 2 lines with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.10, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 99.10, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.18, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byCharWrapping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byCharWrapping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)

    // when: measuring the size for 2 lines with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.06, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.90, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 98.06, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.18, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byClipping_systemFont() throws {
    // given: an attributed string with system font and .byClipping paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byClipping)

    // when: measuring the size for 2 lines with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.0, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09375, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byClipping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byClipping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)

    // when: measuring the size for 2 lines with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byTruncatingTail_systemFont() throws {
    // given: an attributed string with system font and .byTruncatingTail paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingTail)

    // when: measuring the size for 2 lines with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 95.53, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.390625, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09375, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byTruncatingTail_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingTail paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)

    // when: measuring the size for 2 lines with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.26, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.2, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byTruncatingHead_systemFont() throws {
    // given: an attributed string with system font and .byTruncatingHead paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingHead)

    // when: measuring the size for 2 lines with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 92.12, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 94.5234375, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09375, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byTruncatingHead_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingHead paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)

    // when: measuring the size for 2 lines with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.73, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 96.896, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byTruncatingMiddle_systemFont() throws {
    // given: an attributed string with system font and .byTruncatingMiddle paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingMiddle)

    // when: measuring the size for 2 lines with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.87, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 99.8359375, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09375, within: 1e-1))
    #endif
  }

  func test_multiline_byWordWrapping_paragraphStyle_byTruncatingMiddle_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingMiddle paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)

    // when: measuring the size for 2 lines with .byWordWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byWordWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.82, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 93.648, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byWordWrapping_systemFont() throws {
    // given: an attributed string with system font and .byWordWrapping paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)

    // when: measuring the size for 2 lines with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.45, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 144, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 99.45, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 152.75, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byWordWrapping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byWordWrapping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)

    // when: measuring the size for 2 lines with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.78, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 147.59, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.78, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 152.70, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byCharWrapping_systemFont() throws {
    // given: an attributed string with system font and .byCharWrapping paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byCharWrapping)

    // when: measuring the size for 2 lines with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.63, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 126, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 99.63, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 133.66, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byCharWrapping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byCharWrapping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)

    // when: measuring the size for 2 lines with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.96, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 147.59, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 98.96, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 152.70, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byClipping_systemFont() throws {
    // given: an attributed string with system font and .byClipping paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byClipping)

    // when: measuring the size for 2 lines with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.0, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09375, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byClipping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byClipping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)

    // when: measuring the size for 2 lines with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byTruncatingTail_systemFont() throws {
    // given: an attributed string with system font and .byTruncatingTail paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingTail)

    // when: measuring the size for 2 lines with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 95.53, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.390625, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09375, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byTruncatingTail_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingTail paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)

    // when: measuring the size for 2 lines with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.26, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.2, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byTruncatingHead_systemFont() throws {
    // given: an attributed string with system font and .byTruncatingHead paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingHead)

    // when: measuring the size for 2 lines with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 92.12, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 94.5234375, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09375, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byTruncatingHead_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingHead paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)

    // when: measuring the size for 2 lines with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.73, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 96.896, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byTruncatingMiddle_systemFont() throws {
    // given: an attributed string with system font and .byTruncatingMiddle paragraph style
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byTruncatingMiddle)

    // when: measuring the size for 2 lines with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.87, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 99.8359375, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.09375, within: 1e-1))
    #endif
  }

  func test_multiline_byCharWrapping_paragraphStyle_byTruncatingMiddle_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingMiddle paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)

    // when: measuring the size for 2 lines with .byCharWrapping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byCharWrapping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.82, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 93.648, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byClipping_paragraphStyle_byWordWrapping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byWordWrapping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)

    // when: measuring the size for 2 lines with .byClipping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.90, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.176, within: 1e-1))
    #endif
  }

  func test_multiline_byClipping_paragraphStyle_byCharWrapping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byCharWrapping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)

    // when: measuring the size for 2 lines with .byClipping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.90, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.176, within: 1e-1))
    #endif
  }

  func test_multiline_byClipping_paragraphStyle_byClipping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byClipping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)

    // when: measuring the size for 2 lines with .byClipping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byClipping_paragraphStyle_byTruncatingTail_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingTail paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)

    // when: measuring the size for 2 lines with .byClipping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.26, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.2, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byClipping_paragraphStyle_byTruncatingHead_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingHead paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)

    // when: measuring the size for 2 lines with .byClipping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.73, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 96.896, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byClipping_paragraphStyle_byTruncatingMiddle_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingMiddle paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)

    // when: measuring the size for 2 lines with .byClipping
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byClipping)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.82, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 93.648, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingTail_paragraphStyle_byWordWrapping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byWordWrapping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)

    // when: measuring the size for 2 lines with .byTruncatingTail
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 95.376, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.89599609375, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 95.376, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.176, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingTail_paragraphStyle_byCharWrapping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byCharWrapping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)

    // when: measuring the size for 2 lines with .byTruncatingTail
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.064, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.89599609375, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 98.064, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.176, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingTail_paragraphStyle_byClipping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byClipping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)

    // when: measuring the size for 2 lines with .byTruncatingTail
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingTail_paragraphStyle_byTruncatingTail_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingTail paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)

    // when: measuring the size for 2 lines with .byTruncatingTail
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.26, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.2, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingTail_paragraphStyle_byTruncatingHead_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingHead paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)

    // when: measuring the size for 2 lines with .byTruncatingTail
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.73, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 96.896, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingTail_paragraphStyle_byTruncatingMiddle_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingMiddle paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)

    // when: measuring the size for 2 lines with .byTruncatingTail
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingTail)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.82, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 93.648, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingHead_paragraphStyle_byWordWrapping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byWordWrapping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)

    // when: measuring the size for 2 lines with .byTruncatingHead
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 96.896, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.89599609375, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 96.896, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.176, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingHead_paragraphStyle_byCharWrapping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byCharWrapping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)

    // when: measuring the size for 2 lines with .byTruncatingHead
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.064, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.89599609375, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 98.064, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.176, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingHead_paragraphStyle_byClipping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byClipping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)

    // when: measuring the size for 2 lines with .byTruncatingHead
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingHead_paragraphStyle_byTruncatingTail_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingTail paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)

    // when: measuring the size for 2 lines with .byTruncatingHead
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.26400000000001, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.2, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingHead_paragraphStyle_byTruncatingHead_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingHead paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)

    // when: measuring the size for 2 lines with .byTruncatingHead
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.73, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 96.896, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingHead_paragraphStyle_byTruncatingMiddle_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingMiddle paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)

    // when: measuring the size for 2 lines with .byTruncatingHead
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingHead)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.816, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 93.648, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingMiddle_paragraphStyle_byWordWrapping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byWordWrapping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byWordWrapping)

    // when: measuring the size for 2 lines with .byTruncatingMiddle
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.672, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.89599609375, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 98.672, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.176, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingMiddle_paragraphStyle_byCharWrapping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byCharWrapping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byCharWrapping)

    // when: measuring the size for 2 lines with .byTruncatingMiddle
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 98.064, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.89599609375, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 98.064, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 38.176, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingMiddle_paragraphStyle_byClipping_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byClipping paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byClipping)

    // when: measuring the size for 2 lines with .byTruncatingMiddle
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 100.0, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingMiddle_paragraphStyle_byTruncatingTail_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingTail paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingTail)

    // when: measuring the size for 2 lines with .byTruncatingMiddle
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 97.26400000000001, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 97.2, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingMiddle_paragraphStyle_byTruncatingHead_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingHead paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingHead)

    // when: measuring the size for 2 lines with .byTruncatingMiddle
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)

    // then: the size matches the expected size
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 99.72800000000001, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 18.45, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 96.896, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 19.088, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingMiddle_paragraphStyle_byTruncatingMiddle_customFont() throws {
    // given: an attributed string with HelveticaNeue font and .byTruncatingMiddle paragraph style
    let attributedString = try makeAttributedString(font: unwrap(Font(name: "HelveticaNeue", size: 16)), lineBreakMode: .byTruncatingMiddle)

    // when: measuring the size for 2 lines with .byTruncatingMiddle
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100, lineBreakMode: .byTruncatingMiddle)

    // then: the size matches the expected size
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
    // given: a cleared cache and an attributed string
    NSAttributedString.clearTextSizeCache()

    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)

    // when: measuring the size uncached, with a cache miss, and with a cache hit
    let uncached = attributedString.computeBoundingRectSize(numberOfLines: 1, layoutWidth: 100)
    let cachedMiss = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100) // computes + caches
    let cachedHit = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100) // served from cache

    // then: the cached sizes match the uncached size
    expect(cachedMiss) == uncached
    expect(cachedHit) == uncached
  }

  func test_cache_cachedMatchesUncached_multiLine() throws {
    // given: a cleared cache and an attributed string
    NSAttributedString.clearTextSizeCache()

    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)

    // when: measuring the size uncached, with a cache miss, and with a cache hit
    let uncached = attributedString.computeBoundingRectSize(numberOfLines: 0, layoutWidth: 100)
    let cachedMiss = attributedString.boundingRectSize(numberOfLines: 0, layoutWidth: 100)
    let cachedHit = attributedString.boundingRectSize(numberOfLines: 0, layoutWidth: 100)

    // then: the cached sizes match the uncached size
    expect(cachedMiss) == uncached
    expect(cachedHit) == uncached
  }

  func test_cache_distinctFonts_notConfused() throws {
    // given: a cleared cache and two attributed strings with the same text but different fonts
    NSAttributedString.clearTextSizeCache()

    // same text, different font: the key includes the attributed string (which carries the font), so the two sizes
    // must not collapse to one cached entry.
    let small = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)
    let large = try makeAttributedString(font: Font.systemFont(ofSize: 32), lineBreakMode: .byWordWrapping)

    // when: measuring both sizes
    let smallSize = small.boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    let largeSize = large.boundingRectSize(numberOfLines: 1, layoutWidth: 100)

    // then: the sizes are distinct
    expect(smallSize) != largeSize
    expect(largeSize.height) > smallSize.height
  }

  func test_cache_distinctWidths_notConfused() throws {
    // given: a cleared cache and a multi line attributed string
    NSAttributedString.clearTextSizeCache()

    // same multi-line text at different widths wraps differently, so the cache (keyed by width) must keep them distinct.
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)

    // when: measuring the size at different widths
    let narrow = attributedString.boundingRectSize(numberOfLines: 0, layoutWidth: 80)
    let wide = attributedString.boundingRectSize(numberOfLines: 0, layoutWidth: 300)

    // then: the sizes are distinct
    expect(narrow) != wide
    expect(narrow.height) > wide.height // narrower wraps to more lines -> taller
  }

  func test_cache_distinctNumbersOfLines_notConfused() throws {
    // given: a cleared cache and a multi line attributed string
    NSAttributedString.clearTextSizeCache()

    // the same text at the same width is as tall as the lines it may take, so the cache (keyed by number of lines) must
    // keep them distinct.
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)

    // when: measuring the size for unlimited lines and for 2 lines
    let unlimited = attributedString.boundingRectSize(numberOfLines: 0, layoutWidth: 100)
    let twoLines = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100)

    // then: the sizes are distinct
    expect(twoLines) != unlimited
    expect(unlimited.height) > twoLines.height // more lines -> taller
  }

  func test_cache_clear_recomputesSameValue() throws {
    // given: an attributed string with a cached size
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)

    let before = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 120)

    // when: clearing the cache and measuring again
    NSAttributedString.clearTextSizeCache()
    let after = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 120)

    // then: the recomputed size matches the cached size
    expect(after) == before
  }

  func test_cache_mutableAttributedString_afterMutation_returnsNewSize() throws {
    // given: a cleared cache and a mutable attributed string with a cached size
    NSAttributedString.clearTextSizeCache()

    let attributes: [NSAttributedString.Key: Any] = [.font: Font.systemFont(ofSize: 16)]
    let mutableString = NSMutableAttributedString(string: "Hi", attributes: attributes)

    let sizeBeforeMutation = mutableString.boundingRectSize(numberOfLines: 1, layoutWidth: 1000)

    // when: mutating the same instance that was just used as a cache key, then asking again with that same instance
    mutableString.append(NSAttributedString(string: " there, this is a much longer piece of text", attributes: attributes))
    let sizeAfterMutation = mutableString.boundingRectSize(numberOfLines: 1, layoutWidth: 1000)

    // then: the size reflects the mutated (longer) content, not a stale value keyed by the pre-mutation string
    expect(sizeAfterMutation) != sizeBeforeMutation
    expect(sizeAfterMutation.width) > sizeBeforeMutation.width
    expect(sizeAfterMutation) == mutableString.computeBoundingRectSize(numberOfLines: 1, layoutWidth: 1000)
  }

  func test_cache_singleLine_sizeIndependentOfWidthAndLineBreakMode() throws {
    // given: a cleared cache and an attributed string
    NSAttributedString.clearTextSizeCache()

    // single-line sizing ignores layoutWidth and lineBreakMode (it measures the natural, unwrapped line)
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)

    // when: measuring the size for 1 line at different widths and line break modes
    let narrow = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 50)
    let wide = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 5000)
    let charWrap = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 123, lineBreakMode: .byCharWrapping)

    // then: all sizes are equal
    expect(narrow) == wide
    expect(narrow) == charWrap
  }

  func test_cache_sameText_measuresOnce() throws {
    // given: a cleared cache and an attributed string
    NSAttributedString.clearTextSizeCache()
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)

    // when: measuring the size twice
    let counts = WorkCounter.counting {
      _ = attributedString.boundingRectSize(numberOfLines: 0, layoutWidth: 100)
      _ = attributedString.boundingRectSize(numberOfLines: 0, layoutWidth: 100)
    }

    // then: the text is measured once, and the second size comes from the cache
    expect(counts.textMeasurements) == 1
  }

  func test_cache_equalTextOfAnotherObject_isServedFromTheCache() throws {
    // given: a cleared cache and the size of an attributed string
    NSAttributedString.clearTextSizeCache()
    let attributedString = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)
    let size = attributedString.boundingRectSize(numberOfLines: 0, layoutWidth: 100)

    // when: measuring an equal text of another object
    let equalText = try makeAttributedString(font: Font.systemFont(ofSize: 16), lineBreakMode: .byWordWrapping)
    var equalTextSize = CGSize.zero
    let counts = WorkCounter.counting {
      equalTextSize = equalText.boundingRectSize(numberOfLines: 0, layoutWidth: 100)
    }

    // then: the size comes from the cache
    expect(equalText) !== attributedString
    expect(counts.textMeasurements) == 0
    expect(equalTextSize) == size
  }

  func test_cache_mutableText_keepsTheSizeOfTheTextAsMeasured() {
    // given: a cleared cache, and the size of a mutable text, which then changes
    NSAttributedString.clearTextSizeCache()
    let attributes: [NSAttributedString.Key: Any] = [.font: Font.systemFont(ofSize: 16)]
    let mutableString = NSMutableAttributedString(string: "Hi", attributes: attributes)
    let size = mutableString.boundingRectSize(numberOfLines: 1, layoutWidth: 1000)
    mutableString.append(NSAttributedString(string: " there", attributes: attributes))

    // when: measuring a text equal to the mutable text as it was measured
    var equalTextSize = CGSize.zero
    let counts = WorkCounter.counting {
      equalTextSize = NSAttributedString(string: "Hi", attributes: attributes).boundingRectSize(numberOfLines: 1, layoutWidth: 1000)
    }

    // then: the size comes from the cache, which kept a copy of the text as it was measured
    expect(counts.textMeasurements) == 0
    expect(equalTextSize) == size
  }

  func test_cache_pastTheGenerationLimit_keepsTheGenerationBefore() {
    // given: a cleared cache, and the sizes of a full generation of texts and of one more text, which starts the next
    // generation
    NSAttributedString.clearTextSizeCache()
    let texts = (0 ... TextSizeCache.generationLimit).map { NSAttributedString(string: "\($0)") }
    for text in texts {
      _ = text.boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    }

    // when: measuring the first text, which the full generation holds
    let firstCounts = WorkCounter.counting {
      _ = texts[0].boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    }

    // then: its size comes from the cache
    expect(firstCounts.textMeasurements) == 0

    // when: filling the next generation and starting a third one, which drops the full generation, then measuring the
    // first and the second texts again
    for index in 0 ..< TextSizeCache.generationLimit - 1 {
      _ = NSAttributedString(string: "next\(index)").boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    }
    let firstAgainCounts = WorkCounter.counting {
      _ = texts[0].boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    }
    let secondCounts = WorkCounter.counting {
      _ = texts[1].boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    }

    // then: the first text's size, which the lookup moved to the next generation, is kept, and the second text, which
    // the dropped generation held, is measured again
    expect(firstAgainCounts.textMeasurements) == 0
    expect(secondCounts.textMeasurements) == 1
  }

  func test_cache_movedBackSize_keepsItsStoredText() {
    // given: a cleared cache, the size of a text, which a full generation of other texts moves to the generation
    // before, and a mutable text equal to it
    NSAttributedString.clearTextSizeCache()
    let text = NSAttributedString(string: "Text")
    _ = text.boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    for index in 0 ..< TextSizeCache.generationLimit {
      _ = NSAttributedString(string: "\(index)").boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    }
    let mutableText = NSMutableAttributedString(string: "Text")

    // when: measuring the mutable text, which moves the size back, then changing the mutable text and measuring the
    // text again
    let movedBackCounts = WorkCounter.counting {
      _ = mutableText.boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    }
    mutableText.append(NSAttributedString(string: " changed"))
    let againCounts = WorkCounter.counting {
      _ = text.boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    }

    // then: both sizes come from the cache, since the moved size keeps its stored text instead of the mutable text
    expect(movedBackCounts.textMeasurements) == 0
    expect(againCounts.textMeasurements) == 0
  }

  func test_cache_memoryWarning_measuresAgain() {
    // given: a cleared cache and the size of a text
    NSAttributedString.clearTextSizeCache()
    let text = NSAttributedString(string: "Text")
    _ = text.boundingRectSize(numberOfLines: 1, layoutWidth: 100)

    // when: the system is low on memory, and measuring the text again
    MemoryWarning.handleMemoryWarning()
    let counts = WorkCounter.counting {
      _ = text.boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    }

    // then: the text is measured again
    expect(counts.textMeasurements) == 1
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
