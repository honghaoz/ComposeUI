//
//  SwiftUIViewNode.swift
//  ComposéUI
//
//  Created by Honghao Zhang on 3/19/25.
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

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// A node that renders a SwiftUI view.
///
/// The node has flexible width and flexible height.
/// Use `fixedSize(width:height:)` to control whether the node uses the view's intrinsic size
/// or adapts to the container size for each dimension.
public struct SwiftUIViewNode<Content: SwiftUI.View>: ComposeNode, IntrinsicSizableComposeNode {

  public var isFixedWidth: Bool = false
  public var isFixedHeight: Bool = false

  private var content: () -> Content
  private var isStaticContent: Bool

  /// Create a static SwiftUI view node.
  ///
  /// This is a static SwiftUI view node. The SwiftUI view will be rendered once and not updated.
  /// Use `SwiftUIViewNode { ... }` to create a dynamic SwiftUI view node.
  ///
  /// - Parameters:
  ///   - id: The id used to differentiate the SwiftUI content. The id should be unique to the SwiftUI content.
  ///   - content: The SwiftUI view to render.
  public init(id: String, _ content: Content) {
    self.content = { content }
    self.isStaticContent = true
    self.id = .custom("SUI-\(id)")
  }

  /// Create a dynamic SwiftUI view node.
  ///
  /// - Parameters:
  ///   - content: A closure that returns the SwiftUI view to render.
  public init(_ content: @escaping () -> Content) {
    self.content = content
    self.isStaticContent = false
    self.id = .standard(.swiftui)
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    switch (isFixedWidth, isFixedHeight) {
    case (true, true):
      size = content().sizeThatFits(containerSize)
      return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height))
    case (true, false):
      size = CGSize(width: content().sizeThatFits(containerSize).width, height: containerSize.height)
      return ComposeNodeSizing(width: .fixed(size.width), height: .flexible)
    case (false, true):
      size = CGSize(width: containerSize.width, height: content().sizeThatFits(containerSize).height)
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

    let viewItem = ViewItem<View>(
      id: id,
      frame: frame,
      make: { context in
        let view: SwiftUIHostingView<AnyView>
        if isStaticContent {
          view = SwiftUIHostingView(rootView: AnyView(content()))
        } else {
          view = MutableSwiftUIHostingView()
        }
        if let initialFrame = context.initialFrame {
          view.frame = initialFrame
        }
        return view
      },
      update: { view, context in
        guard !isStaticContent, context.updateType.requiresFullUpdate else {
          return
        }
        (view as? MutableSwiftUIHostingView)
          .assertNotNil("view should be a MutableSwiftUIHostingView")?
          .content = AnyView(content())
      }
    )

    return [viewItem.eraseToRenderableItem()]
  }
}
