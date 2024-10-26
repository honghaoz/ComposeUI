//
//  VerticalStackNode.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit

public typealias View = ViewNode

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

  public init(make: @autoclosure @escaping () -> T,
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

  public func fixed(width: Bool = true, height: Bool = true) -> Self {
    var node = self
    node.isFixedWidth = width
    node.isFixedHeight = height
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
