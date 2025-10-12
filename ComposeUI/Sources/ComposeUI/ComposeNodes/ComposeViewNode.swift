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
public struct ComposeViewNode: ComposeNode {

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

  public var size: CGSize { node.size }

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

    // the view node has a flexible size, so we need to layout it with the content node's size
    _ = viewNode?.layout(containerSize: node.size, context: context)

    return sizing
  }

  public func renderableItems(in visibleBounds: CGRect) -> [ComposeUI.RenderableItem] {
    guard let viewNode else {
      ComposeUI.assertFailure("renderableItems(in:) is called before layout(containerSize:context:).")
      return []
    }
    return viewNode.renderableItems(in: visibleBounds)
  }
}
