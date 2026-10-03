//
//  ScrollView+ScrollingTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/30/26.
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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import ChouTiTest

import ComposeUI

class ScrollView_ScrollingTests: XCTestCase {

  func test_offsets() {
    // given: a scroll view with content size and insets, automatic inset adjustment disabled
    let scrollView = ScrollView()
    scrollView.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
    scrollView.contentSize = CGSize(width: 300, height: 500)
    scrollView.contentInset = EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)
    #if canImport(AppKit)
    scrollView.automaticallyAdjustsContentInsets = false
    #endif
    #if canImport(UIKit)
    scrollView.contentInsetAdjustmentBehavior = .never
    #endif

    // then: the min and max offsets account for the content size and insets
    expect(scrollView.minOffsetX) == -20
    expect(scrollView.maxOffsetX) == 240
    expect(scrollView.minOffsetY) == -10
    expect(scrollView.maxOffsetY) == 330
  }

  func test_canScroll() {
    // given: a scroll view with content size and insets, automatic inset adjustment disabled
    let scrollView = ScrollView()
    scrollView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    scrollView.contentSize = CGSize(width: 180, height: 220)
    scrollView.contentInset = EdgeInsets(top: 8, left: 6, bottom: 4, right: 2)
    #if canImport(AppKit)
    scrollView.automaticallyAdjustsContentInsets = false
    #endif
    #if canImport(UIKit)
    scrollView.contentInsetAdjustmentBehavior = .never
    #endif

    // when: scrolling to the minimum offset
    scrollView.contentOffset = CGPoint(x: scrollView.minOffsetX, y: scrollView.minOffsetY)

    // then: it can only scroll to the right and to the bottom
    expect(scrollView.canScrollToLeft) == false
    expect(scrollView.canScrollToRight) == true
    expect(scrollView.canScrollToTop) == false
    expect(scrollView.canScrollToBottom) == true

    // when: scrolling to the maximum offset
    scrollView.contentOffset = CGPoint(x: scrollView.maxOffsetX, y: scrollView.maxOffsetY)

    // then: it can only scroll to the left and to the top
    expect(scrollView.canScrollToLeft) == true
    expect(scrollView.canScrollToRight) == false
    expect(scrollView.canScrollToTop) == true
    expect(scrollView.canScrollToBottom) == false
  }

  func test_canScroll_withinAPixelOfAnEdge() {
    // given: a scroll view with content size and insets, automatic inset adjustment disabled
    let scrollView = ScrollView()
    scrollView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    scrollView.contentSize = CGSize(width: 180, height: 220)
    scrollView.contentInset = EdgeInsets(top: 8, left: 6, bottom: 4, right: 2)
    #if canImport(AppKit)
    scrollView.automaticallyAdjustsContentInsets = false
    #endif
    #if canImport(UIKit)
    scrollView.contentInsetAdjustmentBehavior = .never
    #endif

    // when: the offset is within a pixel of the minimum offset, at any display scale
    setExactOffset(CGPoint(x: scrollView.minOffsetX + 0.3, y: scrollView.minOffsetY + 0.3), of: scrollView)

    // then: it counts as at the left and top edges
    expect(scrollView.canScrollToLeft) == false
    expect(scrollView.canScrollToTop) == false

    // when: the offset is within a pixel of the maximum offset
    setExactOffset(CGPoint(x: scrollView.maxOffsetX - 0.3, y: scrollView.maxOffsetY - 0.3), of: scrollView)

    // then: it counts as at the right and bottom edges
    expect(scrollView.canScrollToRight) == false
    expect(scrollView.canScrollToBottom) == false

    // when: the offset is more than a pixel from the minimum offset, at any display scale
    setExactOffset(CGPoint(x: scrollView.minOffsetX + 1.5, y: scrollView.minOffsetY + 1.5), of: scrollView)

    // then: it can scroll to the left and to the top
    expect(scrollView.canScrollToLeft) == true
    expect(scrollView.canScrollToTop) == true

    // when: the offset is more than a pixel from the maximum offset
    setExactOffset(CGPoint(x: scrollView.maxOffsetX - 1.5, y: scrollView.maxOffsetY - 1.5), of: scrollView)

    // then: it can scroll to the right and to the bottom
    expect(scrollView.canScrollToRight) == true
    expect(scrollView.canScrollToBottom) == true
  }

  #if canImport(AppKit)
  func test_canScroll_magnified_withinAPixelOfAnEdge() {
    for (magnification, withinAPixel, beyondAPixel) in [(CGFloat(4), CGFloat(0.1), CGFloat(0.3)), (0.25, 1.5, 5)] {
      // given: a 100 × 100 scroll view showing 2000 × 2000 content, magnified, so that a pixel covers 1 / (scale ×
      // magnification) points of content: at most 0.25 at 4 times, and at least 2 at a quarter, at 1x or 2x
      let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      scrollView.contentSize = CGSize(width: 2000, height: 2000)
      scrollView.magnification = magnification

      // when: the offset is within a pixel of the minimum offset
      scrollView.contentOffset = CGPoint(x: scrollView.minOffsetX + withinAPixel, y: scrollView.minOffsetY + withinAPixel)

      // then: it counts as at the left and top edges
      expect(scrollView.canScrollToLeft) == false
      expect(scrollView.canScrollToTop) == false

      // when: the offset is within a pixel of the maximum offset
      scrollView.contentOffset = CGPoint(x: scrollView.maxOffsetX - withinAPixel, y: scrollView.maxOffsetY - withinAPixel)

      // then: it counts as at the right and bottom edges
      expect(scrollView.canScrollToRight) == false
      expect(scrollView.canScrollToBottom) == false

      // when: the offset is more than a pixel from the minimum offset
      scrollView.contentOffset = CGPoint(x: scrollView.minOffsetX + beyondAPixel, y: scrollView.minOffsetY + beyondAPixel)

      // then: it can scroll to the left and to the top
      expect(scrollView.canScrollToLeft) == true
      expect(scrollView.canScrollToTop) == true

      // when: the offset is more than a pixel from the maximum offset
      scrollView.contentOffset = CGPoint(x: scrollView.maxOffsetX - beyondAPixel, y: scrollView.maxOffsetY - beyondAPixel)

      // then: it can scroll to the right and to the bottom
      expect(scrollView.canScrollToRight) == true
      expect(scrollView.canScrollToBottom) == true
    }
  }

  func test_canScroll_nonUniformlyScaledBounds_usesEachAxisPixel() {
    // given: a 100 × 100 scroll view showing 2000 × 2000 content, with its bounds scaled 4 times along x and a quarter
    // along y, so that a pixel covers at most 0.25 points of content along x and at least 2 along y, at 1x or 2x
    let scrollView = ScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 2000, height: 2000)
    scrollView.scaleUnitSquare(to: NSSize(width: 4, height: 0.25))
    scrollView.tile()

    // when: the offset is 1.5 points from the minimum offset along both axes
    setExactOffset(CGPoint(x: scrollView.minOffsetX + 1.5, y: scrollView.minOffsetY + 1.5), of: scrollView)

    // then: it can scroll to the left, more than a pixel away along x, and counts as at the top, within a pixel along y
    expect(scrollView.canScrollToLeft) == true
    expect(scrollView.canScrollToTop) == false

    // when: the offset is 1.5 points from the maximum offset along both axes
    setExactOffset(CGPoint(x: scrollView.maxOffsetX - 1.5, y: scrollView.maxOffsetY - 1.5), of: scrollView)

    // then: it can scroll to the right, and counts as at the bottom
    expect(scrollView.canScrollToRight) == true
    expect(scrollView.canScrollToBottom) == false
  }

  func test_canScroll_rotated_withinAPixelOfAnEdge() {
    // given: a 100 × 100 scroll view showing 2000 × 2000 content, rotated 45 degrees in a window, where converting a
    // whole size to pixels would mix the axes
    let window = TestWindow()
    let scrollView = ScrollView(frame: CGRect(x: 200, y: 200, width: 100, height: 100))
    scrollView.contentSize = CGSize(width: 2000, height: 2000)
    window.contentView().addSubview(scrollView)
    scrollView.frameCenterRotation = 45

    // when: the offset is within a pixel of the minimum offset, at any display scale
    setExactOffset(CGPoint(x: scrollView.minOffsetX + 0.3, y: scrollView.minOffsetY + 0.3), of: scrollView)

    // then: it counts as at the left and top edges
    expect(scrollView.canScrollToLeft) == false
    expect(scrollView.canScrollToTop) == false

    // when: the offset is more than a pixel from the minimum offset, at any display scale
    setExactOffset(CGPoint(x: scrollView.minOffsetX + 1.5, y: scrollView.minOffsetY + 1.5), of: scrollView)

    // then: it can scroll to the left and to the top
    expect(scrollView.canScrollToLeft) == true
    expect(scrollView.canScrollToTop) == true
  }
  #endif

  // MARK: - Helpers

  /// Sets the content offset exactly, as the platform's own scrolling can leave it, since a set `contentOffset` rounds
  /// to whole pixels, while scrolling the clip view on AppKit, or assigning `bounds.origin` on UIKit, keeps it.
  private func setExactOffset(_ offset: CGPoint, of scrollView: ScrollView) {
    #if canImport(AppKit)
    scrollView.contentView.scroll(to: offset)
    scrollView.reflectScrolledClipView(scrollView.contentView)
    #endif
    #if canImport(UIKit)
    scrollView.bounds.origin = offset
    #endif
  }
}
