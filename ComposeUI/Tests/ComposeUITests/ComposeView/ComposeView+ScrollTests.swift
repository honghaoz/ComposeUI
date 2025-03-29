//
//  ComposeView+ScrollTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/28/25.
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

final class ComposeView_ScrollTests: XCTestCase {

  func test_scrollBehavior() {
    // when content size is smaller than bounds size
    do {
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 50, height: 50)
      }
      contentView.refresh(animated: false)

      // expect the view is not scrollable since the content size is smaller than bounds size
      expect(contentView.isScrollable) == false

      // when set to always scrollable
      contentView.scrollBehavior = .always
      contentView.refresh(animated: false)
      expect(contentView.isScrollable) == true

      // when set to never scrollable
      contentView.scrollBehavior = .never
      contentView.refresh(animated: false)
      expect(contentView.isScrollable) == false
    }

    // when content size is equal to bounds size
    do {
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 100, height: 100)
      }
      contentView.refresh(animated: false)

      // expect the view is not scrollable since the content size is equal to bounds size
      expect(contentView.isScrollable) == false

      // when set to always scrollable
      contentView.scrollBehavior = .always
      contentView.refresh(animated: false)
      expect(contentView.isScrollable) == true

      // when set to never scrollable
      contentView.scrollBehavior = .never
      contentView.refresh(animated: false)
      expect(contentView.isScrollable) == false
    }

    // when content size is larger than bounds size
    do {
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 150, height: 150)
      }
      contentView.refresh(animated: false)

      // expect the view is scrollable since the content size is larger than bounds size
      expect(contentView.isScrollable) == true

      // when set to never scrollable
      contentView.scrollBehavior = .never
      contentView.refresh(animated: false)
      expect(contentView.isScrollable) == false

      // when set to always scrollable
      contentView.scrollBehavior = .always
      contentView.refresh(animated: false)
      expect(contentView.isScrollable) == true
    }
  }
}
