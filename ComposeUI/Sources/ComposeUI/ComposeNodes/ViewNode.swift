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
///
/// A view that always keeps its own size, such as `UISwitch`, needs a node that's fixed in the size, such as
/// `ViewNode<UISwitch>().fixedSize()`.
public struct ViewNode<T: View>: ComposeNode, IntrinsicSizableComposeNode {

  private let make: ((RenderableMakeContext) -> T)?
  private let intrinsicSizeProvider: ((_ proposedSize: CGSize) -> CGSize)?
  private let willInsert: ((T, RenderableInsertContext) -> Void)?
  private let didInsert: ((T, RenderableInsertContext) -> Void)?
  private let willUpdate: ((T, RenderableUpdateContext) -> Void)?
  private let update: (T, RenderableUpdateContext) -> Void
  private let willRemove: ((T, RenderableRemoveContext) -> Void)?
  private let didRemove: ((T, RenderableRemoveContext) -> Void)?

  /// The node's slot in the item cache of its content, so scroll render passes reuse its item instead of rebuilding it.
  private var itemSlot = RenderableItemCache.Slot.unassigned

  #if DEBUG && !COMPOSEUI_BENCHMARK
  /// The proposed size that the layout measured a plain view with, or `nil` when it measured none.
  private var plainViewProposedSize: CGSize?
  #endif

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
  /// You can also provide `intrinsicSize` to return a custom size based on the proposed container size.
  /// This closure is evaluated during layout and must be synchronous. If you need to measure the
  /// view (for example, `sizeThatFits(_:)`), capture the external view and compute it there.
  ///
  /// - Parameters:
  ///   - view: The external view.
  ///   - intrinsicSize: A closure that returns the intrinsic size from the proposed container size. If nil (default), the view's `bounds.size` is used.
  ///   - willInsert: A closure to be called when the view is about to be inserted into the renderable hierarchy.
  ///   - didInsert: A closure to be called when the view is inserted into the renderable hierarchy.
  ///   - willUpdate: A closure to be called when the view is about to be updated.
  ///   - update: A closure to update the view, which must keep the view's frame that the render pass sets.
  ///   - willRemove: A closure to be called when the view is about to be removed from the renderable hierarchy.
  ///   - didRemove: A closure to be called when the view is removed from the renderable hierarchy.
  public init(_ view: T,
              intrinsicSize: ((_ proposedSize: CGSize) -> CGSize)? = nil,
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
    // `if let` instead of `??`, whose generic operands take a closure through allocated reabstraction thunks
    if let intrinsicSize {
      self.intrinsicSizeProvider = intrinsicSize
    } else {
      self.intrinsicSizeProvider = { _ in view.bounds.size }
    }
    self.willInsert = willInsert
    self.didInsert = didInsert
    self.willUpdate = willUpdate
    self.update = update
    self.willRemove = willRemove
    self.didRemove = didRemove
    self.isFixedWidth = true
    self.isFixedHeight = true

    // use a unique id for the view node with an external view so that the view won't be reused incorrectly on refresh
    id = .object(view, kind: .view)
  }

  /// Make a view node with a view factory.
  ///
  /// The node has a flexible size (with `isFixedWidth` and `isFixedHeight` set to `false`).
  ///
  /// - Note: A view that always keeps its own size, such as `UISwitch`, requires a fixed size, such as
  ///   `ViewNode<UISwitch>().fixedSize()`.
  ///
  /// - Parameters:
  ///   - make: A closure to create a view. To avoid incorrect transition animation, the view should be created with
  ///     frame set to `context.initialFrame` if it's provided. The default value is `nil`, which makes a plain `T` with
  ///     its frame set to `context.initialFrame`.
  ///   - intrinsicSize: A closure that returns the view's size for a proposed size, for fixed sizing (see
  ///     `fixedSize(width:height:)`). Provide it when `make` is custom or `update` changes the view's size. Otherwise,
  ///     `nil` measures a plain `T`, which may produce wrong sizes.
  ///   - willInsert: A closure to be called when the view is about to be inserted into the renderable hierarchy.
  ///   - didInsert: A closure to be called when the view is inserted into the renderable hierarchy.
  ///   - willUpdate: A closure to be called when the view is about to be updated.
  ///   - update: A closure to update the view, which must keep the view's frame that the render pass sets.
  ///   - willRemove: A closure to be called when the view is about to be removed from the renderable hierarchy.
  ///   - didRemove: A closure to be called when the view is removed from the renderable hierarchy.
  public init(make: ((_ context: RenderableMakeContext) -> T)? = nil,
              intrinsicSize: ((_ proposedSize: CGSize) -> CGSize)? = nil,
              willInsert: ((_ view: T, _ context: RenderableInsertContext) -> Void)? = nil,
              didInsert: ((_ view: T, _ context: RenderableInsertContext) -> Void)? = nil,
              willUpdate: ((_ view: T, _ context: RenderableUpdateContext) -> Void)? = nil,
              update: @escaping (_ view: T, _ context: RenderableUpdateContext) -> Void = { _, _ in },
              willRemove: ((_ view: T, _ context: RenderableRemoveContext) -> Void)? = nil,
              didRemove: ((_ view: T, _ context: RenderableRemoveContext) -> Void)? = nil)
  {
    self.make = make
    self.intrinsicSizeProvider = intrinsicSize
    self.willInsert = willInsert
    self.didInsert = didInsert
    self.willUpdate = willUpdate
    self.update = update
    self.willRemove = willRemove
    self.didRemove = didRemove
    self.isFixedWidth = false
    self.isFixedHeight = false
    // set here instead of as the default value of `id`, which the initializer that takes a view would assign again,
    // making the compiler copy the node when the initializer returns
    id = .standard(.view)
  }

