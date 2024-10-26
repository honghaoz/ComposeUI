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

import UIKit

public typealias View = ViewNode

/// A node that renders a `UIView`.
public struct ViewNode<T: UIView>: ComposeNode {

  private let makeView: () -> T

  private let updateView: (T) -> Void

  /// Whether the width is fixed. If `true`, the width of the view node follows the view's intrinsic width.
  private var isFixedWidth: Bool

  /// Whether the height is fixed. If `true`, the height of the view node follows the view's intrinsic height.
  private var isFixedHeight: Bool

  private var cachedView: T?

  /// Make a view node with an external view.
  ///
  /// By default, the width and height of the view node are fixed to the size of the provided view.
  ///
  /// - Parameters:
  ///   - view: The external view.
  public init(_ view: T) {
    self.makeView = { view }
    self.updateView = { _ in }
    self.isFixedWidth = true
    self.isFixedHeight = true
    self.cachedView = view
  }

  /// Make a view node with a view factory.
  ///
  /// By default, the width and height of the view node are flexible.
  ///
  /// - Parameters:
  ///   - make: A closure to create a view.
  ///   - update: A closure to update the view.
  public init(make: @escaping () -> T,
              update: @escaping (T) -> Void = { _ in })
  {
    self.makeView = make
    self.updateView = update
    self.isFixedWidth = false
    self.isFixedHeight = false
  }

  /// Make a view node with a view factory.
  ///
  /// By default, the width and height of the view node are flexible.
  ///
  /// - Parameters:
  ///   - make: A closure to create a view.
  ///   - update: A closure to update the view.
  public init(make: @autoclosure @escaping () -> T = T(),
              update: @escaping (T) -> Void = { _ in })
  {
    self.makeView = { make() }
    self.updateView = update
    self.isFixedWidth = false
    self.isFixedHeight = false
  }

  // MARK: - ComposeNode

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

  public func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>] {
    let frame = CGRect(origin: .zero, size: size)
    guard visibleBounds.actuallyIntersects(frame) else {
      return []
    }

    let viewItem = ViewItem<T>(
      id: ComposeNodeId.view.rawValue,
      frame: frame,
      make: { cachedView ?? makeView() },
      update: { view in
        updateView(view)
      }
    ).eraseToUIViewItem()

    return [viewItem]
  }

  // MARK: - Public

  /// Set whether the width and height of the view node are fixed.
  ///
  /// - Parameters:
  ///   - width: Whether the width is fixed.
  ///   - height: Whether the height is fixed.
  /// - Returns: A new view node with the width and height set.
  public func fixed(width: Bool = true, height: Bool = true) -> Self {
    var node = self
    node.isFixedWidth = width
    node.isFixedHeight = height
    return node
  }

  /// Set the view node to be flexible.
  ///
  /// - Returns: A new view node with the width and height set to flexible.
  public func flexible() -> Self {
    var node = self
    node.isFixedWidth = false
    node.isFixedHeight = false
    return node
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
