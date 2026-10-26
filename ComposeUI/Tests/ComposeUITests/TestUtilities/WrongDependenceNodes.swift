//
//  WrongDependenceNodes.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/24/26.
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

import ComposeUI

/// A node that picks a child of a height of 300 or 600 by its container's height, and returns the child's sizing, whose
/// dependence leaves out the height that this node reads, as an app's node that returns a child's sizing can.
struct HeightPickingNode: ComposeNode {

  var id: ComposeNodeId = .custom("HeightPickingNode")

  private var short = SpacerNode(height: 300)

  private var tall = SpacerNode(height: 600)

  private var isTall = false

  var size: CGSize {
    isTall ? tall.size : short.size
  }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    isTall = containerSize.height >= 150
    if isTall {
      return tall.layout(containerSize: containerSize, context: context)
    } else {
      return short.layout(containerSize: containerSize, context: context)
    }
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {}
}

/// A node that fills its container, whose sizing reports that its layout reads no length.
struct FillingNode: ComposeNode {

  var id: ComposeNodeId = .custom("FillingNode")

  private(set) var size: CGSize = .zero

  /// The node provides no items, so its render bounds stay the same at any size.
  var renderBounds: CGRect {
    .null
  }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    size = containerSize
    return ComposeNodeSizing(width: .flexible, height: .flexible, dependence: [])
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {}
}

/// A node of a fixed size without items, whose height sizing is fixed in a container less than 150 points tall and a
/// range in a taller one, and whose sizing reports that its layout reads no length.
struct SizingFlippingNode: ComposeNode {

  var id: ComposeNodeId = .custom("SizingFlippingNode")

  let size = CGSize(width: 50, height: 50)

  var renderBounds: CGRect {
    .null
  }

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    let height: ComposeNodeSizing.Sizing = containerSize.height < 150 ? .fixed(size.height) : .range(min: size.height, max: 100)
    return ComposeNodeSizing(width: .fixed(size.width), height: height, dependence: [])
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {}
}

/// A node of a fixed size whose items move down by a tenth of its container's height, whose sizing reports that its
/// layout reads no length.
struct MovingItemsNode: ComposeNode {

  var id: ComposeNodeId = .custom("MovingItemsNode")

  let size = CGSize(width: 50, height: 50)

  private(set) var renderBounds: CGRect = .null

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    renderBounds = CGRect(x: 0, y: containerSize.height / 10, width: size.width, height: size.height)
    return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height), dependence: [])
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {}
}
