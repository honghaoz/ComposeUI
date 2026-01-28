//
//  ComposeNode+TransformTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 1/28/26.
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

class ComposeNode_TransformTests: XCTestCase {

  func test_map_anyComposeNode() throws {
    var node: any ComposeNode = ViewNode()
      .map { node in
        node.background {
          ColorNode(.red)
        }
      }

    node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
    let renderableItems = node.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))
    let backgroundItem = try renderableItems.first.unwrap()

    let contentView = ComposeView()
    contentView.overrideTheme = .light
    let renderable = backgroundItem.make(RenderableMakeContext(initialFrame: .zero, contentView: contentView))
    let updateContext = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
    backgroundItem.update(renderable, updateContext)

    expect(renderable.layer.backgroundColor) == Color.red.cgColor
  }

  func test_map_sameType() throws {
    let baseNode = LabelNode("Hello")
    var base = baseNode
    _ = base.layout(containerSize: CGSize(width: 200, height: 50), context: ComposeNodeLayoutContext(scaleFactor: 2))
    let baseSize = base.size

    var updated = baseNode
      .map { node in
        node.font(.systemFont(ofSize: 28))
      }
    _ = updated.layout(containerSize: CGSize(width: 200, height: 50), context: ComposeNodeLayoutContext(scaleFactor: 2))
    let renderableItems = updated.renderableItems(in: CGRect(origin: .zero, size: CGSize(width: 200, height: 50)))
    let item = try renderableItems.first.unwrap()

    let contentView = ComposeView()
    contentView.overrideTheme = .light
    let renderable = item.make(RenderableMakeContext(initialFrame: .zero, contentView: contentView))
    let updateContext = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
    item.update(renderable, updateContext)

    let textView = try (renderable.view as? BaseTextView).unwrap()
    let font = textView.attributedString.attribute(.font, at: 0, effectiveRange: nil) as? Font
    try expect(font) == unwrap(Font.systemFont(ofSize: 28))
    expect(updated.size.height) > baseSize.height
  }
}
