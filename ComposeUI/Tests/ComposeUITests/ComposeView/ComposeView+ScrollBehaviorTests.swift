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

  func test_scrollBehavior_auto_contentInsets_contentThatFitsBetweenThemCentersThere() {
    // given: a 100 × 100 view with a 20 pt top inset and a 30 pt bottom inset, showing content 50 pt wide and as tall as
    // the 50 pt between the insets
    var contentHeight: CGFloat = 50
    var contentLayer: CALayer?
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.setContent {
      LayerNode<CALayer>(update: { layer, _ in contentLayer = layer })
        .frame(width: 50, height: contentHeight)
    }
    contentView.contentInset = EdgeInsets(top: 20, left: 0, bottom: 30, right: 0)

    // when: the view refreshes
    contentView.refresh(animated: false)

    // then: the content and the insets fit the view, so it neither scrolls nor clips, and rests with the content filling
    // the space between the insets, 20 to 70 pt from the view's top
    expect(contentView.isScrollEnabled) == false
    expect(contentView.clipsToBounds) == false
    expect(contentView.minOffsetY) == -20
    expect(contentView.maxOffsetY) == -20
    expect(contentView.contentOffset) == CGPoint(x: 0, y: -20)
    expect(contentLayer?.frame) == CGRect(x: 25, y: 0, width: 50, height: 50)

    // when: the content gets 30 pt tall, and the view refreshes
    contentHeight = 30
    contentView.refresh(animated: false)

    // then: the content centers between the insets, 30 to 60 pt from the view's top, instead of in the whole view
    expect(contentView.isScrollEnabled) == false
    expect(contentView.contentOffset) == CGPoint(x: 0, y: -20)
    expect(contentLayer?.frame) == CGRect(x: 25, y: 10, width: 50, height: 30)
  }

  func test_scrollBehavior_auto_contentInsets_contentThatOverflowsBetweenThemScrollsByTheOverflow() {
    // given: a 100 × 100 view with a 20 pt top inset and a 30 pt bottom inset, showing content 50 pt wide and 60 pt tall,
    // 10 pt taller than the space between the insets
    var contentLayer: CALayer?
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.setContent {
      LayerNode<CALayer>(update: { layer, _ in contentLayer = layer })
        .frame(width: 50, height: 60)
    }
    contentView.contentInset = EdgeInsets(top: 20, left: 0, bottom: 30, right: 0)

    // when: the view refreshes
    contentView.refresh(animated: false)

    // then: the view scrolls vertically by the 10 pt overflow, and the content starts at the top of the scroll range
    // instead of centering
    expect(contentView.isScrollEnabled) == true
    expect(contentView.minOffsetY) == -20
    expect(contentView.maxOffsetY) == -10
    expect(contentLayer?.frame) == CGRect(x: 25, y: 0, width: 50, height: 60)

    // when: the insets move to the left and right edges, 30 pt each, and the view refreshes
    contentView.contentInset = EdgeInsets(top: 0, left: 30, bottom: 0, right: 30)
    contentView.refresh(animated: false)

    // then: the content fits vertically and overflows the 40 pt between the side insets by 10 pt, so the view scrolls
    // horizontally by that, and the content centers vertically
    expect(contentView.isScrollEnabled) == true
    expect(contentView.minOffsetX) == -30
    expect(contentView.maxOffsetX) == -20
    expect(contentView.maxOffsetY) == contentView.minOffsetY
    expect(contentLayer?.frame) == CGRect(x: 0, y: 20, width: 50, height: 60)
  }

  func test_scrollBehavior_auto_contentInsetsLargerThanTheView_contentScrollsByWhatExceedsIt() {
    // given: a 100 × 100 view with a 60 pt top inset and a 60 pt bottom inset, which together exceed its height, showing
    // content 50 pt wide and 10 pt tall
    var contentLayer: CALayer?
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.setContent {
      LayerNode<CALayer>(update: { layer, _ in contentLayer = layer })
        .frame(width: 50, height: 10)
    }
    contentView.contentInset = EdgeInsets(top: 60, left: 0, bottom: 60, right: 0)

    // when: the view refreshes
    contentView.refresh(animated: false)

    // then: no space is left between the insets, so the content overflows it and starts at the top of the scroll range.
    // the view scrolls by the 30 pt the content and the insets exceed its height by, or by 10 pt on macOS, where AppKit
    // shrinks the bottom inset to 40 pt once the insets exceed the height
    expect(contentView.isScrollEnabled) == true
    expect(contentView.minOffsetY) == -60
    #if canImport(AppKit)
    expect(contentView.maxOffsetY) == -50
    #else
    expect(contentView.maxOffsetY) == -30
    #endif
    expect(contentLayer?.frame) == CGRect(x: 25, y: 0, width: 50, height: 10)
  }

  func test_scrollBehavior_auto_contentInsets_contentFillingItsContainerFillsTheSpaceBetweenThem() {
    // given: a 100 × 100 view that rendered content filling the container it lays out in, and records the container sizes
    var contentLayer: CALayer?
    var containerSizes: [CGSize] = []
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.setContent {
      LayerNode<CALayer>(update: { layer, _ in contentLayer = layer })
        .frame(width: .flexible, height: .flexible)
    }
    contentView.onWillLayout { _, context in
      containerSizes.append(context.containerSize)
    }
    contentView.refresh(animated: false)
    expect(contentLayer?.frame) == CGRect(x: 0, y: 0, width: 100, height: 100)

    // when: the view gets a 30 pt top inset, as for a bar over its top edge, and 10 pt and 20 pt side insets, and lays out
    containerSizes.removeAll()
    contentView.contentInset = EdgeInsets(top: 30, left: 10, bottom: 0, right: 20)
    contentView.layoutIfNeeded()

    // then: the content lays out once, in the 70 × 70 pt the insets leave, and fills it, so nothing is hidden, and the
    // view doesn't scroll, and rests with the content right inside the insets
    expect(containerSizes) == [CGSize(width: 70, height: 70)]
    expect(contentLayer?.frame) == CGRect(x: 0, y: 0, width: 70, height: 70)
    expect(contentView.isScrollEnabled) == false
    expect(contentView.contentOffset) == CGPoint(x: -10, y: -30)
  }

  func test_scrollBehavior_auto_topInset_contentAsTallAsTheViewScrollsDownToTheInset() {
    // given: a 100 × 100 view that rendered content 100 pt tall, as tall as the view, so it doesn't scroll
    let contentView = ComposeView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    contentView.setContent {
      ColorNode(.red)
        .frame(width: .flexible, height: 100)
    }
    contentView.refresh(animated: false)
    expect(contentView.isScrollEnabled) == false

    // when: the view gets a 30 pt top inset, as for a bar over its top edge, and refreshes
    contentView.contentInset = EdgeInsets(top: 30, left: 0, bottom: 0, right: 0)
    contentView.refresh(animated: false)

    // then: the content stays where it is, under the bar, and the view scrolls, so the content's top can be dragged down
    // to the bar's bottom edge
    expect(contentView.contentOffset) == .zero
    expect(contentView.isScrollEnabled) == true
    expect(contentView.canScrollToTop) == true
    expect(contentView.minOffsetY) == -30
    expect(contentView.maxOffsetY) == 0
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
