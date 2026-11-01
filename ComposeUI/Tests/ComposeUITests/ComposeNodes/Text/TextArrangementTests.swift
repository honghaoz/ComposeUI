//
//  TextArrangementTests.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 10/31/26.
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
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import ChouTiTest

@testable import ComposeUI

class TextArrangementTests: XCTestCase {

  // MARK: - Expected Lines

  func test_lines_areTheExpectedLines() {
    for (state, expectedLines) in Self.expectedLines {
      for kind in Kind.allCases {
        // given: a compose view showing a text node of the kind in the state
        let harness = Harness(state: state, kind: kind)

        // when: rendering it
        let lines = harness.render()

        // then: the node's view lays out the expected lines, which are the same on every platform
        expect(lines, "\(state.name), \(kind)") == expectedLines
      }
    }
  }

  // MARK: - Changes

  func test_lines_afterAChange_areTheLinesOfANewView() {
    for state in Self.finalStates {
      for kind in Kind.allCases {
        let newLines = Harness(state: state, kind: kind).render()
        for change in Change.allCases {
          // given: a compose view showing a text node of the kind in another state, and its view
          let scenario = "\(state.name), \(kind), \(change)"
          guard let from = change.state(before: state, kind: kind) else {
            continue
          }
          let harness = Harness(state: from.state, kind: from.kind)
          harness.render()
          let firstView = harness.model.view

          // when: the change brings it to the state
          change.apply(to: harness, state: state, kind: kind)

          // then: its view, the first one, lays out the same lines as a new view in the state, which shows the text
          expect(firstView, scenario) != nil
          expect(harness.model.view === firstView, scenario) == true
          expect(newLines.isEmpty, scenario) == false
          expect(Harness.lines(of: harness.model.view), scenario) == newLines
        }
      }
    }
  }

  // MARK: - Cases

  private static let latin = makeText("Lorem Ipsum is simply dummy text of the printing and typesetting industry.")

  private static let paragraphs = makeText("First paragraph\nSecond paragraph that is a bit longer\nThird")

  private static let arabic = makeText("مرحبا بالعالم، هذا نص عربي طويل يلتف عبر عدة أسطر")

  /// The texts that the cases show.
  private static let texts: [(name: String, text: NSAttributedString)] = [
    ("latin", latin),
    ("paragraphs", paragraphs),
    ("arabic", arabic),
  ]

  /// States, and the lines that a text node's view lays out in each, on every platform.
  private static let expectedLines: [(state: State, lines: [String])] = [
    (State("latin", latin, 0, .byWordWrapping), ["Lorem Ipsum is simply ", "dummy text of the ", "printing and typesetting ", "industry."]),
    (State("latin", latin, 1, .byWordWrapping), ["Lorem Ipsum is simply "]),
    (State("latin", latin, 1, .byTruncatingTail), ["Lorem Ipsum is simply d…"]),
    (State("latin", latin, 1, .byTruncatingMiddle), ["Lorem Ipsu…ting industry."]),
    (State("latin", latin, 1, .byTruncatingHead), ["…nd typesetting industry."]),
    (State("latin", latin, 1, .byClipping), ["Lorem Ipsum is simply dummy text of the printing and typesetting industry."]),
    (State("latin", latin, 2, .byWordWrapping), ["Lorem Ipsum is simply ", "dummy text of the "]),
    (State("latin", latin, 2, .byTruncatingTail), ["Lorem Ipsum is simply ", "dummy text of the printi…"]),
    (State("latin", latin, 2, .byTruncatingMiddle), ["Lorem Ipsum is simply ", "dummy text…ing industry."]),
    (State("latin", latin, 2, .byTruncatingHead), ["Lorem Ipsum is simply ", "…nd typesetting industry."]),
    (State("latin", latin, 2, .byClipping), ["Lorem Ipsum is simply ", "dummy text of the printing and typesetting industry."]),
    (State("latin", latin, 2, .byTruncatingTail, inset: CGSize(width: 4, height: 2)), ["Lorem Ipsum is simply ", "dummy text of the prin…"]),
    (State("latin", latin, 0, .byCharWrapping), ["Lorem Ipsum is simply du", "mmy text of the printing a", "nd typesetting industry."]),
    (State("latin", latin, 1, .byCharWrapping), ["Lorem Ipsum is simply du"]),
    (State("latin", latin, 2, .byCharWrapping), ["Lorem Ipsum is simply du", "mmy text of the printing a"]),
    (State("latin", latin, 2, .byCharWrapping, inset: CGSize(width: 4, height: 2)), ["Lorem Ipsum is simply d", "ummy text of the printin"]),
    (State("paragraphs", paragraphs, 0, .byWordWrapping), ["First paragraph\n", "Second paragraph that is ", "a bit longer\n", "Third"]),
    (State("paragraphs", paragraphs, 0, .byWordWrapping, inset: CGSize(width: 4, height: 2)), ["First paragraph\n", "Second paragraph that ", "is a bit longer\n", "Third"]),
    (State("paragraphs", paragraphs, 2, .byTruncatingTail), ["First paragraph\n", "Second paragraph that i…"]),
    (State("paragraphs", paragraphs, 2, .byTruncatingMiddle), ["First paragraph\n", "Second par…s a bit longer\n"]),
    (State("paragraphs", paragraphs, 2, .byTruncatingHead), ["First paragraph\n", "…graph that is a bit longer\n"]),
    (State("paragraphs", paragraphs, 2, .byCharWrapping), ["First paragraph\n", "Second paragraph that is "]),
    (State("arabic", arabic, 0, .byWordWrapping), ["مرحبا بالعالم، هذا نص عربي ", "طويل يلتف عبر عدة أسطر"]),
    (State("arabic", arabic, 1, .byTruncatingTail), ["مرحبا بالعالم، هذا نص عربي…"]),
    (State("arabic", arabic, 1, .byTruncatingMiddle), ["مرحبا بالعالم،…عبر عدة أسطر"]),
    (State("arabic", arabic, 1, .byTruncatingHead), ["…ربي طويل يلتف عبر عدة أسطر"]),
    (State("arabic", arabic, 0, .byCharWrapping), ["مرحبا بالعالم، هذا نص عربي طو", "يل يلتف عبر عدة أسطر"]),
    (State("arabic", arabic, 1, .byCharWrapping), ["مرحبا بالعالم، هذا نص عربي طو"]),
  ]

