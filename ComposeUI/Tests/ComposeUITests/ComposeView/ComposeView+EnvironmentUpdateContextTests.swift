//
//  ComposeView+EnvironmentUpdateContextTests.swift
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

import ComposeUI

class ComposeView_EnvironmentUpdateContextTests: XCTestCase {

  func test_themeChange_refreshesThemedColorWithAnimatedContext() throws {
    // given: a rendered themed layer with the initial window and theme refreshes settled
    let window = TestWindow()
    let bounds = CGRect(x: 0, y: 0, width: 120, height: 80)
    let color = ThemedColor(light: .red, dark: .blue)
    var updateContext: RenderableUpdateContext?
    var renderedLayer: CALayer?
    let view = ComposeView {
      LayerNode()
        .backgroundColor(color)
        .animation(.linear())
        .onUpdate { renderable, context in
          renderedLayer = renderable.layer
          updateContext = context
        }
    }
    view.frame = bounds
    window.contentView().addSubview(view)
    view.overrideTheme = .light
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))
    expect(renderedLayer?.backgroundColor).toEventually(beEqual(to: Color.red.cgColor))
    let layer = try unwrap(renderedLayer)
    updateContext = nil

    // when: only the theme changes
    view.overrideTheme = .dark

    // then: the retained layer resolves its themed color in an animated refresh with unchanged viewport snapshots
    expect(layer.backgroundColor).toEventually(beEqual(to: Color.blue.cgColor))
    expect(renderedLayer) === layer
    expect(updateContext?.updateType) == .refresh
    expect(updateContext?.isAnimated) == true
    expect(updateContext?.previousRenderBounds) == bounds
    expect(updateContext?.renderBounds) == bounds
    expect(layer.frame) == bounds

    // when: a dynamic policy disables animation for the next theme change
    view.animationBehavior = .dynamic { _, renderType in
      expect(renderType) == .refresh(isAnimated: true)
      return false
    }
    view.overrideTheme = .light

    // then: the policy overrides the theme's animation preference without changing the refresh snapshots
    expect(layer.backgroundColor).toEventually(beEqual(to: Color.red.cgColor))
    expect(renderedLayer) === layer
    expect(updateContext?.updateType) == .refresh
    expect(updateContext?.isAnimated) == false
    expect(updateContext?.previousRenderBounds) == bounds
    expect(updateContext?.renderBounds) == bounds
    expect(layer.frame) == bounds
  }

  func test_windowChange_refreshesContentWithNonanimatedContext() throws {
    // given: a retained layer whose color depends on its window
    let firstWindow = TestWindow()
    let secondWindow = TestWindow()
    let bounds = CGRect(x: 0, y: 0, width: 120, height: 80)
    var updateContext: RenderableUpdateContext?
    var renderedLayer: CALayer?
    let view = ComposeView { [weak firstWindow] contentView in
      LayerNode()
        .backgroundColor(contentView.window === firstWindow ? Color.red : Color.blue)
        .animation(.linear())
        .onUpdate { renderable, context in
          renderedLayer = renderable.layer
          updateContext = context
        }
    }
    view.frame = bounds
    firstWindow.contentView().addSubview(view)
    view.overrideTheme = .light
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3))
    expect(renderedLayer?.backgroundColor).toEventually(beEqual(to: Color.red.cgColor))
    let layer = try unwrap(renderedLayer)
    updateContext = nil

    // when: the view moves to a different window without changing its viewport
    secondWindow.contentView().addSubview(view)

    // then: the retained layer receives the new window's content without animation or a bounds change
    expect(layer.backgroundColor).toEventually(beEqual(to: Color.blue.cgColor))
    expect(renderedLayer) === layer
    expect(updateContext?.updateType) == .refresh
    expect(updateContext?.isAnimated) == false
    expect(updateContext?.previousRenderBounds) == bounds
    expect(updateContext?.renderBounds) == bounds
    expect(layer.frame) == bounds

    // when: a dynamic policy enables animation while moving back to the first window
    view.animationBehavior = .dynamic { _, renderType in
      expect(renderType) == .refresh(isAnimated: false)
      return true
    }
    firstWindow.contentView().addSubview(view)

    // then: the policy overrides the window's animation preference without changing the refresh snapshots
    expect(layer.backgroundColor).toEventually(beEqual(to: Color.red.cgColor))
    expect(renderedLayer) === layer
    expect(updateContext?.updateType) == .refresh
    expect(updateContext?.isAnimated) == true
    expect(updateContext?.previousRenderBounds) == bounds
    expect(updateContext?.renderBounds) == bounds
    expect(layer.frame) == bounds
  }
}
