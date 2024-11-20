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
private struct ModifierNode: ComposeNode {

  private var node: ComposeNode

  private let willInsert: ((Renderable, ViewInsertContext) -> Void)?
  private let didInsert: ((Renderable, ViewInsertContext) -> Void)?
  private let willUpdate: ((Renderable, ViewUpdateContext) -> Void)?
  private let update: ((Renderable, ViewUpdateContext) -> Void)?
  private let willRemove: ((Renderable, ViewRemoveContext) -> Void)?
  private let didRemove: ((Renderable, ViewRemoveContext) -> Void)?
  private let transition: ViewTransition?
  private let animationTiming: AnimationTiming?

  fileprivate init(node: ComposeNode,
                   willInsert: ((Renderable, ViewInsertContext) -> Void)? = nil,
                   didInsert: ((Renderable, ViewInsertContext) -> Void)? = nil,
                   willUpdate: ((Renderable, ViewUpdateContext) -> Void)? = nil,
                   update: ((Renderable, ViewUpdateContext) -> Void)? = nil,
                   willRemove: ((Renderable, ViewRemoveContext) -> Void)? = nil,
                   didRemove: ((Renderable, ViewRemoveContext) -> Void)? = nil,
                   transition: ViewTransition? = nil,
                   animationTiming: AnimationTiming? = nil)
  {
    if let modifierNode = node as? ModifierNode { // coalescing modifiers
      self.node = modifierNode.node

      self.willInsert = Self.combineBlocks(modifierNode.willInsert, willInsert)
      self.didInsert = Self.combineBlocks(modifierNode.didInsert, didInsert)
      self.willUpdate = Self.combineBlocks(modifierNode.willUpdate, willUpdate)
      self.update = Self.combineBlocks(modifierNode.update, update)
      self.willRemove = Self.combineBlocks(modifierNode.willRemove, willRemove)
      self.didRemove = Self.combineBlocks(modifierNode.didRemove, didRemove)

      self.transition = modifierNode.transition ?? transition
      self.animationTiming = modifierNode.animationTiming ?? animationTiming
    } else {
      self.node = node
      self.willInsert = willInsert
      self.didInsert = didInsert
      self.willUpdate = willUpdate
      self.update = update
      self.willRemove = willRemove
      self.didRemove = didRemove
      self.transition = transition
      self.animationTiming = animationTiming
    }
  }

  private static func combineBlocks<T>(_ first: ((Renderable, T) -> Void)?, _ second: ((Renderable, T) -> Void)?) -> ((Renderable, T) -> Void)? {
    switch (first, second) {
    case (nil, nil):
      return nil
    case (let first?, nil):
      return first
    case (nil, let second?):
      return second
    case (let first?, let second?):
      return { renderable, context in
        first(renderable, context)
        second(renderable, context)
      }
    }
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

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    node.renderableItems(in: visibleBounds)
      .map { item in
        var item = item
        if let willInsert = willInsert {
          item = item.addWillInsert(willInsert)
        }
        if let didInsert = didInsert {
          item = item.addDidInsert(didInsert)
        }
        if let willUpdate = willUpdate {
          item = item.addWillUpdate(willUpdate)
        }
        if let update = update {
          item = item.addUpdate(update)
        }
        if let willRemove = willRemove {
          item = item.addWillRemove(willRemove)
        }
        if let didRemove = didRemove {
          item = item.addDidRemove(didRemove)
        }
        if let transition = transition {
          item = item.transition(transition)
        }
        if let animationTiming = animationTiming {
          item = item.animation(animationTiming)
        }
        return item
      }
  }
}

// MARK: - ComposeNode

public extension ComposeNode {

  /// Execute a block when the renderables provided by the node are about to be inserted into the renderable hierarchy.
  ///
  /// - Note: All renderables provided by the node will have the block executed.
  /// - Parameter willInsert: The block to execute.
  /// - Returns: A new node with the block added.
  func willInsert(_ willInsert: @escaping (Renderable, ViewInsertContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, willInsert: willInsert)
  }

  /// Execute a block when the renderables provided by the node are inserted into the renderable hierarchy.
  ///
  /// - Note: All renderables provided by the node will have the block executed.
  ///
  /// - Parameter didInsert: The block to execute.
  /// - Returns: A new node with the block added.
  func onInsert(_ didInsert: @escaping (Renderable, ViewInsertContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, didInsert: didInsert)
  }

  /// Execute a block when the renderables provided by the node are about to be updated.
  ///
  /// - Note: All renderables provided by the node will have the block executed.
  ///
  /// - Parameter willUpdate: The block to execute.
  /// - Returns: A new node with the block added.
  func willUpdate(_ willUpdate: @escaping (Renderable, ViewUpdateContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, willUpdate: willUpdate)
  }

  /// Execute a block when the renderables provided by the node are updated.
  ///
  /// - Note: All renderables provided by the node will have the block executed.
  ///
  /// - Parameter update: The block to execute.
  /// - Returns: A new node with the block added.
  func onUpdate(_ update: @escaping (Renderable, ViewUpdateContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, update: update)
  }

