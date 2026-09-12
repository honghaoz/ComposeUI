//
//  ComposeView+ReentrantRefreshTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 9/12/26.
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

@testable import ComposeUI

class ComposeView_ReentrantRefreshTests: XCTestCase {

  func test_refresh_duringRenderPass_isDeferredUntilThePassCompletes() throws {

    enum Trigger: CaseIterable {
      case willLayout
      case willRender
      case itemWillUpdate
      case itemUpdate
    }

    var assertionMessages: [String] = []
    Assert.setTestAssertionFailureHandler { message, _, _, _ in
      assertionMessages.append(message)
    }
    defer {
      Assert.resetTestAssertionFailureHandler()
    }

    for trigger in Trigger.allCases {
      // given: a rendered view with a one-shot reentrant refresh armed on one of its render callbacks
      var color = Color.red
      var contentMakeCount = 0
      var layer: CALayer?
      var isArmed = false
      var reentrantRefreshes = 0
      var view: ComposeView?
      let refreshFromCallback = {
        guard isArmed else {
          return
        }
        isArmed = false
        reentrantRefreshes += 1
        color = .blue
        view?.refresh(animated: false)
      }
      view = ComposeView {
        contentMakeCount += 1
        ColorNode(color)
          .frame(width: 40, height: 40)
          .willUpdate { _, _ in
            if trigger == .itemWillUpdate {
              refreshFromCallback()
            }
          }
          .onUpdate { renderable, _ in
            layer = renderable.layer
            if trigger == .itemUpdate {
              refreshFromCallback()
            }
          }
      }
      let composeView = try unwrap(view)
      composeView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      composeView.onWillLayout { _, _ in
        if trigger == .willLayout {
          refreshFromCallback()
        }
      }
      composeView.onWillRender { _, _ in
        if trigger == .willRender {
          refreshFromCallback()
        }
      }
      composeView.refresh(animated: false)
      let originalLayer = try unwrap(layer)
      assertionMessages = []
      isArmed = true

      // when: a refresh runs while the callback refreshes the view again from inside the pass
      composeView.refresh(animated: false)

      // then: the pass completes with the content it started with, without a nested pass
      expect(assertionMessages) == []
      expect(reentrantRefreshes) == 1
      expect(contentMakeCount) == 2
      expect(layer) === originalLayer
      expect(originalLayer.backgroundColor) == Color.red.cgColor
      expect(composeView.contentView().layer().sublayers?.count) == 1

      // when: the run loop performs the deferred refresh
      var isDrained = false
      RunLoop.main.perform { isDrained = true }
      expect(isDrained).toEventually(beTrue())

      // then: the deferred refresh applies the new configuration to the same renderable
      expect(assertionMessages) == []
      expect(contentMakeCount) == 3
      expect(layer) === originalLayer
      expect(originalLayer.backgroundColor) == Color.blue.cgColor
      expect(composeView.contentView().layer().sublayers?.count) == 1
    }
  }
}
