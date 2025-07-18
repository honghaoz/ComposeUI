//
//  FrameNode.swift
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

/// A type that represents the size of a dimension.
public enum FrameSize: Hashable {

  /// A fixed size.
  ///
  /// The node has a fixed size regardless of the container size.
  case fixed(CGFloat)

  /// A flexible size.
  ///
  /// The node has a flexible size that can grow or shrink based on the container size.
  case flexible

  /// An intrinsic size.
  ///
  /// The node has an intrinsic size based on its content.
  case intrinsic
}

/// A node that sets the frame of another node.
private struct FrameNode<Node: ComposeNode>: ComposeNode {

  private var node: Node

  private let width: FrameSize
  private let height: FrameSize
  private let alignment: Layout.Alignment

  fileprivate init(node: Node, width: FrameSize, height: FrameSize, alignment: Layout.Alignment) {
    self.node = node

    self.width = width
    self.height = height
    self.alignment = alignment
  }

  // MARK: - ComposeNode

  var id: ComposeNodeId = .standard(.frame)

  private(set) var size: CGSize = .zero

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    // prepare the proposing size for the child node
    let childContainerSize: CGSize
    switch (width, height) {
    case (.fixed(let width), .fixed(let height)):
      childContainerSize = CGSize(width: width, height: height)
    case (.fixed(let width), _):
      childContainerSize = CGSize(width: width, height: containerSize.height)
    case (_, .fixed(let height)):
      childContainerSize = CGSize(width: containerSize.width, height: height)
    default:
      childContainerSize = containerSize
    }

    let childNodeSizing = node.layout(containerSize: childContainerSize, context: context)

    // determine the final size and sizing for the wrapped node
    let sizing: ComposeNodeSizing
    switch (width, height) {
    case (.fixed(let width), .fixed(let height)):
      size = CGSize(width: width, height: height)
      sizing = ComposeNodeSizing(width: .fixed(width), height: .fixed(height))
    case (.fixed(let width), .flexible):
      size = CGSize(width: width, height: containerSize.height)
      sizing = ComposeNodeSizing(width: .fixed(width), height: .flexible)
    case (.fixed(let width), .intrinsic):
      size = CGSize(width: width, height: node.size.height)
      sizing = ComposeNodeSizing(width: .fixed(width), height: childNodeSizing.height)
    case (.flexible, .fixed(let height)):
      size = CGSize(width: containerSize.width, height: height)
      sizing = ComposeNodeSizing(width: .flexible, height: .fixed(height))
    case (.flexible, .flexible):
      size = containerSize
      sizing = ComposeNodeSizing(width: .flexible, height: .flexible)
    case (.flexible, .intrinsic):
      size = CGSize(width: containerSize.width, height: node.size.height)
      sizing = ComposeNodeSizing(width: .flexible, height: childNodeSizing.height)
    case (.intrinsic, .fixed(let height)):
      size = CGSize(width: node.size.width, height: height)
      sizing = ComposeNodeSizing(width: childNodeSizing.width, height: .fixed(height))
    case (.intrinsic, .flexible):
      size = CGSize(width: node.size.width, height: containerSize.height)
      sizing = ComposeNodeSizing(width: childNodeSizing.width, height: .flexible)
    case (.intrinsic, .intrinsic):
      size = node.size
      sizing = childNodeSizing
    }

    return sizing
  }

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    // the child node's frame in self's coordinates
    let childFrame = Layout.position(rect: node.size, in: size, alignment: alignment)

    // convert the bounds from self's coordinates to the child node's coordinates
    let boundsInChild = visibleBounds.translate(-childFrame.origin)

    let childItems = node.renderableItems(in: boundsInChild)

    var mappedChildItems: [RenderableItem] = []
    mappedChildItems.reserveCapacity(childItems.count)

    for var item in childItems {
      item.id = id.join(with: item.id)
      item.frame = item.frame.translate(childFrame.origin) // translate the frame back to the parent node's coordinates
      mappedChildItems.append(item)
    }

    return mappedChildItems
  }
}

// MARK: - ComposeNode

public extension ComposeNode {

