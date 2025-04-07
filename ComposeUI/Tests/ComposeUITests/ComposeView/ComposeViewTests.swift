//
//  ComposeViewTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/13/24.
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

class ComposeViewTests: XCTestCase {

  private var contentView: ComposeView!

  override func setUp() {
    super.setUp()
    contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
  }

  func test_defaultContent() {
    let contentView = ComposeView()
    expect("\(contentView.content)") == "EmptyNode(id: ComposeUI.ComposeNodeId(id: \"empty\", isFixed: false), size: (0.0, 0.0))"
  }

  func test_centerContent() {
    // when content size is smaller than the bounds size
    do {
      let view = BaseView()
      contentView.setContent {
        ViewNode(view)
          .flexibleSize()
          .frame(width: 50, height: 80)
      }
      contentView.refresh(animated: false)

      expect(contentView.contentSize) == CGSize(width: 100, height: 100)
      expect(view.frame) == CGRect(x: 25, y: 10, width: 50, height: 80)
    }

    // when content width is smaller than the bounds width
    do {
      let view = BaseView()
      contentView.setContent {
        ViewNode(view)
          .flexibleSize()
          .frame(width: 50, height: 120)
      }
      contentView.refresh(animated: false)

      expect(contentView.contentSize) == CGSize(width: 100, height: 120)
      expect(view.frame) == CGRect(x: 25, y: 0, width: 50, height: 120)
    }

    // when content height is smaller than the bounds height
    do {
      let view = BaseView()
      contentView.setContent {
        ViewNode(view)
          .flexibleSize()
          .frame(width: 120, height: 80)
      }
      contentView.refresh(animated: false)

      expect(contentView.contentSize) == CGSize(width: 120, height: 100)
      expect(view.frame) == CGRect(x: 0, y: 10, width: 120, height: 80)
    }
  }

  func test_visibleBoundsInsets() {
    var isTopRendered = false
    var isBottomRendered = false

    contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.visibleBoundsInsets = EdgeInsets(top: -1, left: 0, bottom: -1, right: 0)

    contentView.setContent {
      ZStack {
        // top view
        ViewNode()
          .frame(width: 100, height: 100)
          .offset(x: 0, y: -100) // move the view above the normal bounds
          .onInsert { _, _ in
            isTopRendered = true
          }
          .onRemove { _, _ in
            isTopRendered = false
          }

        // bottom view
        ViewNode()
          .frame(width: 100, height: 100)
          .offset(x: 0, y: 100) // move the view below the normal bounds
          .onInsert { _, _ in
            isBottomRendered = true
          }
          .onRemove { _, _ in
            isBottomRendered = false
          }
      }
    }

    contentView.refresh(animated: false)

    expect(contentView.contentSize) == CGSize(width: 100, height: 100)
    expect(isTopRendered) == true
    expect(isBottomRendered) == true
  }

  func test_sizeThatFits() {
    let contentView = ComposeView {
      LayerNode()
        .frame(width: .flexible, height: 30)
    }
    expect(contentView.sizeThatFits(CGSize(width: 10, height: 10))) == CGSize(width: 10, height: 30)
    expect(contentView.sizeThatFits(CGSize(width: 50, height: 50))) == CGSize(width: 50, height: 30)
  }
}
