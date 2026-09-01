//
//  SwiftUIViewNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/6/25.
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
import SwiftUI

class SwiftUIViewNodeTests: XCTestCase {

  func test() {
    // given: static and dynamic swiftui view nodes in a compose view
    var view1: SwiftUIHostingView<AnyView>?
    var view2: MutableSwiftUIHostingView?
    let contentView = ComposeView {
      // static
      SwiftUIViewNode(
        id: "text",
        Text("Hello, World!")
      )
      .onInsert { renderable, _ in
        view1 = renderable.view as? SwiftUIHostingView<AnyView>
      }

      // dynamic
      SwiftUIViewNode {
        Text("Hello, World!")
      }
      .onInsert { renderable, _ in
        view2 = renderable.view as? MutableSwiftUIHostingView
      }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

    // when: the view is refreshed
    contentView.refresh()

    // then: both hosting views are sized and interactive
    expect(view1?.bounds.size) == CGSize(width: 100, height: 25)
    expect(view1?.isUserInteractionEnabled) == true
    expect(view2?.bounds.size) == CGSize(width: 100, height: 25)
    expect(view2?.isUserInteractionEnabled) == true
  }

  func test_conditional_update() throws {
    // given: a laid out swiftui view node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = SwiftUIViewNode { Text("Hello, World!") }
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when: getting renderable items
    let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
    let items = node.renderableItems(in: visibleBounds)

    // then: one item with the expected id and frame is provided
    expect(items.count) == 1

    let item = items[0]
    expect(item.id.id) == "SUI"
    expect(item.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

    // normal update
    do {
      // given: a renderable made from the item
      let contentView = ComposeView()
      let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

      // when: updating with a refresh update type
      let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
      item.update(renderable, context)

      // then: the hosting view content is updated
      let view = try (renderable.view as? MutableSwiftUIHostingView).unwrap()
      expect("\(view.content)".contains("Hello, World")) == true
    }

    // conditional update
    do {
      // given: a renderable made from the item
      let contentView = ComposeView()
      let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

      do {
        // when: updating with a scroll update type
        let context = RenderableUpdateContext(updateType: .scroll, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
        item.update(renderable, context)

        // then: scroll doesn't trigger update
        let view = try (renderable.view as? MutableSwiftUIHostingView).unwrap()
        expect("\(view.content)") == "AnyView(EmptyView())" // doesn't update
      }

      do {
        // when: updating with a bounds change update type
        let context = RenderableUpdateContext(updateType: .boundsChange, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
        item.update(renderable, context)

        // then: bounds change triggers update
        let view = try (renderable.view as? MutableSwiftUIHostingView).unwrap()
        expect("\(view.content)".contains("Hello, World")) == true
      }
    }
  }

  func test_static_fixedWidth_fixedHeight() {
    // given: a static swiftui view node with fixed width and height
    var view: SwiftUIHostingView<AnyView>?
    let contentView = ComposeView {
      // static
      SwiftUIViewNode(
        id: "text",
        SwiftUI.Color.black
          .frame(width: 80, height: 50)
      )
      .fixedSize(width: true, height: true)
      .onInsert { renderable, _ in
        view = renderable.view as? SwiftUIHostingView<AnyView>
      }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the view is refreshed
    contentView.refresh()

    // then: the hosting view uses the intrinsic size
    expect(view?.bounds.size) == CGSize(width: 80, height: 50)
  }

  func test_static_fixedWidth_flexibleHeight() {
    // given: a static swiftui view node with fixed width and flexible height
    var view: SwiftUIHostingView<AnyView>?
    let contentView = ComposeView {
      // static
      SwiftUIViewNode(
        id: "text",
        SwiftUI.Color.black
          .frame(width: 80, height: 50)
      )
      .fixedSize(width: true, height: false)
      .onInsert { renderable, _ in
        view = renderable.view as? SwiftUIHostingView<AnyView>
      }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the view is refreshed
    contentView.refresh()

    // then: the width is intrinsic and the height fills the container
    expect(view?.bounds.size) == CGSize(width: 80, height: 100)
  }

  func test_static_flexibleWidth_fixedHeight() {
    // given: a static swiftui view node with flexible width and fixed height
    var view: SwiftUIHostingView<AnyView>?
    let contentView = ComposeView {
      // static
      SwiftUIViewNode(
        id: "text",
        SwiftUI.Color.black
          .frame(width: 80, height: 50)
      )
      .fixedSize(width: false, height: true)
      .onInsert { renderable, _ in
        view = renderable.view as? SwiftUIHostingView<AnyView>
      }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the view is refreshed
    contentView.refresh()

    // then: the width fills the container and the height is intrinsic
    expect(view?.bounds.size) == CGSize(width: 100, height: 50)
  }

  func test_static_flexibleWidth_flexibleHeight() {
    // given: a static swiftui view node with flexible width and height
    var view: SwiftUIHostingView<AnyView>?
    let contentView = ComposeView {
      // static
      SwiftUIViewNode(
        id: "text",
        SwiftUI.Color.black
          .frame(width: 80, height: 50)
      )
      .fixedSize(width: false, height: false)
      .onInsert { renderable, _ in
        view = renderable.view as? SwiftUIHostingView<AnyView>
      }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the view is refreshed
    contentView.refresh()

    // then: the hosting view fills the container
    expect(view?.bounds.size) == CGSize(width: 100, height: 100)
  }

  func test_view_outOfBounds() {
    // given: a compose view with the swiftui view node placed below the visible bounds
    var view: SwiftUIHostingView<AnyView>?
    let contentView = ComposeView {
      VStack {
        Spacer(width: 0, height: 100)
        // static
        SwiftUIViewNode(
          id: "text",
          SwiftUI.Color.black
            .frame(width: 80, height: 50)
        )
        .fixedSize(width: true, height: true)
        .onInsert { renderable, _ in
          view = renderable.view as? SwiftUIHostingView<AnyView>
        }
      }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the view is refreshed
    contentView.refresh()

    // then: the out of bounds view is not created
    expect(view) == nil
  }

  func test_renderableItems_doesNotRetainNodeThroughItemCache() {
    // The cached item's make/update closures must not capture `self` (the node holds the item cache), else
    // itemCache -> cachedItem -> closure -> self -> itemCache leaks the node when the tree is replaced.

    // given: a weak probe captured by the node's content closure
    weak var weakProbe: AnyObject?
    do {
      let probe = NSObject()
      weakProbe = probe
      var node: any ComposeNode = SwiftUIViewNode { () -> SwiftUI.Text in
        _ = probe // captured by the content closure; reachable from the cached closures only if they capture `self`
        return SwiftUI.Text("hi")
      }

      // when: the node lays out, provides renderable items, and goes out of scope
      _ = node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
      _ = node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    // then: the probe is released, so the cached item does not retain the node
    expect(weakProbe).to(beNil())
  }
}
