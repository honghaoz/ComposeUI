//
//  ModifierNode.swift
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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// A node that applies a modifier to a child node.
private struct ModifierNode<Node: ComposeNode>: ComposeNode {

  private var node: Node

  private let willInsert: ((View, ViewInsertContext) -> Void)?
  private let didInsert: ((View, ViewInsertContext) -> Void)?
  private let willUpdate: ((View, ViewUpdateContext) -> Void)?
  private let update: ((View, ViewUpdateContext) -> Void)?
  private let willRemove: ((View, ViewRemoveContext) -> Void)?
  private let didRemove: ((View, ViewRemoveContext) -> Void)?
  private let transition: ViewTransition?
  private let animation: ViewAnimation?

  fileprivate init(node: Node,
                   willInsert: ((View, ViewInsertContext) -> Void)? = nil,
                   didInsert: ((View, ViewInsertContext) -> Void)? = nil,
                   willUpdate: ((View, ViewUpdateContext) -> Void)? = nil,
                   update: ((View, ViewUpdateContext) -> Void)? = nil,
                   willRemove: ((View, ViewRemoveContext) -> Void)? = nil,
                   didRemove: ((View, ViewRemoveContext) -> Void)? = nil,
                   transition: ViewTransition? = nil,
                   animation: ViewAnimation? = nil)
  {
    // TODO: support coalescing modifiers into a single modifier node
    self.node = node
    self.willInsert = willInsert
    self.didInsert = didInsert
    self.willUpdate = willUpdate
    self.update = update
    self.willRemove = willRemove
    self.didRemove = didRemove
    self.transition = transition
    self.animation = animation
  }

  // MARK: - ComposeNode

  var id: ComposeNodeId {
    get { node.id }
    set { node.id = newValue }
  }

  var size: CGSize {
    node.size
  }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    node.layout(containerSize: containerSize, context: context)
  }

  func viewItems(in visibleBounds: CGRect) -> [ViewItem<View>] {
    node.viewItems(in: visibleBounds)
      .map { viewItem in
        var viewItem = viewItem
        if let willInsert = willInsert {
          viewItem = viewItem.addWillInsert(willInsert)
        }
        if let didInsert = didInsert {
          viewItem = viewItem.addDidInsert(didInsert)
        }
        if let willUpdate = willUpdate {
          viewItem = viewItem.addWillUpdate(willUpdate)
        }
        if let update = update {
          viewItem = viewItem.addUpdate(update)
        }
        if let willRemove = willRemove {
          viewItem = viewItem.addWillRemove(willRemove)
        }
        if let didRemove = didRemove {
          viewItem = viewItem.addDidRemove(didRemove)
        }
        if let transition = transition {
          viewItem = viewItem.transition(transition)
        }
        if let animation = animation {
          viewItem = viewItem.animation(animation)
        }
        return viewItem
      }
  }
}

// MARK: - ComposeNode

public extension ComposeNode {

  /// Execute a block when the views provided by the node are about to be inserted into the view hierarchy.
  ///
  /// - Note: All views provided by the node will have the block executed.
  /// - Parameter willInsert: The block to execute.
  /// - Returns: A new node with the block added.
  func willInsert(_ willInsert: @escaping (View, ViewInsertContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, willInsert: willInsert)
  }

  /// Execute a block when the views provided by the node are inserted into the view hierarchy.
  ///
  /// - Note: All views provided by the node will have the block executed.
  ///
  /// - Parameter didInsert: The block to execute.
  /// - Returns: A new node with the block added.
  func onInsert(_ didInsert: @escaping (View, ViewInsertContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, didInsert: didInsert)
  }

  /// Execute a block when the views provided by the node are about to be updated.
  ///
  /// - Note: All views provided by the node will have the block executed.
  ///
  /// - Parameter willUpdate: The block to execute.
  /// - Returns: A new node with the block added.
  func willUpdate(_ willUpdate: @escaping (View, ViewUpdateContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, willUpdate: willUpdate)
  }

  /// Execute a block when the views provided by the node are updated.
  ///
  /// - Note: All views provided by the node will have the block executed.
  ///
  /// - Parameter update: The block to execute.
  /// - Returns: A new node with the block added.
  func onUpdate(_ update: @escaping (View, ViewUpdateContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, update: update)
  }

  /// Execute a block when the views provided by the node are about to be removed from the view hierarchy.
  ///
  /// - Note: All views provided by the node will have the block executed.
  ///
  /// - Parameter willRemove: The block to execute.
  /// - Returns: A new node with the block added.
  func willRemove(_ willRemove: @escaping (View, ViewRemoveContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, willRemove: willRemove)
  }

  /// Execute a block when the views provided by the node are removed from the view hierarchy.
  ///
  /// - Note: All views provided by the node will have the block executed.
  ///
  /// - Parameter didRemove: The block to execute.
  /// - Returns: A new node with the block added.
  func onRemove(_ didRemove: @escaping (View, ViewRemoveContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, didRemove: didRemove)
  }

