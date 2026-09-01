//
//  TextNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/31/25.
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

import ComposeUI

class TextNodeTests: XCTestCase {

  func test_defaultSize() {
    // given: a text node
    var node = TextNode("Hello, world!")

    // when: laying out the node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    // then: the sizing is flexible and the size fills the container
    expect(sizing) == ComposeNodeSizing(width: .flexible, height: .flexible)
    expect(node.size) == CGSize(width: 100, height: 50)
  }

  func test_fixedSize() throws {
    // given: a text node with a fixed size
    let font = try unwrap(Font(name: "HelveticaNeue", size: 18))
    var node = TextNode("Hello, world!", font: font).fixedSize()

    // when: laying out the node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    // then: the sizing and size are fixed to the text's intrinsic size
    #if canImport(AppKit)
    expect(sizing) == ComposeNodeSizing(width: .fixed(51), height: .fixed(44))
    expect(node.size) == CGSize(width: 51, height: 44)
    #endif
    #if canImport(UIKit)
    expect(sizing) == ComposeNodeSizing(width: .fixed(51), height: .fixed(43))
    expect(node.size) == CGSize(width: 51, height: 43)
    #endif
  }

  func test_longString_multipleLines() throws {
    // given: a fixed size text node with a long string and unlimited lines
    let font = try unwrap(Font(name: "HelveticaNeue", size: 18))
    var node = TextNode(
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
      font: font
    )
    .numberOfLines(0)
    .fixedSize()

    // when: laying out the node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 100, height: 50), context: context)

    // then: the text wraps to multiple lines within the container width
    expect(sizing) == ComposeNodeSizing(width: .fixed(100), height: .fixed(280))
    expect(node.size) == CGSize(width: 100, height: 280)
  }

  func test_longString_singleLine() throws {
    // given: a fixed size text node with a long string and a single line
    let font = try unwrap(Font(name: "HelveticaNeue", size: 18))
    var node = TextNode(
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut",
      font: font
    )
    .numberOfLines(1)
    .fixedSize()

    // when: laying out the node
    let context = ComposeNodeLayoutContext(scaleFactor: 1)
    let sizing = node.layout(containerSize: CGSize(width: 1000, height: 50), context: context)

    // then: the text is sized to a single line
    expect(sizing) == ComposeNodeSizing(width: .fixed(751.0), height: .fixed(22))
    expect(node.size) == CGSize(width: 751.0, height: 22)
  }

  func test_view() {
    // given: a compose view with a default text node
    var textView: TextView?
    let contentView = ComposeView {
      TextNode("Hello, world!")
        .onUpdate { item, _ in
          textView = item.view as? TextView
        }
    }

    // when: the view is sized and refreshed
    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    contentView.refresh()

    // then: the text view is selectable and interactive but not editable
    #if !os(tvOS)
    expect(textView?.isEditable) == false
    #endif
    expect(textView?.isSelectable) == true

    #if canImport(AppKit)
    expect(textView?.ignoreHitTest) == false
    #endif
    #if canImport(UIKit)
    expect(textView?.isUserInteractionEnabled) == true
    #endif

    // when: the content is updated to a non-selectable, non-editable text node
    contentView.setContent {
      TextNode("Hello, world!")
        .selectable(false)
        .editable(false)
        .onUpdate { item, _ in
          textView = item.view as? TextView
        }
    }
    contentView.refresh()

    // then: the text view is not selectable and not interactive
    #if !os(tvOS)
    expect(textView?.isEditable) == false
    #endif
    expect(textView?.isSelectable) == false

    #if canImport(AppKit)
    expect(textView?.ignoreHitTest) == true
    #endif
    #if canImport(UIKit)
    expect(textView?.isUserInteractionEnabled) == false
    #endif

    // when: the content is updated to a selectable, editable text node
    contentView.setContent {
      TextNode("Hello, world!")
        .selectable()
        .editable()
        .onUpdate { item, _ in
          textView = item.view as? TextView
        }
    }
    contentView.refresh()

    // then: the text view is selectable, editable, and interactive
    #if !os(tvOS)
    expect(textView?.isEditable) == true
    #endif
    expect(textView?.isSelectable) == true

    #if canImport(AppKit)
    expect(textView?.ignoreHitTest) == false
    #endif
    #if canImport(UIKit)
    expect(textView?.isUserInteractionEnabled) == true
    #endif

    // when: the content is updated with a custom text container inset
    contentView.setContent {
      TextNode("Hello, world!")
        .textContainerInset(horizontal: 10, vertical: 20)
        .onUpdate { item, _ in
          textView = item.view as? TextView
        }
    }
    contentView.refresh()

    // then: the text view uses the inset
    #if canImport(AppKit)
    expect(textView?.textContainerInset) == CGSize(width: 10, height: 20)
    #endif

    #if canImport(UIKit)
    expect(textView?.textContainerInset) == EdgeInsets(top: 20, left: 10, bottom: 20, right: 10)
    #endif
  }

