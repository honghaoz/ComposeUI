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
    do {
      // given: content size is smaller than bounds size
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 50, height: 50)
      }

      // when: set to auto
      contentView.scrollIndicatorBehavior = .auto
      contentView.refresh(animated: false)

      // then: content fits within bounds, both indicators should be hidden
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when: set to always shown
      contentView.scrollIndicatorBehavior = .always
      contentView.refresh(animated: false)

      // then: both indicators should be shown
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true

      // when: set to never shown
      contentView.scrollIndicatorBehavior = .never
      contentView.refresh(animated: false)

      // then: both indicators should be hidden
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when: set to manual mode
      contentView.scrollIndicatorBehavior = .manual
      contentView.refresh(animated: false)

      // then: it should not change
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when: manually flip the indicator values
      contentView.showsHorizontalScrollIndicator = true
      contentView.showsVerticalScrollIndicator = true
      contentView.refresh(animated: false)

      // then: it should follow the manual setting
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true

      // when: manually set mixed values
      contentView.showsHorizontalScrollIndicator = true
      contentView.showsVerticalScrollIndicator = false
      contentView.refresh(animated: false)

      // then: it should follow the manual setting
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == false
    }

    do {
      // given: content size is equal to bounds size
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 100, height: 100)
      }

      // when: set to auto
      contentView.scrollIndicatorBehavior = .auto
      contentView.refresh(animated: false)

      // then: content equals bounds, no overflow, both indicators should be hidden
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when: set to always shown
      contentView.scrollIndicatorBehavior = .always
      contentView.refresh(animated: false)

      // then: both indicators should be shown
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true

      // when: set to never shown
      contentView.scrollIndicatorBehavior = .never
      contentView.refresh(animated: false)

      // then: both indicators should be hidden
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when: set to manual mode
      contentView.scrollIndicatorBehavior = .manual
      contentView.refresh(animated: false)

      // then: it should not change
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when: manually flip the indicator values
      contentView.showsHorizontalScrollIndicator = true
      contentView.showsVerticalScrollIndicator = true
      contentView.refresh(animated: false)

      // then: it should follow the manual setting
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true
    }

    do {
      // given: content overflows horizontally only
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 150, height: 50)
      }

      // when: set to auto
      contentView.scrollIndicatorBehavior = .auto
      contentView.refresh(animated: false)

      // then: only horizontal overflows, only horizontal indicator should be shown
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == false

      // when: set to always shown
      contentView.scrollIndicatorBehavior = .always
      contentView.refresh(animated: false)

      // then: both indicators should be shown
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true

      // when: set to never shown
      contentView.scrollIndicatorBehavior = .never
      contentView.refresh(animated: false)

      // then: both indicators should be hidden
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when: set to manual mode
      contentView.scrollIndicatorBehavior = .manual
      contentView.refresh(animated: false)

      // then: it should not change
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when: manually flip the indicator values
      contentView.showsHorizontalScrollIndicator = false
      contentView.showsVerticalScrollIndicator = true
      contentView.refresh(animated: false)

      // then: it should follow the manual setting
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == true
    }

    do {
      // given: content overflows vertically only
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 50, height: 150)
      }

      // when: set to auto
      contentView.scrollIndicatorBehavior = .auto
      contentView.refresh(animated: false)

      // then: only vertical overflows, only vertical indicator should be shown
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == true

      // when: set to always shown
      contentView.scrollIndicatorBehavior = .always
      contentView.refresh(animated: false)

      // then: both indicators should be shown
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true

      // when: set to never shown
      contentView.scrollIndicatorBehavior = .never
      contentView.refresh(animated: false)

      // then: both indicators should be hidden
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when: set to manual mode
      contentView.scrollIndicatorBehavior = .manual
      contentView.refresh(animated: false)

      // then: it should not change
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when: manually flip the indicator values
      contentView.showsHorizontalScrollIndicator = true
      contentView.showsVerticalScrollIndicator = false
      contentView.refresh(animated: false)

      // then: it should follow the manual setting
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == false
    }

    do {
      // given: content overflows both directions
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 150, height: 150)
      }

      // when: set to auto
      contentView.scrollIndicatorBehavior = .auto
      contentView.refresh(animated: false)

      // then: both directions overflow, both indicators should be shown
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true

      // when: set to always shown
      contentView.scrollIndicatorBehavior = .always
      contentView.refresh(animated: false)

      // then: both indicators should be shown
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true

      // when: set to never shown
      contentView.scrollIndicatorBehavior = .never
      contentView.refresh(animated: false)

      // then: both indicators should be hidden
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when: set to manual mode
      contentView.scrollIndicatorBehavior = .manual
      contentView.refresh(animated: false)

      // then: it should not change
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false

      // when: manually flip the indicator values
      contentView.showsHorizontalScrollIndicator = true
      contentView.showsVerticalScrollIndicator = true
      contentView.refresh(animated: false)

      // then: it should follow the manual setting
      expect(contentView.showsHorizontalScrollIndicator) == true
      expect(contentView.showsVerticalScrollIndicator) == true

      // when: manually set the indicator values again
      contentView.showsHorizontalScrollIndicator = false
      contentView.showsVerticalScrollIndicator = false
      contentView.refresh(animated: false)

      // then: it should follow the manual setting
      expect(contentView.showsHorizontalScrollIndicator) == false
      expect(contentView.showsVerticalScrollIndicator) == false
    }
  }

  func test_scrollIndicatorBehavior_auto_contentFittingWithFloatingPointNoise() {
    // given: a view showing six columns a sixth of its width each, which the layout sums to a hair over its width
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.setContent {
      HStack {
        for _ in 0 ..< 6 {
          ColorNode(.red)
            .frame(width: 100.0 / 6, height: 100)
        }
      }
    }
    contentView.scrollIndicatorBehavior = .auto

    // when: the view refreshes
    contentView.refresh(animated: false)

    // then: the content fits, so both indicators are hidden
    expect(contentView.showsHorizontalScrollIndicator) == false
    expect(contentView.showsVerticalScrollIndicator) == false
  }

  func test_scrollIndicatorBehavior_auto_contentOverflowingByLessThanAPixel() {
    // given: a view whose content is a tenth of a point wider than the view, less than a pixel, with scroll bars that
    // take no space, since a legacy horizontal scroll bar on macOS would take height the content needs
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.setContent {
      ColorNode(.red)
        .frame(width: 100.1, height: 100)
    }
    contentView.scrollIndicatorBehavior = .auto
    #if canImport(AppKit)
    contentView.scrollerStyle = .overlay
    #endif

    // when: the view refreshes
    contentView.refresh(animated: false)

    // then: the content overflows horizontally, so only the horizontal indicator is shown
    expect(contentView.showsHorizontalScrollIndicator) == true
    expect(contentView.showsVerticalScrollIndicator) == false
  }

  func test_scrollIndicatorBehavior_auto_contentInsets_showTheIndicatorAlongAnAxisTheContentOverflowsBetweenThem() {
    // given: a 100 × 100 view that shows its scroll indicators automatically, as overlay scroll bars on macOS, showing
    // 50 × 50 content
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.setContent {
      ColorNode(.red)
        .frame(width: 50, height: 50)
    }
    contentView.scrollIndicatorBehavior = .auto
    #if canImport(AppKit)
    contentView.scrollerStyle = .overlay
    #endif

    // when: the view gets a 20 pt top inset and a 30 pt bottom inset, which the content fits between, and refreshes
    contentView.contentInset = EdgeInsets(top: 20, left: 0, bottom: 30, right: 0)
    contentView.refresh(animated: false)

    // then: the content and the insets fit the view, so both indicators are hidden
    expect(contentView.showsHorizontalScrollIndicator) == false
    expect(contentView.showsVerticalScrollIndicator) == false

    // when: the bottom inset grows to 40 pt, which leaves 40 pt for the content between the insets, and the view refreshes
    contentView.contentInset = EdgeInsets(top: 20, left: 0, bottom: 40, right: 0)
    contentView.refresh(animated: false)

    // then: the content overflows vertically between the insets, so only the vertical indicator shows
    expect(contentView.showsHorizontalScrollIndicator) == false
    expect(contentView.showsVerticalScrollIndicator) == true

    // when: the insets move to the left and right edges, and the view refreshes
    contentView.contentInset = EdgeInsets(top: 0, left: 20, bottom: 0, right: 40)
    contentView.refresh(animated: false)

    // then: the content overflows horizontally between the insets, so only the horizontal indicator shows
    expect(contentView.showsHorizontalScrollIndicator) == true
    expect(contentView.showsVerticalScrollIndicator) == false
  }

  func test_scrollIndicatorBehavior_auto_contentInsetChange_decidesTheScrollIndicatorsAgain() {
    // given: a 100 × 100 view that shows its scroll indicators automatically, as overlay scroll bars on macOS, and
    // rendered 50 × 50 content, which fits it, without scroll indicators
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.setContent {
      ColorNode(.red)
        .frame(width: 50, height: 50)
    }
    contentView.scrollIndicatorBehavior = .auto
    #if canImport(AppKit)
    contentView.scrollerStyle = .overlay
    #endif
    contentView.refresh(animated: false)
    expect(contentView.showsVerticalScrollIndicator) == false

    // when: the view gets a 30 pt top inset and a 30 pt bottom inset, which leave 40 pt for the content, and lays out
    // without a refresh
    contentView.contentInset = EdgeInsets(top: 30, left: 0, bottom: 30, right: 0)
    contentView.layoutIfNeeded()

    // then: the view renders again for the insets, which aren't a scroll, so it decides the scroll indicators again, and
    // shows the vertical one for the content that now overflows
    expect(contentView.isScrollEnabled) == true
    expect(contentView.showsVerticalScrollIndicator) == true
  }

  func test_scrollIndicatorBehavior_auto_flashesAShownScrollIndicatorAfterTheContentSizeIsSet() {
    // given: a 100 × 100 view that shows its scroll indicators automatically, as overlay scroll bars on macOS, and
    // rendered content that fits it
    var contentHeight: CGFloat = 50
    let contentView = FlashRecordingComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.setContent {
      ColorNode(.red)
        .frame(width: .flexible, height: contentHeight)
    }
    contentView.scrollIndicatorBehavior = .auto
    #if canImport(AppKit)
    contentView.scrollerStyle = .overlay
    #endif
    contentView.refresh(animated: false)
    expect(contentView.contentSizesWhenFlashing) == []

    // when: the content gets taller than the view, and the view refreshes
    contentHeight = 300
    contentView.refresh(animated: false)

    // then: the vertical scroll indicator flashes once, when the view already has the new content size, so the flash
    // shows the new scroll range
    expect(contentView.showsVerticalScrollIndicator) == true
    expect(contentView.contentSizesWhenFlashing) == [CGSize(width: 100, height: 300)]
  }

  func test_scrollIndicatorBehavior_changedToAuto_scrollDecidesTheScrollIndicators() {
    // given: a 100 × 100 view that never shows its scroll indicators, as overlay scroll bars on macOS, and rendered
    // content taller than it, then switched to showing them automatically
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.setContent {
      ColorNode(.red)
        .frame(width: .flexible, height: 300)
    }
    contentView.scrollIndicatorBehavior = .never
    #if canImport(AppKit)
    contentView.scrollerStyle = .overlay
    #endif
    contentView.refresh(animated: false)
    expect(contentView.showsVerticalScrollIndicator) == false
    contentView.scrollIndicatorBehavior = .auto

    // when: the view scrolls
    contentView.contentOffset = CGPoint(x: 0, y: 50)
    contentView.layoutIfNeeded()

    // then: the scroll is the first render pass under the automatic behavior, so it decides the scroll indicators instead
    // of keeping the hidden ones, and shows the vertical one
    expect(contentView.showsVerticalScrollIndicator) == true
  }
}

/// A view that records its content size each time it flashes its scroll indicators.
private final class FlashRecordingComposeView: ComposeView {

  /// The content sizes the view had when it flashed its scroll indicators, in order.
  var contentSizesWhenFlashing: [CGSize] = []

  #if canImport(AppKit)
  override func flashScrollers() {
    contentSizesWhenFlashing.append(contentSize)
    super.flashScrollers()
  }
  #endif

  #if canImport(UIKit)
  override func flashScrollIndicators() {
    contentSizesWhenFlashing.append(contentSize)
    super.flashScrollIndicators()
  }
  #endif
}