  // MARK: - IntrinsicSizableComposeNode

  public var isFixedWidth: Bool
  public var isFixedHeight: Bool

  private func intrinsicSize(for proposedSize: CGSize) -> CGSize {
    if let intrinsicSizeProvider {
      return intrinsicSizeProvider(proposedSize)
    } else if let make {
      ComposeUI.assertFailure("ViewNode<\(T.self)> with a custom make needs an intrinsicSize closure for fixed sizing")
      return make(RenderableMakeContext(initialFrame: .zero)).intrinsicSize(for: proposedSize)
    } else {
      return MeasuringViews.view(of: T.self).intrinsicSize(for: proposedSize)
    }
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    RenderableItemCache.updateSlot(&itemSlot)

    #if DEBUG && !COMPOSEUI_BENCHMARK
    let measuresPlainView = make == nil && intrinsicSizeProvider == nil && (isFixedWidth || isFixedHeight)
    plainViewProposedSize = measuresPlainView ? containerSize : nil
    #endif

    // the intrinsic size comes from the app, which can read both lengths of the proposed size, so every mode reads both
    switch (isFixedWidth, isFixedHeight) {
    case (true, true):
      size = self.intrinsicSize(for: containerSize)
      return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height), dependence: [.width, .height])
    case (true, false):
      let intrinsicSize = self.intrinsicSize(for: containerSize)
      size = CGSize(width: intrinsicSize.width, height: containerSize.height)
      return ComposeNodeSizing(width: .fixed(size.width), height: .flexible, dependence: [.width, .height])
    case (false, true):
      let intrinsicSize = self.intrinsicSize(for: containerSize)
      size = CGSize(width: containerSize.width, height: intrinsicSize.height)
      return ComposeNodeSizing(width: .flexible, height: .fixed(size.height), dependence: [.width, .height])
    case (false, false):
      size = containerSize
      return ComposeNodeSizing(width: .flexible, height: .flexible, dependence: [.width, .height])
    }
  }

  public func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {
    let frame = CGRect(origin: .zero, size: size)
    guard visibleBounds.intersects(frame) else {
      return
    }

    let item = RenderableItemCache.item(in: itemSlot, id: id, frame: frame) {
      let update: (T, RenderableUpdateContext) -> Void
      #if DEBUG && !COMPOSEUI_BENCHMARK
      if let plainViewProposedSize {
        update = sizeCheckedUpdate(proposedSize: plainViewProposedSize)
      } else {
        update = self.update
      }
      #else
      update = self.update
      #endif

      return ViewItem<T>(
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
      .eraseToRenderableItem()
    }

    items.append(item)
  }

  #if DEBUG && !COMPOSEUI_BENCHMARK
  /// Returns the update, followed by a check that the view has the node's size, which a plain view measured.
  ///
  /// - Parameter proposedSize: The proposed size that the plain view was measured with.
  /// - Returns: The update that checks the size.
  private func sizeCheckedUpdate(proposedSize: CGSize) -> (T, RenderableUpdateContext) -> Void {
    let update = update
    let size = size
    let isFixedWidth = isFixedWidth
    let isFixedHeight = isFixedHeight
    return { view, context in
      update(view, context)
      // checked after `willInsert`, `willUpdate` and `update`, any of which can change the size. a plain view outside a
      // window can round its size to other pixels, so less than a point of difference passes
      let ownSize = view.intrinsicSize(for: proposedSize)
      ComposeUI.assert(
        (!isFixedWidth || abs(ownSize.width - size.width) < 1) && (!isFixedHeight || abs(ownSize.height - size.height) < 1),
        "ViewNode<\(T.self)>'s view is \(ownSize), not the node's size \(size): provide intrinsicSize"
      )
    }
  }
  #endif
}

// MARK: - MeasuringViews

/// The plain views that fixed-size `ViewNode`s with the default `make` measure, one per view type.
private enum MeasuringViews {

  /// The views by type, used on the main thread only.
  private static var views: [ObjectIdentifier: View] = [:]

  /// Returns the plain view of the type, making it on the first call.
  ///
  /// - Parameter type: The view type.
  /// - Returns: The plain view of the type.
  static func view(of type: View.Type) -> View {
    let key = ObjectIdentifier(type)
    if let view = views[key] {
      return view
    } else {
      let view = DefaultView.make(type, RenderableMakeContext(initialFrame: .zero))
      views[key] = view
      return view
    }
  }
}

// MARK: - View + ComposeContent

extension View: ComposeContent {

  /// Wraps the view into a `ViewNode`.
  public func _nodes() -> [ComposeNode] {
    [ViewNode(self)]
  }
}
