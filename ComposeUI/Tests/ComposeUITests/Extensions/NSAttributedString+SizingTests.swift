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

  func test_singleline_byClipping() throws {
    let attributedString = try makeAttributedString(lineBreakMode: .byClipping)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    #if os(macOS)
    expect(size.width) == 100
    expect(size.height).to(beApproximatelyEqual(to: 18.8, within: 1e-1))
    #else
    expect(size.width) == 100
    expect(size.height).to(beApproximatelyEqual(to: 18.8, within: 1e-1))
    #endif
  }

  func test_singleline_byTruncatingTail() throws {
    let attributedString = try makeAttributedString(lineBreakMode: .byTruncatingTail)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    #if os(macOS)
    expect(size.width) == 100
    expect(size.height).to(beApproximatelyEqual(to: 18.8, within: 1e-1))
    #else
    expect(size.width) == 100
    expect(size.height).to(beApproximatelyEqual(to: 18.8, within: 1e-1))
    #endif
  }

  func test_singleline_byTruncatingHead() throws {
    let attributedString = try makeAttributedString(lineBreakMode: .byTruncatingHead)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    #if os(macOS)
    expect(size.width) == 100
    expect(size.height).to(beApproximatelyEqual(to: 18.8, within: 1e-1))
    #else
    expect(size.width) == 100
    expect(size.height).to(beApproximatelyEqual(to: 18.8, within: 1e-1))
    #endif
  }

  func test_singleline_byTruncatingMiddle() throws {
    let attributedString = try makeAttributedString(lineBreakMode: .byTruncatingMiddle)
    let size = attributedString.boundingRectSize(numberOfLines: 1, layoutWidth: 100)
    #if os(macOS)
    expect(size.width) == 100
    expect(size.height).to(beApproximatelyEqual(to: 18.8, within: 1e-1))
    #else
    expect(size.width) == 100
    expect(size.height).to(beApproximatelyEqual(to: 18.8, within: 1e-1))
    #endif
  }

  // MARK: - Multiline

  func test_multiline_byClipping() throws {
    let attributedString = try makeAttributedString(lineBreakMode: .byClipping)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 103.9, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.8, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 103.9, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.8, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingTail() throws {
    let attributedString = try makeAttributedString(lineBreakMode: .byTruncatingTail)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 103.9, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.8, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 103.9, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.8, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingHead() throws {
    let attributedString = try makeAttributedString(lineBreakMode: .byTruncatingHead)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 103.9, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.8, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 103.9, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.8, within: 1e-1))
    #endif
  }

  func test_multiline_byTruncatingMiddle() throws {
    let attributedString = try makeAttributedString(lineBreakMode: .byTruncatingMiddle)
    let size = attributedString.boundingRectSize(numberOfLines: 2, layoutWidth: 100)
    #if os(macOS)
    expect(size.width).to(beApproximatelyEqual(to: 103.9, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.8, within: 1e-1))
    #else
    expect(size.width).to(beApproximatelyEqual(to: 103.9, within: 1e-1))
    expect(size.height).to(beApproximatelyEqual(to: 36.8, within: 1e-1))
    #endif
  }

  private func makeAttributedString(lineBreakMode: NSLineBreakMode) throws -> NSAttributedString {
    try NSAttributedString(
      string: Constants.string,
      attributes: [
        .font: unwrap(Font(name: "HelveticaNeue", size: 16)),
        .foregroundColor: Color.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .left
          style.lineBreakMode = lineBreakMode
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
