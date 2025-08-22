//
//  DropShadowNode.swift
//  ComposéUI
//
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

/// A model contains the shadow path and cutout path for a drop shadow.
public struct DropShadowPaths {

  /// The shadow path.
  public let shadowPath: CGPath

  /// The cutout path. If provided, the shadow will be clipped for the cutout path.
  public let cutoutPath: CGPath?

  /// Initialize a shadow paths model.
  ///
  /// - Parameters:
  ///   - shadowPath: The shadow path.
  ///   - cutoutPath: The cutout path.
  public init(shadowPath: CGPath, cutoutPath: CGPath?) {
    self.shadowPath = shadowPath
    self.cutoutPath = cutoutPath
  }
}

/// A node that renders a drop shadow.
///
/// The node has a flexible size.
public struct DropShadowNode: ComposeNode {

  private let color: ThemedColor
  private let opacity: Themed<CGFloat>
  private let radius: Themed<CGFloat>
  private let offset: Themed<CGSize>
  private let paths: (Renderable) -> DropShadowPaths

  /// Initialize a themed drop shadow node.
  ///
  /// - Parameters:
  ///   - color: The themed color of the drop shadow.
  ///   - opacity: The themed opacity of the drop shadow.
  ///   - radius: The themed radius of the drop shadow.
  ///   - offset: The themed offset of the drop shadow.
  ///   - path: The path of the drop shadow.
  public init(color: ThemedColor, opacity: Themed<CGFloat>, radius: Themed<CGFloat>, offset: Themed<CGSize>, path: @escaping (Renderable) -> CGPath) {
    self.color = color
    self.opacity = opacity
    self.radius = radius
    self.offset = offset
    self.paths = { DropShadowPaths(shadowPath: path($0), cutoutPath: nil) }
  }

  /// Initialize a themed drop shadow node.
  ///
  /// - Parameters:
  ///   - color: The themed color of the drop shadow.
  ///   - opacity: The themed opacity of the drop shadow.
  ///   - radius: The themed radius of the drop shadow.
  ///   - offset: The themed offset of the drop shadow.
  ///   - paths: The paths of the drop shadow. In addition to the shadow path, you can also provide a cutout path, which will be used to clip the shadow.
  public init(color: ThemedColor, opacity: Themed<CGFloat>, radius: Themed<CGFloat>, offset: Themed<CGSize>, paths: @escaping (Renderable) -> DropShadowPaths) {
    self.color = color
    self.opacity = opacity
    self.radius = radius
    self.offset = offset
    self.paths = paths
  }

  /// Initialize a drop shadow node.
  ///
  /// - Parameters:
  ///   - color: The color of the drop shadow.
  ///   - opacity: The opacity of the drop shadow.
  ///   - radius: The radius of the drop shadow.
  ///   - offset: The offset of the drop shadow.
  public init(color: Color, opacity: CGFloat, radius: CGFloat, offset: CGSize, path: @escaping (Renderable) -> CGPath) {
    self.init(color: ThemedColor(color), opacity: Themed<CGFloat>(opacity), radius: Themed<CGFloat>(radius), offset: Themed<CGSize>(offset), path: path)
  }

  /// Initialize a drop shadow node.
  ///
  /// - Parameters:
  ///   - color: The color of the drop shadow.
  ///   - opacity: The opacity of the drop shadow.
  ///   - radius: The radius of the drop shadow.
  ///   - offset: The offset of the drop shadow.
  ///   - paths: The paths of the drop shadow. In addition to the shadow path, you can also provide a cutout path, which will be used to clip the shadow.
  public init(color: Color, opacity: CGFloat, radius: CGFloat, offset: CGSize, paths: @escaping (Renderable) -> DropShadowPaths) {
    self.init(color: ThemedColor(color), opacity: Themed<CGFloat>(opacity), radius: Themed<CGFloat>(radius), offset: Themed<CGSize>(offset), paths: paths)
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.dropShadow)

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

    let layerItem = LayerItem<DropShadowLayer>(
      id: id,
      frame: frame,
      make: { context in
        let layer = DropShadowLayer()
        if let initialFrame = context.initialFrame {
          layer.frame = initialFrame
        }
        return layer
      },
      update: { layer, context in
        switch context.updateType {
        case .insert,
             .refresh,
             .boundsChange: // the shadow path is affected by the layer's size, should update
          break
        case .scroll:
          return
        }

        let theme = context.contentView.theme
        let paths = paths(.layer(layer))

        layer.update(
          color: color.resolve(for: theme),
          opacity: opacity.resolve(for: theme),
          radius: radius.resolve(for: theme),
          offset: offset.resolve(for: theme),
          path: { _ in paths.shadowPath },
          cutoutPath: paths.cutoutPath.map { cutoutPath in { _ in cutoutPath } },
          animationTiming: context.animationTiming
        )
      }
    )

