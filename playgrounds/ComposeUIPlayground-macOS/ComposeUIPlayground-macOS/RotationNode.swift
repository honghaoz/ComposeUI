//
//  RotationNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/17/24.
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

import AppKit
import ComposeUI

extension ComposeNode {

  func rotate(by degrees: CGFloat) -> some ComposeNode {
    RotationNode(node: self, degrees: degrees)
  }
}

private struct RotationNode<Node: ComposeNode>: ComposeNode {

  private var node: Node
  private let degrees: CGFloat

  fileprivate init(node: Node, degrees: CGFloat) {
    self.node = node
    self.degrees = degrees
  }

  // MARK: - ComposeNode

  var id: ComposeNodeId = ComposeNodeId.custom("rotation", isFixed: false)

  var size: CGSize { node.size }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    node.layout(containerSize: containerSize, context: context)
  }

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    let childItems = node.renderableItems(in: visibleBounds)

    var mappedChildItems: [RenderableItem] = []
    mappedChildItems.reserveCapacity(childItems.count)

    for item in childItems {
      let mappedItem = ViewItem<RotationView>(
        id: id.join(with: item.id),
        frame: item.frame,
        make: { context in
          let originalView = item.make(context)
          let rotationView = RotationView(contentView: originalView.view!) // swiftlint:disable:this force_unwrapping
          rotationView.frame = item.frame
          return rotationView
        },
        update: { view, context in
          view.degrees = degrees
          item.update(.view(view.contentView), context)
        }
      )
      mappedChildItems.append(mappedItem.eraseToRenderableItem())
    }

    return mappedChildItems
  }
}
