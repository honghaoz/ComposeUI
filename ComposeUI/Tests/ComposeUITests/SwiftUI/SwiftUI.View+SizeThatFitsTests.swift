//
//  SwiftUI.View+SizeThatFitsTests.swift
//  ComposéUI
//
//  Created by Honghao on 6/30/25.
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

import SwiftUI
import ComposeUI

class SwiftUI_View_SizeThatFitsTests: XCTestCase {

  func test_sizeThatFits() {
    // when the view has a fixed size
    do {
      let view = SwiftUI.Color.black.frame(width: 80, height: 50)

      // when proposing size is larger
      expect(
        view.sizeThatFits(CGSize(width: 100, height: 100))
      ) == CGSize(width: 80, height: 50)

      // when proposing size is smaller
      expect(
        view.sizeThatFits(CGSize(width: 50, height: 40))
      ) == CGSize(width: 80, height: 50)
    }

    // when the view has a flexible size
    do {
      let view = SwiftUI.Color.black

      // when proposing size is larger
      expect(
        view.sizeThatFits(CGSize(width: 100, height: 100))
      ) == CGSize(width: 100, height: 100)

      // when proposing size is smaller
      expect(
        view.sizeThatFits(CGSize(width: 50, height: 50))
      ) == CGSize(width: 50, height: 50)
    }
  }
}
