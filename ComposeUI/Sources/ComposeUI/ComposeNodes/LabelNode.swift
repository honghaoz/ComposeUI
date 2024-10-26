//
//  LabelNode.swift
//  ComposeUI
//
//  Created by Honghao Zhang on 9/29/24.
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

public struct LabelNode: ComposeNode {

  private let text: String
  private var font: UIFont
  private var textColor: UIColor
  private var textAlignment: NSTextAlignment
  private var numberOfLines: Int

  public init(_ text: String) {
    self.text = text
    font = .systemFont(ofSize: UIFont.labelFontSize)
    textColor = .label
    textAlignment = .center
    numberOfLines = 1
  }

  // MARK: - ComposeNode

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize) -> ComposeNodeSizing {
    // TODO: support text sizing
    size = containerSize
    return ComposeNodeSizing(width: .flexible, height: .flexible)
  }

  public func viewItems(in visibleBounds: CGRect) -> [ViewItem<UIView>] {
    let frame = CGRect(origin: .zero, size: size)
    guard visibleBounds.actuallyIntersects(frame) else {
      return []
    }

    let viewItem = ViewItem<UILabel>(
      id: ComposeNodeId.label.rawValue,
      frame: frame,
      update: { view in
        view.text = text
        view.font = font
        view.textColor = textColor
        view.textAlignment = textAlignment

        view.isUserInteractionEnabled = false
      }
    ).eraseToUIViewItem()

    return [viewItem]
  }

  // MARK: - Public

  /// Set the font of the label node.
  public func font(_ value: UIFont) -> Self {
    guard font != value else {
      return self
    }

    var copy = self
    copy.font = value
    return copy
  }

  /// Set the text color of the label node.
  public func textColor(_ value: UIColor) -> Self {
    guard textColor != value else {
      return self
    }

    var copy = self
    copy.textColor = value
    return copy
  }

  /// Set the text alignment of the label node.
  public func textAlignment(_ value: NSTextAlignment) -> Self {
    guard textAlignment != value else {
      return self
    }

    var copy = self
    copy.textAlignment = value
    return copy
  }

  public func numberOfLines(_ value: Int) -> Self {
    guard numberOfLines != value else {
      return self
    }

    var copy = self
    copy.numberOfLines = value
    return copy
  }
}
