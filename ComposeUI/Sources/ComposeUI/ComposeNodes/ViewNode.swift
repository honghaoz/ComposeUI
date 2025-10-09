//
//  ViewNode.swift
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

/// A node that renders a `View`.
///
/// **Sizing Behavior:**
/// - **External view**: Fixed size. By default, the node uses the view's `bounds.size` as intrinsic size.
/// - **Factory-created view**: Flexible size. By default, the node adapts to container size.
///
/// Use `fixedSize(width:height:)` to control whether the node uses the view's intrinsic size or adapts to the container size for each dimension.
public struct ViewNode<T: View>: ComposeNode, IntrinsicSizableComposeNode {

  private let make: (RenderableMakeContext) -> T
  private var intrinsicSize: ((_ view: T, _ proposedSize: CGSize) -> CGSize)?
  private let willInsert: ((T, RenderableInsertContext) -> Void)?
  private let didInsert: ((T, RenderableInsertContext) -> Void)?
  private let willUpdate: ((T, RenderableUpdateContext) -> Void)?
  private let update: (T, RenderableUpdateContext) -> Void
  private let willRemove: ((T, RenderableRemoveContext) -> Void)?
  private let didRemove: ((T, RenderableRemoveContext) -> Void)?

  /// Make a view node with an external view.
  ///
  /// The node has a fixed size (with `isFixedWidth` and `isFixedHeight` set to `true`).
  /// It uses the view's `bounds.size` as intrinsic size. You need to make sure the view's size is updated.
  ///
  /// If the view is constraint-based layout, don't set the node to flexible sizing by using `.flexible()` and
  /// change the node size by using `.frame(width:height:)`, this will cause "Unable to simultaneously satisfy constraints."
  /// warnings.
  ///
  /// The view's `translatesAutoresizingMaskIntoConstraints` will be set to `true` since ComposéUI uses frame-based layout.
  /// This may cause some issues if the view is constraint-based layout. For example, if the view have constraints define
  /// its size, the view's final size may not be the size of the constraints. To ensure the view's size is the size of
  /// the constraints, do a layout pass for the view so that the view's size is updated based on the constraints. For example:
  ///
  /// ```swift
  /// view.translatesAutoresizingMaskIntoConstraints = false
  /// view.setNeedsLayout()
  /// view.layoutIfNeeded() // this will update the view's size based on the constraints
  /// ```
  ///
  /// Or use `systemLayoutSizeFitting(_:)` to get the size of the view and set its `bounds.size`.
  ///
  /// You can also use `intrinsicSize` to provide a custom intrinsic size based on the proposed container size. Usually, you should use view's `sizeThatFits(_:)` to get the intrinsic size.
  ///
  /// - Parameters:
  ///   - view: The external view.
  ///   - intrinsicSize: A closure to provide custom intrinsic size based on the proposed container size. If nil (default), the view's `bounds.size` will be used.
  ///   - willInsert: A closure to be called when the view is about to be inserted into the renderable hierarchy.
  ///   - didInsert: A closure to be called when the view is inserted into the renderable hierarchy.
  ///   - willUpdate: A closure to be called when the view is about to be updated.
  ///   - update: A closure to update the view.
  ///   - willRemove: A closure to be called when the view is about to be removed from the renderable hierarchy.
  ///   - didRemove: A closure to be called when the view is removed from the renderable hierarchy.
  public init(_ view: T,
              intrinsicSize: ((_ view: T, _ proposedSize: CGSize) -> CGSize)? = nil,
              willInsert: ((_ view: T, _ context: RenderableInsertContext) -> Void)? = nil,
              didInsert: ((_ view: T, _ context: RenderableInsertContext) -> Void)? = nil,
              willUpdate: ((_ view: T, _ context: RenderableUpdateContext) -> Void)? = nil,
              update: @escaping (_ view: T, _ context: RenderableUpdateContext) -> Void = { _, _ in },
              willRemove: ((_ view: T, _ context: RenderableRemoveContext) -> Void)? = nil,
              didRemove: ((_ view: T, _ context: RenderableRemoveContext) -> Void)? = nil)
  {
    self.make = { _ in
      view.translatesAutoresizingMaskIntoConstraints = true // use frame-based layout
      return view
    }
    self.intrinsicSize = intrinsicSize
    self.willInsert = willInsert
    self.didInsert = didInsert
    self.willUpdate = willUpdate
    self.update = update
    self.willRemove = willRemove
    self.didRemove = didRemove
    self.isFixedWidth = true
    self.isFixedHeight = true

    // use a unique id for the view node with an external view so that the view won't be reused incorrectly on refresh
    id = .custom("view-\(ObjectIdentifier(view))", isFixed: false)
  }

  /// Make a view node with a view factory.
  ///
  /// The node has a flexible size (with `isFixedWidth` and `isFixedHeight` set to `false`).
  ///
  /// - Parameters:
  ///   - make: A closure to create a view. To avoid incorrect transition animation, the view should be created with with frame set to `context.initialFrame` if it's provided.
  ///   - intrinsicSize: A closure to provide custom intrinsic size based on the proposed container size. If nil (default), the view's `bounds.size` will be used.
  ///   - willInsert: A closure to be called when the view is about to be inserted into the renderable hierarchy.
  ///   - didInsert: A closure to be called when the view is inserted into the renderable hierarchy.
  ///   - willUpdate: A closure to be called when the view is about to be updated.
  ///   - update: A closure to update the view.
  ///   - willRemove: A closure to be called when the view is about to be removed from the renderable hierarchy.
  ///   - didRemove: A closure to be called when the view is removed from the renderable hierarchy.
  public init(make: ((_ context: RenderableMakeContext) -> T)? = nil,
              intrinsicSize: ((_ view: T, _ proposedSize: CGSize) -> CGSize)? = nil,
              willInsert: ((_ view: T, _ context: RenderableInsertContext) -> Void)? = nil,
              didInsert: ((_ view: T, _ context: RenderableInsertContext) -> Void)? = nil,
              willUpdate: ((_ view: T, _ context: RenderableUpdateContext) -> Void)? = nil,
              update: @escaping (_ view: T, _ context: RenderableUpdateContext) -> Void = { _, _ in },
              willRemove: ((_ view: T, _ context: RenderableRemoveContext) -> Void)? = nil,
              didRemove: ((_ view: T, _ context: RenderableRemoveContext) -> Void)? = nil)
  {
    self.make = make ?? { context in
      let view: T
      if let initialFrame = context.initialFrame {
        view = T(frame: initialFrame)
      } else {
        view = T()
      }
      #if canImport(AppKit)
      if T.self == View.self {
        view.wantsLayer = true
      }
      #endif
      view.translatesAutoresizingMaskIntoConstraints = true // use frame-based layout
      return view
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
    let view = getView()

    if let intrinsicSizeProvider = intrinsicSize {
      return intrinsicSizeProvider(view, size)
    }

    return view.bounds.size
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.view)

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

    let viewItem = ViewItem<T>(
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

    return [viewItem.eraseToRenderableItem()]
  }

  // MARK: - Private

  private var cachedView: T?

  private mutating func getView() -> T {
    if let cachedView = cachedView {
      return cachedView
    }

    let view = make(RenderableMakeContext(initialFrame: nil, contentView: nil))
    cachedView = view
    return view
  }
}

// MARK: - View + ComposeContent

extension View: ComposeContent {

  /// Wraps the view into a `ViewNode`.
  public func asNodes() -> [ComposeNode] {
    [ViewNode(self)]
  }
}
