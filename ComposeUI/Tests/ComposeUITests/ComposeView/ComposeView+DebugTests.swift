//
//  ComposeView+DebugTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/15/26.
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

class ComposeView_DebugTests: XCTestCase {

  func test_debugBuild_runsTheSanityChecks() {
    // then: the tests' debug build runs the render pass's sanity checks, which the benchmark builds leave out
    expect(ComposeView.runsSanityChecks) == true
  }

  func test_renderDidFinish_mapsTheRenderableItemsByTheirIds() throws {
    // given: a compose view showing two nodes, with a debug handler that records the finished render pass
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.setContent {
      VStack {
        LayerNode().fixedId("first").frame(width: 100, height: 10)
        ColorNode(.red).fixedId("second").frame(width: 100, height: 10)
      }
    }
    var renderedIds: [ComposeNodeId] = []
    var renderedItemMap: [ComposeNodeId: RenderableItem] = [:]
    view.debug { _, event in
      switch event {
      case .renderDidFinish(let ids, let renderableItemMap, _):
        renderedIds = ids
        renderedItemMap = renderableItemMap
      default:
        break
      }
    }

    // when: the view renders
    view.refresh(animated: false)

    // then: the item map has the rendered items, each under its own id
    expect(renderedIds.map(\.id)) == ["first", "second"]
    expect(renderedItemMap.count) == 2
    for id in renderedIds {
      let item = try renderedItemMap[id].unwrap()
      expect(item.id.id) == id.id
    }
  }
}
