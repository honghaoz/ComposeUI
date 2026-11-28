//
//  PinstripesNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/27/26.
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

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

import ComposeUI

/// A node that fills its frame with pinstripes.
///
/// The node has a flexible size.
struct PinstripesNode: ComposeNode {

  /// The direction that stripes run in.
  typealias Axis = PinstripesLayer.Axis

  /// The layer node that shows the stripes.
  private var node: LayerNode<PinstripesLayer>

  /// Creates a pinstripes node.
  ///
  /// - Parameters:
  ///   - axis: The direction that the stripes run in.
  ///   - thickness: The thickness of a stripe, across its direction. Must be greater than 0.
  ///   - spacing: The space between two stripes. Must not be negative.
  ///   - offset: The distance from the node's top, or its left for vertical stripes, to the start of a stripe, which
  ///     lines the stripes up with other content.
  ///   - color: The color of the stripes.
  ///   - backgroundColor: The color between the stripes.
  init(axis: Axis = .horizontal,
       thickness: CGFloat = 4,
       spacing: CGFloat = 4,
       offset: CGFloat = 0,
       color: ThemedColor = ThemedColor(light: Color(white: 0.9725, alpha: 1), dark: Color(white: 0.15, alpha: 1)),
       backgroundColor: ThemedColor = ThemedColor(light: .clear, dark: .clear))
  {
    node = LayerNode(update: { layer, context in
      let theme = context.contentView.theme
      // the layer lays its stripes out again only for a change, so a refresh that sets the same values costs nothing
      layer.axis = axis
      layer.stripeThickness = thickness
      layer.stripeSpacing = spacing
      layer.stripeOffset = offset
      layer.stripeColor = color.resolve(for: theme).cgColor
      layer.disableActions(for: "backgroundColor") {
        layer.backgroundColor = backgroundColor.resolve(for: theme).cgColor
      }
    })
    node.id = .custom("pinstripes", isFixed: false)
  }

  // MARK: - ComposeNode

  var id: ComposeNodeId {
    get { node.id }
    set { node.id = newValue }
  }

  var size: CGSize { node.size }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    node.layout(containerSize: containerSize, context: context)
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
    node.render(visibleBounds: visibleBounds, into: &items)
  }
}
