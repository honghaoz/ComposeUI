//
//  FrameNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/7/25.
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

import ChouTiTest

@testable import ComposeUI

class FrameNodeTests: XCTestCase {

  // MARK: - FrameSize Tests

  func test_frameSize_equality() throws {
    // then: frame sizes are equal only for matching case and value
    expect(FrameSize.fixed(10)) == FrameSize.fixed(10)
    expect(FrameSize.fixed(10)) != FrameSize.fixed(20)
    expect(FrameSize.flexible) == FrameSize.flexible
    expect(FrameSize.intrinsic) == FrameSize.intrinsic
    expect(FrameSize.fixed(10)) != FrameSize.flexible
    expect(FrameSize.fixed(10)) != FrameSize.intrinsic
    expect(FrameSize.flexible) != FrameSize.intrinsic
  }

  // MARK: - Layout Tests

  func test_layout_fixed_fixed() throws {
    // given: a color node framed with fixed width and height
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ColorNode(.red).frame(width: .fixed(50), height: .fixed(30))

    // when: laying out in a 100x100 container
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the sizing and size are fixed
    expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .fixed(30))
    expect(node.size) == CGSize(width: 50, height: 30)
  }

  func test_layout_fixed_flexible() throws {
    // given: a color node framed with fixed width and flexible height
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ColorNode(.red).frame(width: .fixed(50), height: .flexible)

    // when: laying out in a 100x80 container
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 80), context: context)

    // then: the width is fixed and the height fills the container
    expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .flexible)
    expect(node.size) == CGSize(width: 50, height: 80)
  }

  func test_layout_fixed_intrinsic() throws {
    // given: an intrinsic size node framed with fixed width and intrinsic height
    let context = ComposeNodeLayoutContext(scaleFactor: 1)

    var node = FixedSizeNode(size: CGSize(width: 60, height: 40))
      .frame(width: .fixed(50), height: .intrinsic)

    // when: laying out in a 100x100 container
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the width is fixed and the height is the intrinsic height
    expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .fixed(40))
    expect(node.size) == CGSize(width: 50, height: 40)
  }

  func test_layout_flexible_fixed() throws {
    // given: a color node framed with flexible width and fixed height
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ColorNode(.red).frame(width: .flexible, height: .fixed(30))

    // when: laying out in an 80x100 container
    let sizing = node.layout(containerSize: CGSize(width: 80, height: 100), context: context)

    // then: the width fills the container and the height is fixed
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(30))
    expect(node.size) == CGSize(width: 80, height: 30)
  }

  func test_layout_flexible_flexible() throws {
    // given: a color node framed with flexible width and height
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ColorNode(.red).frame(width: .flexible, height: .flexible)

    // when: laying out in an 80x60 container
    let sizing = node.layout(containerSize: CGSize(width: 80, height: 60), context: context)

    // then: the node fills the container
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
    expect(node.size) == CGSize(width: 80, height: 60)
  }

  func test_layout_flexible_intrinsic() throws {
    // given: an intrinsic size node framed with flexible width and intrinsic height
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = FixedSizeNode(size: CGSize(width: 60, height: 40)).frame(width: .flexible, height: .intrinsic)

    // when: laying out in a 100x100 container
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the width fills the container and the height is the intrinsic height
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(40))
    expect(node.size) == CGSize(width: 100, height: 40)
  }

  func test_layout_intrinsic_fixed() throws {
    // given: an intrinsic size node framed with intrinsic width and fixed height
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = FixedSizeNode(size: CGSize(width: 60, height: 40)).frame(width: .intrinsic, height: .fixed(50))

    // when: laying out in a 100x100 container
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the width is the intrinsic width and the height is fixed
    expect(sizing) == ComposeNodeSizing(width: .fixed(60), height: .fixed(50))
    expect(node.size) == CGSize(width: 60, height: 50)
  }

  func test_layout_intrinsic_flexible() throws {
    // given: an intrinsic size node framed with intrinsic width and flexible height
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = FixedSizeNode(size: CGSize(width: 60, height: 40)).frame(width: .intrinsic, height: .flexible)

    // when: laying out in a 100x80 container
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 80), context: context)

    // then: the width is the intrinsic width and the height fills the container
    expect(sizing) == ComposeNodeSizing(width: .fixed(60), height: .flexible)
    expect(node.size) == CGSize(width: 60, height: 80)
  }

  func test_layout_intrinsic_intrinsic() throws {
    // given: an intrinsic size node framed with intrinsic width and height
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = FixedSizeNode(size: CGSize(width: 60, height: 40)).frame(width: .intrinsic, height: .intrinsic)

    // when: laying out in a 100x100 container
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the size is the intrinsic size
    expect(sizing) == ComposeNodeSizing(width: .fixed(60), height: .fixed(40))
    expect(node.size) == CGSize(width: 60, height: 40)
  }

  // MARK: - RenderableItems Tests

  func test_renderableItems_center_alignment() throws {
    // given: a laid out fixed size node framed with center alignment
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = FixedSizeNode(size: CGSize(width: 10, height: 20)).frame(width: 40, height: 30, alignment: .center)
    _ = node.layout(containerSize: CGSize(width: 100, height: 80), context: context)

    // when: requesting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 80))

    // then: the child item is centered in the frame
    expect(items.count) == 1

    let item = items[0]
    expect(item.id.id) == "F|FixedSizeNode"
    expect(item.frame) == CGRect(x: 15, y: 5, width: 10, height: 20)
  }

  func test_renderableItems_topLeft_alignment() throws {
    // given: a laid out fixed size node framed with top left alignment
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = FixedSizeNode(size: CGSize(width: 10, height: 20)).frame(width: 40, height: 30, alignment: .topLeft)
    _ = node.layout(containerSize: CGSize(width: 100, height: 80), context: context)

    // when: requesting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 80))

    // then: the child item is aligned to the top left of the frame
    expect(items.count) == 1

    let item = items[0]
    expect(item.id.id) == "F|FixedSizeNode"
    expect(item.frame) == CGRect(x: 0, y: 0, width: 10, height: 20)
  }

  func test_renderableItems_bottomRight_alignment() throws {
    // given: a laid out fixed size node framed with bottom right alignment
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = FixedSizeNode(size: CGSize(width: 10, height: 20)).frame(width: 40, height: 30, alignment: .bottomRight)
    _ = node.layout(containerSize: CGSize(width: 100, height: 80), context: context)

    // when: requesting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 80))

    // then: the child item is aligned to the bottom right of the frame
    expect(items.count) == 1

    let item = items[0]
    expect(item.id.id) == "F|FixedSizeNode"
    expect(item.frame) == CGRect(x: 30, y: 10, width: 10, height: 20)
  }

  func test_renderableItemsBoundingRect_overflowChild() throws {
    // given: a child node bigger than the frame node, i.e. the child node overflows the frame
    let context = ComposeNodeLayoutContext(scaleFactor: 1)

    var node = FixedSizeNode(size: CGSize(width: 30, height: 30)).frame(width: 10, height: 10, alignment: .center)

    // when: laying out in a 100x100 container
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the bounding rect includes the overflowing child
    expect(node.size) == CGSize(width: 10, height: 10)
    expect(node.renderableItemsBoundingRect) == CGRect(x: -10, y: -10, width: 30, height: 30)
  }

  func test_renderableItemsBoundingRect_noRenderableItemsChild() throws {
    // given: a framed child node with no renderable items
    let context = ComposeNodeLayoutContext(scaleFactor: 1)

    var node = Spacer().frame(width: 10, height: 10)

    // when: laying out in a 100x100 container
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the bounding rect is null
    expect(node.renderableItemsBoundingRect.isNull) == true
  }

  // MARK: - Frame Modifier Tests

  func test_frame_frameSize_frameSize() throws {
    // given: a node framed with FrameSize width and FrameSize height
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = FixedSizeNode(size: CGSize(width: 10, height: 20)).frame(width: .fixed(50), height: .flexible)

    // when: laying out in a 100x100 container
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the frame sizes are applied
    expect(node.size) == CGSize(width: 50, height: 100)
  }

  func test_frame_cgFloat_frameSize() throws {
    // given: a node framed with CGFloat width and FrameSize height
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = FixedSizeNode(size: CGSize(width: 10, height: 20)).frame(width: 50, height: .flexible)

    // when: laying out in a 100x100 container
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the frame sizes are applied
    expect(node.size) == CGSize(width: 50, height: 100)
  }

  func test_frame_frameSize_cgFloat() throws {
    // given: a node framed with FrameSize width and CGFloat height
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = FixedSizeNode(size: CGSize(width: 10, height: 20)).frame(width: .fixed(50), height: 30)

    // when: laying out in a 100x100 container
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the frame sizes are applied
    expect(node.size) == CGSize(width: 50, height: 30)
  }

  func test_frame_cgFloat_cgFloat() throws {
    // given: a color node framed with CGFloat width and height
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ColorNode(.red).frame(width: 50, height: 30)

    // when: laying out in a 100x100 container
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the frame sizes are applied
    expect(node.size) == CGSize(width: 50, height: 30)
  }

  func test_frame_cgSize() throws {
    // given: a color node framed with a CGSize
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ColorNode(.red).frame(CGSize(width: 60, height: 40))

    // when: laying out in a 100x100 container
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the frame size is applied
    expect(node.size) == CGSize(width: 60, height: 40)
  }

  func test_frame_cgFloat_square() throws {
    // given: a color node framed with a square CGFloat size
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ColorNode(.red).frame(50)

    // when: laying out in a 100x100 container
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the square frame size is applied
    expect(node.size) == CGSize(width: 50, height: 50)
  }

  func test_frame_frameSize_intrinsic_optimization() throws {
    // given: a color node
    let baseNode = ColorNode(.red)

    // when: applying a frame with intrinsic size for both dimensions
    let framedNode = baseNode.frame(.intrinsic)

    // then: should return the original node when both dimensions are intrinsic
    expect(String(describing: framedNode).contains("FrameNode")) == false
  }

  func test_frame_frameSize_non_intrinsic() throws {
    // given: a color node
    let baseNode = ColorNode(.red)

    // when: applying a frame with a fixed size
    let framedNode = baseNode.frame(.fixed(50))

    // then: should create a FrameNode when not both intrinsic
    expect(String(describing: framedNode).contains("FrameNode")) == true
  }

  func test_width_modifier() throws {
    // given: a color node with a fixed width modifier
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ColorNode(.red).width(60)

    // when: laying out in a 100x80 container
    _ = node.layout(containerSize: CGSize(width: 100, height: 80), context: context)

    // then: the width is fixed and the height fills the container
    expect(node.size) == CGSize(width: 60, height: 80)
  }

  func test_height_modifier() throws {
    // given: a color node with a fixed height modifier
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ColorNode(.red).height(40)

    // when: laying out in a 100x80 container
    _ = node.layout(containerSize: CGSize(width: 100, height: 80), context: context)

    // then: the height is fixed and the width fills the container
    expect(node.size) == CGSize(width: 100, height: 40)
  }

  func test_alignment_modifier() throws {
    // given: a laid out fixed size node with a top right alignment modifier
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = FixedSizeNode(size: CGSize(width: 10, height: 20)).alignment(.topRight)
    _ = node.layout(containerSize: CGSize(width: 100, height: 80), context: context)

    // when: requesting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 80))

    // then: the child item is aligned to the top right
    expect(items.count) == 1

    let item = items[0]
    expect(item.frame) == CGRect(x: 90, y: 0, width: 10, height: 20)
  }

  // MARK: - Complex Tests

  func test_frame_with_child_larger_than_frame() throws {
    // given: a laid out frame node with a child larger than the frame
    let context = ComposeNodeLayoutContext(scaleFactor: 1)

    var node = FixedSizeNode(size: CGSize(width: 80, height: 60)).frame(width: 40, height: 30, alignment: .center)
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when: requesting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))

    // then: the child item overflows the frame, centered
    expect(items.count) == 1

    let item = items[0]
    expect(item.frame) == CGRect(x: -20, y: -15, width: 80, height: 60)
  }

  func test_multiple_frame_modifiers() throws {
    // given: a color node with two nested frame modifiers
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ColorNode(.red)
      .frame(width: 60, height: 40)
      .frame(width: 80, height: 50, alignment: .topLeft)

    // when: laying out in a 100x100 container
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // then: the outer frame determines the size
    expect(node.size) == CGSize(width: 80, height: 50) // outer frame wins

    // when: requesting renderable items
    let items = node.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 100))

    // then: a single item with both frame node ids is provided
    expect(items.count) == 1

    let item = items[0]
    expect(item.id.id) == "F|F|C" // Multiple frame node IDs
  }
}

private struct FixedSizeNode: ComposeNode {

  var id: ComposeNodeId = .custom("FixedSizeNode")

  let size: CGSize

  init(size: CGSize) {
    self.size = size
  }

  func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height))
  }

  func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    let layerItem = LayerItem<CALayer>(
      id: id,
      frame: CGRect(origin: .zero, size: size),
      make: { _ in CALayer() },
      update: { _, _ in }
    )
    return [layerItem.eraseToRenderableItem()]
  }
}
