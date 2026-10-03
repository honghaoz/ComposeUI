//
//  ComposeView+ScrollBehaviorTests.swift
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

class ComposeView_ScrollBehaviorTests: XCTestCase {

  func test_scrollBehavior() {
    do {
      // given: a rendered view whose content size is smaller than bounds size
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 50, height: 50)
      }
      contentView.refresh(animated: false)

      // then: the view is not scrollable since the content size is smaller than bounds size
      expect(contentView.isScrollEnabled) == false

      // when: set to always scrollable
      contentView.scrollBehavior = .always
      contentView.refresh(animated: false)

      // then: the view is scrollable and always bounces
      expect(contentView.isScrollEnabled) == true
      expect(contentView.alwaysBounceHorizontal) == true
      expect(contentView.alwaysBounceVertical) == true

      // when: set to never scrollable
      contentView.scrollBehavior = .never
      contentView.refresh(animated: false)

      // then: the view is not scrollable and does not bounce
      expect(contentView.isScrollEnabled) == false
      expect(contentView.alwaysBounceHorizontal) == false
      expect(contentView.alwaysBounceVertical) == false

      // when: set to manual mode
      contentView.scrollBehavior = .manual
      contentView.refresh(animated: false)

      // then: the view's scrollable behavior is not changed
      expect(contentView.isScrollEnabled) == false
      expect(contentView.alwaysBounceHorizontal) == false
      expect(contentView.alwaysBounceVertical) == false

      // when: manually set the scrollable behavior and refresh
      contentView.isScrollEnabled = true
      contentView.alwaysBounceHorizontal = true
      contentView.alwaysBounceVertical = true

      contentView.refresh(animated: false)

