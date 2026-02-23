//
//  NSView+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/28/24.
//

#if canImport(AppKit)

import ChouTiTest

@_spi(Private) @testable import ComposeUI

class NSView_ExtensionsTests: XCTestCase {

  func test_updateCommonSettings() {
    let view = NSView()
    view.updateCommonSettings()

    expect(view.wantsLayer) == true
    expect(view.layer?.cornerCurve) == .circular
    expect(view.layer?.contentsScale) == NSScreen.main?.backingScaleFactor
    expect(view.layer?.masksToBounds) == false
  }

  func test_alpha() {
    let view = NSView()
    expect(view.alpha) == view.alphaValue
    view.alpha = 0.5
    expect(view.alpha) == 0.5
    expect(view.alphaValue) == 0.5
  }

  func test_setNeedsLayout() {
    let view = NSView()
    view.setNeedsLayout()
    expect(view.needsLayout) == true
  }

  func test_layoutIfNeeded() {
    let view = TestView()
    view.layoutIfNeeded()
    expect(view.didLayoutSubtreeIfNeeded) == true
  }

  func test_bringSubviewToFront() {
    let view = BaseView()
    let subview1 = BaseView()
    let subview2 = BaseView()
    let subview3 = BaseView()
    view.addSubview(subview1)
    view.addSubview(subview2)
    view.addSubview(subview3)

    expect(view.subviews[0]) == subview1
    expect(view.subviews[1]) == subview2
    expect(view.subviews[2]) == subview3

    view.bringSubviewToFront(subview2)
    expect(view.subviews[0]) == subview1
    expect(view.subviews[1]) == subview3
    expect(view.subviews[2]) == subview2
  }

  func test_ignoreHitTest() {
    let view = NSTextField(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

    // verify hit test
    expect(view.ignoreHitTest) == false
    let point = CGPoint(x: 5, y: 5)
    let hitView = view.hitTest(point)
    expect(hitView) === view

    // verify ignore hit test
    view.ignoreHitTest = true
    expect(view.ignoreHitTest) == true
    let hitView2 = view.hitTest(point)
    expect(hitView2) == nil
  }
}

private class TestView: NSView {

  var didLayoutSubtreeIfNeeded = false
  override func layoutSubtreeIfNeeded() {
    super.layoutSubtreeIfNeeded()
    didLayoutSubtreeIfNeeded = true
  }
}

#endif