  func test_adjustIntrinsicTextSize() throws {
    // given: a fixed size text node with an intrinsic text size adjustment
    var textView: BaseTextView?
    let view = ComposeView {
      try TextNode("Hello, world!", font: unwrap(Font(name: "HelveticaNeue", size: 13)))
        .numberOfLines(1)
        .fixedSize()
        .intrinsicTextSizeAdjustment { original in
          CGSize(width: 10, height: 20)
        }
        .onInsert { renderable, _ in
          textView = renderable.view as? BaseTextView
        }
    }

    // when: the view is sized and refreshed
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    view.refresh()

    // then: the text view size includes the adjustment
    expect(textView?.bounds.size) == CGSize(width: 83, height: 36)
  }

  func test_renderableItems_doesNotRetainNodeThroughItemCache() {
    // The cached item's `update` closure must not capture `self` (the node holds the item cache), else
    // itemCache -> cachedItem -> update -> self -> itemCache leaks the node when the tree is replaced.

    // given: a weak probe captured by the node's intrinsic size adjustment closure
    weak var weakProbe: AnyObject?
    do {
      let probe = NSObject()
      weakProbe = probe
      // capture the probe via the node's intrinsic-size-adjustment closure; the cached update reaches it only if it
      // captures `self`.
      var node: any ComposeNode = TextNode("hi").intrinsicTextSizeAdjustment { original in
        _ = probe
        return original
      }

      // when: the node lays out, provides renderable items, and goes out of scope
      _ = node.layout(containerSize: CGSize(width: 10, height: 10), context: ComposeNodeLayoutContext(scaleFactor: 2))
      _ = node.renderableItems(in: CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    // then: the probe is released, so the cached item does not retain the node
    expect(weakProbe).to(beNil())
  }

  func test_renderableItems_sharedCache_selectableChange_notStale() {
    // Two copies of a base text node share its item cache (a reference in a value type). Changing `selectable` does not
    // change the frame, so the cache's frame key cannot detect it; the setter must reset the cache so the copy rebuilds
    // instead of returning the base's cached (selectable) item.

    // given: two copies of a base text node, one with selectable disabled
    let base = TextNode("hi").fixedSize(width: true, height: true)
    var defaultView: BaseTextView?
    var nonSelectableView: BaseTextView?
    let view = ComposeView {
      VStack {
        base.onUpdate { item, _ in defaultView = item.view as? BaseTextView }
        base.selectable(false).onUpdate { item, _ in nonSelectableView = item.view as? BaseTextView }
      }
    }

    // when: the view is sized and refreshed
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    view.refresh(animated: false)

    // then: each copy renders with its own selectable state
    expect(defaultView?.isSelectable) == true // TextNode is selectable by default
    expect(nonSelectableView?.isSelectable) == false // would be true (stale) if the setter did not reset the shared cache
  }
}
