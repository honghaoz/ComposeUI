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
    // every built-in node, in each of its modes, has a row here with the dependence it reports, so that a report that's
    // too narrow, which keeps a stale layout, or too wide, which lays out again for nothing, fails
    let font = try unwrap(Font(name: "HelveticaNeue", size: 18))
    let wrappingText = "A text long enough to wrap in a narrow container"
    // a text of its own size, which wraps in the container's width, so its layout reads the width alone
    let text = TextNode(wrappingText, font: font).fixedSize()
    let singleLineText = TextNode(wrappingText, font: font).numberOfLines(1)
    let fixedNode = LayerNode().frame(width: 50, height: 20)
    let color = ColorNode(.red)
    let intrinsicSize: (CGSize) -> CGSize = { _ in CGSize(width: 40, height: 20) }
    let path: (CGSize) -> CGPath = { CGPath(rect: CGRect(origin: .zero, size: $0), transform: nil) }
    let both: ComposeNodeSizing.Dependence = [.width, .height]
    let rows: [(name: String, node: any ComposeNode, dependence: ComposeNodeSizing.Dependence)] = [
      ("text", text, .width),
      ("text of a flexible width", text.fixedSize(width: false, height: true), .width),
      ("text of a flexible height", text.fixedSize(width: true, height: false), both),
      ("flexible text", text.flexibleSize(), both),
      ("single-line text", singleLineText.fixedSize(), []),
      ("single-line text of a flexible width", singleLineText.fixedSize(width: false, height: true), .width),
      ("single-line text of a flexible height", singleLineText.fixedSize(width: true, height: false), .height),
      ("flexible single-line text", singleLineText.flexibleSize(), both),
      ("label", LabelNode("A label"), []),
      ("multi-line label", LabelNode(wrappingText).numberOfLines(0), .width),
      ("spacer", SpacerNode(), both),
      ("spacer of a width", SpacerNode(width: 10), .height),
      ("spacer of a height", SpacerNode(height: 10), .width),
      ("spacer of a size", SpacerNode(width: 10, height: 20), []),
      ("color", color, both),
      ("empty", EmptyNode(), both),
      ("layer", LayerNode(), both),
      ("layer of its size", LayerNode(intrinsicSize: intrinsicSize).fixedSize(), both),
      ("layer of its width", LayerNode(intrinsicSize: intrinsicSize).fixedSize(width: true, height: false), both),
      ("layer of its height", LayerNode(intrinsicSize: intrinsicSize).fixedSize(width: false, height: true), both),
      ("view", ViewNode<ComposeUI.View>(), both),
      ("view of its size", ViewNode<ComposeUI.View>(intrinsicSize: intrinsicSize).fixedSize(), both),
      ("view of its width", ViewNode<ComposeUI.View>(intrinsicSize: intrinsicSize).fixedSize(width: true, height: false), both),
      ("view of its height", ViewNode<ComposeUI.View>(intrinsicSize: intrinsicSize).fixedSize(width: false, height: true), both),
      ("SwiftUI view", SwiftUIViewNode { SwiftUI.Color.red.frame(width: 80, height: 50) }, both),
      ("SwiftUI view of its size", SwiftUIViewNode { SwiftUI.Color.red.frame(width: 80, height: 50) }.fixedSize(), both),
      ("SwiftUI view of its width", SwiftUIViewNode { SwiftUI.Color.red.frame(width: 80, height: 50) }.fixedSize(width: true, height: false), both),
      ("SwiftUI view of its height", SwiftUIViewNode { SwiftUI.Color.red.frame(width: 80, height: 50) }.fixedSize(width: false, height: true), both),
      ("drop shadow", DropShadowNode(color: .black, opacity: 0.5, radius: 4, offset: .zero, path: path), both),
      ("inner shadow", InnerShadowNode(color: .black, opacity: 0.5, radius: 4, offset: .zero, path: path), both),
      ("padding around text", text.padding(8), .width),
      ("padding around a fixed node", fixedNode.padding(8), []),
      ("padding around a color", color.padding(8), both),
      ("overlay on text", text.overlay { color }, .width),
      ("underlay under text", text.underlay { color }, .width),
      ("offset text", text.offset(x: 4, y: 4), .width),
      ("text with an update block", text.onUpdate { _, _ in }, .width),
      ("text with a tap handler", text.onTap { _ in }, .width),
      ("button of text", ButtonNode(content: { _ in text }, onTap: {}), .width),
      ("vertical stack of fixed rows", VStack {
        fixedNode
        fixedNode
      }, []),
      ("vertical stack of text rows", VStack {
        text
        text
      }, .width),
      ("vertical stack with a spacer", VStack {
        text
        SpacerNode()
      }, both),
      ("list in a flexible stack", VStack {
        LabelNode("Header")
        VStack {
          text
          text
          SpacerNode()
        }
      }, both),
      ("horizontal stack of fixed columns", HStack {
        fixedNode
        fixedNode
      }, []),
      ("horizontal stack with text", HStack {
        fixedNode
        text
      }, .width),
      ("horizontal stack with a spacer", HStack {
        text
        SpacerNode()
      }, .width),
      ("layered stack of text and a fixed node", ZStack {
        text
        fixedNode
      }, .width),
      ("layered stack with a color", ZStack {
        text
        color
      }, both),
      ("compose view of text", ComposeViewNode { text }, .width),
      ("compose view of text, of a flexible width", ComposeViewNode { text }.fixedSize(width: false, height: true), .width),
      ("compose view of text, of a flexible height", ComposeViewNode { text }.fixedSize(width: true, height: false), both),
      ("compose view of a fixed node", ComposeViewNode { fixedNode }, []),
      ("compose view of a fixed node, of a flexible width", ComposeViewNode { fixedNode }.fixedSize(width: false, height: true), .width),
      ("compose view of a fixed node, of a flexible height", ComposeViewNode { fixedNode }.fixedSize(width: true, height: false), .height),
      ("flexible compose view", ComposeViewNode { fixedNode }.flexibleSize(), both),
      ("frame of a fixed size around text", text.frame(width: .fixed(50), height: .fixed(30)), []),
      ("frame of a fixed width and a flexible height around text", text.frame(width: .fixed(50), height: .flexible), .height),
      ("frame of a fixed width and the text's height", text.frame(width: .fixed(50), height: .intrinsic), []),
      ("frame of a flexible width and a fixed height around text", text.frame(width: .flexible, height: .fixed(30)), .width),
      ("flexible frame around text", text.frame(width: .flexible, height: .flexible), both),
      ("frame of a flexible width and the text's height", text.frame(width: .flexible, height: .intrinsic), .width),
      ("frame of the text's width and a fixed height", text.frame(width: .intrinsic, height: .fixed(30)), .width),
      ("frame of the text's width and a flexible height", text.frame(width: .intrinsic, height: .flexible), both),
      ("frame of the text's size", text.frame(width: .intrinsic, height: .intrinsic), .width),
      ("frame of a fixed size around a color", color.frame(width: .fixed(50), height: .fixed(30)), []),
      ("frame of a fixed width and a flexible height around a color", color.frame(width: .fixed(50), height: .flexible), .height),
      ("frame of a fixed width and the color's height", color.frame(width: .fixed(50), height: .intrinsic), .height),
      ("frame of a flexible width and a fixed height around a color", color.frame(width: .flexible, height: .fixed(30)), .width),
      ("flexible frame around a color", color.frame(width: .flexible, height: .flexible), both),
      ("frame of a flexible width and the color's height", color.frame(width: .flexible, height: .intrinsic), both),
      ("frame of the color's width and a fixed height", color.frame(width: .intrinsic, height: .fixed(30)), .width),
      ("frame of the color's width and a flexible height", color.frame(width: .intrinsic, height: .flexible), both),
      ("frame of the color's size", color.frame(width: .intrinsic, height: .intrinsic), both),
    ]

    let containerSize = CGSize(width: 200, height: 300)
    let renderBounds = CGRect(x: -1000, y: -1000, width: 4000, height: 4000)
    for (name, node, expectedDependence) in rows {
      // given: a built-in node, laid out
      var node = node
      let sizing = node.layout(containerSize: containerSize, context: ComposeNodeLayoutContext(scaleFactor: 2))
      let size = node.size
      let itemFrames = node.renderableItems(in: renderBounds).map(\.frame)

      // then: it reports the lengths that a node of its kind and mode reads
      expect(sizing.dependence, name) == expectedDependence

      // a smaller and a larger value of each length that the layout doesn't read
      let widths: [CGFloat] = expectedDependence.contains(.width) ? [containerSize.width] : [40, 1000]
      let heights: [CGFloat] = expectedDependence.contains(.height) ? [containerSize.height] : [40, 1000]
      for width in widths {
        for height in heights where CGSize(width: width, height: height) != containerSize {
          // when: laying it out again at a size that differs only in those lengths, in a new pass, so that no stack
          // returns its earlier layout
          let otherSizing = node.layout(containerSize: CGSize(width: width, height: height), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: it lays out the same, and reports the same lengths
          let message = "\(name) at \(width) by \(height)"
          expect(otherSizing, message) == sizing
          expect(otherSizing.dependence, message) == expectedDependence
          expect(node.size, message) == size
          expect(node.renderableItems(in: renderBounds).map(\.frame), message) == itemFrames
        }
      }
    }
  }
}
