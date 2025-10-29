//
//  ComposeViewNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/11/25.
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

/// A node that renders a `ComposeView` with a given content.
///
/// By default, the node has a fixed size (with `isFixedWidth` and `isFixedHeight` set to `true`). This means the node will use the content node's size as its size.
/// Use `fixedSize(width:height:)` to control whether the node uses the content node's size or adapts to the container size for each dimension.
///
/// For example, below code will have a fixed width of 100 and height of 100 regardless of the container size.
///
/// ```swift
/// ComposeViewNode {
///   ColorNode(.red).frame(width: 100, height: 100)
/// }
/// ```
///
/// Below code will have a fixed width of 100 and adapt to the container size for height.
/// ```swift
/// ComposeViewNode {
///   ColorNode(.red).frame(width: 100, height: 100)
/// }
/// .fixedSize(width: true, height: false)
/// ```
public struct ComposeViewNode: ComposeNode, IntrinsicSizableComposeNode {

  public var isFixedWidth: Bool = true
  public var isFixedHeight: Bool = true

  /// The content node.
  private var node: ComposeNode

  /// The view node that renders the `ComposeView`.
  private var viewNode: ViewNode<ComposeView>?

  /// Initialize a `ComposeViewNode` with the given content.
  ///
  /// - Parameter content: The content.
  public init(@ComposeContentBuilder content: () -> ComposeContent) {
    self.node = content().asVStack()
  }

  public var id: ComposeUI.ComposeNodeId = .standard(.composeView)

  public var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize, context: ComposeUI.ComposeNodeLayoutContext) -> ComposeUI.ComposeNodeSizing {
    // use the content node to do the layout
    let sizing = node.layout(containerSize: containerSize, context: context)

    if viewNode == nil {
      viewNode = ViewNode(
        make: {
          ComposeView(frame: $0.initialFrame ?? .zero)
        },
        willInsert: { [node] view, _ in
          // set the content to the view
          view.setContent { node }
        }
      )
      viewNode?.id = id
    }

    switch (isFixedWidth, isFixedHeight) {
    case (true, true):
      size = node.size
      // the view node has a flexible size, it follows the container size
      // use the content node's size as the container size so that the view node follows the content node's size.
      _ = viewNode?.layout(containerSize: size, context: context)
      return sizing
    case (true, false):
      size = CGSize(width: node.size.width, height: containerSize.height)
      _ = viewNode?.layout(containerSize: size, context: context)
      return ComposeNodeSizing(width: sizing.width, height: .flexible)
    case (false, true):
      size = CGSize(width: containerSize.width, height: node.size.height)
      _ = viewNode?.layout(containerSize: size, context: context)
      return ComposeNodeSizing(width: .flexible, height: sizing.height)
    case (false, false):
      size = containerSize
      _ = viewNode?.layout(containerSize: size, context: context)
      return ComposeNodeSizing(width: .flexible, height: .flexible)
    }
  }

  public func renderableItems(in visibleBounds: CGRect) -> [ComposeUI.RenderableItem] {
    guard let viewNode else {
      ComposeUI.assertFailure("renderableItems(in:) is called before layout(containerSize:context:).")
      return []
    }
    return viewNode.renderableItems(in: visibleBounds)
  }
}
