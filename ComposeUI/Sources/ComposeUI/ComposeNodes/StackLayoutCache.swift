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
///
/// A layout rebuilds it with `reset(reservingCapacity:)`, then `appendChild(origin:itemsBoundingRect:)` for each child,
/// then `finish(mainAxis:)`.
struct StackLayoutCache {

  /// The main axis of the stack that the cache builds the search structures for.
  enum MainAxis {
    case horizontal
    case vertical
  }

  /// A child's layout information.
  struct Child {

    /// The layout information of no child, which fills the unused inline storage.
    fileprivate static let empty = Child(origin: .zero, itemsBoundingRect: .null)

    /// The child's origin, in the stack node's coordinate space.
    let origin: CGPoint

    /// The child's renderable items bounding rect, in the stack node's coordinate space.
    ///
    /// The rect is `.null` if the child can't provide any renderable items.
    let itemsBoundingRect: CGRect

    /// The running maximum, from the first child, of the children's items bounding rect max position on the main axis.
    ///
    /// The values are non-decreasing, which makes them binary searchable.
    fileprivate(set) var runningMaxPosition: CGFloat

    /// The running minimum, from the last child, of the children's items bounding rect min position on the main axis.
    ///
    /// The values are non-decreasing, which makes them binary searchable.
    fileprivate(set) var runningMinPosition: CGFloat

    fileprivate init(origin: CGPoint, itemsBoundingRect: CGRect) {
      self.origin = origin
      self.itemsBoundingRect = itemsBoundingRect
      runningMaxPosition = 0
      runningMinPosition = 0
    }
  }

  /// The most children whose layout information the cache keeps inline instead of in an array.
  static let inlineCapacity = 4

  /// Each child's layout information when the stack has up to `inlineCapacity` children, inline, so that the layout
  /// of a new stack with a few children, as a row usually is, allocates nothing.
  private var inlineChildren: (Child, Child, Child, Child) = (.empty, .empty, .empty, .empty)

  /// Each child's layout information when the stack has more children than `inlineCapacity`, in one array, so that a
  /// layout allocates once for all of it.
  private var heapChildren: ContiguousArray<Child> = []

  /// Whether the children's layout information is in `heapChildren` instead of `inlineChildren`.
  private var usesHeapChildren = false

  /// The number of cached children.
  private(set) var childCount = 0

  /// Returns a child's layout information.
  ///
  /// - Parameter index: The child's index, less than `childCount`.
  /// - Returns: The child's layout information.
  func child(at index: Int) -> Child {
    self[index]
  }

  /// A child's layout information, in the inline storage or the array.
  private subscript(index: Int) -> Child {
    get {
      guard usesHeapChildren else {
        switch index {
        case 0:
          return inlineChildren.0
        case 1:
          return inlineChildren.1
        case 2:
          return inlineChildren.2
        default:
          return inlineChildren.3
        }
      }
      return heapChildren[index]
    }
    set {
      guard usesHeapChildren else {
        switch index {
        case 0:
          inlineChildren.0 = newValue
        case 1:
          inlineChildren.1 = newValue
        case 2:
          inlineChildren.2 = newValue
        default:
          inlineChildren.3 = newValue
        }
        return
      }
      heapChildren[index] = newValue
    }
  }

  /// Calls the closure with the children's layout information as one buffer, in the inline storage or the array, so
  /// that a loop over the children changes each one in place instead of copying it out and back.
  private mutating func withMutableChildren<Result>(_ body: (UnsafeMutableBufferPointer<Child>) -> Result) -> Result {
    if usesHeapChildren {
      return heapChildren.withUnsafeMutableBufferPointer { body($0) }
    }
    let childCount = childCount
    return withUnsafeMutablePointer(to: &inlineChildren) { tuple in
      tuple.withMemoryRebound(to: Child.self, capacity: Self.inlineCapacity) { children in
        body(UnsafeMutableBufferPointer(start: children, count: childCount))
      }
    }
  }

  /// The union of all children's renderable items bounding rects, in the stack node's coordinate space.
  ///
  /// The rect is `.null` if no child can provide any renderable items.
  private(set) var itemsBoundingRect: CGRect = .null

  /// Whether the cache was finished with a main axis, which builds the search structures that
  /// `visibleChildRange(minPosition:maxPosition:)` uses.
  private var hasSearchStructures = false

  /// Starts rebuilding the cache, removing the children of the previous layout.
  ///
  /// - Parameter capacity: The number of children the layout appends.
  mutating func reset(reservingCapacity capacity: Int) {
    childCount = 0
    heapChildren.removeAll(keepingCapacity: true)
    usesHeapChildren = capacity > Self.inlineCapacity
    if usesHeapChildren {
      heapChildren.reserveCapacity(capacity)
    }
    itemsBoundingRect = .null
    hasSearchStructures = false
  }

