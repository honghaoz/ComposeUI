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

import ComposeUI

class ButtonNodeTests: XCTestCase {

  func test_flexibleSize() throws {
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
      .onInsert { renderable, _ in
        view = renderable.view as? ButtonView
      }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    contentView.refresh()

    expect(try view.unwrap().bounds.size) == CGSize(width: 100, height: 50)
    let buttonContentDescription = try "\(view.unwrap().content)"
    expect(buttonContentDescription.hasPrefix("[ComposeUI.ColorNode"), buttonContentDescription) == true
  }

  func test_fixedSize() throws {
    var view: ButtonView?
    let contentView = ComposeView {
      ButtonNode(
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
      .onInsert { renderable, _ in
        view = renderable.view as? ButtonView
      }
    }

    contentView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
    contentView.refresh()

    expect(try view.unwrap().bounds.size) == CGSize(width: 50, height: 20)
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
