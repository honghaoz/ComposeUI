//
//  ComposeNode+TransformTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 1/28/26.
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
