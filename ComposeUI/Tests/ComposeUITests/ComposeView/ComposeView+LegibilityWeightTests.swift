//
//  ComposeView+LegibilityWeightTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/3/26.
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

#if canImport(UIKit)

import ChouTiTest
import SwiftUI
import UIKit

@testable import ComposeUI

class ComposeView_LegibilityWeightTests: XCTestCase {

  func test_layout_givesNodesTheViewsLegibilityWeight() throws {
    guard #available(iOS 17.0, tvOS 17.0, *) else {
      try skip("trait overrides are available from iOS 17 and tvOS 17")
      return
    }

    // given: a compose view in a window with Bold Text on, with a node that records the text weight of its layouts
    let window = TestWindow()
    window.traitOverrides.legibilityWeight = .bold
    var legibilityWeights: [UILegibilityWeight] = []
    let view = ComposeView {
      LegibilityWeightRecordingNode { legibilityWeights.append($0) }
    }
    view.frame = Constants.frame
    window.addSubview(view)
    window.updateTraitsIfNeeded()

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the node lays out at the window's text weight
    expect(legibilityWeights.isEmpty) == false
    expect(Set(legibilityWeights)) == [.bold]
  }

  func test_layout_measuresAndRendersAtTheViewsLegibilityWeight() throws {
    guard #available(iOS 17.0, tvOS 17.0, *) else {
      try skip("trait overrides are available from iOS 17 and tvOS 17")
      return
    }

    // given: a window with Bold Text on, and a compose view with a node whose size fits a line of text, which records
    // the text weights that it's evaluated at
    let window = TestWindow()
    window.traitOverrides.legibilityWeight = .bold
    let recorder = LegibilityWeightRecorder()
    var renderedView: UIView?
    let view = ComposeView {
      SwiftUIViewNode { LegibilityWeightProbe(text: Constants.line, recorder: recorder) }
        .fixedSize()
        .onInsert { renderable, _ in
          renderedView = renderable.view
        }
    }
    view.frame = Constants.frame
    window.addSubview(view)
    window.updateTraitsIfNeeded()

    // when: the view refreshes, and the node's SwiftUI host lays out its content
    view.refresh(animated: false)
    let hostingView = try unwrap(renderedView)
    hostingView.layoutIfNeeded()

    // then: the node is as wide as the text in bold, wider than in regular
    expect(hostingView.frame.width).to(beApproximatelyEqual(to: Self.width(at: .bold), within: 1 / view.contentScaleFactor))
    expect(hostingView.frame.width) > Self.width(at: .regular)

    // then: the content was measured and rendered in bold
    expect(recorder.legibilityWeights.count).toEventually(beGreaterThanOrEqual(to: 2))
    expect(Set(recorder.legibilityWeights)) == [.bold]
  }

  func test_legibilityWeightChange_refreshesWithoutAnimation() throws {
    guard #available(iOS 17.0, tvOS 17.0, *) else {
      try skip("trait overrides are available from iOS 17 and tvOS 17")
      return
    }

    // given: a compose view in a window with Bold Text off, with a node whose size fits a line of text and that
    // animates its frame changes, rendered
    let window = TestWindow()
    window.traitOverrides.legibilityWeight = .regular
    var renderCount = 0
    var updateContext: RenderableUpdateContext?
    var renderedView: UIView?
    let view = ComposeView {
      renderCount += 1
      SwiftUIViewNode { Text(verbatim: Constants.line) }
        .fixedSize()
        .animation(.linear())
        .onUpdate { renderable, context in
          updateContext = context
          renderedView = renderable.view
        }
    }
    view.frame = Constants.frame
    window.addSubview(view)
    window.updateTraitsIfNeeded()

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3)) // settle the initial environment refresh
    expect(renderCount).toEventually(beEqual(to: 1))
    let hostingView = try unwrap(renderedView)
    let regularWidth = hostingView.frame.width
    expect(regularWidth).to(beApproximatelyEqual(to: Self.width(at: .regular), within: 1 / view.contentScaleFactor))

    // when: Bold Text turns on in the window
    window.traitOverrides.legibilityWeight = .bold
    window.updateTraitsIfNeeded()

    // then: the view refreshes without animation, and the node fits the text in bold
    expect(renderCount).toEventually(beEqual(to: 2))
    expect(updateContext?.updateType) == .refresh
    expect(updateContext?.animationTiming) == nil
    expect(renderedView) === hostingView
    expect(hostingView.frame.width).to(beApproximatelyEqual(to: Self.width(at: .bold), within: 1 / view.contentScaleFactor))
    expect(hostingView.frame.width) > regularWidth

    // then: no extra refresh follows
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3)) // flush any pending refreshes
    expect(renderCount) == 2
  }

  // MARK: - Helpers

  /// Returns the width of the test's line at a text weight, in the test's frame.
  @available(iOS 14.0, tvOS 14.0, *)
  private static func width(at legibilityWeight: LegibilityWeight) -> CGFloat {
    Text(verbatim: Constants.line).environment(\.legibilityWeight, legibilityWeight).sizeThatFits(Constants.frame.size).width
  }

  // MARK: - Constants

  private enum Constants {

    /// A text that fits on one line in the frame's width.
    static let line = "Bold text"

    /// The frame of the compose view.
    static let frame = CGRect(x: 0, y: 0, width: 200, height: 1000)
  }
}

/// A node that reports the text weight of each of its layouts.
private struct LegibilityWeightRecordingNode: ComposeNode {

  private let record: (UILegibilityWeight) -> Void

  init(record: @escaping (UILegibilityWeight) -> Void) {
    self.record = record
  }

  var id: ComposeNodeId = .custom("legibility-weight-recording")

  private(set) var size: CGSize = .zero

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    record(context.legibilityWeight)
    return ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {}
}

/// A recorder of the text weights that a probe's content is evaluated at, which the probe's copies share.
@available(iOS 14.0, tvOS 14.0, *)
private final class LegibilityWeightRecorder {

  /// The text weights, in the order of the evaluations.
  var legibilityWeights: [LegibilityWeight?] = []
}

/// A text that records the text weight of each evaluation of its body.
@available(iOS 14.0, tvOS 14.0, *)
private struct LegibilityWeightProbe: SwiftUI.View {

  let text: String
  let recorder: LegibilityWeightRecorder

  @SwiftUI.Environment(\.legibilityWeight) private var legibilityWeight

  var body: some SwiftUI.View {
    recorder.legibilityWeights.append(legibilityWeight)
    return Text(verbatim: text)
  }
}

#endif
