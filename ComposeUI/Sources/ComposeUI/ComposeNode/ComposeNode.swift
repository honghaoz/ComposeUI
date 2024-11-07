//
//  ComposeNode.swift
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

public protocol ComposeNode: ComposeContent {

  /// The id of the node.
  ///
  /// The id should be unique.
  /// The id is used in the returned view items to diff the view items in the view hierarchy.
  var id: ComposeNodeId { get set }

  /// The size of the node.
  var size: CGSize { get }

  /// Layout the node in the given container size.
  ///
  /// - Parameter containerSize: The container size.
  /// - Returns: The sizing information of the node.
  @discardableResult
  mutating func layout(containerSize: CGSize) -> ComposeNodeSizing

  /// Get the view items that are visible in the given bounds.
  ///
  /// - Parameter visibleBounds: The visible bounds, in the node's coordinate space.
  /// - Returns: The view items that are visible in the given bounds.
  func viewItems(in visibleBounds: CGRect) -> [ViewItem<View>]
}

// MARK: - ComposeContent

public extension ComposeNode {

  func asNodes() -> [any ComposeNode] {
    [self]
  }
}

// MARK: - Id

public extension ComposeNode {

  /// Set the id of the node.
  func id(_ id: String) -> Self {
    self.id(.custom(id, isFixed: false))
  }

  /// Set a fixed id of the node.
  ///
  /// The view items provided by this node should have the fixed id.
  func fixedId(_ id: String) -> Self {
    self.id(.custom(id, isFixed: true))
  }

  private func id(_ id: ComposeNodeId) -> Self {
    guard self.id != id else {
      return self
    }

    var node = self
    node.id = id
    return node
  }
}
