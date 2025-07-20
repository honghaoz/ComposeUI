//
//  LayerNode.swift
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

import QuartzCore

/// A node that renders a `CALayer`.
///
/// **Sizing Behavior:**
/// - **External layer**: Fixed size. By default, the node uses the layer's `bounds.size` as intrinsic size.
/// - **Factory-created layer**: Flexible size. By default, the node adapts to container size.
///
/// Use `fixedSize(width:height:)` to control whether the node uses the layer's intrinsic size or adapts to the container size for each dimension.
public struct LayerNode<T: CALayer>: ComposeNode, IntrinsicSizableComposeNode {

  private let make: (RenderableMakeContext) -> T
  private var intrinsicSize: ((_ layer: T, _ proposedSize: CGSize) -> CGSize)?
  private let willInsert: ((T, RenderableInsertContext) -> Void)?
  private let didInsert: ((T, RenderableInsertContext) -> Void)?
  private let willUpdate: ((T, RenderableUpdateContext) -> Void)?
  private let update: (T, RenderableUpdateContext) -> Void
  private let willRemove: ((T, RenderableRemoveContext) -> Void)?
  private let didRemove: ((T, RenderableRemoveContext) -> Void)?

  /// Make a layer node with an external layer.
  ///
  /// The node has a fixed size (with `isFixedWidth` and `isFixedHeight` set to `true`).
  /// It uses the layer's `bounds.size` as intrinsic size. You need to make sure the layer's size is updated.
  ///
  /// You can also use `intrinsicSize` to provide a custom intrinsic size based on the proposed container size.
  ///
  /// - Parameters:
  ///   - layer: The external layer.
  ///   - intrinsicSize: A closure to provide custom intrinsic size based on the proposed container size.
  ///   - willInsert: A closure to be called when the layer is about to be inserted into the renderable hierarchy.
  ///   - didInsert: A closure to be called when the layer is inserted into the renderable hierarchy.
  ///   - willUpdate: A closure to be called when the layer is about to be updated.
  ///   - update: A closure to update the layer.
  ///   - willRemove: A closure to be called when the layer is about to be removed from the renderable hierarchy.
  ///   - didRemove: A closure to be called when the layer is removed from the renderable hierarchy.
  public init(_ layer: T,
              intrinsicSize: ((_ layer: T, _ proposedSize: CGSize) -> CGSize)? = nil,
              willInsert: ((_ layer: T, _ context: RenderableInsertContext) -> Void)? = nil,
              didInsert: ((_ layer: T, _ context: RenderableInsertContext) -> Void)? = nil,
              willUpdate: ((_ layer: T, _ context: RenderableUpdateContext) -> Void)? = nil,
              update: @escaping (_ layer: T, _ context: RenderableUpdateContext) -> Void = { _, _ in },
              willRemove: ((_ layer: T, _ context: RenderableRemoveContext) -> Void)? = nil,
              didRemove: ((_ layer: T, _ context: RenderableRemoveContext) -> Void)? = nil)
  {
    self.make = { _ in layer }
    self.intrinsicSize = intrinsicSize
    self.willInsert = willInsert
    self.didInsert = didInsert
    self.willUpdate = willUpdate
    self.update = update
    self.willRemove = willRemove
    self.didRemove = didRemove
    self.isFixedWidth = true
    self.isFixedHeight = true

    // use a unique id for the layer node with an external layer so that the layer won't be reused incorrectly on refresh
    id = .custom("layer-\(ObjectIdentifier(layer))", isFixed: false)
  }

