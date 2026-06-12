//
//  RenderableItemsProbeNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 6/11/26.
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

import CoreGraphics
import QuartzCore

import ComposeUI

/// A fixed size node that tracks `renderableItems(in:)` calls, for testing renderable items culling.
struct RenderableItemsProbeNode: ComposeNode {

  final class State {

    /// The number of times `renderableItems(in:)` is called.
    var renderableItemsCallCount = 0
  }

  private let state: State
  private let fixedSize: CGSize

  init(state: State, size: CGSize) {
    self.state = state
    self.fixedSize = size
  }

  // MARK: - ComposeNode

  var id: ComposeNodeId = .custom("probe", isFixed: false)

  private(set) var size: CGSize = .zero

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    size = fixedSize
    return ComposeNodeSizing(width: .fixed(fixedSize.width), height: .fixed(fixedSize.height))
  }

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    state.renderableItemsCallCount += 1

    let frame = CGRect(origin: .zero, size: size)
    guard visibleBounds.intersects(frame) else {
      return []
    }

    let layerItem = LayerItem<CALayer>(
      id: id,
      frame: frame,
      make: { _ in CALayer() },
      update: { _, _ in }
    )

    return [layerItem.eraseToRenderableItem()]
  }
}
