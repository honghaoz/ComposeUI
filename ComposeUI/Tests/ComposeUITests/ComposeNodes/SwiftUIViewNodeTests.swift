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

#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

import ChouTiTest

@testable import ComposeUI

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
      let context = RenderableUpdateContext(updateType: updateType, oldFrame: .zero, newFrame: item.frame, previousRenderBounds: .zero, renderBounds: .zero, animationTiming: nil, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)
      item.update(renderable, context)

      // then: the supplied content replaces the host's previous content
      expect(view.content.sizeThatFits(containerSize)) == CGSize(width: 80, height: 50)
    }

    let previousRenderBounds = CGRect(origin: .zero, size: containerSize)
    for renderBounds in [previousRenderBounds.offsetBy(dx: 0, dy: 20), CGRect(x: 0, y: 0, width: 100, height: 150)] {
      // given: a host with different content
      view.content = AnyView(SwiftUI.Color.blue.frame(width: 30, height: 20))

      // when: applying a scroll or resize update directly
      let context = RenderableUpdateContext(updateType: .boundsChange, oldFrame: .zero, newFrame: item.frame, previousRenderBounds: previousRenderBounds, renderBounds: renderBounds, animationTiming: nil, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)
      item.update(renderable, context)

      // then: bounds changes keep the host's current content
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
    let context = RenderableUpdateContext(updateType: .refresh, oldFrame: frame, newFrame: frame, previousRenderBounds: .zero, renderBounds: .zero, animationTiming: nil, contentView: nil, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)
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

    // then: the native appearance remains unchanged while the frame adapts
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

  func test_static_refreshWithSameId_keepsMountedContent() throws {
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

  #if canImport(UIKit)

  // MARK: - Content Size Category

  func test_layout_measuresAtTheContextsContentSizeCategory() throws {
    guard #available(iOS 15.0, tvOS 15.0, *) else {
      try skip("Dynamic Type sizes are available from iOS 15 and tvOS 15")
    }

    // given: a node whose height fits wrapping text
    let node = SwiftUIViewNode { Text(verbatim: Constants.text) }.fixedSize(width: false, height: true)

    // when: laying it out at the smallest text size, at the largest, and at an unspecified one
    var smallest = node
    _ = smallest.layout(containerSize: Constants.containerSize, context: Self.context(at: .extraSmall))
    var largest = node
    _ = largest.layout(containerSize: Constants.containerSize, context: Self.context(at: .accessibilityExtraExtraExtraLarge))
    var unspecified = node
    _ = unspecified.layout(containerSize: Constants.containerSize, context: Self.context(at: .unspecified))

    // then: the node fits the text at each text size, and as the text measures by itself at an unspecified one
    expect(smallest.size.height) == Self.height(of: Text(verbatim: Constants.text).dynamicTypeSize(.xSmall))
    expect(largest.size.height) == Self.height(of: Text(verbatim: Constants.text).dynamicTypeSize(.accessibility5))
    expect(unspecified.size.height) == Self.height(of: Text(verbatim: Constants.text))

    // then: the node is taller at the largest text size on a system that sizes text by the text size, and the same
    // height on one that doesn't
    if UIContentSizeCategory.sizesText {
      expect(largest.size.height) > smallest.size.height
    } else {
      expect(largest.size.height) == smallest.size.height
    }
  }

  func test_layout_contentWithItsOwnDynamicTypeSize_keepsIt() throws {
    guard #available(iOS 15.0, tvOS 15.0, *) else {
      try skip("Dynamic Type sizes are available from iOS 15 and tvOS 15")
    }

    // given: a node whose height fits wrapping text that sets its own text size
    let node = SwiftUIViewNode { Text(verbatim: Constants.text).dynamicTypeSize(.large) }.fixedSize(width: false, height: true)

    // when: laying it out at the smallest and at the largest text size
    var smallest = node
    _ = smallest.layout(containerSize: Constants.containerSize, context: Self.context(at: .extraSmall))
    var largest = node
    _ = largest.layout(containerSize: Constants.containerSize, context: Self.context(at: .accessibilityExtraExtraExtraLarge))

    // then: the node fits the text at the text's own size at both
    let height = Self.height(of: Text(verbatim: Constants.text).dynamicTypeSize(.large))
    expect(smallest.size.height) == height
    expect(largest.size.height) == height
  }

  // MARK: - Legibility Weight

  func test_layout_measuresAtTheContextsLegibilityWeight() throws {
    guard #available(iOS 15.0, tvOS 15.0, *) else {
      try skip("the measurement pins the text weight from iOS 15 and tvOS 15")
    }

    // given: a node whose size fits a line of text
    let node = SwiftUIViewNode { Text(verbatim: Constants.line) }.fixedSize()

    // when: laying it out at the regular and at the bold text weight, without a text size
    var regular = node
    _ = regular.layout(containerSize: Constants.containerSize, context: Self.context(at: .unspecified, legibilityWeight: .regular))
    var bold = node
    _ = bold.layout(containerSize: Constants.containerSize, context: Self.context(at: .unspecified, legibilityWeight: .bold))

    // then: the node fits the text at each weight, and is wider in bold
    expect(regular.size) == Self.size(of: Text(verbatim: Constants.line).environment(\.legibilityWeight, .regular))
    expect(bold.size) == Self.size(of: Text(verbatim: Constants.line).environment(\.legibilityWeight, .bold))
    expect(bold.size.width) > regular.size.width
  }

  // MARK: - Helpers

  /// Returns a layout context at a text size and weight.
  private static func context(at contentSizeCategory: UIContentSizeCategory, legibilityWeight: UILegibilityWeight = .unspecified) -> ComposeNodeLayoutContext {
    ComposeNodeLayoutContext(scaleFactor: 1, contentSizeCategory: contentSizeCategory, legibilityWeight: legibilityWeight, contentEvaluation: ContentEvaluation())
  }

  /// Returns the size of a SwiftUI view in the container size of the tests.
  private static func size(of view: some SwiftUI.View) -> CGSize {
    view.sizeThatFits(Constants.containerSize)
  }

  /// Returns the height of a SwiftUI view in the container size of the tests.
  private static func height(of view: some SwiftUI.View) -> CGFloat {
    size(of: view).height
  }

  // MARK: - Constants

  private enum Constants {

    /// A text that wraps in the container's width at every text size.
    static let text = "The quick brown fox jumps over the lazy dog, then naps in the warm afternoon sun."

    /// A text that fits on one line in the container's width.
    static let line = "Bold text"

    /// The container size, tall enough for the text at the largest text size.
    static let containerSize = CGSize(width: 200, height: 1000)
  }

  #endif
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
