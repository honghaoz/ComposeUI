//
//  RangeReplaceableCollection+Extensions.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/3/24.
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
