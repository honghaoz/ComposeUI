//
//  ComposeView+ScrollReuseTests.swift
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

class ComposeView_ScrollReuseTests: XCTestCase {

  func test_scroll_rendersWhatANewViewRendersAtEachOffset() {
    // given: a compose view with its own pool, showing rows of texts of each kind, line limit and line break mode, and
    // of layers, in a frame that shows a few rows, and a recorder of what it renders
    let scrolledView = Self.makeView()
    let recorder = RenderRecorder(scrolledView)
    scrolledView.refresh(animated: false)
    let bottom = scrolledView.contentSize.height - scrolledView.bounds.height
    expect(bottom) > 1000

    for offset in Self.offsets(bottom: bottom) {
      // when: scrolling to the offset, which reuses the views and layers of the rows that scroll out for the rows that
      // scroll in
      scrolledView.contentOffset = CGPoint(x: 0, y: offset)
      scrolledView.layoutIfNeeded()

      // then: it renders the same as a new view that renders at the offset first, and shows nothing else, such as a
      // view of a row that scrolled out
      let newView = Self.makeView()
      let newRecorder = RenderRecorder(newView)
      newView.contentOffset = CGPoint(x: 0, y: offset)
      newView.refresh(animated: false)
      expect(recorder.rendered.isEmpty, "offset \(offset)") == false
      expect(recorder.rendered, "offset \(offset)") == newRecorder.rendered
      let shownContent = Self.shownContent(of: scrolledView)
      expect(shownContent.isEmpty, "offset \(offset)") == false
      expect(shownContent, "offset \(offset)") == Self.shownContent(of: newView)
    }

    // then: the scroll reused label views, text views and layers
    expect(recorder.reusedTypes.contains("TextLabelView")) == true
    expect(recorder.reusedTypes.contains("BaseTextView")) == true
    expect(recorder.reusedTypes.contains { $0.contains("Layer") }) == true
  }

  // MARK: - Content

  /// Returns the offsets to scroll to: down in steps that don't divide the rows' heights, a jump back to the top, then
  /// down and back up in other steps.
  private static func offsets(bottom: CGFloat) -> [CGFloat] {
    var offsets: [CGFloat] = []
    var offset: CGFloat = 0
    while offset < bottom {
      offset = min(offset + 53, bottom)
      offsets.append(offset)
    }
    offsets.append(0)
    offset = 0
    while offset < bottom {
      offset = min(offset + 131, bottom)
      offsets.append(offset)
    }
    while offset > 0 {
      offset = max(offset - 71, 0)
      offsets.append(offset)
    }
    return offsets
  }

  /// Returns a compose view with its own pool, showing the rows in a frame that shows a few of them.
  private static func makeView() -> ComposeView {
    let view = ComposeView {
      VStack(spacing: 6) {
        for index in 0 ..< 48 {
          row(index)
        }
      }
    }
    view.frame = CGRect(x: 0, y: 0, width: 320, height: 300)
    view.renderablePool = RenderablePool()
    return view
  }

  /// Returns a row of texts or layers, which differ from row to row in their kinds, settings, texts and heights.
  @ComposeContentBuilder
  private static func row(_ index: Int) -> ComposeContent {
    let numberOfLines = [0, 1, 2][index / 6 % 3]
    let lineBreakMode: NSLineBreakMode = [.byWordWrapping, .byTruncatingTail, .byTruncatingMiddle, .byTruncatingHead, .byClipping, .byCharWrapping][index % 6]
    switch index % 4 {
    case 0:
      HStack(alignment: .top, spacing: 8) {
        for kind in TextKind.allCases {
          text(index, kind: kind, numberOfLines: numberOfLines, lineBreakMode: lineBreakMode)
        }
      }
    case 1:
      ColorNode(Color(red: CGFloat(index % 7) / 7, green: 0.5, blue: CGFloat(index % 3) / 3, alpha: 1))
        .frame(width: .flexible, height: 12 + CGFloat(index % 5) * 9)
    case 2:
      HStack(alignment: .top, spacing: 8) {
        text(index, kind: TextKind.allCases[index / 4 % 3], numberOfLines: 0, lineBreakMode: .byWordWrapping)
        text(index + 1, kind: TextKind.allCases[(index / 4 + 1) % 3], numberOfLines: numberOfLines, lineBreakMode: lineBreakMode)
      }
    default:
      text(index, kind: TextKind.allCases[index / 4 % 3], numberOfLines: numberOfLines, lineBreakMode: lineBreakMode)
    }
  }

  /// Returns a text node of a kind, with a text whose length, font size and color differ from row to row, sized to its
  /// text.
  private static func text(_ index: Int, kind: TextKind, numberOfLines: Int, lineBreakMode: NSLineBreakMode) -> some ComposeNode {
    let string = (0 ... (index * 7) % 23).map { "word\($0)" }.joined(separator: " ") + " end of row \(index)"
    let fontSize: CGFloat = [13, 15, 11][index % 3]
    let color: Color = [.black, .red, .blue][index / 3 % 3]
    return TextNode(string, font: Font.systemFont(ofSize: fontSize), foregroundColor: ThemedColor(color))
      .numberOfLines(numberOfLines)
      .lineBreakMode(lineBreakMode)
      .editable(kind == .editable)
      .selectable(kind != .label)
      .fixedSize(width: false, height: true)
  }

