//
//  LabelNodeTests.swift
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

class LabelNodeTests: XCTestCase {

  func test_size_assertion() throws {
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, file, line, column in
      expect(message) == "layout(containerSize:context:) should be called before calling size"
      assertionCount += 1
    }

    let labelNode = LabelNode("Test")

    // when accessing size without calling layout first
    // then it should trigger the assertion
    _ = labelNode.size
    expect(assertionCount) == 1

    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
  }

  func test_renderableItems_assertion() throws {
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, file, line, column in
      expect(message) == "layout(containerSize:context:) should be called before calling renderableItems(in:)"
      assertionCount += 1
    }

    let labelNode = LabelNode("Test")

    // when accessing renderableItems without calling layout first
    // then it should trigger the assertion
    _ = labelNode.renderableItems(in: CGRect(0, 0, 100, 100))
    expect(assertionCount) == 1

    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
  }

  // MARK: - Single-line

  func test_singleLine_enoughWidth() throws {
    // when fixed size
    do {
      var textView: BaseTextView?
      let view = ComposeView {
        try LabelNode("Hello World")
          .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
          .onInsert { renderable, _ in
            textView = renderable.view as? BaseTextView
          }
      }

      view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

      view.refresh()

      expect(textView?.attributedString.string) == "Hello World"
      expect(textView?.bounds.size) == CGSize(width: 67, height: 16.0)
      expect(textView?.numberOfLines) == 1
      expect(textView?.attributedString.paragraphStyle()?.alignment) == .center
      expect(textView?.attributedString.paragraphStyle()?.lineBreakMode) == .byWordWrapping
      expect(textView?.lineBreakMode) == .byTruncatingTail
    }

    // when flexible width
    do {
      var textView: BaseTextView?
      let view = ComposeView {
        try LabelNode("Hello World")
          .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
          .fixedSize(width: false, height: true)
          .onInsert { renderable, _ in
            textView = renderable.view as? BaseTextView
          }
      }

      view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

      view.refresh()

      expect(textView?.attributedString.string) == "Hello World"
      expect(textView?.bounds.size) == CGSize(width: 100, height: 16.0)
      expect(textView?.numberOfLines) == 1
      expect(textView?.attributedString.paragraphStyle()?.alignment) == .center
      expect(textView?.attributedString.paragraphStyle()?.lineBreakMode) == .byWordWrapping
      expect(textView?.lineBreakMode) == .byTruncatingTail
    }
  }

  func test_singleLine_notEnoughWidth() throws {
    // when fixed size
    do {
      var textView: BaseTextView?
      let view = ComposeView {
        try LabelNode("Hello World")
          .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
          .onInsert { renderable, _ in
            textView = renderable.view as? BaseTextView
          }
      }

      view.frame = CGRect(x: 0, y: 0, width: 50, height: 50)

      view.refresh()

      expect(textView?.attributedString.string) == "Hello World"
      expect(textView?.bounds.size) == CGSize(width: 67, height: 16)
      expect(textView?.numberOfLines) == 1
      expect(textView?.attributedString.paragraphStyle()?.alignment) == .center
      expect(textView?.attributedString.paragraphStyle()?.lineBreakMode) == .byWordWrapping
      expect(textView?.lineBreakMode) == .byTruncatingTail
    }

    // when flexible width
    do {
      var textView: BaseTextView?
      let view = ComposeView {
        try LabelNode("Hello World")
          .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
          .fixedSize(width: false, height: true)
          .onInsert { renderable, _ in
            textView = renderable.view as? BaseTextView
          }
      }

      view.frame = CGRect(x: 0, y: 0, width: 50, height: 50)

      view.refresh()

      expect(textView?.attributedString.string) == "Hello World"
      expect(textView?.bounds.size) == CGSize(width: 50, height: 16)
      expect(textView?.numberOfLines) == 1
      expect(textView?.attributedString.paragraphStyle()?.alignment) == .center
      expect(textView?.attributedString.paragraphStyle()?.lineBreakMode) == .byWordWrapping
      expect(textView?.lineBreakMode) == .byTruncatingTail
    }
  }

  func test_singleLineWithNewline_enoughWidth() throws {
    var textView: BaseTextView?
    let view = ComposeView {
      try LabelNode("Hello\nWorld")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        .onInsert { renderable, _ in
          textView = renderable.view as? BaseTextView
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    view.refresh()

    expect(textView?.attributedString.string) == "Hello\nWorld"
    expect(textView?.bounds.size) == CGSize(width: 30, height: 16.0)
    expect(textView?.numberOfLines) == 1
    expect(textView?.attributedString.paragraphStyle()?.alignment) == .center
    expect(textView?.attributedString.paragraphStyle()?.lineBreakMode) == .byWordWrapping
    expect(textView?.lineBreakMode) == .byTruncatingTail
  }

  func test_singleLineWithNewline_notEnoughWidth() throws {
    var textView: BaseTextView?
    let view = ComposeView {
      try LabelNode("Hello\nWorld")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        .onInsert { renderable, _ in
          textView = renderable.view as? BaseTextView
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 50, height: 50)

    view.refresh()

    expect(textView?.attributedString.string) == "Hello\nWorld"
    expect(textView?.bounds.size) == CGSize(width: 30, height: 16.0)
    expect(textView?.numberOfLines) == 1
    expect(textView?.attributedString.paragraphStyle()?.alignment) == .center
    expect(textView?.attributedString.paragraphStyle()?.lineBreakMode) == .byWordWrapping
    expect(textView?.lineBreakMode) == .byTruncatingTail
  }

  func test_singleLine_lineBreakMode() throws {
    var textView: BaseTextView?
    let view = ComposeView {
      try LabelNode("Hello World")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        .lineBreakMode(.byClipping)
        .onInsert { renderable, _ in
          textView = renderable.view as? BaseTextView
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    view.refresh()

    expect(textView?.attributedString.string) == "Hello World"
    expect(textView?.bounds.size) == CGSize(width: 67, height: 16.0)
    expect(textView?.numberOfLines) == 1
    expect(textView?.attributedString.paragraphStyle()?.alignment) == .center
    expect(textView?.attributedString.paragraphStyle()?.lineBreakMode) == .byWordWrapping
    expect(textView?.lineBreakMode) == .byClipping
  }

  // MARK: - Multi-line

  func test_multiLine_flexible() throws {
    var textView: BaseTextView?
    let view = ComposeView {
      try LabelNode("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        .numberOfLines(0)
        .flexibleSize()
        .onInsert { renderable, _ in
          textView = renderable.view as? BaseTextView
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 98, height: 100)

    view.refresh()

    expect(textView?.attributedString.string) == "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
    expect(textView?.bounds.size) == CGSize(width: 98, height: 100)
    expect(textView?.numberOfLines) == 0
    expect(textView?.attributedString.paragraphStyle()?.alignment) == .center
    expect(textView?.attributedString.paragraphStyle()?.lineBreakMode) == .byWordWrapping
    expect(textView?.lineBreakMode) == .byTruncatingTail
  }

  func test_multiLine_fixedWidth_flexibleHeight() throws {
    var textView: BaseTextView?
    let view = ComposeView {
      try LabelNode("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        .numberOfLines(0)
        .fixedSize(width: true, height: false)
        .onInsert { renderable, _ in
          textView = renderable.view as? BaseTextView
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 98, height: 100)

    view.refresh()

    expect(textView?.attributedString.string) == "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
    expect(textView?.bounds.size) == CGSize(width: 97, height: 100)
    expect(textView?.numberOfLines) == 0
    expect(textView?.attributedString.paragraphStyle()?.alignment) == .center
    expect(textView?.attributedString.paragraphStyle()?.lineBreakMode) == .byWordWrapping
    expect(textView?.lineBreakMode) == .byTruncatingTail
  }

  func test_multiLine_flexibleWidth_fixedHeight() throws {
    var textView: BaseTextView?
    let view = ComposeView {
      try LabelNode("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        .numberOfLines(0)
        .fixedSize(width: false, height: true)
        .onInsert { renderable, _ in
          textView = renderable.view as? BaseTextView
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 98, height: 100)

    view.refresh()

    expect(textView?.attributedString.string) == "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
    #if canImport(AppKit)
    expect(textView?.bounds.size) == CGSize(width: 98, height: 139)
    #endif
    #if canImport(UIKit)
    expect(textView?.bounds.size) == CGSize(width: 98, height: 140)
    #endif
    expect(textView?.numberOfLines) == 0
    expect(textView?.attributedString.paragraphStyle()?.alignment) == .center
    expect(textView?.attributedString.paragraphStyle()?.lineBreakMode) == .byWordWrapping
    expect(textView?.lineBreakMode) == .byTruncatingTail
  }

  func test_multiLine_flexibleWidth_fixedHeight2() throws {
    var textView: BaseTextView?
    let view = ComposeView {
      try LabelNode("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        .numberOfLines(0) // this sets the width to be flexible and the height to be fixed
        .onInsert { renderable, _ in
          textView = renderable.view as? BaseTextView
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 98, height: 100)

    view.refresh()

    expect(textView?.attributedString.string) == "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
    #if canImport(AppKit)
    expect(textView?.bounds.size) == CGSize(width: 98, height: 139)
    #endif
    #if canImport(UIKit)
    expect(textView?.bounds.size) == CGSize(width: 98, height: 140)
    #endif
    expect(textView?.numberOfLines) == 0
    expect(textView?.attributedString.paragraphStyle()?.alignment) == .center
    expect(textView?.attributedString.paragraphStyle()?.lineBreakMode) == .byWordWrapping
    expect(textView?.lineBreakMode) == .byTruncatingTail
  }

  func test_multiLine_fixedSize() throws {
    var textView: BaseTextView?
    let view = ComposeView {
      try LabelNode("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        .numberOfLines(0)
        .fixedSize()
        .onInsert { renderable, _ in
          textView = renderable.view as? BaseTextView
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 98, height: 100)

    view.refresh()

    expect(textView?.attributedString.string) == "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
    #if canImport(AppKit)
    expect(textView?.bounds.size) == CGSize(width: 97, height: 139)
    #endif
    #if canImport(UIKit)
    expect(textView?.bounds.size) == CGSize(width: 97, height: 140)
    #endif
    expect(textView?.numberOfLines) == 0
    expect(textView?.attributedString.paragraphStyle()?.alignment) == .center
    expect(textView?.attributedString.paragraphStyle()?.lineBreakMode) == .byWordWrapping
    expect(textView?.lineBreakMode) == .byTruncatingTail
  }

  // MARK: - User Interaction

  func test_userInteraction() {
    var textView: BaseTextView?
    let view = ComposeView {
      LabelNode("Hello World")
        .onInsert { renderable, _ in
          textView = renderable.view as? BaseTextView
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh()

    // by default, the label is not interactive
    expect(textView?.isSelectable) == false
    #if canImport(AppKit)
    expect(textView?.ignoreHitTest) == true
    #endif
    #if canImport(UIKit)
    expect(textView?.isUserInteractionEnabled) == false
    #endif

    // when set to selectable
    view.setContent {
      LabelNode("Hello World")
        .selectable()
        .onInsert { renderable, _ in
          textView = renderable.view as? BaseTextView
        }
    }
    view.refresh()

    // the label is now interactive
    expect(textView?.isSelectable) == true
    #if canImport(AppKit)
    expect(textView?.ignoreHitTest) == false
    #endif
    #if canImport(UIKit)
    expect(textView?.isUserInteractionEnabled) == true
    #endif
  }

  // MARK: - Modifiers

  func test_modifiers() throws {
    var textView: BaseTextView?
    let view = ComposeView {
      try LabelNode("Hello World")
        .font(unwrap(Font(name: "HelveticaNeue", size: 20)))
        .textColor(.red)
        .textColor(ThemedColor(.blue))
        .textBackgroundColor(ThemedColor(.green))
        .textShadow(Themed<NSShadow>({
          let shadow = NSShadow()
          shadow.shadowOffset = CGSize(width: 0, height: 1)
          return shadow
        }()))
        .textAlignment(.right)
        .numberOfLines(1)
        .lineBreakMode(.byTruncatingMiddle)
        .selectable()
        .onInsert { renderable, _ in
          textView = renderable.view as? BaseTextView
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    view.refresh()

    try expect(textView?.attributedString.font()) == unwrap(Font(name: "HelveticaNeue", size: 20))
    expect(textView?.attributedString.foregroundColor()) == .blue
    expect(textView?.attributedString.backgroundColor()) == .green
    expect(textView?.attributedString.shadow()) == {
      let shadow = NSShadow()
      #if canImport(AppKit)
      shadow.shadowOffset = CGSize(width: 0, height: -1)
      #else
      shadow.shadowOffset = CGSize(width: 0, height: 1)
      #endif
      return shadow
    }()
    let paragraphStyle = try unwrap(textView?.attributedString.paragraphStyle())
    expect(paragraphStyle.alignment) == .right
    expect(paragraphStyle.lineBreakMode) == .byWordWrapping
    expect(textView?.lineBreakMode) == .byTruncatingMiddle
    expect(textView?.isSelectable) == true

    #if canImport(AppKit)
    expect(textView?.ignoreHitTest) == false
    #endif
    #if canImport(UIKit)
    expect(textView?.isUserInteractionEnabled) == true
    #endif
  }

  func test_modifiers_resetNode() throws {
    // given a node
    var node = LabelNode("Hello World")

    // font
    do {
      try node = node.font(unwrap(Font(name: "HelveticaNeue", size: 20)))

      // when layout is triggered
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // the underlying node should have been set
      expect(DynamicLookup(node).property("node")) != nil

      // when a duplicate modifier is triggered
      try node = node.font(unwrap(Font(name: "HelveticaNeue", size: 20)))

      // the underlying node should still be set
      expect(DynamicLookup(node).property("node")) != nil

      // then a new modifier is triggered
      try node = node.font(unwrap(Font(name: "HelveticaNeue", size: 13)))

      // the underlying node should be cleared
      expect(DynamicLookup(node).property("node")) == nil
    }

    // textColor
    do {
      node = node.textColor(.red)

      // when layout is triggered
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // the underlying node should have been set
      expect(DynamicLookup(node).property("node")) != nil

      // when a duplicate modifier is triggered
      node = node.textColor(.red)

      // the underlying node should still be set
      expect(DynamicLookup(node).property("node")) != nil

      // then a new modifier is triggered
      node = node.textColor(ThemedColor(.blue))

      // the underlying node should be cleared
      expect(DynamicLookup(node).property("node")) == nil
    }

    // textBackgroundColor
    do {
      node = node.textBackgroundColor(ThemedColor(.green))

      // when layout is triggered
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // the underlying node should have been set
      expect(DynamicLookup(node).property("node")) != nil

      // when a duplicate modifier is triggered
      node = node.textBackgroundColor(ThemedColor(.green))

      // the underlying node should still be set
      expect(DynamicLookup(node).property("node")) != nil

      // then a new modifier is triggered
      node = node.textBackgroundColor(nil)

      // the underlying node should be cleared
      expect(DynamicLookup(node).property("node")) == nil
    }

    // textShadow
    do {
      node = node.textShadow(Themed<NSShadow>({
        let shadow = NSShadow()
        shadow.shadowOffset = CGSize(width: 0, height: 1)
        return shadow
      }()))

      // when layout is triggered
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // the underlying node should have been set
      expect(DynamicLookup(node).property("node")) != nil

      // when a duplicate modifier is triggered
      node = node.textShadow(Themed<NSShadow>({
        let shadow = NSShadow()
        shadow.shadowOffset = CGSize(width: 0, height: 1)
        return shadow
      }()))

      // the underlying node should still be set
      expect(DynamicLookup(node).property("node")) != nil

      // then a new modifier is triggered
      node = node.textShadow(nil)

      // the underlying node should be cleared
      expect(DynamicLookup(node).property("node")) == nil
    }

    // textAlignment
    do {
      // when layout is triggered
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // the underlying node should have been set
      expect(DynamicLookup(node).property("node")) != nil

      // when a duplicate modifier is triggered
      node = node.textAlignment(.center)

      // the underlying node should still be set
      expect(DynamicLookup(node).property("node")) != nil

      // then a new modifier is triggered
      node = node.textAlignment(.left)

      // the underlying node should be cleared
      expect(DynamicLookup(node).property("node")) == nil
    }

    // numberOfLines
    do {
      // when layout is triggered
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // the underlying node should have been set
      expect(DynamicLookup(node).property("node")) != nil

      // when a duplicate modifier is triggered
      node = node.numberOfLines(1)

      // the underlying node should still be set
      expect(DynamicLookup(node).property("node")) != nil

      // then a new modifier is triggered
      node = node.numberOfLines(0)

      // the underlying node should be cleared
      expect(DynamicLookup(node).property("node")) == nil
    }

    // lineBreakMode
    do {
      // when layout is triggered
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // the underlying node should have been set
      expect(DynamicLookup(node).property("node")) != nil

      // when a duplicate modifier is triggered
      node = node.lineBreakMode(.byTruncatingTail)

      // the underlying node should still be set
      expect(DynamicLookup(node).property("node")) != nil

      // then a new modifier is triggered
      node = node.lineBreakMode(.byTruncatingMiddle)

      // the underlying node should be cleared
      expect(DynamicLookup(node).property("node")) == nil
    }

    // selectable
    do {
      // when layout is triggered
      let context = ComposeNodeLayoutContext(scaleFactor: 1)
      _ = node.layout(containerSize: CGSize(width: 100, height: 100), context: context)

      // the underlying node should have been set
      expect(DynamicLookup(node).property("node")) != nil

      // when a duplicate modifier is triggered
      node = node.selectable(false)

      // the underlying node should still be set
      expect(DynamicLookup(node).property("node")) != nil

      // then a new modifier is triggered
      node = node.selectable(true)

      // the underlying node should be cleared
      expect(DynamicLookup(node).property("node")) == nil
    }
  }

  // MARK: - View reuse

  func test_viewReuse_defaultReuseKey_usesFrameworkNamespace() {
    // LabelNode renders through TextNode, so its renderable opts into the same framework-internal BaseTextView pool bucket.
    let item = firstRenderableItem(of: LabelNode("Hello"))
    expect(item?.reuseId) == ReuseId(namespace: .framework, id: "BaseTextView")
    expect(item?.reuseKey?.reuseId) == ReuseId(namespace: .framework, id: "BaseTextView")
  }

  func test_viewReuse_recycledView_resetsStateAndReuses() throws {
    let view = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    view.renderablePool = RenderablePool() // isolate from the shared pool so the reused view is deterministic.

    view.setContent {
      LabelNode("First")
        .numberOfLines(2)
    }
    view.refresh(animated: false)

    let textView = try firstBaseTextView(in: view).unwrap()
    expect(textView.attributedString.string) == "First"
    expect(textView.numberOfLines) == 2

    // removing the label enqueues its view into the pool, which resets it (via TextNode's resetForReuse) for reuse.
    view.setContent {
      Empty()
    }
    view.refresh(animated: false)

    expect(firstBaseTextView(in: view)) == nil
    expect(textView.attributedString.string) == ""
    expect(textView.numberOfLines) == 0
    expect(textView.lineBreakMode) == .byWordWrapping
    expect(textView.isSelectable) == true

    // a new label reuses the very same pooled view, reconfigured for the new content (no stale state).
    view.setContent {
      LabelNode("Second")
    }
    view.refresh(animated: false)

    let reusedView = try firstBaseTextView(in: view).unwrap()
    expect(reusedView) === textView
    expect(reusedView.attributedString.string) == "Second"
    expect(reusedView.numberOfLines) == 1
  }

  // MARK: -

  func test_renderableItems_sharedBase_selectableChange_notStale() {
    // LabelNode delegates to an inner TextNode that it recreates when a setter runs (copy.node = nil), so two copies of
    // a shared base get their own TextNode (and item cache) and a config change is never served a stale cached item.
    let base = LabelNode("hi")
    var defaultView: BaseTextView?
    var selectableView: BaseTextView?
    let view = ComposeView {
      VStack {
        base.onUpdate { item, _ in defaultView = item.view as? BaseTextView }
        base.selectable(true).onUpdate { item, _ in selectableView = item.view as? BaseTextView }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)

    expect(defaultView?.isSelectable) == false // LabelNode is not selectable by default
    expect(selectableView?.isSelectable) == true
  }

  // MARK: - Helpers

  private func firstRenderableItem(of node: LabelNode) -> RenderableItem? {
    var node = node
    let size = CGSize(width: 100, height: 100)
    _ = node.layout(containerSize: size, context: ComposeNodeLayoutContext(scaleFactor: 1))
    return node.renderableItems(in: CGRect(origin: .zero, size: size)).first
  }

  private func firstBaseTextView(in view: ComposeView) -> BaseTextView? {
    view.contentView().subviews.compactMap { $0 as? BaseTextView }.first
  }
}

private extension NSAttributedString {

  func font() -> Font? {
    attributes(at: 0, effectiveRange: nil)[NSAttributedString.Key.font] as? Font
  }

  func foregroundColor() -> Color? {
    attributes(at: 0, effectiveRange: nil)[NSAttributedString.Key.foregroundColor] as? Color
  }

  func backgroundColor() -> Color? {
    attributes(at: 0, effectiveRange: nil)[NSAttributedString.Key.backgroundColor] as? Color
  }

  func shadow() -> NSShadow? {
    attributes(at: 0, effectiveRange: nil)[NSAttributedString.Key.shadow] as? NSShadow
  }

  func paragraphStyle() -> NSParagraphStyle? {
    attributes(at: 0, effectiveRange: nil)[NSAttributedString.Key.paragraphStyle] as? NSParagraphStyle
  }
}
