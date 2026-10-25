//
//  ComposeNodeSizingTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/24/26.
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

import ChouTiTest

@testable import ComposeUI

class ComposeNodeSizingTests: XCTestCase {

  func test_init_dependence() {
    // given: a sizing made without a dependence, as a node that doesn't report one makes it
    let sizing = ComposeNodeSizing(width: .fixed(10), height: .flexible)

    // then: it depends on both lengths, which is correct for any layout
    expect(sizing.dependence) == [.width, .height]

    // given: a sizing made with a dependence
    let widthSizing = ComposeNodeSizing(width: .fixed(10), height: .flexible, dependence: .width)

    // then: it has that dependence
    expect(widthSizing.dependence) == .width
  }

  func test_equality_ignoresDependence() {
    // given: two sizings of the same behaviors, made by layouts that depended on different lengths
    let sizing = ComposeNodeSizing(width: .fixed(10), height: .flexible, dependence: .width)
    let otherSizing = ComposeNodeSizing(width: .fixed(10), height: .flexible, dependence: [])

    // then: they're equal and hash the same
    expect(sizing) == otherSizing
    expect(sizing.hashValue) == otherSizing.hashValue

    // then: sizings of another width or height behavior aren't equal
    expect(sizing) != ComposeNodeSizing(width: .fixed(20), height: .flexible, dependence: .width)
    expect(sizing) != ComposeNodeSizing(width: .fixed(10), height: .fixed(10), dependence: .width)
  }

  func test_dependence_isSame_comparesTheLengthsItContains() {
    // given: a container size, and sizes that differ from it in the width, the height, or both
    let size = CGSize(width: 100, height: 200)
    let otherWidth = CGSize(width: 150, height: 200)
    let otherHeight = CGSize(width: 100, height: 250)
    let otherWidthAndHeight = CGSize(width: 150, height: 250)

    // then: a layout that depended on no length is the same at any size
    let none: ComposeNodeSizing.Dependence = []
    expect(none.isSame(size, as: size)) == true
    expect(none.isSame(size, as: otherWidthAndHeight)) == true

    // then: a layout that depended on the width compares the widths alone
    let width: ComposeNodeSizing.Dependence = .width
    expect(width.isSame(size, as: otherHeight)) == true
    expect(width.isSame(size, as: otherWidth)) == false
    expect(width.isSame(size, as: otherWidthAndHeight)) == false

    // then: a layout that depended on the height compares the heights alone
    let height: ComposeNodeSizing.Dependence = .height
    expect(height.isSame(size, as: otherWidth)) == true
    expect(height.isSame(size, as: otherHeight)) == false
    expect(height.isSame(size, as: otherWidthAndHeight)) == false

    // then: a layout that depended on both lengths compares both
    let widthAndHeight: ComposeNodeSizing.Dependence = [.width, .height]
    expect(widthAndHeight.isSame(size, as: size)) == true
    expect(widthAndHeight.isSame(size, as: otherWidth)) == false
    expect(widthAndHeight.isSame(size, as: otherHeight)) == false
  }
}
