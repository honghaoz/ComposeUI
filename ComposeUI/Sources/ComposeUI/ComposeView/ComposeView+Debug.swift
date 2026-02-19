//
//  ComposeView+Debug.swift
//  ComposéUI
//
//  Created by Honghao on 6/28/25.
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

#if DEBUG
import Foundation

public extension ComposeView {

  /// A debug tool to inject event handlers into the ComposeView.
  final class Debug {

    /// The debug events.
    public enum Event {

      /// The render pass is about to begin, the content node is about to be laid out.
      case renderWillBegin(contentNode: ComposeNode)

      /// The content node will begin the layout process with the given bounds (container size) and visible bounds.
      case renderWillLayout(contentNode: ComposeNode, bounds: CGRect, visibleBounds: CGRect)

      /// The content node has finished the layout process. The content size is the size of the content node.
      case renderDidLayout(contentSize: CGSize)

      /// The content node will begin to request the renderable items in the given visible bounds.
      case renderWillRequestRenderableItems(visibleBounds: CGRect)

      /// The content node has received the renderable items.
      case renderDidReceiveRenderableItems(renderableItems: [RenderableItem], contentSize: CGSize)

      /// The scrollable behavior has been updated.
      case renderDidUpdateScrollableBehavior(isScrollable: Bool, alwaysBounceHorizontal: Bool, alwaysBounceVertical: Bool)

      /// The clipping behavior has been updated.
      case renderDidUpdateClippingBehavior(clipsToBounds: Bool)

      /// The scroll indicator behavior has been updated.
      case renderDidUpdateScrollIndicatorBehavior(showsHorizontalScrollIndicator: Bool, showsVerticalScrollIndicator: Bool)

      /// The renderable item will be removed from the renderable hierarchy.
      case renderWillRemoveRenderable(item: RenderableItem, renderable: Renderable)

      /// The renderable item has been removed from the renderable hierarchy.
      case renderDidRemoveRenderable(item: RenderableItem, renderable: Renderable)

      /// The removing renderable transition has been cancelled.
      case renderDidCancelRemoveRenderable(item: RenderableItem, renderable: Renderable)

      /// The renderable item will be reused.
      case renderWillReuseRenderable(item: RenderableItem, renderable: Renderable)

      /// The renderable item has been reused.
      case renderDidReuseRenderable(item: RenderableItem, renderable: Renderable)

      /// The renderable item will be inserted into the renderable hierarchy.
      case renderWillInsertRenderable(item: RenderableItem, renderable: Renderable)

      /// The renderable item has been inserted into the renderable hierarchy.
      case renderDidInsertRenderable(item: RenderableItem, renderable: Renderable)

      /// The render pass is finished, all the renderable items are rendered, transition animations or animations may still be running.
      case renderDidFinish(renderableItemIds: [String], renderableItemMap: [String: RenderableItem], renderableMap: [String: Renderable])
    }

    private weak var composeView: ComposeView?
    private let eventHandler: (ComposeView, ComposeView.Debug.Event) -> Void

    init(composeView: ComposeView, eventHandler: @escaping (ComposeView, ComposeView.Debug.Event) -> Void) {
      self.composeView = composeView
      self.eventHandler = eventHandler
    }

    func onEvent(_ event: ComposeView.Debug.Event) {
      guard let composeView else {
        return
      }
      eventHandler(composeView, event)
    }
  }
}
#endif
