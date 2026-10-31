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

  func test_id() throws {
    // then: a factory view node uses the default id
    expect(ViewNode().id.id) == "V"

    // given: two external views
    let view = View()
    let otherView = View()

    // then: an external view node's id is the view's, which the nodes of the view share, and the nodes of another view
    // don't
    expect(ViewNode(view).id) == ComposeNodeId.object(view, kind: .view)
    expect(ViewNode(view).id) == ViewNode(view).id
    expect(ViewNode(view).id) != ViewNode(otherView).id
  }

  func test_fixedSize() {
    do {
      // given: a view node using a view factory
      var node = ViewNode()

      // then: the size is flexible
      expect(node.isFixedWidth) == false
      expect(node.isFixedHeight) == false

      // when: setting fixed size
      node = node.fixedSize()

      // then: the size is fixed
      expect(node.isFixedWidth) == true
      expect(node.isFixedHeight) == true
    }

    do {
      // given: a view node using an external view
      var node = ViewNode(View())

      // then: the size is fixed
      expect(node.isFixedWidth) == true
      expect(node.isFixedHeight) == true

      // when: setting flexible size
      node = node.flexibleSize()

      // then: the size is flexible
      expect(node.isFixedWidth) == false
      expect(node.isFixedHeight) == false
    }
  }

  func test_constraint_based_view() {
    // given: a view with constraints
    let view = BaseView(frame: CGRect(x: 10, y: 20, width: 100, height: 50))
    expect(view.frame) == CGRect(x: 10, y: 20, width: 100, height: 50) // test initial frame

    // with constraints
    view.translatesAutoresizingMaskIntoConstraints = false
    view.widthAnchor.constraint(equalToConstant: 200).isActive = true
    view.heightAnchor.constraint(equalToConstant: 100).isActive = true

    // when the view is used in ViewNode with fixed size
    do {
      // given: the view in a fixed size ViewNode, in a compose view
      let node = ViewNode(view)
        .fixedSize()
        .padding(10)
        .frame(.flexible, alignment: .topLeft)

      let container = ComposeView(content: { node })
      container.frame = CGRect(x: 0, y: 0, width: 500, height: 500)

      // when: the compose view is refreshed
      container.refresh(animated: false)

      // then: the view's translatesAutoresizingMaskIntoConstraints is changed to true
      expect(view.translatesAutoresizingMaskIntoConstraints) == true

      // then: the view's size should not be changed
      expect(view.frame) == CGRect(x: 10, y: 10, width: 100, height: 50)

      // when: force a layout pass
      container.setNeedsLayout()
      container.layoutIfNeeded()

      // then: the view's size should not be changed
      expect(view.frame) == CGRect(x: 10, y: 10, width: 100, height: 50)

      // when: have the view update its size by constraints
      view.translatesAutoresizingMaskIntoConstraints = false
      view.setNeedsLayout()
      view.layoutIfNeeded()

      // then: the view sizes itself by the constraints
      expect(view.bounds.size) == view.intrinsicSize(for: CGSize(width: 500, height: 500))

      // when: the compose view is refreshed
      container.refresh(animated: false)

      // then: the view's frame should be changed to the size of the constraints
      expect(view.frame) == CGRect(x: 10, y: 10, width: 200, height: 100)
    }

    // when the view is used in ViewNode with flexible size
    do {
      // given: the view in a flexible size ViewNode, in a compose view
      let node = ViewNode(view)
        .flexibleSize()
        .frame(width: 210, height: 110)
        .padding(10)
        .frame(.flexible, alignment: .topLeft)

      let container = ComposeView(content: { node })
      container.frame = CGRect(x: 0, y: 0, width: 500, height: 500)

      // when: the compose view is refreshed
      container.refresh(animated: false)

      // then: the view's frame should be set by ComposéUI, not by the constraints
      expect(view.frame) == CGRect(x: 10, y: 10, width: 210, height: 110)

      // when: force a layout pass
      container.setNeedsLayout()
      container.layoutIfNeeded()

      // then: the view's frame should not be changed by the constraints
      expect(view.frame) == CGRect(x: 10, y: 10, width: 210, height: 110)
    }
  }

  func test_size() {
    // using view's bounds.size as intrinsic size
    do {
      // with external view
      do {
        // given: a view node with an external view
        let view = BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        var node = ViewNode(view)

        // fixed size
        do {
          // when: laying out the node
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the sizing and size use the view's size
          expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .fixed(50))
          expect(node.size) == CGSize(width: 50, height: 50)
        }

        // fixed width, flexible height
        do {
          // when: setting fixed width only and laying out
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width uses the view's width and the height fills the container
          expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .flexible)
          expect(node.size) == CGSize(width: 50, height: 100)
        }

        // flexible width, fixed height
        do {
          // when: setting fixed height only and laying out
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width fills the container and the height uses the view's height
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(50))
          expect(node.size) == CGSize(width: 100, height: 50)
        }

        // flexible size
        do {
          // when: setting flexible size and laying out
          node = node.flexibleSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the sizing is flexible and the size fills the container
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
          expect(node.size) == CGSize(width: 100, height: 100)
        }
      }

      // with view factory
      do {
        // given: a view node with a view factory and a custom intrinsic size
        var node = ViewNode(
          make: { _ in BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50)) },
          intrinsicSize: { containerSize in CGSize(width: containerSize.width * 2, height: containerSize.height * 2) }
        )

        // flexible size
        do {
          // when: laying out the node
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the sizing is flexible and the size fills the container
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
          expect(node.size) == CGSize(width: 100, height: 100)
        }

        // fixed width, flexible height
        do {
          // when: setting fixed width only and laying out
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width uses the intrinsic width and the height fills the container
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .flexible)
          expect(node.size) == CGSize(width: 200, height: 100)
        }

        // flexible width, fixed height
        do {
          // when: setting fixed height only and laying out
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width fills the container and the height uses the intrinsic height
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(200))
          expect(node.size) == CGSize(width: 100, height: 200)
        }

        // fixed size
        do {
          // when: setting fixed size and laying out
          node = node.fixedSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the sizing and size use the intrinsic size
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .fixed(200))
          expect(node.size) == CGSize(width: 200, height: 200)
        }
      }
    }

    // using custom intrinsic size
    do {
      // with external view
      do {
        // given: a view node with an external view and a custom intrinsic size
        let view = BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        var node = ViewNode(view, intrinsicSize: { containerSize in CGSize(width: containerSize.width * 2, height: containerSize.height * 2) })

        // fixed size
        do {
          // when: laying out the node
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the sizing and size use the intrinsic size
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .fixed(200))
          expect(node.size) == CGSize(width: 200, height: 200)
        }

        // fixed width, flexible height
        do {
          // when: setting fixed width only and laying out
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width uses the intrinsic width and the height fills the container
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .flexible)
          expect(node.size) == CGSize(width: 200, height: 100)
        }

        // flexible width, fixed height
        do {
          // when: setting fixed height only and laying out
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width fills the container and the height uses the intrinsic height
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(200))
          expect(node.size) == CGSize(width: 100, height: 200)
        }

        // flexible size
        do {
          // when: setting flexible size and laying out
          node = node.flexibleSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the sizing is flexible and the size fills the container
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
          expect(node.size) == CGSize(width: 100, height: 100)
        }
      }

      // with view factory
      do {
        // given: a view node with a view factory and a custom intrinsic size
        var node = ViewNode(
          make: { _ in BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50)) },
          intrinsicSize: { containerSize in CGSize(width: containerSize.width * 2, height: containerSize.height * 2) }
        )

        // flexible size
        do {
          // when: laying out the node
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the sizing is flexible and the size fills the container
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
          expect(node.size) == CGSize(width: 100, height: 100)
        }

        // fixed width, flexible height
        do {
          // when: setting fixed width only and laying out
          node = node.fixedSize(width: true, height: false)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width uses the intrinsic width and the height fills the container
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .flexible)
          expect(node.size) == CGSize(width: 200, height: 100)
        }

        // flexible width, fixed height
        do {
          // when: setting fixed height only and laying out
          node = node.fixedSize(width: false, height: true)
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the width fills the container and the height uses the intrinsic height
          expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(200))
          expect(node.size) == CGSize(width: 100, height: 200)
        }

        // fixed size
        do {
          // when: setting fixed size and laying out
          node = node.fixedSize()
          let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 2))

          // then: the sizing and size use the intrinsic size
          expect(sizing) == ComposeNodeSizing(width: .fixed(200), height: .fixed(200))
          expect(node.size) == CGSize(width: 200, height: 200)
        }
      }
    }
  }

  func test_fixedSize_withoutIntrinsicSize_measuresAViewOrAssertsForACustomMake() {
    // given: a handler that records the assertions
    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }
    let customMakeMessage = "ViewNode<FixedSizeView> with a custom make needs an intrinsicSize closure for fixed sizing"

    // empty view
    do {
      // given: a fixed size factory view node without an intrinsic size provider
      var node = ViewNode()
        .fixedSize()

      // when: laying out the node
      let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: ComposeNodeLayoutContext(scaleFactor: 1))

      // then: the size is a plain view's, zero, without an assertion
      expect(sizing) == ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
      expect(node.size) == .zero
      expect(assertionMessages) == []
    }

    // fixed size (width: true, height: true)
    do {
      // given: a fixed size factory node for a fixed size view, with a make call counter
      var makeCallCount = 0
      var node = ViewNode<FixedSizeView>(
        make: { _ in
          makeCallCount += 1
          return FixedSizeView()
        }
      ).fixedSize()

      // when: laying out the node
      let sizing = node.layout(containerSize: CGSize(width: 200, height: 200), context: ComposeNodeLayoutContext(scaleFactor: 1))

      // then: the layout asserts, and measures a view that make makes
      expect(assertionMessages) == [customMakeMessage]
      expect(sizing) == ComposeNodeSizing(width: .fixed(80), height: .fixed(60))
      expect(node.size) == CGSize(width: 80, height: 60)
      expect(makeCallCount) == 1
      assertionMessages.removeAll()
    }

    // fixed width only (width: true, height: false)
    do {
      // given: a fixed width factory node for a fixed size view, with a make call counter
      var makeCallCount = 0
      var node = ViewNode<FixedSizeView>(
        make: { _ in
          makeCallCount += 1
          return FixedSizeView()
        }
      ).fixedSize(width: true, height: false)

      // when: laying out the node
      let sizing = node.layout(containerSize: CGSize(width: 200, height: 200), context: ComposeNodeLayoutContext(scaleFactor: 1))

      // then: the layout asserts, the width is the measured view's, and the height fills the container
      expect(assertionMessages) == [customMakeMessage]
      expect(sizing) == ComposeNodeSizing(width: .fixed(80), height: .flexible)
      expect(node.size) == CGSize(width: 80, height: 200)
      expect(makeCallCount) == 1
      assertionMessages.removeAll()
    }

    // fixed height only (width: false, height: true)
    do {
      // given: a fixed height factory node for a fixed size view, with a make call counter
      var makeCallCount = 0
      var node = ViewNode<FixedSizeView>(
        make: { _ in
          makeCallCount += 1
          return FixedSizeView()
        }
      ).fixedSize(width: false, height: true)

      // when: laying out the node
      let sizing = node.layout(containerSize: CGSize(width: 200, height: 200), context: ComposeNodeLayoutContext(scaleFactor: 1))

      // then: the layout asserts, the height is the measured view's, and the width fills the container
      expect(assertionMessages) == [customMakeMessage]
      expect(sizing) == ComposeNodeSizing(width: .flexible, height: .fixed(60))
      expect(node.size) == CGSize(width: 200, height: 60)
      expect(makeCallCount) == 1
    }
  }

  func test_fixedSize_defaultMake_measuresOnePlainViewOfItsType() {
    // given: two fixed-size nodes of a view type that counts the views made of it, with the default view factory
    let madeCountBefore = CountedFixedSizeView.madeCount
    var node = ViewNode<CountedFixedSizeView>().fixedSize()
    var heightNode = ViewNode<CountedFixedSizeView>().fixedSize(width: false, height: true)
    let containerSize = CGSize(width: 200, height: 200)

    // when: the nodes lay out, the first one twice
    _ = node.layout(containerSize: containerSize, context: ComposeNodeLayoutContext(scaleFactor: 1))
    let madeByTheFirstLayout = CountedFixedSizeView.madeCount - madeCountBefore
    _ = heightNode.layout(containerSize: containerSize, context: ComposeNodeLayoutContext(scaleFactor: 1))
    _ = node.layout(containerSize: containerSize, context: ComposeNodeLayoutContext(scaleFactor: 1))

    // then: the nodes take the plain view's size in their fixed dimensions, and at most the first layout made a view
    expect(node.size) == CGSize(width: 80, height: 60)
    expect(heightNode.size) == CGSize(width: 200, height: 60)
    expect(madeByTheFirstLayout <= 1) == true
    expect(CountedFixedSizeView.madeCount - madeCountBefore) == madeByTheFirstLayout
  }

  #if DEBUG && !COMPOSEUI_BENCHMARK
  func test_fixedSize_defaultMake_viewWhoseSizeItsBlocksChange_asserts() {
    // given: fixed-size nodes of a view that's 10 x 10 plain, each with a block that changes its size, and a handler
    // that records the assertions
    let nodes: [(node: ViewNode<SideView>, side: CGFloat)] = [
      (ViewNode<SideView>(willInsert: { view, _ in view.side = 30 }), 30),
      (ViewNode<SideView>(willUpdate: { view, _ in view.side = 30 }), 30),
      (ViewNode<SideView>(update: { view, _ in view.side = 30 }), 30),
      (ViewNode<SideView>(update: { view, _ in view.side = 11 }), 11),
    ]
    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    for (node, side) in nodes {
      let contentView = ComposeView {
        node.fixedSize()
      }
      contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

      // when: the view renders
      contentView.refresh(animated: false)

      // then: the update asserts with the view's size, even a point off
      expect(assertionMessages) == [
        "ViewNode<SideView>'s view is (\(side), \(side)), not the node's size (10.0, 10.0): provide intrinsicSize",
      ]
      assertionMessages.removeAll()
    }
  }

  func test_fixedSize_defaultMake_viewWhoseSizeDiffersInAWindow_doesNotAssert() {
    // given: a fixed-size node of a view that's 65 x 24 outside a window and 64.5 x 24 in one, as an AppKit control can
    // round its size to a window's pixels, in a window, and a handler that records the assertions
    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }
    let window = TestWindow()
    let contentView = ComposeView {
      ViewNode<WindowRoundedView>().fixedSize()
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    window.contentView().addSubview(contentView)

    // when: the view renders, inserting the node's view, then refreshes, reusing it
    contentView.refresh(animated: false)
    contentView.refresh(animated: false)

    // then: nothing asserts, since the update doesn't change the view's size
    expect(assertionMessages) == []
  }
  #endif

  #if os(iOS) || os(visionOS)
  func test_fixedSize_systemControlsThatKeepTheirOwnSize_takeTheirFrames() throws {
    // given: a switch, a stepper and a progress view in fixed-size nodes, each in a 100 x 50 frame, and a handler that
    // records the assertions
    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }
    var height: CGFloat = 50
    var controls: [String: UIView] = [:]
    let contentView = ComposeView {
      VStack {
        ViewNode<UISwitch>(update: { view, _ in controls["switch"] = view })
          .fixedSize()
          .frame(width: 100, height: height)
        ViewNode<UIStepper>(update: { view, _ in controls["stepper"] = view })
          .fixedSize()
          .frame(width: 100, height: height)
        ViewNode<UIProgressView>(update: { view, _ in controls["progress"] = view })
          .fixedSize(width: false, height: true)
          .frame(width: 100, height: height)
      }
      .animation(.linear(duration: 10))
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 200, height: 400)

    // when: the view renders, then an animated refresh makes the frames taller
    contentView.refresh(animated: false)
    height = 70
    contentView.refresh(animated: true)

    // then: nothing asserts, and each control has its own size, in the dimensions that it keeps
    expect(assertionMessages) == []
    let toggle = try unwrap(controls["switch"])
    let stepper = try unwrap(controls["stepper"])
    let progress = try unwrap(controls["progress"])
    expect(toggle.bounds.size) == UISwitch().sizeThatFits(.zero)
    expect(stepper.bounds.size) == UIStepper().sizeThatFits(.zero)
    expect(progress.bounds.size) == CGSize(width: 100, height: UIProgressView().sizeThatFits(.zero).height)
  }
  #endif

  func test_make_default_makesTheViewTypeAtTheInitialFrame() throws {
    // given: a node of a view subclass with the default view factory
    let node = ViewNode<ConstraintBasedView>()

    // when: making its view with an initial frame
    let view = try makeView(of: node, initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4))

    // then: the view is of the node's type, at the initial frame, and lays out by its frame
    expect(view is ConstraintBasedView) == true
    expect(view.frame) == CGRect(x: 1, y: 2, width: 3, height: 4)
    expect(view.translatesAutoresizingMaskIntoConstraints) == true

    // when: making its view without an initial frame
    let viewWithoutInitialFrame = try makeView(of: node, initialFrame: nil)

    // then: the view is of the node's type, at a zero frame, and lays out by its frame
    expect(viewWithoutInitialFrame is ConstraintBasedView) == true
    expect(viewWithoutInitialFrame.frame) == .zero
    expect(viewWithoutInitialFrame.translatesAutoresizingMaskIntoConstraints) == true
  }

  #if canImport(AppKit)
  func test_make_default_plainView_isLayerBacked() throws {
    // given: a node of plain views with the default view factory
    let node = ViewNode<View>()

    // when: making its view
    let view = try makeView(of: node, initialFrame: nil)

    // then: the view is layer-backed
    expect(view.wantsLayer) == true

    // when: making the view of a node of a view subclass with the default view factory
    let subclassView = try makeView(of: ViewNode<ConstraintBasedView>(), initialFrame: nil)

    // then: the subclass's layer backing is left to the subclass
    expect(subclassView.wantsLayer) == false
  }
  #endif

  func test_make_nil_makesTheDefaultView() throws {
    // given: a node of a view subclass with a nil view factory
    let node = ViewNode<ConstraintBasedView>(make: nil)

    // when: making its view with an initial frame
    let view = try makeView(of: node, initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4))

    // then: the view is the default one, of the node's type at the initial frame
    expect(view is ConstraintBasedView) == true
    expect(view.frame) == CGRect(x: 1, y: 2, width: 3, height: 4)
    expect(view.translatesAutoresizingMaskIntoConstraints) == true
  }

  func test_make_custom_makesTheCustomView() throws {
    // given: a node with a custom view factory
    let customView = View()
    let node = ViewNode(make: { _ in customView })

    // when: making its view
    let view = try makeView(of: node, initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4))

    // then: the view is the custom one
    expect(view) === customView
  }

  func test_init_withAViewFactory_keepsTheFactoryWithoutAllocating() {
    // given: a view factory and an update, and a body that makes a node with them, run once already, since a first run
    // can also allocate what the runtime makes on first use, such as type metadata
    let make: (RenderableMakeContext) -> View = { _ in View() }
    let update: (View, RenderableUpdateContext) -> Void = { _, _ in }
    let body = {
      _ = ViewNode(make: make, update: update)
    }
    _ = AllocationCounter.count(body)

    // when: counting the allocations of the body
    let allocations = AllocationCounter.count(body)

    // then: the node keeps the factory as it is, without wrapping it in a reabstraction thunk
    expect(allocations) == 0
  }

  func test_view_as_composeContent() {
    // given: a compose view using a plain view as content
    let view = ComposeView {
      BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50)) as ViewType
    }

    // when: the view is sized and refreshed
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)

    // then: the view is added and centered
    expect(view.contentContainerView.subviews.count) == 1
    expect(view.contentContainerView.subviews[0].frame) == CGRect(x: 25, y: 25, width: 50, height: 50)
  }

  func test_renderableItems() throws {
    // given: a laid out view node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ViewNode()
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    do {
      // when: getting renderable items in visible bounds intersecting the node's frame
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)

      // then: one item with the node's id and frame is provided
      expect(items.count) == 1

      let item = items[0]
      expect(item.id.id) == "V"
      expect(item.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

      do {
        // when: making a renderable
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: nil))

        // then: the renderable uses the initial frame
        expect(renderable.layer.frame) == CGRect(x: 1, y: 2, width: 3, height: 4)
      }

      // then: the item has no insert or update callbacks
      expect(item.willInsert) == nil
      expect(item.didInsert) == nil
      expect(item.willUpdate) == nil

      do {
        // given: a renderable made from the item
        let contentView = ComposeView()
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

        // when: updating the renderable
        let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, previousRenderBounds: .zero, renderBounds: .zero, animationTiming: nil, contentView: contentView, contentEvaluation: nil, animationDecision: ComposeView.AnimationDecision.disabled)
        item.update(renderable, context)

        // then: the renderable keeps its frame
        let layer = renderable.layer
        expect(layer.frame) == CGRect(x: 1, y: 2, width: 3, height: 4)
      }

      // then: the item has no remove callbacks, transition, or animation timing
      expect(item.willRemove) == nil
      expect(item.didRemove) == nil
      expect(item.transition) == nil
      expect(item.animationTiming) == nil
    }

    do {
      // when: getting renderable items in visible bounds not intersecting the node's frame
      let visibleBounds = CGRect(x: 0, y: 100, width: 100, height: 100)
      let items = node.renderableItems(in: visibleBounds)

      // then: no items are provided
      expect(items.count) == 0
    }
  }

  func test_renderableItems_visibleBounds() {
    // given: a view node with specific size
    let view = BaseView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    var node = ViewNode(view)

    // layout the node to set its size
    _ = node.layout(containerSize: CGSize(width: 50, height: 50), context: ComposeNodeLayoutContext(scaleFactor: 1))
    expect(node.size) == CGSize(width: 50, height: 50)

    do {
      // when: getting renderable items with visible bounds intersecting the node frame
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 100) // intersects
      let items = node.renderableItems(in: visibleBounds)

      // then: one item is provided
      expect(items.count) == 1
    }

    do {
      // when: getting renderable items with visible bounds partially intersecting the node frame
      let visibleBounds = CGRect(x: 25, y: 25, width: 50, height: 50) // partially intersects
      let items = node.renderableItems(in: visibleBounds)

      // then: one item is provided
      expect(items.count) == 1
    }

    do {
      // when: getting renderable items with visible bounds not intersecting the node frame
      let visibleBounds = CGRect(x: 100, y: 100, width: 50, height: 50) // no intersection
      let items = node.renderableItems(in: visibleBounds)

      // then: no items are provided
      expect(items.count) == 0 // should return empty array
    }
  }

  func test_update_appliesBoundsAndScrollDependentConfiguration() throws {
    // given: a view whose appearance depends on its width and the container's scroll position
    var renderedView: BaseView?
    var updateType: RenderableUpdateType?
    let contentView = ComposeView {
      ViewNode<BaseView>(update: { view, context in
        view.layer().cornerRadius = context.newFrame.width / 4
        view.layer().backgroundColor = context.contentView.contentOffset.y > 0 ? Color.blue.cgColor : Color.red.cgColor
        renderedView = view
        updateType = context.updateType
      })
      .frame(width: .flexible, height: 200)
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the view is inserted
    contentView.refresh(animated: false)

    // then: the initial configuration is applied
    let view = try unwrap(renderedView)
    expect(view.layer().cornerRadius) == 25
    expect(view.layer().backgroundColor) == Color.red.cgColor
    expect(updateType) == .insert

    // when: the container is resized
    contentView.frame.size.width = 200
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: the same view receives its new size-dependent configuration
    expect(renderedView) === view
    expect(view.bounds.size) == CGSize(width: 200, height: 200)
    expect(view.layer().cornerRadius) == 50
    expect(updateType) == .boundsChange

    // when: the container scrolls
    contentView.contentOffset = CGPoint(x: 0, y: 20)
    contentView.layoutIfNeeded()

    // then: custom updates can also apply scroll-dependent configuration
    expect(renderedView) === view
    expect(view.layer().backgroundColor) == Color.blue.cgColor
    expect(updateType) == .boundsChange
  }

  #if canImport(AppKit)
  func test_nonLayerBackedView_assertion() {
    // given: a view that is not layer backed, in a compose view, with a test assertion failure handler
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
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    // when: refreshing the compose view
    container.refresh(animated: false)

    // then: it should trigger the assertion for non-layer-backed view
    expect(assertionCount) == 1
  }
  #endif

  // MARK: - Helpers

  /// Lays out the node and makes the view of its item.
  private func makeView(of node: ViewNode<some Any>, initialFrame: CGRect?) throws -> View {
    var node = node
    _ = node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 1))
    let item = try unwrap(node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10)).first)
    return try unwrap(item.make(RenderableMakeContext(initialFrame: initialFrame, contentView: nil)).view)
  }
}

