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
/// Use `fixedSize(width:height:)` to control whether the node uses the view's intrinsic size or adapts to the container
/// size for each dimension.
public struct SwiftUIViewNode<Content: SwiftUI.View>: ComposeNode, IntrinsicSizableComposeNode {

  public var isFixedWidth: Bool = false
  public var isFixedHeight: Bool = false

  /// The retained content closure, identified consistently across copies of this node.
  private let contentProvider: ContentEvaluation.Provider<Content>

  /// Whether the SwiftUI content is static. Static content is not reevaluated on refresh.
  private let isStaticContent: Bool

  /// The render state by the most recent layout.
  private var renderState: RenderState?

  /// Create a static SwiftUI view node.
  /// 
  /// A static SwiftUI view node will evaluate the SwiftUI view once and not update it on refresh.
  /// Use `SwiftUIViewNode { ... }` to create a dynamic SwiftUI view node.
  ///
  /// - Parameters:
  ///   - id: The id used to differentiate the SwiftUI content. The id should be unique to the SwiftUI content.
  ///   - content: The SwiftUI view to render.
  public init(id: String, _ content: Content) {
    self.contentProvider = ContentEvaluation.Provider(make: { content })
    self.isStaticContent = true
    self.id = .custom("SUI-\(id)")
  }

  /// Create a dynamic SwiftUI view node.
  /// 
  /// The dynamic SwiftUI view node will evaluate the SwiftUI view on each refresh.
  ///
  /// - Parameter content: The SwiftUI view to render.
  public init(_ content: @escaping () -> Content) {
    self.contentProvider = ContentEvaluation.Provider(make: content)
    self.isStaticContent = false
    self.id = .standard(.swiftui)
  }

  // MARK: - ComposeNode

  public var id: ComposeNodeId

  public private(set) var size: CGSize = .zero

  public mutating func layout(containerSize: CGSize, context: ComposeNodeLayoutContext) -> ComposeNodeSizing {
    let content = prepareContent(for: context.contentEvaluation)

    switch (isFixedWidth, isFixedHeight) {
    case (true, true):
      size = content.value.sizeThatFits(containerSize)
      return ComposeNodeSizing(width: .fixed(size.width), height: .fixed(size.height))
    case (true, false):
      size = CGSize(width: content.value.sizeThatFits(containerSize).width, height: containerSize.height)
      return ComposeNodeSizing(width: .fixed(size.width), height: .flexible)
    case (false, true):
      size = CGSize(width: containerSize.width, height: content.value.sizeThatFits(containerSize).height)
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

    guard let renderState else {
      return []
    }

    // capture only content and configuration, since renderState also owns the cache retaining these closures.
    let content = renderState.content
    let isStaticContent = isStaticContent

    let item = renderState.itemCache.item(id: id, frame: frame) {
      ViewItem<View>(
        id: id,
        frame: frame,
        make: { context in
          let view: SwiftUIHostingView<AnyView>
          if isStaticContent {
            view = SwiftUIHostingView(rootView: AnyView(content.value))
          } else {
            view = MutableSwiftUIHostingView()
          }
          if let initialFrame = context.initialFrame {
            view.frame = initialFrame
          }
          return view
        },
        update: { view, context in
          guard !isStaticContent else {
            return
          }

          switch context.updateType {
          case .insert,
               .refresh:
            break
          case .boundsChange,
               .scroll:
            return
          }

          (view as? MutableSwiftUIHostingView)
            .assertNotNil("view should be a MutableSwiftUIHostingView")?
            .content = AnyView(content.value)
        }
      )
      .eraseToRenderableItem()
    }

    return [item]
  }

  // MARK: - Content

  /// Returns the content value for the given content evaluation. It returns the cached content if possible.
  private mutating func prepareContent(for evaluation: ContentEvaluation?) -> ContentEvaluation.LazyValue<Content> {
    // Repeated layout proposals reuse the cached content without another dictionary lookup in the evaluation.
    if let renderState, renderState.evaluation === evaluation {
      return renderState.content
    }

    let content = evaluation?.lazyValue(for: contentProvider) ?? ContentEvaluation.LazyValue(provider: contentProvider)
    renderState = RenderState(evaluation: evaluation, content: content)
    return content
  }

  private struct RenderState {

    let evaluation: ContentEvaluation?
    let content: ContentEvaluation.LazyValue<Content>
    let itemCache: RenderableItemCache

    init(evaluation: ContentEvaluation?, content: ContentEvaluation.LazyValue<Content>) {
      self.evaluation = evaluation
      self.content = content
      self.itemCache = RenderableItemCache()
    }
  }
}
