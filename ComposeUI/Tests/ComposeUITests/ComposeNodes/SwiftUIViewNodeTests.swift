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
    // given: static and dynamic SwiftUI view nodes in a compose view
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
    // given: a laid out node with fixed size SwiftUI content
    let containerSize = CGSize(width: 100, height: 100)
    var node = SwiftUIViewNode {
      SwiftUI.Color.red.frame(width: 80, height: 50)
    }
    _ = node.layout(containerSize: containerSize, context: ComposeNodeLayoutContext(scaleFactor: 1))
    let item = try node.renderableItems(in: CGRect(origin: .zero, size: containerSize)).first.unwrap()
    let contentView = ComposeView()

    // when: making hosts with and without an initial frame
    let initialFrame = CGRect(x: 1, y: 2, width: 3, height: 4)
    let renderable = item.make(RenderableMakeContext(initialFrame: initialFrame, contentView: contentView))
    let view = try (renderable.view as? MutableSwiftUIHostingView).unwrap()
    let unframedRenderable = item.make(RenderableMakeContext(initialFrame: nil, contentView: contentView))
    let offscreenItems = node.renderableItems(in: CGRect(x: 0, y: 200, width: 100, height: 100))

    // then: the hosts use the supplied frames and start with empty content
    expect(item.id.id) == "SUI"
    expect(item.frame) == CGRect(origin: .zero, size: containerSize)
    expect(view.frame) == initialFrame
    expect(unframedRenderable.frame) == .zero
    expect(view.content.sizeThatFits(containerSize)) == EmptyView().sizeThatFits(containerSize)
    expect(offscreenItems.isEmpty) == true

    for updateType in [RenderableUpdateType.insert, .refresh] {
      // given: a host with different content
      view.content = AnyView(SwiftUI.Color.blue.frame(width: 30, height: 20))

      // when: applying a configuration update
      let context = RenderableUpdateContext(updateType: updateType, oldFrame: .zero, newFrame: item.frame, animationTiming: nil, contentView: contentView)
      item.update(renderable, context)

      // then: the supplied content replaces the host's previous content
      expect(view.content.sizeThatFits(containerSize)) == CGSize(width: 80, height: 50)
    }

    for updateType in [RenderableUpdateType.boundsChange, .scroll] {
      // given: a host with different content
      view.content = AnyView(SwiftUI.Color.blue.frame(width: 30, height: 20))

      // when: applying a geometry-only update directly
      let context = RenderableUpdateContext(updateType: updateType, oldFrame: .zero, newFrame: item.frame, animationTiming: nil, contentView: contentView)
      item.update(renderable, context)

      // then: geometry-only updates retain the host's current content
      expect(view.content.sizeThatFits(containerSize)) == CGSize(width: 30, height: 20)
    }
  }

  func test_dynamic_update_rejectsNonMutableHost() throws {
    // given: a dynamic node and a non-mutable host
    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    var node = SwiftUIViewNode {
      SwiftUI.Color.blue
    }
    _ = node.layout(containerSize: frame.size, context: ComposeNodeLayoutContext(scaleFactor: 1))
    let item = try node.renderableItems(in: frame).first.unwrap()
    let view = BaseView(frame: frame)
    view.layer().backgroundColor = ComposeUI.Color.red.cgColor
    var messages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      messages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: applying the configuration to an incompatible host
    let context = RenderableUpdateContext(updateType: .refresh, oldFrame: frame, newFrame: frame, animationTiming: nil, contentView: nil)
    item.update(.view(view), context)

    // then: the invalid host is reported without changing its appearance
    expect(messages) == ["view should be a MutableSwiftUIHostingView"]
    expect(view.layer().backgroundColor) == ComposeUI.Color.red.cgColor
  }

  func test_dynamic_sameFrameRefresh_updatesNativeAppearance() throws {
    // given: a lazy flexible node with native content
    let window = TestWindow()
    let nativeView = BaseView()
    var color = ComposeUI.Color.red
    var renderedView: MutableSwiftUIHostingView?
    let node = SwiftUIViewNode { NativeColorContent(view: nativeView, color: color) }
    let contentView = ComposeView {
      node.onUpdate { renderable, _ in
        renderedView = renderable.view as? MutableSwiftUIHostingView
      }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    window.contentView().addSubview(contentView)
    contentView.refresh(animated: false)
    let view = try renderedView.unwrap()
    view.layoutIfNeeded()

    // then: initial insertion renders the first resolved appearance
    expect(nativeView.layer().backgroundColor).toEventually(beEqual(to: ComposeUI.Color.red.cgColor))

    // when: resize keeps the same node after its data changes
    color = .blue
    contentView.frame.size.width = 160
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()
    view.layoutIfNeeded()

    // then: the native appearance remains unchanged while geometry adapts
    expect(renderedView) === view
    expect(view.bounds.size) == CGSize(width: 160, height: 100)
    expect(nativeView.layer().backgroundColor) == ComposeUI.Color.red.cgColor

    // when: an explicit refresh keeps the same renderable id and frame
    contentView.refresh(animated: false)
    view.layoutIfNeeded()

    // then: cached render-item closures use the new content on the same native host
    expect(renderedView) === view
    expect(nativeView.layer().backgroundColor).toEventually(beEqual(to: ComposeUI.Color.blue.cgColor))
    expect(nativeView.superview) != nil
  }

  func test_static_refreshWithSameId_retainsMountedContent() throws {
    // given: a static node displaying a native red view
    let window = TestWindow()
    let initialNativeView = BaseView()
    var suppliedView = initialNativeView
    var color = ComposeUI.Color.red
    var id = "static"
    var renderedView: SwiftUIHostingView<AnyView>?
    let contentView = ComposeView {
      SwiftUIViewNode(id: id, NativeColorContent(view: suppliedView, color: color))
        .onUpdate { renderable, _ in
          renderedView = renderable.view as? SwiftUIHostingView<AnyView>
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    window.contentView().addSubview(contentView)
    contentView.refresh(animated: false)
    let view = try renderedView.unwrap()
    view.layoutIfNeeded()

    // then: the static host mounts the supplied appearance
    expect(initialNativeView.layer().backgroundColor).toEventually(beEqual(to: ComposeUI.Color.red.cgColor))
    expect(initialNativeView.superview) != nil
    expect(view is MutableSwiftUIHostingView) == false

    // when: a resize follows changes to the supplied content
    suppliedView = BaseView()
    color = .blue
    contentView.frame.size = CGSize(width: 200, height: 150)
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()
    view.layoutIfNeeded()

    // then: resizing preserves the original content while updating its host frame
    expect(renderedView) === view
    expect(view.bounds.size) == CGSize(width: 200, height: 150)
    expect(initialNativeView.layer().backgroundColor) == ComposeUI.Color.red.cgColor
    expect(suppliedView.superview) == nil

    // when: refreshing with a new static value under the same id
    contentView.refresh(animated: false)
    view.layoutIfNeeded()

    // then: a static host does not replace its original content on refresh
    expect(renderedView) === view
    expect(initialNativeView.layer().backgroundColor) == ComposeUI.Color.red.cgColor
    expect(suppliedView.superview) == nil

    // when: the static content receives a new id
    id = "replacement"
    contentView.refresh(animated: false)
    renderedView?.layoutIfNeeded()

    // then: a new host mounts the new appearance
    expect(renderedView) !== view
    expect(suppliedView.layer().backgroundColor).toEventually(beEqual(to: ComposeUI.Color.blue.cgColor))
    expect(suppliedView.superview) != nil
    expect(renderedView?.window) === window
  }

  func test_static_fixedWidth_fixedHeight() {
    // given: a static SwiftUI view node with fixed width and height
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
    // given: a static SwiftUI view node with fixed width and flexible height
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
    // given: a static SwiftUI view node with flexible width and fixed height
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
    // given: a static SwiftUI view node with flexible width and height
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
    // given: a compose view with the SwiftUI view node placed below the visible bounds
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
    for resolvesContent in [false, true] {
      // given: a provider-owned probe that cannot be retained by SwiftUI's native sizing graph
      weak var weakProbe: AnyObject?
      do {
        let probe = NSObject()
        weakProbe = probe
        var node: any ComposeNode = SwiftUIViewNode { [probe] in
          _ = probe
          return SwiftUI.Color.red
        }
        .fixedSize(width: resolvesContent, height: resolvesContent)

        // when: the node lays out, provides renderable items, and goes out of scope
        _ = node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
        _ = node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))
      }

      // then: the provider, resolved value, and cached renderable item do not keep the node alive
      expect(weakProbe).to(beNil())
    }
  }
}

private struct NativeColorContent {

  let view: BaseView
  let color: ComposeUI.Color
}

#if canImport(AppKit)
extension NativeColorContent: NSViewRepresentable {

  func makeNSView(context: Context) -> BaseView {
    view
  }

  func updateNSView(_ nsView: BaseView, context: Context) {
    nsView.layer().backgroundColor = color.cgColor
  }
}
#endif

#if canImport(UIKit)
extension NativeColorContent: UIViewRepresentable {

  func makeUIView(context: Context) -> BaseView {
    view
  }

  func updateUIView(_ uiView: BaseView, context: Context) {
    uiView.layer().backgroundColor = color.cgColor
  }
}
#endif
