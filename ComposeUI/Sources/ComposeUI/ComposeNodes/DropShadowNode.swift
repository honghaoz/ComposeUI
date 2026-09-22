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
/// The node has a flexible size. The path providers are given the shadow's size, and run when the renderable is
/// inserted, refreshed, or changes size, and for the sizes it passes through while its frame animates.
/// Request a refresh when other inputs of a path change.
public struct DropShadowNode: ComposeNode {

  private let color: ThemedColor
  private let opacity: Themed<CGFloat>
  private let radius: Themed<CGFloat>
  private let offset: Themed<CGSize>
  private let paths: (CGSize) -> DropShadowPaths

  /// Caches the built renderable item so scroll render passes reuse it instead of rebuilding it.
  private let itemCache = RenderableItemCache()

  /// Initialize a themed drop shadow node.
  ///
  /// - Parameters:
  ///   - color: The themed color of the drop shadow.
  ///   - opacity: The themed opacity of the drop shadow.
  ///   - radius: The themed radius of the drop shadow.
  ///   - offset: The themed offset of the drop shadow.
  ///   - path: The path of the drop shadow, for the shadow's size.
  public init(color: ThemedColor, opacity: Themed<CGFloat>, radius: Themed<CGFloat>, offset: Themed<CGSize>, path: @escaping (CGSize) -> CGPath) {
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
  ///   - paths: The paths of the drop shadow, for the shadow's size. In addition to the shadow path, you can also provide a cutout path, which will be used to clip the shadow.
  public init(color: ThemedColor, opacity: Themed<CGFloat>, radius: Themed<CGFloat>, offset: Themed<CGSize>, paths: @escaping (CGSize) -> DropShadowPaths) {
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
  ///   - path: The path of the drop shadow, for the shadow's size.
  public init(color: Color, opacity: CGFloat, radius: CGFloat, offset: CGSize, path: @escaping (CGSize) -> CGPath) {
    self.init(color: ThemedColor(color), opacity: Themed<CGFloat>(opacity), radius: Themed<CGFloat>(radius), offset: Themed<CGSize>(offset), path: path)
  }

  /// Initialize a drop shadow node.
  ///
  /// - Parameters:
  ///   - color: The color of the drop shadow.
  ///   - opacity: The opacity of the drop shadow.
  ///   - radius: The radius of the drop shadow.
  ///   - offset: The offset of the drop shadow.
  ///   - paths: The paths of the drop shadow, for the shadow's size. In addition to the shadow path, you can also provide a cutout path, which will be used to clip the shadow.
  public init(color: Color, opacity: CGFloat, radius: CGFloat, offset: CGSize, paths: @escaping (CGSize) -> DropShadowPaths) {
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

    // bind the configuration values locally so the cached `update` closure captures them instead of `self`.
    // capturing `self` (a struct, captured by value) would copy in `itemCache`, forming the retain cycle:
    // itemCache -> cachedItem -> update -> self copy -> itemCache.
    let color = color
    let opacity = opacity
    let radius = radius
    let offset = offset
    let paths = paths

    let item = itemCache.item(id: id, frame: frame) {
      LayerItem<DropShadowLayer>(
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
               .refresh:
            break
          case .boundsChange:
            // the shadow path depends on the layer's size, should update if the size is changed
            guard context.oldFrame.size != context.newFrame.size else {
              return
            }
          }

          let theme = context.contentView.theme

          // the layer calls the providers for other sizes while its frame animates, memoized per size since it asks
          // for the shadow path and the cutout path separately
          var lastPaths: (size: CGSize, paths: DropShadowPaths)?
          func shadowPaths(for size: CGSize) -> DropShadowPaths {
            if let lastPaths, lastPaths.size == size {
              return lastPaths.paths
            }
            let shadowPaths = paths(size)
            lastPaths = (size, shadowPaths)
            return shadowPaths
          }

          // whether there is a cutout is decided at the layer's own size, a provider that drops it at another size
          // falls back to the cutout at the layer's size
          let cutoutPath: ((CGSize) -> CGPath)? = shadowPaths(for: layer.bounds.size).cutoutPath.map { modelCutoutPath in
            { shadowPaths(for: $0).cutoutPath ?? modelCutoutPath }
          }

          layer.update(
            color: color.resolve(for: theme),
            opacity: opacity.resolve(for: theme),
            radius: radius.resolve(for: theme),
            offset: offset.resolve(for: theme),
            path: { shadowPaths(for: $0).shadowPath },
            cutoutPath: cutoutPath,
            animationTiming: context.animationTiming
          )
        },
        reuseId: ReuseId(namespace: .framework, id: "DropShadowLayer"),
        resetForReuse: { $0.resetForReuse() }
      )
      .eraseToRenderableItem()
    }

    return [item]
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
  ///   - path: The path of the drop shadow. The block is given the size of the shadow, the node's size.
  /// - Returns: A new node with the drop shadow underlay set.
  func dropShadow(color: ThemedColor,
                  opacity: Themed<CGFloat>,
                  radius: Themed<CGFloat>,
                  offset: Themed<CGSize>,
                  path: @escaping (CGSize) -> CGPath) -> some ComposeNode
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
  ///   - path: The path of the drop shadow. The block is given the size of the shadow, the node's size.
  /// - Returns: A new node with the drop shadow underlay set.
  func dropShadow(color: Color,
                  opacity: CGFloat,
                  radius: CGFloat,
                  offset: CGSize,
                  path: @escaping (CGSize) -> CGPath) -> some ComposeNode
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
  ///   - paths: The paths of the drop shadow. The block is given the size of the shadow, the node's size. In addition to the shadow path, you can also provide a cutout path, which will be used to clip the shadow.
  /// - Returns: A new node with the drop shadow underlay set.
  func dropShadow(color: ThemedColor,
                  opacity: Themed<CGFloat>,
                  radius: Themed<CGFloat>,
                  offset: Themed<CGSize>,
                  paths: @escaping (CGSize) -> DropShadowPaths) -> some ComposeNode
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
  ///   - paths: The paths of the drop shadow. The block is given the size of the shadow, the node's size. In addition to the shadow path, you can also provide a cutout path, which will be used to clip the shadow.
  /// - Returns: A new node with the drop shadow underlay set.
  func dropShadow(color: Color,
                  opacity: CGFloat,
                  radius: CGFloat,
                  offset: CGSize,
                  paths: @escaping (CGSize) -> DropShadowPaths) -> some ComposeNode
  {
    underlay {
      DropShadowNode(color: color, opacity: opacity, radius: radius, offset: offset, paths: paths)
    }
  }
}
