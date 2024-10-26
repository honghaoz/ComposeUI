//
//  ModifierNode.swift
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

/// A node that applies a modifier to a child node.
private struct ModifierNode<Node: ComposeNode>: ComposeNode {

  private var node: Node
  private let modifier: (UIView) -> Void

  fileprivate init(node: Node, modifier: @escaping (UIView) -> Void) {
    self.node = node
    self.modifier = modifier
  }

  // MARK: - ComposeNode

  var size: CGSize {
    node.size
  }

  mutating func layout(containerSize: CGSize) -> ComposeNodeSizing {
    node.layout(containerSize: containerSize)
  }

  func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>] {
    node.viewItems(in: visibleBounds)
      .map { $0.addsUpdate(modifier) }
  }
}

// MARK: - ComposeNode

public extension ComposeNode {

  /// Apply a modifier to the node's view.
  ///
  /// - Parameter modifier: The modifier to apply.
  /// - Returns: A new node with the modifier applied.
  func modify(with modifier: @escaping (UIView) -> Void) -> some ComposeNode {
    ModifierNode(node: self, modifier: modifier)
  }

  /// Set a key path of the node's view.
  ///
  /// - Parameters:
  ///   - keyPath: The key path to set.
  ///   - value: The value to set.
  /// - Returns: A new node with the key path set.
  func keyPath<Value>(_ keyPath: ReferenceWritableKeyPath<UIView, Value>, _ value: Value) -> some ComposeNode {
    modify { view in
      view[keyPath: keyPath] = value
    }
  }

  /// Set the border of the node's view.
  ///
  /// - Parameters:
  ///   - color: The color of the border.
  ///   - width: The width of the border.
  /// - Returns: A new node with the border set.
  func border(color: UIColor, width: CGFloat) -> some ComposeNode {
    modify { view in
      view.layer.borderColor = color.cgColor
      view.layer.borderWidth = width
    }
  }

  /// Set the corner radius of the node's view.
  ///
  /// - Parameter radius: The corner radius to set.
  /// - Returns: A new node with the corner radius set.
  func cornerRadius(_ radius: CGFloat) -> some ComposeNode {
    modify { view in
      view.layer.masksToBounds = true
      view.layer.cornerCurve = .continuous
      view.layer.cornerRadius = radius
    }
  }

  /// Set the shadow of the node's view.
  ///
  /// - Parameters:
  ///   - color: The color of the shadow.
  ///   - offset: The offset of the shadow.
  ///   - radius: The radius of the shadow.
  ///   - opacity: The opacity of the shadow.
  /// - Returns: A new node with the shadow set.
  func shadow(color: UIColor, offset: CGSize, radius: CGFloat, opacity: Float) -> some ComposeNode {
    modify { view in
      view.layer.shadowColor = color.cgColor
      view.layer.shadowOffset = offset
      view.layer.shadowRadius = radius
      view.layer.shadowOpacity = opacity
    }
  }

  /// Set the background color of the node's view.
  ///
  /// - Parameter color: The background color to set.
  /// - Returns: A new node with the background color set.
  func backgroundColor(_ color: UIColor) -> some ComposeNode {
    modify { view in
      view.backgroundColor = color
    }
  }

  /// Set the opacity of the node's view.
  ///
  /// - Parameter opacity: The opacity to set.
  /// - Returns: A new node with the opacity set.
  func opacity(_ opacity: CGFloat) -> some ComposeNode {
    modify { view in
      view.alpha = opacity
    }
  }

  /// Set whether the node's view is interactive.
  ///
  /// - Parameter isEnabled: Whether the view is interactive.
  /// - Returns: A new node with the `isUserInteractionEnabled` set.
  func interactive(_ isEnabled: Bool = true) -> some ComposeNode {
    modify { view in
      view.isUserInteractionEnabled = isEnabled
    }
  }
}
