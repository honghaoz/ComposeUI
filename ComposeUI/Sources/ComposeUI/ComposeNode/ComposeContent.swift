//
//  ComposeContent.swift
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

import Foundation

// MARK: - ComposeContent

public protocol ComposeContent {

  /// Convert the compose content to a list of nodes.
  /// - Returns: The list of nodes.
  func asNodes() -> [any ComposeNode]
}

public extension ComposeContent {

  /// Convert the compose content to a vertical stack node.
  /// - Parameter alignment: The alignment of the vertical stack node.
  /// - Returns: The vertical stack node.
  func asVStack(alignment: Layout.HorizontalAlignment = .center) -> any ComposeNode {
    let nodes = asNodes()
    switch nodes.count {
    case 0:
      return EmptyNode()
    case 1:
      return nodes.first! // swiftlint:disable:this force_unwrapping
    default:
      return VerticalStackNode(alignment: alignment, content: { nodes })
    }
  }

  /// Convert the compose content to a layered stack node.
  /// - Parameter alignment: The alignment of the layered stack node.
  /// - Returns: The layered stack node.
  func asZStack(alignment: Layout.Alignment = .center) -> any ComposeNode {
    let nodes = asNodes()
    switch nodes.count {
    case 0:
      return EmptyNode()
    case 1:
      return nodes.first! // swiftlint:disable:this force_unwrapping
    default:
      return LayeredStackNode(alignment: alignment, content: { nodes })
    }
  }
}

// MARK: - ComposeNode Array

extension [ComposeNode]: ComposeContent {

  public func asNodes() -> [any ComposeNode] {
    self
  }
}
