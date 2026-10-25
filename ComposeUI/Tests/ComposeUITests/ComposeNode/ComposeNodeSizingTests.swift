//
//  ComposeNodeSizingTests.swift
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

import ChouTiTest

@testable import ComposeUI
import SwiftUI

class ComposeNodeSizingTests: XCTestCase {

  func test_init_dependence() {
    // given: a sizing made without a dependence, as a node that doesn't report one makes it
    let sizing = ComposeNodeSizing(width: .fixed(10), height: .flexible)

    // then: it depends on both lengths, which is correct for any layout
    expect(sizing.dependence) == [.width, .height]

    // given: a sizing made with a dependence
    let widthSizing = ComposeNodeSizing(width: .fixed(10), height: .flexible, dependence: .width)

    // then: it has that dependence
    expect(widthSizing.dependence) == .width
  }

  func test_equality_ignoresDependence() {
    // given: two sizings of the same behaviors, made by layouts that depended on different lengths
    let sizing = ComposeNodeSizing(width: .fixed(10), height: .flexible, dependence: .width)
    let otherSizing = ComposeNodeSizing(width: .fixed(10), height: .flexible, dependence: [])

    // then: they're equal and hash the same
    expect(sizing) == otherSizing
    expect(sizing.hashValue) == otherSizing.hashValue

    // then: sizings of another width or height behavior aren't equal
    expect(sizing) != ComposeNodeSizing(width: .fixed(20), height: .flexible, dependence: .width)
    expect(sizing) != ComposeNodeSizing(width: .fixed(10), height: .fixed(10), dependence: .width)
  }

  func test_dependence_isSame_comparesTheLengthsItContains() {
    // given: a container size, and sizes that differ from it in the width, the height, or both
    let size = CGSize(width: 100, height: 200)
    let otherWidth = CGSize(width: 150, height: 200)
    let otherHeight = CGSize(width: 100, height: 250)
    let otherWidthAndHeight = CGSize(width: 150, height: 250)

    // then: a layout that depended on no length is the same at any size
    let none: ComposeNodeSizing.Dependence = []
    expect(none.isSame(size, as: size)) == true
    expect(none.isSame(size, as: otherWidthAndHeight)) == true

    // then: a layout that depended on the width compares the widths alone
    let width: ComposeNodeSizing.Dependence = .width
    expect(width.isSame(size, as: otherHeight)) == true
    expect(width.isSame(size, as: otherWidth)) == false
    expect(width.isSame(size, as: otherWidthAndHeight)) == false

    // then: a layout that depended on the height compares the heights alone
    let height: ComposeNodeSizing.Dependence = .height
    expect(height.isSame(size, as: otherWidth)) == true
    expect(height.isSame(size, as: otherHeight)) == false
    expect(height.isSame(size, as: otherWidthAndHeight)) == false

    // then: a layout that depended on both lengths compares both
    let widthAndHeight: ComposeNodeSizing.Dependence = [.width, .height]
    expect(widthAndHeight.isSame(size, as: size)) == true
    expect(widthAndHeight.isSame(size, as: otherWidth)) == false
    expect(widthAndHeight.isSame(size, as: otherHeight)) == false
  }

