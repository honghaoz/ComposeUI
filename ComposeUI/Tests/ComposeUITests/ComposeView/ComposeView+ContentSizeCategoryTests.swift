//
//  ComposeView+ContentSizeCategoryTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 11/2/26.
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

import SwiftUI
import UIKit

import ChouTiTest

@testable import ComposeUI

class ComposeView_ContentSizeCategoryTests: XCTestCase {

  func test_layout_measuresAndRendersAtTheViewsContentSizeCategory() throws {
    guard #available(iOS 17.0, tvOS 17.0, *) else {
      try skip("trait overrides are available from iOS 17 and tvOS 17")
    }

    // given: a window at the largest text size, and a compose view with a node whose height fits wrapping text, which
    // records the text sizes that it's evaluated at
    let window = TestWindow()
    window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
    let recorder = DynamicTypeSizeRecorder()
    var renderedView: UIView?
    let view = ComposeView {
      SwiftUIViewNode { DynamicTypeSizeProbe(text: Constants.text, recorder: recorder) }
        .fixedSize(width: false, height: true)
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

    // then: the node is as tall as the text at the window's text size, taller than at the default text size on a system
    // that sizes text by the text size
    expect(hostingView.frame.height).to(beApproximatelyEqual(to: Self.height(at: .accessibility5), within: 1 / view.contentScaleFactor))
    if UIContentSizeCategory.sizesText {
      expect(hostingView.frame.height) > Self.height(at: .large)
    }

    // then: the content was measured and rendered at the window's text size
    expect(recorder.dynamicTypeSizes.count).toEventually(beGreaterThanOrEqual(to: 2))
    expect(Set(recorder.dynamicTypeSizes)) == [.accessibility5]
  }

  func test_layout_givesNodesTheViewsContentSizeCategory() throws {
    guard #available(iOS 17.0, tvOS 17.0, *) else {
      try skip("trait overrides are available from iOS 17 and tvOS 17")
    }

    // given: a compose view in a window at the largest text size, with a node that records the text size of its layouts
    let window = TestWindow()
    window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
    var contentSizeCategories: [UIContentSizeCategory] = []
    let view = ComposeView {
      ContentSizeCategoryRecordingNode { contentSizeCategories.append($0) }
    }
    view.frame = Constants.frame
    window.addSubview(view)
    window.updateTraitsIfNeeded()

    // when: the view refreshes
    view.refresh(animated: false)

    // then: the node lays out at the window's text size
    expect(contentSizeCategories.isEmpty) == false
    expect(Set(contentSizeCategories)) == [.accessibilityExtraExtraExtraLarge]
  }

  func test_contentSizeCategoryChange_refreshesWithoutAnimation() throws {
    guard #available(iOS 17.0, tvOS 17.0, *) else {
      try skip("trait overrides are available from iOS 17 and tvOS 17")
    }

    // given: a compose view in a window at the smallest text size, with a node whose height fits wrapping text and that
    // animates its frame changes, rendered
    let window = TestWindow()
    window.traitOverrides.preferredContentSizeCategory = .extraSmall
    var renderCount = 0
    var updateContext: RenderableUpdateContext?
    var renderedView: UIView?
    let view = ComposeView {
      renderCount += 1
      SwiftUIViewNode { Text(verbatim: Constants.text) }
        .fixedSize(width: false, height: true)
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
    let smallHeight = hostingView.frame.height
    expect(smallHeight).to(beApproximatelyEqual(to: Self.height(at: .xSmall), within: 1 / view.contentScaleFactor))

    // when: the window's text size changes to the largest
    window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
    window.updateTraitsIfNeeded()

    // then: the view refreshes without animation, and the node fits the text at the new text size, which is taller on a
    // system that sizes text by the text size
    expect(renderCount).toEventually(beEqual(to: 2))
    expect(updateContext?.updateType) == .refresh
    expect(updateContext?.animationTiming) == nil
    expect(renderedView) === hostingView
    expect(hostingView.frame.height).to(beApproximatelyEqual(to: Self.height(at: .accessibility5), within: 1 / view.contentScaleFactor))
    if UIContentSizeCategory.sizesText {
      expect(hostingView.frame.height) > smallHeight
    }

    // then: no extra refresh follows
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-3)) // flush any pending refreshes
    expect(renderCount) == 2
  }

  func test_sizeThatFits_measuresAtTheViewsContentSizeCategory() throws {
    guard #available(iOS 17.0, tvOS 17.0, *) else {
      try skip("trait overrides are available from iOS 17 and tvOS 17")
    }

    // given: a compose view in a window at the largest text size, with a node whose height fits wrapping text
    let window = TestWindow()
    window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
    let view = ComposeView {
      SwiftUIViewNode { Text(verbatim: Constants.text) }
        .fixedSize(width: false, height: true)
    }
    window.addSubview(view)
    window.updateTraitsIfNeeded()

    // when: measuring the view
    let size = view.sizeThatFits(Constants.frame.size)

    // then: the view fits the text at the window's text size
    let textSize = CGSize(width: Constants.frame.width, height: Self.height(at: .accessibility5))
    expect(size) == textSize.roundedUp(scaleFactor: view.contentScaleFactor)
  }

  // MARK: - Helpers

  /// Returns the height of the test's text at a text size, in the width of the test's frame.
  @available(iOS 15.0, tvOS 15.0, *)
  private static func height(at dynamicTypeSize: DynamicTypeSize) -> CGFloat {
    Text(verbatim: Constants.text).dynamicTypeSize(dynamicTypeSize).sizeThatFits(Constants.frame.size).height
  }

  // MARK: - Constants

  private enum Constants {

    /// A text that wraps in the frame's width at every text size.
    static let text = "The quick brown fox jumps over the lazy dog, then naps in the warm afternoon sun."

    /// The frame of the compose view, tall enough for the text at the largest text size.
    static let frame = CGRect(x: 0, y: 0, width: 200, height: 1000)
  }
}

/// A node that reports the text size of each of its layouts.
private struct ContentSizeCategoryRecordingNode: ComposeNode {

  private let record: (UIContentSizeCategory) -> Void

  init(record: @escaping (UIContentSizeCategory) -> Void) {
    self.record = record
  }

  var id: ComposeNodeId = .custom("content-size-category-recording")

  private(set) var size: CGSize = .zero

  mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    record(context.contentSizeCategory)
    return ComposeNodeSizing(width: .fixed(0), height: .fixed(0))
  }

  func render(visibleBounds: CGRect, into items: inout [RenderableItem]) {}
}

/// A recorder of the text sizes that a probe's content is evaluated at, which the probe's copies share.
@available(iOS 15.0, tvOS 15.0, *)
private final class DynamicTypeSizeRecorder {

  /// The text sizes, in the order of the evaluations.
  var dynamicTypeSizes: [DynamicTypeSize] = []
}

/// A text that records the text size of each evaluation of its body.
@available(iOS 15.0, tvOS 15.0, *)
private struct DynamicTypeSizeProbe: SwiftUI.View {

  let text: String
  let recorder: DynamicTypeSizeRecorder

  @SwiftUI.Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some SwiftUI.View {
    recorder.dynamicTypeSizes.append(dynamicTypeSize)
    return Text(verbatim: text)
  }
}

#endif
