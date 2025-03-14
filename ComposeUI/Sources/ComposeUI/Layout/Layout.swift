//
//  Layout.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
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

public enum Layout {

  /// The horizontal alignment.
  public enum HorizontalAlignment: Hashable, Sendable, CaseIterable {
    case center
    case left
    case right
  }

  /// The vertical alignment.
  public enum VerticalAlignment: Hashable, Sendable, CaseIterable {
    case center
    case top
    case bottom
  }

  /// The alignment.
  public enum Alignment: Hashable, Sendable, CaseIterable {
    case center
    case left
    case right
    case top
    case bottom
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
  }

  /// Position a rectangle in a container.
  ///
  /// - Parameters:
  ///   - size: The size of the rectangle.
  ///   - containerSize: The size of the container.
  ///   - alignment: The alignment of the rectangle.
  /// - Returns: The position of the rectangle.
  static func position(rect size: CGSize, in containerSize: CGSize, alignment: Layout.Alignment) -> CGRect {
    CGRect(
      origin: {
        switch alignment {
        case .center:
          return CGPoint(x: (containerSize.width - size.width) / 2, y: (containerSize.height - size.height) / 2)
        case .left:
          return CGPoint(x: 0, y: (containerSize.height - size.height) / 2)
        case .right:
          return CGPoint(x: containerSize.width - size.width, y: (containerSize.height - size.height) / 2)
        case .top:
          return CGPoint(x: (containerSize.width - size.width) / 2, y: 0)
        case .bottom:
          return CGPoint(x: (containerSize.width - size.width) / 2, y: containerSize.height - size.height)
        case .topLeft:
          return .zero
        case .topRight:
          return CGPoint(x: containerSize.width - size.width, y: 0)
        case .bottomLeft:
          return CGPoint(x: 0, y: containerSize.height - size.height)
        case .bottomRight:
          return CGPoint(x: containerSize.width - size.width, y: containerSize.height - size.height)
        }
      }(),
      size: size
    )
  }

  /// Distribute `space` to children items based on their sizings.
  ///
  /// - Parameters:
  ///   - space: The total space to distribute.
  ///   - items: The items to distribute the space to.
  /// - Returns: The allocated sizes to the items.
  static func stackLayout(space: CGFloat, items: [ComposeNodeSizing.Sizing]) -> ContiguousArray<CGFloat> {
    let count = items.count
    guard count > 0 else {
      return []
    }

    // the allocated sizes to the children.
    var allocations = ContiguousArray<CGFloat>(repeating: 0, count: count)

    // the total allocated space.
    var allocatedSpace: CGFloat = 0

    // the indices of the expandable items.
    var expandableItemIndices = ContiguousArray<Int>()
    expandableItemIndices.reserveCapacity(count)
    var expandableItemCount = 0

    // first pass: allocate fixed sizes and minimum sizes for range items
    for i in 0 ..< count {
      let item = items[i]
      switch item.normalized() {
      case .fixed(let size):
        allocations[i] = size // always allocate the fixed size
        allocatedSpace += size
      case .range(let min, _):
        allocations[i] = min // always allocate the minimum size
        allocatedSpace += min
        expandableItemIndices.append(i)
        expandableItemCount += 1
      case .flexible:
        expandableItemIndices.append(i)
        expandableItemCount += 1
      }
    }

    var remainingSpace = space - allocatedSpace

    // second pass: allocate remaining space to expandable items up to their maximum
    // use 0.01 to avoid floating point precision issues
    while remainingSpace > 0.01, expandableItemCount > 0 {
      let spacePerItem = remainingSpace / CGFloat(expandableItemCount)

      var i = 0
      while i < expandableItemCount {
        let index = expandableItemIndices[i]

        switch items[index] {
        case .range(_, let max):
          let currentAllocation = allocations[index]
          let additionalSpace = Swift.min(max - currentAllocation, spacePerItem)

          if additionalSpace <= 0 {
            // this should be impossible
            _ = expandableItemIndices.swapRemove(at: i)
            expandableItemCount -= 1
            continue
          }

          allocations[index] += additionalSpace
          remainingSpace -= additionalSpace

          if allocations[index] >= max {
            _ = expandableItemIndices.swapRemove(at: i) // the item is fulfilled
            expandableItemCount -= 1
            continue
          }

        case .flexible:
          allocations[index] += spacePerItem
          remainingSpace -= spacePerItem

        case .fixed:
          break // impossible
        }

        i += 1
      }
    }

    return allocations
  }
}
