//
//  InlineFirstArray.swift
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

/// A collection that keeps its first element inline, so a collection of one element doesn't allocate.
///
/// A layer's key path usually has one animation in flight, so a retarget collects the animations in it instead of an
/// array, which allocates for its first element.
struct InlineFirstArray<Element>: RandomAccessCollection {

  /// The first element, `nil` when the collection is empty.
  private var firstElement: Element?

  /// The elements after the first.
  private var otherElements: [Element]

  /// Creates an empty collection.
  init() {
    firstElement = nil
    otherElements = []
  }

  var startIndex: Int {
    0
  }

  var endIndex: Int {
    firstElement == nil ? 0 : otherElements.count + 1
  }

  subscript(position: Int) -> Element {
    if position == 0, let firstElement {
      return firstElement
    }
    return otherElements[position - 1]
  }

  /// Adds an element at the end.
  ///
  /// - Parameter element: The element to add.
  mutating func append(_ element: Element) {
    if firstElement == nil {
      firstElement = element
    } else {
      otherElements.append(element)
    }
  }
}