  /// Appends a child's layout information.
  ///
  /// - Parameters:
  ///   - origin: The child's origin, in the stack node's coordinate space.
  ///   - itemsBoundingRect: The child's renderable items bounding rect, translated to the stack node's coordinate
  ///     space.
  mutating func appendChild(origin: CGPoint, itemsBoundingRect: CGRect) {
    let child = Child(origin: origin, itemsBoundingRect: itemsBoundingRect)
    if usesHeapChildren {
      heapChildren.append(child)
    } else if childCount < Self.inlineCapacity {
      self[childCount] = child
    } else {
      // more children than the reset reserved: they move to the array, which has room for any number
      heapChildren = [inlineChildren.0, inlineChildren.1, inlineChildren.2, inlineChildren.3, child]
      usesHeapChildren = true
    }
    childCount += 1
  }

  /// Finishes rebuilding the cache, after the children are appended.
  ///
  /// - Parameter mainAxis: The main axis of the stack. Pass `nil` for stacks whose children are not ordered along an
  ///   axis (e.g. a layered stack), which skips building the binary-search structures that only
  ///   `visibleChildRange(minPosition:maxPosition:)` uses.
  mutating func finish(mainAxis: MainAxis?) {
    let itemsBoundingRect: CGRect = withMutableChildren { children in
      var itemsBoundingRect: CGRect = .null

      guard let mainAxis else {
        // no main axis: the caller doesn't use `visibleChildRange(minPosition:maxPosition:)`, so only collect the
        // union of the bounding rects.
        for child in children where !child.itemsBoundingRect.isNull {
          itemsBoundingRect = itemsBoundingRect.union(child.itemsBoundingRect)
        }
        return itemsBoundingRect
      }

      // build the running max positions (from the first child) and collect the union of the bounding rects
      var runningMax: CGFloat = -.greatestFiniteMagnitude
      for index in children.indices {
        let rect = children[index].itemsBoundingRect
        if !rect.isNull {
          itemsBoundingRect = itemsBoundingRect.union(rect)
          runningMax = Swift.max(runningMax, mainAxis == .vertical ? rect.maxY : rect.maxX)
        }
        children[index].runningMaxPosition = runningMax
      }

      // build the running min positions (from the last child)
      var runningMin: CGFloat = .greatestFiniteMagnitude
      for index in children.indices.reversed() {
        let rect = children[index].itemsBoundingRect
        if !rect.isNull {
          runningMin = Swift.min(runningMin, mainAxis == .vertical ? rect.minY : rect.minX)
        }
        children[index].runningMinPosition = runningMin
      }

      return itemsBoundingRect
    }

    self.itemsBoundingRect = itemsBoundingRect
    hasSearchStructures = mainAxis != nil
  }

  /// Get the range of children that can provide visible renderable items for the given visible range on the main axis.
  ///
  /// Children outside of the returned range are guaranteed to provide no visible renderable items.
  /// Children within the returned range may still provide no visible renderable items, the caller should
  /// still query each child with `renderableItems(in:)`.
  ///
  /// The cache must be finished with a main axis (`finish(mainAxis:)` with a non-nil `mainAxis`), unless it's empty.
  ///
  /// - Parameters:
  ///   - minPosition: The min position of the visible bounds on the main axis.
  ///   - maxPosition: The max position of the visible bounds on the main axis.
  /// - Returns: The range of children that can provide visible renderable items.
  func visibleChildRange(minPosition: CGFloat, maxPosition: CGFloat) -> Range<Int> {
    // an empty cache, such as an empty stack's, has no children to search
    guard hasSearchStructures || childCount == 0 else {
      // the cache was built without a main axis, so there are no search structures. treat all children as potentially
      // visible, which is safe because the caller still queries each child.
      ComposeUI.assertFailure("visibleChildRange(minPosition:maxPosition:) requires the cache built with a main axis")
      return 0 ..< childCount
    }

    // the first child whose items can extend beyond the visible min position.
    // children before this index have all of their items at or before the visible min position (no intersection).
    let start = firstChildIndex { $0.runningMaxPosition > minPosition }

    // the first child from which all of the remaining children's items are at or beyond the visible max position (no
    // intersection).
    let end = firstChildIndex { $0.runningMinPosition >= maxPosition }

    return start ..< Swift.max(start, end)
  }

  /// Binary search for the first child that satisfies the predicate.
  ///
  /// The children must be partitioned by the predicate: all children that don't satisfy the predicate
  /// must come before all children that do.
  ///
  /// - Parameter predicate: The predicate to satisfy.
  /// - Returns: The index of the first child that satisfies the predicate, or `childCount` if no child satisfies it.
  private func firstChildIndex(where predicate: (Child) -> Bool) -> Int {
    var low = 0
    var high = childCount
    while low < high {
      let mid = (low + high) / 2
      if predicate(self[mid]) {
        high = mid
      } else {
        low = mid + 1
      }
    }
    return low
  }
}
