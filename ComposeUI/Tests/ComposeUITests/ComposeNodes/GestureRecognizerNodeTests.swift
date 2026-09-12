//
//  GestureRecognizerNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 7/30/25.
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

import ChouTi
@testable import ComposeUI

class GestureRecognizerNodeTests: XCTestCase {

  // MARK: - Basic Node Tests

  func test_nodeSize() {
    // given: a layer node with a tap handler
    let baseNode = LayerNode()
    var gestureNode = baseNode.onTap { _ in }
    let containerSize = CGSize(width: 200, height: 100)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)

    // when: laying out in the container
    gestureNode.layout(containerSize: containerSize, context: context)

    // then: the node size matches the container size
    expect(gestureNode.size) == containerSize
  }

  // MARK: - Renderable Items Tests

  func test_renderableItems() throws {
    // given: a laid out framed color node with a tap handler
    var node = ColorNode(.red).frame(width: 100, height: 50).onTap { _ in }

    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when: visible bounds intersects with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)

      // then: the color item and a gesture overlay item are provided with the expected behaviors
      expect(items.count) == 2

      let item = items[1]
      expect(item.id.id) == "G"
      expect(item.frame) == CGRect(x: 0, y: 0, width: 100, height: 50)

      // make
      do {
        let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: nil))
        expect(renderable.view?.frame) == CGRect(x: 1, y: 2, width: 3, height: 4)
      }

      expect(item.willInsert) == nil
      expect(item.didInsert) == nil
      expect(item.willUpdate) == nil

      // update
      do {
        // normal update
        do {
          let contentView = ComposeView()
          let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

          let context = RenderableUpdateContext(updateType: .refresh, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
          item.update(renderable, context)
          let view = try (renderable.view).unwrap()
          let viewLookup = DynamicLookup(view)
          expect((viewLookup.property("handlers") as? [AnyHashable: Any])?.count) == 1
          expect((viewLookup.property("installedGestureRecognizers") as? [AnyHashable: Any])?.count) == 1

          expect((view as? GestureRecognizerDelegate)?.gestureRecognizer?(GestureRecognizer(), shouldRecognizeSimultaneouslyWith: GestureRecognizer())) == true
        }

        // update with various update types
        do {
          // given: an unconfigured gesture overlay
          let contentView = ComposeView()
          let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))
          let view = try renderable.view.unwrap()

          // when: updating for a scroll
          item.update(renderable, RenderableUpdateContext(updateType: .scroll, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView))

          // then: no gesture recognizers are installed
          let unconfiguredRecognizers: [GestureRecognizer]? = view.gestureRecognizers
          expect(unconfiguredRecognizers?.isEmpty ?? true) == true

          // when: updating for a bounds change
          item.update(renderable, RenderableUpdateContext(updateType: .boundsChange, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView))

          // then: geometry updates do not install gesture recognizers
          let resizedRecognizers: [GestureRecognizer]? = view.gestureRecognizers
          expect(resizedRecognizers?.isEmpty ?? true) == true

          // when: inserting the gesture overlay
          item.update(renderable, RenderableUpdateContext(updateType: .insert, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView))

          // then: insertion installs the configured tap recognizer
          let recognizers: [GestureRecognizer]? = view.gestureRecognizers
          expect(recognizers?.count) == 1
          let tapRecognizer = try (recognizers?.first as? TapGestureRecognizer).unwrap()
          expect(tapRecognizer.view === view) == true
          #if canImport(AppKit)
          expect(tapRecognizer.numberOfClicksRequired) == 1
          #endif
          #if canImport(UIKit)
          expect(tapRecognizer.numberOfTapsRequired) == 1
          #endif
        }
      }

      expect(item.willRemove) == nil
      expect(item.didRemove) == nil
      expect(item.transition) == nil
      expect(item.animationTiming) == nil
    }

    // when: visible bounds does not intersect with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 100, width: 100, height: 100)
      let items = node.renderableItems(in: visibleBounds)

      // then: no items are provided
      expect(items.count) == 0
    }
  }

  func test_renderableItemsBoundingRect() {
    // given: a layout context
    let context = ComposeNodeLayoutContext(scaleFactor: 1)

    // when: laying out a node whose child items are within the node's bounds
    do {
      var node = ColorNode(.red).frame(width: 100, height: 50).onTap { _ in }
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the bounding rect is the child items rect
      expect(node.renderableItemsBoundingRect) == CGRect(x: 0, y: 0, width: 100, height: 50)
    }

    // when: laying out a node whose child items are outside of the node's bounds
    do {
      var node = ColorNode(.red).frame(width: 50, height: 50).offset(x: -10, y: -10).onTap { _ in }
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the bounding rect should include both the child items rect and the gesture overlay (the node's bounds)
      expect(node.renderableItemsBoundingRect) == CGRect(x: -10, y: -10, width: 60, height: 60)
    }

    // when: laying out a node whose child has no renderable items
    do {
      var node = Spacer().onTap { _ in }
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the node provides no items, including the gesture overlay
      expect(node.renderableItemsBoundingRect.isNull) == true
    }
  }

  // MARK: - Gesture Handler Coalescing Tests

  func test_gestureHandlerCoalescing() {
    // given: a laid out node with tap and press handlers
    let baseNode = LayerNode().frame(width: 100, height: 50)

    var tapCallCount = 0
    var pressCallCount = 0

    var gestureNode = baseNode
      .onTap { _ in tapCallCount += 1 }
      .onPress { _ in pressCallCount += 1 }

    let containerSize = CGSize(width: 200, height: 100)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)
    gestureNode.layout(containerSize: containerSize, context: context)

    // when: requesting renderable items
    let renderableItems = gestureNode.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    // then: should still only have base node items + single gesture overlay view
    expect(renderableItems.count) == 2

    // then: the gesture overlay should handle both gestures
    let gestureItem = renderableItems.last
    expect(gestureItem?.id) == .standard(.gesture)
  }

  func test_multipleGestureCoalescing() {
    // given: a laid out node with multiple gesture handlers
    let baseNode = LayerNode().frame(width: 100, height: 50)

    var gestureNode = baseNode
      .onTap(count: 1) { _ in }
      .onTap(count: 2) { _ in }
      .onPress(duration: 0.5) { _ in }
      .onPan { _ in }

    let containerSize = CGSize(width: 200, height: 100)
    let context = ComposeNodeLayoutContext(scaleFactor: 2)
    gestureNode.layout(containerSize: containerSize, context: context)

    // when: requesting renderable items
    let renderableItems = gestureNode.renderableItems(in: CGRect(x: 0, y: 0, width: 100, height: 50))

    // then: should still only have base node items + single gesture overlay view
    expect(renderableItems.count) == 2
  }

  // MARK: - Integration Tests

  func test_geometryUpdates_retainGestureRecognizers_untilRefresh() throws {
    // given: a fixed-size gesture node configured from the container width
    var additionalTapCount = 0
    var renderedGestureView: View?
    var updateType: RenderableUpdateType?
    let contentView = ComposeView { contentView in
      let isNarrow = contentView.bounds().width < 150
      let color: Color = isNarrow ? .red : .blue
      VStack(alignment: .left) {
        LayerNode()
          .frame(width: 80, height: 120)
          .onTap(count: (isNarrow ? 1 : 2) + additionalTapCount) { recognizer in
            recognizer.view?.layer().backgroundColor = color.cgColor
          }
          .onPress(duration: isNarrow ? 0.25 : 0.75) { _ in }
          .onUpdate { renderable, context in
            if let view = renderable.view {
              renderedGestureView = view
              updateType = context.updateType
            }
          }
        Spacer()
          .frame(width: .flexible, height: 180)
      }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    contentView.scrollIndicatorBehavior = .never

    // when: rendering in the narrow container
    contentView.refresh(animated: false)

    // then: insertion installs the requested tap and press recognizers
    let gestureView = try renderedGestureView.unwrap()
    let itemFrame = CGRect(x: 0, y: 0, width: 80, height: 120)
    let initialRecognizers: [GestureRecognizer]? = gestureView.gestureRecognizers
    let initialTap = try (initialRecognizers?.compactMap { $0 as? TapGestureRecognizer }.first).unwrap()
    let initialPress = try (initialRecognizers?.compactMap { $0 as? PressGestureRecognizer }.first).unwrap()
    expect(updateType) == .insert
    expect(gestureView.frame) == itemFrame
    expect(initialRecognizers?.count) == 2
    expect(initialTap.view === gestureView) == true
    expect(initialPress.view === gestureView) == true
    #if canImport(AppKit)
    expect(initialTap.numberOfClicksRequired) == 1
    #endif
    #if canImport(UIKit)
    expect(initialTap.numberOfTapsRequired) == 1
    #endif
    expect(initialPress.minimumPressDuration) == 0.25

    // when: dispatching the installed tap action
    _ = gestureView.perform(NSSelectorFromString("handleGesture:"), with: initialTap)

    // then: the configured handler produces the narrow color
    expect(gestureView.layer().backgroundColor) == Color.red.cgColor

    // when: resizing the container without refreshing explicitly
    contentView.frame.size.width = 200
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: the same overlay retains its recognizers and configuration
    let resizedRecognizers: [GestureRecognizer]? = gestureView.gestureRecognizers
    expect(updateType) == .boundsChange
    expect(renderedGestureView === gestureView) == true
    expect(gestureView.frame) == itemFrame
    expect(resizedRecognizers?.count) == 2
    expect(resizedRecognizers?.contains { $0 === initialTap }) == true
    expect(resizedRecognizers?.contains { $0 === initialPress }) == true
    expect(initialTap.view === gestureView) == true
    expect(initialPress.view === gestureView) == true
    #if canImport(AppKit)
    expect(initialTap.numberOfClicksRequired) == 1
    #endif
    #if canImport(UIKit)
    expect(initialTap.numberOfTapsRequired) == 1
    #endif
    expect(initialPress.minimumPressDuration) == 0.25

    // when: dispatching the retained tap action after resize
    gestureView.layer().backgroundColor = nil
    _ = gestureView.perform(NSSelectorFromString("handleGesture:"), with: initialTap)

    // then: the handler still uses the retained configuration
    expect(gestureView.layer().backgroundColor) == Color.red.cgColor

    // when: scrolling with changed data but without an explicit refresh
    additionalTapCount = 1
    contentView.setContentOffset(CGPoint(x: 0, y: 50))
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: the visible overlay retains its installed recognizers
    let scrolledRecognizers: [GestureRecognizer]? = gestureView.gestureRecognizers
    expect(updateType) == .scroll
    expect(renderedGestureView === gestureView) == true
    expect(gestureView.frame) == itemFrame
    expect(scrolledRecognizers?.count) == 2
    expect(scrolledRecognizers?.contains { $0 === initialTap }) == true
    expect(scrolledRecognizers?.contains { $0 === initialPress }) == true

    // when: dispatching the retained tap action after scroll
    gestureView.layer().backgroundColor = nil
    _ = gestureView.perform(NSSelectorFromString("handleGesture:"), with: initialTap)

    // then: scrolling preserves the handler's rendered output
    expect(gestureView.layer().backgroundColor) == Color.red.cgColor

    // when: refreshing the changed gesture data at the same container size
    contentView.refresh(animated: false)

    // then: the same overlay installs the refreshed handler configuration
    let refreshedRecognizers: [GestureRecognizer]? = gestureView.gestureRecognizers
    let refreshedTap = try (refreshedRecognizers?.compactMap { $0 as? TapGestureRecognizer }.first).unwrap()
    let refreshedPress = try (refreshedRecognizers?.compactMap { $0 as? PressGestureRecognizer }.first).unwrap()
    expect(updateType) == .refresh
    expect(renderedGestureView === gestureView) == true
    expect(gestureView.frame) == itemFrame
    expect(refreshedRecognizers?.count) == 2
    expect(initialTap.view) == nil
    expect(initialPress.view) == nil
    expect(refreshedTap.view === gestureView) == true
    expect(refreshedPress.view === gestureView) == true
    #if canImport(AppKit)
    expect(refreshedTap.numberOfClicksRequired) == 3
    #endif
    #if canImport(UIKit)
    expect(refreshedTap.numberOfTapsRequired) == 3
    #endif
    expect(refreshedPress.minimumPressDuration) == 0.75

    // when: dispatching the refreshed tap action
    _ = gestureView.perform(NSSelectorFromString("handleGesture:"), with: refreshedTap)

    // then: refresh supplies the new handler output
    expect(gestureView.layer().backgroundColor) == Color.blue.cgColor
  }

  func test_boundsChange_retainsGestureIdentity_withUnchangedSettings() throws {
    // given: a flexible gesture node with constant settings
    var renderedGestureView: View?
    let contentView = ComposeView {
      LayerNode()
        .onTap(count: 2) { recognizer in
          recognizer.view?.layer().backgroundColor = Color.green.cgColor
        }
        .onPress(duration: 0.75) { _ in }
        .onPan { _ in }
        .onUpdate { renderable, _ in
          if let view = renderable.view {
            renderedGestureView = view
          }
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    contentView.refresh(animated: false)
    let gestureView = try renderedGestureView.unwrap()
    let initialRecognizers: [GestureRecognizer]? = gestureView.gestureRecognizers
    let tap = try (initialRecognizers?.compactMap { $0 as? TapGestureRecognizer }.first).unwrap()
    let press = try (initialRecognizers?.compactMap { $0 as? PressGestureRecognizer }.first).unwrap()
    let pan = try (initialRecognizers?.compactMap { $0 as? PanGestureRecognizer }.first).unwrap()

    // then: the overlay begins at the original size
    expect(gestureView.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: resizing without changing gesture settings
    contentView.frame.size = CGSize(width: 200, height: 150)
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: the overlay resizes without replacing any recognizer
    let resizedRecognizers: [GestureRecognizer]? = gestureView.gestureRecognizers
    expect(renderedGestureView === gestureView) == true
    expect(gestureView.frame) == CGRect(x: 0, y: 0, width: 200, height: 150)
    expect(resizedRecognizers?.count) == 3
    expect(resizedRecognizers?.contains { $0 === tap }) == true
    expect(resizedRecognizers?.contains { $0 === press }) == true
    expect(resizedRecognizers?.contains { $0 === pan }) == true
    expect(tap.view === gestureView) == true
    expect(press.view === gestureView) == true
    expect(pan.view === gestureView) == true
    expect(tap.state) == .possible
    expect(press.state) == .possible
    expect(pan.state) == .possible
    #if canImport(AppKit)
    expect(tap.numberOfClicksRequired) == 2
    #endif
    #if canImport(UIKit)
    expect(tap.numberOfTapsRequired) == 2
    #endif
    expect(press.minimumPressDuration) == 0.75

    // when: dispatching the retained tap action
    _ = gestureView.perform(NSSelectorFromString("handleGesture:"), with: tap)

    // then: the handler still produces its configured output
    expect(gestureView.layer().backgroundColor) == Color.green.cgColor
  }

  #if canImport(AppKit)
  // this test drives a real pan with window-dispatched mouse events, which only AppKit allows, so the active gesture
  // state across geometry updates is verified on AppKit only. UIKit cannot synthesize touches without private API, and
  // a recognizer with a faked state would only assert the value the test supplied. The UIKit path is covered by the
  // recognizer identity tests above, which run on both platforms.
  func test_geometryUpdates_preserveActivePan() throws {
    // given: a window-backed overlay with an installed native pan recognizer
    let testWindow = TestWindow()
    var renderedGestureView: View?
    let contentView = ComposeView {
      LayerNode()
        .frame(width: .flexible, height: 300)
        .onPan { recognizer in
          switch recognizer.state {
          case .began:
            recognizer.view?.layer().backgroundColor = Color.green.cgColor
          case .changed:
            recognizer.view?.layer().backgroundColor = Color.yellow.cgColor
          case .ended:
            recognizer.view?.layer().backgroundColor = Color.blue.cgColor
          default:
            break
          }
        }
        .onUpdate { renderable, _ in
          if let view = renderable.view {
            renderedGestureView = view
          }
        }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    contentView.scrollIndicatorBehavior = .never
    testWindow.contentView().addSubview(contentView)
    testWindow.makeKeyAndOrderFront(nil)
    defer { testWindow.orderOut(nil) }
    contentView.refresh(animated: false)
    let gestureView = try renderedGestureView.unwrap()
    let pan = try (gestureView.gestureRecognizers.compactMap { $0 as? PanGestureRecognizer }.first).unwrap()
    let eventView = GestureEventView(frame: gestureView.bounds)
    eventView.autoresizingMask = [.width, .height]
    gestureView.addSubview(eventView)

    func mouseEvent(_ type: NSEvent.EventType, x: CGFloat, number: Int) throws -> NSEvent {
      try NSEvent.mouseEvent(
        with: type,
        location: gestureView.convert(CGPoint(x: x, y: 50), to: nil),
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: testWindow.windowNumber,
        context: nil,
        eventNumber: number,
        clickCount: 1,
        pressure: type == .leftMouseUp ? 0 : 1
      ).unwrap()
    }

    // when: window-dispatched mouse events begin a pan
    try testWindow.sendEvent(mouseEvent(.leftMouseDown, x: 20, number: 1))
    try testWindow.sendEvent(mouseEvent(.leftMouseDragged, x: 60, number: 2))

    // then: the installed recognizer is active and its native action renders the active color
    expect(pan.state).toEventually(beEqual(to: .began))
    expect(gestureView.layer().backgroundColor).toEventually(beEqual(to: Color.green.cgColor))

    // when: resizing during the active pan
    contentView.frame.size = CGSize(width: 200, height: 150)
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: resizing preserves the original active recognizer and its output
    expect(renderedGestureView === gestureView) == true
    expect(gestureView.frame) == CGRect(x: 0, y: 0, width: 200, height: 300)
    expect(gestureView.gestureRecognizers.contains { $0 === pan }) == true
    expect(pan.view === gestureView) == true
    expect(pan.state) == .began
    expect(gestureView.layer().backgroundColor) == Color.green.cgColor

    // when: scrolling during the active pan
    contentView.setContentOffset(CGPoint(x: 0, y: 30))
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()

    // then: scrolling also preserves the recognizer state and output
    expect(renderedGestureView === gestureView) == true
    expect(pan.view === gestureView) == true
    expect(pan.state) == .began
    expect(gestureView.layer().backgroundColor) == Color.green.cgColor

    // when: the mouse continues dragging after both geometry changes
    try testWindow.sendEvent(mouseEvent(.leftMouseDragged, x: 80, number: 3))

    // then: the original recognizer continues delivering its native action
    expect(pan.state).toEventually(beEqual(to: .changed))
    expect(gestureView.layer().backgroundColor).toEventually(beEqual(to: Color.yellow.cgColor))

    // when: the mouse is released
    try testWindow.sendEvent(mouseEvent(.leftMouseUp, x: 80, number: 4))

    // then: the original gesture completes on the same view
    expect(gestureView.layer().backgroundColor).toEventually(beEqual(to: Color.blue.cgColor))
    expect(pan.view === gestureView) == true
  }
  #endif

  func test_gestureRecognizer() throws {
    // given: a compose view in a test window with a tap gesture
    var optionalGestureView: View?

    let testWindow = TestWindow()
    let view = ComposeView {
      LayerNode()
        .onTap { _ in }
        .onUpdate { renderable, _ in
          if let view = renderable.view {
            optionalGestureView = view
          }
        }
    }

    testWindow.contentView().addSubview(view)
    view.frame = testWindow.contentView().bounds

    // when: the view is refreshed
    view.refresh()

    // then: the tap gesture is installed
    do {
      let gestureView = try optionalGestureView.unwrap()

      let installedGestureRecognizers = try (DynamicLookup(gestureView).keyPath("installedGestureRecognizers") as? [AnyHashable: Any]).unwrap()
      expect(installedGestureRecognizers.count) == 1

      let handlers = try (DynamicLookup(gestureView).keyPath("handlers") as? [AnyHashable: Any]).unwrap()
      expect(handlers.count) == 1
    }

    // when: refresh with multiple gestures
    view.setContent {
      LayerNode()
        .onTap { _ in }
        .onPress { _ in }
        .onPan { _ in }
    }

    view.refresh()

    // then: the multiple gestures are installed
    do {
      let gestureView = try optionalGestureView.unwrap()

      let installedGestureRecognizers = try (DynamicLookup(gestureView).keyPath("installedGestureRecognizers") as? [AnyHashable: Any]).unwrap()
      expect(installedGestureRecognizers.count) == 3

      let handlers = try (DynamicLookup(gestureView).keyPath("handlers") as? [AnyHashable: Any]).unwrap()
      expect(handlers.count) == 3
    }
  }
}

#if canImport(AppKit)
private final class GestureEventView: NSView {

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override func mouseDown(with event: NSEvent) {}
}
#endif
