//
//  RangeReplaceableCollection+Extensions.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 11/3/24.
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

import Foundation

extension RangeReplaceableCollection where Self: BidirectionalCollection & MutableCollection {

  /// Removes and returns the element at the specified position by swapping with the last element.
  ///
  /// This is more efficient than regular remove(at:) for cases where element order doesn't matter.
  ///
  /// - Parameter index: The position of the element to remove. `index` must be a valid index of the collection.
  /// - Returns: The removed element.
  /// - Complexity: O(1) when using a random-access collection
  @inlinable mutating func swapRemove(at index: Index) -> Element {
    guard index != self.index(before: endIndex) else {
      return removeLast()
    }

    swapAt(index, self.index(before: endIndex))
    return removeLast()
  }
}
