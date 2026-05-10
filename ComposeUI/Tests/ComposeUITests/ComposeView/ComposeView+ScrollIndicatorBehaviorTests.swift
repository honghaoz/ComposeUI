//
//  ComposeView+ScrollIndicatorBehaviorTests.swift
//  ComposéUI
//
//  Created by Honghao on 5/9/25.
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

class ComposeView_ScrollIndicatorBehaviorTests: XCTestCase {

  func test_scrollIndicatorBehavior() {
    // when content size is smaller than bounds size
    do {
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 50, height: 50)
      }

      // when set to auto, content fits within bounds, both indicators should be hidden
      contentView.scrollIndicatorBehavior = .auto
      contentView.refresh(animated: false)
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when set to always shown
      contentView.scrollIndicatorBehavior = .always
      contentView.refresh(animated: false)
      // then both indicators should be shown
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true

      // when set to never shown
      contentView.scrollIndicatorBehavior = .never
      contentView.refresh(animated: false)
      // then both indicators should be hidden
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when set to manual mode
      contentView.scrollIndicatorBehavior = .manual
      contentView.refresh(animated: false)
      // then it should not change
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when manually flip the indicator values
      contentView.showsHorizontalScrollIndicator = true
      contentView.showsVerticalScrollIndicator = true
      contentView.refresh(animated: false)
      // then it should follow the manual setting
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true

      // when manually set mixed values
      contentView.showsHorizontalScrollIndicator = true
      contentView.showsVerticalScrollIndicator = false
      contentView.refresh(animated: false)
      // then it should follow the manual setting
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == false
    }

    // when content size is equal to bounds size
    do {
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 100, height: 100)
      }

      // when set to auto, content equals bounds, no overflow, both indicators should be hidden
      contentView.scrollIndicatorBehavior = .auto
      contentView.refresh(animated: false)
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when set to always shown
      contentView.scrollIndicatorBehavior = .always
      contentView.refresh(animated: false)
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true

      // when set to never shown
      contentView.scrollIndicatorBehavior = .never
      contentView.refresh(animated: false)
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when set to manual mode
      contentView.scrollIndicatorBehavior = .manual
      contentView.refresh(animated: false)
      // then it should not change
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when manually flip the indicator values
      contentView.showsHorizontalScrollIndicator = true
      contentView.showsVerticalScrollIndicator = true
      contentView.refresh(animated: false)
      // then it should follow the manual setting
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true
    }

    // when content overflows horizontally only
    do {
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 150, height: 50)
      }

      // when set to auto, only horizontal overflows, only horizontal indicator should be shown
      contentView.scrollIndicatorBehavior = .auto
      contentView.refresh(animated: false)
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == false

      // when set to always shown
      contentView.scrollIndicatorBehavior = .always
      contentView.refresh(animated: false)
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true

      // when set to never shown
      contentView.scrollIndicatorBehavior = .never
      contentView.refresh(animated: false)
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when set to manual mode
      contentView.scrollIndicatorBehavior = .manual
      contentView.refresh(animated: false)
      // then it should not change
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when manually flip the indicator values
      contentView.showsHorizontalScrollIndicator = false
      contentView.showsVerticalScrollIndicator = true
      contentView.refresh(animated: false)
      // then it should follow the manual setting
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == true
    }

    // when content overflows vertically only
    do {
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 50, height: 150)
      }

      // when set to auto, only vertical overflows, only vertical indicator should be shown
      contentView.scrollIndicatorBehavior = .auto
      contentView.refresh(animated: false)
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == true

      // when set to always shown
      contentView.scrollIndicatorBehavior = .always
      contentView.refresh(animated: false)
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true

      // when set to never shown
      contentView.scrollIndicatorBehavior = .never
      contentView.refresh(animated: false)
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when set to manual mode
      contentView.scrollIndicatorBehavior = .manual
      contentView.refresh(animated: false)
      // then it should not change
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when manually flip the indicator values
      contentView.showsHorizontalScrollIndicator = true
      contentView.showsVerticalScrollIndicator = false
      contentView.refresh(animated: false)
      // then it should follow the manual setting
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == false
    }

    // when content overflows both directions
    do {
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 150, height: 150)
      }

      // when set to auto, both directions overflow, both indicators should be shown
      contentView.scrollIndicatorBehavior = .auto
      contentView.refresh(animated: false)
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true

      // when set to always shown
      contentView.scrollIndicatorBehavior = .always
      contentView.refresh(animated: false)
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true

      // when set to never shown
      contentView.scrollIndicatorBehavior = .never
      contentView.refresh(animated: false)
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when set to manual mode
      contentView.scrollIndicatorBehavior = .manual
      contentView.refresh(animated: false)
      // then it should not change
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when manually flip the indicator values
      contentView.showsHorizontalScrollIndicator = true
      contentView.showsVerticalScrollIndicator = true
      contentView.refresh(animated: false)
      // then it should follow the manual setting
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true

      // when manually set the indicator values again
      contentView.showsHorizontalScrollIndicator = false
      contentView.showsVerticalScrollIndicator = false
      contentView.refresh(animated: false)
      // then it should follow the manual setting
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false
    }
  }
}
