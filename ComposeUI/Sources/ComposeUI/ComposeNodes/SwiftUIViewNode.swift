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
/// The node will be flexible in width and height. Use `fixedSize(width:height:)` to set the size of the node.
public struct SwiftUIViewNode<Content: SwiftUI.View>: ComposeNode, FixedSizableComposeNode {

  private var viewNode: ViewNode<View>

  /// Create a static SwiftUI view node.
  ///
  /// This is a static SwiftUI view node. The SwiftUI view will be rendered once and not updated.
  /// Use `SwiftUIViewNode { ... }` to create a dynamic SwiftUI view node.
  ///
  /// - Parameters:
  ///   - id: The id used to differentiate the SwiftUI content. The id should be unique to the SwiftUI content.
  ///   - content: The SwiftUI view to render.
  public init(id: String, _ content: Content) {
    self.viewNode = ViewNode(
      make: { context in
        let view = SwiftUIHostingView(rootView: AnyView(content))
        if let initialFrame = context.initialFrame {
          view.frame = initialFrame
        }
        return view
      }
    )
    self.viewNode.id = .custom("SUI-\(id)")
  }

  /// Create a dynamic SwiftUI view node.
  ///
  /// - Parameters:
  ///   - content: A closure that returns the SwiftUI view to render.
  public init(_ content: @escaping () -> Content) {
    self.viewNode = ViewNode<View>(
      make: { context in
        let view = MutableSwiftUIHostingView()
        if let initialFrame = context.initialFrame {
          view.frame = initialFrame
        }
        return view
      },
      update: { view, context in
        guard context.updateType.requiresFullUpdate else {
          return
        }
        (view as? MutableSwiftUIHostingView)?.content = AnyView(content())
      }
    )
    self.viewNode.id = .standard(.swiftui)
  }

  // MARK: - FixedSizableComposeNode

  public var isFixedWidth: Bool {
    get { viewNode.isFixedWidth }
    set { viewNode.isFixedWidth = newValue }
  }

  public var isFixedHeight: Bool {
    get { viewNode.isFixedHeight }
    set { viewNode.isFixedHeight = newValue }
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId {
    get { viewNode.id }
    set { viewNode.id = newValue }
  }

  public var size: CGSize { viewNode.size }

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    viewNode.layout(containerSize: containerSize, context: context)
  }

  public func renderableItems(in visibleBounds: CGRect) -> [RenderableItem] {
    viewNode.renderableItems(in: visibleBounds)
  }
}
