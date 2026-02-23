//
//  UIEdgeInsets+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 2/22/26.
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

import XCTest
import UIKit

@testable import ComposeUI

class UIEdgeInsets_ExtensionsTests: XCTestCase {

  func test_horizontal() {
    let insets = UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4)
    XCTAssertEqual(insets.horizontal, 6)
  }

  func test_vertical() {
    let insets = UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4)
    XCTAssertEqual(insets.vertical, 4)
  }

  func test_initInset() {
    let insets = UIEdgeInsets(inset: 8)
    XCTAssertEqual(insets.top, 8)
    XCTAssertEqual(insets.left, 8)
    XCTAssertEqual(insets.bottom, 8)
    XCTAssertEqual(insets.right, 8)
  }
}