  /// The number of lines and the line break modes that the cases use.
  private static let settings: [(numberOfLines: Int, lineBreakMode: NSLineBreakMode)] = [
    (0, .byWordWrapping),
    (0, .byCharWrapping),
    (1, .byWordWrapping),
    (1, .byCharWrapping),
    (1, .byTruncatingTail),
    (1, .byTruncatingMiddle),
    (1, .byTruncatingHead),
    (1, .byClipping),
    (2, .byWordWrapping),
    (2, .byTruncatingTail),
    (2, .byTruncatingMiddle),
    (2, .byTruncatingHead),
    (2, .byClipping),
    (2, .byCharWrapping),
  ]

  /// The states that each change ends in.
  private static let finalStates: [State] = texts.flatMap { text in
    settings.flatMap { setting in
      [CGSize.zero, CGSize(width: 4, height: 2)].map { inset in
        State(text.name, text.text, setting.numberOfLines, setting.lineBreakMode, inset: inset)
      }
    }
  }

  private static func makeText(_ string: String) -> NSAttributedString {
    NSAttributedString(string: string, attributes: [.font: Font.systemFont(ofSize: 13), .foregroundColor: Color.black])
  }
}

// MARK: - Harness

/// The kinds of view that a text node shows its text in.
private enum Kind: CaseIterable, CustomStringConvertible {

  /// A text that the user can neither edit nor select, in a label view.
  case label

  /// A text that the user can select, in a text view that doesn't scroll.
  case selectable

  /// A text that the user can edit, in a text view that scrolls.
  case editable

  var description: String {
    switch self {
    case .label:
      return "label"
    case .selectable:
      return "selectable"
    case .editable:
      return "editable"
    }
  }
}

/// A text node's text, settings and width.
private struct State {

  let name: String

  var text: NSAttributedString

  var numberOfLines: Int

  var lineBreakMode: NSLineBreakMode

  var inset: CGSize

  var width: CGFloat

  /// Creates a state in the width that the cases use.
  init(_ textName: String, _ text: NSAttributedString, _ numberOfLines: Int, _ lineBreakMode: NSLineBreakMode, inset: CGSize = .zero) {
    name = "\(textName), \(numberOfLines) lines, \(lineBreakMode.name), inset \(inset.width)x\(inset.height)"
    self.text = text
    self.numberOfLines = numberOfLines
    self.lineBreakMode = lineBreakMode
    self.inset = inset
    width = 160
  }
}

/// A change that a refresh or a reuse makes to a text node's view.
private enum Change: CaseIterable, CustomStringConvertible {

  /// The view gets wider.
  case wider

  /// The view gets narrower.
  case narrower

  /// The text had one line.
  case fromOneLine

  /// The text had no line limit.
  case fromNoLimit

  /// The text had another line break mode.
  case fromOtherLineBreakMode

  /// The text had character wrapping, which breaks every line between characters.
  case fromCharWrapping

  /// The text had another inset.
  case fromOtherInset

  /// The view showed another text.
  case fromOtherText

  /// The text had the other editability, which only a text view has both of.
  case fromOtherEditability

  /// The view showed another text node, which one render pass removes, reusing its view for the text node.
  case reusedInTheSamePass

  /// The view showed another text node, which a render pass removed to the pool, which a later render pass takes it from.
  case reusedFromThePool

  var description: String {
    switch self {
    case .wider:
      return "wider"
    case .narrower:
      return "narrower"
    case .fromOneLine:
      return "from one line"
    case .fromNoLimit:
      return "from no limit"
    case .fromOtherLineBreakMode:
      return "from another line break mode"
    case .fromCharWrapping:
      return "from char wrapping"
    case .fromOtherInset:
      return "from another inset"
    case .fromOtherText:
      return "from another text"
    case .fromOtherEditability:
      return "from the other editability"
    case .reusedInTheSamePass:
      return "reused in the same pass"
    case .reusedFromThePool:
      return "reused from the pool"
    }
  }