      // then: the view's scrollable behavior is not changed after refresh
      expect(contentView.isScrollEnabled) == true
      expect(contentView.alwaysBounceHorizontal) == true
      expect(contentView.alwaysBounceVertical) == true
    }

    do {
      // given: a rendered view whose content size is equal to bounds size
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 100, height: 100)
      }
      contentView.refresh(animated: false)

      // then: the view is not scrollable since the content size is equal to bounds size
      expect(contentView.isScrollEnabled) == false

      // when: set to always scrollable
      contentView.scrollBehavior = .always
      contentView.refresh(animated: false)

      // then: the view is scrollable and always bounces
      expect(contentView.isScrollEnabled) == true
      expect(contentView.alwaysBounceHorizontal) == true
      expect(contentView.alwaysBounceVertical) == true

      // when: set to never scrollable
      contentView.scrollBehavior = .never
      contentView.refresh(animated: false)

      // then: the view is not scrollable and does not bounce
      expect(contentView.isScrollEnabled) == false
      expect(contentView.alwaysBounceHorizontal) == false
      expect(contentView.alwaysBounceVertical) == false

      // when: set to manual mode
      contentView.scrollBehavior = .manual
      contentView.refresh(animated: false)

      // then: the view's scrollable behavior is not changed
      expect(contentView.isScrollEnabled) == false
      expect(contentView.alwaysBounceHorizontal) == false
      expect(contentView.alwaysBounceVertical) == false

      // when: manually set the scrollable behavior and refresh
      contentView.isScrollEnabled = true
      contentView.alwaysBounceHorizontal = true
      contentView.alwaysBounceVertical = true

      contentView.refresh(animated: false)

      // then: the view's scrollable behavior is not changed after refresh
      expect(contentView.isScrollEnabled) == true
      expect(contentView.alwaysBounceHorizontal) == true
      expect(contentView.alwaysBounceVertical) == true
    }

    do {
      // given: a rendered view whose content size is larger than bounds size
      let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      contentView.setContent {
        ColorNode(.red)
          .frame(width: 150, height: 150)
      }
      contentView.refresh(animated: false)

      // then: the view is scrollable since the content size is larger than bounds size
      expect(contentView.isScrollEnabled) == true

      // when: set to never scrollable
      contentView.scrollBehavior = .never
      contentView.refresh(animated: false)

      // then: the view is not scrollable and does not bounce
      expect(contentView.isScrollEnabled) == false
      expect(contentView.alwaysBounceHorizontal) == false
      expect(contentView.alwaysBounceVertical) == false

      // when: set to always scrollable
      contentView.scrollBehavior = .always
      contentView.refresh(animated: false)

      // then: the view is scrollable and always bounces
      expect(contentView.isScrollEnabled) == true
      expect(contentView.alwaysBounceHorizontal) == true
      expect(contentView.alwaysBounceVertical) == true

      // when: set to manual mode
      contentView.scrollBehavior = .manual
      contentView.refresh(animated: false)

      // then: the view's scrollable behavior is not changed
      expect(contentView.isScrollEnabled) == true
      expect(contentView.alwaysBounceHorizontal) == true
      expect(contentView.alwaysBounceVertical) == true

      // when: manually set the scrollable behavior and refresh
      contentView.isScrollEnabled = false
      contentView.alwaysBounceHorizontal = false
      contentView.alwaysBounceVertical = false

      contentView.refresh(animated: false)

      // then: the view's scrollable behavior is not changed after refresh
      expect(contentView.isScrollEnabled) == false
      expect(contentView.alwaysBounceHorizontal) == false
      expect(contentView.alwaysBounceVertical) == false
    }
  }

  func test_scrollBehavior_auto_contentFittingWithFloatingPointNoise() throws {
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
    var laidOutContentSize: CGSize?
    contentView.onDidRender { _, context in
      laidOutContentSize = context.contentSize
    }

    // when: the view refreshes
    contentView.refresh(animated: false)

    // then: the content is wider than the view by floating-point noise only
    let contentWidth = try unwrap(laidOutContentSize).width
    expect(contentWidth) > 100
    expect(contentWidth).to(beApproximatelyEqual(to: 100, within: 1e-9))

    // then: the content fits, so the view neither scrolls nor clips, and has nothing to scroll horizontally
    expect(contentView.isScrollEnabled) == false
    expect(contentView.clipsToBounds) == false
    expect(contentView.contentSize.width) == 100
  }

  func test_scrollBehavior_auto_contentFittingOneAxisWithFloatingPointNoise() {
    // given: a view whose content overflows vertically and is wider than the view by floating-point noise, which rounding
    // up to whole pixels would turn into a pixel
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.setContent {
      ColorNode(.red)
        .frame(width: 100 + 1e-9, height: 300)
    }

    // when: the view refreshes
    contentView.refresh(animated: false)

    // then: the view scrolls, but its content is as wide as the view, so it scrolls only vertically
    expect(contentView.isScrollEnabled) == true
    expect(contentView.contentSize) == CGSize(width: 100, height: 300)

    #if canImport(AppKit)
    // when: the scroll elasticity updates
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    // then: the view bounces only vertically
    expect(contentView.horizontalScrollElasticity) == .none
    expect(contentView.verticalScrollElasticity) == .allowed
    #endif
  }

  func test_scrollBehavior_auto_contentOverflowingByLessThanAPixel() {
    // given: a view whose content is a tenth of a point wider than the view, less than a pixel
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.setContent {
      ColorNode(.red)
        .frame(width: 100.1, height: 100)
    }

    // when: the view refreshes
    contentView.refresh(animated: false)

    // then: the content overflows, so the view scrolls and clips
    expect(contentView.isScrollEnabled) == true
    expect(contentView.clipsToBounds) == true
  }

  #if canImport(AppKit)
  func test_scrollElasticity_followsTheContentSizeAndTheRenderSize() {
    // given: a 100 × 100 view with overlay scroll bars that rendered content that fits it
    var contentHeight: CGFloat = 50
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.setContent {
      ColorNode(.red)
        .frame(width: 50, height: contentHeight)
    }
    contentView.scrollerStyle = .overlay
    contentView.refresh(animated: false)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))
    expect(contentView.verticalScrollElasticity) == .none

    // when: the content gets taller than the view, the view refreshes, and the scroll elasticity updates
    contentHeight = 300
    contentView.refresh(animated: false)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    // then: the content size changed, so the view bounces vertically
    expect(contentView.contentSize) == CGSize(width: 100, height: 300)
    expect(contentView.verticalScrollElasticity) == .allowed

    // when: the view scrolls, which changes neither the content size nor the render size
    contentView.contentOffset = CGPoint(x: 0, y: 50)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    // then: the view still bounces vertically
    expect(contentView.verticalScrollElasticity) == .allowed

    // when: the view gets as tall as the content, which changes the render size but keeps the content size
    contentView.frame.size = CGSize(width: 100, height: 300)
    contentView.layoutIfNeeded()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))

    // then: the content fits, so the view stops bouncing vertically
    expect(contentView.contentSize) == CGSize(width: 100, height: 300)
    expect(contentView.verticalScrollElasticity) == .none
  }
  #endif
}
