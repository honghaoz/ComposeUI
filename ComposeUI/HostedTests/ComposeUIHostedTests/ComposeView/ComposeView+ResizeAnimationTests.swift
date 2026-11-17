//
//  ComposeView+ResizeAnimationTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/17/26.
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

import UIKit

import ChouTiTest

@testable import ComposeUI

/// Tests that the content follows the animation that UIKit resizes a `ComposeView` with, on screen.
class ComposeView_ResizeAnimationTests: XCTestCase {

  func test_animatedLayout_contentAnimatesWithView() throws {
    // given: a view in a window with a row inset from its edges
    let window = try makeHostWindow()
    var rowLayer: CALayer?
    let view = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: 50)
        .padding(horizontal: Constants.inset)
        .onUpdate { renderable, _ in
          rowLayer = renderable.layer
        }
    }
    window.contentView.addSubview(view)
    view.frame = CGRect(x: 0, y: 100, width: 200, height: 100)
    view.layoutIfNeeded()
    let row = try unwrap(rowLayer)

    // when: animating the view wider with a layout in the animation block
    UIView.animate(withDuration: 1) {
      view.frame.size.width = 400
      view.layoutIfNeeded()
    }
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.4))

    // then: the row resizes with the view's animation, and midway it's on its way
    try expectFollowsResize(row: row, of: view, from: 200, to: 400)
  }

  #if os(iOS)

  func test_rotation_contentAnimatesWithView() throws {
    guard #available(iOS 16.0, *) else {
      try skip("requesting an interface orientation needs iOS 16")
      return
    }

    // given: a view filling the window, with a row inset from its edges
    let window = try makeHostWindow()
    let scene = try unwrap(window.windowScene)
    var rowLayer: CALayer?
    let view = ComposeView {
      ColorNode(.red)
        .frame(width: .flexible, height: 50)
        .padding(horizontal: Constants.inset)
        .onUpdate { renderable, _ in
          rowLayer = renderable.layer
        }
    }
    view.frame = window.contentView.bounds
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.contentView.addSubview(view)
    view.layoutIfNeeded()
    let row = try unwrap(rowLayer)
    addTeardownBlock {
      scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 1))
    }
    let portraitWidth = view.bounds.width

    // when: rotating to landscape
    scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
    let deadline = Date(timeIntervalSinceNow: 2)
    while view.layer.animation(forKey: "bounds.size") == nil, Date() < deadline {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
    }
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

    // then: the row resizes with the rotation's animation, and midway it's on its way
    try expectFollowsResize(row: row, of: view, from: portraitWidth, to: view.bounds.width)
  }

  #endif

  // MARK: - Helpers

  /// Expects a row inset from the view's edges to resize with the view's resize animation, which is in flight.
  ///
  /// The row's place midway is checked against its two ends, not against the view's width: the row's animation begins
  /// at the start of the run loop turn that lays it out, as every animation of ComposeUI does, while UIKit's begins when
  /// the turn commits, which for a rotation is in a later turn, so the row can run ahead of the view by that time.
  private func expectFollowsResize(row: CALayer, of view: UIView, from oldWidth: CGFloat, to newWidth: CGFloat, file: StaticString = #filePath, line: UInt = #line) throws {
    func sizeAnimation(of layer: CALayer) throws -> CABasicAnimation {
      let animations = (layer.animationKeys() ?? []).compactMap { layer.animation(forKey: $0) as? CABasicAnimation }
      return try unwrap(animations.last { $0.keyPath == "bounds.size" }, "the bounds.size animation", file: file, line: line)
    }
    let viewAnimation = try sizeAnimation(of: view.layer)
    let rowAnimation = try sizeAnimation(of: row)
    expect(rowAnimation.duration, file: file, line: line) == viewAnimation.duration
    expect(rowAnimation.timingFunction, file: file, line: line) == viewAnimation.timingFunction
    expect(rowAnimation.beginTime, file: file, line: line).to(beLessThanOrEqual(to: viewAnimation.beginTime))

    let viewWidth = try unwrap(view.layer.presentation(), file: file, line: line).bounds.width
    let rowMaxX = try unwrap(row.presentation(), file: file, line: line).frame.maxX
    expect(viewWidth, file: file, line: line).to(beGreaterThan(oldWidth + 1))
    expect(viewWidth, file: file, line: line).to(beLessThan(newWidth - 1))
    expect(rowMaxX, file: file, line: line).to(beGreaterThan(oldWidth - Constants.inset + 1))
    expect(rowMaxX, file: file, line: line).to(beLessThan(newWidth - Constants.inset - 1))
  }

  // MARK: - Constants

  private enum Constants {

    /// The row's inset from the view's left and right edges.
    static let inset: CGFloat = 10
  }
}
