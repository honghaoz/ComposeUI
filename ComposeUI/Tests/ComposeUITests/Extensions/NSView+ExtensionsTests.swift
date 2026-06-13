//
//  NSView+ExtensionsTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 8/28/24.
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

  // MARK: - bringSubviewToFront(_:)

  func test_bringSubviewToFront() {
    let view = BaseView()
    let subview1 = BaseView()
    let subview2 = BaseView()
    let subview3 = BaseView()
    view.addSubview(subview1)
    view.addSubview(subview2)
    view.addSubview(subview3)

    expect(view.subviews) == [subview1, subview2, subview3]

    view.bringSubviewToFront(subview2)
    expect(view.subviews) == [subview1, subview3, subview2]

    // bringing the front subview to front keeps the order
    view.bringSubviewToFront(subview2)
    expect(view.subviews) == [subview1, subview3, subview2]

    // bringing the back subview to front
    view.bringSubviewToFront(subview1)
    expect(view.subviews) == [subview3, subview2, subview1]
  }

  func test_bringSubviewToFront_sublayersOrder() throws {
    // host the view in a window so that the subviews' backing layers are attached to the view's layer
    let window = TestWindow()
    let view = BaseView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    window.contentView().addSubview(view)

    let subview1 = BaseView()
    let subview2 = BaseView()
    let subview3 = BaseView()
    view.addSubview(subview1)
    view.addSubview(subview2)
    view.addSubview(subview3)
    window.displayIfNeeded() // makes AppKit attach the backing layers

    let viewLayer = try unwrap(view.layer)
    let layer1 = try unwrap(subview1.layer)
    let layer2 = try unwrap(subview2.layer)
    let layer3 = try unwrap(subview3.layer)

    // a manually added sublayer on top
    let manualLayer = CALayer()
    viewLayer.addSublayer(manualLayer)

    expect(viewLayer.sublayers) == [layer1, layer2, layer3, manualLayer]

    // the backing layer is moved to the front immediately (above the manual sublayer), without a display pass
    view.bringSubviewToFront(subview2)
    expect(view.subviews) == [subview1, subview3, subview2]
    expect(viewLayer.sublayers) == [layer1, layer3, manualLayer, layer2]

    view.bringSubviewToFront(subview1)
    expect(view.subviews) == [subview3, subview2, subview1]
    expect(viewLayer.sublayers) == [layer3, manualLayer, layer2, layer1]
  }

  func test_bringSubviewToFront_notASubview_assertion() {
    var assertionCount = 0
    ComposeUI.Assert.setTestAssertionFailureHandler { message, _, _, _ in
      expect(message.hasSuffix("is not a subview")) == true
      assertionCount += 1
    }

    let view = BaseView()
    let subview = BaseView()
    view.addSubview(subview)
    let notASubview = BaseView()

    view.bringSubviewToFront(notASubview)
    expect(assertionCount) == 1
    expect(view.subviews) == [subview] // unchanged

    ComposeUI.Assert.setTestAssertionFailureHandler(nil)
  }

  // MARK: - sortSubviews(by:)

  func test_sortSubviews_byOrder() {
    let view = BaseView()
    let subview1 = BaseView()
    let subview2 = BaseView()
    let subview3 = BaseView()
    let subview4 = BaseView()
    view.addSubview(subview1)
    view.addSubview(subview2)
    view.addSubview(subview3)
    view.addSubview(subview4)

    // reorder with a full order map
    view.sortSubviews(by: [
      ObjectIdentifier(subview4): 0,
      ObjectIdentifier(subview2): 1,
      ObjectIdentifier(subview1): 2,
      ObjectIdentifier(subview3): 3,
    ])
    expect(view.subviews) == [subview4, subview2, subview1, subview3]

    // sorting with the same order keeps the order
    view.sortSubviews(by: [
      ObjectIdentifier(subview4): 0,
      ObjectIdentifier(subview2): 1,
      ObjectIdentifier(subview1): 2,
      ObjectIdentifier(subview3): 3,
    ])
    expect(view.subviews) == [subview4, subview2, subview1, subview3]
  }

  func test_sortSubviews_byOrder_partial() {
    let view = BaseView()
    let subview1 = BaseView()
    let subview2 = BaseView()
    let subview3 = BaseView()
    let subview4 = BaseView()
    view.addSubview(subview1)
    view.addSubview(subview2)
    view.addSubview(subview3)
    view.addSubview(subview4)

    // a partial order map that is consistent with the current order doesn't reorder anything,
    // subviews not in the order map keep their relative order
    view.sortSubviews(by: [
      ObjectIdentifier(subview1): 0,
      ObjectIdentifier(subview3): 1,
    ])
    expect(view.subviews) == [subview1, subview2, subview3, subview4]

    // an empty order map keeps the order
    view.sortSubviews(by: [:])
    expect(view.subviews) == [subview1, subview2, subview3, subview4]

    // a partial order map that is inconsistent with the current order reorders the subviews
    view.sortSubviews(by: [
      ObjectIdentifier(subview3): 1,
      ObjectIdentifier(subview1): 2,
    ])
    expect(view.subviews) == [subview3, subview1, subview2, subview4]
  }

  func test_sortSubviews_byOrder_doesNotUpdateSublayers() throws {
    // host the view in a window so that the subviews' backing layers are attached to the view's layer
    let window = TestWindow()
    let view = BaseView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    window.contentView().addSubview(view)

    let subview1 = BaseView()
    let subview2 = BaseView()
    view.addSubview(subview1)
    view.addSubview(subview2)
    window.displayIfNeeded() // makes AppKit attach the backing layers

    let viewLayer = try unwrap(view.layer)
    let layer1 = try unwrap(subview1.layer)
    let layer2 = try unwrap(subview2.layer)
    expect(viewLayer.sublayers) == [layer1, layer2]

    view.sortSubviews(by: [
      ObjectIdentifier(subview2): 0,
      ObjectIdentifier(subview1): 1,
    ])

    // the subview order is updated, but the backing layer order is not (AppKit syncs it at the next display pass)
    expect(view.subviews) == [subview2, subview1]
    expect(viewLayer.sublayers) == [layer1, layer2]
  }

  /// Pins the AppKit display-pass behavior that the `sortSubviews(by:)` doc note and `ComposeView.placeNewRenderables` rely on:
  /// - When the backing layers are out of sync with the subview order, the next display pass re-syncs
  ///   them, placing all backing layers above the non-backing sublayers.
  /// - When the backing layers are already in sync, the display pass keeps the non-backing sublayers
  ///   interleaved in place.
  func test_sortSubviews_byOrder_displayPassSyncsSublayers() throws {
    let window = TestWindow()
    let view = BaseView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    window.contentView().addSubview(view)

    let subview1 = BaseView()
    let subview2 = BaseView()
    view.addSubview(subview1)
    view.addSubview(subview2)
    window.displayIfNeeded() // makes AppKit attach the backing layers

    let viewLayer = try unwrap(view.layer)
    let layer1 = try unwrap(subview1.layer)
    let layer2 = try unwrap(subview2.layer)

    // a manually added sublayer interleaved between the backing layers, like a ComposeUI layer item
    let manualLayer = CALayer()
    viewLayer.insertSublayer(manualLayer, above: layer1)
    expect(viewLayer.sublayers) == [layer1, manualLayer, layer2]

    // when the backing layers match the subview order, the display pass keeps the sublayers in place
    view.needsDisplay = true
    window.displayIfNeeded()
    expect(viewLayer.sublayers) == [layer1, manualLayer, layer2]

    // when the backing layers are out of sync with the subview order, the display pass re-syncs them
    // and places the backing layers above the manually added sublayer
    view.sortSubviews(by: [
      ObjectIdentifier(subview2): 0,
      ObjectIdentifier(subview1): 1,
    ])
    expect(view.subviews) == [subview2, subview1]
    expect(viewLayer.sublayers) == [layer1, manualLayer, layer2] // not synced yet

    view.needsDisplay = true
    window.displayIfNeeded()
    expect(viewLayer.sublayers) == [manualLayer, layer2, layer1]
  }

  // MARK: - ignoreHitTest

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
