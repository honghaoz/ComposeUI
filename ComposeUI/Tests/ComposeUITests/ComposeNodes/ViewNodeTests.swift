//
//  ViewNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/29/24.
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

class ViewNodeTests: XCTestCase {

  func test_fixedSize() {
    do {
      // when using view factory
      var node = ViewNode()

      // then the size is flexible
      expect(node.isFixedWidth) == false
      expect(node.isFixedHeight) == false

      // when set fixed size
      node = node.fixed()

      // then the size is fixed
      expect(node.isFixedWidth) == true
      expect(node.isFixedHeight) == true
    }

    do {
      // when using external view
      var node = ViewNode(View())

      // then the size is fixed
      expect(node.isFixedWidth) == true
      expect(node.isFixedHeight) == true

      // when set flexible size
      node = node.flexible()

      // then the size is flexible
      expect(node.isFixedWidth) == false
      expect(node.isFixedHeight) == false
    }
  }

  func test_constraint_based_view() {
    // given a view with constraints
    let view = BaseView(frame: CGRect(x: 10, y: 20, width: 100, height: 50))
    expect(view.frame) == CGRect(x: 10, y: 20, width: 100, height: 50) // test initial frame

    // with constraints
    view.translatesAutoresizingMaskIntoConstraints = false
    view.widthAnchor.constraint(equalToConstant: 200).isActive = true
    view.heightAnchor.constraint(equalToConstant: 100).isActive = true

    // when the view is used in ViewNode with fixed size
    do {
      let node = ViewNode(view)
        .fixed()
        .padding(10)
        .frame(.flexible, alignment: .topLeft)

      let container = ComposeView(content: { node })
      container.frame = CGRect(x: 0, y: 0, width: 500, height: 500)

      container.refresh(animated: false)

      // the view's translatesAutoresizingMaskIntoConstraints is changed to true
      expect(view.translatesAutoresizingMaskIntoConstraints) == true

      // the view's size should not be changed
      expect(view.frame) == CGRect(x: 10, y: 10, width: 100, height: 50)

      // force a layout pass
      container.setNeedsLayout()
      container.layoutIfNeeded()
      // the view's size should not be changed
      expect(view.frame) == CGRect(x: 10, y: 10, width: 100, height: 50)

      // have the view update its size by constraints
      view.translatesAutoresizingMaskIntoConstraints = false
      view.setNeedsLayout()
      view.layoutIfNeeded()
      expect(view.bounds.size) == view.intrinsicSize(for: CGSize(width: 500, height: 500))
      container.refresh(animated: false)
      // the view's frame should be changed to the size of the constraints
      expect(view.frame) == CGRect(x: 10, y: 10, width: 200, height: 100)
    }

    // when the view is used in ViewNode with flexible size
    do {
      let node = ViewNode(view)
        .flexible()
        .frame(width: 210, height: 110)
        .padding(10)
        .frame(.flexible, alignment: .topLeft)

      let container = ComposeView(content: { node })
      container.frame = CGRect(x: 0, y: 0, width: 500, height: 500)

      container.refresh(animated: false)

      // the view's frame should be set by ComposéUI, not by the constraints
      expect(view.frame) == CGRect(x: 10, y: 10, width: 210, height: 110)

      // force a layout pass
      container.setNeedsLayout()
      container.layoutIfNeeded()
      // the view's frame should not be changed by the constraints
      expect(view.frame) == CGRect(x: 10, y: 10, width: 210, height: 110)
    }
  }
}
