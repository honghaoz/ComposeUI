//
//  TextNodeTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/20/26.
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

/// Tests how a text shows an appearance change in an app's window.
class TextNodeTests: XCTestCase {

  func test_appearanceChange_crossfadesATextInADynamicColorInTheCommitThatRedrawsIt() throws {
    let window = try makeHostWindow()
    for isSelectable in [false, true] {
      let name = isSelectable ? "text view" : "label"

      // given: a text in the default text color, a dynamic color that UIKit draws again for a new appearance, with an
      // animation, in a light window
      window.overrideUserInterfaceStyle = .light
      Self.turnRunLoop(until: window.contentView, hasStyle: .light)
      let contentView = ComposeView {
        TextNode("Hello")
          .selectable(isSelectable)
          .animation(.easeInEaseOut(duration: 1))
      }
      window.contentView.addSubview(contentView)
      contentView.frame = CGRect(x: 0, y: 100, width: 200, height: 100)
      contentView.layoutIfNeeded()
      let view = try unwrap(contentView.contentContainerView.subviews.first, name)
      expect(view.layer.animation(forKey: kCATransition), name) == nil

      // when: the window turns dark, and the run loop turns until a commit delivers the change, which draws the text
      // for it
      window.overrideUserInterfaceStyle = .dark
      Self.turnRunLoop(until: view, hasStyle: .dark)

      // then: the text crossfades to the dark appearance from that commit
      expect(view.traitCollection.userInterfaceStyle, name) == .dark
      let transition = try unwrap(view.layer.animation(forKey: kCATransition) as? CATransition, name)
      expect(transition.type, name) == .fade
      expect(transition.duration, name) == 1

      contentView.removeFromSuperview()
    }
  }

  func test_appearanceChange_labelInADynamicColor_drawsTheNewAppearanceInTheCrossfade() throws {
    // given: a label in the default text color with an animation, in a light window, which records each draw
    let window = try makeHostWindow()
    window.overrideUserInterfaceStyle = .light
    Self.turnRunLoop(until: window.contentView, hasStyle: .light)
    let contentView = ComposeView {
      TextNode("Hello")
        .selectable(false)
        .animation(.linear(duration: 10))
    }
    window.contentView.addSubview(contentView)
    addTeardownBlock {
      contentView.removeFromSuperview()
    }
    contentView.frame = CGRect(x: 0, y: 100, width: 200, height: 100)
    contentView.layoutIfNeeded()
    let labelView = try unwrap(contentView.contentContainerView.subviews.first as? TextLabelView)
    var draws: [(style: UIUserInterfaceStyle, isCrossfading: Bool)] = []
    labelView.test.drawObserver = { [weak labelView] in
      draws.append((UITraitCollection.current.userInterfaceStyle, labelView?.layer.animation(forKey: kCATransition) != nil))
    }
    expect(draws.count).toEventually(beEqual(to: 1))
    expect(draws.first?.style) == .light
    expect(draws.first?.isCrossfading) == false

    // when: the window turns dark, which UIKit delivers in the commit that draws the label again in the dark text color
    window.overrideUserInterfaceStyle = .dark

    // then: the label draws in the dark text color with the crossfade on its layer, with the refresh's timing
    expect(draws.count).toEventually(beEqual(to: 2))
    expect(draws.last?.style) == .dark
    expect(draws.last?.isCrossfading) == true
    let transition = try unwrap(labelView.layer.animation(forKey: kCATransition) as? CATransition)
    expect(transition.type) == .fade
    expect(transition.duration) == 10
  }

  /// Turns the run loop until UIKit delivers an interface style to a view, which it does in a commit, or a timeout.
  private static func turnRunLoop(until view: UIView, hasStyle style: UIUserInterfaceStyle) {
    let deadline = Date(timeIntervalSinceNow: Constants.timeout)
    while view.traitCollection.userInterfaceStyle != style, Date() < deadline {
      RunLoop.main.run(until: Date())
    }
  }

  // MARK: - Constants

  private enum Constants {

    /// How long to wait for UIKit to deliver an appearance change.
    static let timeout: TimeInterval = 5
  }
}