  /// Make a layer node with a layer factory.
  ///
  /// The node has a flexible size (with `isFixedWidth` and `isFixedHeight` set to `false`).
  ///
  /// - Parameters:
  ///   - make: A closure to create a layer. To avoid incorrect transition animation, the layer should be created with frame set to `context.initialFrame` if it's provided.
  ///   - intrinsicSize: A closure to provide custom intrinsic size based on the proposed container size.
  ///   - willInsert: A closure to be called when the layer is about to be inserted into the renderable hierarchy.
  ///   - didInsert: A closure to be called when the layer is inserted into the renderable hierarchy.
  ///   - willUpdate: A closure to be called when the layer is about to be updated.
  ///   - update: A closure to update the layer.
  ///   - willRemove: A closure to be called when the layer is about to be removed from the renderable hierarchy.
  ///   - didRemove: A closure to be called when the layer is removed from the renderable hierarchy.
  public init(make: ((_ context: RenderableMakeContext) -> T)? = nil,
              intrinsicSize: ((_ layer: T, _ proposedSize: CGSize) -> CGSize)? = nil,
              willInsert: ((_ layer: T, _ context: RenderableInsertContext) -> Void)? = nil,
              didInsert: ((_ layer: T, _ context: RenderableInsertContext) -> Void)? = nil,
              willUpdate: ((_ layer: T, _ context: RenderableUpdateContext) -> Void)? = nil,
              update: @escaping (_ layer: T, _ context: RenderableUpdateContext) -> Void = { _, _ in },
              willRemove: ((_ layer: T, _ context: RenderableRemoveContext) -> Void)? = nil,
              didRemove: ((_ layer: T, _ context: RenderableRemoveContext) -> Void)? = nil)
  {
    self.make = make ?? { context in
      let layer = T()
      if let initialFrame = context.initialFrame {
        layer.frame = initialFrame
      }
      return layer
    }
    self.intrinsicSize = intrinsicSize
    self.willInsert = willInsert
    self.didInsert = didInsert
    self.willUpdate = willUpdate
    self.update = update
    self.willRemove = willRemove
    self.didRemove = didRemove
    self.isFixedWidth = false
    self.isFixedHeight = false
  }

  // MARK: - IntrinsicSizableComposeNode

  public var isFixedWidth: Bool
  public var isFixedHeight: Bool

  private mutating func intrinsicSize(for size: CGSize) -> CGSize {
    let layer = getLayer()

    if let intrinsicSizeProvider = intrinsicSize {
      return intrinsicSizeProvider(layer, size)
    }

    return layer.bounds.size
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.layer)

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    switch (isFixedWidth, isFixedHeight) {
    case (true, true):
      size = self.intrinsicSize(for: containerSize)
      return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height))
    case (true, false):
      let intrinsicSize = self.intrinsicSize(for: containerSize)
      size = CGSize(width: intrinsicSize.width, height: containerSize.height)
      return ComposeNodeSizing(width: .fixed(size.width), height: .flexible)
    case (false, true):
      let intrinsicSize = self.intrinsicSize(for: containerSize)
      size = CGSize(width: containerSize.width, height: intrinsicSize.height)
      return ComposeNodeSizing(width: .flexible, height: .fixed(size.height))
    case (false, false):
      size = containerSize
      return ComposeNodeSizing(width: .flexible, height: .flexible)
    }
  }

  public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    let frame = CGRect(origin: .zero, size: size)
    guard visibleBounds.intersects(frame) else {
      return []
    }

    let layerItem = LayerItem<T>(
      id: id,
      frame: frame,
      make: make,
      willInsert: willInsert,
      didInsert: didInsert,
      willUpdate: willUpdate,
      update: update,
      willRemove: willRemove,
      didRemove: didRemove
    )

    return [layerItem.eraseToRenderableItem()]
  }

  // MARK: - Private

  private var cachedLayer: T?

  private mutating func getLayer() -> T {
    if let cachedLayer = cachedLayer {
      return cachedLayer
    }

    let layer = make(RenderableMakeContext(initialFrame: nil, contentView: nil))
    cachedLayer = layer
    return layer
  }
}

// MARK: - CALayer + ComposeContent

extension CALayer: ComposeContent {

  public func asNodes() -> [ComposeNode] {
    [LayerNode(self)]
  }
}
