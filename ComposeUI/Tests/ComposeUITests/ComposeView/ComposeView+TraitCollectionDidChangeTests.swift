//
//  ComposeView+TraitCollectionDidChangeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/31/26.
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

#if canImport(UIKit) && !os(visionOS)

import ChouTiTest
import UIKit

import ComposeUI

class ComposeView_TraitCollectionDidChangeTests: XCTestCase {

  func test_traitCollectionDidChange_displayScaleChanged() {
    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let window = TestWindow()

    var renderCount = 0
    var refreshCount = 0
    var isAnimated: Bool?
    let view = ComposeView {
      renderCount += 1
      LayerNode()
        .animation(.linear())
        .onUpdate { _, context in
          isAnimated = context.animationTiming != nil
          refreshCount += 1
        }
    }

    view.frame = frame
    window.addSubview(view)

    // initial render when added to window
    expect(renderCount).toEventually(beEqual(to: 1))
    expect(refreshCount) == 1
    expect(isAnimated) == false
    isAnimated = nil

    let displayScale = view.traitCollection.displayScale
    expect(view.contentScaleFactor) == displayScale

    // simulate a stale content scale left by a previous display, then deliver a trait change
    let staleScale: CGFloat = displayScale == 1 ? 2 : 1
    view.contentScaleFactor = staleScale
    view.traitCollectionDidChange(nil)

    // should adopt the trait collection's display scale and refresh, non-animated
    expect(view.contentScaleFactor) == displayScale
    expect(renderCount).toEventually(beEqual(to: 2))
    expect(refreshCount) == 2
    expect(isAnimated) == false
  }

  func test_traitCollectionDidChange_displayScaleUnchanged() {
    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let window = TestWindow()

    var renderCount = 0
    var refreshCount = 0
    let view = ComposeView {
      renderCount += 1
      LayerNode()
        .onUpdate { _, _ in
          refreshCount += 1
        }
    }

    view.frame = frame
    window.addSubview(view)

    // initial render when added to window
    expect(renderCount).toEventually(beEqual(to: 1))
    expect(refreshCount) == 1

    let displayScale = view.traitCollection.displayScale
    expect(view.contentScaleFactor) == displayScale

    // the content scale already matches the trait collection's display scale, should not refresh
    view.traitCollectionDidChange(nil)

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3)) // flush any pending refreshes
    expect(renderCount) == 1 // no new render
    expect(refreshCount) == 1
    expect(view.contentScaleFactor) == displayScale
  }
}

#endif
