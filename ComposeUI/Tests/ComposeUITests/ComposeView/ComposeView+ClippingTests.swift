//
//  ComposeView+ClippingTests.swift
//  ComposéUI
//
//  Created by Honghao on 5/10/25.
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

class ComposeView_ClippingTests: XCTestCase {

  func test_clippingBehavior() {
    // when view is not scrollable
    do {
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 50, height: 50)
      }
      contentView.refresh(animated: false)

      // should not clip
      expect(contentView.clipsToBounds) == false
      #if canImport(AppKit)
      expect(contentView.contentView.clipsToBounds) == false
      #endif

      // when set to always clipping
      contentView.clippingBehavior = .always
      contentView.refresh(animated: false)
      expect(contentView.clipsToBounds) == true
      #if canImport(AppKit)
      expect(contentView.contentView.clipsToBounds) == true
      #endif

      // when set to never clipping
      contentView.clippingBehavior = .never
      contentView.refresh(animated: false)
      expect(contentView.clipsToBounds) == false
      #if canImport(AppKit)
      expect(contentView.contentView.clipsToBounds) == false
      #endif
    }

    do {
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 100, height: 100)
      }
      contentView.refresh(animated: false)

      // should not clip
      expect(contentView.clipsToBounds) == false
      #if canImport(AppKit)
      expect(contentView.contentView.clipsToBounds) == false
      #endif

      // when set to always clipping
      contentView.clippingBehavior = .always
      contentView.refresh(animated: false)
      expect(contentView.clipsToBounds) == true
      #if canImport(AppKit)
      expect(contentView.contentView.clipsToBounds) == true
      #endif

      // when set to never clipping
      contentView.clippingBehavior = .never
      contentView.refresh(animated: false)
      expect(contentView.clipsToBounds) == false
      #if canImport(AppKit)
      expect(contentView.contentView.clipsToBounds) == false
      #endif
    }

    // when view is scrollable
    do {
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 150, height: 50)
      }
      contentView.refresh(animated: false)

      // should clip
      expect(contentView.clipsToBounds) == true
      #if canImport(AppKit)
      expect(contentView.contentView.clipsToBounds) == true
      #endif

      // when set to always clipping
      contentView.clippingBehavior = .always
      contentView.refresh(animated: false)
      expect(contentView.clipsToBounds) == true
      #if canImport(AppKit)
      expect(contentView.contentView.clipsToBounds) == true
      #endif

      // when set to never clipping
      contentView.clippingBehavior = .never
      contentView.refresh(animated: false)
      expect(contentView.clipsToBounds) == false
      #if canImport(AppKit)
      expect(contentView.contentView.clipsToBounds) == false
      #endif
    }
  }
}
