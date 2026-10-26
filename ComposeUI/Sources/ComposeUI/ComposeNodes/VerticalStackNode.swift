//
//  VerticalStackNode.swift
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

public typealias VStack = VerticalStackNode
public typealias VerticalStack = VerticalStackNode

/// A node that stacks its children vertically.
///
/// The node's width is the maximum width of its children.
/// The node's height is the sum of its children's heights plus the spacing between them.
public struct VerticalStackNode: ComposeNode, ContainerNodeInternal {

  public init(alignment: Layout.HorizontalAlignment = .center,
              spacing: CGFloat = 0,
              @ComposeContentBuilder content: () -> ComposeContent)
  {
    // the stack is built in place, since delegating to `init(alignment:spacing:children:)` builds the node in a
    // temporary and copies all of it into place
    stack = AxisStack(alignment: alignment, spacing: spacing, children: NodeList.buffer(of: content()))
  }

  /// Creates a stack of the children in a buffer.
  init(alignment: Layout.HorizontalAlignment, spacing: CGFloat, children: NodeBuffer) {
    stack = AxisStack(alignment: alignment, spacing: spacing, children: children)
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

  public var id: ComposeNodeId = .standard(.vStack)

  public var size: CGSize {
    stack.size
  }

  public var renderableItemsBounds: CGRect {
    stack.renderableItemsBounds
  }

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    stack.layout(containerSize: containerSize, context: context)
  }

  public func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
    stack.render(visibleBounds: visibleBounds, into: &items, id: id)
  }

  // MARK: - Stack

  /// The children, and their layout along the vertical axis.
  ///
  /// Declared after `id`: it ends 7 bytes short of an 8-byte boundary, so as the last stored property, those bytes are
  /// the node's tail padding, which a struct that stores the node can put its next field in, instead of padding inside
  /// the node before `id`.
  private var stack: AxisStack<Axis>

  /// The vertical axis, across which the stack aligns its children horizontally.
  private enum Axis: StackAxis {

    static var mainAxis: StackLayoutCache.MainAxis {
      .vertical
    }

    static func crossPosition(of childLength: CGFloat, in length: CGFloat, alignment: Layout.HorizontalAlignment) -> CGFloat {
      switch alignment {
      case .center:
        return (length - childLength) / 2
      case .left:
        return 0
      case .right:
        return length - childLength
      }
    }
  }
}