  /// Sets the frame of the node.
  ///
  /// - Parameters:
  ///   - width: The width of the node.
  ///   - height: The height of the node.
  ///   - alignment: The alignment of the node. Default to `.center`.
  func frame(width: FrameSize, height: FrameSize, alignment: Layout.Alignment = .center) -> any ComposeNode {
    if case .intrinsic = width, case .intrinsic = height {
      // intrinsic size has no effect on the layout
      return self
    } else {
      return FrameNode(node: self, width: width, height: height, alignment: alignment)
    }
  }

  /// Sets the frame of the node.
  ///
  /// - Parameters:
  ///   - width: The width of the node.
  ///   - height: The height of the node.
  ///   - alignment: The alignment of the node. Default to `.center`.
  func frame(width: CGFloat, height: FrameSize, alignment: Layout.Alignment = .center) -> some ComposeNode {
    FrameNode(node: self, width: .fixed(width), height: height, alignment: alignment)
  }

  /// Sets the frame of the node.
  ///
  /// - Parameters:
  ///   - width: The width of the node.
  ///   - height: The height of the node.
  ///   - alignment: The alignment of the node. Default to `.center`.
  func frame(width: FrameSize, height: CGFloat, alignment: Layout.Alignment = .center) -> some ComposeNode {
    FrameNode(node: self, width: width, height: .fixed(height), alignment: alignment)
  }

  /// Sets the frame of the node.
  ///
  /// - Parameters:
  ///   - width: The width of the node.
  ///   - height: The height of the node.
  ///   - alignment: The alignment of the node. Default to `.center`.
  func frame(width: CGFloat, height: CGFloat, alignment: Layout.Alignment = .center) -> some ComposeNode {
    FrameNode(node: self, width: .fixed(width), height: .fixed(height), alignment: alignment)
  }

  /// Sets the frame of the node.
  ///
  /// - Parameters:
  ///   - size: The size of the node.
  ///   - alignment: The alignment of the node. Default to `.center`.
  func frame(_ size: CGSize, alignment: Layout.Alignment = .center) -> some ComposeNode {
    FrameNode(node: self, width: .fixed(size.width), height: .fixed(size.height), alignment: alignment)
  }

  /// Sets the frame of the node.
  ///
  /// - Parameters:
  ///   - size: The size of the node.
  ///   - alignment: The alignment of the node. Default to `.center`.
  func frame(_ size: CGFloat, alignment: Layout.Alignment = .center) -> some ComposeNode {
    FrameNode(node: self, width: .fixed(size), height: .fixed(size), alignment: alignment)
  }

  /// Sets the frame of the node.
  ///
  /// - Parameters:
  ///   - size: The size of the node.
  ///   - alignment: The alignment of the node. Default to `.center`.
  func frame(_ size: FrameSize, alignment: Layout.Alignment = .center) -> any ComposeNode {
    if case .intrinsic = size {
      // intrinsic size has no effect on the layout
      return self
    } else {
      return FrameNode(node: self, width: size, height: size, alignment: alignment)
    }
  }

  /// Sets the width of the node.
  ///
  /// - Parameters:
  ///   - width: The width of the node.
  ///   - alignment: The alignment of the node. Default to `.center`.
  func width(_ width: CGFloat, alignment: Layout.Alignment = .center) -> some ComposeNode {
    FrameNode(node: self, width: .fixed(width), height: .intrinsic, alignment: alignment)
  }

  /// Sets the height of the node.
  ///
  /// - Parameters:
  ///   - height: The height of the node.
  ///   - alignment: The alignment of the node. Default to `.center`.
  func height(_ height: CGFloat, alignment: Layout.Alignment = .center) -> some ComposeNode {
    FrameNode(node: self, width: .intrinsic, height: .fixed(height), alignment: alignment)
  }

  /// Sets the alignment of the node within its container.
  ///
  /// - Parameters:
  ///   - alignment: The alignment of the node. Default to `.center`.
  func alignment(_ alignment: Layout.Alignment) -> some ComposeNode {
    FrameNode(node: self, width: .flexible, height: .flexible, alignment: alignment)
  }
}
