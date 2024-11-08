//
//  ViewNode.swift
//  ComposeUI
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
public struct ViewNode<T: View>: ComposeNode, FixedSizableComposeNode {

  private let makeView: () -> T

  private let updateView: (T) -> Void

  public var isFixedWidth: Bool

  public var isFixedHeight: Bool

  private var cachedView: T?

  /// Make a view node with an external view.
  ///
  /// The node with external view will have a fixed size (with `isFixedWidth` and `isFixedHeight` set to `true`)
  /// and the size of the node is fixed to the size of the provided view (`bounds.size`).
  /// You need to make sure the view's size is updated.
  ///
  /// If the view is constraint-based layout, don't set the node to flexible sizing by using `.flexible()` and
  /// change the node size by using `.frame(width:height:)`, this will cause "Unable to simultaneously satisfy constraints."
  /// warnings.
  ///
  /// The view's `translatesAutoresizingMaskIntoConstraints` will be set to `true` since ComposeUI uses frame-based layout.
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
  /// - Parameters:
  ///   - view: The external view.
  public init(_ view: T) {
    self.makeView = {
      view.translatesAutoresizingMaskIntoConstraints = true // use frame-based layout
      return view
    }
    self.updateView = { _ in }
    self.isFixedWidth = true
    self.isFixedHeight = true
  }

  /// Make a view node with a view factory.
  ///
  /// The node will have a flexible size (with `isFixedWidth` and `isFixedHeight` set to `false`).
  ///
  /// - Parameters:
  ///   - make: A closure to create a view.
  ///   - update: A closure to update the view.
  public init(make: @escaping () -> T,
              update: @escaping (T) -> Void = { _ in })
  {
    self.makeView = {
      let view = make()
      view.translatesAutoresizingMaskIntoConstraints = true // use frame-based layout
      return view
    }
    self.updateView = update
    self.isFixedWidth = false
    self.isFixedHeight = false
  }

  /// Make a view node with a view factory.
  ///
  /// The node will have a flexible size (with `isFixedWidth` and `isFixedHeight` set to `false`).
  ///
  /// - Parameters:
  ///   - make: A closure to create a view.
  ///   - update: A closure to update the view.
  public init(make: @autoclosure @escaping () -> T = T(),
              update: @escaping (T) -> Void = { _ in })
  {
    self.makeView = {
      let view = make()
      view.translatesAutoresizingMaskIntoConstraints = true // use frame-based layout
      return view
    }
    self.updateView = update
    self.isFixedWidth = false
    self.isFixedHeight = false
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .predefined(.view)

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize) -> ComposeNodeSizing {
    switch (isFixedWidth, isFixedHeight) {
    case (true, true):
      let view = getView()
      size = view.bounds.size
      return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height))
    case (true, false):
      let view = getView()
      size = CGSize(width: view.bounds.width, height: containerSize.height)
      return ComposeNodeSizing(width: .fixed(size.width), height: .flexible)
    case (false, true):
      let view = getView()
      size = CGSize(width: containerSize.width, height: view.bounds.height)
      return ComposeNodeSizing(width: .flexible, height: .fixed(size.height))
    case (false, false):
      size = containerSize
      return ComposeNodeSizing(width: .flexible, height: .flexible)
    }
  }

  public func viewItems(in visibleBounds: CGRect) -> [ViewItem<View>] {
    let frame = CGRect(origin: .zero, size: size)
    guard visibleBounds.intersects(frame) else {
      return []
    }

    let viewItem = ViewItem<T>(
      id: id,
      frame: frame,
      make: { cachedView ?? makeView() },
      update: { view in
        #if canImport(AppKit)
        assert(view.wantsLayer, "\(T.self) should be layer backed. Please set `wantsLayer == true`.")
        #endif
        updateView(view)
      }
    ).eraseToViewItem()

    return [viewItem]
  }

  // MARK: - Private

  private mutating func getView() -> T {
    if let cachedView = cachedView {
      return cachedView
    }

    let view = makeView()
    cachedView = view
    return view
  }
}
