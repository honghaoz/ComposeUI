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
      var labelView: BaseLabel?
      let view = ComposeView {
        try LabelNode("Hello World")
          .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
          .onInsert { renderable, _ in
            labelView = renderable.view as? BaseLabel
          }
      }

      view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

      view.refresh()

      expect(labelView?.text) == "Hello World"
      expect(labelView?.bounds.size) == CGSize(width: 67, height: 16.0)
      expect(labelView?.textAlignment) == .center
      expect(labelView?.numberOfLines) == 1
      expect(labelView?.lineBreakMode) == .byTruncatingTail
    }

    // when flexible width
    do {
      var labelView: BaseLabel?
      let view = ComposeView {
        try LabelNode("Hello World")
          .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
          .fixedSize(width: false, height: true)
          .onInsert { renderable, _ in
            labelView = renderable.view as? BaseLabel
          }
      }

      view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

      view.refresh()

      expect(labelView?.text) == "Hello World"
      expect(labelView?.bounds.size) == CGSize(width: 100, height: 16.0)
      expect(labelView?.textAlignment) == .center
      expect(labelView?.numberOfLines) == 1
      expect(labelView?.lineBreakMode) == .byTruncatingTail
    }
  }

  func test_singleLine_notEnoughWidth() throws {
    // when fixed size
    do {
      var labelView: BaseLabel?
      let view = ComposeView {
        try LabelNode("Hello World")
          .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
          .onInsert { renderable, _ in
            labelView = renderable.view as? BaseLabel
          }
      }

      view.frame = CGRect(x: 0, y: 0, width: 50, height: 50)

      view.refresh()

      expect(labelView?.text) == "Hello World"
      expect(labelView?.bounds.size) == CGSize(width: 67, height: 16)
      expect(labelView?.textAlignment) == .center
      expect(labelView?.numberOfLines) == 1
      expect(labelView?.lineBreakMode) == .byTruncatingTail
    }

    // when flexible width
    do {
      var labelView: BaseLabel?
      let view = ComposeView {
        try LabelNode("Hello World")
          .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
          .fixedSize(width: false, height: true)
          .onInsert { renderable, _ in
            labelView = renderable.view as? BaseLabel
          }
      }

      view.frame = CGRect(x: 0, y: 0, width: 50, height: 50)

      view.refresh()

      expect(labelView?.text) == "Hello World"
      expect(labelView?.bounds.size) == CGSize(width: 50, height: 16)
      expect(labelView?.textAlignment) == .center
      expect(labelView?.numberOfLines) == 1
      expect(labelView?.lineBreakMode) == .byTruncatingTail
    }
  }

  func test_singleLineWithNewline_enoughWidth() throws {
    var labelView: BaseLabel?
    let view = ComposeView {
      try LabelNode("Hello\nWorld")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        .onInsert { renderable, _ in
          labelView = renderable.view as? BaseLabel
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    view.refresh()

    expect(labelView?.text) == "Hello\nWorld"
    expect(labelView?.bounds.size) == CGSize(width: 30, height: 16.0)
    expect(labelView?.textAlignment) == .center
    expect(labelView?.numberOfLines) == 1
    expect(labelView?.lineBreakMode) == .byTruncatingTail
  }

  func test_singleLineWithNewline_notEnoughWidth() throws {
    var labelView: BaseLabel?
    let view = ComposeView {
      try LabelNode("Hello\nWorld")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        .onInsert { renderable, _ in
          labelView = renderable.view as? BaseLabel
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 50, height: 50)

    view.refresh()

    expect(labelView?.text) == "Hello\nWorld"
    expect(labelView?.bounds.size) == CGSize(width: 30, height: 16.0)
    expect(labelView?.textAlignment) == .center
    expect(labelView?.numberOfLines) == 1
    expect(labelView?.lineBreakMode) == .byTruncatingTail
  }

  func test_singleLine_lineBreakMode() throws {
    var labelView: BaseLabel?
    let view = ComposeView {
      try LabelNode("Hello World")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        .lineBreakMode(.byWordWrapping)
        .onInsert { renderable, _ in
          labelView = renderable.view as? BaseLabel
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    view.refresh()

    expect(labelView?.bounds.size) == CGSize(width: 67, height: 16.0)
    expect(labelView?.textAlignment) == .center
    expect(labelView?.numberOfLines) == 1
    #if canImport(AppKit)
    expect(labelView?.lineBreakMode) == .byTruncatingTail // byWordWrapping is not supported for single-line labels
    #endif
  }

  // MARK: - Multi-line

  func test_multiLine_flexible() throws {
    var labelView: BaseLabel?
    let view = ComposeView {
      try LabelNode("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        .numberOfLines(0)
        .onInsert { renderable, _ in
          labelView = renderable.view as? BaseLabel
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 98, height: 100)

    view.refresh()

    expect(labelView?.text) == "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
    #if canImport(AppKit)
    expect(labelView?.bounds.size) == CGSize(width: 95, height: 165)
    #endif
    #if canImport(UIKit)
    expect(labelView?.bounds.size) == CGSize(width: 98, height: 137)
    #endif
    expect(labelView?.textAlignment) == .center
    expect(labelView?.numberOfLines) == 0
    #if canImport(AppKit)
    expect(labelView?.lineBreakMode) == .byWordWrapping
    #endif
  }

  func test_multiLine_fixedWidth_flexibleHeight() throws {
    var labelView: BaseLabel?
    let view = ComposeView {
      try LabelNode("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        .numberOfLines(0)
        .fixedSize(width: true, height: false)
        .onInsert { renderable, _ in
          labelView = renderable.view as? BaseLabel
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 98, height: 100)

    view.refresh()

    #if canImport(AppKit)
    expect(labelView?.bounds.size) == CGSize(width: 95, height: 100)
    #endif
    #if canImport(UIKit)
    expect(labelView?.bounds.size) == CGSize(width: 98, height: 100)
    #endif
  }

  func test_multiLine_flexibleWidth_fixedHeight() throws {
    var labelView: BaseLabel?
    let view = ComposeView {
      try LabelNode("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        .numberOfLines(0)
        .fixedSize(width: false, height: true)
        .onInsert { renderable, _ in
          labelView = renderable.view as? BaseLabel
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 98, height: 100)

    view.refresh()

    #if canImport(AppKit)
    expect(labelView?.bounds.size) == CGSize(width: 98, height: 165)
    #endif
    #if canImport(UIKit)
    expect(labelView?.bounds.size) == CGSize(width: 98, height: 137)
    #endif
  }

  func test_multiLine_fixedSize() throws {
    var labelView: BaseLabel?
    let view = ComposeView {
      try LabelNode("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        .numberOfLines(0)
        .fixedSize()
        .onInsert { renderable, _ in
          labelView = renderable.view as? BaseLabel
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 98, height: 100)

    view.refresh()

    #if canImport(AppKit)
    expect(labelView?.bounds.size) == CGSize(width: 95, height: 165)
    #endif
    #if canImport(UIKit)
    expect(labelView?.bounds.size) == CGSize(width: 98, height: 137)
    #endif
  }

  func test_multiLine_flexibleSize() throws {
    var labelView: BaseLabel?
    let view = ComposeView {
      try LabelNode("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
        .font(unwrap(Font(name: "HelveticaNeue", size: 13)))
        .numberOfLines(0)
        .flexibleSize()
        .onInsert { renderable, _ in
          labelView = renderable.view as? BaseLabel
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    view.refresh()

    expect(labelView?.bounds.size) == CGSize(width: 100, height: 100)
  }

  // MARK: - Modifiers

  func test_modifiers() throws {
    var labelView: BaseLabel?
    let view = ComposeView {
      try LabelNode("Hello World")
        .font(unwrap(Font(name: "HelveticaNeue", size: 20)))
        .textColor(.red)
        .textAlignment(.right)
        .onInsert { renderable, _ in
          labelView = renderable.view as? BaseLabel
        }
    }

    view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    view.refresh()

    try expect(labelView?.font) == unwrap(Font(name: "HelveticaNeue", size: 20))
    expect(labelView?.textColor) == .red
    expect(labelView?.textAlignment) == .right
  }
}
