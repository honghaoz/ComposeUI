//
//  Layout.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import CoreGraphics

public enum Layout {

  public enum HorizontalAlignment: Hashable, Sendable {
    case center
    case left
    case right
  }

  public enum VerticalAlignment: Hashable, Sendable {
    case center
    case top
    case bottom
  }

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
  static func stackLayout(space: CGFloat, children: [ComposeNodeSizing.Sizing]) -> [CGFloat] {
    guard !children.isEmpty else {
      return []
    }

    let nodes = children.map { $0.normalized() }

    let count = nodes.count

    // the allocated sizes to the nodes.
    var allocations = [CGFloat](repeating: 0, count: count)

    // the sum of the allocated sizes.
    var allocatedSpace: CGFloat = 0

    var expandableNodeIndices = [Int]()
    expandableNodeIndices.reserveCapacity(count)

    // first pass: allocate fixed sizes and minimum sizes for range nodes
    for (index, node) in nodes.enumerated() {
      switch node {
      case .fixed(let size):
        // always allocate the fixed size
        allocations[index] = size
        allocatedSpace += size
      case .range(let min, _):
        // always allocate the minimum size
        allocations[index] = min
        allocatedSpace += min
        expandableNodeIndices.append(index)
      case .flexible:
        expandableNodeIndices.append(index)
      }
    }

    var remainingSpace = space - allocatedSpace

    // second pass: allocate remaining space to expandable nodes up to their maximum
    while remainingSpace > 0.01, !expandableNodeIndices.isEmpty {
      let spacePerNode = remainingSpace / CGFloat(expandableNodeIndices.count)

      var i = 0
      while i < expandableNodeIndices.count {
        let index = expandableNodeIndices[i]

        switch nodes[index] {
        case .range(_, let max):
          let currentAllocation = allocations[index]
          let additionalSpace = Swift.min(max - currentAllocation, spacePerNode)
          assert(additionalSpace > 0, "additional space must be > 0, got \(additionalSpace)")

          allocations[index] += additionalSpace
          allocatedSpace += additionalSpace
          remainingSpace -= additionalSpace

          if allocations[index] >= max {
            expandableNodeIndices.remove(at: i) // the node is fulfilled
            i -= 1
          }
        case .flexible:
          allocations[index] += spacePerNode
          allocatedSpace += spacePerNode
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
