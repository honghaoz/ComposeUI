//
//  ColorNode.swift
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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// A node that renders a solid color.
///
/// The node has a flexible size.
public struct ColorNode: ComposeNode {

  private let color: ThemedColor

  /// Initialize a color node with a color.
  ///
  /// - Parameter color: The color to render.
  public init(_ color: Color) {
    self.color = ThemedColor(light: color, dark: color)
  }

  /// Initialize a color node with a themed color.
  ///
  /// - Parameter color: The themed color to render.
  public init(_ color: ThemedColor) {
    self.color = color
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.color)

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    size = containerSize
    return ComposeNodeSizing(width: .flexible, height: .flexible)
  }

  public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    let frame = CGRect(origin: .zero, size: size)
    guard visibleBounds.intersects(frame) else {
      return []
    }

    let layerItem = LayerItem<CALayer>(
      id: id,
      frame: frame,
      make: { context in
        let layer = CALayer()
        if let initialFrame = context.initialFrame {
          layer.frame = initialFrame
        }
        return layer
      },
      update: { layer, context in
        let color = self.color.resolve(for: context.contentView.theme).cgColor
        if let animationTiming = context.animationTiming {
          layer.animate(
            keyPath: "backgroundColor",
            timing: animationTiming,
            from: { $0.presentation()?.backgroundColor },
            to: { _ in color }
          )
        } else {
          layer.disableActions(for: "backgroundColor") {
            layer.backgroundColor = color
          }
        }
      }
    )

    return [layerItem.eraseToRenderableItem()]
  }
}
