//
//  ContainerNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/21/25.
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

/// A container node that manages a list of child nodes.
public protocol ContainerNode {

  /// Applies a modifier to all children of the node.
  ///
  /// - Parameter modifier: The modifier to apply to the children.
  /// - Returns: A new container node with the modifier applied to its children.
  func mapChildren(_ modifier: (any ComposeNode) -> any ComposeNode) -> Self
}

protocol ContainerNodeInternal: ContainerNode {

  /// The list of child nodes managed by the container node.
  var childNodes: [any ComposeNode] { get set }
}

extension ContainerNodeInternal {

  public func mapChildren(_ modifier: (any ComposeNode) -> any ComposeNode) -> Self {
    var node = self
    node.childNodes = node.childNodes.map { modifier($0) }
    return node
  }
}