// MARK: - Test Helpers

/// A view that lays out by constraints when it's made, so a test can tell that a factory sets it to lay out by its frame.
private class ConstraintBasedView: View {

  override init(frame: CGRect) {
    super.init(frame: frame)
    translatesAutoresizingMaskIntoConstraints = false
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }
}

/// A view that reports an 80 x 60 size and counts the views made of it.
private final class CountedFixedSizeView: BaseView {

  /// The number of views made of the type.
  static var madeCount = 0

  override init(frame: CGRect) {
    super.init(frame: frame)
    Self.madeCount += 1
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  #if canImport(AppKit)
  override var fittingSize: NSSize {
    CGSize(width: 80, height: 60)
  }
  #else
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: 80, height: 60)
  }
  #endif
}

/// A view that's 65 x 24 outside a window and 64.5 x 24 in one.
private final class WindowRoundedView: BaseView {

  private var ownSize: CGSize {
    CGSize(width: window == nil ? 65 : 64.5, height: 24)
  }

  #if canImport(AppKit)
  override var fittingSize: NSSize {
    ownSize
  }
  #else
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    ownSize
  }
  #endif
}

/// A square view whose size follows its side length.
private final class SideView: BaseView {

  /// The side length of the view's size.
  var side: CGFloat = 10

  #if canImport(AppKit)
  override var fittingSize: NSSize {
    CGSize(width: side, height: side)
  }
  #else
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: side, height: side)
  }
  #endif
}

private class FixedSizeView: BaseView {

  override init(frame: CGRect) {
    super.init(frame: frame)

    #if canImport(AppKit)
    translatesAutoresizingMaskIntoConstraints = false
    widthAnchor.constraint(equalToConstant: 80).isActive = true
    heightAnchor.constraint(equalToConstant: 60).isActive = true
    #endif
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable") // swiftlint:disable:this fatal_error
  }

  #if canImport(UIKit)
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: 80, height: 60)
  }
  #endif
}
