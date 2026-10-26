//
//  HorizontalStackNode.swift
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

public typealias HStack = HorizontalStackNode
public typealias HorizontalStack = HorizontalStackNode

/// A node that stacks its children horizontally.
///
/// The node's width is the sum of its children's widths plus the spacing between them.
/// The node's height is the maximum height of its children.
public struct HorizontalStackNode: ComposeNode, ContainerNodeInternal {

  public init(alignment: Layout.VerticalAlignment = .center,
              spacing: CGFloat = 0,
              @ComposeContentBuilder content: () -> ComposeContent)
  {
    stack = AxisStack(alignment: alignment, spacing: spacing, children: NodeList.buffer(of: content()))
  }

  var childNodes: [any ComposeNode] {
    get {
      stack.childNodes
    }
    set {
      stack.childNodes = newValue
    }
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.hStack)

  public var size: CGSize {
    stack.size
  }

  public var renderBounds: CGRect {
    stack.renderBounds
  }

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    stack.layout(containerSize: containerSize, context: context)
  }

  public func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
    stack.render(visibleBounds: visibleBounds, into: &items, id: id)
  }

  // MARK: - Stack

  /// The children, and their layout along the horizontal axis.
  ///
  /// Declared after `id`: it ends 7 bytes short of an 8-byte boundary, so as the last stored property, those bytes are
  /// the node's tail padding, which a struct that stores the node can put its next field in, instead of padding inside
  /// the node before `id`.
  private var stack: AxisStack<Axis>

  /// The horizontal axis, across which the stack aligns its children vertically.
  private enum Axis: StackAxis {

    static var mainAxis: StackLayoutCache.MainAxis {
      .horizontal
    }

    static func crossPosition(of childLength: CGFloat, in length: CGFloat, alignment: Layout.VerticalAlignment) -> CGFloat {
      switch alignment {
      case .center:
        return (length - childLength) / 2
      case .top:
        return 0
      case .bottom:
        return length - childLength
      }
    }
  }
}
