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

  private let willInsert: ((Renderable, RenderableInsertContext) -> Void)?
  private let didInsert: ((Renderable, RenderableInsertContext) -> Void)?
  private let willUpdate: ((Renderable, RenderableUpdateContext) -> Void)?
  private let update: ((Renderable, RenderableUpdateContext) -> Void)?
  private let willRemove: ((Renderable, RenderableRemoveContext) -> Void)?
  private let didRemove: ((Renderable, RenderableRemoveContext) -> Void)?
  private let reuseId: String?
  private let resetForReuse: ((Renderable) -> Void)?
  private let transition: RenderableTransition?
  private let animationTiming: AnimationTiming?
  private let zIndex: CGFloat?

  fileprivate init(node: ComposeNode,
                   willInsert: ((Renderable, RenderableInsertContext) -> Void)? = nil,
                   didInsert: ((Renderable, RenderableInsertContext) -> Void)? = nil,
                   willUpdate: ((Renderable, RenderableUpdateContext) -> Void)? = nil,
                   update: ((Renderable, RenderableUpdateContext) -> Void)? = nil,
                   willRemove: ((Renderable, RenderableRemoveContext) -> Void)? = nil,
                   didRemove: ((Renderable, RenderableRemoveContext) -> Void)? = nil,
                   reuseId: String? = nil,
                   resetForReuse: ((Renderable) -> Void)? = nil,
                   transition: RenderableTransition? = nil,
                   animationTiming: AnimationTiming? = nil,
                   zIndex: CGFloat? = nil)
  {
    if let modifierNode = node as? ModifierNode { // coalescing modifiers
      self.node = modifierNode.node
      self.willInsert = Self.combineBlocks(modifierNode.willInsert, willInsert)
      self.didInsert = Self.combineBlocks(modifierNode.didInsert, didInsert)
      self.willUpdate = Self.combineBlocks(modifierNode.willUpdate, willUpdate)
      self.update = Self.combineBlocks(modifierNode.update, update)
      self.willRemove = Self.combineBlocks(modifierNode.willRemove, willRemove)
      self.didRemove = Self.combineBlocks(modifierNode.didRemove, didRemove)
      self.reuseId = modifierNode.reuseId ?? reuseId
      self.resetForReuse = Self.combineBlocks(modifierNode.resetForReuse, resetForReuse)
      self.transition = modifierNode.transition ?? transition
      self.animationTiming = modifierNode.animationTiming ?? animationTiming
      self.zIndex = zIndex ?? modifierNode.zIndex // the outer z-index wins, see `ComposeNode.zIndex(_:)`
    } else {
      self.node = node
      self.willInsert = willInsert
      self.didInsert = didInsert
      self.willUpdate = willUpdate
      self.update = update
      self.willRemove = willRemove
      self.didRemove = didRemove
      self.reuseId = reuseId
      self.resetForReuse = resetForReuse
      self.transition = transition
      self.animationTiming = animationTiming
      self.zIndex = zIndex
    }
  }

  private static func combineBlocks(_ first: ((Renderable) -> Void)?, _ second: ((Renderable) -> Void)?) -> ((Renderable) -> Void)? {
    switch (first, second) {
    case (nil, nil):
      return nil
    case (let first?, nil):
      return first
    case (nil, let second?):
      return second
    case (let first?, let second?):
      return { renderable in
        first(renderable)
        second(renderable)
      }
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

  var renderableItemsBoundingRect: CGRect {
    node.renderableItemsBoundingRect
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
        if let reuseId = reuseId {
          item = item.reuseId(reuseId)
        }
        if let resetForReuse = resetForReuse {
          item = item.addResetForReuse(resetForReuse)
        }
        if let transition = transition {
          item = item.transition(transition)
        }
        if let animationTiming = animationTiming {
          item = item.animation(animationTiming)
        }
        if let zIndex = zIndex {
          item = item.zIndex(zIndex)
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
  func willInsert(_ willInsert: @escaping (_ renderable: Renderable, _ context: RenderableInsertContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, willInsert: willInsert)
  }

  /// Execute a block when the renderables provided by the node are inserted into the renderable hierarchy.
  ///
  /// - Note: All renderables provided by the node will have the block executed.
  ///
  /// - Parameter didInsert: The block to execute.
  /// - Returns: A new node with the block added.
  func onInsert(_ didInsert: @escaping (_ renderable: Renderable, _ context: RenderableInsertContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, didInsert: didInsert)
  }

  /// Execute a block when the renderables provided by the node are about to be updated.
  ///
  /// - Note: All renderables provided by the node will have the block executed.
  ///
  /// - Parameter willUpdate: The block to execute.
  /// - Returns: A new node with the block added.
  func willUpdate(_ willUpdate: @escaping (_ renderable: Renderable, _ context: RenderableUpdateContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, willUpdate: willUpdate)
  }

  /// Execute a block when the renderables provided by the node are updated.
  ///
  /// - Note: All renderables provided by the node will have the block executed.
  ///
  /// - Parameter update: The block to execute.
  /// - Returns: A new node with the block added.
  func onUpdate(_ update: @escaping (_ renderable: Renderable, _ context: RenderableUpdateContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, update: update)
  }

  /// Execute a block when the renderables provided by the node are about to be removed from the renderable hierarchy.
  ///
  /// - Note: All renderables provided by the node will have the block executed.
  ///
  /// - Parameter willRemove: The block to execute.
  /// - Returns: A new node with the block added.
  func willRemove(_ willRemove: @escaping (_ renderable: Renderable, _ context: RenderableRemoveContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, willRemove: willRemove)
  }

  /// Execute a block when the renderables provided by the node are removed from the renderable hierarchy.
  ///
  /// - Note: All renderables provided by the node will have the block executed.
  ///
  /// - Parameter didRemove: The block to execute.
  /// - Returns: A new node with the block added.
  func onRemove(_ didRemove: @escaping (_ renderable: Renderable, _ context: RenderableRemoveContext) -> Void) -> some ComposeNode {
    ModifierNode(node: self, didRemove: didRemove)
  }

  /// Set a transition for the renderables provided by the node.
  ///
  /// - Note: All renderables provided by the node will have the transition set.
  /// - Note: The inner node's transition will have higher priority.
  ///
  /// - Parameter transition: The transition to set.
  /// - Returns: A new node with the transition set.
  func transition(_ transition: RenderableTransition) -> some ComposeNode {
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

  /// Set a reuse identifier for the renderables provided by the node, opting them into the recycle pool.
  ///
  /// When a renderable is removed from the renderable hierarchy, it is added to a pool instead of being
  /// deallocated, and is handed back when a new item with the same reuse identifier and concrete type is inserted.
  ///
  /// For renderables that are expensive to create, this can avoid the cost of creating and speed up the rendering.
  ///
  /// - Note: This is intended for leaf nodes that produce a single renderable. For nodes that produce multiple renderables,
  ///   calling this method on the node will make every matching concrete type share a pool bucket, so only do that when
  ///   those renderables are interchangeable and reset/configured by the same contract.
  ///   Prefer calling this method on the innermost node that produces a single renderable to avoid accidentally sharing.
  /// - Note: Reused renderables can carry states from their previous usage, either ensure the same set of properties
  ///   are set on the reused renderable, or use ``onResetForReuse(_:)`` to reset the renderable's modified properties.
  /// - Note: The inner node's reuse identifier (closer to the leaf) has higher priority.
  ///
  /// - Parameter reuseId: The reuse identifier to set.
  /// - Returns: A new node with the reuse identifier set.
  func reuseId(_ reuseId: String) -> some ComposeNode {
    ModifierNode(node: self, reuseId: reuseId)
  }

  /// Execute a block when the node's renderable is about to be added to the reuse pool, to reset any modified state so the
  /// pooled renderable is clean for its next use.
  ///
  /// - Note: All renderables provided by the node will have the block executed when they are added to the reuse pool.
  ///
  /// - Parameter resetForReuse: The block to execute.
  /// - Returns: A new node with the block added.
  func onResetForReuse(_ resetForReuse: @escaping (_ renderable: Renderable) -> Void) -> some ComposeNode {
    ModifierNode(node: self, resetForReuse: resetForReuse)
  }

  /// Set the background color of the node's renderables.
  ///
  /// - Note: All renderables provided by the node will have the background color set.
  ///
  /// - Parameter color: The background color to set.
  /// - Returns: A new node with the background color set.
  func backgroundColor(_ color: Color) -> some ComposeNode {
    backgroundColor(ThemedColor(color))
  }

  /// Set the themed background color of the node's renderables.
  ///
  /// - Note: All renderables provided by the node will have the background color set.
  ///
  /// - Parameter color: The themed background color to set.
  /// - Returns: A new node with the background color set.
  func backgroundColor(_ color: ThemedColor) -> some ComposeNode {
    ModifierNode(
      node: self,
      update: { item, context in
        guard context.updateType.requiresFullUpdate else {
          return
        }

        let layer = item.layer
        let color = color.resolve(for: context.contentView.theme).cgColor
        if let animationTiming = context.animationTiming {
          layer.animate(
            keyPath: "backgroundColor",
            timing: animationTiming,
            from: { $0.presentation()?.backgroundColor ?? $0.backgroundColor ?? Color.clear.cgColor },
            to: { _ in color }
          )
        } else {
          layer.disableActions(for: "backgroundColor") {
            layer.backgroundColor = color
          }
        }
      },
      resetForReuse: { renderable in
        let layer = renderable.layer
        if layer.backgroundColor != nil {
          layer.disableActions(for: "backgroundColor") {
            layer.backgroundColor = nil
          }
        }
      }
    )
  }

  /// Set the opacity of the node's renderables.
  ///
  /// - Note: All renderables provided by the node will have the opacity set.
  ///
  /// - Parameter opacity: The opacity to set.
  /// - Returns: A new node with the opacity set.
  func opacity(_ opacity: CGFloat) -> some ComposeNode {
    self.opacity(Themed<CGFloat>(opacity))
  }

  /// Set the themed opacity of the node's renderables.
  ///
  /// - Note: All renderables provided by the node will have the opacity set.
  ///
  /// - Parameter opacity: The themed opacity to set.
  /// - Returns: A new node with the opacity set.
  func opacity(_ opacity: Themed<CGFloat>) -> some ComposeNode {
    ModifierNode(
      node: self,
      update: { item, context in
        guard context.updateType.requiresFullUpdate else {
          return
        }
        let layer = item.layer
        let opacity = Float(opacity.resolve(for: context.contentView.theme))
        if let animationTiming = context.animationTiming {
          layer.animate(keyPath: "opacity", to: opacity, timing: animationTiming)
        } else {
          layer.disableActions(for: "opacity") {
            layer.opacity = opacity
          }
        }
      },
      resetForReuse: { renderable in
        let layer = renderable.layer
        if layer.opacity != 1 {
          layer.disableActions(for: "opacity") {
            layer.opacity = 1
          }
        }
      }
    )
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
    border(color: ThemedColor(color), width: Themed<CGFloat>(width))
  }

  /// Set the themed border of the node's renderables.
  ///
  /// - Note: All renderables provided by the node will have the border set.
  ///
  /// - Parameters:
  ///   - color: The themed color of the border.
  ///   - width: The themed width of the border.
  /// - Returns: A new node with the border set.
  func border(color: ThemedColor, width: Themed<CGFloat>) -> some ComposeNode {
    ModifierNode(
      node: self,
      update: { item, context in
        guard context.updateType.requiresFullUpdate else {
          return
        }

        let layer = item.layer
        let color = color.resolve(for: context.contentView.theme).cgColor
        let width: CGFloat = width.resolve(for: context.contentView.theme)
        if let animationTiming = context.animationTiming {
          layer.animate(
            keyPath: "borderColor",
            timing: animationTiming,
            from: { $0.presentation()?.borderColor ?? $0.borderColor ?? Color.clear.cgColor },
            to: { _ in color }
          )
          layer.animate(keyPath: "borderWidth", to: width, timing: animationTiming)
        } else {
          layer.disableActions(for: "borderColor", "borderWidth") {
            layer.borderColor = color
            layer.borderWidth = width
          }
        }
      },
      resetForReuse: { renderable in
        let layer = renderable.layer
        let defaultBorderColor = layer.defaultBorderColor
        if layer.borderColor != defaultBorderColor || layer.borderWidth != 0 {
          layer.disableActions(for: "borderColor", "borderWidth") {
            layer.borderColor = defaultBorderColor
            layer.borderWidth = 0
          }
        }
      }
    )
  }

  /// Set the corner radius of the node's renderables.
  ///
  /// - Note: All renderables provided by the node will have the corner radius set.
  ///
  /// - Parameters:
  ///   - radius: The corner radius to set.
  ///   - cornerCurve: The corner curve to set. The default is `.continuous`.
  /// - Returns: A new node with the corner radius set.
  func cornerRadius(_ radius: CGFloat, cornerCurve: CALayerCornerCurve = .continuous) -> some ComposeNode {
    ModifierNode(
      node: self,
      update: { item, context in
        guard context.updateType.requiresFullUpdate else {
          return
        }

        let layer = item.layer
        layer.cornerCurve = cornerCurve

        if let animationTiming = context.animationTiming {
          layer.animate(keyPath: "cornerRadius", to: radius, timing: animationTiming)
        } else {
          layer.disableActions(for: "cornerRadius") {
            layer.cornerRadius = radius
          }
        }
      },
      resetForReuse: { renderable in
        let layer = renderable.layer
        if layer.cornerCurve != .continuous {
          layer.cornerCurve = .continuous
        }
        if layer.cornerRadius != 0 {
          layer.disableActions(for: "cornerRadius") {
            layer.cornerRadius = 0
          }
        }
      }
    )
  }

  /// Set whether the node's renderables are masked to bounds.
  ///
  /// - Note: All renderables provided by the node will have the `masksToBounds` set.
  ///
  /// - Parameter masksToBounds: Whether the renderable is masked to bounds. The default is `true`.
  /// - Returns: A new node with the `masksToBounds` set.
  func masksToBounds(_ masksToBounds: Bool = true) -> some ComposeNode {
    ModifierNode(
      node: self,
      update: { item, context in
        guard context.updateType.requiresFullUpdate else {
          return
        }

        let layer = item.layer
        layer.masksToBounds = masksToBounds
      },
      resetForReuse: { renderable in
        if renderable.layer.masksToBounds != false {
          renderable.layer.masksToBounds = false
        }
      }
    )
  }

  /// Set the shadow of the node's renderables.
  ///
  /// - Note: All renderables provided by the node will have the shadow set.
  ///
  /// - Note: The layer's border may show ghosting effect when the shadow is animating. You may want to avoid adding a shadow to layers that have a border.
  /// Tip: You can use a dedicated transparent `LayerNode` as an underlay and apply the shadow to the underlay or use `dropShadow(color:opacity:radius:offset:path:)` to add a drop shadow underlay to the node.
  ///
  /// - Parameters:
  ///   - color: The color of the shadow. The color should be a solid color.
  ///   - opacity: The opacity of the shadow.
  ///   - radius: The radius of the shadow.
  ///   - offset: The offset of the shadow.
  ///   - path: The block to provide the path of the shadow. The block provides the renderable that the shadow is applied to.
  /// - Returns: A new node with the shadow set.
  func shadow(color: Color, opacity: CGFloat, radius: CGFloat, offset: CGSize, path: ((Renderable) -> CGPath)?) -> some ComposeNode {
    shadow(color: ThemedColor(color), opacity: Themed<CGFloat>(opacity), radius: Themed<CGFloat>(radius), offset: Themed<CGSize>(offset), path: path)
  }

  /// Set the themed shadow of the node's renderables.
  ///
  /// - Note: All renderables provided by the node will have the shadow set.
  ///
  /// - Note: The layer's border may show ghosting effect when the shadow is animating. You may want to avoid adding a shadow to layers that have a border.
  /// Tip: You can use a dedicated transparent `LayerNode` as an underlay and apply the shadow to the underlay or use `dropShadow(color:opacity:radius:offset:path:)` to add a drop shadow underlay to the node.
  ///
  /// - Parameters:
  ///   - color: The themed color of the shadow. The color should be a solid color.
  ///   - opacity: The themed opacity of the shadow.
  ///   - radius: The themed radius of the shadow.
  ///   - offset: The themed offset of the shadow.
  ///   - path: The block to provide the path of the shadow. The block provides the renderable that the shadow is applied to.
  /// - Returns: A new node with the shadow set.
  func shadow(color: ThemedColor, opacity: Themed<CGFloat>, radius: Themed<CGFloat>, offset: Themed<CGSize>, path: ((Renderable) -> CGPath)?) -> some ComposeNode {
    ModifierNode(
      node: self,
      update: { item, context in
        switch context.updateType {
        case .insert,
             .refresh,
             .boundsChange: // the shadow path is affected by the layer's size, should update
          break
        case .scroll:
          return
        }

        let theme = context.contentView.theme

        let layer = item.layer
        let color = color.resolve(for: theme).cgColor
        let opacity = Float(opacity.resolve(for: theme))
        let radius: CGFloat = radius.resolve(for: theme)
        let offset: CGSize = offset.resolve(for: theme)

        layer.masksToBounds = false

        if let animationTiming = context.animationTiming {
          layer.animate(
            keyPath: "shadowColor",
            timing: animationTiming,
            from: { $0.presentation()?.shadowColor ?? $0.shadowColor ?? Color.clear.cgColor },
            to: { _ in color }
          )
          layer.animate(keyPath: "shadowOpacity", to: opacity, timing: animationTiming)
          layer.animate(keyPath: "shadowRadius", to: radius, timing: animationTiming)
          layer.animate(keyPath: "shadowOffset", to: offset, timing: animationTiming)
          let path = path?(item)
          layer.animate(
            keyPath: "shadowPath",
            timing: animationTiming,
            from: { $0.presentation()?.shadowPath ?? $0.shadowPath },
            to: { _ in path }
          )
        } else {
          layer.disableActions(for: "shadowColor", "shadowOpacity", "shadowRadius", "shadowOffset", "shadowPath") {
            layer.shadowColor = color
            layer.shadowOpacity = opacity
            layer.shadowRadius = radius
            layer.shadowOffset = offset
            layer.shadowPath = path?(item)
          }
        }
      },
      resetForReuse: { renderable in
        let layer = renderable.layer
        layer.disableActions(for: "shadowColor", "shadowOpacity", "shadowRadius", "shadowOffset", "shadowPath") {
          layer.shadowColor = layer.defaultShadowColor
          layer.shadowOpacity = 0
          layer.shadowRadius = 3
          layer.shadowOffset = CGSize(width: 0, height: -3)
          layer.shadowPath = nil
        }
      }
    )
  }

  /// Set the z-index of the node's renderables, controlling their stacking band.
  ///
  /// Renderables stack in bands by z-index: a renderable with a higher z-index renders above any renderable with a
  /// lower z-index, regardless of the items order. Within the same band, renderables stack in the items order.
  /// Renderables without a z-index are in band 0.
  ///
  /// The render pass computes each renderable layer's actual `zPosition` from the z-index.
  ///
  /// - Note: All renderables provided by the node will have the z-index set.
  /// - Note: The outermost z-index wins: `node.zIndex(2).zIndex(8)` uses 8.
  ///
  /// - Parameter zIndex: The z-index to set.
  /// - Returns: A new node with the z-index set.
  func zIndex(_ zIndex: CGFloat) -> some ComposeNode {
    ModifierNode(node: self, zIndex: zIndex)
  }

  /// Set whether the node's renderables are interactive.
  ///
  /// - Note: All renderables provided by the node will have the `isUserInteractionEnabled` set.
  ///
  /// - Parameter isEnabled: Whether the renderable is interactive.
  /// - Returns: A new node with the `isUserInteractionEnabled` set.
  func interactive(_ isEnabled: Bool = true) -> some ComposeNode {
    ModifierNode(
      node: self,
      update: { item, context in
        guard context.updateType.requiresFullUpdate, let view = item.view else {
          return
        }

        #if canImport(AppKit)
        view.ignoreHitTest = !isEnabled
        #endif

        #if canImport(UIKit)
        view.isUserInteractionEnabled = isEnabled
        #endif
      },
      resetForReuse: { renderable in
        guard let view = renderable.view else {
          return
        }
        #if canImport(AppKit)
        if view.ignoreHitTest != false {
          view.ignoreHitTest = false
        }
        #endif
        #if canImport(UIKit)
        if view.isUserInteractionEnabled != true {
          view.isUserInteractionEnabled = true
        }
        #endif
      }
    )
  }

  /// Set whether the node's renderables are rasterized.
  ///
  /// - Note: All renderables provided by the node will have the `shouldRasterize` set.
  ///
  /// - Parameter scale: The scale of the rasterized content. Specify `nil` to disable rasterization.
  /// - Returns: A new node with the rasterization set.
  func rasterize(_ scale: CGFloat?) -> some ComposeNode {
    ModifierNode(
      node: self,
      update: { item, context in
        guard context.updateType.requiresFullUpdate else {
          return
        }

        let layer = item.layer
        if let scale = scale {
          layer.shouldRasterize = true
          layer.rasterizationScale = scale
        } else {
          layer.shouldRasterize = false
          layer.rasterizationScale = 1
        }
      },
      resetForReuse: { renderable in
        let layer = renderable.layer
        if layer.shouldRasterize != false {
          layer.shouldRasterize = false
        }
        if layer.rasterizationScale != 1 {
          layer.rasterizationScale = 1
        }
      }
    )
  }
}

private extension CALayer {

  var defaultBorderColor: CGColor {
    CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
  }

  var defaultShadowColor: CGColor {
    CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
  }
}
