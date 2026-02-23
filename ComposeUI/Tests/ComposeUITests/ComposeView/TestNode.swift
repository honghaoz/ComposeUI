//
//  TestNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
//

import Foundation
import ComposeUI

struct TestNode: ComposeNode {

  final class State {
    var layoutCount = 0
    var renderCount = 0
  }

  private var state: State

  init(state: State) {
    self.state = state
  }

  var id: ComposeNodeId = .custom("test", isFixed: false)

  var size: CGSize = .zero

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    state.layoutCount += 1
    size = containerSize
    return ComposeNodeSizing(width: .flexible, height: .flexible)
  }

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    state.renderCount += 1
    return []
  }
}
