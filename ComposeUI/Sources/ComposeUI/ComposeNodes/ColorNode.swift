//
//  ColorNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit

/// A node that renders a solid color.
///
/// The node has a flexible size.
public struct ColorNode: ComposeNode {

  private let color: UIColor

  /// Initialize a color node with a color.
  ///
  /// - Parameter color: The color to render.
  public init(_ color: UIColor) {
    self.color = color
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.color)

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    size = containerSize
    return ComposeNodeSizing(width: .flexible, height: .flexible)
  }

  public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    let frame = CGRect(origin: .zero, size: size)
    guard visibleBounds.intersects(frame) else {
      return []
    }

    let layerItem = LayerItem<CALayer>(
      id: id,
      frame: frame,
      make: { context in
        let layer = CALayer()
        if let initialFrame = context.initialFrame {
          layer.frame = initialFrame
        }
        return layer
      },
      update: { layer, context in
        guard context.updateType.requiresFullUpdate else {
          return
        }

        let color = self.color.cgColor
        if let animationTiming = context.animationTiming {
          layer.animate(
            keyPath: "backgroundColor",
            timing: animationTiming,
            from: { $0.presentation()?.backgroundColor },
            to: { _ in color }
          )
        } else {
          layer.disableActions(for: "backgroundColor") {
            layer.backgroundColor = color
          }
        }
      }
    )

    return [layerItem.eraseToRenderableItem()]
  }
}
