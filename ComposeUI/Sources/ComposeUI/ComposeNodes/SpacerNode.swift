//
//  SpacerNode.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit

public typealias Spacer = SpacerNode

public struct SpacerNode: ComposeNode {

  var width: CGFloat?
  var height: CGFloat?

  /// Make a SpacerNode with CGSize.
  /// - Parameters:
  ///   - size: The size of the spacer. If not specified, the size follows the container.
  @inlinable
  @inline(__always)
  public init(_ size: CGSize?) {
    self.init(width: size?.width, height: size?.height)
  }

  @inlinable
  @inline(__always)
  public init(_ size: CGFloat?) {
    self.init(width: size, height: size)
  }

  /// Make a SpacerNode.
  /// - Parameters:
  ///   - width: The fixed width. If not specified, the width follows the container.
  ///   - height: The fixed height. If not specified, the height follows the container.
  public init(width: CGFloat? = nil, height: CGFloat? = nil) {
    self.width = width
    self.height = height
  }

  // MARK: - ComposeNode

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize) -> ComposeNodeSizing {
    let sizing: ComposeNodeSizing

    switch (width, height) {
    case (.none, .none):
      self.size = containerSize
      sizing = ComposeNodeSizing(width: .flexible, height: .flexible)
    case (.some(let width), .none):
      self.size = CGSize(width: width, height: containerSize.height)
      sizing = ComposeNodeSizing(width: .fixed(width), height: .flexible)
    case (.none, .some(let height)):
      self.size = CGSize(width: containerSize.width, height: height)
      sizing = ComposeNodeSizing(width: .flexible, height: .fixed(height))
    case (.some(let width), .some(let height)):
      self.size = CGSize(width: width, height: height)
      sizing = ComposeNodeSizing(width: .fixed(width), height: .fixed(height))
    }

    return sizing
  }

  public func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>] {
    return []
  }

  // MARK: - 

  public func width(_ width: CGFloat?) -> SpacerNode {
    guard self.width != width else {
      return self
    }

    var copy = self
    copy.width = width

    return copy
  }

  public func height(_ height: CGFloat?) -> SpacerNode {
    guard self.height != height else {
      return self
    }

    var copy = self
    copy.height = height

    return copy
  }
}
