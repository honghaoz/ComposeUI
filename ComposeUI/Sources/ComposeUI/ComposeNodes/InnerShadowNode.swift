//
//  InnerShadowNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/5/25.
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

/// A node that renders an inner shadow.
///
/// The node has a flexible size.
public struct InnerShadowNode: ComposeNode {

  private let color: ThemedColor
  private let opacity: Themed<CGFloat>
  private let radius: Themed<CGFloat>
  private let offset: Themed<CGSize>
  private let path: (Renderable) -> CGPath

  /// Initialize a themed inner shadow node.
  ///
  /// - Parameters:
  ///   - color: The themed color of the inner shadow.
  ///   - opacity: The themed opacity of the inner shadow.
  ///   - radius: The themed radius of the inner shadow.
  ///   - offset: The themed offset of the inner shadow.
  ///   - path: The path of the inner shadow.
  public init(color: ThemedColor, opacity: Themed<CGFloat>, radius: Themed<CGFloat>, offset: Themed<CGSize>, path: @escaping (Renderable) -> CGPath) {
    self.color = color
    self.opacity = opacity
    self.radius = radius
    self.offset = offset
    self.path = path
  }

  /// Initialize an inner shadow node.
  ///
  /// - Parameters:
  ///   - color: The color of the inner shadow.
  ///   - opacity: The opacity of the inner shadow.
  ///   - radius: The radius of the inner shadow.
  ///   - offset: The offset of the inner shadow.
  ///   - path: The path of the inner shadow.
  public init(color: Color, opacity: CGFloat, radius: CGFloat, offset: CGSize, path: @escaping (Renderable) -> CGPath) {
    self.init(color: ThemedColor(color), opacity: Themed<CGFloat>(opacity), radius: Themed<CGFloat>(radius), offset: Themed<CGSize>(offset), path: path)
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.innerShadow)

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

    let layerItem = LayerItem<InnerShadowLayer>(
      id: id,
      frame: frame,
      make: { context in
        let layer = InnerShadowLayer()
        if let initialFrame = context.initialFrame {
          layer.frame = initialFrame
        }
        return layer
      },
      update: { layer, context in
        guard context.updateType.requiresFullUpdate else {
          return
        }

        let theme = context.contentView.theme

        layer.update(
          color: color.resolve(for: theme),
          opacity: opacity.resolve(for: theme),
          radius: radius.resolve(for: theme),
          offset: offset.resolve(for: theme),
          path: { path(.layer($0)) },
          animationTiming: context.animationTiming
        )
      }
    )

    return [layerItem.eraseToRenderableItem()]
  }
}

public extension ComposeNode {

  /// Add a themed inner shadow underlay to the node.
  ///   - color: The themed color of the inner shadow.
  ///   - opacity: The themed opacity of the inner shadow.
  ///   - radius: The themed radius of the inner shadow.
  ///   - offset: The themed offset of the inner shadow.
  ///   - path: The path of the inner shadow. The block provides the renderable that the shadow is applied to.
  /// - Returns: A new node with the inner shadow underlay set.
  func innerShadow(color: ThemedColor, opacity: Themed<CGFloat>, radius: Themed<CGFloat>, offset: Themed<CGSize>, path: @escaping (Renderable) -> CGPath) -> some ComposeNode {
    overlay {
      InnerShadowNode(color: color, opacity: opacity, radius: radius, offset: offset, path: path)
    }
  }

  /// Add an inner shadow underlay to the node.
  ///   - color: The color of the inner shadow.
  ///   - opacity: The opacity of the inner shadow.
  ///   - radius: The radius of the inner shadow.
  ///   - offset: The offset of the inner shadow.
  ///   - path: The path of the inner shadow. The block provides the renderable that the shadow is applied to.
  /// - Returns: A new node with the inner shadow underlay set.
  func innerShadow(color: Color, opacity: CGFloat, radius: CGFloat, offset: CGSize, path: @escaping (Renderable) -> CGPath) -> some ComposeNode {
    innerShadow(color: ThemedColor(color), opacity: Themed<CGFloat>(opacity), radius: Themed<CGFloat>(radius), offset: Themed<CGSize>(offset), path: path)
  }
}
