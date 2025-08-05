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

import ChouTiTest
import ChouTi

@testable import ComposeUI

class ButtonNodeTests: XCTestCase {

  func test_init() throws {
    _ = ButtonNode(content: { state in ColorNode(.red) }, onTap: {})
    _ = ButtonNode(content: { state, contentView in ColorNode(.red) }, onTap: {})
  }

  func test_id() throws {
    expect(ButtonNode(content: { state in ColorNode(.red) }, onTap: {}).id.id) == "B"
  }

  func test_size() throws {
    expect(ButtonNode(content: { state in ColorNode(.red) }, onTap: {}).size) == .zero
  }

  func test_layout() throws {
    let context = ComposeNodeLayoutContext(scaleFactor: 1)

    // flexible size
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

      let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
      expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
      expect(node.size) == CGSize(width: 100, height: 100)
    }

    // fixed size
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

      let sizing = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)
      expect(sizing) == ComposeNodeSizing(width: .fixed(50), height: .fixed(20))
      expect(node.size) == CGSize(width: 50, height: 20)
    }
  }

  func test_renderableItems() throws {
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    var node = ButtonNode(content: { state in ColorNode(.red) }, onTap: {})
    #if canImport(UIKit) && !os(tvOS) && !os(visionOS)
    node = node.hapticFeedbackStyle(.heavy)
    #endif
    #if canImport(AppKit)
    node = node.shouldPerformKeyEquivalent { _ in false }
    #endif
    _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

    // when visible bounds intersects with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 0, width: 100, height: 50)
      let items = node.renderableItems(in: visibleBounds)
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

        // requires full update
        do {
          let contentView = ComposeView()
          let renderable = item.make(RenderableMakeContext(initialFrame: CGRect(x: 1, y: 2, width: 3, height: 4), contentView: contentView))

          // scroll doesn't require a full update
          let context = RenderableUpdateContext(updateType: .scroll, oldFrame: .zero, newFrame: .zero, animationTiming: nil, contentView: contentView)
          item.update(renderable, context)
          let view = try (renderable.view as? ButtonView).unwrap()
          let viewLookup = DynamicLookup(view)
          expect(viewLookup.property("onTap")) == nil // doesn't update
        }
      }

      expect(item.willRemove) == nil
      expect(item.didRemove) == nil
      expect(item.transition) == nil
      expect(item.animationTiming) == nil
    }

    // when visible bounds does not intersect with the node's frame
    do {
      let visibleBounds = CGRect(x: 0, y: 100, width: 100, height: 100)
      let items = node.renderableItems(in: visibleBounds)
      expect(items.count) == 0
    }
  }

  func test_doubleTap() {
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
    contentView.refresh()

    expect(try view.unwrap().onDoubleTap) != nil
  }
}
