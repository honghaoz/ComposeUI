//
//  SpacerNode.swift
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

import CoreGraphics

public typealias Spacer = SpacerNode

/// A node that occupies the some space.
public struct SpacerNode: ComposeNode {

  var width: CGFloat?
  var height: CGFloat?

  /// Make a spacer with the given size.
  /// - Parameters:
  ///   - size: The size of the spacer. Pass `nil` to make the spacer flexible.
  @inlinable
  @inline(__always)
  public init(_ size: CGSize?) {
    self.init(width: size?.width, height: size?.height)
  }

  /// Make a spacer with the given size.
  /// - Parameters:
  ///   - size: The size of the spacer. Pass `nil` to make the spacer flexible.
  @inlinable
  @inline(__always)
  public init(_ size: CGFloat?) {
    self.init(width: size, height: size)
  }

  /// Make a spacer with the given size.
  /// - Parameters:
  ///   - width: The fixed width. If not specified, the width follows the container.
  ///   - height: The fixed height. If not specified, the height follows the container.
  public init(width: CGFloat? = nil, height: CGFloat? = nil) {
    self.width = width
    self.height = height
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .predefined(.spacer)

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

  public func viewItems(in visibleBounds: CGRect) -> [ViewItem<View>] {
    return []
  }

  // MARK: -

  /// Set the width of the spacer.
  /// - Parameter width: The width to set. Pass `nil` to make the spacer flexible in width.
  public func width(_ width: CGFloat?) -> SpacerNode {
    guard self.width != width else {
      return self
    }

    var copy = self
    copy.width = width

    return copy
  }

  /// Set the height of the spacer.
  /// - Parameter height: The height to set. Pass `nil` to make the spacer flexible in height.
  public func height(_ height: CGFloat?) -> SpacerNode {
    guard self.height != height else {
      return self
    }

    var copy = self
    copy.height = height

    return copy
  }
}
