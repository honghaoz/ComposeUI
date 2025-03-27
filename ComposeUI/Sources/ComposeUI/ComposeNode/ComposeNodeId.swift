//
//  ComposeNodeId.swift
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

enum StandardComposeNodeId: String {

  case empty

  case color
  case label
  case textView
  case button
  case view
  case layer
  case swiftui
  case gesture

  case spacer
  case frame
  case padding
  case offset

  case overlay
  case underlay
  case vStack
  case hStack
  case zStack
}

public struct ComposeNodeId: Equatable {

  /// Create a custom id for a node.
  ///
  /// - Parameters:
  ///   - id: The id string. You should ensure the id is unique.
  ///   - isFixed: If the id is fixed.
  /// - Returns: A `ComposeNodeId`.
  public static func custom(_ id: String, isFixed: Bool) -> ComposeNodeId {
    guard StandardComposeNodeId(rawValue: id) == nil else {
      assertionFailure("Conflict with standard id: \(id), please use a unique id.")
      return ComposeNodeId(id: "\(id)-\(UUID().uuidString)", isFixed: isFixed)
    }
    return ComposeNodeId(id: id, isFixed: isFixed)
  }

  /// Create a standard id for a node.
  static func standard(_ id: StandardComposeNodeId) -> ComposeNodeId {
    ComposeNodeId(id: id.rawValue, isFixed: false)
  }

  /// The id of the node.
  let id: String

  /// If the id is fixed, `makeId` will not add the parent node's id to the child node's id.
  private let isFixed: Bool

  /// Make a `ComposeNodeId` by joining the current node's id to a child renderable item's id.
  ///
  /// If the `childRenderItemId` is fixed, it will return the `childRenderItemId` directly.
  ///
  /// - Parameters:
  ///   - childRenderItemId: The child renderable's id.
  ///   - suffix: An optional suffix to be added to the current node's id.
  /// - Returns: A `ComposeNodeId`.
  public func join(with childRenderItemId: ComposeNodeId, suffix: String? = nil) -> ComposeNodeId {
    if childRenderItemId.isFixed {
      return childRenderItemId
    } else {
      if let suffix {
        return ComposeNodeId(id: "\(id)|\(suffix)|\(childRenderItemId.id)", isFixed: isFixed)
      } else {
        return ComposeNodeId(id: "\(id)|\(childRenderItemId.id)", isFixed: isFixed)
      }
    }
  }
}
