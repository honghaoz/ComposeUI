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
    // given: a compose view made without content
    let contentView = ComposeView()
    let nodes = contentView.content.nodes

    // then: the default content is a single empty node
    expect(nodes.count) == 1
    expect(nodes[0].id.id) == "E"
    expect(nodes[0].size) == .zero
  }

  func test_centerContent() {
    do {
      // given: content size is smaller than the bounds size
      let view = BaseView()
      contentView.setContent {
        ViewNode(view)
          .flexibleSize()
          .frame(width: 50, height: 80)
      }

      // when: the view is refreshed
      contentView.refresh(animated: false)

      // then: the content is centered in both directions
      expect(contentView.contentSize) == CGSize(width: 100, height: 100)
      expect(view.frame) == CGRect(x: 25, y: 10, width: 50, height: 80)
    }

    do {
      // given: content width is smaller than the bounds width
      let view = BaseView()
      contentView.setContent {
        ViewNode(view)
          .flexibleSize()
          .frame(width: 50, height: 120)
      }

      // when: the view is refreshed
      contentView.refresh(animated: false)

      // then: the content is centered horizontally
      expect(contentView.contentSize) == CGSize(width: 100, height: 120)
      expect(view.frame) == CGRect(x: 25, y: 0, width: 50, height: 120)
    }

    do {
      // given: content height is smaller than the bounds height
      let view = BaseView()
      contentView.setContent {
        ViewNode(view)
          .flexibleSize()
          .frame(width: 120, height: 80)
      }

      // when: the view is refreshed
      contentView.refresh(animated: false)

      // then: the content is centered vertically
      expect(contentView.contentSize) == CGSize(width: 120, height: 100)
      expect(view.frame) == CGRect(x: 0, y: 10, width: 120, height: 80)
    }
  }

  #if canImport(UIKit)
  func test_centerContent_viewOffThePixelGrid() {
    // given: a view whose width is off the pixel grid, showing smaller content
    contentView.frame = CGRect(x: 0, y: 0, width: 100.3, height: 100)
    contentView.setContent {
      ColorNode(.red)
        .frame(width: 50, height: 80)
    }

    // when: the view is refreshed
    contentView.refresh(animated: false)

    // then: the content size is the view's size instead of that size rounded up to whole pixels, so there's nothing to
    // scroll
    expect(contentView.contentSize) == CGSize(width: 100.3, height: 100)
  }
  #endif

  func test_visibleBoundsInsets() {
    // given: a compose view with extended visible bounds and render tracking for offscreen top and bottom views
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

    // when: the view is refreshed
    contentView.refresh(animated: false)

    // then: both offscreen views are rendered thanks to the extended visible bounds
    expect(contentView.contentSize) == CGSize(width: 100, height: 100)
    expect(isTopRendered) == true
    expect(isBottomRendered) == true
  }

  // MARK: - sizeThatFits

  func test_sizeThatFits() {
    // given: a compose view with a flexible-width, fixed-height node
    let contentView = ComposeView {
      LayerNode()
        .frame(width: .flexible, height: 30)
    }

    // then: the fitting size adopts the proposed width and keeps the fixed height
    expect(contentView.sizeThatFits(CGSize(width: 10, height: 10))) == CGSize(width: 10, height: 30)
    expect(contentView.sizeThatFits(CGSize(width: 50, height: 50))) == CGSize(width: 50, height: 30)
  }

  func test_sizeThatFits_contentInsets_includesThem() {
    // given: a view with 10 pt content insets, showing 50 × 50 content
    let view = ComposeView {
      LayerNode()
        .frame(width: 50, height: 50)
    }
    view.contentInset = EdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

    // when: measuring a 200 × 200 proposal
    let size = view.sizeThatFits(CGSize(width: 200, height: 200))

    // then: the fitting size is the content plus the insets
    expect(size) == CGSize(width: 70, height: 70)

    // when: the view takes that size and renders
    view.frame = CGRect(origin: .zero, size: size)
    view.refresh(animated: false)

    // then: the content fits between the insets, so the view doesn't scroll
    expect(view.isScrollEnabled) == false
  }

  func test_sizeThatFits_contentInsets_laysOutTheContentBetweenThem() {
    // given: a view with 20 pt side insets and 5 pt top and bottom insets, whose content is half as tall as the width it
    // lays out in
    let view = ComposeView {
      ViewNode<BaseView>(intrinsicSize: { CGSize(width: $0.width, height: $0.width / 2) })
        .fixedSize(width: false, height: true)
    }
    view.contentInset = EdgeInsets(top: 5, left: 20, bottom: 5, right: 20)

    // then: for a 100 pt wide proposal, the content lays out in the 60 pt between the side insets, so it's 30 pt tall,
    // and the fitting size adds the insets
    expect(view.sizeThatFits(CGSize(width: 100, height: 300))) == CGSize(width: 100, height: 40)

    // then: for a proposal narrower than the side insets, the content lays out in no width
    expect(view.sizeThatFits(CGSize(width: 30, height: 300))) == CGSize(width: 40, height: 10)
  }

  func test_sizeThatFits_doesNotReplaceReusedContent() throws {
    // given: rendered content whose next configuration has a different color and height
    var color = Color.red
    var height: CGFloat = 300
    var layer: CALayer?
    var contentMakeCount = 0
    let view = ComposeView {
      contentMakeCount += 1
      ColorNode(color)
        .frame(width: .flexible, height: height)
        .onUpdate { renderable, _ in layer = renderable.layer }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let originalLayer = try unwrap(layer)
    color = .blue
    height = 400

    // when: fresh content is measured with a different proposal
    let measuredSize = view.sizeThatFits(CGSize(width: 200, height: 80))

    // then: measurement observes fresh configuration without installing it
    expect(measuredSize) == CGSize(width: 200, height: 400)
    expect(contentMakeCount) == 2
    expect(view.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
    expect(layer?.frame) == CGRect(x: 0, y: 0, width: 100, height: 300)
    expect(layer?.backgroundColor) == Color.red.cgColor

    // when: the displayed content scrolls and resizes after measurement
    view.contentOffset = CGPoint(x: 0, y: 20)
    view.layoutIfNeeded()
    view.frame.size.width = 150
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the reused tree still uses its original configuration with new frames
    expect(contentMakeCount) == 2
    expect(layer) === originalLayer
    expect(layer?.frame) == CGRect(x: 0, y: 0, width: 150, height: 300)
    expect(layer?.backgroundColor) == Color.red.cgColor

    // when: fresh content is measured while an explicit refresh is pending
    view.setNeedsRefresh(animated: false)
    expect(view.sizeThatFits(CGSize(width: 250, height: 50))) == CGSize(width: 250, height: 400)

    // then: measurement does not perform the pending refresh
    expect(contentMakeCount) == 3
    expect(layer?.backgroundColor) == Color.red.cgColor
    expect(layer?.frame) == CGRect(x: 0, y: 0, width: 150, height: 300)

    // when: layout fulfills the pending refresh
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the fresh configuration is now committed to the same renderable
    expect(contentMakeCount) == 4
    expect(layer) === originalLayer
    expect(layer?.backgroundColor) == Color.blue.cgColor
    expect(layer?.frame) == CGRect(x: 0, y: 0, width: 150, height: 400)
  }

  func test_sizeThatFits_measuresNewBuilderBeforeScheduledRefresh() throws {
    // given: an existing red renderable and a replacement builder waiting to be displayed
    var layer: CALayer?
    let view = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: 30)
        .onUpdate { renderable, _ in
          layer = renderable.layer
        }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let originalLayer = try unwrap(layer)
    view.setContent {
      ColorNode(.blue)
        .frame(width: .flexible, height: 80)
        .onUpdate { renderable, _ in
          layer = renderable.layer
        }
    }

    // when: measuring the replacement before its scheduled refresh
    let measuredSize = view.sizeThatFits(CGSize(width: 200, height: 200))

    // then: measurement uses the new builder without replacing the displayed content
    expect(measuredSize) == CGSize(width: 200, height: 80)
    expect(layer) === originalLayer
    expect(layer?.backgroundColor) == Color.red.cgColor
    expect(layer?.bounds.size) == CGSize(width: 100, height: 30)
    expect(view.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: layout performs the pending refresh
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the same renderable receives the replacement configuration and frame
    expect(layer) === originalLayer
    expect(layer?.backgroundColor) == Color.blue.cgColor
    expect(layer?.bounds.size) == CGSize(width: 100, height: 80)
  }

  func test_sizeThatFits_usesProposedSizeForIntrinsicLayout() throws {
    // given: a view whose intrinsic height follows its proposed width
    var renderedView: BaseView?
    let view = ComposeView {
      ViewNode<BaseView>(intrinsicSize: { CGSize(width: $0.width, height: $0.width / 2) })
        .fixedSize(width: false, height: true)
        .onUpdate { renderable, _ in renderedView = renderable.view as? BaseView }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let originalView = try unwrap(renderedView)

    // when: measuring proposals different from the host bounds
    let wideSize = view.sizeThatFits(CGSize(width: 200, height: 300))
    let narrowSize = view.sizeThatFits(CGSize(width: 40, height: 300))

    // then: intrinsic layout uses each proposal without changing the mounted view
    expect(wideSize) == CGSize(width: 200, height: 100)
    expect(narrowSize) == CGSize(width: 40, height: 20)
    expect(originalView.bounds.size) == CGSize(width: 100, height: 50)

    // when: the mounted content resizes
    view.frame.size.width = 160
    view.setNeedsLayout()
    view.layoutIfNeeded()

    // then: the reused view adapts to its own new proposal
    expect(renderedView) === originalView
    expect(originalView.bounds.size) == CGSize(width: 160, height: 80)
  }

  func test_sizeThatFits_doesNotDisturbNestedContent() throws {
    // given: a nested compose view with flexible-width content
    var nestedView: ComposeView?
    var layer: CALayer?
    let view = ComposeView {
      ComposeViewNode {
        ColorNode(.red)
          .frame(width: .flexible, height: 300)
          .onUpdate { renderable, _ in layer = renderable.layer }
      }
      .fixedSize(width: false, height: true)
      .onUpdate { renderable, _ in nestedView = renderable.view as? ComposeView }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)
    let nested = try unwrap(nestedView)
    nested.setNeedsLayout()
    nested.layoutIfNeeded()
    let originalLayer = try unwrap(layer)

    // when: fresh content is measured and the mounted content is resized
    expect(view.sizeThatFits(CGSize(width: 250, height: 150))) == CGSize(width: 250, height: 300)
    view.frame.size.width = 180
    view.setNeedsLayout()
    view.layoutIfNeeded()
    nested.setNeedsLayout()
    nested.layoutIfNeeded()

    // then: the nested content renders the mounted proposal rather than the measurement proposal
    expect(nestedView) === nested
    expect(layer) === originalLayer
    expect(nested.visibleSize) == CGSize(width: 180, height: 300)
    expect(layer?.frame) == CGRect(x: 0, y: 0, width: 180, height: 300)
    expect(layer?.backgroundColor) == Color.red.cgColor

    // when: the outer view scrolls without another layout proposal
    view.contentOffset = CGPoint(x: 0, y: 20)
    view.layoutIfNeeded()

    // then: the nested frames remain consistent
    expect(layer?.frame) == CGRect(x: 0, y: 0, width: 180, height: 300)
    expect(nested.frame) == CGRect(x: 0, y: 0, width: 180, height: 300)
  }

  // MARK: - Scroll View Settings

  func test_contentInsetAdjustmentBehavior() {
    // then: automatic content inset adjustment is disabled
    #if canImport(AppKit)
    expect(contentView.automaticallyAdjustsContentInsets) == false
    #endif
    #if canImport(UIKit)
    expect(contentView.contentInsetAdjustmentBehavior) == .never
    #endif
  }

  #if canImport(AppKit)
  func test_automaticallyAdjustsContentInsets_staysOff() {
    // given: a compose view filling a window whose title bar and toolbar overlap it, and a handler that records the
    // assertions
    let window = NSWindow(
      contentRect: CGRect(x: 0, y: 0, width: 400, height: 300),
      styleMask: [.titled, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.toolbar = NSToolbar(identifier: "ComposeViewTests")
    let view = ComposeView()
    window.contentView = view

    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: the automatic adjustment is turned off
    view.automaticallyAdjustsContentInsets = false

    // then: nothing asserts
    expect(assertionMessages) == []

    // when: the automatic adjustment is turned on, and the window lays out
    view.automaticallyAdjustsContentInsets = true
    window.layoutIfNeeded()

    // then: it asserts and stays off, so the content insets leave out the overlap
    expect(assertionMessages) == ["ComposeView doesn't support adjusting the content insets automatically"]
    expect(view.automaticallyAdjustsContentInsets) == false
    expect(view.bounds.height - window.contentLayoutRect.height) > 0
    expect(view.contentInset.top) == 0
  }

  func test_magnification_staysOne() {
    // given: a 100 × 100 compose view, and a handler that records the assertions
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: magnification is disallowed, and the magnification and its range are set to 1
    view.allowsMagnification = false
    view.magnification = 1
    view.setMagnification(1, centeredAt: CGPoint(x: 50, y: 50))
    view.minMagnification = 1
    view.maxMagnification = 1

    // then: nothing asserts
    expect(assertionMessages) == []

    // when: magnification is allowed
    view.allowsMagnification = true

    // then: it asserts and stays disallowed
    expect(assertionMessages) == ["ComposeView doesn't support magnification"]
    expect(view.allowsMagnification) == false

    // when: the magnification range is widened
    view.minMagnification = 0.25
    view.maxMagnification = 4

    // then: each asserts, and the range stays at 1
    expect(assertionMessages) == Array(repeating: "ComposeView doesn't support magnification", count: 3)
    expect(view.minMagnification) == 1
    expect(view.maxMagnification) == 1

    // when: the view is magnified through each of AppKit's magnifying APIs
    view.magnification = 2
    view.setMagnification(2, centeredAt: CGPoint(x: 50, y: 50))
    view.magnify(toFit: CGRect(x: 0, y: 0, width: 400, height: 400))

    // then: each asserts, and the magnification stays 1, so the visible area keeps the view's size
    expect(assertionMessages) == Array(repeating: "ComposeView doesn't support magnification", count: 6)
    expect(view.magnification) == 1
    expect(view.visibleSize) == CGSize(width: 100, height: 100)
  }

  func test_magnification_animator_staysOne() {
    // given: a 100 × 100 compose view in a window, showing fifty 10 pt rows, referenced as an `NSScrollView`, where the
    // animator's magnifying methods don't call the view's overrides
    let window = TestWindow()
    let view = ComposeView {
      VStack {
        for _ in 0 ..< 50 {
          LayerNode().frame(width: .flexible, height: 10)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    window.contentView().addSubview(view)
    view.refresh(animated: false)
    let scrollView: NSScrollView = view

    ComposeUI.Assert.setTestAssertionFailureHandler { _, _, _, _ in }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    let magnifyingCalls: [(NSScrollView) -> Void] = [
      { $0.animator().setMagnification(0.25, centeredAt: CGPoint(x: 50, y: 50)) },
      { $0.animator().magnify(toFit: CGRect(x: 0, y: 0, width: 400, height: 400)) },
    ]
    for magnify in magnifyingCalls {
      // when: the view is magnified through the animator, and the animation finishes
      var isFinished = false
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.05
        magnify(scrollView)
      } completionHandler: {
        isFinished = true
      }
      expect(isFinished).toEventually(beTrue())
      view.refresh(animated: false)

      // then: the magnification stays 1, so the clip view keeps the view's size, and the rendered rows are the visible
      // ones at their full width
      expect(view.magnification) == 1
      expect(view.contentView.bounds.size) == CGSize(width: 100, height: 100)
      let visibleBounds = view.contentView.bounds
      let rowFrames = (view.documentView?.layer?.sublayers ?? []).map(\.frame).filter { $0.height == 10 }
      let visibleRows = Int((visibleBounds.minY / 10).rounded(.down)) ..< Int((visibleBounds.maxY / 10).rounded(.up))
      expect(rowFrames.sorted { $0.minY < $1.minY }) == visibleRows.map { CGRect(x: 0, y: CGFloat($0) * 10, width: 100, height: 10) }
    }
  }

  func test_borderType_staysNoBorder() {
    // given: a 100 × 100 compose view, and a handler that records the assertions
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: the view is set to have no border
    view.borderType = .noBorder

    // then: nothing asserts
    expect(assertionMessages) == []

    // when: the view is given each border, and it tiles
    for borderType in [NSBorderType.lineBorder, .bezelBorder, .grooveBorder] {
      view.borderType = borderType
    }
    view.tile()

    // then: each asserts, and the view stays borderless, so the clip view fills it
    expect(assertionMessages) == Array(repeating: "ComposeView doesn't support borders", count: 3)
    expect(view.borderType) == .noBorder
    expect(view.contentView.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)
  }

  func test_autohidesScrollers_staysOff() {
    // given: a 100 × 100 compose view, and a handler that records the assertions
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: auto-hiding is turned off
    view.autohidesScrollers = false

    // then: nothing asserts, and it's off
    expect(assertionMessages) == []
    expect(view.autohidesScrollers) == false

    // when: auto-hiding is turned on
    view.autohidesScrollers = true

    // then: it asserts and stays off
    expect(assertionMessages) == ["ComposeView doesn't support auto-hiding scrollers"]
    expect(view.autohidesScrollers) == false
  }

  func test_rulersVisible_staysOff() {
    // given: a 100 × 100 compose view with a vertical ruler, and a handler that records the assertions
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.hasVerticalRuler = true

    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: the rulers are hidden
    view.rulersVisible = false

    // then: nothing asserts, and they're hidden
    expect(assertionMessages) == []
    expect(view.rulersVisible) == false

    // when: the rulers are shown, and the view tiles
    view.rulersVisible = true
    view.tile()

    // then: it asserts, and the rulers stay hidden, so they take no room from the content
    expect(assertionMessages) == ["ComposeView doesn't support rulers"]
    expect(view.rulersVisible) == false
    let insets = view.adjustedContentInset
    expect([insets.top, insets.left, insets.bottom, insets.right]) == [0, 0, 0, 0]
  }

  func test_isFindBarVisible_staysOff() {
    // given: a 100 × 100 compose view with a 30 pt tall find bar view, and a handler that records the assertions
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.findBarView = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 30))

    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: the find bar is hidden
    view.isFindBarVisible = false

    // then: nothing asserts, and it's hidden
    expect(assertionMessages) == []
    expect(view.isFindBarVisible) == false

    // when: the find bar is shown, and the view tiles
    view.isFindBarVisible = true
    view.tile()

    // then: it asserts, and the find bar stays hidden, so it takes no room from the content
    expect(assertionMessages) == ["ComposeView doesn't support the find bar"]
    expect(view.isFindBarVisible) == false
    let insets = view.adjustedContentInset
    expect([insets.top, insets.left, insets.bottom, insets.right]) == [0, 0, 0, 0]
  }
  #endif

  #if os(iOS)
  func test_contentInsetAdjustmentBehavior_automatic_rendersTheVisibleRows() {
    // given: a compose view showing fifty 20 pt rows, set to adjust its content insets automatically, as the root view
    // of a view controller in a navigation controller
    let view = ComposeView {
      VStack {
        for _ in 0 ..< 50 {
          LayerNode().frame(width: .flexible, height: 20)
        }
      }
    }
    view.contentInsetAdjustmentBehavior = .automatic
    let viewController = UIViewController()
    viewController.view = view
    let window = TestWindow()
    window.rootViewController = UINavigationController(rootViewController: viewController)

    // when: the window shows and lays out
    window.makeKeyAndVisible()
    window.layoutIfNeeded()
    view.layoutIfNeeded()

    // then: UIKit insets the content by the navigation bar, and shows its top right below the bar
    expect(view.contentInsetAdjustmentBehavior) == .automatic
    expect(view.adjustedContentInset.top) > 0
    expect(view.contentOffset.y) == -view.adjustedContentInset.top

    // then: the rendered rows are the ones in the visible area
    let rowFrames = (view.layer.sublayers ?? []).map(\.frame).filter { $0.size == CGSize(width: view.bounds.width, height: 20) }
    let visibleRowCount = Int((view.bounds.maxY / 20).rounded(.up))
    expect(rowFrames.sorted { $0.minY < $1.minY }) == (0 ..< visibleRowCount).map { CGRect(x: 0, y: CGFloat($0) * 20, width: view.bounds.width, height: 20) }
  }

  func test_contentInsetAdjustmentBehavior_automatic_contentFittingTheViewButNotBetweenTheBars_scrollsIntoView() throws {
    // given: a compose view set to adjust its content insets automatically, as the root view of a view controller in a
    // navigation controller, laid out in a window, so UIKit insets it by the navigation bar and the home indicator
    var rowCount = 0
    let view = ComposeView {
      VStack {
        for _ in 0 ..< rowCount {
          LayerNode().frame(width: .flexible, height: 20)
        }
      }
    }
    view.contentInsetAdjustmentBehavior = .automatic
    let viewController = UIViewController()
    viewController.view = view
    let window = TestWindow()
    window.rootViewController = UINavigationController(rootViewController: viewController)
    window.makeKeyAndVisible()
    window.layoutIfNeeded()
    let insets = view.adjustedContentInset
    expect(insets.top) > 0
    expect(insets.bottom) > 0

    // when: the view shows 20 pt rows that fit its height, but not the height between the insets
    let contentHeight = view.bounds.height - (insets.top + insets.bottom) / 2
    rowCount = Int(contentHeight / 20)
    view.refresh(animated: false)

    // then: the rows overflow the space between the insets, so the view scrolls, and the rows start at the top of the
    // content instead of centering, which at rest leaves the last one below the bottom inset
    expect(view.isScrollEnabled) == true
    let lastRowMaxY = CGFloat(rowCount) * 20
    expect(lastRowMaxY - view.contentOffset.y) > view.bounds.height - insets.bottom

    // when: the view scrolls to the end
    view.contentOffset = CGPoint(x: 0, y: view.maxOffsetY)
    view.layoutIfNeeded()

    // then: the last row shows above the bottom inset
    let renderedLastRowMaxY = try unwrap((view.layer.sublayers ?? []).map(\.frame).filter { $0.height == 20 }.map(\.maxY).max())
    expect(renderedLastRowMaxY) == lastRowMaxY
    expect(renderedLastRowMaxY - view.contentOffset.y) <= view.bounds.height - insets.bottom
  }

  func test_contentInsetAdjustmentBehavior_automatic_insetChange_laysOutTheContentBetweenTheNewInsets() {
    // given: a compose view showing content that fills the container it lays out in, set to adjust its content insets
    // automatically, as the root view of a view controller in a navigation controller, laid out in a window
    var contentLayer: CALayer?
    let view = ComposeView {
      LayerNode<CALayer>(update: { layer, _ in contentLayer = layer })
        .frame(width: .flexible, height: .flexible)
    }
    view.contentInsetAdjustmentBehavior = .automatic
    let viewController = UIViewController()
    viewController.view = view
    let window = TestWindow()
    window.rootViewController = UINavigationController(rootViewController: viewController)
    window.makeKeyAndVisible()
    window.layoutIfNeeded()
    view.layoutIfNeeded()
    let insets = view.adjustedContentInset
    let boundsSize = view.bounds.size
    expect(contentLayer?.frame.height) == boundsSize.height - insets.top - insets.bottom

    // when: the view controller's top safe area grows by 30 pt, which changes the insets without resizing the view
    viewController.additionalSafeAreaInsets.top = 30
    window.layoutIfNeeded()
    view.layoutIfNeeded()

    // then: the view renders again, with the content in the space the larger insets leave
    expect(view.bounds.size) == boundsSize
    expect(view.adjustedContentInset.top) == insets.top + 30
    expect(contentLayer?.frame.height) == boundsSize.height - insets.top - 30 - insets.bottom
  }
  #endif

  // MARK: - Theme

  func test_theme_duringARenderPass_staysTheThemeThePassReadFirst() throws {
    // given: a compose view in the light theme, whose first node reads the theme and then changes the view's appearance
    // to dark when it updates, and whose second node has a themed color
    var themesReadByTheUpdates: [Theme] = []
    var themedLayer: CALayer?
    let view = ComposeView {
      VStack {
        ColorNode(.clear)
          .frame(width: 10, height: 10)
          .onUpdate { _, context in
            themesReadByTheUpdates.append(context.contentView.theme)
            Self.setAppearance(of: context.contentView, to: .dark)
          }
        ColorNode(ThemedColor(light: .red, dark: .blue))
          .frame(width: 10, height: 10)
          .onUpdate { renderable, context in
            themedLayer = renderable.layer
            themesReadByTheUpdates.append(context.contentView.theme)
          }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.overrideTheme = .light

    // when: refreshing
    view.refresh(animated: false)

    // then: the updates read the light theme that the pass read first, and the themed color is light, while the view is
    // dark after the pass
    expect(themesReadByTheUpdates) == [.light, .light]
    expect(try unwrap(themedLayer).backgroundColor) == Color.red.cgColor
    expect(view.theme) == .dark

    // when: refreshing again
    themesReadByTheUpdates = []
    view.refresh(animated: false)

    // then: the updates read the dark theme, and the themed color is dark
    expect(themesReadByTheUpdates) == [.dark, .dark]
    expect(try unwrap(themedLayer).backgroundColor) == Color.blue.cgColor
  }

  func test_themePublisher_themeChangedDuringARenderPass_publishesTheChange() {
    // given: a compose view in a window, in the light theme, whose node can change the view's appearance to dark when
    // it updates, and the themes its theme publisher publishes
    var changesTheTheme = false
    let view = ComposeView {
      ColorNode(.clear)
        .frame(width: 10, height: 10)
        .onUpdate { _, context in
          if changesTheTheme {
            Self.setAppearance(of: context.contentView, to: .dark)
          }
        }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.overrideTheme = .light
    let window = TestWindow()
    window.contentView().addSubview(view)
    var publishedThemes: [Theme] = []
    let cancellable = view.themePublisher.sink { publishedThemes.append($0) }
    expect(publishedThemes.last == .light).toEventually(beTrue())

    // when: refreshing, with the node changing the theme during the pass
    publishedThemes = []
    changesTheTheme = true
    view.refresh(animated: false)

    // then: the change made during the pass is published, since the view's own bookkeeping reads its appearance
    expect(publishedThemes).toEventually(beEqual(to: [.dark]))
    cancellable.cancel()
  }

  func test_overrideTheme_duringARenderPass_assertsAndKeepsTheCurrentValue() {
    // given: a compose view in the light theme, whose node sets the override theme to dark when it updates, and the
    // assertions it makes
    var overrideThemeAfterTheSet: Theme?
    let view = ComposeView {
      ColorNode(.clear)
        .frame(width: 10, height: 10)
        .onUpdate { _, context in
          context.contentView.overrideTheme = .dark
          overrideThemeAfterTheSet = context.contentView.overrideTheme
        }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.overrideTheme = .light
    var assertionMessages: [String] = []
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      ComposeUI.Assert.resetTestAssertionFailureHandler()
    }

    // when: refreshing
    view.refresh(animated: false)

    // then: setting the override theme during the pass asserts and keeps the light theme
    expect(assertionMessages) == ["ComposeView doesn't support changing the theme during its render pass"]
    expect(overrideThemeAfterTheSet) == .light
    expect(view.overrideTheme) == .light
    expect(view.theme) == .light
  }

  func test_theme_outsideARenderPass_followsTheAppearance() {
    // given: a compose view in the light theme, whose theme is read
    contentView.overrideTheme = .light
    expect(contentView.theme) == .light

    // when: the theme changes outside a render pass
    contentView.overrideTheme = .dark

    // then: the theme is the new one
    expect(contentView.theme) == .dark
  }

  func test_theme_offTheMainThread_isTheViewsTheme() {
    // given: a compose view in the dark theme
    contentView.overrideTheme = .dark

    // when: reading its theme off the main thread
    var theme: Theme?
    let expectation = XCTestExpectation(description: "theme")
    DispatchQueue.global().async { [contentView] in
      theme = contentView?.theme
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1)

    // then: it's the view's theme
    expect(theme) == .dark
  }

  func test_overrideTheme_offTheMainThread_setsTheTheme() {
    // given: a compose view in the light theme
    contentView.overrideTheme = .light

    // when: setting its override theme to dark off the main thread
    let expectation = XCTestExpectation(description: "override theme")
    DispatchQueue.global().async { [contentView] in
      contentView?.overrideTheme = .dark
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1)

    // then: the view is dark
    expect(contentView.overrideTheme) == .dark
    expect(contentView.theme) == .dark
  }

  // MARK: - Helpers

  /// Changes the view's appearance to the theme without `overrideTheme`, as a change of an ancestor's appearance would.
  private static func setAppearance(of view: ComposeView, to theme: Theme) {
    #if canImport(AppKit)
    view.appearance = NSAppearance(named: theme.isLight ? .aqua : .darkAqua)
    #endif
    #if canImport(UIKit)
    view.overrideUserInterfaceStyle = theme.isLight ? .light : .dark
    #endif
  }
}