  /// Execute a block when the renderables provided by the node are about to be removed from the renderable hierarchy.
  ///
  /// - Note: All renderables provided by the node will have the block executed.
  ///
  /// - Parameter willRemove: The block to execute.
  /// - Returns: A new node with the block added.
  func willRemove(_ willRemove: @escaping (Renderable, ViewRemoveContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, willRemove: willRemove)
  }

  /// Execute a block when the renderables provided by the node are removed from the renderable hierarchy.
  ///
  /// - Note: All renderables provided by the node will have the block executed.
  ///
  /// - Parameter didRemove: The block to execute.
  /// - Returns: A new node with the block added.
  func onRemove(_ didRemove: @escaping (Renderable, ViewRemoveContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, didRemove: didRemove)
  }

  /// Set a transition for the renderables provided by the node.
  ///
  /// - Note: All renderables provided by the node will have the transition set.
  /// - Note: The inner node's transition will have higher priority.
  ///
  /// - Parameter transition: The transition to set.
  /// - Returns: A new node with the transition set.
  func transition(_ transition: ViewTransition) -> some ComposeNode {
    ModifierNode(node: self, transition: transition)
  }

  /// Set an animation for the renderables provided by the node.
  ///
  /// - Note: All renderables provided by the node will have the animation set.
  /// - Note: The inner node's animation will have higher priority.
  ///
  /// - Parameter animationTiming: The animation timing to set.
  /// - Returns: A new node with the animation set.
  func animation(_ animationTiming: AnimationTiming) -> some ComposeNode {
    ModifierNode(node: self, animationTiming: animationTiming)
  }

  /// Set the background color of the node's renderables.
  ///
  /// - Note: All renderables provided by the node will have the background color set.
  ///
  /// - Parameter color: The background color to set.
  /// - Returns: A new node with the background color set.
  func backgroundColor(_ color: Color) -> some ComposeNode {
    onUpdate { item, context in
      item.layer.backgroundColor = color.cgColor
    }
  }

  /// Set the opacity of the node's renderables.
  ///
  /// - Note: All renderables provided by the node will have the opacity set.
  ///
  /// - Parameter opacity: The opacity to set.
  /// - Returns: A new node with the opacity set.
  func opacity(_ opacity: CGFloat) -> some ComposeNode {
    onUpdate { item, context in
      item.layer.opacity = Float(opacity)
    }
  }

  /// Set the border of the node's renderables.
  ///
  /// - Note: All renderables provided by the node will have the border set.
  ///
  /// - Parameters:
  ///   - color: The color of the border.
  ///   - width: The width of the border.
  /// - Returns: A new node with the border set.
  func border(color: Color, width: CGFloat) -> some ComposeNode {
    onUpdate { item, context in
      let layer = item.layer
      layer.borderColor = color.cgColor
      layer.borderWidth = width
    }
  }

  /// Set the corner radius of the node's renderables.
  ///
  /// - Note: All renderables provided by the node will have the corner radius set.
  ///
  /// - Parameter radius: The corner radius to set.
  /// - Returns: A new node with the corner radius set.
  func cornerRadius(_ radius: CGFloat) -> some ComposeNode {
    onUpdate { item, context in
      let layer = item.layer
      layer.masksToBounds = true
      layer.cornerCurve = .continuous
      layer.cornerRadius = radius
    }
  }

  /// Set the shadow of the node's renderables.
  ///
  /// - Note: All renderables provided by the node will have the shadow set.
  ///
  /// - Parameters:
  ///   - color: The color of the shadow.
  ///   - offset: The offset of the shadow.
  ///   - radius: The radius of the shadow.
  ///   - opacity: The opacity of the shadow.
  ///   - path: The block to provide the path of the shadow. The block provides the renderable that the shadow is applied to.
  /// - Returns: A new node with the shadow set.
  func shadow(color: Color, offset: CGSize, radius: CGFloat, opacity: CGFloat, path: ((Renderable) -> CGPath)?) -> some ComposeNode {
    onUpdate { item, context in
      let layer = item.layer
      layer.shadowColor = color.cgColor
      layer.shadowOffset = offset
      layer.shadowRadius = radius
      layer.shadowOpacity = Float(opacity)
      if let path = path?(item) {
        layer.shadowPath = path
      }
    }
  }

  /// Set the z-index (zPosition) of the node's renderables.
  ///
  /// - Note: All renderables provided by the node will have the z-index set.
  ///
  /// - Parameter zIndex: The z-index to set.
  /// - Returns: A new node with the z-index set.
  func zIndex(_ zIndex: CGFloat) -> some ComposeNode {
    onUpdate { item, context in
      item.layer.zPosition = zIndex
    }
  }

  /// Set whether the node's renderables are interactive.
  ///
  /// - Note: All renderables provided by the node will have the `isUserInteractionEnabled` set.
  ///
  /// - Parameter isEnabled: Whether the renderable is interactive.
  /// - Returns: A new node with the `isUserInteractionEnabled` set.
  func interactive(_ isEnabled: Bool = true) -> some ComposeNode {
    onUpdate { item, context in
      guard let view = item.view else {
        return
      }

      #if canImport(AppKit)
      view.ignoreHitTest = !isEnabled
      #endif

      #if canImport(UIKit)
      view.isUserInteractionEnabled = isEnabled
      #endif
    }
  }
}
