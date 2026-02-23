//
//  ComposeView+WindowChangeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 4/3/25.
//

import ChouTiTest

@testable import ComposeUI

class ComposeView_WindowChangeTests: XCTestCase {

  func test_windowDidChange() throws {
    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let window = TestWindow()
    #if canImport(UIKit)
    window.contentScaleFactor = 1
    #endif

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
    #if canImport(AppKit)
    window.contentView?.addSubview(view)
    #endif
    #if canImport(UIKit)
    window.addSubview(view)
    #endif

    expect(renderCount) == 0
    expect(refreshCount) == 0
    expect(renderCount).toEventually(beEqual(to: 1))
    expect(refreshCount) == 1
    expect(isAnimated) == false
    isAnimated = nil

    view.removeFromSuperview()
    expect(renderCount) == 1
    expect(refreshCount) == 1

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3)) // flush the pending refresh
    expect(renderCount) == 1 // setting window to nil should not trigger a new render
    expect(refreshCount) == 1

    #if canImport(AppKit)
    window.contentView?.addSubview(view)
    #endif
    #if canImport(UIKit)
    window.addSubview(view)
    #endif
    expect(renderCount) == 1
    expect(renderCount).toEventually(beEqual(to: 2)) // adding to the same window again should trigger a new render
    expect(refreshCount) == 2
    expect(isAnimated) == false
    isAnimated = nil

    let window2 = TestWindow()
    #if canImport(UIKit)
    window.contentScaleFactor = 4
    #endif

    #if canImport(AppKit)
    window2.contentView?.addSubview(view)
    #endif
    #if canImport(UIKit)
    window2.addSubview(view)
    #endif
    expect(renderCount) == 2
    expect(renderCount).toEventually(beEqual(to: 3)) // adding to a different window should trigger a new render
    expect(refreshCount) == 3
    expect(isAnimated) == false
    isAnimated = nil
  }
}
