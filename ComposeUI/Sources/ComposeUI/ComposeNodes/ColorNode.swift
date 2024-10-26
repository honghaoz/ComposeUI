//
//  ColorNode.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit

public typealias Color = ColorNode

public struct ColorNode: ComposeNode {

  private let color: UIColor

  public init(_ color: UIColor) {
    self.color = color
  }

  // MARK: - ComposeNode

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize) -> ComposeNodeSizing {
    size = containerSize
    return ComposeNodeSizing(width: .flexible, height: .flexible)
  }

  public func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>] {
    let frame = CGRect(origin: .zero, size: size)
    guard visibleBounds.actuallyIntersects(frame) else {
      return []
    }

    let viewItem = ViewItem<UIView>(
      id: ComposeNodeId.color.rawValue,
      frame: frame,
      update: { view in
        view.backgroundColor = color
      }
    )

    return [viewItem]
  }
}