  /// Returns the state and the kind before the change, `nil` when the change doesn't apply.
  func state(before state: State, kind: Kind) -> (state: State, kind: Kind)? {
    var before = state
    switch self {
    case .wider:
      before.width = state.width - 40
    case .narrower:
      before.width = state.width + 60
    case .fromOneLine:
      guard state.numberOfLines != 1 else {
        return nil
      }
      before.numberOfLines = 1
    case .fromNoLimit:
      guard state.numberOfLines != 0 else {
        return nil
      }
      before.numberOfLines = 0
    case .fromOtherLineBreakMode:
      before.lineBreakMode = state.lineBreakMode == .byWordWrapping ? .byTruncatingTail : .byWordWrapping
    case .fromCharWrapping:
      guard state.lineBreakMode != .byCharWrapping else {
        return nil
      }
      before.lineBreakMode = .byCharWrapping
    case .fromOtherInset:
      before.inset = state.inset == .zero ? CGSize(width: 4, height: 2) : .zero
    case .fromOtherText,
         .reusedInTheSamePass,
         .reusedFromThePool:
      // another text in another number of lines, so that the view also changes its height
      before.text = NSAttributedString(
        string: "Another text, which wraps across a few lines in the width",
        attributes: state.text.attributes(at: 0, effectiveRange: nil)
      )
      before.numberOfLines = state.numberOfLines == 1 ? 0 : 1
    case .fromOtherEditability:
      switch kind {
      case .label:
        return nil
      case .selectable:
        return (before, .editable)
      case .editable:
        return (before, .selectable)
      }
    }
    return (before, kind)
  }

  /// Applies the change to the harness, which shows the state before the change, so that it shows the state.
  func apply(to harness: Harness, state: State, kind: Kind) {
    switch self {
    case .wider,
         .narrower,
         .fromOneLine,
         .fromNoLimit,
         .fromOtherLineBreakMode,
         .fromCharWrapping,
         .fromOtherInset,
         .fromOtherText,
         .fromOtherEditability:
      harness.model.state = state
      harness.model.kind = kind
      harness.render()
    case .reusedInTheSamePass:
      harness.model.id = "other"
      harness.model.state = state
      harness.render()
    case .reusedFromThePool:
      harness.model.isShown = false
      harness.render()
      harness.model.id = "other"
      harness.model.state = state
      harness.model.isShown = true
      harness.render()
    }
  }
}

/// What a harness shows.
private final class Model {

  var state: State

  var kind: Kind

  var id = "text"

  var isShown = true

  /// The view of the text node, as of the last render that showed it.
  var view: View?

  init(state: State, kind: Kind) {
    self.state = state
    self.kind = kind
  }
}

/// A compose view, with its own pool, that shows a text node of a model's state, sized to its text in the state's width.
private final class Harness {

  let model: Model

  private let contentView: ComposeView

  init(state: State, kind: Kind) {
    let model = Model(state: state, kind: kind)
    self.model = model
    contentView = ComposeView {
      if model.isShown {
        TextNode(model.state.text)
          .numberOfLines(model.state.numberOfLines)
          .lineBreakMode(model.state.lineBreakMode)
          .textContainerInset(horizontal: model.state.inset.width, vertical: model.state.inset.height)
          .editable(model.kind == .editable)
          .selectable(model.kind != .label)
          .fixedSize(width: false, height: true)
          .id(model.id)
          .onUpdate { renderable, _ in
            model.view = renderable.view
          }
      }
    }
    contentView.renderablePool = RenderablePool()
  }

  /// Renders the model, and returns the lines that the text node's view lays out.
  @discardableResult
  func render() -> [String] {
    contentView.frame = CGRect(x: 0, y: 0, width: model.state.width, height: 1000)
    contentView.refresh(animated: false)
    return Self.lines(of: model.view)
  }

  /// Returns the lines that a text node's view lays out.
  static func lines(of view: View?) -> [String] {
    guard let view else {
      return []
    }
    switch view {
    case let textView as BaseTextView:
      #if canImport(AppKit)
      guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else {
        return []
      }
      return layoutManager.laidOutLines(in: textContainer)
      #endif
      #if canImport(UIKit)
      return textView.layoutManager.laidOutLines(in: textView.textContainer)
      #endif
    case let labelView as TextLabelView:
      // a label lays out its text when it draws
      labelView.layer().displayIfNeeded()
      return labelView.test.layoutManager.laidOutLines(in: labelView.test.textContainer)
    default:
      return []
    }
  }
}

private extension NSLineBreakMode {

  var name: String {
    switch self {
    case .byWordWrapping:
      return "word wrapping"
    case .byCharWrapping:
      return "char wrapping"
    case .byClipping:
      return "clipping"
    case .byTruncatingHead:
      return "truncating head"
    case .byTruncatingTail:
      return "truncating tail"
    case .byTruncatingMiddle:
      return "truncating middle"
    @unknown default:
      return "\(rawValue)"
    }
  }
}
