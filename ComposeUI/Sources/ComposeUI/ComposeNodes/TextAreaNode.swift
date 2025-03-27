//
//  TextAreaNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/23/25.
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

public typealias TextArea = TextAreaNode

/// A node that renders a multi-line, editable text area.
///
/// By default, the text area node is multi-line with flexible width and height.
/// Use `fixedSize(width:height:)` to set the width and height to be fixed or flexible.
public struct TextAreaNode: ComposeNode, FixedSizableComposeNode {

  // MARK: - Text storage

  private let attributedString: NSAttributedString

  // MARK: - Text layout

  private var numberOfLines: Int

  private var textSizeAdjustment: CGSize? // TODO: support this

  private var isEditable: Bool
  private var isSelectable: Bool

  public var isFixedWidth: Bool
  public var isFixedHeight: Bool

  /// Initialize a text area node with optional initial text.
  ///
  /// - Parameter attributedString: The text to display.
  public init(_ attributedString: NSAttributedString) {
    self.attributedString = attributedString
    numberOfLines = 0

    isEditable = false
    isSelectable = true

    isFixedWidth = false
    isFixedHeight = false
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.textView)

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    switch (isFixedWidth, isFixedHeight) {
    case (true, true):
      size = attributedString.boundingRectSize(numberOfLines: numberOfLines, layoutWidth: containerSize.width).roundedUp(scaleFactor: 1)
      return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height))
    case (true, false):
      let intrinsicSize = attributedString.boundingRectSize(numberOfLines: numberOfLines, layoutWidth: containerSize.width).roundedUp(scaleFactor: 1)
      size = CGSize(width: intrinsicSize.width, height: containerSize.height)
      return ComposeNodeSizing(width: .fixed(size.width), height: .flexible)
    case (false, true):
      let intrinsicSize = attributedString.boundingRectSize(numberOfLines: numberOfLines, layoutWidth: containerSize.width).roundedUp(scaleFactor: 1)
      size = CGSize(width: containerSize.width, height: intrinsicSize.height)
      return ComposeNodeSizing(width: .flexible, height: .fixed(size.height))
    case (false, false):
      size = containerSize
      return ComposeNodeSizing(width: .flexible, height: .flexible)
    }
  }

  public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    let frame = CGRect(origin: .zero, size: size)
    guard visibleBounds.intersects(frame) else {
      return []
    }

    let viewItem = ViewItem<BaseTextView>(
      id: id,
      frame: frame,
      make: { BaseTextView(frame: $0.initialFrame ?? .zero) },
      update: { view, context in
        guard context.updateType.requiresFullUpdate else {
          return
        }
        updateTextView(view)
      }
    )

    return [viewItem.eraseToRenderableItem()]
  }

  // MARK: - Private

  private func updateTextView(_ textView: BaseTextView) {
    #if canImport(AppKit)
    // TODO: support scrollable
    textView.attributedString = attributedString
    textView.numberOfLines = numberOfLines
    #endif

    #if canImport(UIKit)
    // TODO: verify the behavior
    textView.attributedText = attributedString
    textView.textContainer.maximumNumberOfLines = numberOfLines
    textView.backgroundColor = .clear
    textView.isScrollEnabled = true
    #endif

    textView.isEditable = isEditable
    textView.isSelectable = isSelectable
  }

  // MARK: - Public

  /// Set the number of lines of the text area.
  ///
  /// - Parameter value: The number of lines to set.
  /// - Returns: A new text area node with the updated number of lines.
  public func numberOfLines(_ value: Int) -> Self {
    let value = max(value, 0)
    guard numberOfLines != value else {
      return self
    }

    var copy = self
    copy.numberOfLines = value
    return copy
  }

  /// Set whether the text area is editable.
  ///
  /// - Parameter value: A boolean indicating whether the text area is editable.
  /// - Returns: A new text area node with the updated editable state.
  public func editable(_ value: Bool = true) -> Self {
    guard isEditable != value else {
      return self
    }

    var copy = self
    copy.isEditable = value
    return copy
  }

  /// Set whether the text area is selectable.
  ///
  /// - Parameter value: A boolean indicating whether the text area is selectable.
  /// - Returns: A new text area node with the updated selectable state.
  public func selectable(_ value: Bool = true) -> Self {
    guard isSelectable != value else {
      return self
    }

    var copy = self
    copy.isSelectable = value
    return copy
  }
}
