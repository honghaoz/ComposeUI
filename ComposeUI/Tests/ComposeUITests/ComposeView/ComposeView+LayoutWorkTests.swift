//
//  ComposeView+LayoutWorkTests.swift
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

/// Pins the layout work of representative content: the layouts of a node, and the text measurements.
///
/// The counts don't depend on the machine's speed or load, so they hold on any machine. A changed count is a changed
/// cost: update the expected count when the change is intended.
class ComposeView_LayoutWorkTests: XCTestCase {

  override func setUp() {
    super.setUp()

    // the text sizes are cached process-wide, so each test starts from an empty cache to count every measurement
    NSAttributedString.clearTextSizeCache()
  }

  // MARK: - Node Layouts

  func test_refresh_nestedContainers_layOutTheLeafOnce() {
    for container in [Container.verticalStack, .horizontalStack, .layeredStack, .padding, .flexibleFrame, .overlay] {
      // given: a leaf node in 8 nested containers of one kind
      let state = TestNode.State()
      let view = ComposeView {
        Self.nest(TestNode(state: state).frame(width: 10, height: 10), in: container, depth: 8)
      }
      view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

      // when: refreshing
      view.refresh(animated: false)

      // then: the leaf lays out once, regardless of the depth
      expect(state.layoutCount, "\(container)") == 1
    }
  }

  func test_refresh_nestedStacksWithASpacer_layOutTheLeafOncePerEnclosingStack() {
    for container in [Container.verticalStackWithSpacer, .horizontalStackWithSpacer] {
      for depth in 1 ... 8 {
        // given: a leaf node in nested stacks that each also hold a spacer
        let state = TestNode.State()
        let view = ComposeView {
          Self.nest(TestNode(state: state).frame(width: 10, height: 10), in: container, depth: depth)
        }
        view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

        // when: refreshing
        view.refresh(animated: false)

        // then: a stack that holds a spacer is flexible, so its enclosing stack lays it out twice, for its sizing and at
        // its proposed size, but a stack laid out again at a size it already had in the pass returns that layout, so
        // each enclosing stack adds one layout of the leaf instead of doubling them
        expect(state.layoutCount, "\(container) at depth \(depth)") == depth
      }
    }
  }

  func test_refresh_alternatingStacksWithASpacer_doubleTheLeafLayoutsFromTheThirdLevel() {
    for depth in 1 ... 8 {
      // given: a leaf node in nested stacks that alternate between vertical and horizontal, each also holding a spacer
      let state = TestNode.State()
      let view = ComposeView {
        Self.nest(TestNode(state: state).frame(width: 10, height: 10), in: .alternatingStacksWithSpacer, depth: depth)
      }
      view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

      // when: refreshing
      view.refresh(animated: false)

      // then: from the third level on, each stack is flexible in its enclosing stack's direction, so the enclosing stack
      // lays it out twice, for its sizing and at its proposed size. The levels change the width and the height in turns,
      // so no stack is laid out again at a size it already had in the pass, and each of these levels doubles the leaf's
      // layouts
      expect(state.layoutCount, "at depth \(depth)") == 1 << max(depth - 2, 0)
    }
  }

  // MARK: - Text Measurements

  func test_refresh_measuresEachTextOnce() {
    // given: 10 single-line and 10 multi-line labels
    let view = makeLabelsView()

    // when: refreshing
    let firstRefreshCounts = WorkCounter.counting {
      view.refresh(animated: false)
    }

    // then: each text is measured once
    expect(firstRefreshCounts.textMeasurements) == 20

    // when: refreshing again
    let secondRefreshCounts = WorkCounter.counting {
      view.refresh(animated: false)
    }

    // then: the text sizes come from the text size cache
    expect(secondRefreshCounts.textMeasurements) == 0
  }

  func test_scroll_measuresNoText() {
    // given: labels taller than the view, rendered
    let view = makeLabelsView()
    view.refresh(animated: false)

    // when: scrolling
    let counts = WorkCounter.counting {
      view.contentOffset = CGPoint(x: 0, y: 50)
      view.layoutIfNeeded()
    }

    // then: no text is measured, as a scroll doesn't lay out
    expect(counts.textMeasurements) == 0
  }

  func test_widthChange_remeasuresTheMultilineTexts() {
    // given: 10 single-line and 10 multi-line labels, rendered
    let view = makeLabelsView()
    view.refresh(animated: false)

    // when: the view's width changes
    let counts = WorkCounter.counting {
      view.frame = CGRect(x: 0, y: 0, width: 150, height: 100)
      view.layoutIfNeeded()
    }

    // then: only the multi-line texts are measured again, as a single-line text's size doesn't depend on the width
    expect(counts.textMeasurements) == 10
  }

  // MARK: - Helpers

  private enum Container {

    case verticalStack
    case horizontalStack
    case verticalStackWithSpacer
    case horizontalStackWithSpacer
    case alternatingStacksWithSpacer
    case layeredStack
    case padding
    case flexibleFrame
    case overlay
  }

  /// Wraps the node in containers of one kind, nested to the given depth.
  private static func nest(_ node: any ComposeNode, in container: Container, depth: Int) -> any ComposeNode {
    guard depth > 0 else {
      return node
    }

    let child = nest(node, in: container, depth: depth - 1)
    switch container {
    case .verticalStack:
      return VStack { child }
    case .horizontalStack:
      return HStack { child }
    case .verticalStackWithSpacer:
      return VStack {
        child
        Spacer()
      }
    case .horizontalStackWithSpacer:
      return HStack {
        child
        Spacer()
      }
    case .alternatingStacksWithSpacer:
      if depth.isMultiple(of: 2) {
        return HStack {
          child
          Spacer()
        }
      } else {
        return VStack {
          child
          Spacer()
        }
      }
    case .layeredStack:
      return ZStack { child }
    case .padding:
      return child.padding(1)
    case .flexibleFrame:
      return child.frame(width: .flexible, height: .flexible)
    case .overlay:
      return child.overlay { ColorNode(.red) }
    }
  }

  /// A view of 10 single-line and 10 multi-line labels, each with its own text, taller than the view.
  private func makeLabelsView() -> ComposeView {
    let view = ComposeView {
      VStack {
        for index in 0 ..< 10 {
          LabelNode("Single-line label \(index)")
          LabelNode("Multi-line label \(index), with a text long enough to wrap").numberOfLines(0)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    #if canImport(AppKit)
    // overlay scroll bars take no space, so the layout doesn't depend on the system's scroll bar setting
    view.scrollerStyle = .overlay
    #endif
    return view
  }
}
