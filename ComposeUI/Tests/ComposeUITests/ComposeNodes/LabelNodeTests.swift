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

import ComposeUI

class LabelNodeTests: XCTestCase {

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
    expect(textView?.bounds.size) == CGSize(width: 99, height: 100)
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
    expect(textView?.bounds.size) == CGSize(width: 98, height: 136)
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
    expect(textView?.bounds.size) == CGSize(width: 98, height: 136)
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
    expect(textView?.bounds.size) == CGSize(width: 99, height: 136)
    expect(textView?.numberOfLines) == 0
    expect(textView?.attributedString.paragraphStyle()?.alignment) == .center
    expect(textView?.attributedString.paragraphStyle()?.lineBreakMode) == .byWordWrapping
    expect(textView?.lineBreakMode) == .byTruncatingTail
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
