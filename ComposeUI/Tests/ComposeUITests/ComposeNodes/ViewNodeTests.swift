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
      node = node.fixedSize()

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
      node = node.flexibleSize()

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
        .fixedSize()
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
        .flexibleSize()
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

  func test_size() {
    // using view's bounds.size as intrinsic size
    do {
      // with external view
      do {
        let view = BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        var node = ViewNode(view)

        // fixed size
        do {
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .fixed(50))
          expect(node.size) == CGSize(width: 50, height: 50)
        }

        // fixed width, flexible height
        do {
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .flexible)
          expect(node.size) == CGSize(width: 50, height: 100)
        }

        // flexible width, fixed height
        do {
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(50))
          expect(node.size) == CGSize(width: 100, height: 50)
        }

        // flexible size
        do {
          node = node.flexibleSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
          expect(node.size) == CGSize(width: 100, height: 100)
        }
      }

      // with view factory
      do {
        var node = ViewNode(
          make: { _ in BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50)) },
          intrinsicSize: { _, containerSize in CGSize(width: containerSize.width * 2, height: containerSize.height * 2) }
        )

        // flexible size
        do {
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
          expect(node.size) == CGSize(width: 100, height: 100)
        }

        // fixed width, flexible height
        do {
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .flexible)
          expect(node.size) == CGSize(width: 200, height: 100)
        }

        // flexible width, fixed height
        do {
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(200))
          expect(node.size) == CGSize(width: 100, height: 200)
        }

        // fixed size
        do {
          node = node.fixedSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .fixed(200))
          expect(node.size) == CGSize(width: 200, height: 200)
        }
      }
    }

    // using custom intrinsic size
    do {
      // with external view
      do {
        let view = BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        var node = ViewNode(view, intrinsicSize: { _, containerSize in CGSize(width: containerSize.width * 2, height: containerSize.height * 2) })

        // fixed size
        do {
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .fixed(200))
          expect(node.size) == CGSize(width: 200, height: 200)
        }

        // fixed width, flexible height
        do {
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .flexible)
          expect(node.size) == CGSize(width: 200, height: 100)
        }

        // flexible width, fixed height
        do {
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(200))
          expect(node.size) == CGSize(width: 100, height: 200)
        }

        // flexible size
        do {
          node = node.flexibleSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
          expect(node.size) == CGSize(width: 100, height: 100)
        }
      }

      // with view factory
      do {
        var node = ViewNode(
          make: { _ in BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50)) },
          intrinsicSize: { _, containerSize in CGSize(width: containerSize.width * 2, height: containerSize.height * 2) }
        )

        // flexible size
        do {
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
          expect(node.size) == CGSize(width: 100, height: 100)
        }

        // fixed width, flexible height
        do {
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .flexible)
          expect(node.size) == CGSize(width: 200, height: 100)
        }

        // flexible width, fixed height
        do {
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(200))
          expect(node.size) == CGSize(width: 100, height: 200)
        }

        // fixed size
        do {
          node = node.fixedSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .fixed(200))
          expect(node.size) == CGSize(width: 200, height: 200)
        }
      }
    }
  }

  func test_view_as_composeContent() {
    let view = ComposeView {
      BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50)) as ViewType
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)

    expect(view.contentView().subviews.count) == 1
    expect(view.contentView().subviews[0].frame) == CGRect(x: 25, y: 25, width: 50, height: 50)
  }

  #if canImport(AppKit)
  func test_nonLayerBackedView_assertion() {
    // given a view that is not layer backed
    let view = BaseView()
    view.wantsLayer = false // explicitly disable layer backing

    let node = ViewNode(view)
      .frame(width: 100, height: 100)

    let container = ComposeView(content: { node })
    container.frame = CGRect(x: 0, y: 0, width: 200, height: 200)

    var assertionCount = 0
    Assert.setTestAssertionFailureHandler { message, file, line, column in
      expect(message) == "\(view) should be layer backed. Please set `wantsLayer == true`."
      assertionCount += 1
    }

    // when refreshing the compose view
    // then it should trigger the assertion for non-layer-backed view
    container.refresh(animated: false)
    expect(assertionCount) == 1
  }
  #endif
}
