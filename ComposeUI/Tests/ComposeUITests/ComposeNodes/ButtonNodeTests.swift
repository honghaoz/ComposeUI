//
//  ButtonNodeTests.swift
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
import UIKit.UIGestureRecognizerSubclass
#endif

import ChouTiTest
import ChouTi

@testable import ComposeUI

class ButtonNodeTests: XCTestCase {

  func test_init() throws {
    // then: button nodes can be created with both content closure variants
    _ = ButtonNode(content: { state in ColorNode(.red) }, onTap: {})
    _ = ButtonNode(content: { state, contentView in ColorNode(.red) }, onTap: {})
  }

  func test_id() throws {
    // then: the id is "B"
    expect(ButtonNode(content: { state in ColorNode(.red) }, onTap: {}).id.id) == "B"
  }

  func test_size() throws {
    // then: the default size is zero
    expect(ButtonNode(content: { state in ColorNode(.red) }, onTap: {}).size) == .zero
  }

  func test_layout() throws {
    // given: a layout context
    let context = ComposeNodeLayoutContext(scaleFactor: 1)

    // given: a button node with flexible size content
    do {
      var node = ButtonNode(
        content: { state in
          switch state {
          case .normal:
            ColorNode(.red)
          case .hovered:
            ColorNode(.red)
          case .pressed:
            ColorNode(.red)
          case .selected:
            ColorNode(.red)
          case .disabled:
            ColorNode(.red)
          }
        },
        onTap: {}
      )

      // when: laying out in a 100x100 container
      let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the sizing and size are flexible
      expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
      expect(node.size) == CGSize(width: 100, height: 100)
    }

    // given: a button node with fixed size content
    do {
      var node = ButtonNode(
        content: { state in
          switch state {
          case .normal:
            ColorNode(.red).frame(width: 50, height: 20)
          case .hovered:
            ColorNode(.red)
          case .pressed:
            ColorNode(.red)
          case .selected:
            ColorNode(.red)
          case .disabled:
            ColorNode(.red)
          }
        },
        onTap: {}
      )

      // when: laying out in a 100x100 container
      let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // then: the sizing and size are fixed to the content size
      expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .fixed(20))
      expect(node.size) == CGSize(width: 50, height: 20)
    }
  }

  func test_renderableItems() throws {
    // given: a laid out button node with platform-specific configurations
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ButtonNode(content: { state in ColorNode(.red) }, onTap: {})
    #if canImport(UIKit) && !os(tvOS) && !os(visionOS)
    node = node.hapticFeedbackStyle(.heavy)
    #endif
    #if canImport(AppKit)
    node = node.shouldPerformKeyEquivalent { _ in false }
    #endif
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when: visible bounds intersects with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)

      // then: a single button item is provided with the expected id, frame, and behaviors
      expect(items.count) == 1

      let item = items[0]
      expect(item.id.id) == "B"
      expect(item.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

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
          let view = try (renderable.view as? ButtonView).unwrap()
          let viewLookup = DynamicLookup(view)
          expect(viewLookup.property("onTap")) != nil
          expect(viewLookup.property("onDoubleTap")) == nil
          #if canImport(UIKit) && !os(tvOS) && !os(visionOS)
          expect(viewLookup.property("hapticFeedbackStyle")) != nil
          #endif
          #if canImport(AppKit)
          expect(viewLookup.property("shouldPerformKeyEquivalent")) != nil
          #endif
        }

        // conditional update
        do {
          let contentView = ComposeView()
          let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

          // scroll doesn't trigger update
          do {
            let context = RenderableUpdateContext(updateType: .scroll, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
            item.update(renderable, context)
            let view = try (renderable.view as? ButtonView).unwrap()
            let viewLookup = DynamicLookup(view)
            expect(viewLookup.property("onTap")) == nil // doesn't update
          }

          // when: updating for a bounds change
          do {
            let context = RenderableUpdateContext(updateType: .boundsChange, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
            item.update(renderable, context)
            let view = try (renderable.view as? ButtonView).unwrap()
            let viewLookup = DynamicLookup(view)

            // then: geometry updates do not configure the button
            expect(viewLookup.property("onTap")) == nil
          }
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

  func test_update_skipsGeometryChanges() throws {
    // given: a configured button and a replacement configuration
    let frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    let button = ButtonView(frame: frame)
    var action = ""
    button.configure(
      content: { _, _ in
        ColorNode(.red)
      },
      onTap: {
        action = "old tap"
      },
      onDoubleTap: {
        action = "old double tap"
      }
    )
    button.refresh(animated: false)

    let layer = try (button.contentView().layer().sublayers?.first).unwrap()
    var node = ButtonNode(
      content: { _ in
        ColorNode(.blue)
      },
      onTap: {
        action = "new tap"
      }
    )
    .onDoubleTap { action = "new double tap" }
    _ = node.layout(containerSize: frame.size, context: ComposeNodeLayoutContext(scaleFactor: 1))
    let item = try node.renderableItems(in: frame).first.unwrap()
    let renderable = Renderable.view(button)

    for updateType in [RenderableUpdateType.scroll, .boundsChange] {
      // when: updating geometry without an explicit refresh
      item.update(renderable, RenderableUpdateContext(updateType: updateType, oldFrame: frame, newFrame: frame, animationTiming: nil, contentView: nil))
      button.setNeedsLayout()
      button.layoutIfNeeded()
      button.onDoubleTap?()

      // then: the existing content and handler remain installed
      expect(layer.backgroundColor) == Color.red.cgColor
      expect(action) == "old double tap"
    }

    // when: explicitly refreshing the configuration
    item.update(renderable, RenderableUpdateContext(updateType: .refresh, oldFrame: frame, newFrame: frame, animationTiming: nil, contentView: nil))
    button.onDoubleTap?()

    // then: the new content and handler replace the prior configuration
    expect(layer.backgroundColor).toEventually(beEqual(to: Color.blue.cgColor))
    expect(action) == "new double tap"
    expect(button.contentView().layer().sublayers?.first === layer) == true
  }

  func test_boundsChange_preservesPressedContentAndNormalMeasurement() throws {
    // given: a button with separate normal measurement and state-specific appearance
    var text = "Initial"
    var generation = 1
    var tappedGeneration = 0
    var renderedButton: ButtonView?
    var colorLayer: CALayer?
    var textView: BaseTextView?

    let contentView = ComposeView {
      let configuration = generation
      ButtonNode(
        content: { state in
          VStack {
            ColorNode(state == .pressed ? (configuration == 1 ? .blue : .black) : .red)
              .frame(width: .flexible, height: 20)
              .onUpdate { item, _ in colorLayer = item.layer }
            TextNode(text, font: .systemFont(ofSize: 12))
              .frame(width: .flexible, height: state == .pressed ? 50 : 30)
              .onUpdate { item, _ in textView = item.view as? BaseTextView }
          }
        },
        onTap: { tappedGeneration = configuration }
      )
      .onUpdate { item, _ in renderedButton = item.view as? ButtonView }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 240, height: 150)

    contentView.refresh(animated: false)

    expect(textView?.attributedString.string).toEventually(beEqual(to: "Initial"))
    let button = try renderedButton.unwrap()
    let originalLayer = try colorLayer.unwrap()
    let originalTextView = try textView.unwrap()
    expect(button.frame.size) == CGSize(width: 240, height: 50)
    expect(originalLayer.backgroundColor) == Color.red.cgColor
    #if canImport(UIKit)
    var pressState = GestureRecognizer.State.possible
    let recognizer = button.buttonTest.pressGestureRecognizer
    recognizer.override(
      locationInView: { view in CGPoint(x: 10, y: 10) },
      state: { pressState }
    )
    #endif
    #if canImport(AppKit)
    let mouseEventView = button.buttonTest.mouseEventView
    #endif

    // when: a local press changes the button state
    #if canImport(UIKit)
    pressState = .began
    button.buttonTest.press()
    #endif
    #if canImport(AppKit)
    button.buttonTest.handlePress(with: .began)
    #endif

    // then: the actual appearance changes without changing the normal-state measurement
    expect(button.buttonTest.buttonState) == .pressed
    expect(originalLayer.backgroundColor) == Color.blue.cgColor
    expect(originalTextView.frame.height) == 50
    expect(button.frame.height) == 50

    // when: external configuration changes and the parent only resizes
    text = "Updated"
    generation = 2
    contentView.frame.size.width = 120
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()
    button.setNeedsLayout()
    button.layoutIfNeeded()

    // then: pressed content and interaction identity survive while geometry reflows
    expect(renderedButton === button) == true
    expect(colorLayer === originalLayer) == true
    expect(textView === originalTextView) == true
    expect(button.buttonTest.buttonState) == .pressed
    expect(button.frame.size) == CGSize(width: 120, height: 50)
    expect(originalTextView.frame.size) == CGSize(width: 120, height: 50)
    expect(originalTextView.attributedString.string) == "Initial"
    expect(originalLayer.backgroundColor) == Color.blue.cgColor
    #if canImport(UIKit)
    expect(button.buttonTest.pressGestureRecognizer === recognizer) == true
    expect(recognizer.state) == .began
    #endif
    #if canImport(AppKit)
    expect(button.buttonTest.mouseEventView === mouseEventView) == true
    #endif
    let oldTap = try (DynamicLookup(button).property("onTap") as? (() -> Void)).unwrap()
    oldTap()
    expect(tappedGeneration) == 1

    // when: the parent explicitly refreshes with the same button id and size
    contentView.refresh(animated: false)
    button.setNeedsLayout()
    button.layoutIfNeeded()

    // then: refreshed content uses the current local state and preserves the button view
    expect(renderedButton === button) == true
    expect(button.frame.size) == CGSize(width: 120, height: 50)
    expect(button.buttonTest.buttonState) == .pressed
    expect(originalTextView.attributedString.string) == "Updated"
    expect(originalLayer.backgroundColor) == Color.black.cgColor
    #if canImport(AppKit)
    expect(originalTextView.string) == "Updated"
    #endif
    #if canImport(UIKit)
    expect(originalTextView.attributedText.string) == "Updated"
    #endif

    // when: the local press ends after the parent refresh
    #if canImport(UIKit)
    pressState = .ended
    button.buttonTest.press()
    #endif
    #if canImport(AppKit)
    button.buttonTest.handlePress(with: .ended)
    #endif

    // then: normal appearance is restored and the new tap handler runs
    expect(button.buttonTest.buttonState) == .normal
    expect(originalLayer.backgroundColor) == Color.red.cgColor
    expect(originalTextView.frame.height) == 30
    expect(originalTextView.attributedString.string) == "Updated"
    expect(tappedGeneration) == 2
  }

  func test_refresh_updatesDoubleTapHandler() throws {
    // given: a mounted button with a captured double tap action
    var generation = 1
    var tappedGeneration = 0
    var renderedButton: ButtonView?
    let contentView = ComposeView {
      let configuration = generation
      ButtonNode(content: { _ in ColorNode(configuration == 1 ? .red : .blue) }, onTap: {})
        .onDoubleTap { tappedGeneration = configuration }
        .onUpdate { item, _ in renderedButton = item.view as? ButtonView }
    }
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    contentView.refresh(animated: false)
    let button = try renderedButton.unwrap()
    button.setNeedsLayout()
    button.layoutIfNeeded()
    let layer = try (button.contentView().layer().sublayers?.first).unwrap()

    // when: new data is supplied without a refresh and the parent resizes
    generation = 2
    contentView.frame.size.width = 200
    contentView.setNeedsLayout()
    contentView.layoutIfNeeded()
    button.setNeedsLayout()
    button.layoutIfNeeded()
    button.onDoubleTap?()

    // then: content and the existing double tap action are retained
    expect(layer.backgroundColor) == Color.red.cgColor
    expect(tappedGeneration) == 1

    // when: the parent refreshes at the same size
    contentView.refresh(animated: false)
    button.onDoubleTap?()

    // then: content and the double tap action update on the same button
    expect(layer.backgroundColor).toEventually(beEqual(to: Color.blue.cgColor))
    expect(tappedGeneration) == 2
    expect(renderedButton === button) == true
    expect(button.frame.size) == CGSize(width: 200, height: 50)
  }

  func test_doubleTap() {
    // given: a compose view with a button node that has a double tap handler
    var view: ButtonView?
    let contentView = ComposeView {
      ButtonNode(
        content: { state in
          switch state {
          case .normal:
            ColorNode(.red)
          case .hovered:
            ColorNode(.red)
          case .pressed:
            ColorNode(.red)
          case .selected:
            ColorNode(.red)
          case .disabled:
            ColorNode(.red)
          }
        },
        onTap: {}
      )
      .onDoubleTap {}
      .onInsert { renderable, _ in
        view = renderable.view as? ButtonView
      }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)

    // when: the view is refreshed
    contentView.refresh()

    // then: the button view has the double tap handler set
    expect(try view.unwrap().onDoubleTap) != nil
  }
}
