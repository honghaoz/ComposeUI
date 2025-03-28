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

  private var textContainerInset: CGSize
  private var lineFragmentPadding: CGFloat
  private var intrinsicTextSizeAdjustment: CGSize

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

    textContainerInset = .zero
    lineFragmentPadding = 0
    intrinsicTextSizeAdjustment = Constants.defaultIntrinsicTextSizeAdjustment

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
      size = intrinsicTextSize(for: containerSize)
      return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height))
    case (true, false):
      let intrinsicSize = intrinsicTextSize(for: containerSize)
      size = CGSize(width: intrinsicSize.width, height: containerSize.height)
      return ComposeNodeSizing(width: .fixed(size.width), height: .flexible)
    case (false, true):
      let intrinsicSize = intrinsicTextSize(for: containerSize)
      size = CGSize(width: containerSize.width, height: intrinsicSize.height)
      return ComposeNodeSizing(width: .flexible, height: .fixed(size.height))
    case (false, false):
      size = containerSize
      return ComposeNodeSizing(width: .flexible, height: .flexible)
    }
  }

  private func intrinsicTextSize(for containerSize: CGSize) -> CGSize {
    let rawIntrinsicSize = attributedString.boundingRectSize(numberOfLines: numberOfLines, layoutWidth: containerSize.width)
    let intrinsicSize = CGSize(width: rawIntrinsicSize.width + intrinsicTextSizeAdjustment.width, height: rawIntrinsicSize.height + intrinsicTextSizeAdjustment.height)
    return intrinsicSize.roundedUp(scaleFactor: 1)
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
    textView.attributedString = attributedString

    textView.numberOfLines = numberOfLines

    #if canImport(AppKit)
    textView.textContainerInset = textContainerInset
    textView.textContainer?.lineFragmentPadding = lineFragmentPadding
    #endif

    #if canImport(UIKit)
    textView.textContainerInset = UIEdgeInsets(
      top: textContainerInset.height,
      left: textContainerInset.width,
      bottom: textContainerInset.height,
      right: textContainerInset.width
    )
    textView.textContainer.lineFragmentPadding = lineFragmentPadding
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

  /// Set the text container inset of the underlying text view.
  ///
  /// The default text container inset is `(0, 0)`.
  ///
  /// - Parameter horizontal: The horizontal inset to set.
  /// - Parameter vertical: The vertical inset to set.
  /// - Returns: A new text area node with the updated text container inset.
  public func textContainerInset(horizontal: CGFloat, vertical: CGFloat) -> Self {
    guard textContainerInset != CGSize(width: horizontal, height: vertical) else {
      return self
    }

    var copy = self
    copy.textContainerInset = CGSize(width: horizontal, height: vertical)
    return copy
  }

  /// Set the line fragment padding of the underlying text view.
  ///
  /// The default line fragment padding is `0`.
  ///
  /// - Parameter value: The line fragment padding to set.
  /// - Returns: A new text area node with the updated line fragment padding.
  public func lineFragmentPadding(_ value: CGFloat) -> Self {
    guard lineFragmentPadding != value else {
      return self
    }

    var copy = self
    copy.lineFragmentPadding = value
    return copy
  }

  /// Set the intrinsic text size adjustment.
  ///
  /// The text area node with fixed size uses the intrinsic text size to determine
  /// the size of the text area. You can use this method to apply an additional
  /// size adjustment to the intrinsic text size.
  ///
  /// The default adjustment is `(0, 1)`.
  ///
  /// - Parameter width: The width adjustment to set.
  /// - Parameter height: The height adjustment to set.
  /// - Returns: A new text area node with the updated intrinsic text size adjustment.
  public func intrinsicTextSizeAdjustment(width: CGFloat, height: CGFloat) -> Self {
    let adjustment = CGSize(width: width, height: height)
    guard intrinsicTextSizeAdjustment != adjustment else {
      return self
    }

    var copy = self
    copy.intrinsicTextSizeAdjustment = adjustment
    return copy
  }

  // MARK: - Constants

  private enum Constants {
    static let defaultIntrinsicTextSizeAdjustment = CGSize(width: 0, height: 1)
  }
}
