//
//  ComposeView+AnimationWorkTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/4/26.
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

/// Pins the animation work of representative updates: the animations added to layers.
///
/// The counts don't depend on the machine's speed or load, so they hold on any machine. A changed count is a changed
/// cost: update the expected count when the change is intended.
///
/// Each row is a layer with 5 animated properties: the background color, the opacity, the corner radius, the border
/// color and the border width.
class ComposeView_AnimationWorkTests: XCTestCase {

  func test_animatedRefresh_unchangedValues_addsNoAnimation() {
    // given: rendered rows
    let view = makeRowsView(isAlternate: { false }, height: { Constants.rowHeight })
    view.refresh(animated: false)

    // when: refreshing with animation, with the same values
    let counts = WorkCounter.counting {
      view.refresh(animated: true)
    }

    // then: no animation is added
    expect(counts.animations) == 0
  }

  func test_animatedRefresh_changedValues_addsAnAnimationPerProperty() {
    // given: rendered rows
    var isAlternate = false
    let view = makeRowsView(isAlternate: { isAlternate }, height: { Constants.rowHeight })
    view.refresh(animated: false)

    // when: refreshing with animation, with other values for the 5 properties
    isAlternate = true
    let counts = WorkCounter.counting {
      view.refresh(animated: true)
    }

    // then: each row adds an animation for each of the 5 properties
    expect(counts.animations) == 5 * Constants.rowCount
  }

  func test_refresh_changedValuesWhileAnimating_addsAnimationsForTheColorsAndTheOpacity() {
    // given: rows animating to other values for the 5 properties
    var isAlternate = false
    let view = makeRowsView(isAlternate: { isAlternate }, height: { Constants.rowHeight })
    view.refresh(animated: false)
    isAlternate = true
    view.refresh(animated: true)

    // when: refreshing without animation, back to the first values, before any time passes
    isAlternate = false
    let counts = WorkCounter.counting {
      view.refresh(animated: false)
    }

    // then: each row continues the animations of the 2 colors and the opacity toward the values, and sets the border
    // width and the corner radius directly, since no time has passed and their additive animations fold into their
    // start values
    expect(counts.animations) == 3 * Constants.rowCount
  }

  func test_animatedRefresh_changedHeight_addsPositionAndSizeAnimations() {
    // given: rendered rows
    var height = Constants.rowHeight
    let view = makeRowsView(isAlternate: { false }, height: { height })
    view.refresh(animated: false)

    // when: refreshing with animation, with the rows twice as tall
    height = Constants.rowHeight * 2
    let counts = WorkCounter.counting {
      view.refresh(animated: true)
    }

    // then: each row animates its position and its size
    expect(counts.animations) == 2 * Constants.rowCount
  }

  // MARK: - Helpers

  private enum Constants {

    static let rowCount = 10
    static let rowWidth: CGFloat = 100
    static let rowHeight: CGFloat = 10

    /// An animation duration that outlasts the test, so the animations stay in flight throughout.
    static let animationDuration: TimeInterval = 60
  }

  /// A view of rows that each animate 5 layer properties, all visible.
  ///
  /// - Parameters:
  ///   - isAlternate: Whether the rows use the second set of values.
  ///   - height: The height of a row.
  private func makeRowsView(isAlternate: @escaping () -> Bool, height: @escaping () -> CGFloat) -> ComposeView {
    let view = ComposeView {
      VStack {
        for _ in 0 ..< Constants.rowCount {
          LayerNode()
            .backgroundColor(isAlternate() ? .red : .blue)
            .opacity(isAlternate() ? 0.5 : 0.6)
            .cornerRadius(isAlternate() ? 4 : 6)
            .border(color: isAlternate() ? .blue : .red, width: isAlternate() ? 1 : 2)
            .frame(width: Constants.rowWidth, height: height())
            .animation(.easeInEaseOut(duration: Constants.animationDuration))
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: Constants.rowWidth, height: CGFloat(Constants.rowCount) * Constants.rowHeight * 2)
    return view
  }
}
