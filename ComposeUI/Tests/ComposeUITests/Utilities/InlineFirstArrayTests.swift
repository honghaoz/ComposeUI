//
//  InlineFirstArrayTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/9/26.
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

class InlineFirstArrayTests: XCTestCase {

  func test_empty() {
    // when: creating a collection
    let array = InlineFirstArray<Int>()

    // then: it's empty
    expect(array.isEmpty) == true
    expect(array.count) == 0
    expect(Array(array)) == []
  }

  func test_append_oneElement() {
    // given: an empty collection
    var array = InlineFirstArray<Int>()

    // when: adding an element
    array.append(1)

    // then: it has the element
    expect(array.count) == 1
    expect(array[0]) == 1
    expect(Array(array)) == [1]
  }

  func test_append_moreElements() {
    // given: an empty collection
    var array = InlineFirstArray<Int>()

    // when: adding elements
    array.append(1)
    array.append(2)
    array.append(3)

    // then: it has the elements in the order they were added
    expect(array.count) == 3
    expect(array[0]) == 1
    expect(array[1]) == 2
    expect(array[2]) == 3
    expect(Array(array)) == [1, 2, 3]
    expect(Array(array.reversed())) == [3, 2, 1]
  }
}