  /// Set a transition for the views provided by the node.
  ///
  /// - Note: All views provided by the node will have the transition set.
  /// - Note: The inner node's transition will have higher priority.
  ///
  /// - Parameter transition: The transition to set.
  /// - Returns: A new node with the transition set.
  func transition(_ transition: ViewTransition) -> some ComposeNode {
    ModifierNode(node: self, transition: transition)
  }

  /// Set an animation for the views provided by the node.
  ///
  /// - Note: All views provided by the node will have the animation set.
  /// - Note: The inner node's animation will have higher priority.
  ///
  /// - Parameter animation: The animation to set.
  /// - Returns: A new node with the animation set.
  func animation(_ animation: ViewAnimation) -> some ComposeNode {
    ModifierNode(node: self, animation: animation)
  }

  /// Set a key path of the node's views.
  ///
  /// - Note: All views provided by the node will have the key path set.
  ///
  /// - Parameters:
  ///   - keyPath: The key path to set.
  ///   - value: The value to set.
  /// - Returns: A new node with the key path set.
  func keyPath<Value>(_ keyPath: ReferenceWritableKeyPath<View, Value>, _ value: Value) -> some ComposeNode {
    onUpdate { view, context in
      view[keyPath: keyPath] = value
    }
  }

  /// Set the background color of the node's views.
  ///
  /// - Note: All views provided by the node will have the background color set.
  ///
  /// - Parameter color: The background color to set.
  /// - Returns: A new node with the background color set.
  func backgroundColor(_ color: Color) -> some ComposeNode {
    onUpdate { view, context in
      view.layer().backgroundColor = color.cgColor
    }
  }

  /// Set the opacity of the node's views.
  ///
  /// - Note: All views provided by the node will have the opacity set.
  ///
  /// - Parameter opacity: The opacity to set.
  /// - Returns: A new node with the opacity set.
  func opacity(_ opacity: CGFloat) -> some ComposeNode {
    onUpdate { view, context in
      view.layer().opacity = Float(opacity)
    }
  }

  /// Set the border of the node's views.
  ///
  /// - Note: All views provided by the node will have the border set.
  /// - Parameters:
  ///   - color: The color of the border.
  ///   - width: The width of the border.
  /// - Returns: A new node with the border set.
  func border(color: Color, width: CGFloat) -> some ComposeNode {
    onUpdate { view, context in
      let layer = view.layer()
      layer.borderColor = color.cgColor
      layer.borderWidth = width
    }
  }

  /// Set the corner radius of the node's views.
  ///
  /// - Note: All views provided by the node will have the corner radius set.
  ///
  /// - Parameter radius: The corner radius to set.
  /// - Returns: A new node with the corner radius set.
  func cornerRadius(_ radius: CGFloat) -> some ComposeNode {
    onUpdate { view, context in
      let layer = view.layer()
      layer.masksToBounds = true
      layer.cornerCurve = .continuous
      layer.cornerRadius = radius
    }
  }

  /// Set the shadow of the node's views.
  ///
  /// - Note: All views provided by the node will have the shadow set.
  /// - Parameters:
  ///   - color: The color of the shadow.
  ///   - offset: The offset of the shadow.
  ///   - radius: The radius of the shadow.
  ///   - opacity: The opacity of the shadow.
  ///   - path: The block to provide the path of the shadow. The block provides the view that the shadow is applied to.
  /// - Returns: A new node with the shadow set.
  func shadow(color: Color, offset: CGSize, radius: CGFloat, opacity: CGFloat, path: ((View) -> CGPath)?) -> some ComposeNode {
    onUpdate { view, context in
      let layer = view.layer()
      layer.shadowColor = color.cgColor
      layer.shadowOffset = offset
      layer.shadowRadius = radius
      layer.shadowOpacity = Float(opacity)
      if let path = path?(view) {
        layer.shadowPath = path
      }
    }
  }

  /// Set the z-index (zPosition) of the node's views.
  ///
  /// - Note: All views provided by the node will have the z-index set.
  ///
  /// - Parameter zIndex: The z-index to set.
  /// - Returns: A new node with the z-index set.
  func zIndex(_ zIndex: CGFloat) -> some ComposeNode {
    onUpdate { view, context in
      view.layer().zPosition = zIndex
    }
  }

  /// Set whether the node's views are interactive.
  ///
  /// - Note: All views provided by the node will have the `isUserInteractionEnabled` set.
  ///
  /// - Parameter isEnabled: Whether the view is interactive.
  /// - Returns: A new node with the `isUserInteractionEnabled` set.
  func interactive(_ isEnabled: Bool = true) -> some ComposeNode {
    onUpdate { view, context in
      #if canImport(AppKit)
      view.ignoreHitTest = !isEnabled
      #endif

      #if canImport(UIKit)
      view.isUserInteractionEnabled = isEnabled
      #endif
    }
  }
}