    return [layerItem.eraseToRenderableItem()]
  }
}

public extension ComposeNode {

  /// Add a themed drop shadow underlay to the node.
  ///
  /// - Note: This is different than `shadow(color:opacity:radius:offset:path:)` which sets the shadow to all of the node's renderables.
  /// This method adds a drop shadow underlay to the node. The shadow is applied to a dedicated shadow layer.
  ///
  /// - Parameters:
  ///   - color: The themed color of the drop shadow.
  ///   - opacity: The themed opacity of the drop shadow.
  ///   - radius: The themed radius of the drop shadow.
  ///   - offset: The themed offset of the drop shadow.
  ///   - path: The path of the drop shadow. The block provides the renderable that the shadow is applied to.
  /// - Returns: A new node with the drop shadow underlay set.
  func dropShadow(color: ThemedColor,
                  opacity: Themed<CGFloat>,
                  radius: Themed<CGFloat>,
                  offset: Themed<CGSize>,
                  path: @escaping (Renderable) -> CGPath) -> some ComposeNode
  {
    underlay {
      DropShadowNode(color: color, opacity: opacity, radius: radius, offset: offset, path: path)
    }
  }

  /// Add a drop shadow underlay to the node.
  ///
  /// - Note: This is different than `shadow(color:opacity:radius:offset:path:)` which sets the shadow to all of the node's renderables.
  /// This method adds a drop shadow underlay to the node. The shadow is applied to a dedicated shadow layer.
  ///
  /// - Parameters:
  ///   - color: The color of the drop shadow.
  ///   - opacity: The opacity of the drop shadow.
  ///   - radius: The radius of the drop shadow.
  ///   - offset: The offset of the drop shadow.
  ///   - path: The path of the drop shadow. The block provides the renderable that the shadow is applied to.
  /// - Returns: A new node with the drop shadow underlay set.
  func dropShadow(color: Color,
                  opacity: CGFloat,
                  radius: CGFloat,
                  offset: CGSize,
                  path: @escaping (Renderable) -> CGPath) -> some ComposeNode
  {
    underlay {
      DropShadowNode(color: color, opacity: opacity, radius: radius, offset: offset, path: path)
    }
  }

  /// Add a themed drop shadow underlay to the node.
  ///
  /// - Note: This is different than `shadow(color:opacity:radius:offset:path:)` which sets the shadow to all of the node's renderables.
  /// This method adds a drop shadow underlay to the node. The shadow is applied to a dedicated shadow layer.
  ///
  /// - Parameters:
  ///   - color: The themed color of the drop shadow.
  ///   - opacity: The themed opacity of the drop shadow.
  ///   - radius: The themed radius of the drop shadow.
  ///   - offset: The themed offset of the drop shadow.
  ///   - paths: The paths of the drop shadow. In addition to the shadow path, you can also provide a cutout path, which will be used to clip the shadow.
  /// - Returns: A new node with the drop shadow underlay set.
  func dropShadow(color: ThemedColor,
                  opacity: Themed<CGFloat>,
                  radius: Themed<CGFloat>,
                  offset: Themed<CGSize>,
                  paths: @escaping (Renderable) -> DropShadowPaths) -> some ComposeNode
  {
    underlay {
      DropShadowNode(color: color, opacity: opacity, radius: radius, offset: offset, paths: paths)
    }
  }

  /// Add a drop shadow underlay to the node.
  ///
  /// - Note: This is different than `shadow(color:opacity:radius:offset:path:)` which sets the shadow to all of the node's renderables.
  /// This method adds a drop shadow underlay to the node. The shadow is applied to a dedicated shadow layer.
  ///
  /// - Parameters:
  ///   - color: The color of the drop shadow.
  ///   - opacity: The opacity of the drop shadow.
  ///   - radius: The radius of the drop shadow.
  ///   - offset: The offset of the drop shadow.
  ///   - paths: The paths of the drop shadow. In addition to the shadow path, you can also provide a cutout path, which will be used to clip the shadow.
  /// - Returns: A new node with the drop shadow underlay set.
  func dropShadow(color: Color,
                  opacity: CGFloat,
                  radius: CGFloat,
                  offset: CGSize,
                  paths: @escaping (Renderable) -> DropShadowPaths) -> some ComposeNode
  {
    underlay {
      DropShadowNode(color: color, opacity: opacity, radius: radius, offset: offset, paths: paths)
    }
  }
}