  /// Describes what a compose view's content container shows: its subviews and its layers of their own that aren't
  /// hidden, sorted, without UIKit's private subviews, such as the scroll indicators.
  private static func shownContent(of view: ComposeView) -> [String] {
    let container = view.contentContainerView
    #if canImport(AppKit)
    let containerLayer = container.layer
    let viewLayers = container.subviews.compactMap(\.layer)
    #endif
    #if canImport(UIKit)
    let containerLayer: CALayer? = container.layer
    let viewLayers = container.subviews.map(\.layer)
    #endif
    let subviews = container.subviews.filter { !$0.isHidden && !String(describing: type(of: $0)).hasPrefix("_") }
    let layers = (containerLayer?.sublayers ?? []).filter { layer in
      !layer.isHidden && !viewLayers.contains { $0 === layer }
    }
    return (subviews.map { "view \(type(of: $0)) \($0.frame)" } + layers.map { "layer \(type(of: $0)) \($0.frame)" }).sorted()
  }
}

// MARK: - Helpers

/// The kinds of view that a text node shows its text in.
private enum TextKind: CaseIterable {

  /// A text that the user can neither edit nor select, in a label view.
  case label

  /// A text that the user can select, in a text view that doesn't scroll.
  case selectable

  /// A text that the user can edit, in a text view that scrolls.
  case editable
}

/// Records what a compose view renders, and which kinds of renderable its render passes reuse.
private final class RenderRecorder {

  /// What the last render pass rendered, described for each renderable item, by its id.
  private(set) var rendered: [String: String] = [:]

  /// The types of the renderables that a render pass inserted again, after an earlier pass had them.
  private(set) var reusedTypes: Set<String> = []

  private var seenRenderables: Set<ObjectIdentifier> = []

  init(_ view: ComposeView) {
    view.debug { [weak self] _, event in
      guard let self else {
        return
      }
      switch event {
      case .renderWillInsertRenderable(_, let renderable):
        let identifier = ObjectIdentifier(Self.object(of: renderable))
        if self.seenRenderables.contains(identifier) {
          self.reusedTypes.insert(Self.typeName(of: renderable))
        }
      case .renderDidFinish(let ids, _, let renderableMap):
        self.rendered = [:]
        for id in ids {
          guard let renderable = renderableMap[id] else {
            continue
          }
          self.seenRenderables.insert(ObjectIdentifier(Self.object(of: renderable)))
          self.rendered[id.id] = Self.describe(renderable)
        }
      default:
        break
      }
    }
  }

  private static func object(of renderable: Renderable) -> AnyObject {
    switch renderable {
    case .view(let view):
      return view
    case .layer(let layer):
      return layer
    }
  }

  private static func typeName(of renderable: Renderable) -> String {
    String(describing: type(of: object(of: renderable)))
  }

  /// Describes what a renderable shows: its type and frame, whether it shows, and for a text, the lines that it lays
  /// out, its font and color, and a text view's scroll offset.
  private static func describe(_ renderable: Renderable) -> String {
    var parts = [typeName(of: renderable), "frame \(renderable.frame)"]
    let layer = renderable.layer
    parts.append("opacity \(layer.opacity), hidden \(layer.isHidden)")
    if let backgroundColor = layer.backgroundColor {
      parts.append("background \(backgroundColor.components ?? [])")
    }
    switch renderable.view {
    case let textView as BaseTextView:
      #if canImport(AppKit)
      if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
        parts.append("lines \(layoutManager.laidOutLines(in: textContainer)), \(describeStyle(of: layoutManager.textStorage))")
      }
      #endif
      #if canImport(UIKit)
      parts.append("lines \(textView.layoutManager.laidOutLines(in: textView.textContainer)), \(describeStyle(of: textView.textStorage)), offset \(textView.contentOffset)")
      #endif
    case let labelView as TextLabelView:
      // a label lays out its text when it draws
      labelView.layer().displayIfNeeded()
      parts.append("lines \(labelView.test.layoutManager.laidOutLines(in: labelView.test.textContainer)), \(describeStyle(of: labelView.test.layoutManager.textStorage))")
    default:
      break
    }
    return parts.joined(separator: ", ")
  }

  /// Describes the font and the color of a text's first character.
  private static func describeStyle(of textStorage: NSTextStorage?) -> String {
    guard let textStorage, textStorage.length > 0 else {
      return "no text"
    }
    let font = textStorage.attribute(.font, at: 0, effectiveRange: nil) as? Font
    let color = textStorage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? Color
    return "font \(font?.fontName ?? "none") \(font?.pointSize ?? 0), color \(color?.cgColor.components ?? [])"
  }
}
