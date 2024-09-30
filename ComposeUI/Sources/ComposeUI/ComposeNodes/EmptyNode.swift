//
//  EmptyNode.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
//

import UIKit

extension Compose {

  public struct EmptyNode: ComposeNode {

    public init() {}

    // MARK: - ComposeNode

    public private(set) var size: CGSize = .zero

    public mutating func layout(containerSize: CGSize) -> ComposeNodeSizing {
      size = containerSize
      return ComposeNodeSizing(width: .flexible, height: .flexible)
    }

    public func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>] {
      return []
    }
  }
}
