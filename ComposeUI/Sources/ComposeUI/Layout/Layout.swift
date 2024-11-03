//
//  Layout.swift
//  ComposeUI
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
  public enum HorizontalAlignment: Hashable, Sendable {
    case center
    case left
    case right
  }

  /// The vertical alignment.
  public enum VerticalAlignment: Hashable, Sendable {
    case center
    case top
    case bottom
  }

  /// The alignment.
  public enum Alignment: Hashable, Sendable {
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

  /// Distribute `space` to nodes based on their sizings.
  ///
  /// - Parameters:
  ///   - space: The total space to distribute.
  ///   - nodes: The nodes to distribute the space to.
  /// - Returns: The allocated sizes to the nodes.
  static func stackLayout(space: CGFloat, children nodes: [ComposeNodeSizing.Sizing]) -> ContiguousArray<CGFloat> {
    let count = nodes.count
    guard count > 0 else {
      return []
    }

    // the allocated sizes to the nodes.
    var allocations = ContiguousArray<CGFloat>(repeating: 0, count: count)

    // the total allocated space.
    var allocatedSpace: CGFloat = 0

    // the indices of the expandable nodes.
    var expandableNodeIndices = ContiguousArray<Int>()
    expandableNodeIndices.reserveCapacity(count)
    var expandableNodeCount = 0

    // first pass: allocate fixed sizes and minimum sizes for range nodes
    for i in 0 ..< count {
      let node = nodes[i]
      switch node.normalized() {
      case .fixed(let size):
        allocations[i] = size // always allocate the fixed size
        allocatedSpace += size
      case .range(let min, _):
        allocations[i] = min // always allocate the minimum size
        allocatedSpace += min
        expandableNodeIndices.append(i)
        expandableNodeCount += 1
      case .flexible:
        expandableNodeIndices.append(i)
        expandableNodeCount += 1
      }
    }

    var remainingSpace = space - allocatedSpace

    // second pass: allocate remaining space to expandable nodes up to their maximum
    // use 0.01 to avoid floating point precision issues
    while remainingSpace > 0.01, expandableNodeCount > 0 {
      let spacePerNode = remainingSpace / CGFloat(expandableNodeCount)

      var i = 0
      while i < expandableNodeCount {
        let index = expandableNodeIndices[i]

        switch nodes[index] {
        case .range(_, let max):
          let currentAllocation = allocations[index]
          let additionalSpace = Swift.min(max - currentAllocation, spacePerNode)

          if additionalSpace <= 0 {
            // this should be impossible
            _ = expandableNodeIndices.swapRemove(at: i)
            expandableNodeCount -= 1
            continue
          }

          allocations[index] += additionalSpace
          remainingSpace -= additionalSpace

          if allocations[index] >= max {
            _ = expandableNodeIndices.swapRemove(at: i) // the node is fulfilled
            expandableNodeCount -= 1
            continue
          }

        case .flexible:
          allocations[index] += spacePerNode
          remainingSpace -= spacePerNode

        case .fixed:
          break // impossible
        }

        i += 1
      }
    }

    return allocations
  }
}