  func test_dependence_eachBuiltInNodeLaysOutTheSame_atSizesThatDifferOnlyInLengthsItDoesntRead() throws {
    // every built-in node, in each of its modes, has a row here, so that the dependence it reports is checked against
    // its layout, including the nodes that report both lengths, whose rows check a report narrowed later
    let font = try unwrap(Font(name: "HelveticaNeue", size: 18))
    let wrappingText = "A text long enough to wrap in a narrow container"
    let textNode = TextNode(wrappingText, font: font)
    var nodes: [(name: String, node: any ComposeNode)] = [
      ("text", textNode),
      ("text of a flexible width", textNode.fixedSize(width: false, height: true)),
      ("text of a flexible height", textNode.fixedSize(width: true, height: false)),
      ("flexible text", textNode.flexibleSize()),
      ("label", LabelNode("A label")),
      ("multi-line label", LabelNode(wrappingText).numberOfLines(0)),
      ("spacer", SpacerNode()),
      ("spacer of a width", SpacerNode(width: 10)),
      ("spacer of a height", SpacerNode(height: 10)),
      ("spacer of a size", SpacerNode(width: 10, height: 20)),
      ("color", ColorNode(.red)),
      ("empty", EmptyNode()),
      ("layer", LayerNode()),
      ("layer of its size", LayerNode(intrinsicSize: { _ in CGSize(width: 40, height: 20) }).fixedSize()),
      ("layer of its width", LayerNode(intrinsicSize: { _ in CGSize(width: 40, height: 20) }).fixedSize(width: true, height: false)),
      ("layer of its height", LayerNode(intrinsicSize: { _ in CGSize(width: 40, height: 20) }).fixedSize(width: false, height: true)),
      ("view", ViewNode<ComposeUI.View>()),
      ("view of its size", ViewNode<ComposeUI.View>(intrinsicSize: { _ in CGSize(width: 40, height: 20) }).fixedSize()),
      ("view of its width", ViewNode<ComposeUI.View>(intrinsicSize: { _ in CGSize(width: 40, height: 20) }).fixedSize(width: true, height: false)),
      ("view of its height", ViewNode<ComposeUI.View>(intrinsicSize: { _ in CGSize(width: 40, height: 20) }).fixedSize(width: false, height: true)),
      ("SwiftUI view", SwiftUIViewNode { SwiftUI.Color.red.frame(width: 80, height: 50) }),
      ("SwiftUI view of its size", SwiftUIViewNode { SwiftUI.Color.red.frame(width: 80, height: 50) }.fixedSize()),
      ("SwiftUI view of its width", SwiftUIViewNode { SwiftUI.Color.red.frame(width: 80, height: 50) }.fixedSize(width: true, height: false)),
      ("SwiftUI view of its height", SwiftUIViewNode { SwiftUI.Color.red.frame(width: 80, height: 50) }.fixedSize(width: false, height: true)),
      ("drop shadow", DropShadowNode(color: .black, opacity: 0.5, radius: 4, offset: .zero, path: { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) })),
      ("inner shadow", InnerShadowNode(color: .black, opacity: 0.5, radius: 4, offset: .zero, path: { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) })),
      ("padding around text", textNode.padding(8)),
      ("padding around a color", ColorNode(.red).padding(8)),
      ("overlay on text", textNode.overlay { ColorNode(.red) }),
      ("underlay under text", textNode.underlay { ColorNode(.red) }),
      ("offset text", textNode.offset(x: 4, y: 4)),
      ("text with an update block", textNode.onUpdate { _, _ in }),
      ("text with a tap handler", textNode.onTap { _ in }),
      ("button of text", ButtonNode(content: { _ in TextNode(wrappingText, font: font) }, onTap: {})),
      ("vertical stack of fixed rows", VStack {
        LayerNode().frame(width: 50, height: 20)
        LayerNode().frame(width: 60, height: 20)
      }),
      ("vertical stack of text rows", VStack {
        textNode
        textNode
      }),
      ("vertical stack with a spacer", VStack {
        textNode
        SpacerNode()
      }),
      ("list in a flexible stack", VStack {
        LabelNode("Header")
        VStack {
          textNode
          textNode
          SpacerNode()
        }
      }),
      ("horizontal stack of fixed columns", HStack {
        LayerNode().frame(width: 50, height: 20)
        LayerNode().frame(width: 60, height: 30)
      }),
      ("horizontal stack with text", HStack {
        LayerNode().frame(width: 30, height: 30)
        textNode
      }),
      ("horizontal stack with a spacer", HStack {
        textNode
        SpacerNode()
      }),
      ("layered stack of text and a fixed node", ZStack {
        textNode
        LayerNode().frame(width: 50, height: 50)
      }),
      ("layered stack with a color", ZStack {
        textNode
        ColorNode(.red)
      }),
      ("compose view of text", ComposeViewNode { textNode }),
      ("compose view of text, of a flexible width", ComposeViewNode { textNode }.fixedSize(width: false, height: true)),
      ("compose view of text, of a flexible height", ComposeViewNode { textNode }.fixedSize(width: true, height: false)),
      ("flexible compose view of text", ComposeViewNode { textNode }.flexibleSize()),
    ]
    for width in [FrameSize.fixed(50), .flexible, .intrinsic] {
      for height in [FrameSize.fixed(30), .flexible, .intrinsic] {
        nodes.append(("frame of \(width) by \(height) around text", textNode.frame(width: width, height: height)))
        nodes.append(("frame of \(width) by \(height) around a color", ColorNode(.red).frame(width: width, height: height)))
      }
    }

    let containerSize = CGSize(width: 200, height: 300)
    let renderBounds = CGRect(x: -1000, y: -1000, width: 4000, height: 4000)
    for (name, node) in nodes {
      // given: a built-in node, laid out
      var node = node
      let sizing = node.layout(containerSize: containerSize, context: ComposeNodeLayoutContext(scaleFactor: 2))
      let size = node.size
      let itemFrames = node.renderableItems(in: renderBounds).map(\.frame)

      // a smaller and a larger value of each length that the layout doesn't read
      let widths: [CGFloat] = sizing.dependence.contains(.width) ? [containerSize.width] : [40, 1000]
      let heights: [CGFloat] = sizing.dependence.contains(.height) ? [containerSize.height] : [40, 1000]
      for width in widths {
        for height in heights where CGSize(width: width, height: height) != containerSize {
          // when: laying it out again at a size that differs only in those lengths, in a new pass, so that no stack
          // returns its earlier layout
          let otherSizing = node.layout(containerSize: CGSize(width: width, height: height), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: it lays out the same
          let message = "\(name) at \(width) by \(height)"
          expect(otherSizing, message) == sizing
          expect(node.size, message) == size
          expect(node.renderableItems(in: renderBounds).map(\.frame), message) == itemFrames
        }
      }
    }
  }
}
