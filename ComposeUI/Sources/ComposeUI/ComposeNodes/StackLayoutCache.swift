//
//  StackLayoutCache.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 6/11/26.
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

/// A cache of a stack node's children layout information.
///
/// Stack nodes build this cache in `layout(containerSize:context:)` and use it in `renderableItems(in:)`
/// to skip querying child nodes that can't provide visible renderable items, so that getting renderable
/// items is O(visible children) instead of O(all children).
struct StackLayoutCache {

  /// The main axis of the stack that the cache builds the search structures for.
  enum MainAxis {
    case horizontal
    case vertical
  }

  /// The number of cached children.
  private(set) var childCount: Int = 0

  /// Each child's origin, in the stack node's coordinate space.
  private(set) var childOrigins: ContiguousArray<CGPoint> = []

  /// Each child's renderable items bounding rect, in the stack node's coordinate space.
  ///
  /// The rect is `.null` if the child can't provide any renderable items.
  private(set) var childItemsBoundingRects: ContiguousArray<CGRect> = []

  /// The union of all children's renderable items bounding rects, in the stack node's coordinate space.
  ///
  /// The rect is `.null` if no child can provide any renderable items.
  private(set) var itemsBoundingRect: CGRect = .null

  /// Running maximum (from the first child) of the children's items bounding rect max position on the main axis.
  ///
  /// The values are non-decreasing, which makes them binary searchable.
  private var runningMaxPositions: ContiguousArray<CGFloat> = []

  /// Running minimum (from the last child) of the children's items bounding rect min position on the main axis.
  ///
  /// The values are non-decreasing, which makes them binary searchable.
  private var runningMinPositions: ContiguousArray<CGFloat> = []

  /// Rebuild the cache with the children's layout information.
  ///
  /// - Parameters:
  ///   - childOrigins: Each child's origin, in the stack node's coordinate space.
  ///   - childItemsBoundingRects: Each child's renderable items bounding rect, translated to the stack node's coordinate space.
  ///   - mainAxis: The main axis of the stack. Pass `nil` for stacks whose children are not ordered along an axis (e.g. a layered stack),
  ///     which skips building the binary-search structures that only `visibleChildRange(minPosition:maxPosition:)` uses.
  mutating func update(childOrigins: ContiguousArray<CGPoint>,
                       childItemsBoundingRects: ContiguousArray<CGRect>,
                       mainAxis: MainAxis?)
  {
    ComposeUI.assert(childOrigins.count == childItemsBoundingRects.count, "mismatched child origins and bounding rects count")

    childCount = childOrigins.count
    self.childOrigins = childOrigins
    self.childItemsBoundingRects = childItemsBoundingRects

    var itemsBoundingRect: CGRect = .null

    runningMaxPositions.removeAll(keepingCapacity: true)
    runningMinPositions.removeAll(keepingCapacity: true)

    guard let mainAxis else {
      // no main axis: the caller doesn't use `visibleChildRange(minPosition:maxPosition:)`, so only collect the union of the bounding rects.
      for rect in childItemsBoundingRects where !rect.isNull {
        itemsBoundingRect = itemsBoundingRect.union(rect)
      }
      self.itemsBoundingRect = itemsBoundingRect
      return
    }

    runningMaxPositions.reserveCapacity(childCount)
    runningMinPositions.reserveCapacity(childCount)

    // build the running max positions (from the first child) and collect the union of the bounding rects
    var runningMax: CGFloat = -.greatestFiniteMagnitude
    for rect in childItemsBoundingRects {
      if !rect.isNull {
        itemsBoundingRect = itemsBoundingRect.union(rect)
        runningMax = Swift.max(runningMax, mainAxis == .vertical ? rect.maxY : rect.maxX)
      }
      runningMaxPositions.append(runningMax)
    }

    // build the running min positions (from the last child)
    var runningMin: CGFloat = .greatestFiniteMagnitude
    runningMinPositions.append(contentsOf: repeatElement(0, count: childCount))
    for i in stride(from: childCount - 1, through: 0, by: -1) {
      let rect = childItemsBoundingRects[i]
      if !rect.isNull {
        runningMin = Swift.min(runningMin, mainAxis == .vertical ? rect.minY : rect.minX)
      }
      runningMinPositions[i] = runningMin
    }

    self.itemsBoundingRect = itemsBoundingRect
  }

  /// Get the range of children that can provide visible renderable items for the given visible range on the main axis.
  ///
  /// Children outside of the returned range are guaranteed to provide no visible renderable items.
  /// Children within the returned range may still provide no visible renderable items, the caller should
  /// still query each child with `renderableItems(in:)`.
  ///
  /// The cache must be built with a main axis (`update(childOrigins:childItemsBoundingRects:mainAxis:)` with a non-nil `mainAxis`).
  ///
  /// - Parameters:
  ///   - minPosition: The min position of the visible bounds on the main axis.
  ///   - maxPosition: The max position of the visible bounds on the main axis.
  /// - Returns: The range of children that can provide visible renderable items.
  func visibleChildRange(minPosition: CGFloat, maxPosition: CGFloat) -> Range<Int> {
    guard runningMaxPositions.count == childCount, runningMinPositions.count == childCount else {
      // the cache was built without a main axis, so there are no search structures. treat all children as potentially
      // visible, which is safe because the caller still queries each child.
      ComposeUI.assertFailure("visibleChildRange(minPosition:maxPosition:) requires the cache built with a main axis")
      return 0 ..< childCount
    }

    // the first child whose items can extend beyond the visible min position.
    // children before this index have all of their items at or before the visible min position (no intersection).
    let start = Self.firstIndex(in: runningMaxPositions) { $0 > minPosition }

    // the first child from which all of the remaining children's items are at or beyond the visible max position (no intersection).
    let end = Self.firstIndex(in: runningMinPositions) { $0 >= maxPosition }

    return start ..< Swift.max(start, end)
  }

  /// Binary search for the first index whose value satisfies the predicate.
  ///
  /// The values must be partitioned by the predicate: all values that don't satisfy the predicate
  /// must come before all values that do.
  ///
  /// - Parameters:
  ///   - values: The values to search.
  ///   - predicate: The predicate to satisfy.
  /// - Returns: The first index whose value satisfies the predicate, or `values.count` if no value satisfies it.
  private static func firstIndex(in values: ContiguousArray<CGFloat>, where predicate: (CGFloat) -> Bool) -> Int {
    var low = 0
    var high = values.count
    while low < high {
      let mid = (low + high) / 2
      if predicate(values[mid]) {
        high = mid
      } else {
        low = mid + 1
      }
    }
    return low
  }
}
