//
//  ColorNode.swift
//  ComposéUI
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

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// A node that renders a solid color.
///
/// The node has a flexible size.
public struct ColorNode: ComposeNode {

  private let color: Color

  /// Initialize a color node with a color.
  ///
  /// - Parameter color: The color to render.
  public init(_ color: Color) {
    self.color = color
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId = .standard(.color)

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    size = containerSize
    return ComposeNodeSizing(width: .flexible, height: .flexible)
  }

  public func viewItems(in visibleBounds: CGRect) -> [ViewItem<View>] {
    let frame = CGRect(origin: .zero, size: size)
    guard visibleBounds.intersects(frame) else {
      return []
    }

    let viewItem = ViewItem<BaseView>(
      id: id,
      frame: frame,
      make: { context in
        if let initialFrame = context.initialFrame {
          return BaseView(frame: initialFrame)
        } else {
          return BaseView()
        }
      },
      update: { view, context in
        #if canImport(AppKit)
        view.ignoreHitTest = true
        #endif

        #if canImport(UIKit)
        view.isUserInteractionEnabled = false
        #endif

        view.layer().backgroundColor = color.cgColor
      }
    )

    return [viewItem.eraseToViewItem()]
  }
}
