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
    pauseTime(of: window.contentView.layer)

    // when: animating the view wider with a layout in the animation block
    UIView.animate(withDuration: 1) {
      view.frame.size.width = 400
      view.layoutIfNeeded()
    }

    // then: the row resizes with the view's animation
    try expectFollowsResize(row: row, of: view, from: 200, to: { 400 })
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
    pauseTime(of: window.contentView.layer)

    // when: rotating to landscape
    scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))

    // then: the row resizes with the rotation's animation
    try expectFollowsResize(row: row, of: view, from: portraitWidth, to: { view.bounds.width })
  }

  #endif

  // MARK: - Helpers

  /// Stops the time of a layer's tree, until the test ends, so that the test sets the time that the animations show.
  ///
  /// An animation that begins at the commit then begins at the same time as one that begins earlier in the run loop
  /// turn, since no time passes in between. The checks of the time an animation begins at are left to the unit tests.
  private func pauseTime(of layer: CALayer) {
    let time = layer.convertTime(CACurrentMediaTime(), from: nil)
    layer.speed = 0
    layer.timeOffset = time
    addTeardownBlock {
      layer.speed = 1
      layer.timeOffset = 0
    }
  }

  /// Expects a row inset from the view's edges to resize with the view's resize animation, in a tree whose time is
  /// paused, see `pauseTime(of:)`.
  private func expectFollowsResize(row: CALayer, of view: UIView, from oldWidth: CGFloat, to newWidth: () -> CGFloat, file: StaticString = #filePath, line: UInt = #line) throws {
    func sizeAnimation(of layer: CALayer) -> CABasicAnimation? {
      let animations = (layer.animationKeys() ?? []).compactMap { layer.animation(forKey: $0) as? CABasicAnimation }
      return animations.last { $0.keyPath == "bounds.size" }
    }

    // wait for the commit that begins the view's animation, which the paused time keeps in flight
    let deadline = Date(timeIntervalSinceNow: Constants.commitTimeout)
    while (sizeAnimation(of: view.layer)?.beginTime ?? 0) == 0, Date() < deadline {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: Constants.pollInterval))
    }
    let viewAnimation = try unwrap(sizeAnimation(of: view.layer), "the view's bounds.size animation", file: file, line: line)
    let rowAnimation = try unwrap(sizeAnimation(of: row), "the row's bounds.size animation", file: file, line: line)
    expect(viewAnimation.beginTime, file: file, line: line) != 0
    expect(rowAnimation.duration, file: file, line: line) == viewAnimation.duration
    expect(rowAnimation.timingFunction, file: file, line: line) == viewAnimation.timingFunction

    // when: showing the animations halfway
    let superlayer = try unwrap(view.layer.superlayer, file: file, line: line)
    superlayer.timeOffset = viewAnimation.beginTime + viewAnimation.duration / 2

    // then: the row's right edge keeps its inset from the view's animating width
    let viewWidth = try unwrap(view.layer.presentation(), file: file, line: line).bounds.width
    let rowMaxX = try unwrap(row.presentation(), file: file, line: line).frame.maxX
    expect(viewWidth, file: file, line: line).to(beGreaterThan(oldWidth + 1))
    expect(viewWidth, file: file, line: line).to(beLessThan(newWidth() - 1))
    expect(rowMaxX, file: file, line: line).to(beApproximatelyEqual(to: viewWidth - Constants.inset, within: 0.01))
  }

  // MARK: - Constants

  private enum Constants {

    /// The row's inset from the view's left and right edges.
    static let inset: CGFloat = 10

    /// How long to wait for the commit that begins the view's animation.
    static let commitTimeout: TimeInterval = 2

    /// How long each run loop turn of a wait runs for.
    static let pollInterval: TimeInterval = 0.005
  }
}
